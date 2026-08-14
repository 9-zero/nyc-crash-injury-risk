source(here::here("R", "plots.R"))

table_dir <- here::here("outputs", "tables")
figure_dir <- here::here("outputs", "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

annual <- readr::read_csv(
  file.path(table_dir, "annual_summary.csv"),
  show_col_types = FALSE
)
hourly <- readr::read_csv(
  file.path(table_dir, "hourly_summary.csv"),
  show_col_types = FALSE
)
borough <- readr::read_csv(
  file.path(table_dir, "borough_summary.csv"),
  show_col_types = FALSE
)
bootstrap <- readr::read_csv(
  file.path(table_dir, "bootstrap_summary.csv"),
  show_col_types = FALSE
)
odds_ratios <- readr::read_csv(
  file.path(table_dir, "odds_ratios.csv"),
  show_col_types = FALSE
)
dashboard_data <- readRDS(
  here::here("data", "processed", "dashboard_data.rds")
)

figures <- list(
  annual_injury_rate = plot_annual_trend(annual),
  hourly_injury_rate = plot_hourly_pattern(hourly),
  borough_injury_rate = plot_borough_comparison(borough, bootstrap),
  model_odds_ratios = plot_model_effects(odds_ratios),
  crash_density = plot_crash_density(dashboard_data)
)

purrr::iwalk(
  figures,
  function(plot, name) {
    ggplot2::ggsave(
      filename = file.path(figure_dir, paste0(name, ".png")),
      plot = plot,
      width = 8,
      height = 5,
      dpi = 300,
      bg = "white"
    )
  }
)
