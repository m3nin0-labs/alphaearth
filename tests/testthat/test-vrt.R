#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

test_that("as_vrt - stack layout writes one multi-band VRT per tile", {
  skip_if_not_installed("terra")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_tiles(dir)

  # define output directory
  out <- fs::path(dir, "vrt")

  files <- as_vrt(
    x = tiles,
    output_dir = out,
    bands = c("A00", "A01", "A02"),
    layout = "stack",
    progress = FALSE
  )

  # tests
  expect_s3_class(files, "tbl_df")
  expect_named(files, c("tile", "year", "band", "path"))
  expect_equal(nrow(files), 1L)
  expect_true(is.na(files$band))

  # expect one VRT named ae_<tile>_<year>.vrt, referencing all requested bands
  expect_equal(fs::path_file(files$path), "ae_19S-2-104_2020.vrt")
  expect_true(fs::file_exists(files$path))
  expect_equal(terra::nlyr(terra::rast(files$path)), 3L)
})

test_that("as_vrt - bands layout writes one single-band VRT per dimension", {
  skip_if_not_installed("terra")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_tiles(dir)

  # define output directory
  out <- fs::path(dir, "vrt")

  files <- as_vrt(
    x = tiles,
    output_dir = out,
    bands = c("A00", "A01"),
    layout = "bands", progress = FALSE
  )

  # tests
  expect_equal(nrow(files), 2L)
  expect_setequal(files$band, c("A00", "A01"))
  expect_setequal(
    fs::path_file(files$path),
    c("ae_19S-2-104_A00_2020.vrt", "ae_19S-2-104_A01_2020.vrt")
  )

  # each VRT references a single band
  expect_true(all(purrr::map_lgl(
    files$path, function(p) terra::nlyr(terra::rast(p)) == 1L
  )))
})

test_that("as_vrt - an ROI crops the virtual raster", {
  skip_if_not_installed("terra")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_tiles(dir)

  # define output directory
  out <- fs::path(dir, "vrt")

  files <- as_vrt(
    x = tiles,
    output_dir = out,
    bands = "A00", layout = "bands",
    roi = c(
      xmin = -47.9,
      ymin = -15.9,
      xmax = -47.5,
      ymax = -15.5
    ),
    progress = FALSE
  )

  # tests
  cropped <- terra::rast(files$path)

  expect_lt(terra::ncol(cropped), 10L)
  expect_lt(terra::nrow(cropped), 10L)
})

test_that("as_vrt - existing VRTs are reused unless overwrite = TRUE", {
  skip_if_not_installed("terra")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_tiles(dir)
  out <- fs::path(dir, "vrt")

  files <- as_vrt(
    x = tiles,
    output_dir = out,
    bands = "A00",
    layout = "bands",
    progress = FALSE
  )

  # replace the output with a sentinel so a rewrite is detectable
  writeLines("sentinel", files$path)

  # skip: the sentinel survives
  as_vrt(
    x = tiles,
    output_dir = out,
    bands = "A00",
    layout = "bands",
    progress = FALSE
  )

  expect_equal(readLines(files$path), "sentinel")

  # overwrite: the VRT is regenerated as a real virtual raster again
  as_vrt(
    x = tiles,
    output_dir = out,
    bands = "A00",
    layout = "bands",
    overwrite = TRUE, progress = FALSE
  )

  # tests
  expect_equal(terra::nlyr(terra::rast(files$path)), 1L)
})
