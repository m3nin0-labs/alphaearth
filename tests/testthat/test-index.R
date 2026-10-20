#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

test_that("index - builds a local database from the catalogue", {
  local_index_fixture()

  db <- index()

  # expect database was created in the cache
  expect_true(fs::file_exists(db))
  expect_equal(as.character(db), as.character(.config_db_path()))

  # expect search resolves the fixture tiles
  expect_equal(nrow(search(fid = 1L)), 1L)
})

test_that("index - reuses the cache without re-downloading", {
  local_index_fixture()

  index()

  # expect second call finds the gpkg + table already in place and does not error
  expect_no_error(index())

  # expect search resolves the fixture tiles
  expect_equal(search(fid = 3L)$tile, "24S-0-0")
})

test_that("index - a missing content length does not fail the size check", {
  path <- withr::local_tempfile()
  writeBin(raw(4L), path)

  local_mocked_bindings(
    curl_fetch_memory = function(url, handle) {
      list(
        headers = charToRaw(
          "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\n\r\n"
        )
      )
    },
    .package = "curl"
  )

  expect_true(.index_check_size(path, "https://example.invalid/aef_index.gpkg"))
})

test_that("index - a short download fails the size check", {
  path <- withr::local_tempfile()
  writeBin(raw(4L), path)

  local_mocked_bindings(
    curl_fetch_memory = function(url, handle) {
      list(
        headers = charToRaw("HTTP/1.1 200 OK\r\nContent-Length: 12\r\n\r\n")
      )
    },
    .package = "curl"
  )

  expect_error(
    .index_check_size(path, "https://example.invalid/aef_index.gpkg"),
    "not written to the cache"
  )
})
