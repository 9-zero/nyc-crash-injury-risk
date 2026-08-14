normalize_source_names <- function(names) {
  normalized <- tolower(names)
  normalized <- gsub("[^a-z0-9]+", "_", normalized)
  normalized <- gsub("^_+|_+$", "", normalized)

  normalized[normalized == "vehicle_type_code_1"] <- "vehicle_type_code1"
  normalized
}

read_local_crash_csv <- function(path) {
  if (!file.exists(path)) {
    stop("Local crash CSV does not exist: ", path, call. = FALSE)
  }

  readr::read_csv(
    path,
    name_repair = normalize_source_names,
    col_select = dplyr::all_of(nyc_crash_fields),
    show_col_types = FALSE,
    progress = interactive()
  )
}

source_year <- function(crash_date) {
  crash_date <- as.character(crash_date)
  slash_date <- grepl("^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$", crash_date)
  year <- rep(NA_integer_, length(crash_date))
  year[slash_date] <- suppressWarnings(
    as.integer(sub("^.*/", "", crash_date[slash_date]))
  )
  year[!slash_date] <- suppressWarnings(
    as.integer(substr(crash_date[!slash_date], 1L, 4L))
  )
  year
}

cache_local_crash_csv <- function(
    path,
    cache_dir = "data/raw",
    years = 2013L:2025L,
    refresh = FALSE) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

  expected_paths <- file.path(
    cache_dir,
    sprintf("crashes_%d.rds", years)
  )
  if (all(file.exists(expected_paths)) && !refresh) {
    message("Using existing yearly cache files")
    return(invisible(expected_paths))
  }

  local_data <- read_local_crash_csv(path)
  local_data$source_year <- source_year(local_data$crash_date)

  for (year in years) {
    year_data <- local_data[local_data$source_year == year, , drop = FALSE]
    year_data$source_year <- NULL

    saveRDS(
      year_data,
      file.path(cache_dir, sprintf("crashes_%d.rds", year)),
      compress = "xz"
    )
  }

  invisible(expected_paths)
}
