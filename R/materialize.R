#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Materialise files to disk.
#'
#' @description Write files to disk using GDAL.
#'
#' @param x An `sf` object returned by [search()].
#' @param output_dir A `character` with the output directory (created if needed).
#' @param bands A `character` vector with the requested bands, or `NULL` for all.
#' @param roi Optional region of interest used to crop each tile, or `NULL`.
#' @param layout A `character`, either `"stack"` or `"bands"`.
#' @param overwrite Logical. Re-write files that already exist.
#' @param progress Logical. Show a progress bar.
#' @param multicores An `integer` with the number of parallel workers.
#' @param kind A `character` passed to `.materialize_target()` (`"gtiff"` or `"vrt"`).
#'
#' @return A `tibble` with one row per written file (invisible).
#'
#' @noRd
.materialize <- function(x, output_dir, bands, roi, layout, overwrite, progress,
                         multicores, kind) {
  # create the output directory
  output_dir <- fs::dir_create(fs::path_abs(output_dir))

  # describe the output kind, plan the files, then write the ones still needed
  target <- .materialize_target(kind, bbox = roi)
  manifest <- .materialize_manifest(x, bands, layout, output_dir, target$ext)
  .materialize_write(manifest, bands, target, overwrite, progress, multicores)

  # return the file manifest (public columns only)
  invisible(manifest[, c("tile", "year", "band", "path")])
}

#' Describe a materialisation target.
#'
#' @description Bundle the GDAL settings that distinguish the two kinds of
#' on-disk output produced by [download()] (real GeoTIFFs) and [as_vrt()]
#' (virtual VRTs pointing at the remote COGs).
#'
#' @param kind A `character`, either `"gtiff"` (materialise pixels) or `"vrt"`
#'        (write a VRT that streams from the source).
#' @param bbox Optional bbox (EPSG:4326) used to crop each tile, or `NULL`.
#'
#' @return A `list` with the GDAL `driver`, the file `ext`ension, and the
#'         `options` passed to `gdal_translate`.
#'
#' @noRd
.materialize_target <- function(kind, bbox = NULL) {
  # the bbox crop window applies to both kinds
  projwin <- .gdal_projwin(bbox)

  switch(kind,
    gtiff = list(
      driver  = "GTiff",
      ext     = "tif",
      options = c(.config_gtiff_options(), projwin)
    ),
    vrt = list(
      driver  = "VRT",
      ext     = "vrt",
      options = projwin
    )
  )
}

#' Plan the files to materialise.
#'
#' @description Build the file manifest shared by [download()] and [as_vrt()]:
#' one row per output file. The file extension is supplied by the target.
#'
#' @param x An `sf` object returned by [search()].
#' @param bands A `character` vector with the requested bands.
#' @param layout A `character`, either `"stack"` or `"bands"`.
#' @param output_dir A `character` with the output directory.
#' @param ext A `character` with the output file extension (e.g. `"tif"`, `"vrt"`).
#'
#' @return A `tibble` with one row per output file (invisible).
#'
#' @noRd
.materialize_manifest <- function(x, bands, layout, output_dir, ext) {
  # define the file prefix
  prefix <- .config_download_prefix()

  # one multi-band file per tile
  if (layout == "stack") {
    return(tibble::tibble(
      tile = x$tile,
      year = x$year,
      vsicurl = x$vsicurl,
      band = NA_character_,
      path = as.character(
        fs::path(output_dir, glue::glue("{prefix}_{x$tile}_{x$year}.{ext}"))
      )
    ))
  }

  # one single-band file per tile x band
  n_bands <- length(bands)

  tile <- rep(x$tile, each = n_bands)
  year <- rep(x$year, each = n_bands)
  vsicurl <- rep(x$vsicurl, each = n_bands)
  band <- rep(bands, times = nrow(x))

  # build the file manifest
  tibble::tibble(
    tile = tile,
    year = year,
    vsicurl = vsicurl,
    band = band,
    path = as.character(
      fs::path(output_dir, glue::glue("{prefix}_{tile}_{band}_{year}.{ext}"))
    )
  )
}

#' Write a single manifest row.
#'
#' @description Materialise one file from the manifest. A missing (`NA`) band 
#' means a multi-band file holding every requested band; otherwise a single-band file.
#'
#' @param vsicurl A `character` with the streamable `/vsicurl/` source.
#' @param path A `character` with the destination path.
#' @param band A `character` with the band name, or `NA` for a multi-band file.
#' @param idx_all An `integer` vector with the source indices of every requested
#'                band (used for the multi-band case).
#' @param target A `list` from `.materialize_target()` with the `driver` and
#'               `options`.
#'
#' @return The destination `path`, invisibly.
#'
#' @noRd
.materialize_write_row <- function(vsicurl, path, band, idx_all, target) {
  # one multi-band file with every requested band
  if (is.na(band)) {
    .gdal_stack_dataset(
      src     = vsicurl,
      dst     = path,
      driver  = target$driver,
      idx     = idx_all,
      options = target$options
    )
  } 
  
  # one single-band file
  else {
    .gdal_band_dataset(
      src     = vsicurl,
      idx     = .export_band_index(band),
      dst     = path,
      driver  = target$driver,
      options = target$options
    )
  }

  # return the path (invisible)
  invisible(path)
}

#' Materialise the planned files.
#'
#' @description Write every file in the manifest that is still needed 
#' (skipping those already on disk unless `overwrite` is `TRUE`).
#'
#' @param manifest A `tibble` from `.materialize_manifest()`.
#' @param bands A `character` vector with the requested bands (used for the multi-band layout).
#' @param target A `list` from `.materialize_target()`.
#' @param overwrite Logical. Re-write files that already exist.
#' @param progress Logical. Show a progress bar.
#' @param multicores An `integer` with the number of parallel workers.
#'
#' @return The `manifest` (invisible).
#'
#' @noRd
.materialize_write <- function(manifest, bands, target, overwrite, progress,
                               multicores) {
  # band indices for the multi-band layout
  idx_all <- .export_band_index(bands)

  # keep only the rows that still need writing
  todo <- manifest

  if (!overwrite) {
    todo <- manifest[!fs::file_exists(manifest$path), ]
  }

  # nothing to do
  if (nrow(todo) == 0L) {
    return(invisible(manifest))
  }

  # write one row per output file
  .parallel_pwalk(
    .l = list(
      vsicurl = todo$vsicurl,
      path = todo$path,
      band = todo$band
    ),
    .f = function(vsicurl, path, band) {
      .materialize_write_row(
        vsicurl = vsicurl,
        path = path,
        band = band,
        idx_all = idx_all,
        target = target
      )
    },
    multicores = multicores,
    progress = progress,
    label = "Materialising AlphaEarth tiles"
  )

  invisible(manifest)
}
