app_path <- testthat::test_path("..", "..", "app", "app.R")
map_path <- testthat::test_path(
  "..",
  "..",
  "outputs",
  "tables",
  "map_cells.csv.gz"
)

testthat::test_that("the Shiny application parses", {
  testthat::expect_silent(parse(file = app_path))
})

testthat::test_that("the committed map aggregate has the app schema", {
  map_cells <- readr::read_csv(map_path, show_col_types = FALSE)
  required_columns <- c(
    "crash_year",
    "borough",
    "cell_longitude",
    "cell_latitude",
    "crashes",
    "known_injury_outcomes",
    "injury_crashes"
  )

  testthat::expect_true(all(required_columns %in% names(map_cells)))
  testthat::expect_gt(nrow(map_cells), 0L)
  testthat::expect_equal(range(map_cells$crash_year), c(2013, 2025))
  testthat::expect_true(all(map_cells$injury_crashes <= map_cells$crashes))
})
