# Getting started with alphaearth

## Overview

[AlphaEarth Foundations](https://source.coop/tge-labs/aef) publishes
annual, global **satellite embeddings**: for each 10m pixel, a
64-dimensional vector (bands `A00`-`A63`) that summarises a year of
Earth Observation. The tiles are distributed as Cloud-Optimized GeoTIFFs
(COGs) on [Source Cooperative](https://source.coop/tge-labs/aef).

`alphaearth` is a small, functional R Package to **find** the tiles you
need and **bring them into R** as a datacube, as local GeoTIFFs, or as
VRTs. The typical workflow is four steps:

## 1. Build the local index

[`index()`](https://m3nin0-labs.github.io/alphaearth/reference/index.md)
downloads the AlphaEarth spatial index once (~500 MB) and loads it into
a persistent local DuckDB database. The download and load happen a
single time; later calls reuse the cache unless `overwrite = TRUE`.

``` r

alphaearth::index()
```

## 2. Search tiles by space and time

[`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md)
queries the local index and returns the matching tiles as an `sf` object
(one row per tile), including the tile id, year, and both a plain HTTP
`url` and a streamable `/vsicurl/` url for each COG.

``` r

tiles <- alphaearth::search(
  roi        = c(
    xmin = -47.9,
    ymin = -15.9, 
    xmax = -47.8, 
    ymax = -15.8
  ),
  start_date = "2020-01-01",
  end_date   = "2022-01-01"
)

tiles
```

### The `roi` argument

`roi` is flexible any of the following is accepted and reprojected to
EPSG:4326 automatically:

- an `sf` / `sfc` object,
- an `sf` bounding box (`bbox`),
- a named numeric vector `c(xmin, ymin, xmax, ymax)` in EPSG:4326,
- a `terra` `SpatRaster` / `SpatVector` (its extent is used).

### The date arguments

`start_date` / `end_date` accept either a full year (`"2020"`) or an ISO
date (`"2020-01-01"`). You can also select tiles directly by feature id
with `fid`.

## 3. Bring the tiles into R

From here, you have three options, each covered in its own article:

### Datacubes

**[`as_cube()`](https://m3nin0-labs.github.io/alphaearth/reference/as_cube.md)**
build an analysis-ready data cube for
[`sits`](https://e-sensing.github.io/sitsbook/) or
[`stars`](https://r-spatial.github.io/stars/).

``` r

# sits
cube <- alphaearth::as_cube(
  x  = tiles, 
  to = "sits"
)

# or stars
cube <- alphaearth::as_cube(
  x  = tiles, 
  to = "stars"
)
```

For more information, check the
[`vignette("data-cubes")`](https://m3nin0-labs.github.io/alphaearth/articles/data-cubes.md)

### VRTs

**[`as_vrt()`](https://m3nin0-labs.github.io/alphaearth/reference/as_vrt.md)**
write lightweight virtual rasters (VRT) that stream from the COGs.

``` r

# virtual rasters (no pixels downloaded)
vrts <- alphaearth::as_vrt(
  x = tiles,
  output_dir = "embeddings"
)
```

For more information, check the
[`vignette("downloading")`](https://m3nin0-labs.github.io/alphaearth/articles/downloading.md)

### Download

**[`download()`](https://m3nin0-labs.github.io/alphaearth/reference/download.md)**
materialise the tiles as local GeoTIFFs (optionally cropped).

``` r

# local GeoTIFFs
files <- alphaearth::download(
  x = tiles,
  output_dir = "embeddings",
  multicores = 4
)
```

For more information, check the
[`vignette("downloading")`](https://m3nin0-labs.github.io/alphaearth/articles/downloading.md)

## Data representation

Embedding values are stored as signed 8-bit integers. The
de-quantization `(v / 127.5)^2 * sign(v)` is **not** applied by
`alphaearth` in any step the values are returned exactly as stored, so
you remain in control of any scaling.

## License & attribution

The `alphaearth` code is MIT licensed. The data is hosted by [Source
Cooperative](https://source.coop/tge-labs/aef); the AlphaEarth
Foundations Satellite Embedding dataset is produced by Google and Google
DeepMind and licensed under CC-BY 4.0.
