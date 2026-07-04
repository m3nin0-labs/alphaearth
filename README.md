
<!-- README.md is generated from README.Rmd. Please edit that file -->

# alphaearth

<!-- badges: start -->

[![R-CMD-check](https://github.com/m3nin0-labs/alphaearth/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/m3nin0-labs/alphaearth/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/m3nin0-labs/alphaearth/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/m3nin0-labs/alphaearth/actions/workflows/pkgdown.yaml)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

R package to **search** and **retrieve** data from the [AlphaEarth
Foundations](https://source.coop/tge-labs/aef) Satellite Embedding
dataset.

## Installation

``` r
# install.packages("remotes")
remotes::install_github("m3nin0-labs/alphaearth")
```

## Usage

``` r
# 1. build the local index (downloads `aef_index.gpkg` once, ~500 MB)
alphaearth::index()

# 2. search tiles by space and time.
#    `roi` accepts an `sf` object, an `sf` bbox, a named numeric vector in
#    EPSG:4326, or a terra object
tiles <- alphaearth::search(
  roi        = c(
    xmin = -47.9,
    ymin = -15.9, 
    xmax = -47.8, 
    ymax = -15.8
  ),
  start_date = 2020,
  end_date   = 2022
)

# 3a. results as a data cube. `to` selects the backend:
#  "sits" -> a local sits cube; 
#  "stars" -> stars objects.
cube <- alphaearth::as_cube(
  x          = tiles,
  to         = "sits",
  output_dir = tempdir(),
  multicores = 4
)

# 3b. or download the tiles as local GeoTIFFs
files <- alphaearth::download(
  x          = tiles,
  output_dir = tempdir(),
  multicores = 4
)

# 3c. or write virtual rasters (VRT)
vrts <- alphaearth::as_vrt(
  x          = tiles,
  output_dir = tempdir()
)
```

## Functions

`alphaearth` is a simple yet complete toolkit, built around five
functions:

| Function | Purpose |
|----|----|
| `index()` | Download the tile index once into a fast local DuckDB database |
| `search()` | Find tiles by space, time, and attributes |
| `as_cube()` | Export the AlphaEarth data as a datacube ([`sits`](https://e-sensing.github.io/sitsbook/) or [`stars`](https://r-spatial.github.io/stars/)) |
| `as_vrt()` | Write AlphaEarth files as virtual rasters (VRT) |
| `download()` | Download AlphaEarth files to a local directory |

## Learn more

Full documentation and articles live on the package website:

- [Getting
  started](https://m3nin0-labs.github.io/alphaearth/articles/alphaearth.html)
- [Data cubes: sits &
  stars](https://m3nin0-labs.github.io/alphaearth/articles/data-cubes.html)
- [Downloading & virtual
  rasters](https://m3nin0-labs.github.io/alphaearth/articles/downloading.html)

## Data representation

Embedding values are stored as signed 8-bit integers. The
de-quantization (`(v / 127.5)^2 * sign(v)`) is **not** applied in any
step performed by `alphaearth`.

## License & attribution

Code is MIT licensed.

Data used in the package is hosted by [Source
Cooperative](https://source.coop/tge-labs/aef). The AlphaEarth
Foundations Satellite Embedding dataset is produced by Google and Google
DeepMind and is licensed under CC-BY 4.0.
