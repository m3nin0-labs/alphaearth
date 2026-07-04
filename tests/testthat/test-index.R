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
