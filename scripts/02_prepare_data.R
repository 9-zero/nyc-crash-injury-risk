source(here::here("R", "clean.R"))
source(here::here("R", "analysis.R"))

raw_paths <- list.files(
  here::here("data", "raw"),
  pattern = "^crashes_[0-9]{4}\\.rds$",
  full.names = TRUE
)

if (length(raw_paths) == 0L) {
  stop(
    "No yearly cache files found. Run scripts/01_download_data.R first.",
    call. = FALSE
  )
}

raw_data <- purrr::map(raw_paths, readRDS) |>
  dplyr::bind_rows()

analysis_data <- clean_crashes(raw_data)
model_data <- stratified_sample(
  analysis_data,
  fraction = 0.05,
  seed = 2026L
)

set.seed(2026L)
dashboard_data <- analysis_data |>
  dplyr::filter(.data$valid_coordinates) |>
  dplyr::group_by(.data$crash_year) |>
  dplyr::group_modify(
    ~ dplyr::slice_sample(.x, n = min(nrow(.x), 5000L))
  ) |>
  dplyr::ungroup()

processed_dir <- here::here("data", "processed")
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(
  analysis_data,
  file.path(processed_dir, "analysis_data.rds"),
  compress = "xz"
)
saveRDS(
  model_data,
  file.path(processed_dir, "model_data.rds"),
  compress = "xz"
)
saveRDS(
  dashboard_data,
  file.path(processed_dir, "dashboard_data.rds"),
  compress = "xz"
)
