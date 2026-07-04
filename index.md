# alphaearth

R package to **search** and **retrieve** data from the [AlphaEarth
Foundations](https://source.coop/tge-labs/aef) Satellite Embedding
dataset.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("m3nin0-labs/alphaearth")
```

## Usage

The typical workflow of the `alphaearth` package is composed of three
steps:

### 1. Build the local index

[`index()`](https://m3nin0-labs.github.io/alphaearth/reference/index.md)
downloads the AlphaEarth spatial index once (~500 MB) and loads it into
a persistent local DuckDB database. The download and load happen a
single time. Later calls reuse the cache unless `overwrite = TRUE`.

``` r

alphaearth::index()
```

### 2. Search tiles by space and time

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

### 3. Bring the tiles into R

From here, you have three options, each covered in its own article:

#### Datacubes

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

#### VRTs

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

#### Download

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

## Functions

`alphaearth` is a simple yet complete toolkit, built around five
functions:

| Function | Purpose |
|----|----|
| [`index()`](https://m3nin0-labs.github.io/alphaearth/reference/index.md) | Download the tile index once into a fast local DuckDB database |
| [`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md) | Find tiles by space, time, and attributes |
| [`as_cube()`](https://m3nin0-labs.github.io/alphaearth/reference/as_cube.md) | Export the AlphaEarth data as a datacube ([`sits`](https://e-sensing.github.io/sitsbook/) or [`stars`](https://r-spatial.github.io/stars/)) |
| [`as_vrt()`](https://m3nin0-labs.github.io/alphaearth/reference/as_vrt.md) | Write AlphaEarth files as virtual rasters (VRT) |
| [`download()`](https://m3nin0-labs.github.io/alphaearth/reference/download.md) | Download AlphaEarth files to a local directory |

## Learn more

Full documentation and articles live on the package website:

- [Getting
  started](https://m3nin0-labs.github.io/alphaearth/articles/alphaearth.html)
- [Datacubes: sits &
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
