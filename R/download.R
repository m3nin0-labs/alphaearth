#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Download AlphaEarth tiles as local GeoTIFFs
#'
#' @description Materialises the selected tiles into local GeoTIFFs, and 
#' (optionally) cropping them to a region of interest. 
#' 
#' Two on-disk layouts are supported:
#'
#' - `"stack"`: one multi-band GeoTIFF per tile, holding every requested
#'   embedding dimension (`ae_<tile>_<year>.tif`);
#' - `"bands"`: one single-band GeoTIFF per embedding dimension
#'   (`ae_<tile>_<band>_<year>.tif`).
#'
#' Each tile keeps its native UTM CRS (no reprojection). Existing files are
#' reused unless `overwrite = TRUE`.
#'
#' @param x An `sf` object returned by [search()].
#' @param output_dir Directory where the GeoTIFFs are written (created if needed).
#' @param bands Character vector of embedding bands to download, from `A00` to
#'              `A63` (defaults to all 64 bands).
#' @param roi Optional region of interest used to crop each tile (any object
#'            accepted by [search()]). Defaults to `NULL` (full tiles).
#' @param layout One of `"stack"` (one multi-band file per tile) or `"bands"`
#'              (one file per embedding dimension).
#' @param overwrite Logical. Re-write files that already exist. Defaults to `FALSE`.
#' @param progress Logical. Show a progress bar. Defaults to `TRUE`.
#' @param multicores Integer. Number of parallel workers used to write the files.
#'                            Defaults to `1` (sequential); values above `1` download 
#'                            tiles concurrently.
#'
#' @return A `tibble` (invisible) with one row per written file.
#'
#' @seealso [search()], [as_vrt()], [as_cube()]
#'
#' @examples
#' \dontrun{
#'   tiles <- alphaearth::search(
#'     roi = my_roi,
#'     start_date = "2020",
#'     end_date   = "2020"
#'   )
#'
#'   # one multi-band GeoTIFF per tile, cropped to a ROI
#'   files <- alphaearth::download(
#'     x = tiles,
#'     output_dir = "embeddings",
#'     roi = c(
#'       xmin = -47.9,
#'       ymin = -15.9,
#'       xmax = -47.85,
#'       ymax = -15.85
#'     )
#'   )
#'
#'   # one file per embedding dimension
#'   files <- alphaearth::download(
#'     x = tiles,
#'     output_dir = "embeddings",
#'     bands = c("A00", "A01"),
#'     layout = "bands"
#'   )
#' }
#' @export
download <- function(x, output_dir, bands = NULL, roi = NULL,
                     layout = c("stack", "bands"),
                     overwrite = FALSE, progress = TRUE, multicores = 1L) {
  # pre-condition: tibble must have the required columns
  .check_tiles(x, c("tile", "year", "vsicurl"))
  # pre-condition: output directory must be valid
  .check_output_dir(output_dir)
  # pre-condition: multicores must be valid
  .check_multicores(multicores)
  
  # validate the layout and bands
  layout <- match.arg(layout)
  
  # prepare the bands
  bands <- .export_prepare_bands(bands)
  
  # if ROI is defined, normalise it's representation
  if (!is.null(roi)) {
    roi <- .search_roi_bbox(roi)
  }

  # write the files to disk
  .materialize(
    x = x,
    output_dir = output_dir,
    bands = bands,
    roi = roi,
    layout = layout,
    overwrite = overwrite,
    progress = progress,
    multicores = multicores,
    kind = "gtiff"
  )
}
