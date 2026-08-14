annual_summary <- function(data) {
  data |>
    dplyr::group_by(.data$crash_year) |>
    dplyr::summarise(
      crashes = dplyr::n(),
      injury_crashes = sum(.data$injury_crash, na.rm = TRUE),
      injury_rate = mean(.data$injury_crash, na.rm = TRUE),
      mean_injuries = mean(.data$persons_injured, na.rm = TRUE),
      missing_injury_count = sum(is.na(.data$persons_injured)),
      .groups = "drop"
    )
}

borough_summary <- function(data) {
  data |>
    dplyr::filter(!is.na(.data$borough)) |>
    dplyr::group_by(.data$borough) |>
    dplyr::summarise(
      crashes = dplyr::n(),
      injury_rate = mean(.data$injury_crash, na.rm = TRUE),
      mean_injuries = mean(.data$persons_injured, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$injury_rate))
}

hourly_summary <- function(data) {
  data |>
    dplyr::filter(!is.na(.data$crash_hour)) |>
    dplyr::group_by(.data$crash_hour) |>
    dplyr::summarise(
      crashes = dplyr::n(),
      injury_rate = mean(.data$injury_crash, na.rm = TRUE),
      mean_injuries = mean(.data$persons_injured, na.rm = TRUE),
      .groups = "drop"
    )
}

rush_summary <- function(data) {
  data |>
    dplyr::filter(!is.na(.data$rush_hour), !is.na(.data$injury_crash)) |>
    dplyr::group_by(.data$rush_hour) |>
    dplyr::summarise(
      crashes = dplyr::n(),
      injury_rate = mean(.data$injury_crash),
      mean_injuries = mean(.data$persons_injured, na.rm = TRUE),
      .groups = "drop"
    )
}

sample_balance_summary <- function(full_data, sample_data) {
  summarise_one <- function(data, label) {
    tibble::tibble(
      sample = label,
      crashes = nrow(data),
      mean_injuries = mean(data$persons_injured, na.rm = TRUE),
      injury_rate = mean(data$injury_crash, na.rm = TRUE),
      borough_recorded = mean(!is.na(data$borough)),
      coordinates_valid = mean(data$valid_coordinates)
    )
  }

  dplyr::bind_rows(
    summarise_one(full_data, "Full data"),
    summarise_one(sample_data, "Year-stratified 5% sample")
  )
}

dashboard_cube_summary <- function(data) {
  data |>
    dplyr::mutate(
      borough = dplyr::coalesce(as.character(.data$borough), "Not recorded"),
      time_band = dplyr::coalesce(as.character(.data$time_band), "Unknown")
    ) |>
    dplyr::group_by(
      .data$crash_year,
      .data$borough,
      .data$time_band,
      .data$weekend
    ) |>
    dplyr::summarise(
      crashes = dplyr::n(),
      known_injury_outcomes = sum(!is.na(.data$injury_crash)),
      injury_crashes = sum(.data$injury_crash, na.rm = TRUE),
      known_injury_counts = sum(!is.na(.data$persons_injured)),
      total_injuries = sum(.data$persons_injured, na.rm = TRUE),
      .groups = "drop"
    )
}

map_cell_summary <- function(data, cell_size = 0.003) {
  stopifnot(length(cell_size) == 1L, cell_size > 0)

  longitude_min <- -74.30
  latitude_min <- 40.45

  data |>
    dplyr::filter(
      .data$valid_coordinates,
      !is.na(.data$longitude),
      !is.na(.data$latitude)
    ) |>
    dplyr::mutate(
      borough = dplyr::coalesce(as.character(.data$borough), "Not recorded"),
      cell_longitude = round(
        floor((.data$longitude - longitude_min) / cell_size) * cell_size +
          longitude_min + cell_size / 2,
        6
      ),
      cell_latitude = round(
        floor((.data$latitude - latitude_min) / cell_size) * cell_size +
          latitude_min + cell_size / 2,
        6
      )
    ) |>
    dplyr::group_by(
      .data$crash_year,
      .data$borough,
      .data$cell_longitude,
      .data$cell_latitude
    ) |>
    dplyr::summarise(
      crashes = dplyr::n(),
      known_injury_outcomes = sum(!is.na(.data$injury_crash)),
      injury_crashes = sum(.data$injury_crash, na.rm = TRUE),
      .groups = "drop"
    )
}

stratified_sample <- function(data, fraction = 0.05, seed = 2026L) {
  stopifnot(fraction > 0, fraction <= 1)

  set.seed(seed)
  data |>
    dplyr::filter(!is.na(.data$crash_year)) |>
    dplyr::group_by(.data$crash_year) |>
    dplyr::slice_sample(prop = fraction) |>
    dplyr::ungroup()
}

fit_injury_model <- function(data) {
  model_data <- data |>
    dplyr::filter(
      !is.na(.data$injury_crash),
      !is.na(.data$time_band),
      !is.na(.data$borough),
      !is.na(.data$weekend),
      !is.na(.data$crash_year)
    ) |>
    dplyr::mutate(
      time_band = stats::relevel(.data$time_band, ref = "Midday"),
      borough = stats::relevel(.data$borough, ref = "MANHATTAN"),
      crash_year = factor(.data$crash_year)
    )

  stats::glm(
    injury_crash ~ time_band + borough + weekend + crash_year,
    data = model_data,
    family = stats::binomial(link = "logit")
  )
}

odds_ratio_table <- function(model) {
  broom::tidy(model) |>
    dplyr::mutate(
      odds_ratio = exp(.data$estimate),
      conf_low = exp(.data$estimate - 1.96 * .data$std.error),
      conf_high = exp(.data$estimate + 1.96 * .data$std.error)
    ) |>
    dplyr::select(
      term,
      odds_ratio,
      conf_low,
      conf_high,
      p.value
    )
}

model_fit_summary <- function(model) {
  tibble::tibble(
    observations = stats::nobs(model),
    aic = stats::AIC(model),
    null_deviance = model$null.deviance,
    residual_deviance = model$deviance
  )
}

rush_difference <- function(injury, rush) {
  complete <- !is.na(injury) & !is.na(rush)
  injury <- as.numeric(injury[complete])
  rush <- rush[complete]

  if (!any(rush) || !any(!rush)) {
    return(NA_real_)
  }

  mean(injury[rush]) - mean(injury[!rush])
}

bootstrap_metrics <- function(
    data,
    reps = 1000L,
    seed = 2026L) {
  stopifnot(reps >= 2L)

  bootstrap_data <- data |>
    dplyr::filter(
      !is.na(.data$injury_crash),
      !is.na(.data$crash_year)
    ) |>
    dplyr::select(
      crash_year,
      injury_crash,
      persons_injured,
      rush_hour,
      borough
    )

  borough_levels <- levels(droplevels(bootstrap_data$borough))
  borough_metric_names <- paste0(
    "borough_injury_rate_",
    gsub(" ", "_", tolower(borough_levels))
  )
  metric_names <- c(
    "mean_injuries",
    "injury_rate",
    "rush_mean_injury_difference",
    "rush_injury_rate_difference",
    borough_metric_names
  )

  calculate_metrics <- function(rows) {
    injury_count <- bootstrap_data$persons_injured[rows]
    injury_event <- as.numeric(bootstrap_data$injury_crash[rows])
    rush <- bootstrap_data$rush_hour[rows]
    borough <- bootstrap_data$borough[rows]

    borough_rates <- vapply(
      borough_levels,
      function(level) {
        mean(injury_event[borough == level], na.rm = TRUE)
      },
      numeric(1L)
    )

    stats::setNames(
      c(
        mean(injury_count, na.rm = TRUE),
        mean(injury_event, na.rm = TRUE),
        rush_difference(injury_count, rush),
        rush_difference(injury_event, rush),
        borough_rates
      ),
      metric_names
    )
  }

  by_year <- split(
    seq_len(nrow(bootstrap_data)),
    bootstrap_data$crash_year
  )
  observed <- calculate_metrics(seq_len(nrow(bootstrap_data)))

  set.seed(seed)
  estimates <- matrix(
    NA_real_,
    nrow = reps,
    ncol = length(metric_names),
    dimnames = list(NULL, metric_names)
  )

  for (replicate_id in seq_len(reps)) {
    rows <- unlist(
      lapply(by_year, function(year_rows) {
        sample(
          year_rows,
          size = length(year_rows),
          replace = TRUE
        )
      }),
      use.names = FALSE
    )
    estimates[replicate_id, ] <- calculate_metrics(rows)
  }

  standard_errors <- apply(estimates, 2L, stats::sd, na.rm = TRUE)
  intervals <- apply(
    estimates,
    2L,
    stats::quantile,
    probs = c(0.025, 0.975),
    na.rm = TRUE
  )

  list(
    summary = tibble::tibble(
      metric = metric_names,
      estimate = as.numeric(observed),
      bootstrap_se = as.numeric(standard_errors),
      conf_low = as.numeric(intervals[1L, ]),
      conf_high = as.numeric(intervals[2L, ]),
      reps = as.integer(reps),
      seed = as.integer(seed)
    ),
    replicates = tibble::as_tibble(estimates) |>
      dplyr::mutate(replicate = dplyr::row_number(), .before = 1L)
  )
}
