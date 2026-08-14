source(here::here("R", "api.R"))
source(here::here("R", "io.R"))

analysis_years <- 2013L:2025L
refresh <- identical(tolower(Sys.getenv("REFRESH_DATA", "false")), "true")
local_csv <- Sys.getenv("NYC_CRASH_CSV", unset = "")

if (nzchar(local_csv)) {
  cache_local_crash_csv(
    path = local_csv,
    cache_dir = here::here("data", "raw"),
    years = analysis_years,
    refresh = refresh
  )
} else {
  purrr::walk(
    analysis_years,
    function(year) {
      download_crash_year(
        year = year,
        cache_dir = here::here("data", "raw"),
        refresh = refresh
      )
      invisible(NULL)
    }
  )
}
