pipeline_scripts <- c(
  "01_download_data.R",
  "02_prepare_data.R",
  "03_run_analysis.R",
  "04_make_figures.R"
)

for (script in pipeline_scripts) {
  message("Running ", script)
  sys.source(here::here("scripts", script), envir = new.env(parent = globalenv()))
}

message("Pipeline completed successfully.")
