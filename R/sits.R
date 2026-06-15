#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Prepare AlphaEarth tiles as a local sits cube
#'
#' @description Turns the result of [search()] into a local data cube usable
#' by the `sits` package. For each selected tile the corrected.
#'
#' @param x An `sf` object returned by [search()], with at least the `tile`,
#'        `vrt_url` and `date` columns.
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

  # write the vrt files
  file_info <- list(
    tile = x$tile,
    vrt_url = x$vrt_url,
    date = x$date
  )

  purrr::pwalk(file_info, function(tile, vrt_url, date) {
    # only the bands not yet written need to be regenerated
    missing <- .as_sits_missing_bands(tile, date, bands, output_dir)

    # nothing to do. Just reuse the existing vrt
    if (length(missing) == 0L) {
      return(invisible(NULL))
    }

    # fetch the vrt
    vrt <- .as_sits_fetch_vrt(vrt_url)

    # write vrt
    .as_sits_write_band_vrts(
      vrt = vrt,
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

#' Download vrt file.
#'
#' @description Download vrt file and rewrite its source to a streamable /vsicurl location.
#'
#' @param vrt_url Character vector with the URL of the warped VRT.
#'
#' @return Character vector with the corrected VRT as text.
#'
#' @noRd
.as_sits_fetch_vrt <- function(vrt_url) {
  # download the vrt file
  doc <- xml2::read_xml(vrt_url)

  # rewrite the source
  doc <- .as_sits_rewrite_source(doc)

  # return!
  as.character(doc)
}

#' Rewrite source dataset to a http streamable location.
#'
#' @description Rewrite every <SourceDataset> from /vsis3 to a streamable /vsicurl location.
#'
#' @param doc XML document with the VRT.
#'
#' @return XML document with the corrected VRT.
#'
#' @noRd
.as_sits_rewrite_source <- function(doc) {
  # find the source dataset nodes
  nodes <- xml2::xml_find_all(doc, ".//SourceDataset")

  # rewrite the source dataset nodes (update in-place)
  purrr::walk(nodes, function(node) {
    xml2::xml_text(node) <- .config_vsicurl_from_vsis3(xml2::xml_text(node))
  })

  # return!
  invisible(doc)
}

#' Find band VRTs that still need to be written.
#'
#' @description Return the subset of `bands` whose single-band VRT file does not
#' yet exist in `output_dir`. Lets [as_sits()] skip tiles already prepared,
#' which avoids re-fetching VRTs over the network when iterating or processing
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
#' @description Write one self-contained single-band warped VRT per requested band.
#'
#' @param vrt An `character` vector with the VRT as text.
#' @param tile An `character` vector with the tile name.
#' @param date An `Date` with the date.
#' @param bands An `character` vector with the requested bands.
#' @param output_dir A `character` with the directory where the cube files are written.
#'
#' @return Invisible NULL.
#'
#' @noRd
.as_sits_write_band_vrts <- function(vrt, tile, date, bands, output_dir) {
  # get all bands
  all_bands <- .config_bands()

  # write the band VRT files
  purrr::walk(bands, function(band) {
    # get the index of the band
    idx <- match(band, all_bands)

    # build the band VRT
    doc <- .as_sits_band_vrt(vrt, idx)

    # write the band VRT file
    file <- fs::path(output_dir, .as_sits_filename(tile, band, date))

    # write the band VRT file
    xml2::write_xml(doc, file)
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

#' Mutate VRT to a single band VRT.
#'
#' @description Select a single band from a multi-band VRT and rewrite it as a
#' single-band VRT object.
#'
#' @param vrt An `character` vector with the VRT as text.
#' @param idx An `integer` with the index of the source band.
#'
#' @return An `XMLDocument` with the single-band VRT.
#'
#' @noRd
.as_sits_band_vrt <- function(vrt, idx) {
  # read the VRT
  doc <- xml2::read_xml(vrt)

  # find the raster bands
  raster_bands <- xml2::xml_find_all(doc, "/VRTDataset/VRTRasterBand")

  # walk through the raster bands (update in-place)
  purrr::iwalk(raster_bands, function(node, i) {
    # remove the band if it's not the source band
    if (i != idx) {
      xml2::xml_remove(node)
    }
  })

  # get the first band
  kept_band <- xml2::xml_find_first(doc, "/VRTDataset/VRTRasterBand")

  # set the band number
  xml2::xml_attr(kept_band, "band") <- "1"

  # find the warp band list
  mappings <- xml2::xml_find_all(doc, ".//GDALWarpOptions/BandList/BandMapping")

  # walk through the warp band list (update in-place)
  purrr::walk(mappings, function(node) {
    # if it is the source band, set the destination band to 1
    if (xml2::xml_attr(node, "src") == as.character(idx)) {
      xml2::xml_attr(node, "dst") <- "1"
    }

    # otherwise, remove the band
    else {
      xml2::xml_remove(node)
    }
  })

  # return!
  doc
}

#' Register the AlphaEarth in sits.
#'
#' @description Register AlphaEarth in sits configuration.
#'
#' @noRd
.as_sits_register_config <- function() {
  sits::sits_config(config_user_file = .config_sits_yaml())
}
