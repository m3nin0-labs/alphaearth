#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Export AlphaEarth tiles to a data cube format.
#'
#' @description Turns the result of [search()] into a data cube.
#'
#' @param x An `sf` object returned by [search()].
#' @param to Character naming the target backend, either `"sits"` or `"stars"`.
#' @param ... Extra arguments forwarded to the selected backend (see Details).
#'
#' @details
#' The backends accept the following arguments through `...`:
#'
#' - `"sits"`: `output_dir` (directory for the per-band VRTs), `bands` (embedding
#'   bands, `A00`-`A63`, defaults to all 64), `roi` (optional crop, any object
#'   accepted by [search()]), and any further argument passed on to
#'   `sits::sits_cube()` (e.g. `multicores`, `progress`). Returns a `sits` cube.
#' - `"stars"`: `output_dir` (directory for the intermediate VRTs, defaults to a
#'   temporary directory), `bands`, `roi`, `proxy` (read lazily as a
#'   `stars_proxy`, defaults to `TRUE`), and any further argument passed on to
#'   [stars::read_stars()]. Returns one `stars` object for a single tile, or a
#'   named list of `stars` objects keyed by tile id.
#'
#' @note To materialise the tiles as GeoTIFFs on disk instead, use [download()].
#'
#' @return The object produced by the selected format.
#'
#' @seealso [search()], [download()]
#'
#' @examples
#' \dontrun{
#'   tiles <- alphaearth::search(
#'     roi = my_roi,
#'     start_date = "2020",
#'     end_date = "2021"
#'   )
#'
#'   # read the tiles as a stars cube
#'   cube <- alphaearth::as_cube(
#'     x = tiles,
#'     to = "stars",
#'     bands = c("A00", "A01")
#'   )
#'
#'   # read the tiles as a sits cube
#'   cube <- alphaearth::as_cube(
#'     x = tiles,
#'     to = "sits",
#'     bands = c("A00", "A01")
#'   )
#' }
#' @export
as_cube <- function(x, to = c("sits", "stars"), ...) {
  UseMethod("as_cube")
}

#' @rdname as_cube
#' @export
as_cube.sf <- function(x, to = c("sits", "stars"), ...) {
  # get registry
  registry <- .export_registry()

  # pre-condition: backend must be valid
  backend <- match.arg(to, names(registry))

  # pre-condition: tiles must have the required columns
  .check_tiles(x, c("tile", "vsicurl"))

  # dispatch to the selected backend
  registry[[backend]](x, ...)
}

#' Registry of available exporters.
#'
#' @description Map a backend name to its function.
#'
#' @return A named list of functions.
#'
#' @noRd
.export_registry <- function() {
  list(
    sits  = .as_sits,
    stars = .as_stars
  )
}

#' Prepare requested bands.
#'
#' @description Prepare the requested embedding bands: default to all 64 when
#' `NULL`, upper-case them, and validate that each is a known band.
#'
#' @param bands Character vector of embedding bands, or `NULL` for all 64.
#'
#' @return Character vector of embedding bands (defaults to all 64 bands).
#'
#' @noRd
.export_prepare_bands <- function(bands) {
  # if bands is NULL, return default bands
  all_bands <- .config_bands()

  if (is.null(bands)) {
    return(all_bands)
  }

  # convert the bands to uppercase
  bands <- toupper(bands)

  # check if the bands are valid
  bands_invalid <- setdiff(bands, all_bands)

  # if the bands are invalid, abort operation
  if (length(bands_invalid) > 0L) {
    cli::cli_abort(
      "Unknown band{?s}: {.val {bands_invalid}}. Bands range from A00 to A63."
    )
  }

  # return
  bands
}

#' Map band names to their source band index.
#'
#' @description Translate embedding band names into their 1-based band index in
#' the source COG (e.g., `A00 -> 1`, ..., `A63 -> 64`).
#'
#' @param band Character vector with the band names.
#'
#' @return Integer vector with the source band indices.
#'
#' @noRd
.export_band_index <- function(band) {
  match(band, .config_bands())
}

#' Find output files that still need to be written.
#'
#' @description Return the subset of `paths` that do not yet exist on disk.
#'
#' @param paths character vector with the candidate output paths.
#'
#' @return character vector with the paths still missing on disk.
#'
#' @noRd
.export_missing <- function(paths) {
  purrr::discard(paths, fs::file_exists)
}
