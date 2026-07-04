#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

.mock_tiles <- function(dir) {
  tibble::tibble(
    tile = "19S-2-104",
    year = 2020L,
    vsicurl = as.character(.mock_raster(dir))
  )
}

.mock_stars_tiles <- function(dir, tiles = "19S-2-104") {
  # define geometry
  geom <- sf::st_point(c(-47.5, -15.5))
  geom <- rep(list(geom), length(tiles))

  # geometry as sf object
  geom <- sf::st_sfc(geom, crs = 4326)

  # define tiles table
  sf::st_as_sf(
    tibble::tibble(
      tile = tiles,
      year = 2020L,
      date = as.Date("2020-01-01"),
      vsicurl = as.character(.mock_raster(dir)),
      geom = geom
    ),
    sf_column_name = "geom"
  )
}

# write a 3-band georeferenced raster and return its path.
.mock_raster <- function(dir) {
  # define source path
  src <- fs::path(dir, "src.tif")

  # write raster if it doesn't exist
  if (!fs::file_exists(src)) {
    # define raster
    r <- terra::rast(
      nrows = 10,
      ncols = 10,
      nlyrs = 3,
      xmin = -48, xmax = -47,
      ymin = -16, ymax = -15,
      crs = "EPSG:4326"
    )

    # set values
    terra::values(r) <- seq_len(terra::ncell(r) * terra::nlyr(r))

    # write raster
    terra::writeRaster(r, src)
  }

  # return!
  src
}
