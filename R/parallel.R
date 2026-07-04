#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Walk over parallel arguments, sequentially or across workers.
#'
#' @description Apply `.f` to each set of arguments in `.l`, either sequentially
#' or across `multicores` `future` workers. The default (`multicores = 1`) keeps 
#' the lightweight sequential path and `multicores > 1` uses `furrr`.
#'
#' @param .l A named `list` of arguments.
#' @param .f A `function` applied to each argument in `.l`.
#' @param multicores An `integer` with the number of parallel workers.
#' @param progress Logical. Show a progress bar.
#' @param label A `character` with the progress bar label (sequential mode).
#'
#' @return Invisible `NULL`, called for its side effects.
#'
#' @noRd
.parallel_pwalk <- function(.l, .f, multicores = 1L, progress = TRUE,
                            label = "Working") {
  # if multicores is 1, use the sequential path
  if (multicores <= 1L) {
    pb <- NULL

    if (progress) {
      pb <- cli::cli_progress_bar(label, total = length(.l[[1L]]))
    }

    purrr::pwalk(.l, function(...) {
      # call function
      .f(...)

      # update progress bar
      if (progress) {
        cli::cli_progress_update(id = pb)
      }
    })

    # close progress bar
    if (progress) {
      cli::cli_progress_done(id = pb)
    }

    return(invisible(NULL))
  }

  # if multicores is greater than 1, use the parallel path
  # define plan
  oplan <- future::plan(future::multisession, workers = multicores)

  # side-effect: restore original plan on exit
  on.exit(future::plan(oplan), add = TRUE)

  # call function in parallel
  furrr::future_pwalk(
    .l, .f,
    .progress = progress,
    .options  = furrr::furrr_options(seed = TRUE)
  )

  # return!
  invisible(NULL)
}
