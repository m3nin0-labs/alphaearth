# Search AlphaEarth tiles

Queries the local index built by
[`index()`](https://m3nin0-labs.github.io/alphaearth/reference/index.md)
and returns the matching tiles.

## Usage

``` r
search(roi = NULL, start_date = NULL, end_date = NULL, fid = NULL)
```

## Arguments

- roi:

  object with the spatial region of interest (more information below).

- start_date:

  character with the start date of the temporal filter (more information
  below).

- end_date:

  character with the end date of the temporal filter (more information
  below).

- fid:

  Integer vector of feature ids to select directly.

## Value

An `sf` object (with class `alphaearth_tiles`) with one row per tile,
including `fid`, `tile`, `year`, the `url` (plain HTTP) and `vsicurl`
(streamable `/vsicurl/`), and a `geom` (`sfc`) column.

## Note

The `roi` argument accepts the following types of objects:

- an `sf`/`sfc` object,

- an `sf` `bbox`,

- a named numeric vector `c(xmin, ymin, xmax, ymax)` in EPSG:4326,

- a `terra` `SpatRaster`/`SpatVector` (its extent is used).

Any CRS is accepted and reprojected to EPSG:4326.

The `date` argument accepts the following formats:

- "YYYY" (e.g. "2020"),

- "YYYY-MM-DD" (e.g. "2020-01-01").

## See also

[`index()`](https://m3nin0-labs.github.io/alphaearth/reference/index.md),
[`as_cube()`](https://m3nin0-labs.github.io/alphaearth/reference/as_cube.md)

## Examples

``` r
if (FALSE) { # \dontrun{
alphaearth::search(
  roi = c(xmin = -47.9, ymin = -15.9, xmax = -47.8, ymax = -15.8),
  start_date = "2020", end_date = "2020"
)
} # }
```
