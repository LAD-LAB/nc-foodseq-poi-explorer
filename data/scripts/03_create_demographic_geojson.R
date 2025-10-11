#!/usr/bin/env Rscript
# File: 03_create_demographic_geojson.R
# Purpose: Create GeoJSON with demographic/economic data for NC census tracts
# Output: data/nc_demographics.geojson
#
# Variables included:
# 1. Median household income
# 2. % Foreign born
# 3. % White
# 4. % Black
# 5. % Asian
# 6. % Hispanic/Latino

library(sf)
library(tidyverse)
library(tidycensus)

cat("Creating demographic GeoJSON for NC census tracts...\n")

# Load Census API key from .env file
env_file <- ".env"
if (file.exists(env_file)) {
  env_vars <- readLines(env_file)
  for (line in env_vars) {
    # Skip comments and empty lines
    if (!grepl("^#", line) && nchar(trimws(line)) > 0) {
      # Parse KEY=VALUE
      parts <- strsplit(line, "=")[[1]]
      if (length(parts) == 2) {
        key <- trimws(parts[1])
        value <- trimws(parts[2])
        if (key == "CENSUS_API_KEY") {
          Sys.setenv(CENSUS_API_KEY = value)
          cat("  - Loaded Census API key from .env\n")
        }
      }
    }
  }
}

# Check if API key is available
if (Sys.getenv("CENSUS_API_KEY") == "") {
  stop("Census API key not found. Please add CENSUS_API_KEY to .env file")
}

# Set the API key for tidycensus
census_api_key(Sys.getenv("CENSUS_API_KEY"))

# Define variables to fetch from ACS 5-year estimates
cat("  - Fetching demographic data from Census API...\n")
cat("  - Using ACS 5-year estimates (2019-2023)...\n")

# Fetch all variables in one call for efficiency
acs_vars <- c(
  # Median household income
  "B19013_001",

  # Foreign born population
  "B05002_013",  # Foreign born
  "B05002_001",  # Total population for foreign born calculation

  # Race variables
  "B02001_001",  # Total population for race
  "B02001_002",  # White alone
  "B02001_003",  # Black or African American alone
  "B02001_005",  # Asian alone

  # Hispanic/Latino ethnicity
  "B03003_001",  # Total population for Hispanic origin
  "B03003_003"   # Hispanic or Latino
)

nc_tracts <- get_acs(
  geography = "tract",
  variables = acs_vars,
  state = "NC",
  year = 2023,
  survey = "acs5",
  geometry = TRUE,
  output = "wide"
)

cat("  - Loaded", nrow(nc_tracts), "census tracts\n")

# Calculate demographic percentages and organize data
nc_demographics <- nc_tracts %>%
  mutate(
    # Median household income (raw value)
    median_income = B19013_001E,

    # % Foreign born
    pct_foreign_born = (B05002_013E / B05002_001E) * 100,

    # % White
    pct_white = (B02001_002E / B02001_001E) * 100,

    # % Black
    pct_black = (B02001_003E / B02001_001E) * 100,

    # % Asian
    pct_asian = (B02001_005E / B02001_001E) * 100,

    # % Hispanic/Latino
    pct_hispanic = (B03003_003E / B03003_001E) * 100
  ) %>%
  # Handle missing/invalid values
  mutate(
    across(starts_with("pct_"), ~ifelse(is.na(.) | is.infinite(.), 0, .)),
    median_income = ifelse(is.na(median_income) | median_income < 0, NA, median_income)
  ) %>%
  # Select only needed columns
  select(
    GEOID, NAME,
    median_income,
    pct_foreign_born,
    pct_white,
    pct_black,
    pct_asian,
    pct_hispanic,
    geometry
  )

# Create categorical bins for better visualization
nc_demographics <- nc_demographics %>%
  mutate(
    # Income bins (in thousands)
    income_bin = cut(
      median_income,
      breaks = c(0, 30000, 40000, 50000, 60000, 75000, 100000, 150000, Inf),
      labels = c(
        "Under $30k", "$30k-$40k", "$40k-$50k", "$50k-$60k",
        "$60k-$75k", "$75k-$100k", "$100k-$150k", "Over $150k"
      ),
      include.lowest = TRUE
    ),

    # Percentage bins (0-100 scale)
    foreign_born_bin = cut(
      pct_foreign_born,
      breaks = c(0, 2, 5, 10, 15, 20, 30, 40, 100),
      labels = c(
        "0-2%", "2-5%", "5-10%", "10-15%",
        "15-20%", "20-30%", "30-40%", "Over 40%"
      ),
      include.lowest = TRUE
    ),

    white_bin = cut(
      pct_white,
      breaks = c(0, 20, 40, 50, 60, 70, 80, 90, 100),
      labels = c(
        "0-20%", "20-40%", "40-50%", "50-60%",
        "60-70%", "70-80%", "80-90%", "90-100%"
      ),
      include.lowest = TRUE
    ),

    black_bin = cut(
      pct_black,
      breaks = c(0, 5, 10, 20, 30, 40, 60, 80, 100),
      labels = c(
        "0-5%", "5-10%", "10-20%", "20-30%",
        "30-40%", "40-60%", "60-80%", "Over 80%"
      ),
      include.lowest = TRUE
    ),

    asian_bin = cut(
      pct_asian,
      breaks = c(0, 1, 2, 3, 5, 7, 10, 15, 100),
      labels = c(
        "0-1%", "1-2%", "2-3%", "3-5%",
        "5-7%", "7-10%", "10-15%", "Over 15%"
      ),
      include.lowest = TRUE
    ),

    hispanic_bin = cut(
      pct_hispanic,
      breaks = c(0, 3, 5, 10, 15, 20, 30, 40, 100),
      labels = c(
        "0-3%", "3-5%", "5-10%", "10-15%",
        "15-20%", "20-30%", "30-40%", "Over 40%"
      ),
      include.lowest = TRUE
    )
  )

# Simplify geometry for web performance
cat("  - Simplifying geometry for web...\n")
nc_demographics_simple <- nc_demographics %>%
  st_simplify(dTolerance = 100) %>%
  st_transform(4326)  # Ensure WGS84 projection

OUTPUT_FILE <- "data/nc_demographics.geojson"
cat("  - Writing GeoJSON...\n")
st_write(nc_demographics_simple, OUTPUT_FILE, delete_dsn = TRUE, quiet = TRUE)

file_size <- file.size(OUTPUT_FILE)
cat("  - Output file:", OUTPUT_FILE, "\n")
cat("  - File size:", format(file_size / 1024^2, digits = 2), "MB\n\n")

# Summary statistics
cat("======================================================================\n")
cat("DEMOGRAPHIC DATA SUMMARY\n")
cat("======================================================================\n\n")

cat("Median Household Income:\n")
income_summary <- nc_demographics %>%
  st_drop_geometry() %>%
  summarise(
    min = min(median_income, na.rm = TRUE),
    q25 = quantile(median_income, 0.25, na.rm = TRUE),
    median = median(median_income, na.rm = TRUE),
    q75 = quantile(median_income, 0.75, na.rm = TRUE),
    max = max(median_income, na.rm = TRUE),
    mean = mean(median_income, na.rm = TRUE)
  )
print(income_summary)

cat("\n% Foreign Born:\n")
cat("  Mean:", round(mean(nc_demographics$pct_foreign_born, na.rm = TRUE), 2), "%\n")
cat("  Range:", round(min(nc_demographics$pct_foreign_born, na.rm = TRUE), 2), "% to",
    round(max(nc_demographics$pct_foreign_born, na.rm = TRUE), 2), "%\n")

cat("\n% White:\n")
cat("  Mean:", round(mean(nc_demographics$pct_white, na.rm = TRUE), 2), "%\n")
cat("  Range:", round(min(nc_demographics$pct_white, na.rm = TRUE), 2), "% to",
    round(max(nc_demographics$pct_white, na.rm = TRUE), 2), "%\n")

cat("\n% Black:\n")
cat("  Mean:", round(mean(nc_demographics$pct_black, na.rm = TRUE), 2), "%\n")
cat("  Range:", round(min(nc_demographics$pct_black, na.rm = TRUE), 2), "% to",
    round(max(nc_demographics$pct_black, na.rm = TRUE), 2), "%\n")

cat("\n% Asian:\n")
cat("  Mean:", round(mean(nc_demographics$pct_asian, na.rm = TRUE), 2), "%\n")
cat("  Range:", round(min(nc_demographics$pct_asian, na.rm = TRUE), 2), "% to",
    round(max(nc_demographics$pct_asian, na.rm = TRUE), 2), "%\n")

cat("\n% Hispanic/Latino:\n")
cat("  Mean:", round(mean(nc_demographics$pct_hispanic, na.rm = TRUE), 2), "%\n")
cat("  Range:", round(min(nc_demographics$pct_hispanic, na.rm = TRUE), 2), "% to",
    round(max(nc_demographics$pct_hispanic, na.rm = TRUE), 2), "%\n")

cat("\n✓ Demographic GeoJSON created successfully!\n")
cat("✓ Ready to visualize in index.html\n")
