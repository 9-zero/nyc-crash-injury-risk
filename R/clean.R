required_crash_columns <- c(
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

validate_crash_schema <- function(data) {
  missing_columns <- setdiff(required_crash_columns, names(data))

  if (length(missing_columns) > 0L) {
    stop(
      "Missing required columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(data)
}

blank_to_na <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  x
}

parse_crash_date <- function(x) {
  x <- trimws(as.character(x))
  slash_date <- grepl("^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$", x)
  result <- as.Date(rep(NA_character_, length(x)))

  result[slash_date] <- as.Date(x[slash_date], format = "%m/%d/%Y")
  result[!slash_date] <- as.Date(
    substr(x[!slash_date], 1L, 10L),
    format = "%Y-%m-%d"
  )

  result
}

parse_crash_hour <- function(x) {
  x <- trimws(as.character(x))
  valid <- grepl("^([01]?[0-9]|2[0-3]):[0-5][0-9]$", x)
  hour <- rep(NA_integer_, length(x))
  hour[valid] <- as.integer(sub(":.*$", "", x[valid]))
  hour
}

valid_nyc_coordinates <- function(latitude, longitude) {
  !is.na(latitude) &
    !is.na(longitude) &
    dplyr::between(latitude, 40.45, 40.95) &
    dplyr::between(longitude, -74.30, -73.65)
}

clean_crashes <- function(data) {
  validate_crash_schema(data)

  valid_boroughs <- c(
    "MANHATTAN",
    "BRONX",
    "BROOKLYN",
    "QUEENS",
    "STATEN ISLAND"
  )

  result <- data |>
    dplyr::transmute(
      collision_id = as.character(.data$collision_id),
      crash_date = parse_crash_date(.data$crash_date),
      crash_time = as.character(.data$crash_time),
      borough = toupper(blank_to_na(.data$borough)),
      zip_code = blank_to_na(.data$zip_code),
      latitude = suppressWarnings(as.numeric(.data$latitude)),
      longitude = suppressWarnings(as.numeric(.data$longitude)),
      on_street_name = blank_to_na(.data$on_street_name),
      cross_street_name = blank_to_na(.data$cross_street_name),
      off_street_name = blank_to_na(.data$off_street_name),
      persons_injured = suppressWarnings(
        as.numeric(.data$number_of_persons_injured)
      ),
      persons_killed = suppressWarnings(
        as.numeric(.data$number_of_persons_killed)
      ),
      primary_factor = blank_to_na(.data$contributing_factor_vehicle_1),
      primary_vehicle = blank_to_na(.data$vehicle_type_code1)
    ) |>
    dplyr::mutate(
      borough = dplyr::if_else(
        .data$borough %in% valid_boroughs,
        .data$borough,
        NA_character_
      ),
      persons_injured = dplyr::if_else(
        .data$persons_injured >= 0,
        .data$persons_injured,
        NA_real_
      ),
      persons_killed = dplyr::if_else(
        .data$persons_killed >= 0,
        .data$persons_killed,
        NA_real_
      ),
      location_label = dplyr::coalesce(
        .data$on_street_name,
        .data$cross_street_name,
        .data$off_street_name
      ),
      crash_hour = parse_crash_hour(.data$crash_time),
      crash_year = as.integer(format(.data$crash_date, "%Y")),
      weekend = as.POSIXlt(.data$crash_date)$wday %in% c(0L, 6L),
      rush_hour = dplyr::case_when(
        is.na(.data$crash_hour) ~ NA,
        .data$crash_hour %in% c(7L:9L, 16L:18L) ~ TRUE,
        TRUE ~ FALSE
      ),
      time_band = dplyr::case_when(
        dplyr::between(.data$crash_hour, 0L, 5L) ~ "Overnight",
        dplyr::between(.data$crash_hour, 6L, 9L) ~ "Morning",
        dplyr::between(.data$crash_hour, 10L, 15L) ~ "Midday",
        dplyr::between(.data$crash_hour, 16L, 19L) ~ "Evening",
        dplyr::between(.data$crash_hour, 20L, 23L) ~ "Night",
        TRUE ~ NA_character_
      ),
      injury_crash = dplyr::case_when(
        is.na(.data$persons_injured) ~ NA,
        .data$persons_injured > 0 ~ TRUE,
        TRUE ~ FALSE
      ),
      valid_coordinates = valid_nyc_coordinates(
        .data$latitude,
        .data$longitude
      ),
      latitude = dplyr::if_else(
        .data$valid_coordinates,
        .data$latitude,
        NA_real_
      ),
      longitude = dplyr::if_else(
        .data$valid_coordinates,
        .data$longitude,
        NA_real_
      ),
      time_band = factor(
        .data$time_band,
        levels = c("Overnight", "Morning", "Midday", "Evening", "Night")
      ),
      borough = factor(.data$borough, levels = valid_boroughs)
    ) |>
    dplyr::filter(
      !is.na(.data$collision_id),
      !is.na(.data$crash_date),
      dplyr::between(.data$crash_year, 2013L, 2025L)
    ) |>
    dplyr::distinct(.data$collision_id, .keep_all = TRUE)

  result
}
