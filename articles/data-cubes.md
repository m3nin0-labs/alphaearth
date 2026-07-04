# Data cubes: sits & stars

## From a search to a data cube

[`as_cube()`](https://m3nin0-labs.github.io/alphaearth/reference/as_cube.md)
turns the result of
[`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md)
into an analysis-ready data cube for a supported backend, selected with
`to`:

``` r

library(alphaearth)

tiles <- alphaearth::search(
  roi    = c(
    xmin = -47.9,
    ymin = -15.9,
    xmax = -47.8,
    ymax = -15.8
  ),
  start_date = 2021,
  end_date   = 2021
)
```

Under the hood
[`as_cube()`](https://m3nin0-labs.github.io/alphaearth/reference/as_cube.md)
never downloads pixels: for each tile it writes small **VRT** files that
read the embedding COG directly over the network (via `/vsicurl/`). The
heavy raster data is only touched when you actually process the cube.

Both backends share three arguments:

- `output_dir`: where the intermediate VRTs are written,
- `bands`: the embedding bands to expose (`A00`–`A63`; all 64 by
  default),
- `roi`: an optional crop applied to every tile (any object
  [`search()`](https://m3nin0-labs.github.io/alphaearth/reference/search.md)
  accepts).

## sits cubes (`to = "sits"`)

For [`sits`](https://e-sensing.github.io/sitsbook/), one single-band VRT
is written per requested band and registered as a local `sits` cube.
Extra arguments (e.g. `multicores`, `progress`) are forwarded to
[`sits::sits_cube()`](https://e-sensing.github.io/sits/reference/sits_cube.html).

``` r

cube <- alphaearth::as_cube(
  x          = tiles,
  to         = "sits",
  output_dir = "cube_sits",
  bands      = c("A00", "A01", "A02"),
  multicores = 4
)

# the result is a regular sits cube, ready for the sits workflow
class(cube)
```

**Note**: In version `2.0`,
[`sits`](https://e-sensing.github.io/sitsbook/) provides native access
to `alphaearth`. Please, consider using their operation.

## stars objects (`to = "stars"`)

For [`stars`](https://r-spatial.github.io/stars/), one multi-band VRT is
written per tile (the embedding dimensions become the `band` dimension)
and read with
[`stars::read_stars()`](https://r-spatial.github.io/stars/reference/read_stars.html).
A single tile returns a bare `stars` object; several tiles return a
named list keyed by tile id.

``` r

cube <- alphaearth::as_cube(
  x          = tiles,
  to         = "stars",
  output_dir = "cube_stars",
  bands      = c("A00", "A01")
)
```

By default the cube is read **lazily** as a `stars_proxy`, meaning no
pixels are read until you access them. Pass `proxy = FALSE` to pull the
values into memory immediately, and any further argument is forwarded to
[`stars::read_stars()`](https://r-spatial.github.io/stars/reference/read_stars.html).

``` r

# eager read (pixels loaded now)
cube <- alphaearth::as_cube(
  x      = tiles,
  to     = "stars",
  bands  = "A00",
  proxy  = FALSE
)
```

## Cropping to a region of interest

Supplying `roi` crops every tile to the same window as it is read. This
is useful for when your area of interest is much smaller than a full
tile:

``` r

small <- alphaearth::as_cube(
  x     = tiles,
  to    = "stars",
  roi   = c(
    xmin = -47.88,
    ymin = -15.88,
    xmax = -47.85,
    ymax = -15.85
  )
)
```

## When to use what

- Reach for
  [`as_cube()`](https://m3nin0-labs.github.io/alphaearth/reference/as_cube.md)
  when you want to *analyse* the embeddings in the `sits` or `stars`
  ecosystems without managing files yourself.

- Reach for
  `download() /`as_vrt()`when you want explicit files on disk. See`vignette(“downloading”)\`.
