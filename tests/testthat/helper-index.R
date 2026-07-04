#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

.make_index_gpkg <- function(path) {
  make_bbox <- function(west, south, east, north) {
    sf::st_polygon(
      list(
        matrix(
          c(
            west, south,
            east, south,
            east, north,
            west, north,
            west, south
          ),
          ncol = 2,
          byrow = TRUE
        )
      )
    )
  }

  df <- data.frame(
    path = c(
      "s3://us-west-2.opendata.source.coop/tge-labs/aef/v1/annual/2020/22S/tileA-0-0.tiff",
      "s3://us-west-2.opendata.source.coop/tge-labs/aef/v1/annual/2021/22S/tileB-0-0.tiff",
      "s3://us-west-2.opendata.source.coop/tge-labs/aef/v1/annual/2020/24S/tileC-0-0.tiff"
    ),
    year = c(2020, 2021, 2020),
    utm_zone = c("22S", "22S", "24S"),
    crs = c("EPSG:32722", "EPSG:32722", "EPSG:32724"),
    utm_west = c(0, 0, 0),
    utm_south = c(0, 0, 0),
    wgs84_west = c(-48, -48, -40),
    wgs84_south = c(-16, -16, -10),
    wgs84_east = c(-47.5, -47.5, -39.5),
    wgs84_north = c(-15.5, -15.5, -9.5)
  )

  df$geom <- sf::st_sfc(
    make_bbox(-48, -16, -47.5, -15.5),
    make_bbox(-48, -16, -47.5, -15.5),
    make_bbox(-40, -10, -39.5, -9.5),
    crs = 4326
  )

  # write gpkg
  sf::st_write(sf::st_as_sf(df), path, layer = "aef_index", quiet = TRUE)

  # return!
  path
}

local_index_fixture <- function(env = parent.frame()) {
  # define cache directory
  cache <- withr::local_tempdir(.local_envir = env)

  # define env var
  withr::local_envvar(R_USER_CACHE_DIR = cache, .local_envir = env)

  # place fixture
  .make_index_gpkg(.config_gpkg_path())

  # return cache path
  invisible(cache)
}
