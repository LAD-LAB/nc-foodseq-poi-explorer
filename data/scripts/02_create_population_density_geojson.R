#!/usr/bin/env Rscript
# File: 02_create_population_density_geojson.R
# Purpose: Create GeoJSON with population density for NC block groups using real Census data
# Output: data/nc_population_density.geojson

library(sf)
library(tidyverse)
library(tidycensus)

cat("Creating population density GeoJSON...\n")

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

# Fetch NC census block groups with population (matching manuscript code)
cat("  - Fetching block groups from Census API...\n")
nc_block_groups <- get_decennial(
  geography = "block group",
  variables = "P1_001N",  # Total population from 2020 Census
  year = 2020,
  state = "NC",
  geometry = TRUE
)

cat("  - Loaded", nrow(nc_block_groups), "block groups\n")

# Calculate density exactly as in manuscript
nc_bg <- nc_block_groups %>%
  mutate(
    area_sqmi = as.numeric(st_area(geometry)) * 3.861e-7,
    pop_density_mi = value / area_sqmi
  ) %>%
  filter(is.finite(pop_density_mi), pop_density_mi > 0) %>%
  mutate(
    pop_density_bin = cut(
      pop_density_mi,
      breaks = c(0, 50, 100, 500, 1000, 2000, 5000, 10000, Inf),
      labels = c(
        "Less than 50", "50 to 99", "100 to 499", "500 to 999",
        "1,000 to 1,999", "2,000 to 4,999", "5,000 to 9,999", "10,000 or more"
      ),
      include.lowest = TRUE,
      right = FALSE
    ),
    density_category = case_when(
      pop_density_mi >= 2000 ~ "urban",
      pop_density_mi >= 500  ~ "suburban",
      TRUE ~ "rural"
    )
  )

# Simplify and export
cat("  - Simplifying geometry for web...\n")
nc_bg_simple <- nc_bg %>%
  st_simplify(dTolerance = 100) %>%
  select(GEOID, area_sqmi, pop_density_mi, pop_density_bin, density_category)

OUTPUT_FILE <- "data/nc_population_density.geojson"
cat("  - Writing GeoJSON...\n")
st_write(nc_bg_simple, OUTPUT_FILE, delete_dsn = TRUE, quiet = TRUE)

file_size <- file.size(OUTPUT_FILE)
cat("  - Output file:", OUTPUT_FILE, "\n")
cat("  - File size:", format(file_size / 1024^2, digits = 2), "MB\n\n")

# Summary statistics
cat("Population Density Summary:\n")
summary_stats <- nc_bg %>%
  st_drop_geometry() %>%
  group_by(density_category) %>%
  summarise(
    n_block_groups = n(),
    avg_density = mean(pop_density_mi, na.rm = TRUE),
    .groups = "drop"
  )
print(summary_stats)

cat("\nDensity Distribution:\n")
density_dist <- nc_bg %>%
  st_drop_geometry() %>%
  count(pop_density_bin) %>%
  arrange(desc(n))
print(density_dist)

cat("\n✓ Population density GeoJSON created with REAL Census data!\n")
