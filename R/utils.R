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
.utils_check_package <- function(pkg, reason = NULL) {
  # check if the package is installed
  installed <- purrr::map_lgl(
    pkg, requireNamespace, quietly = TRUE
  )

  # check if the package is missing
  missing <- pkg[!installed]

  # if the package is missing, abort the operation
  if (length(missing) > 0L) {

    cli::cli_abort(c(
      "Package{?s} {.pkg {missing}} {?is/are} required but not installed.",
      i = if (!is.null(reason)) reason,
      i = "Install with {.code install.packages(c({paste0('\"', missing, '\"', collapse = ', ')}))}."
    ))

  }

  # return!
  invisible(TRUE)
}
