#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' GDAL `-projwin` options for a bbox.
#'
#' @description Build the `gdal_translate` `-projwin` arguments. The window is 
#' expressed in EPSG:4326 (via `-projwin_srs`).
#'
#' @param bbox [sf::st_bbox()] (EPSG:4326) with the crop window, or `NULL` for no crop.
#'
#' @return character vector with the `-projwin` options, or `NULL` when
#'   `bbox` is `NULL`.
#'
#' @noRd
.gdal_projwin <- function(bbox) {
  # no bbox -> no crop
  if (is.null(bbox)) {
    return(NULL)
  }

  # -projwin is <ulx> <uly> <lrx> <lry>, i.e. xmin ymax xmax ymin
  c(
    "-projwin",
    format(bbox[["xmin"]], scientific = FALSE),
    format(bbox[["ymax"]], scientific = FALSE),
    format(bbox[["xmax"]], scientific = FALSE),
    format(bbox[["ymin"]], scientific = FALSE),
    "-projwin_srs", "EPSG:4326"
  )
}

#' Write a single-band GDAL dataset.
#'
#' @description Select a single band from a source raster and write it with the
#' requested GDAL driver.
#'
#' @param src A `character` with the source dataset (e.g., a `/vsicurl/` URL).
#' @param idx An `integer` with the 1-based source band index.
#' @param dst A `character` with the destination path.
#' @param driver A `character` with the GDAL output driver (e.g., `"VRT"`, `"GTiff"`).
#' @param options A `character` vector with extra `gdal_translate` options
#'                (i.e., creation options, `-projwin`, ...).
#'
#' @return The destination path (invisible).
#'
#' @noRd
.gdal_band_dataset <- function(src, idx, dst, driver, options = character()) {
  .gdal_translate(
    src     = src,
    dst     = dst,
    options = c(
      "-of",
      driver,
      "-b", 
      as.character(idx), 
      options
    )
  )
}

#' Write a (multi-band) GDAL dataset from a COG.
#'
#' @description Write one dataset that keeps several bands together, with the
#' requested GDAL `driver`. When `idx` is `NULL` all source bands are kept;
#' otherwise only the listed bands are selected, in the given order.
#'
#' @param src A `character` with the source dataset (e.g., a `/vsicurl/` URL).
#' @param dst A `character` with the destination path.
#' @param driver A `character` with the GDAL output driver (e.g., `"VRT"`, `"GTiff"`).
#' @param idx An `integer` vector with the 1-based source band indices, or `NULL`
#'            to keep all bands.
#' @param options A `character` vector with extra `gdal_translate` options
#'                (i.e., creation options, `-projwin`, ...).
#'
#' @return The destination path (invisible).
#'
#' @noRd
.gdal_stack_dataset <- function(src, dst, driver, idx = NULL, options = character()) {
  # one "-b <i>" pair per requested band (empty keeps all bands)
  band_opts <- character()

  if (!is.null(idx)) {
    band_opts <- as.character(rbind("-b", as.character(idx)))
  }

  .gdal_translate(
    src = src,
    dst = dst,
    options = c("-of", driver, band_opts, options)
  )
}

#' Run `gdal_translate`.
#'
#' @description Wrapper around `gdal_translate`.
#'
#' @param src A `character` with the source dataset.
#' @param dst A `character` with the destination path.
#' @param options A `character` vector with the `gdal_translate` options.
#'
#' @return The destination `dst`, invisibly.
#'
#' @noRd
.gdal_translate <- function(src, dst, options) {
  sf::gdal_utils(
    util        = "translate",
    source      = src,
    destination = dst,
    options     = options,
    quiet       = TRUE
  )

  # return!
  invisible(dst)
}
