#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Prepare AlphaEarth tiles as a local sits cube
#'
#' @description Turns the result of [search()] into a local data cube usable
#' by the `sits` package. For each selected tile, one single-band VRT per
#' requested band is written into `output_dir`, reading the embedding COG
#' directly over the network (no intermediate download).
#'
#' @param x An `sf` object returned by [search()], with at least the `tile`,
#'        `gdal_url` and `date` columns.
#' @param output_dir Directory where the cube vrt files are written (created if needed).
#' @param bands Character vector of embedding bands to write, from `A00` to `A63` (Defaults to all 64 bands).
#' @param ... Extra arguments passed to `sits::sits_cube()` (e.g.`multicores`, `progress`).
#'
#' @return The `sits` cube returned by `sits::sits_cube()`.
#'
#' @seealso [search()]
#'
#' @examples
#' \dontrun{
#'   # search for tiles
#'   tiles <- alphaearth::search(
#'     roi = my_roi,
#'     start_date = "2020",
#'     end_date   = "2021"
#'   )
#'
#'   # build the data cube
#'   cube <- alphaearth::as_sits(
#'     x = tiles,
#'     output_dir = tempdir(),
#'     multicores = 4,
#'     progress = TRUE
#'   )
#' }
#' @export
as_sits <- function(x, ...) {
  UseMethod("as_sits")
}

#' @rdname as_sits
#' @export
as_sits.sf <- function(x, output_dir, bands = NULL, ...) {
  # pre-condition: sits must be installed
  .utils_check_package(
    pkg = "sits",
    reason = "needed to build the data cube"
  )

  # validate the bands
  bands <- .as_sits_check_bands(bands)

  # create the output directory
  output_dir <- fs::dir_create(fs::path_abs(output_dir))

  # write the per-band vrt files (one tile at a time)
  file_info <- list(
    tile = x$tile,
    gdal_url = x$gdal_url,
    date = x$date
  )

  purrr::pwalk(file_info, function(tile, gdal_url, date) {
    # only the bands not yet written need to be regenerated
    missing <- .as_sits_missing_bands(tile, date, bands, output_dir)

    # nothing to do, just reuse the existing band vrts
    if (length(missing) == 0L) {
      return(invisible(NULL))
    }

    # write one single-band vrt per missing band, reading the COG directly
    .as_sits_write_band_vrts(
      src = gdal_url,
      tile = tile,
      date = date,
      bands = missing,
      output_dir = output_dir
    )
  })

  # register the sits configuration
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

#' Validate requested bands.
#'
#' @description Validate requested bands.
#'
#' @param bands Character vector of embedding bands to write.
#'
#' @return Character vector of embedding bands to write (defaults to all 64 bands).
#'
#' @noRd
.as_sits_check_bands <- function(bands) {
  # if bands is NULL, return default bands
  all_bands <- .config_bands()

  if (is.null(bands)) {
    return(all_bands)
  }

  # convert the bands to uppercase
  bands <- toupper(bands)

  # check if the bands are valid
  bands_valid <- setdiff(bands, all_bands)

  if (length(bands_valid) > 0L) {
    cli::cli_abort(
      "Unknown band{?s}: {.val {bands_valid}}. Bands range from A00 to A63."
    )
  }

  # return the bands
  bands
}

#' Find band VRTs that still need to be written.
#'
#' @description Return the subset of `bands` whose single-band VRT file does not
#' yet exist in `output_dir`. Lets [as_sits()] skip tiles already prepared,
#' which avoids re-building VRTs over the network when iterating or processing
#' large areas.
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
  purrr::discard(bands, function(band) {
    fs::file_exists(
      fs::path(output_dir, .as_sits_filename(tile, band, date))
    )
  })
}

#' Write band VRT files.
#'
#' @description Write one single-band VRT per requested band, each reading the
#' corresponding band of the embedding COG directly over the network.
#'
#' @param src A `character` with the streamable `/vsicurl/` URL of the COG.
#' @param tile An `character` vector with the tile name.
#' @param date An `Date` with the date.
#' @param bands An `character` vector with the requested bands.
#' @param output_dir A `character` with the directory where the cube files are written.
#'
#' @return Invisible NULL.
#'
#' @noRd
.as_sits_write_band_vrts <- function(src, tile, date, bands, output_dir) {
  # get all bands (to map a band name to its source band index)
  all_bands <- .config_bands()

  # write the band VRT files
  purrr::walk(bands, function(band) {
    # get the index of the band (e.g. A00 -> 1, ..., A63 -> 64)
    idx <- match(band, all_bands)

    # destination band VRT file
    file <- fs::path(output_dir, .as_sits_filename(tile, band, date))

    # write the single-band VRT
    .as_sits_band_vrt(src, idx, file)
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

#' Write a single-band VRT for one COG band.
#'
#' @description Select a single band from the embedding COG and write it as a
#' self-contained VRT. The VRT references the COG over `/vsicurl/`, so the
#' raster is read directly (no download) and keeps its native georeferencing.
#'
#' @param src A `character` with the streamable `/vsicurl/` URL of the COG.
#' @param idx An `integer` with the index of the source band.
#' @param file A `character` with the destination VRT path.
#'
#' @return The destination `file`, invisibly.
#'
#' @noRd
.as_sits_band_vrt <- function(src, idx, file) {
  sf::gdal_utils(
    util        = "translate",
    source      = src,
    destination = file,
    options     = c("-of", "VRT", "-b", as.character(idx)),
    quiet       = TRUE
  )

  # return!
  invisible(file)
}

#' Register the AlphaEarth in sits.
#'
#' @description Register AlphaEarth in sits configuration.
#'
#' @noRd
.as_sits_register_config <- function() {
  sits::sits_config(config_user_file = .config_sits_yaml())
}
