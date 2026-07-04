#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Read AlphaEarth tiles as `stars` objects
#'
#' @description Backend for `as_cube`. Turns the result of [search()] into 
#' `stars` objects. For each selected tile a single multi-band VRT is written into
#' `output_dir`, and then read with [stars::read_stars()]. The `band` dimension
#' is labelled with the requested bands.
#'
#' @param x An `sf` object returned by [search()].
#' @param output_dir Directory where the intermediate VRT files are written (created if needed).
#' @param bands Character vector of embedding bands to read, from `A00` to `A63`
#'              (defaults to all 64 bands).
#' @param roi Optional region of interest used to crop each tile. Defaults to `NULL` (full tiles).
#' @param proxy Logical. Read lazily as a `stars_proxy`. Defaults to `TRUE` (lazy).
#' @param ... Extra arguments passed to [stars::read_stars()].
#'
#' @return A single `stars` object when `x` has one tile, otherwise a named list
#'         of `stars` objects keyed by tile.
#'
#' @noRd
.as_stars <- function(x, output_dir = tempdir(), bands = NULL, roi = NULL,
                      proxy = TRUE, ...) {
  # pre-condition: stars must be available
  .check_package(
    pkg = "stars",
    reason = "needed to read the tiles as stars objects"
  )

  # validate output dir
  .check_output_dir(output_dir)

  # prepare bands
  bands <- .export_prepare_bands(bands)

  # define band indices
  idx <- .export_band_index(bands)

  # if ROI is defined, normalise it's representation
  if (!is.null(roi)) {
    roi <- .search_roi_bbox(roi)
  }

  # create output dir
  output_dir <- fs::dir_create(fs::path_abs(output_dir))

  # define crop window
  projwin <- .gdal_projwin(roi)

  # tasks: read one stars object per tile
  file_info <- list(
    tile = x$tile,
    vsicurl = x$vsicurl,
    year = x$year
  )

  # execute tasks
  cubes <- purrr::pmap(file_info, function(tile, vsicurl, year) {
    .as_stars_read_tile(
      src        = vsicurl,
      tile       = tile,
      year       = year,
      bands      = bands,
      idx        = idx,
      output_dir = output_dir,
      options    = projwin,
      proxy      = proxy,
      ...
    )
  })

  # name by tile id
  names(cubes) <- x$tile

  # if there is only one tile, return a bare stars object
  if (length(cubes) == 1L) {
    return(cubes[[1L]])
  }

  # return!
  cubes
}

#' Read a single tile as a `stars` object.
#'
#' @description Write the tile's multi-band VRT (once) and read it as a `stars`
#' object, labelling the `band` dimension with the requested bands.
#'
#' @param src A `character` with the streamable `/vsicurl/` URL.
#' @param tile A `character` with the tile id.
#' @param year An `integer` with the tile year.
#' @param bands A `character` vector with the requested bands.
#' @param idx An `integer` vector with the source band indices for `bands`.
#' @param output_dir A `character` with the directory where the VRT is written.
#' @param options A `character` vector with extra `gdal_translate` options
#'                (e.g., an ROI `-projwin`).
#' @param proxy Logical. Read lazily as a `stars_proxy`.
#' @param ... Extra arguments passed to [stars::read_stars()].
#'
#' @return A `stars` object.
#'
#' @noRd
.as_stars_read_tile <- function(src, tile, year, bands, idx, output_dir,
                                options, proxy, ...) {
  # define destination vrt
  vrt <- fs::path(output_dir, .as_stars_filename(tile, year))

  # write vrt once
  if (length(.export_missing(vrt)) > 0L) {
    .gdal_stack_dataset(
      src     = src,
      dst     = vrt,
      driver  = "VRT",
      idx     = idx,
      options = options
    )
  }

  # read the tile
  cube <- stars::read_stars(vrt, proxy = proxy, ...)

  # label the band dimension with the requested bands
  band_is_present <- "band" %in% names(stars::st_dimensions(cube))

  if (band_is_present) {
    cube <- stars::st_set_dimensions(
      .x = cube,
      which = "band", 
      values = bands
    )
  }

  # return!
  cube
}

#' Define the stars VRT filename for a tile.
#'
#' @description Define the filename of the intermediate multi-band VRT written
#' for one tile.
#'
#' @param tile A `character` with the tile id.
#' @param year An `integer` with the tile year.
#'
#' @return A `character` with the filename.
#'
#' @noRd
.as_stars_filename <- function(tile, year) {
  glue::glue("{.config_download_prefix()}_{tile}_{year}.vrt")
}
