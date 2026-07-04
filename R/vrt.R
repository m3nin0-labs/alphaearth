#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Write AlphaEarth tiles as virtual rasters (VRT)
#'
#' @description Materialises the selected tiles as lightweight GDAL VRT files
#' that point at the remote COGs (via `/vsicurl/`). Two on-disk formats
#' are supported for VRTs:
#'
#' - `"stack"`: one multi-band VRT per tile, referencing every requested band
#'   (`ae_<tile>_<year>.vrt`);
#' - `"bands"`: one single-band VRT per band (`ae_<tile>_<band>_<year>.vrt`).
#'
#' Each tile keeps its native UTM CRS (no reprojection). Existing files are reused
#' unless `overwrite = TRUE`.
#'
#' @param x An `sf` object returned by [search()].
#' @param output_dir Directory where the VRTs are written (created if needed).
#' @param bands Character vector of embedding bands to reference, from `A00` to
#'              `A63` (defaults to all 64 bands).
#' @param roi Optional region of interest used to crop each tile. Defaults to `NULL` (full tiles).
#' @param layout One of `"stack"` (one multi-band VRT per tile) or `"bands"` (one VRT per band).
#' @param overwrite Logical. Re-write files that already exist. Defaults to `FALSE`.
#' @param progress Logical. Show a progress bar. Defaults to `TRUE`.
#' @param multicores Integer. Number of parallel workers used to write the files.
#'                   Defaults to `1` (sequential). Values above `1` write tiles concurrently.
#'
#' @return A `tibble` (invisible) with one row per written file.
#'
#' @seealso [search()], [download()], [as_cube()]
#'
#' @examples
#' \dontrun{
#'   tiles <- alphaearth::search(
#'     roi = my_roi,
#'     start_date = "2020",
#'     end_date   = "2020"
#'   )
#'
#'   # one multi-band VRT per tile
#'   vrts <- alphaearth::as_vrt(tiles, output_dir = "embeddings")
#'
#'   # one VRT per embedding dimension
#'   vrts <- alphaearth::as_vrt(
#'     x = tiles,
#'     output_dir = "embeddings",
#'     bands = c("A00", "A01"),
#'     layout = "bands"
#'   )
#' }
#' @export
as_vrt <- function(x, output_dir, bands = NULL, roi = NULL,
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
    x          = x,
    output_dir = output_dir,
    bands      = bands,
    roi        = roi,
    layout     = layout,
    overwrite  = overwrite,
    progress   = progress,
    multicores = multicores,
    kind       = "vrt"
  )
}
