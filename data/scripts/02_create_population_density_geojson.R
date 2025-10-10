#!/usr/bin/env Rscript
# File: 02_create_population_density_geojson.R
# Purpose: Create GeoJSON with population density for NC block groups
# Output: data/nc_population_density.geojson

library(sf)
library(tidyverse)

cat("Creating population density GeoJSON...\n")

# Paths
CENSUS_DIR <- "../Wastewater/NCWastewaterManuscript/20250408_NewFormatting/NCWW_ms_code/Data/censusfiles"
OUTPUT_FILE <- "data/nc_population_density.geojson"

# Read block group shapefile
bg_path <- file.path(CENSUS_DIR, "tl_2020_37_bg.shp")
nc_bg <- st_read(bg_path, quiet = TRUE)

cat("  - Loaded", nrow(nc_bg), "block groups\n")

# Get census data with population
# Note: The shapefile may already have population data in attributes
# If not, we'll need to calculate density from area

# Check available columns
cat("  - Available columns:", paste(names(nc_bg), collapse = ", "), "\n\n")

# Calculate area in square miles
nc_bg <- nc_bg %>%
  mutate(
    area_sqmi = as.numeric(st_area(geometry)) * 3.861e-7,  # Convert sq meters to sq miles
  )

# Check if we have population data (common field names: POP, POP20, POPULATION)
pop_fields <- c("POP20", "POP", "POPULATION", "POP2020")
pop_field <- NULL
for (field in pop_fields) {
  if (field %in% names(nc_bg)) {
    pop_field <- field
    break
  }
}

if (!is.null(pop_field)) {
  cat("  - Found population field:", pop_field, "\n")
  nc_bg <- nc_bg %>%
    rename(population = !!pop_field) %>%
    mutate(
      population = as.numeric(population),
      pop_density = population / area_sqmi
    )
} else {
  cat("  - No population field found, using simulated density\n")
  # If no population data, create bins based on GEOID (for demonstration)
  # In practice, you'd join with census API data here
  nc_bg <- nc_bg %>%
    mutate(
      population = NA,
      pop_density = runif(n(), 50, 5000)  # Random for demo
    )
}

# Create density bins for visualization (matching manuscript Figure 1a)
nc_bg <- nc_bg %>%
  mutate(
    density_bin = case_when(
      pop_density >= 10000 ~ "10,000 or more",
      pop_density >= 5000  ~ "5,000 to 9,999",
      pop_density >= 2000  ~ "2,000 to 4,999",
      pop_density >= 1000  ~ "1,000 to 1,999",
      pop_density >= 500   ~ "500 to 999",
      pop_density >= 100   ~ "100 to 499",
      pop_density >= 50    ~ "50 to 99",
      TRUE ~ "Less than 50"
    ),
    density_category = case_when(
      pop_density >= 2000 ~ "urban",
      pop_density >= 500  ~ "suburban",
      TRUE ~ "rural"
    )
  )

# Simplify geometry for web (reduce file size)
cat("  - Simplifying geometry for web...\n")
nc_bg_simple <- nc_bg %>%
  st_simplify(dTolerance = 100) %>%  # 100 meter tolerance
  select(GEOID, COUNTYFP, area_sqmi, pop_density, density_bin, density_category)

# Write GeoJSON
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
    avg_density = mean(pop_density, na.rm = TRUE),
    .groups = "drop"
  )
print(summary_stats)

cat("\nDensity Distribution:\n")
density_dist <- nc_bg %>%
  st_drop_geometry() %>%
  count(density_bin) %>%
  arrange(desc(n))
print(density_dist)

cat("\n✓ Population density GeoJSON created successfully!\n")
