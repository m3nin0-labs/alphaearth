
## AlphaEarth Search

A small, functional R package to `search` data available in the
[AlphaEarth Foundations](https://source.coop/tge-labs/aef) Satellite
Embedding dataset.

### Installation

``` r
# install.packages("remotes")
remotes::install_github("m3nin0-labs/alphaearth")
```

### Usage

``` r
# 1. build the local index (downloads `aef_index.gpkg` once, ~500 MB).
alphaearth::index()

# 2. search data.
# Note: `roi` accepts an `sf` object, an `sf` bbox, a named numeric vector in EPSG:4326, or a terra object.
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

# 3. results as a local sits cube.
cube <- alphaearth::as_sits(
  x = tiles,
  output_dir = tempdir(),
  multicores = 4
)
```

### Functions available

The `alphaearth` was created to be a simple yet useful R package to
search data available in the Alpha Earth embeddings dataset. To
accomplish this task, it provides only three functions:

| Function | Purpose |
|----|----|
| `index()` | Download the tile index once into a fast local DuckDB database. |
| `search()` | Find tiles by space, time, and attributes. |
| `as_sits()` | Prepare the selected tiles as a local [`sits`](https://e-sensing.github.io/sitsbook/) data cube. |

### Data representation

Embedding values are signed 8-bit. The de-quantization
(`(v / 127.5)^2 * sign(v)`) is not applied in any step performed by the
`alphaearth` package.

### License & attribution

Code is MIT licensed.

Data used in the package is hosted by [source
cooperative](https://source.coop/tge-labs/aef).

The AlphaEarth Foundations Satellite Embedding dataset is produced by
Google and Google DeepMind and is licensed under CC-BY 4.0.
