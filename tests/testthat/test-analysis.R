source(testthat::test_path("..", "..", "R", "analysis.R"))

testthat::test_that("rush differences use rush hour first", {
  testthat::expect_equal(
    rush_difference(
      injury = c(1, 0, 1, 1),
      rush = c(TRUE, TRUE, FALSE, FALSE)
    ),
    -0.5
  )
})

testthat::test_that("dashboard cells retain sufficient statistics", {
  example <- tibble::tibble(
    crash_year = c(2024L, 2024L, 2024L),
    borough = factor(c("MANHATTAN", "MANHATTAN", NA)),
    time_band = factor(c("Morning", "Morning", NA)),
    weekend = c(FALSE, FALSE, TRUE),
    injury_crash = c(TRUE, FALSE, NA),
    persons_injured = c(2, 0, NA)
  )

  result <- dashboard_cube_summary(example)
  manhattan <- result |>
    dplyr::filter(.data$borough == "MANHATTAN")

  testthat::expect_equal(manhattan$crashes, 2L)
  testthat::expect_equal(manhattan$known_injury_outcomes, 2L)
  testthat::expect_equal(manhattan$injury_crashes, 1L)
  testthat::expect_equal(manhattan$total_injuries, 2)
  testthat::expect_true("Not recorded" %in% result$borough)
  testthat::expect_true("Unknown" %in% result$time_band)
})
