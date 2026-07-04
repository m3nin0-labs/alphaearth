# Write AlphaEarth tiles as virtual rasters (VRT)

Materialises the selected tiles as lightweight GDAL VRT files that point
at the remote COGs (via `/vsicurl/`). Two on-disk formats are supported
for VRTs:

- `"stack"`: one multi-band VRT per tile, referencing every requested
  band (`ae_<tile>_<year>.vrt`);

- `"bands"`: one single-band VRT per band
  (`ae_<tile>_<band>_<year>.vrt`).

Each tile keeps its native UTM CRS (no reprojection). Existing files are
reused unless `overwrite = TRUE`.

## Usage

``` r
as_vrt(
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

  Directory where the VRTs are written (created if needed).

- bands:

  Character vector of embedding bands to reference, from `A00` to `A63`
  (defaults to all 64 bands).

- roi:

  Optional region of interest used to crop each tile. Defaults to `NULL`
  (full tiles).

- layout:

  One of `"stack"` (one multi-band VRT per tile) or `"bands"` (one VRT
  per band).

- overwrite:

  Logical. Re-write files that already exist. Defaults to `FALSE`.

- progress:

  Logical. Show a progress bar. Defaults to `TRUE`.

- multicores:

  Integer. Number of parallel workers used to write the files. Defaults
  to `1` (sequential). Values above `1` write tiles concurrently.

## Value

A `tibble` (invisible) with one row per written file.

## See also

[`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md),
[`download()`](https://m3nin0-labs.github.io/alphaearth/reference/download.md),
[`as_cube()`](https://m3nin0-labs.github.io/alphaearth/reference/as_cube.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  tiles <- alphaearth::search(
    roi = my_roi,
    start_date = "2020",
    end_date   = "2020"
  )

  # one multi-band VRT per tile
  vrts <- alphaearth::as_vrt(tiles, output_dir = "embeddings")

  # one VRT per embedding dimension
  vrts <- alphaearth::as_vrt(
    x = tiles,
    output_dir = "embeddings",
    bands = c("A00", "A01"),
    layout = "bands"
  )
} # }
```
