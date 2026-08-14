nyc_crash_endpoint <-
  "https://data.cityofnewyork.us/resource/h9gi-nx95.csv"

nyc_crash_fields <- c(
  "collision_id",
  "crash_date",
  "crash_time",
  "borough",
  "zip_code",
  "latitude",
  "longitude",
  "on_street_name",
  "cross_street_name",
  "off_street_name",
  "number_of_persons_injured",
  "number_of_persons_killed",
  "contributing_factor_vehicle_1",
  "vehicle_type_code1"
)

build_year_query <- function(year, limit, offset) {
  stopifnot(
    length(year) == 1L,
    year == as.integer(year),
    limit > 0L,
    offset >= 0L
  )

  next_year <- as.integer(year) + 1L

  list(
    `$select` = paste(nyc_crash_fields, collapse = ","),
    `$where` = sprintf(
      "crash_date >= '%d-01-01T00:00:00' AND crash_date < '%d-01-01T00:00:00'",
      as.integer(year),
      next_year
    ),
    `$order` = "collision_id",
    `$limit` = as.integer(limit),
    `$offset` = as.integer(offset)
  )
}

fetch_crash_page <- function(year, limit = 50000L, offset = 0L) {
  query <- build_year_query(year, limit, offset)
  request <- do.call(
    httr2::req_url_query,
    c(list(httr2::request(nyc_crash_endpoint)), query)
  )

  app_token <- Sys.getenv("NYC_OPEN_DATA_APP_TOKEN", unset = "")
  if (nzchar(app_token)) {
    request <- httr2::req_headers(request, `X-App-Token` = app_token)
  }

  response <- request |>
    httr2::req_user_agent("nyc-crash-injury-risk/0.1") |>
    httr2::req_retry(max_tries = 5L) |>
    httr2::req_timeout(seconds = 90) |>
    httr2::req_perform()

  httr2::resp_check_status(response)

  readr::read_csv(
    I(httr2::resp_body_string(response)),
    show_col_types = FALSE,
    progress = FALSE
  )
}

download_crash_year <- function(
    year,
    cache_dir = "data/raw",
    page_size = 50000L,
    refresh = FALSE) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_path <- file.path(cache_dir, sprintf("crashes_%d.rds", year))

  if (file.exists(cache_path) && !refresh) {
    message("Using cached data for ", year)
    return(readRDS(cache_path))
  }

  pages <- list()
  offset <- 0L

  repeat {
    message("Downloading ", year, ": offset ", format(offset, big.mark = ","))
    page <- fetch_crash_page(year, limit = page_size, offset = offset)

    if (nrow(page) == 0L) {
      break
    }

    pages[[length(pages) + 1L]] <- page

    if (nrow(page) < page_size) {
      break
    }

    offset <- offset + page_size
  }

  if (length(pages) == 0L) {
    stop("The API returned no records for ", year, call. = FALSE)
  }

  result <- dplyr::bind_rows(pages) |>
    dplyr::distinct(.data$collision_id, .keep_all = TRUE)

  saveRDS(result, cache_path, compress = "xz")
  result
}
