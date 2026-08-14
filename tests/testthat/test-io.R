source(file.path("R", "io.R"))

testthat::test_that("source column names normalize to the API schema", {
  original <- c(
    "CRASH DATE",
    "NUMBER OF PERSONS INJURED",
    "VEHICLE TYPE CODE 1"
  )

  testthat::expect_equal(
    normalize_source_names(original),
    c(
      "crash_date",
      "number_of_persons_injured",
      "vehicle_type_code1"
    )
  )
})

testthat::test_that("calendar years parse from both source formats", {
  testthat::expect_equal(
    source_year(c("01/02/2025", "2024-12-31T00:00:00.000")),
    c(2025L, 2024L)
  )
})
