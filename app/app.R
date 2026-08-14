library(bslib)
library(dplyr)
library(ggplot2)
library(here)
library(readr)
library(scales)
library(shiny)

table_dir <- here::here("outputs", "tables")

dashboard <- read_csv(
  file.path(table_dir, "dashboard_cube.csv"),
  show_col_types = FALSE
) |>
  mutate(
    crash_year = as.integer(.data$crash_year),
    weekend = as.logical(.data$weekend)
  )

bootstrap <- read_csv(
  file.path(table_dir, "bootstrap_summary.csv"),
  show_col_types = FALSE
)
odds_ratios <- read_csv(
  file.path(table_dir, "odds_ratios.csv"),
  show_col_types = FALSE
)
map_cells <- read_csv(
  file.path(table_dir, "map_cells.csv.gz"),
  show_col_types = FALSE
) |>
  mutate(crash_year = as.integer(.data$crash_year))

nyc_counties <- map_data("county") |>
  filter(
    .data$region == "new york",
    .data$subregion %in% c(
      "bronx",
      "kings",
      "new york",
      "queens",
      "richmond"
    )
  )

borough_order <- c(
  "MANHATTAN",
  "BRONX",
  "BROOKLYN",
  "QUEENS",
  "STATEN ISLAND",
  "Not recorded"
)
time_order <- c(
  "Overnight",
  "Morning",
  "Midday",
  "Evening",
  "Night",
  "Unknown"
)
map_years <- sort(unique(map_cells$crash_year), decreasing = TRUE)
map_year_choices <- c(
  "All years" = "All",
  stats::setNames(as.character(map_years), as.character(map_years))
)
map_borough_choices <- c(
  "All boroughs" = "All",
  "Bronx" = "BRONX",
  "Brooklyn" = "BROOKLYN",
  "Manhattan" = "MANHATTAN",
  "Queens" = "QUEENS",
  "Staten Island" = "STATEN ISLAND"
)
borough_subregions <- c(
  "BRONX" = "bronx",
  "BROOKLYN" = "kings",
  "MANHATTAN" = "new york",
  "QUEENS" = "queens",
  "STATEN ISLAND" = "richmond"
)

theme_dashboard <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", color = "#17324D"),
      plot.subtitle = element_text(color = "#52677D"),
      panel.grid.minor = element_blank(),
      legend.position = "none"
    )
}

metric_card <- function(label, value, note = NULL) {
  div(
    class = "metric-card",
    div(class = "metric-label", label),
    div(class = "metric-value", value),
    if (!is.null(note)) div(class = "metric-note", note)
  )
}

ui <- navbarPage(
  title = "NYC Crash Injury Risk",
  id = "navigation",
  theme = bs_theme(
    version = 5,
    bg = "#F6F8FB",
    fg = "#17324D",
    primary = "#1F5A94",
    base_font = font_google("Source Sans 3"),
    heading_font = font_google("Source Sans 3")
  ),
  header = tagList(
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
    div(
      class = "hero",
      div(
        class = "hero-inner",
        tags$h1("When and where do reported NYC crashes involve injury?"),
        tags$p(
          "Explore 2.13 million police-reported crashes from complete calendar years 2013-2025."
        )
      )
    )
  ),
  tabPanel(
    "Explore",
    div(
      class = "page-shell",
      sidebarLayout(
        sidebarPanel(
          class = "filter-panel",
          sliderInput(
            "years",
            "Calendar years",
            min = min(dashboard$crash_year),
            max = max(dashboard$crash_year),
            value = range(dashboard$crash_year),
            sep = ""
          ),
          selectInput(
            "borough",
            "Borough",
            choices = c("All records", borough_order),
            selected = "All records"
          ),
          checkboxGroupInput(
            "time_band",
            "Time of day",
            choices = time_order,
            selected = time_order
          ),
          radioButtons(
            "day_type",
            "Day type",
            choices = c("All days", "Weekday", "Weekend"),
            selected = "All days"
          ),
          downloadButton("download_summary", "Download filtered summary"),
          tags$p(
            class = "filter-note",
            "Rates describe injury among reported crashes. They are not population or travel-exposure rates."
          )
        ),
        mainPanel(
          fluidRow(
            column(4, uiOutput("crash_card")),
            column(4, uiOutput("rate_card")),
            column(4, uiOutput("mean_card"))
          ),
          div(class = "chart-card", plotOutput("year_plot", height = 360)),
          fluidRow(
            column(6, div(class = "chart-card", plotOutput("borough_plot", height = 360))),
            column(6, div(class = "chart-card", plotOutput("time_plot", height = 360)))
          )
        )
      )
    )
  ),
  tabPanel(
    "Model & uncertainty",
    div(
      class = "page-shell",
      fluidRow(
        column(
          7,
          div(
            class = "chart-card",
            plotOutput("model_plot", height = 520)
          )
        ),
        column(
          5,
          div(
            class = "text-card",
            tags$h3("How to read this model"),
            tags$p(
              "The logistic regression adjusts for time band, borough, weekend status, and calendar-year fixed effects."
            ),
            tags$p(
              "Odds ratios are associations within reported crash records; they do not identify causal effects."
            ),
            tags$hr(),
            tags$h3("Year-stratified bootstrap"),
            tableOutput("bootstrap_table")
          )
        )
      )
    )
  ),
  tabPanel(
    "Spatial context",
    div(
      class = "page-shell",
      sidebarLayout(
        sidebarPanel(
          class = "filter-panel",
          selectInput(
            "map_year",
            "Calendar year",
            choices = map_year_choices,
            selected = "2025"
          ),
          selectInput(
            "map_borough",
            "Reported borough",
            choices = map_borough_choices,
            selected = "All"
          ),
          downloadButton("download_map_data", "Download mapped cells"),
          tags$p(
            class = "filter-note",
            "Each colored cell aggregates nearby crash coordinates. The map shows reported crash density, not risk per trip or mile traveled."
          )
        ),
        mainPanel(
          fluidRow(
            column(4, uiOutput("map_crash_card")),
            column(4, uiOutput("map_rate_card")),
            column(4, uiOutput("map_cell_card"))
          ),
          div(
            class = "chart-card map-chart-card",
            plotOutput("density_map", height = 680)
          )
        )
      )
    )
  ),
  tabPanel(
    "About",
    div(
      class = "page-shell narrow-page",
      div(
        class = "text-card",
        tags$h2("Research question"),
        tags$blockquote(
          "How are time of day and borough associated with the probability that a police-reported NYC crash results in at least one injury?"
        ),
        tags$h2("Design"),
        tags$p(
          "Descriptive summaries use all 2013-2025 records. The logistic model and 1,000-replicate bootstrap use a fixed 5% sample within each year. Bootstrap resampling is stratified by year."
        ),
        tags$h2("Key limitations"),
        tags$ul(
          tags$li("Police-reported crashes may not represent unreported events."),
          tags$li("No denominator is available for trips, miles traveled, or road use."),
          tags$li("Traffic volume, speed, weather, road design, and vehicle mix are not modeled."),
          tags$li("A large sample improves precision but does not solve measurement or causal-identification problems.")
        ),
        tags$p(
          tags$a(
            href = "https://data.cityofnewyork.us/Public-Safety/Motor-Vehicle-Collisions-Crashes/h9gi-nx95",
            target = "_blank",
            "Official NYC Open Data source"
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  filtered_cube <- reactive({
    req(length(input$time_band) > 0L)

    result <- dashboard |>
      filter(
        dplyr::between(.data$crash_year, input$years[1], input$years[2]),
        .data$time_band %in% input$time_band
      )

    if (input$borough != "All records") {
      result <- result |>
        filter(.data$borough == input$borough)
    }
    if (input$day_type == "Weekday") {
      result <- result |>
        filter(!.data$weekend)
    }
    if (input$day_type == "Weekend") {
      result <- result |>
        filter(.data$weekend)
    }

    result
  })

  aggregate_cube <- function(data, ...) {
    data |>
      group_by(...) |>
      summarise(
        crashes = sum(.data$crashes),
        known_injury_outcomes = sum(.data$known_injury_outcomes),
        injury_crashes = sum(.data$injury_crashes),
        known_injury_counts = sum(.data$known_injury_counts),
        total_injuries = sum(.data$total_injuries),
        .groups = "drop"
      ) |>
      mutate(
        injury_rate = .data$injury_crashes / .data$known_injury_outcomes,
        mean_injuries = .data$total_injuries / .data$known_injury_counts
      )
  }

  totals <- reactive({
    result <- aggregate_cube(filtered_cube())
    validate(need(nrow(result) == 1L && result$crashes > 0L, "No records match these filters."))
    result
  })

  output$crash_card <- renderUI({
    metric_card("Reported crashes", comma(totals()$crashes))
  })
  output$rate_card <- renderUI({
    metric_card(
      "Injury-producing crashes",
      percent(totals()$injury_rate, accuracy = 0.1),
      "Among records with a known injury outcome"
    )
  })
  output$mean_card <- renderUI({
    metric_card(
      "Mean injuries per crash",
      number(totals()$mean_injuries, accuracy = 0.001)
    )
  })

  output$year_plot <- renderPlot({
    plot_data <- aggregate_cube(filtered_cube(), .data$crash_year)

    ggplot(plot_data, aes(x = .data$crash_year, y = .data$injury_rate)) +
      geom_line(linewidth = 0.9, color = "#1F5A94") +
      geom_point(size = 2.4, color = "#1F5A94") +
      scale_x_continuous(breaks = sort(unique(plot_data$crash_year))) +
      scale_y_continuous(labels = label_percent(accuracy = 0.1)) +
      labs(
        title = "Injury rate by calendar year",
        subtitle = "Filtered records",
        x = NULL,
        y = "Injury-producing crashes"
      ) +
      theme_dashboard() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })

  output$borough_plot <- renderPlot({
    plot_data <- aggregate_cube(filtered_cube(), .data$borough) |>
      mutate(
        borough = factor(.data$borough, levels = borough_order),
        borough_label = tools::toTitleCase(tolower(as.character(.data$borough)))
      )

    ggplot(
      plot_data,
      aes(
        x = reorder(.data$borough_label, .data$injury_rate),
        y = .data$injury_rate
      )
    ) +
      geom_col(fill = "#2A9D8F", width = 0.7) +
      coord_flip() +
      scale_y_continuous(labels = label_percent(accuracy = 0.1)) +
      labs(
        title = "Borough comparison",
        x = NULL,
        y = "Injury-producing crashes"
      ) +
      theme_dashboard()
  })

  output$time_plot <- renderPlot({
    plot_data <- aggregate_cube(filtered_cube(), .data$time_band) |>
      mutate(time_band = factor(.data$time_band, levels = time_order))

    ggplot(plot_data, aes(x = .data$time_band, y = .data$injury_rate)) +
      geom_col(fill = "#E76F51", width = 0.7) +
      scale_y_continuous(labels = label_percent(accuracy = 0.1)) +
      labs(
        title = "Time-of-day comparison",
        x = NULL,
        y = "Injury-producing crashes"
      ) +
      theme_dashboard() +
      theme(axis.text.x = element_text(angle = 25, hjust = 1))
  })

  output$model_plot <- renderPlot({
    plot_data <- odds_ratios |>
      filter(.data$term != "(Intercept)", !grepl("^crash_year", .data$term)) |>
      mutate(
        label = recode(
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

    ggplot(
      plot_data,
      aes(x = .data$odds_ratio, y = reorder(.data$label, .data$odds_ratio))
    ) +
      geom_vline(xintercept = 1, color = "grey55", linetype = "dashed") +
      geom_errorbar(
        aes(xmin = .data$conf_low, xmax = .data$conf_high),
        orientation = "y",
        width = 0.15,
        color = "#264653"
      ) +
      geom_point(size = 2.7, color = "#E76F51") +
      labs(
        title = "Adjusted associations with an injury-producing crash",
        subtitle = "Odds ratios and 95% Wald confidence intervals",
        x = "Odds ratio",
        y = NULL
      ) +
      theme_dashboard()
  })

  output$bootstrap_table <- renderTable({
    label_map <- c(
      mean_injuries = "Mean injuries",
      injury_rate = "Injury rate",
      rush_mean_injury_difference = "Rush difference: mean injuries",
      rush_injury_rate_difference = "Rush difference: injury rate"
    )

    bootstrap |>
      filter(.data$metric %in% names(label_map)) |>
      transmute(
        Estimand = recode(.data$metric, !!!label_map),
        Estimate = round(.data$estimate, 4),
        `95% CI` = paste0(
          "[",
          round(.data$conf_low, 4),
          ", ",
          round(.data$conf_high, 4),
          "]"
        )
      )
  }, striped = TRUE, bordered = FALSE, spacing = "s")

  filtered_map_cells <- reactive({
    result <- map_cells

    if (input$map_year != "All") {
      result <- result |>
        filter(.data$crash_year == as.integer(input$map_year))
    }
    if (input$map_borough != "All") {
      result <- result |>
        filter(.data$borough == input$map_borough)
    }

    result |>
      group_by(.data$cell_longitude, .data$cell_latitude) |>
      summarise(
        crashes = sum(.data$crashes),
        known_injury_outcomes = sum(.data$known_injury_outcomes),
        injury_crashes = sum(.data$injury_crashes),
        .groups = "drop"
      ) |>
      mutate(
        injury_rate = .data$injury_crashes / .data$known_injury_outcomes
      )
  })

  map_totals <- reactive({
    result <- filtered_map_cells()
    validate(need(nrow(result) > 0L, "No mapped crashes match these filters."))

    result |>
      summarise(
        crashes = sum(.data$crashes),
        known_injury_outcomes = sum(.data$known_injury_outcomes),
        injury_crashes = sum(.data$injury_crashes),
        occupied_cells = dplyr::n()
      ) |>
      mutate(
        injury_rate = .data$injury_crashes / .data$known_injury_outcomes
      )
  })

  map_labels <- reactive({
    year <- if (input$map_year == "All") "2013-2025" else input$map_year
    borough <- if (input$map_borough == "All") {
      "New York City"
    } else {
      names(map_borough_choices)[map_borough_choices == input$map_borough]
    }

    list(year = year, borough = unname(borough))
  })

  map_limits <- reactive({
    if (input$map_borough == "All") {
      return(list(
        x = c(-74.30, -73.65),
        y = c(40.45, 40.95)
      ))
    }

    boundary <- nyc_counties |>
      filter(.data$subregion == borough_subregions[[input$map_borough]])
    x_range <- range(boundary$long, na.rm = TRUE)
    y_range <- range(boundary$lat, na.rm = TRUE)
    x_padding <- max(diff(x_range) * 0.10, 0.012)
    y_padding <- max(diff(y_range) * 0.10, 0.012)

    list(
      x = x_range + c(-x_padding, x_padding),
      y = y_range + c(-y_padding, y_padding)
    )
  })

  output$map_crash_card <- renderUI({
    metric_card(
      "Mapped crashes",
      comma(map_totals()$crashes),
      "Records with valid NYC coordinates"
    )
  })
  output$map_rate_card <- renderUI({
    metric_card(
      "Injury-producing crashes",
      percent(map_totals()$injury_rate, accuracy = 0.1),
      "Among mapped records with a known outcome"
    )
  })
  output$map_cell_card <- renderUI({
    metric_card(
      "Occupied map cells",
      comma(map_totals()$occupied_cells),
      "Approximately 0.003° coordinate bins"
    )
  })

  output$density_map <- renderPlot({
    plot_data <- filtered_map_cells()
    labels <- map_labels()
    limits <- map_limits()

    ggplot() +
      geom_polygon(
        data = nyc_counties,
        aes(x = .data$long, y = .data$lat, group = .data$group),
        fill = "#E9EFF4",
        color = "white",
        linewidth = 0.35
      ) +
      geom_tile(
        data = plot_data,
        aes(
          x = .data$cell_longitude,
          y = .data$cell_latitude,
          fill = .data$crashes
        ),
        width = 0.003,
        height = 0.003,
        alpha = 0.88
      ) +
      scale_fill_viridis_c(
        option = "C",
        trans = "sqrt",
        begin = 0.08,
        end = 0.95,
        labels = label_number(big.mark = ","),
        guide = guide_colorbar(
          title.position = "top",
          barheight = grid::unit(3.2, "cm")
        )
      ) +
      coord_fixed(
        xlim = limits$x,
        ylim = limits$y,
        ratio = 1.3,
        expand = FALSE
      ) +
      labs(
        title = paste("Reported crash density —", labels$borough),
        subtitle = paste0(
          labels$year,
          "; color encodes the number of reported crashes in each coordinate cell"
        ),
        fill = "Crashes"
      ) +
      theme_void(base_size = 13) +
      theme(
        plot.title = element_text(
          face = "bold",
          color = "#17324D",
          size = 17,
          margin = margin(b = 5)
        ),
        plot.subtitle = element_text(
          color = "#52677D",
          margin = margin(b = 14)
        ),
        legend.position = "right",
        legend.title = element_text(face = "bold"),
        plot.margin = margin(12, 12, 12, 12)
      )
  }, res = 120)

  output$download_map_data <- downloadHandler(
    filename = function() {
      paste0(
        "nyc-crash-map-",
        tolower(gsub(" ", "-", map_labels()$borough)),
        "-",
        map_labels()$year,
        ".csv"
      )
    },
    content = function(file) {
      filtered_map_cells() |>
        write_csv(file)
    }
  )

  output$download_summary <- downloadHandler(
    filename = function() {
      paste0("nyc-crash-summary-", Sys.Date(), ".csv")
    },
    content = function(file) {
      aggregate_cube(
        filtered_cube(),
        .data$crash_year,
        .data$borough,
        .data$time_band,
        .data$weekend
      ) |>
        write_csv(file)
    }
  )
}

shinyApp(ui, server)
