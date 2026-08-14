if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop(
    "Install the deployment package first with install.packages('rsconnect').",
    call. = FALSE
  )
}

accounts <- rsconnect::accounts(server = "shinyapps.io")
account <- Sys.getenv("SHINYAPPS_ACCOUNT", unset = "")

if (!nzchar(account) && nrow(accounts) == 1L) {
  account <- accounts$name[[1]]
}
if (!nzchar(account)) {
  stop(
    paste(
      "Connect a shinyapps.io account first, then set SHINYAPPS_ACCOUNT",
      "to the account name shown in the dashboard."
    ),
    call. = FALSE
  )
}

bundle_dir <- tempfile("nyc-crash-shiny-")
dir.create(bundle_dir, recursive = TRUE)
dir.create(file.path(bundle_dir, "www"))
dir.create(file.path(bundle_dir, "data"))

bundle_files <- c(
  "app/app.R" = "app.R",
  "app/www/styles.css" = "www/styles.css",
  "outputs/tables/dashboard_cube.csv" = "data/dashboard_cube.csv",
  "outputs/tables/bootstrap_summary.csv" = "data/bootstrap_summary.csv",
  "outputs/tables/odds_ratios.csv" = "data/odds_ratios.csv",
  "outputs/tables/map_cells.csv.gz" = "data/map_cells.csv.gz"
)

source_paths <- here::here(names(bundle_files))
missing_files <- names(bundle_files)[!file.exists(source_paths)]
if (length(missing_files) > 0L) {
  stop(
    "Deployment files are missing: ",
    paste(missing_files, collapse = ", "),
    call. = FALSE
  )
}

copied <- file.copy(
  from = source_paths,
  to = file.path(bundle_dir, unname(bundle_files)),
  overwrite = TRUE
)
if (!all(copied)) {
  stop("Failed to assemble the deployment bundle.", call. = FALSE)
}

tryCatch(
  rsconnect::deployApp(
    appDir = bundle_dir,
    appName = "nyc-crash-injury-risk",
    appTitle = "NYC Crash Injury Risk",
    account = account,
    server = "shinyapps.io",
    appVisibility = "public",
    recordDir = here::here("app"),
    launch.browser = TRUE
  ),
  finally = unlink(bundle_dir, recursive = TRUE)
)
