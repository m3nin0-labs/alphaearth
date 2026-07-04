# Export AlphaEarth tiles to a data cube format.

Turns the result of
[`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md)
into a data cube.

## Usage

``` r
as_cube(x, to = c("sits", "stars"), ...)

# S3 method for class 'sf'
as_cube(x, to = c("sits", "stars"), ...)
```

## Arguments

- x:

  An `sf` object returned by
  [`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md).

- to:

  Character naming the target backend, either `"sits"` or `"stars"`.

- ...:

  Extra arguments forwarded to the selected backend (see Details).

## Value

The object produced by the selected format.

## Details

The backends accept the following arguments through `...`:

- `"sits"`: `output_dir` (directory for the per-band VRTs), `bands`
  (embedding bands, `A00`-`A63`, defaults to all 64), `roi` (optional
  crop, any object accepted by
  [`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md)),
  and any further argument passed on to
  [`sits::sits_cube()`](https://e-sensing.github.io/sits/reference/sits_cube.html)
  (e.g. `multicores`, `progress`). Returns a `sits` cube.

- `"stars"`: `output_dir` (directory for the intermediate VRTs, defaults
  to a temporary directory), `bands`, `roi`, `proxy` (read lazily as a
  `stars_proxy`, defaults to `TRUE`), and any further argument passed on
  to
  [`stars::read_stars()`](https://r-spatial.github.io/stars/reference/read_stars.html).
  Returns one `stars` object for a single tile, or a named list of
  `stars` objects keyed by tile id.

## Note

To materialise the tiles as GeoTIFFs on disk instead, use
[`download()`](https://m3nin0-labs.github.io/alphaearth/reference/download.md).

## See also

[`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md),
[`download()`](https://m3nin0-labs.github.io/alphaearth/reference/download.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  tiles <- alphaearth::search(
    roi = my_roi,
    start_date = "2020",
    end_date = "2021"
  )

  # read the tiles as a stars cube
  cube <- alphaearth::as_cube(
    x = tiles,
    to = "stars",
    bands = c("A00", "A01")
  )

  # read the tiles as a sits cube
  cube <- alphaearth::as_cube(
    x = tiles,
    to = "sits",
    bands = c("A00", "A01")
  )
} # }
```
