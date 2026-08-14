source(file.path("R", "clean.R"))

example_crashes <- tibble::tibble(
  collision_id = c("1", "2", "3"),
  crash_date = c(
    "2025-01-01T00:00:00.000",
    "2025-06-15T00:00:00.000",
    "2025-09-01T00:00:00.000"
  ),
  crash_time = c("08:30", "23:05", "not-a-time"),
  borough = c("brooklyn", "MANHATTAN", "UNKNOWN"),
  zip_code = c("11201", "10001", ""),
  latitude = c("40.70", "0", "41.50"),
  longitude = c("-73.95", "0", "-75.00"),
  on_street_name = c(" Flatbush Ave ", "", NA),
  cross_street_name = c("", "Broadway", NA),
  off_street_name = c(NA, NA, "1 Test Plaza"),
  number_of_persons_injured = c("1", "0", NA),
  number_of_persons_killed = c("0", "0", "0"),
  contributing_factor_vehicle_1 = c("Driver Inattention", "", NA),
  vehicle_type_code1 = c("Sedan", "Bike", "Taxi")
)

testthat::test_that("crash hours are parsed without relying on datetime coercion", {
  testthat::expect_equal(parse_crash_hour(c("00:01", "9:05", "23:59")), c(0L, 9L, 23L))
  testthat::expect_true(is.na(parse_crash_hour("24:00")))
  testthat::expect_true(is.na(parse_crash_hour("bad")))
})

testthat::test_that("both API and downloaded CSV date formats are parsed", {
  testthat::expect_equal(
    parse_crash_date(c("2025-01-02T00:00:00.000", "01/02/2025")),
    as.Date(c("2025-01-02", "2025-01-02"))
  )
})

testthat::test_that("cleaning preserves missing injury counts", {
  cleaned <- clean_crashes(example_crashes)
  testthat::expect_true(is.na(cleaned$persons_injured[cleaned$collision_id == "3"]))
  testthat::expect_true(is.na(cleaned$injury_crash[cleaned$collision_id == "3"]))
})

testthat::test_that("coordinates are restricted to the NYC bounding box", {
  cleaned <- clean_crashes(example_crashes)
  testthat::expect_true(cleaned$valid_coordinates[cleaned$collision_id == "1"])
  testthat::expect_false(cleaned$valid_coordinates[cleaned$collision_id == "2"])
  testthat::expect_true(is.na(cleaned$latitude[cleaned$collision_id == "2"]))
  testthat::expect_true(is.na(cleaned$longitude[cleaned$collision_id == "3"]))
})

testthat::test_that("location labels use the first available street field", {
  cleaned <- clean_crashes(example_crashes)
  testthat::expect_equal(
    as.character(cleaned$location_label),
    c("Flatbush Ave", "Broadway", "1 Test Plaza")
  )
})
