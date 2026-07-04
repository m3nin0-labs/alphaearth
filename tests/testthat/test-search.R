#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

test_that("search - filters tiles by ROI, year and feature id", {
  local_index_fixture()
  index()

  # define ROI
  roi <- c(
    xmin = -47.9,
    ymin = -15.9,
    xmax = -47.8,
    ymax = -15.8
  )

  # search
  res <- search(
    roi = roi,
    start_date = "2020",
    end_date = "2020"
  )

  # tests
  expect_s3_class(res, "alphaearth_tiles")
  expect_equal(res$fid, 1L)
  expect_equal(res$tile, "22S-0-0")
  expect_match(
    res$vsicurl,
    "^/vsicurl/https://data\\.source\\.coop/.*2020/22S/tileA-0-0\\.tiff$"
  )

  # two years search returns two tiles (two years in the same tile)
  both <- search(
    roi = roi,
    start_date = "2020",
    end_date = "2021"
  )

  # tests
  expect_equal(nrow(both), 2L)
  expect_equal(unique(both$tile), "22S-0-0")
  expect_setequal(both$year, c(2020L, 2021L))

  # ISO date filters by its year
  res <- search(
    roi = roi,
    start_date = "2020-06-15",
    end_date = "2020-12-31"
  )

  expect_equal(
    nrow(res), 1L
  )

  # filter by fid
  expect_equal(search(fid = 3L)$tile, "24S-0-0")
})

test_that("search - accepts any ROI form and reprojects to EPSG:4326", {
  local_index_fixture()
  index()

  # define ROI in EPSG:4326
  roi_utm <- sf::st_bbox(
    c(
      xmin = -47.9,
      ymin = -15.9,
      xmax = -47.8,
      ymax = -15.8
    ),
    crs = sf::st_crs(4326)
  )

  # reproject to UTM
  roi_utm <- sf::st_transform(sf::st_as_sfc(roi_utm), 32722)

  # search
  res <- search(
    roi = roi_utm,
    start_date = "2020",
    end_date = "2020"
  )

  expect_equal(res$tile, "22S-0-0")
})

test_that("search - warns on no matches and requires at least one filter", {
  local_index_fixture()
  index()

  # define far-away ROI
  roi <- c(
    xmin = 0,
    ymin = 0,
    xmax = 1,
    ymax = 1
  )

  # warn on no matches
  expect_warning(
    res <- search(roi = roi)
  )

  # tests
  expect_equal(nrow(res), 0L)
  expect_error(search(), "At least one search filter")
})
