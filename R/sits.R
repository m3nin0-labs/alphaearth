#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Prepare AlphaEarth tiles as a local sits cube
#'
#' @description Backend for `as_cube`. Turns the result of
#' [search()] into a local data cube ready for the `sits` package. For each
#' selected tile, one single-band VRT per requested band is written into
#' `output_dir`.
#'
#' @param x An `sf` object returned by [search()].
#' @param output_dir Directory where the cube vrt files are written (created if needed).
#' @param bands Character vector of bands to write, from `A00` to `A63` (Defaults to all 64 bands).
#' @param roi Optional region of interest used to crop each tile. Defaults to `NULL` (full tiles).
#' @param ... Extra arguments passed to `sits::sits_cube()` (e.g.`multicores`, `progress`).
#'
#' @return The `sits` cube returned by `sits::sits_cube()`.
#'
#' @noRd
.as_sits <- function(x, output_dir, bands = NULL, roi = NULL, ...) {
  # pre-condition: sits must be installed
  .check_package(
    pkg = "sits",
    reason = "needed to build the data cube"
  )

  # validate output dir
  .check_output_dir(output_dir)

  # prepare bands
  bands <- .export_prepare_bands(bands)

  # if ROI is defined, normalise it's representation
  if (!is.null(roi)) {
    roi <- .search_roi_bbox(roi)
  }

  # create the output directory
  output_dir <- fs::dir_create(fs::path_abs(output_dir))

  # optional crop window (EPSG:4326), shared by every tile
  projwin <- .gdal_projwin(roi)

  # write the per-band vrt files (one tile at a time)
  file_info <- list(
    tile = x$tile,
    vsicurl = x$vsicurl,
    date = x$date
  )

  # write the per-band vrt files
  purrr::pwalk(file_info, function(tile, vsicurl, date) {
    # define missing bands
    missing <- .as_sits_missing_bands(tile, date, bands, output_dir)

    # if there are no missing bands, skip
    if (length(missing) == 0L) {
      return(invisible(NULL))
    }

    # write one single-band vrt per missing band (sits-friendly format)
    .as_sits_write_band_vrts(
      src = vsicurl,
      tile = tile,
      date = date,
      bands = missing,
      output_dir = output_dir,
      options = projwin
    )
  })

  # register sits configuration
  .as_sits_register_config()

  # build and return the sits cube
  sits::sits_cube(
    source = .config_source(),
    collection = .config_collection(),
    data_dir = output_dir,
    bands = bands,
    parse_info = .config_parse_info(),
    ...
  )
}

#' Find band VRTs that still need to be written.
#'
#' @description Return the subset of `bands` whose single-band VRT file does not
#' yet exist in `output_dir`.
#'
#' @param tile An `character` vector with the tile name.
#' @param date An `Date` with the date.
#' @param bands An `character` vector with the requested bands.
#' @param output_dir A `character` with the directory where the cube files are written.
#'
#' @return An `character` vector with the bands still missing on disk.
#'
#' @noRd
.as_sits_missing_bands <- function(tile, date, bands, output_dir) {
  # candidate VRT path for each requested band
  paths <- fs::path(output_dir, .as_sits_filename(tile, bands, date))

  # keep the bands whose VRT is still missing on disk
  bands[paths %in% .export_missing(paths)]
}

#' Write band VRT files.
#'
#' @description Write one single-band VRT per requested band, each 
#' corresponding the band of the embedding COG.
#'
#' @param src A `character` with the streamable `/vsicurl/` URL of the COG.
#' @param tile An `character` vector with the tile name.
#' @param date An `Date` with the date.
#' @param bands An `character` vector with the requested bands.
#' @param output_dir A `character` with the directory where the cube files are written.
#' @param options A `character` vector with extra `gdal_translate` options
#'                (e.g., an ROI `-projwin`).
#'
#' @return Invisible `NULL`, called for its side effects.
#'
#' @noRd
.as_sits_write_band_vrts <- function(src, tile, date, bands, output_dir,
                                     options = character()) {
  # write vrt
  purrr::walk(bands, function(band) {
    # get the index of the band
    idx <- .export_band_index(band)

    # define file
    file <- fs::path(output_dir, .as_sits_filename(tile, band, date))

    # write the single-band VRT
    .gdal_band_dataset(
      src     = src,
      idx     = idx,
      dst     = file,
      driver  = "VRT",
      options = options
    )
  })
}

#' Define sits filename.
#'
#' @description Define the filename for a band VRT file.
#'
#' @param tile An `character` vector with the tile name.
#' @param band An `character` vector with the band name.
#' @param date An `Date` with the date.
#'
#' @return A `character` with the filename.
#' @noRd
.as_sits_filename <- function(tile, band, date) {
  glue::glue(
    "{.config_source()}_{.config_collection()}_{tile}_{band}_{format(date)}.vrt"
  )
}

#' Register the AlphaEarth in sits.
#'
#' @description Register AlphaEarth in sits configuration.
#'
#' @noRd
.as_sits_register_config <- function() {
  sits::sits_config(config_user_file = .config_sits_yaml())
}
