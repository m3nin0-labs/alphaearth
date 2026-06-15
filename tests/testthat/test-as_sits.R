#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

test_that("the VRT source is rewritten from /vsis3 to /vsicurl", {
  # read the sample VRT
  doc <- xml2::read_xml(test_path("fixtures", "sample.vrt"))

  # rewrite the source
  .as_sits_rewrite_source(doc)

  # check the source
  src <- xml2::xml_text(xml2::xml_find_first(doc, ".//SourceDataset"))
  expect_match(src, "^/vsicurl/https://data\\.source\\.coop/")
  expect_false(grepl("/vsis3/", src))
})

test_that("per-band VRTs are written with the sits naming convention", {
  # create a temporary directory
  out <- withr::local_tempdir()
  vrt <- .as_sits_fetch_vrt(test_path("fixtures", "sample.vrt"))

  # write the band VRTs
  .as_sits_write_band_vrts(vrt, "sampletile", as.Date("2019-01-01"), c("A00", "A01"), out)

  # check the files
  files <- fs::path_file(fs::dir_ls(out, glob = "*.vrt"))

  expect_setequal(files, c(
    "ALPHAEARTH_EMBEDDING_sampletile_A00_2019-01-01.vrt",
    "ALPHAEARTH_EMBEDDING_sampletile_A01_2019-01-01.vrt"
  ))
})

test_that("already-written band VRTs are reported as not missing", {
  # create a temporary directory
  out <- withr::local_tempdir()
  vrt <- .as_sits_fetch_vrt(test_path("fixtures", "sample.vrt"))

  # nothing on disk yet: both bands are missing
  expect_setequal(
    .as_sits_missing_bands("sampletile", as.Date("2019-01-01"), c("A00", "A01"), out), c("A00", "A01")
  )

  # write only A00
  .as_sits_write_band_vrts(vrt, "sampletile", as.Date("2019-01-01"), "A00", out)

  # now only A01 is missing
  expect_equal(
    .as_sits_missing_bands("sampletile", as.Date("2019-01-01"), c("A00", "A01"), out), "A01"
  )

  # write A01 too: nothing left to rewrite
  .as_sits_write_band_vrts(vrt, "sampletile", as.Date("2019-01-01"), "A01", out)

  expect_length(
    .as_sits_missing_bands("sampletile", as.Date("2019-01-01"), c("A00", "A01"), out), 0L
  )
})

test_that("a band VRT is a self-contained single-band warped VRT", {
  # create a temporary directory
  out <- withr::local_tempdir()

  # fetch the vrt
  vrt <- .as_sits_fetch_vrt(test_path("fixtures", "sample.vrt"))

  # write the band VRTs
  .as_sits_write_band_vrts(vrt, "sampletile", as.Date("2019-01-01"), "A01", out)

  # check the band file
  band_file <- fs::path(out, "ALPHAEARTH_EMBEDDING_sampletile_A01_2019-01-01.vrt")

  # read the band file
  doc <- xml2::read_xml(band_file)

  # check the band
  raster_bands <- xml2::xml_find_all(doc, "/VRTDataset/VRTRasterBand")

  expect_length(raster_bands, 1L)
  expect_equal(xml2::xml_attr(raster_bands[[1]], "band"), "1")
  expect_equal(
    xml2::xml_text(xml2::xml_find_first(doc, ".//VRTRasterBand/Description")),
    "A01"
  )

  # check the warp BandList
  mappings <- xml2::xml_find_all(doc, ".//GDALWarpOptions/BandList/BandMapping")

  expect_length(mappings, 1L)
  expect_equal(xml2::xml_attr(mappings[[1]], "src"), "2")
  expect_equal(xml2::xml_attr(mappings[[1]], "dst"), "1")

  # check the warped dataset
  expect_equal(xml2::xml_attr(xml2::xml_root(doc), "subClass"), "VRTWarpedDataset")

  src <- xml2::xml_text(xml2::xml_find_first(doc, ".//SourceDataset"))
  expect_match(src, "^/vsicurl/https://data\\.source\\.coop/")

  expect_false(is.na(xml2::xml_find_first(doc, ".//SRS")))
  expect_false(is.na(xml2::xml_find_first(doc, ".//GeoTransform")))
})

test_that("unknown bands are rejected", {
  expect_error(.as_sits_check_bands("A64"), "Unknown band")
  expect_equal(.as_sits_check_bands(NULL), .config_bands())
  expect_equal(.as_sits_check_bands("a00"), "A00")
})
