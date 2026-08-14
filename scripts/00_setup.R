required_packages <- c(
  "bslib",
  "broom",
  "dplyr",
  "ggplot2",
  "here",
  "httr2",
  "knitr",
  "maps",
  "purrr",
  "readr",
  "scales",
  "shiny",
  "testthat",
  "tibble",
  "tidyr"
)

missing_packages <- setdiff(required_packages, rownames(installed.packages()))

if (length(missing_packages) > 0L) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}
