source(here::here("R", "analysis.R"))

analysis_path <- here::here("data", "processed", "analysis_data.rds")
model_path <- here::here("data", "processed", "model_data.rds")

if (!file.exists(analysis_path) || !file.exists(model_path)) {
  stop(
    "Processed data are missing. Run scripts/02_prepare_data.R first.",
    call. = FALSE
  )
}

analysis_data <- readRDS(analysis_path)
model_data <- readRDS(model_path)

annual <- annual_summary(analysis_data)
borough <- borough_summary(analysis_data)
hourly <- hourly_summary(analysis_data)
rush <- rush_summary(analysis_data)
sample_balance <- sample_balance_summary(analysis_data, model_data)
dashboard_cube <- dashboard_cube_summary(analysis_data)
map_cells <- map_cell_summary(analysis_data)

injury_model <- fit_injury_model(model_data)
odds_ratios <- odds_ratio_table(injury_model)
model_fit <- model_fit_summary(injury_model)

bootstrap_reps <- suppressWarnings(
  as.integer(Sys.getenv("BOOTSTRAP_REPS", unset = "1000"))
)
if (is.na(bootstrap_reps) || bootstrap_reps < 2L) {
  stop("BOOTSTRAP_REPS must be an integer of at least 2.", call. = FALSE)
}

bootstrap <- bootstrap_metrics(
  model_data,
  reps = bootstrap_reps,
  seed = 2026L
)

table_dir <- here::here("outputs", "tables")
model_dir <- here::here("outputs", "models")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)

readr::write_csv(annual, file.path(table_dir, "annual_summary.csv"))
readr::write_csv(borough, file.path(table_dir, "borough_summary.csv"))
readr::write_csv(hourly, file.path(table_dir, "hourly_summary.csv"))
readr::write_csv(rush, file.path(table_dir, "rush_summary.csv"))
readr::write_csv(
  sample_balance,
  file.path(table_dir, "sample_balance.csv")
)
readr::write_csv(
  dashboard_cube,
  file.path(table_dir, "dashboard_cube.csv")
)
readr::write_csv(
  map_cells,
  file.path(table_dir, "map_cells.csv.gz")
)
readr::write_csv(odds_ratios, file.path(table_dir, "odds_ratios.csv"))
readr::write_csv(
  model_fit,
  file.path(table_dir, "model_fit.csv")
)
readr::write_csv(
  bootstrap$summary,
  file.path(table_dir, "bootstrap_summary.csv")
)
readr::write_csv(
  bootstrap$replicates,
  file.path(table_dir, "bootstrap_replicates.csv")
)

saveRDS(injury_model, file.path(model_dir, "injury_model.rds"))
