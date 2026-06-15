#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Index the AlphaEarth tile catalogue locally
#'
#' Downloads the AlphaEarth Foundations spatial index and loads it into a
#' persistent local DuckDB database so that [search()] runs quickly and smooth.
#' The download and load happen once. Later calls reuse the cached database
#' unless `overwrite = TRUE`.
#'
#' The database and the downloaded index live under
#' `tools::R_user_dir("alphaearth", "cache")`.
#'
#' @param overwrite Logical. Re-download the index and rebuild the database even
#'   when a cached copy already exists.
#'
#' @return [fs::path()] with the path to the local database.
#'
#' @examples
#' \dontrun{
#'   alphaearth::index()
#' }
#' @export
index <- function(overwrite = FALSE) {
  # download the index
  gpkg <- .index_download(overwrite = overwrite)

  # open the database
  con <- .index_con()

  # side-effect: stop the connection on exit
  on.exit(duckspatial::ddbs_stop_conn(con), add = TRUE)

  # load the index into the database
  .index_load(
    con       = con,
    gpkg      = gpkg,
    overwrite = overwrite
  )

  # query tiles
  tiles_count <- DBI::dbGetQuery(
    con, glue::glue("SELECT COUNT(*) AS n FROM {.config_table()}")
  )

  # get the number of tiles
  tiles_count <- tiles_count$n

  # return the database path
  db_path <- .config_db_path()

  # inform user
  cli::cli_alert_success(
    "Indexed {.val {tiles_count}} AlphaEarth tiles in {.path {db_path}}."
  )

  # return! (invisible to keep the message the last thing users see)
  invisible(db_path)
}

#' Download the AlphaEarth index into the cache.
#'
#' @description Download the AlphaEarth index into the cache.
#'
#' @param overwrite Logical. Re-download the index when a cached copy already
#'   exists.
#'
#' @return [fs::path()] with the path to the index file.
#'
#' @noRd
.index_download <- function(overwrite = FALSE) {
  # get the index path
  gpkg <- .config_gpkg_path()

  # check if the index already exists and if we should overwrite it
  if (fs::file_exists(gpkg) && !overwrite) {
    return(gpkg)
  }

  # update user
  cli::cli_alert_info("Downloading the AlphaEarth index (this happens once)...")

  # download index file
  utils::download.file(.config_index_url(), gpkg, mode = "wb", quiet = TRUE)

  # return!
  gpkg
}

#' Open a DuckDB connection
#'
#' @description Open a DuckDB connection with the spatial extension loaded.
#'
#' @param dbdir [fs::path()] with the path to the database directory.
#'
#' @return [DBI::dbConnect()] with the connection to the database.
#'
#' @noRd
.index_con <- function(dbdir = .config_db_path()) {
  # create the connection
  con <- duckspatial::ddbs_create_conn(dbdir = dbdir)

  # install the spatial extension
  duckspatial::ddbs_install(con, quiet = TRUE)

  # load the spatial extension
  duckspatial::ddbs_load(con, quiet = TRUE)

  # return!
  con
}

#' Load the AlphaEarth index into the database
#'
#' @description Load the AlphaEarth tile index into the database.
#'
#' @param con [DBI::dbConnect()] with the connection to the database.
#' @param gpkg [fs::path()] with the path to the index file.
#' @param overwrite Logical. Overwrite the existing table if it already exists.
#'
#' @return boolean indicating if the index was loaded successfully.
#'
#' @noRd
.index_load <- function(con, gpkg, overwrite = FALSE) {
  # get the table name
  tbl <- .config_table()

  # check if the table already exists and if we should overwrite it
  exists <- tbl %in% DBI::dbListTables(con)

  if (exists && !overwrite) {
    return(invisible(FALSE))
  }

  # drop the table if it already exists
  if (exists) {
    DBI::dbExecute(con, glue::glue("DROP TABLE {tbl}"))
  }

  # create the table
  DBI::dbExecute(con, sprintf(
    "CREATE TABLE %s AS
       SELECT CAST(ROW_NUMBER() OVER () AS BIGINT) AS fid, *
       FROM ST_Read(%s)",
    DBI::dbQuoteIdentifier(con, tbl),
    DBI::dbQuoteString(con, fs::path_expand(gpkg))
  ))

  # return!
  invisible(TRUE)
}
