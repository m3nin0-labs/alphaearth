# Downloading & virtual rasters

## Two ways to put tiles on disk

Once you have a search result, `alphaearth` offers two file-based
exporters that share the same options and return the same manifest:

- [`download()`](https://m3nin0-labs.github.io/alphaearth/reference/download.md)
  materialises real **GeoTIFFs** (pixels copied locally).
- [`as_vrt()`](https://m3nin0-labs.github.io/alphaearth/reference/as_vrt.md)
  writes lightweight **VRT** files that *point at* the remote COGs and
  stream pixels on demand (no download).

``` r

library(alphaearth)

tiles <- alphaearth::search(
  roi        = c(
    xmin = -47.9,
    ymin = -15.9,
    xmax = -47.8,
    ymax = -15.8
  ),
  start_date = 2020,
  end_date   = 2020
)
```

Both functions accept `bands`, an optional `roi` crop, a `layout`,
`overwrite`, `progress`, and `multicores`, and both return a `tibble`
(invisible) with one row per written file and the columns `tile`,
`year`, `band` and `path`.

## Layouts: `stack` vs `bands`

The `layout` argument controls how the embedding dimensions are
organised on disk:

- `"stack"` (default), **one multi-band file per tile**, holding every
  requested band: `ae_<tile>_<year>.tif`.
- `"bands"`, **one single-band file per embedding dimension**:
  `ae_<tile>_<band>_<year>.tif`.

``` r

# one multi-band GeoTIFF per tile
alphaearth::download(tiles, output_dir = "embeddings", layout = "stack")

# one file per band
alphaearth::download(
  x          = tiles,
  output_dir = "embeddings",
  layout     = "bands"
)
```

Each tile keeps its native UTM CRS (no reprojection). Files that already
exist are reused unless `overwrite = TRUE`.

## Cropping to a region of interest

Pass `roi` to crop every tile as it is written. This is useful to keep
only your study area instead of full tiles:

``` r

alphaearth::download(
  x          = tiles,
  output_dir = "embeddings",
  roi        = c(
    xmin = -47.88,
    ymin = -15.88,
    xmax = -47.85,
    ymax = -15.85
  )
)
```

## Downloading in parallel

Writing each file is dominated by network reads of the files, so
downloads parallelise well. Set `multicores` above `1` to write several
files at once (backed by [`future`](https://future.futureverse.org/) /
[`furrr`](https://furrr.futureverse.org/)).

``` r

alphaearth::download(
  x          = tiles,
  output_dir = "embeddings",
  bands      = paste0("A", sprintf("%02d", 0:9)),
  layout     = "bands",
  multicores = 4
)
```

## Virtual rasters with `as_vrt()`

When you don’t need a local copy, for example to prototype, to keep disk
usage low, or to hand a small, portable file to `terra` / `stars`,
[`as_vrt()`](https://m3nin0-labs.github.io/alphaearth/reference/as_vrt.md)
writes VRTs that stream from the COGs. It supports the exact same
`layout`, `roi`, `overwrite` and `multicores` options:

``` r

# one multi-band VRT per tile, streaming from the remote COGs
vrts <- alphaearth::as_vrt(tiles, output_dir = "embeddings")

# one VRT per band
alphaearth::as_vrt(
  tiles,
  output_dir = "embeddings",
  bands      = c("A00", "A01"),
  layout     = "bands"
)
```

A VRT is a tiny XML file; reading it fetches only the bytes you actually
request. Because a cropped
[`as_vrt()`](https://m3nin0-labs.github.io/alphaearth/reference/as_vrt.md)
records the crop window in the VRT, you get a small “view” onto the
cloud data without moving any pixels.

## Choosing between them

| You want… | Use |
|----|----|
| Local, self-contained GeoTIFFs (offline, fastest repeated reads) | [`download()`](https://m3nin0-labs.github.io/alphaearth/reference/download.md) |
| No download; a portable pointer to the cloud data | [`as_vrt()`](https://m3nin0-labs.github.io/alphaearth/reference/as_vrt.md) |
| An analysis-ready cube for `sits` / `stars` | [`as_cube()`](https://m3nin0-labs.github.io/alphaearth/reference/as_cube.md) (see [`vignette("data-cubes")`](https://m3nin0-labs.github.io/alphaearth/articles/data-cubes.md)) |
