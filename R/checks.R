#
# Copyright (C) 2026 Felipe Carlos (m3nin0-labs).
#
# alphaearth Package is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.
#

#' Check if a package is installed
#'
#' @description Check if a package is installed.
#'
#' @param pkg character vector with the names of the packages to check.
#' @param reason character with the reason for the missing package.
#'
#' @noRd
.check_package <- function(pkg, reason = NULL) {
  # check if the package is installed
  installed <- purrr::map_lgl(
    pkg, requireNamespace, quietly = TRUE
  )

  # check if the package is missing
  missing <- pkg[!installed]

  # if the package is missing, abort the operation
  if (length(missing) > 0L) {

    # build the message
    msg <- "Package{?s} {.pkg {missing}} {?is/are} required but not installed."

    if (!is.null(reason)) {
      msg <- c(msg, i = reason)
    }

    msg <- c(
      msg,
      i = "Install with {.code install.packages(c({paste0('\"', missing, '\"', collapse = ', ')}))}."
    )

    # abort
    cli::cli_abort(msg)
  }

  # return!
  invisible(TRUE)
}

#' Check the tiles object.
#'
#' @description Validate that `x` is a data frame carrying the required columns.
#'
#' @param x object to validate.
#' @param cols character vector with the required column names.
#'
#' @return The input object (invisible).
#'
#' @noRd
.check_tiles <- function(x, cols) {
  # pre-condition: x must be a data frame
  if (!is.data.frame(x)) {
    cli::cli_abort(
      "{.arg x} must be a tiles table from {.fn search}, not {.cls {class(x)}}."
    )
  }

  # pre-condition: the required columns must be present
  missing <- setdiff(cols, names(x))

  if (length(missing) > 0L) {
    cli::cli_abort(
      "{.arg x} is missing the column{?s} {.field {missing}}."
    )
  }

  # return!
  invisible(TRUE)
}

#' Check an output directory argument.
#'
#' @description Validate that `output_dir` is a single, non-missing directory path.
#'
#' @param output_dir object to validate.
#'
#' @return `TRUE` (invisible).
#'
#' @noRd
.check_output_dir <- function(output_dir) {
  ok <- is.character(output_dir) && length(output_dir) == 1L && !is.na(output_dir)

  if (!ok) {
    cli::cli_abort("{.arg output_dir} must be a single directory path.")
  }

  # return!
  invisible(TRUE)
}

#' Check a `multicores` argument.
#'
#' @description Validate that `multicores` is a single number `>= 1`.
#'
#' @param multicores object to validate.
#'
#' @return `TRUE` (invisible).
#'
#' @noRd
.check_multicores <- function(multicores) {
  ok <- is.numeric(multicores) && length(multicores) == 1L
  ok <- ok && !is.na(multicores) && multicores >= 1L

  if (!ok) {
    cli::cli_abort("{.arg multicores} must be a single number {.val {1}} or greater.")
  }

  # return!
  invisible(TRUE)
}
