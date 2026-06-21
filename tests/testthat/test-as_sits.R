#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

test_that("unknown bands are rejected", {
  expect_error(.as_sits_check_bands("A64"), "Unknown band")
  expect_equal(.as_sits_check_bands(NULL), .config_bands())
  expect_equal(.as_sits_check_bands("a00"), "A00")
})

test_that("the band filename follows the sits naming convention", {
  expect_equal(
    as.character(.as_sits_filename("19S-2-104", "A01", as.Date("2019-01-01"))),
    "ALPHAEARTH_EMBEDDING_19S-2-104_A01_2019-01-01.vrt"
  )
})

test_that("per-band VRTs are written, single-band, and skip existing files", {
  skip_if_not_installed("terra")

  # output directory for the band VRTs
  out <- withr::local_tempdir()

  # a small multi-band raster standing in for an embedding COG
  src <- fs::path(out, "src.tif")
  r <- terra::rast(nrows = 4, ncols = 4, nlyrs = 3)
  terra::values(r) <- seq_len(terra::ncell(r) * terra::nlyr(r))
  terra::writeRaster(r, src)

  # nothing on disk yet: both bands are missing
  expect_setequal(
    .as_sits_missing_bands("tileX", as.Date("2019-01-01"), c("A00", "A01"), out),
    c("A00", "A01")
  )

  # write the two band VRTs directly from the source raster
  .as_sits_write_band_vrts(src, "tileX", as.Date("2019-01-01"), c("A00", "A01"), out)

  # the files follow the sits naming convention
  files <- fs::path_file(fs::dir_ls(out, glob = "*.vrt"))
  expect_setequal(files, c(
    "ALPHAEARTH_EMBEDDING_tileX_A00_2019-01-01.vrt",
    "ALPHAEARTH_EMBEDDING_tileX_A01_2019-01-01.vrt"
  ))

  # each VRT is a single-band raster
  a01 <- terra::rast(fs::path(out, "ALPHAEARTH_EMBEDDING_tileX_A01_2019-01-01.vrt"))
  expect_equal(terra::nlyr(a01), 1L)

  # already-written bands are reported as not missing
  expect_length(
    .as_sits_missing_bands("tileX", as.Date("2019-01-01"), c("A00", "A01"), out),
    0L
  )
})
