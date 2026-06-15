#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Search AlphaEarth tiles
#'
#' @description Queries the local index built by [index()] and returns the matching tiles.
#'
#' @param roi object with the spatial region of interest (more information below).
#' @param start_date character with the start date of the temporal filter (more information below).
#' @param end_date character with the end date of the temporal filter (more information below).
#' @param fid Integer vector of feature ids to select directly.
#'
#' @return An `sf` object (with class `alphaearth_tiles`) with one row per
#'   tile, including `fid`, `tile`, `year`, `date`, `crs`, `utm_zone`, the
#'   `tiff_url`/`vrt_url` of the tile, its WGS84 bounds and a `geom` (`sfc`)
#'   column.
#'
#' @seealso [index()], [as_sits()]
#'
#' @note
#' The `roi` argument accepts the following types of objects:
#'
#' - an `sf`/`sfc` object,
#' - an `sf` `bbox`,
#' - a named numeric vector `c(xmin, ymin, xmax, ymax)` in EPSG:4326,
#' - a `terra` `SpatRaster`/`SpatVector` (its extent is used).
#'
#' Any CRS is accepted and reprojected to EPSG:4326.
#'
#' @note
#' The `date` argument accepts the following formats:
#' - "YYYY" (e.g. "2020"),
#' - "YYYY-MM-DD" (e.g. "2020-01-01").
#'
#' @examples
#' \dontrun{
#' alphaearth::search(
#'   roi = c(xmin = -47.9, ymin = -15.9, xmax = -47.8, ymax = -15.8),
#'   start_date = "2020", end_date = "2020"
#' )
#' }
#' @export
search <- function(roi = NULL, start_date = NULL, end_date = NULL, fid = NULL) {
  # open the database
  con <- .search_con()

  # side-effect: stop the connection on exit
  on.exit(duckspatial::ddbs_stop_conn(con), add = TRUE)

  # build the search predicates
  predicates <- .search_predicates(
    con = con,
    roi = roi,
    start_date = start_date,
    end_date = end_date,
    fid = fid
  )

  # check if there are any predicates
  if (length(predicates) == 0L) {

    # in case of no predicates, abort operation
    cli::cli_abort(c(
      "At least one search filter is required.",
      i = "Pass e.g. {.arg roi}, {.arg start_date}, {.arg end_date} or {.arg fid}."
    ))

  }

  # collect the results
  .search_collect(
    con = con,
    predicates = predicates
  )
}

#' Open the index database
#'
#' @description Open the index database and check if it is empty.
#'
#' @return [DBI::dbConnect()] with the connection to the database.
#'
#' @noRd
.search_con <- function() {
  # check if the database exists
  if (!fs::file_exists(.config_db_path())) {
    # in case of no database, abort operation
    cli::cli_abort(c(
      "No local index found.",
      i = "Run {.run alphaearth::index()} first."
    ))
  }

  # open the database
  con <- .index_con()

  # check if the table exists
  if (!.config_table() %in% DBI::dbListTables(con)) {
    # in case of no table, abort operation
    duckspatial::ddbs_stop_conn(con)

    # inform user
    cli::cli_abort(c(
      "The local index is empty.",
      i = "Run {.run alphaearth::index()} first."
    ))
  }

  # return!
  con
}

#' Assemble the SQL predicates based on all filters.
#'
#' @description Assemble the (non-NULL) SQL predicates based on defined filters properties.
#'
#' @param con [DBI::dbConnect()] with the connection to the database.
#' @param roi object with the spatial region of interest.
#' @param start_date character with the start date of the temporal filter.
#' @param end_date character with the end date of the temporal filter.
#' @param fid Integer vector of feature ids to select directly.
#'
#' @return character with the SQL predicates.
#'
#' @noRd
.search_predicates <- function(con, roi, start_date, end_date, fid) {
  purrr::compact(list(
    .search_roi_sql(con, roi),
    .search_year_sql("year >= %d", start_date),
    .search_year_sql("year <= %d", end_date),
    .search_in_sql(con, "fid", fid, quote = FALSE)
  ))
}

#' SQL predicate for the spatial filter.
#'
#' @description Build the SQL predicate for the spatial filter.
#'
#' @param con [DBI::dbConnect()] with the connection to the database.
#' @param roi object with the spatial region of interest.
#'
#' @return character with the SQL predicate.
#'
#' @noRd
.search_roi_sql <- function(con, roi) {
  # pre-condition: roi can't be NULL
  if (is.null(roi)) {
    return(NULL)
  }

  # build the WKT from the ROI
  wkt <- sf::st_as_text(sf::st_as_sfc(.search_roi_bbox(roi)))

  # build the SQL predicate
  glue::glue(
    "ST_Intersects(geom, ST_GeomFromText({DBI::dbQuoteString(con, wkt)}))"
  )
}

#' Normalize ROI object to an EPSG:4326 bbox.
#'
#' @description Normalize any supported ROI object to an EPSG:4326 bbox.
#'
#' @param roi object with the spatial region of interest.
#'
#' @return [sf::st_bbox()] with the bounding box in EPSG:4326.
#'
#' @note
#' The `roi` argument accepts the following types of objects:
#' - an `sf`/`sfc` object,
#' - an `sf` `bbox`,
#' - a named numeric vector `c(xmin, ymin, xmax, ymax)` in EPSG:4326,
#' - a `terra` `SpatRaster`/`SpatVector` (its extent is used).
#'
#' Any CRS is accepted and reprojected to EPSG:4326.
#'
#' @noRd
.search_roi_bbox <- function(roi) {
  bbox <-
    # case 1: sf bbox
    if (inherits(roi, "bbox")) {
      roi

    # case 2: sf object
    } else if (inherits(roi, c("sf", "sfc"))) {
      sf::st_bbox(roi)

    # case 3: terra object
    } else if (inherits(roi, c("SpatRaster", "SpatVector"))) {
      .search_terra_bbox(roi)

    # case 4: named numeric vector
    } else if (is.numeric(roi)) {
      .search_numeric_bbox(roi)

    # case 5: unsupported object
    } else {
      cli::cli_abort("Unsupported {.arg roi} of class {.cls {class(roi)}}.")
    }

  # normalize the bbox to EPSG:4326
  .search_to_4326(bbox)
}

#' Convert a named numeric vector to an EPSG:4326 bbox.
#'
#' @description Convert a named numeric vector to an EPSG:4326 bbox.
#'
#' @param roi named numeric vector with the spatial region of interest.
#'
#' @return [sf::st_bbox()] with the bounding box in EPSG:4326.
#'
#' @noRd
.search_numeric_bbox <- function(roi) {
  # pre-condition: roi must be named
  nms <- c("xmin", "ymin", "xmax", "ymax")

  # check if the names are correct
  if (!all(nms %in% names(roi))) {
    cli::cli_abort(
      "Numeric {.arg roi} must be named {.field {nms}} (in EPSG:4326)."
    )
  }

  # convert the named numeric vector to an EPSG:4326 bbox
  sf::st_bbox(
    obj = roi[nms],
    crs = sf::st_crs(4326)
  )
}

#' Convert a terra object to an EPSG:4326 bbox.
#'
#' @description Convert a terra object to an EPSG:4326 bbox.
#'
#' @param roi terra object with the spatial region of interest.
#'
#' @return [sf::st_bbox()] with the bounding box in EPSG:4326.
#'
#' @noRd
.search_terra_bbox <- function(roi) {
  # check package availability
  .utils_check_package(
    pkg = "terra",
    reason = "needed to use a terra object as {.arg roi}"
  )

  # project the extent to EPSG:4326
  ext <- terra::ext(roi)
  ext <- terra::project(
    x = ext,
    from = terra::crs(roi),
    to = "EPSG:4326"
  )

  # convert the extent to an EPSG:4326 bbox
  bbox <- c(
    xmin = ext$xmin,
    ymin = ext$ymin,
    xmax = ext$xmax,
    ymax = ext$ymax
  )

  # transform and return!
  sf::st_bbox(
    obj = bbox,
    crs = sf::st_crs(4326)
  )
}

#' Ensure a bbox is expressed in EPSG:4326.
#'
#' @description Ensure a bbox is expressed in EPSG:4326.
#'
#' @param bbox [sf::st_bbox()] with the bounding box.
#'
#' @return [sf::st_bbox()] with the bounding box in EPSG:4326.
#'
#' @noRd
.search_to_4326 <- function(bbox) {
  # check if the bbox has a CRS
  crs <- sf::st_crs(bbox)

  # if the bbox has no CRS, warn and return the bbox in EPSG:4326
  if (is.na(crs)) {
    cli::cli_warn("{.arg roi} has no CRS; assuming EPSG:4326.")

    return(
      sf::st_bbox(
        obj = bbox,
        crs = sf::st_crs(4326)
      )
    )
  }

  # if the bbox is already in EPSG:4326, return it
  if (crs == sf::st_crs(4326)) {
    return(bbox)
  }

  # transform the bbox to EPSG:4326 and return!
  sf::st_bbox(
    sf::st_transform(
      x = sf::st_as_sfc(bbox),
      crs = 4326
    )
  )
}

#' SQL predicate for the temporal filter.
#'
#' @description Build the SQL predicate for the temporal filter.
#'
#' @param template character with the SQL template.
#' @param date character with the date (either "YYYY" or "YYYY-MM-DD").
#'
#' @return character with the SQL predicate.
#'
#' @note
#' The `date` argument accepts the following formats:
#' - "YYYY" (e.g. "2020"),
#' - "YYYY-MM-DD" (e.g. "2020-01-01").
#'
#' @noRd
.search_year_sql <- function(template, date) {
  # pre-condition: date can't be NULL
  if (is.null(date)) {
    return(NULL)
  }

  # build the SQL predicate
  sprintf(
    template, as.integer(substr(as.character(date), 1L, 4L))
  )
}

#' SQL predicate for the attribute filter.
#'
#' @description Build the SQL predicate for the attribute filter.
#'
#' @param con [DBI::dbConnect()] with the connection to the database.
#' @param column character with the column name.
#' @param values vector with the values to filter.
#' @param quote logical with whether to quote the values.
#'
#' @return character with the SQL predicate.
#'
#' @noRd
.search_in_sql <- function(con, column, values, quote = TRUE) {
  # pre-condition: values can't be NULL
  if (is.null(values)) {
    return(NULL)
  }

  # define the values to filter
  vals <- if (quote) {
    DBI::dbQuoteString(con, as.character(values))
  } else {
    as.character(as.integer(values))
  }

  # build the SQL predicate
  glue::glue("{column} IN ({paste(vals, collapse = ', ')})")
}

#' Execute the SQL predicates in a database.
#'
#' @description Execute the query and shape the result into an `alphaearth_tiles` tibble.
#'
#' @param con [DBI::dbConnect()] with the connection to the database.
#' @param predicates character with the SQL predicates.
#'
#' @return [tibble::tibble()] with the result.
#'
#' @noRd
.search_collect <- function(con, predicates) {
  # build the WHERE clause
  where <- paste(predicates, collapse = " AND ")

  # build the sql query
  sql <- glue::glue(
    "SELECT fid, path, year, utm_zone, crs, ",
    "wgs84_west, wgs84_south, wgs84_east, wgs84_north, ",
    "ST_AsText(geom) AS wkt ",
    "FROM {.config_table()} WHERE {where} ORDER BY year, fid"
  )

  # query and return!
  .search_as_tiles(
    df = DBI::dbGetQuery(con, sql)
  )
}

#' Spatial tile id.
#'
#' @description Derive the spatial tile identity from the UTM zone and the COG's
#' grid offset. AlphaEarth filenames are `<earth-engine-image-id>-<offsetY>-<offsetX>`,
#' where the image id changes every year but the UTM zone and (Y, X) offset
#' describe a fixed ground footprint.
#'
#' @param path character vector with the COG `path` stored in the index.
#' @param utm_zone character vector with the tile UTM zone (e.g. `"19S"`).
#'
#' @return character vector with the tile id.
#'
#' @noRd
.search_tile_id <- function(path, utm_zone) {
  # get filename
  base <- fs::path_ext_remove(fs::path_file(path))

  # get grid offset
  offset <- sub("^.*?-(\\d+-\\d+)$", "\\1", base)

  # concat utm + offset
  paste(utm_zone, offset, sep = "-")
}

#' Build a result `sf` object from raw rows.
#'
#' @description Build the result as an `sf` object.
#'
#' @param df [data.frame()] with the raw rows.
#'
#' @return [sf::st_sf()] with the result.
#'
#' @noRd
.search_as_tiles <- function(df) {
  # pre-condition: df can't be empty
  if (nrow(df) == 0L) {
    cli::cli_warn("No AlphaEarth tiles matched the search.")
  }

  # build the geometry column
  geom <- if (nrow(df) > 0L) {
    sf::st_as_sfc(df$wkt, crs = 4326)
  } else {
    sf::st_sfc(crs = 4326)
  }

  # build the tiff_url column
  tiff_url <- .config_http_from_s3(df$path)

  # build the attribute table
  out <- tibble::tibble(
    fid      = as.integer(df$fid),
    tile     = .search_tile_id(df$path, df$utm_zone),
    year     = as.integer(df$year),
    date     = as.Date(sprintf("%d-01-01", df$year)),
    crs      = df$crs,
    utm_zone = df$utm_zone,
    tiff_url = tiff_url,
    vrt_url  = .config_vrt_url(tiff_url),
    xmin     = df$wgs84_west,
    ymin     = df$wgs84_south,
    xmax     = df$wgs84_east,
    ymax     = df$wgs84_north,
    geom     = geom
  )

  # promote to an sf object and tag it
  out <- sf::st_as_sf(out, sf_column_name = "geom")

  # return!
  structure(
    out, class = c("alphaearth_tiles", class(out))
  )
}
