# Download AlphaEarth tiles as local GeoTIFFs

Materialises the selected tiles into local GeoTIFFs, and (optionally)
cropping them to a region of interest.

Two on-disk layouts are supported:

- `"stack"`: one multi-band GeoTIFF per tile, holding every requested
  embedding dimension (`ae_<tile>_<year>.tif`);

- `"bands"`: one single-band GeoTIFF per embedding dimension
  (`ae_<tile>_<band>_<year>.tif`).

Each tile keeps its native UTM CRS (no reprojection). Existing files are
reused unless `overwrite = TRUE`.

## Usage

``` r
download(
  x,
  output_dir,
  bands = NULL,
  roi = NULL,
  layout = c("stack", "bands"),
  overwrite = FALSE,
  progress = TRUE,
  multicores = 1L
)
```

## Arguments

- x:

  An `sf` object returned by
  [`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md).

- output_dir:

  Directory where the GeoTIFFs are written (created if needed).

- bands:

  Character vector of embedding bands to download, from `A00` to `A63`
  (defaults to all 64 bands).

- roi:

  Optional region of interest used to crop each tile (any object
  accepted by
  [`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md)).
  Defaults to `NULL` (full tiles).

- layout:

  One of `"stack"` (one multi-band file per tile) or `"bands"` (one file
  per embedding dimension).

- overwrite:

  Logical. Re-write files that already exist. Defaults to `FALSE`.

- progress:

  Logical. Show a progress bar. Defaults to `TRUE`.

- multicores:

  Integer. Number of parallel workers used to write the files. Defaults
  to `1` (sequential); values above `1` download tiles concurrently.

## Value

A `tibble` (invisible) with one row per written file.

## See also

[`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md),
[`as_vrt()`](https://m3nin0-labs.github.io/alphaearth/reference/as_vrt.md),
[`as_cube()`](https://m3nin0-labs.github.io/alphaearth/reference/as_cube.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  tiles <- alphaearth::search(
    roi = my_roi,
    start_date = "2020",
    end_date   = "2020"
  )

  # one multi-band GeoTIFF per tile, cropped to a ROI
  files <- alphaearth::download(
    x = tiles,
    output_dir = "embeddings",
    roi = c(
      xmin = -47.9,
      ymin = -15.9,
      xmax = -47.85,
      ymax = -15.85
    )
  )

  # one file per embedding dimension
  files <- alphaearth::download(
    x = tiles,
    output_dir = "embeddings",
    bands = c("A00", "A01"),
    layout = "bands"
  )
} # }
```
