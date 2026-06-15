#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

.make_index_gpkg <- function(path) {
  # closure - make a bbox utility
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

  # create the data frame
  df <- data.frame(
    path = c(
      "s3://us-west-2.opendata.source.coop/tge-labs/aef/v1/annual/2020/22S/tileA-0-0.tiff",
      "s3://us-west-2.opendata.source.coop/tge-labs/aef/v1/annual/2021/22S/tileB-0-0.tiff",
      "s3://us-west-2.opendata.source.coop/tge-labs/aef/v1/annual/2020/24S/tileC-0-0.tiff"
    ),
    year = c(
      2020,
      2021,
      2020
    ),
    utm_zone = c(
      "22S",
      "22S",
      "24S"
    ),
    crs = c(
      "EPSG:32722",
      "EPSG:32722",
      "EPSG:32724"
    ),
    wgs84_west = c(
      -48,
      -48,
      -40
    ),
    wgs84_south = c(
      -16,
      -16,
      -10
    ),
    wgs84_east = c(
      -47.5,
      -47.5,
      -39.5
    ),
    wgs84_north = c(
      -15.5,
      -15.5,
      -9.5
    )
  )

  # create the geometry column
  df$geom <- sf::st_sfc(
    make_bbox(-48, -16, -47.5, -15.5),
    make_bbox(-48, -16, -47.5, -15.5),
    make_bbox(-40, -10, -39.5, -9.5),
    crs = 4326
  )

  # write gpkg
  sf::st_write(sf::st_as_sf(df), path, layer = "aef_index_updated", quiet = TRUE)

  # return!
  path
}

test_that("index load + search filter tiles spatially, by year and attributes", {
  # create a temporary file
  gpkg <- .make_index_gpkg(withr::local_tempfile(fileext = ".gpkg"))

  # create a temporary database
  db <- withr::local_tempfile(fileext = ".duckdb")
  con <- .index_con(db)

  # side-effect: stop the connection on exit
  withr::defer(duckspatial::ddbs_stop_conn(con))

  # load the index
  .index_load(con, gpkg, overwrite = TRUE)

  # check if the fid column exists
  expect_true("fid" %in% DBI::dbListFields(con, .config_table()))

  # closure - create a search function
  search_con <- function(...) {
    .search_collect(con, .search_predicates(con, ...))
  }

  # search for the first tile
  res <- search_con(
    roi = c(
      xmin = -47.9,
      ymin = -15.9,
      xmax = -47.8,
      ymax = -15.8
    ),
    start_date = "2020",
    end_date = "2020",
    fid = NULL
  )

  # check the result: the tile id is a "stable" <utm_zone>-<offset>
  expect_equal(res$fid, 1L)
  expect_equal(res$tile, "22S-0-0")
  expect_match(res$vrt_url, "2020/22S/tileA-0-0\\.vrt$")
  expect_s3_class(res, "alphaearth_tiles")

  # tileA (2020) and tileB (2021) share the footprint, so across both years they
  # resolve to a single tile id
  both <- search_con(
    roi = c(
      xmin = -47.9,
      ymin = -15.9,
      xmax = -47.8,
      ymax = -15.8
    ),
    start_date = "2020",
    end_date = "2021",
    fid = NULL
  )
  expect_equal(nrow(both), 2L)
  expect_equal(unique(both$tile), "22S-0-0")
  expect_setequal(both$year, c(2020L, 2021L))

  # an ROI over the distant tile C selects it alone
  res_c <- search_con(
    roi = c(
      xmin = -39.9,
      ymin = -9.9,
      xmax = -39.8,
      ymax = -9.8
    ),
    start_date = NULL,
    end_date = NULL,
    fid = NULL
  )
  expect_equal(res_c$fid, 3L)
  expect_equal(res_c$tile, "24S-0-0")

  # search by feature id
  expect_equal(
    search_con(
      fid = 2L,
      roi = NULL,
      start_date = NULL,
      end_date = NULL
    )$tile,
    "22S-0-0"
  )
})
