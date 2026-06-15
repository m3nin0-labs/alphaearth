#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

test_that("ROI inputs all normalise to an EPSG:4326 bbox", {
  # expected bbox
  expected <- sf::st_bbox(
    obj = c(
      xmin = -47.9,
      ymin = -15.9,
      xmax = -47.8,
      ymax = -15.8
    ),
    crs = sf::st_crs(4326)
  )

  # named numeric
  num <- .search_roi_bbox(
    c(
      xmin = -47.9,
      ymin = -15.9,
      xmax = -47.8,
      ymax = -15.8
    )
  )
  expect_equal(sf::st_crs(num), sf::st_crs(4326))
  expect_equal(as.numeric(num), as.numeric(expected))

  # sf / sfc
  sfc <- sf::st_as_sfc(expected)
  expect_equal(as.numeric(.search_roi_bbox(sfc)), as.numeric(expected))

  # bbox passed through
  expect_equal(as.numeric(.search_roi_bbox(expected)), as.numeric(expected))
})

test_that("an sf object in another CRS is reprojected to 4326", {
  # expected bbox
  poly <- sf::st_as_sfc(sf::st_bbox(
    c(
      xmin = 200000,
      ymin = 8200000,
      xmax = 210000,
      ymax = 8210000
    ),
    crs = sf::st_crs(32723)
  ))

  # reproject the polygon to 4326
  bbox <- .search_roi_bbox(poly)

  # check the CRS
  expect_equal(sf::st_crs(bbox), sf::st_crs(4326))

  # check the bbox
  expect_true(all(c(bbox["xmin"], bbox["xmax"]) < 0)) # western hemisphere
})

test_that("numeric ROI requires the four named corners", {
  # an unnamed vector is missing the required xmin/ymin/xmax/ymax names
  expect_error(
    .search_roi_bbox(c(-47.9, -15.9, -47.8, -15.8)), "named")
})

test_that("the tile id is the stable UTM-zone + offset, shared across years", {
  # two different filenames at the same grid offset / UTM zone (different years)
  p2020 <- "s3://x/tge-labs/aef/v1/annual/2020/19S/x3pef947d5h16b9ug-0000000000-0000008192.tiff"
  p2021 <- "s3://x/tge-labs/aef/v1/annual/2021/19S/xxbj5w6n1ior4rmmo-0000000000-0000008192.tiff"

  # resolve to the same stable tile id
  expect_equal(.search_tile_id(p2020, "19S"), "19S-0000000000-0000008192")
  expect_equal(.search_tile_id(p2021, "19S"), "19S-0000000000-0000008192")

  # the UTM zone disambiguates equal offsets in different zones
  expect_equal(
    .search_tile_id(p2020, "20S"), "20S-0000000000-0000008192"
  )
})

test_that("predicate builders produce the expected SQL", {
  # create a temporary database
  con <- duckspatial::ddbs_create_conn()
  on.exit(duckspatial::ddbs_stop_conn(con), add = TRUE)

  # check the year SQL predicate
  expect_null(.search_year_sql("year >= %d", NULL))
  expect_equal(.search_year_sql("year >= %d", "2017-06-01"), "year >= 2017")
  expect_equal(.search_year_sql("year <= %d", "2021"), "year <= 2021")

  # check the in SQL predicate
  expect_null(.search_in_sql(con, "utm_zone", NULL))
  expect_equal(
    as.character(.search_in_sql(con, "utm_zone", c("10N", "11N"))),
    "utm_zone IN ('10N', '11N')"
  )
  expect_equal(
    as.character(.search_in_sql(con, "fid", c(1L, 2L), quote = FALSE)),
    "fid IN (1, 2)"
  )
})

test_that("an empty result is shaped correctly and warns", {
  # create a data frame
  df <- data.frame(
    fid = integer(),
    path = character(),
    year = integer(),
    utm_zone = character(),
    crs = character(),
    wgs84_west = double(),
    wgs84_south = double(),
    wgs84_east = double(),
    wgs84_north = double(),
    wkt = character()
  )

  # shape the result
  expect_warning(
    res <- .search_as_tiles(df),
    "No AlphaEarth tiles"
  )

  # check the result
  expect_s3_class(res, "alphaearth_tiles")
  expect_true(inherits(res$geom, "sfc"))
})
