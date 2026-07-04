#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#
# Constants for the AlphaEarth package
#
# S3 and HTTP hosts
.AE_S3_HOST      <- "s3://us-west-2.opendata.source.coop/"

# HTTP host
.AE_HTTP_HOST    <- "https://data.source.coop/"

#' AlphaEarth index URL
#' 
#' @description The URL of the AlphaEarth index file.
#' 
#' @return The URL of the AlphaEarth index file.
#'
#' @noRd
.config_index_url <- function() {
  "https://data.source.coop/tge-labs/aef/v1/annual/aef_index.gpkg"
}

#' AlphaEarth embedding bands
#' 
#' @description Names of the AlphaEarth embedding bands
#' 
#' @return vector with the names of the embedding bands
#'
#' @noRd
.config_bands <- function() {
  sprintf("A%02d", 0:63)
}

#' AlphaEarth tile size in metres
#'
#' @description Side length of an AlphaEarth COG footprint in its UTM CRS. Each
#' tile is 8192 pixels at 10 m, i.e. a fixed 81920 m square. Used to derive the
#' stable `<utm_zone>-<col>-<row>` tile id from the UTM origin.
#'
#' @return integer with the tile side length in metres.
#'
#' @noRd
.config_tile_size <- function() {
  8192L * 10L
}

#' AlphaEarth source for sits
#' 
#' @description sits source for the AlphaEarth embedding cube in [sits::sits_cube()]
#' 
#' @return character with the source name.
#'
#' @noRd
.config_source <- function() {
  "ALPHAEARTH"
}

#' AlphaEarth collection for sits
#' 
#' @description sits collection for the AlphaEarth embedding cube in [sits::sits_cube()]
#' 
#' @return character with the collection name.
#'
#' @noRd
.config_collection <- function() {
  "EMBEDDING"
}

#' AlphaEarth parse info for sits
#' 
#' @description parse info for the AlphaEarth embedding cube in [sits::sits_cube()]
#' 
#' @return vector with the parse info.
#'
#' @noRd
.config_parse_info <- function() {
  c("satellite", "sensor", "tile", "band", "date")
}

#' AlphaEarth cache directory
#' 
#' @description cache directory for the AlphaEarth embedding index and database
#' 
#' @return character with the path to the cache directory.
#'
#' @noRd
.config_cache_dir <- function() {
  # create cache directory
  dir <- tools::R_user_dir("alphaearth", "cache")

  # create directory and return it
  fs::dir_create(dir)
}

#' AlphaEarth index path
#' 
#' @description path to the AlphaEarth embedding index file
#' 
#' @return [fs::path()] with the path to the index file.
#'
#' @noRd
.config_gpkg_path <- function() {
  fs::path(.config_cache_dir(), "aef_index.gpkg")
}

#' AlphaEarth database path
#' 
#' @description path to the AlphaEarth embedding database file
#' 
#' @return [fs::path()] with the path to the database file.
#'
#' @noRd
.config_db_path <- function() {
  fs::path(.config_cache_dir(), "alphaearth.duckdb")
}

#' AlphaEarth table name
#' 
#' @description name of the AlphaEarth embedding table in the database
#' 
#' @return character with the name of the table.
#'
#' @noRd
.config_table <- function() {
  "aef_index"
}

#' AlphaEarth HTTP from S3 path
#' 
#' @description convert an S3 path to an HTTP path
#' 
#' @param path character with the S3 path
#' 
#' @return character with the HTTP path.
#'
#' @noRd
.config_http_from_s3 <- function(path) {
  sub(.AE_S3_HOST, .AE_HTTP_HOST, path, fixed = TRUE)
}

#' AlphaEarth streamable GDAL URL from HTTP URL
#'
#' @description Wrap an HTTP URL in the GDAL `/vsicurl/` handler so the raster
#' can be read directly over the network (range requests), without downloading.
#'
#' @param url character with the HTTP URL
#'
#' @return character with the `/vsicurl/` GDAL URL.
#'
#' @noRd
.config_vsicurl_url <- function(url) {
  paste0("/vsicurl/", url)
}

#' AlphaEarth sits source/collection configuration
#'
#' @description path to the bundled sits source/collection configuration
#'
#' @return character with the path to the configuration file.
#'
#' @noRd
.config_sits_yaml <- function() {
  system.file("extdata", "alphaearth.yml", package = "alphaearth")
}

#' AlphaEarth GeoTIFF creation options
#'
#' @description GDAL creation options used when [download()] materialises the
#' embedding COGs into local GeoTIFFs.
#'
#' @return character vector with the `-co` GDAL creation options.
#'
#' @noRd
.config_gtiff_options <- function() {
  # tiled and ZSTD-compressed, so the output 
  # stays compact and fast to read
  c("-co", "TILED=YES", "-co", "COMPRESS=ZSTD")
}

#' AlphaEarth download filename prefix
#'
#' @description Prefix used for the GeoTIFFs written by [download()].
#'
#' @return character with the filename prefix.
#'
#' @noRd
.config_download_prefix <- function() {
  "ae"
}
