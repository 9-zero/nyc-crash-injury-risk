portfolio_theme <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(color = "grey35"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "top"
    )
}

plot_annual_trend <- function(summary_data) {
  ggplot2::ggplot(
    summary_data,
    ggplot2::aes(x = .data$crash_year, y = .data$injury_rate)
  ) +
    ggplot2::geom_line(linewidth = 0.8, color = "#1F5A94") +
    ggplot2::geom_point(size = 2.2, color = "#1F5A94") +
    ggplot2::scale_x_continuous(breaks = summary_data$crash_year) +
    ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 0.1)) +
    ggplot2::labs(
      title = "Injury rate among reported crashes",
      subtitle = "New York City, complete calendar years 2013-2025",
      x = NULL,
      y = "Crashes with at least one injury"
    ) +
    portfolio_theme() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )
}

plot_hourly_pattern <- function(summary_data) {
  ggplot2::ggplot(
    summary_data,
    ggplot2::aes(x = .data$crash_hour, y = .data$injury_rate)
  ) +
    ggplot2::annotate(
      "rect",
      xmin = 7,
      xmax = 10,
      ymin = -Inf,
      ymax = Inf,
      fill = "#F4A261",
      alpha = 0.15
    ) +
    ggplot2::annotate(
      "rect",
      xmin = 16,
      xmax = 19,
      ymin = -Inf,
      ymax = Inf,
      fill = "#F4A261",
      alpha = 0.15
    ) +
    ggplot2::geom_line(linewidth = 0.8, color = "#264653") +
    ggplot2::geom_point(size = 2, color = "#264653") +
    ggplot2::scale_x_continuous(breaks = 0:23) +
    ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 0.1)) +
    ggplot2::labs(
      title = "Injury risk varies over the day",
      subtitle = "Shaded areas mark the prespecified rush-hour windows",
      x = "Hour of day",
      y = "Crashes with at least one injury"
    ) +
    portfolio_theme()
}

plot_borough_comparison <- function(summary_data, bootstrap_summary = NULL) {
  plot_data <- summary_data

  if (!is.null(bootstrap_summary)) {
    intervals <- bootstrap_summary |>
      dplyr::filter(grepl("^borough_injury_rate_", .data$metric)) |>
      dplyr::transmute(
        borough = toupper(gsub(
          "_",
          " ",
          sub("^borough_injury_rate_", "", .data$metric)
        )),
        conf_low = .data$conf_low,
        conf_high = .data$conf_high
      )

    plot_data <- plot_data |>
      dplyr::mutate(borough = as.character(.data$borough)) |>
      dplyr::left_join(intervals, by = "borough")
  } else {
    plot_data$conf_low <- NA_real_
    plot_data$conf_high <- NA_real_
  }

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = stats::reorder(.data$borough, .data$injury_rate),
      y = .data$injury_rate
    )
  ) +
    ggplot2::geom_col(fill = "#2A9D8F", width = 0.72) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = .data$conf_low, ymax = .data$conf_high),
      width = 0.18,
      na.rm = TRUE
    ) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 0.1)) +
    ggplot2::labs(
      title = "Injury rate differs across boroughs",
      x = NULL,
      y = "Crashes with at least one injury"
    ) +
    portfolio_theme()
}

plot_model_effects <- function(odds_ratios) {
  plot_data <- odds_ratios |>
    dplyr::filter(
      .data$term != "(Intercept)",
      !grepl("^crash_year", .data$term)
    ) |>
    dplyr::mutate(
      label = dplyr::recode(
        .data$term,
        "time_bandOvernight" = "Overnight vs midday",
        "time_bandMorning" = "Morning vs midday",
        "time_bandEvening" = "Evening vs midday",
        "time_bandNight" = "Night vs midday",
        "boroughBRONX" = "Bronx vs Manhattan",
        "boroughBROOKLYN" = "Brooklyn vs Manhattan",
        "boroughQUEENS" = "Queens vs Manhattan",
        "boroughSTATEN ISLAND" = "Staten Island vs Manhattan",
        "weekendTRUE" = "Weekend vs weekday",
        .default = .data$term
      )
    )

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = .data$odds_ratio,
      y = stats::reorder(.data$label, .data$odds_ratio)
    )
  ) +
    ggplot2::geom_vline(
      xintercept = 1,
      color = "grey55",
      linetype = "dashed"
    ) +
    ggplot2::geom_errorbar(
      ggplot2::aes(xmin = .data$conf_low, xmax = .data$conf_high),
      orientation = "y",
      width = 0.15,
      color = "#264653"
    ) +
    ggplot2::geom_point(size = 2.4, color = "#E76F51") +
    ggplot2::labs(
      title = "Adjusted associations with an injury-producing crash",
      subtitle = "Odds ratios with 95% Wald confidence intervals; year fixed effects omitted",
      x = "Odds ratio",
      y = NULL
    ) +
    portfolio_theme()
}

plot_crash_density <- function(map_data) {
  county_map <- ggplot2::map_data("county") |>
    dplyr::filter(
      .data$region == "new york",
      .data$subregion %in% c("bronx", "kings", "new york", "queens", "richmond")
    )

  ggplot2::ggplot() +
    ggplot2::geom_polygon(
      data = county_map,
      ggplot2::aes(
        x = .data$long,
        y = .data$lat,
        group = .data$group
      ),
      fill = "grey97",
      color = "white",
      linewidth = 0.25
    ) +
    ggplot2::geom_bin_2d(
      data = map_data,
      ggplot2::aes(x = .data$longitude, y = .data$latitude),
      bins = 85
    ) +
    ggplot2::scale_fill_viridis_c(
      trans = "sqrt",
      option = "C",
      labels = scales::label_number(big.mark = ",")
    ) +
    ggplot2::coord_fixed(
      xlim = c(-74.30, -73.65),
      ylim = c(40.45, 40.95),
      ratio = 1.3,
      expand = FALSE
    ) +
    ggplot2::labs(
      title = "Reported crash density across New York City",
      subtitle = "Year-balanced display sample, 2013-2025",
      x = NULL,
      y = NULL,
      fill = "Crashes"
    ) +
    portfolio_theme() +
    ggplot2::theme(
      axis.text = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )
}
