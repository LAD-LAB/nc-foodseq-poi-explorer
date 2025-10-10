# TODO: Use Real Census Population Data

## Current Status
The population density layer currently uses **simulated random density values** because the block group shapefile doesn't contain population data.

## What Needs to Be Done

### Install tidycensus Package
```r
install.packages("tidycensus")
```

### Get Census API Key
1. Go to https://api.census.gov/data/key_signup.html
2. Sign up for a free API key
3. Add it to your `~/.Renviron` file:
```bash
echo 'CENSUS_API_KEY="your_key_here"' >> ~/.Renviron
```

### Updated R Script
Use the updated script below (save to `data/scripts/02_create_population_density_geojson.R`):

```r
#!/usr/bin/env Rscript
# File: 02_create_population_density_geojson.R
# Purpose: Create GeoJSON with population density for NC block groups using real Census data

library(sf)
library(tidyverse)
library(tidycensus)

cat("Creating population density GeoJSON...\n")

# Load Census API key
readRenviron("~/.Renviron")
if (Sys.getenv("CENSUS_API_KEY") == "") {
  stop("Census API key not found. Add CENSUS_API_KEY to ~/.Renviron")
}

# Fetch NC census block groups with population (matching manuscript code)
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
nc_bg_simple <- nc_bg %>%
  st_simplify(dTolerance = 100) %>%
  select(GEOID, area_sqmi, pop_density_mi, pop_density_bin, density_category)

st_write(nc_bg_simple, "data/nc_population_density.geojson", delete_dsn = TRUE, quiet = TRUE)

cat("\n✓ Population density GeoJSON created with REAL Census data!\n")
```

### Update Visualization
After regenerating the GeoJSON with real data, update `index.html` line 817:
```javascript
const density = feature.properties.pop_density_mi;  // Change from pop_density
```

### Run the Script
```bash
Rscript data/scripts/02_create_population_density_geojson.R
```

This will match the manuscript Figure 1a exactly!
