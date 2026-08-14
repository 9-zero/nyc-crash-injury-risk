# Analysis codebook

The cleaned analysis file contains one row per unique `collision_id` from the
official NYC crash table. Names below refer to variables created by
`R/clean.R`.

| Variable | Type | Definition |
| --- | --- | --- |
| `collision_id` | character | Unique crash identifier supplied by NYC Open Data. |
| `crash_date` | Date | Calendar date parsed from the source timestamp. |
| `crash_time` | character | Original reported local clock time. |
| `crash_hour` | integer | Hour from 0 through 23 parsed from `crash_time`. Invalid times are missing. |
| `crash_year` | integer | Calendar year of `crash_date`. The analysis retains 2013-2025. |
| `borough` | factor | One of Manhattan, Bronx, Brooklyn, Queens, or Staten Island. Other values are missing. |
| `zip_code` | character | Reported ZIP code, when available. |
| `latitude`, `longitude` | numeric | Coordinates retained only when they fall inside the prespecified NYC bounding box. |
| `valid_coordinates` | logical | Whether both coordinates fall within latitude 40.45-40.95 and longitude -74.30 to -73.65. |
| `location_label` | character | First nonmissing value among on-street, cross-street, and off-street fields. |
| `persons_injured` | numeric | Reported number injured. Missing values remain missing. |
| `persons_killed` | numeric | Reported number killed. Missing values remain missing. |
| `injury_crash` | logical | `TRUE` when `persons_injured > 0`, `FALSE` when the reported count equals 0, and missing otherwise. |
| `weekend` | logical | Saturday or Sunday based on `crash_date`. |
| `rush_hour` | logical | 7:00-9:59 or 16:00-18:59; missing when the clock time is invalid. |
| `time_band` | ordered categories | Overnight 0-5, morning 6-9, midday 10-15, evening 16-19, and night 20-23. |
| `primary_factor` | character | First contributing-factor field reported for the crash. It is not interpreted causally. |
| `primary_vehicle` | character | First vehicle-type field reported for the crash. |

## Analysis samples

- **Descriptive sample:** all cleaned records from complete calendar years
  2013-2025.
- **Model sample:** a fixed 5% simple random sample within each calendar year,
  using seed 2026.
- **Dashboard map sample:** at most 5,000 records with valid coordinates per
  year, also using seed 2026.

## Missing-data rule

The original course code replaced missing injury and death counts with zero.
This version does not make that assumption. Rates and models exclude records
whose injury outcome is unknown, and summary tables report the number of missing
injury counts by year.
