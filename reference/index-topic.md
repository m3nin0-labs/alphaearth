# Index the AlphaEarth tile catalogue locally

Downloads the AlphaEarth Foundations spatial index and loads it into a
persistent local DuckDB database so that
[`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md)
runs quickly and smooth. The download and load happen once. Later calls
reuse the cached database unless `overwrite = TRUE`.

## Usage

``` r
index(overwrite = FALSE)
```

## Arguments

- overwrite:

  Logical. Re-download the index and rebuild the database even when a
  cached copy already exists.

## Value

[`fs::path()`](https://fs.r-lib.org/reference/path.html) with the path
to the local database.

## Details

The database and the downloaded index live under
`tools::R_user_dir("alphaearth", "cache")`.

## Examples

``` r
if (FALSE) { # \dontrun{
  alphaearth::index()
} # }
```
