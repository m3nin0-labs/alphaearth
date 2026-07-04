#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

test_that("download - stack layout writes one multi-band file per tile", {
  skip_if_not_installed("terra")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_tiles(dir)
  out <- fs::path(dir, "cube")

  # download files
  files <- download(
    x = tiles,
    output_dir = out,
    bands = c("A00", "A01", "A02"),
    layout = "stack",
    progress = FALSE
  )

  # expect a tibble
  expect_s3_class(files, "tbl_df")
  
  # expect named columns
  expect_named(files, c("tile", "year", "band", "path"))
  
  # expect one row
  expect_equal(nrow(files), 1L)
  expect_true(is.na(files$band))

  # expect one file named ae_<tile>_<year>.tif
  expect_equal(
    fs::path_file(files$path), "ae_19S-2-104_2020.tif"
  )

  # expect file exists
  expect_true(fs::file_exists(files$path))

  # expect 3 bands
  expect_equal(terra::nlyr(terra::rast(files$path)), 3L)
})

test_that("download - bands layout writes one single-band file per dimension", {
  skip_if_not_installed("terra")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_tiles(dir)

  # define output directory
  out <- fs::path(dir, "cube")

  # download files
  files <- download(
    x = tiles,
    output_dir = out,
    bands = c("A00", "A01"),
    layout = "bands",
    progress = FALSE
  )

  # expect a tibble
  expect_s3_class(files, "tbl_df")

  # expect named columns
  expect_named(files, c("tile", "year", "band", "path"))

  # expect two rows
  expect_equal(nrow(files), 2L)
  expect_setequal(files$band, c("A00", "A01"))

  # expect two files named ae_<tile>_<band>_<year>.tif
  expect_equal(
    fs::path_file(files$path),
    c("ae_19S-2-104_A00_2020.tif", "ae_19S-2-104_A01_2020.tif")
  )

  # expect two files exist
  expect_true(all(fs::file_exists(files$path)))

  # each file is a single band
  expect_true(all(
    purrr::map_lgl(files$path, function(p) {
      terra::nlyr(terra::rast(p)) == 1L
    })
  ))
})

test_that("download - an ROI crops the downloaded pixels", {
  skip_if_not_installed("terra")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_tiles(dir)

  # define output directory
  out <- fs::path(dir, "cube")

  files <- download(
    x = tiles,
    output_dir = out,
    bands = "A00",
    layout = "bands",
    roi = c(
      xmin = -47.9,
      ymin = -15.9,
      xmax = -47.5,
      ymax = -15.5
    ),
    progress = FALSE
  )

  # expect small raster
  cropped <- terra::rast(files$path)

  expect_lt(terra::ncol(cropped), 10L)
  expect_lt(terra::nrow(cropped), 10L)
})

test_that("download - existing files are reused unless overwrite enabled", {
  skip_if_not_installed("terra")

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_tiles(dir)

  # define output directory
  out <- fs::path(dir, "cube")

  # download files
  files <- download(
    x = tiles,
    output_dir = out,
    bands = "A00",
    layout = "bands",
    progress = FALSE
  )

  # replace the output with a sentinel so a rewrite is detectable
  writeLines("sentinel", files$path)

  # skip: the sentinel survives (the existing file is reused)
  download(
    x = tiles,
    output_dir = out,
    bands = "A00",
    layout = "bands",
    progress = FALSE
  )
  expect_equal(readLines(files$path), "sentinel")

  # overwrite: the file is regenerated as a real raster again
  files <- download(
    x = tiles,
    output_dir = out,
    bands = "A00",
    layout = "bands",
    overwrite = TRUE,
    progress = FALSE
  )

  # expect 1 band
  expect_equal(
    terra::nlyr(terra::rast(files$path)), 1L
  )
})

test_that("download - multicores writes the same files as the sequential path", {
  skip_on_cran()
  skip_if_not_installed("terra")
  skip_if_not_installed("furrr")

  # multisession workers load the *installed* package, so skip
  # during development mode
  is_in_dev_mode <- requireNamespace("pkgload", quietly = TRUE) && 
                    pkgload::is_dev_package("alphaearth")
  
  skip_if(
    is_in_dev_mode,
    "parallel workers need the installed package, not a load_all() namespace"
  )

  # define temporary directory
  dir <- withr::local_tempdir()

  # define tiles
  tiles <- .mock_tiles(dir)

  # define output directory
  out <- fs::path(dir, "cube")

  files <- download(
    x = tiles,
    output_dir = out,
    bands = c("A00", "A01", "A02"),
    layout = "bands",
    multicores = 2,
    progress = FALSE
  )

  # tests
  expect_equal(nrow(files), 3L)
  expect_true(all(fs::file_exists(files$path)))
  expect_true(all(purrr::map_lgl(
    files$path, function(p) {
      terra::nlyr(terra::rast(p)) == 1L
    }
  )))
})

test_that("download validates its inputs before doing any work", {
  dir <- withr::local_tempdir()
  tiles <- .mock_tiles(dir)
  out <- fs::path(dir, "cube")

  # tests
  expect_error(download(tibble::tibble(a = 1), out, progress = FALSE), "missing the column")
  expect_error(download(tiles, out, multicores = 0, progress = FALSE), "or greater")
  expect_error(download(tiles, out, bands = "A64", progress = FALSE), "Unknown band")

  # nothing was written
  expect_false(fs::dir_exists(out))
})
