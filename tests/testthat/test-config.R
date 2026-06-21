#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

test_that("path conversions follow the source.coop conventions", {
  # convert S3 to HTTP
  s3 <- "s3://us-west-2.opendata.source.coop/tge-labs/aef/v1/annual/2019/1S/abc-0-0.tiff"
  http <- .config_http_from_s3(s3)

  # check the HTTP path
  expect_equal(http, "https://data.source.coop/tge-labs/aef/v1/annual/2019/1S/abc-0-0.tiff")

  # wrap the HTTP path in the /vsicurl/ GDAL handler
  expect_equal(
    .config_vsicurl_url(http),
    "/vsicurl/https://data.source.coop/tge-labs/aef/v1/annual/2019/1S/abc-0-0.tiff"
  )
})

test_that("the tile size is the fixed 81920 m COG footprint", {
  expect_equal(.config_tile_size(), 81920L)
})

test_that("there are 64 bands named A00..A63", {
  # get the bands
  bands <- .config_bands()

  # check the bands
  expect_length(bands, 64)
  expect_equal(bands[c(1, 64)], c("A00", "A63"))
})
