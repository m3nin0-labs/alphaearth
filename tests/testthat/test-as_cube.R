#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

test_that("as_cube - stars reads a single tile lazily by default", {
  skip_if_not_installed("terra")
  skip_if_not_installed("stars")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_stars_tiles(dir)

  # build cube
  cube <- as_cube(
    x = tiles,
    to = "stars",
    output_dir = dir,
    bands = c("A00", "A01")
  )

  # expect a bare stars object
  expect_s3_class(cube, "stars_proxy")

  # expect band dimension
  expect_equal(
    stars::st_get_dimension_values(cube, "band"), c("A00", "A01")
  )
})

test_that("as_cube - stars can read eagerly and key multiple tiles", {
  skip_if_not_installed("terra")
  skip_if_not_installed("stars")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_stars_tiles(dir)

  # build cube
  eager <- as_cube(
    x = tiles,
    to = "stars",
    output_dir = dir,
    bands = "A00",
    proxy = FALSE
  )

  # expect a stars object
  expect_s3_class(eager, "stars")

  # expect not to be a proxy
  expect_false(inherits(eager, "stars_proxy"))

  # define tiles
  tiles <- .mock_stars_tiles(dir, tiles = c("19S-2-104", "19S-2-105"))

  # build cube
  cubes <- as_cube(
    x = tiles,
    to = "stars", output_dir = dir, bands = "A00"
  )

  # tests
  expect_named(cubes, c("19S-2-104", "19S-2-105"))
  expect_s3_class(cubes[[1]], "stars")
})

test_that("as_cube - sits builds a sits cube", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sits")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_stars_tiles(dir)

  # build cube
  cube <- as_cube(
    x = tiles,
    to = "sits",
    output_dir = dir,
    bands = c("A00", "A01")
  )

  # tests
  expect_s3_class(cube, "raster_cube")
})

test_that("as_cube - rejects an unknown backend and a malformed tiles object", {
  dir <- withr::local_tempdir()

  # an unknown backend is rejected before anything else
  expect_error(
    as_cube(x = .mock_stars_tiles(dir), to = "nope"), "should be one of"
  )

  # an sf without the required columns aborts up front
  sf_obj <- tibble::tibble(
    a = 1,
    geom = sf::st_sfc(
      sf::st_point(c(0, 0)), crs = 4326
    )
  )

  sf_obj <- sf::st_as_sf(sf_obj, sf_column_name = "geom")

  # expect error
  expect_error(
    as_cube(x = sf_obj, to = "stars"),
    "missing the column"
  )
})
