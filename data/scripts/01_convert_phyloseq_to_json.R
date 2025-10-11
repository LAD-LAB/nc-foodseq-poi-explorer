#!/usr/bin/env Rscript
# File: 01_convert_phyloseq_to_json.R
# Author: Anna Bauer (adapted from NCWW manuscript code)
# Date: 2025-10-10 (Updated)
# Purpose: Convert phyloseq RDS files to JSON format for FoodSeq web visualization
#
# Input:
#   - Manuscript data: NCWW_allsamples_animal.rds
#   - Manuscript data: NCWW_allsamples_trnL.rds
#   - Lab food group mappings: asv_to_foodgroup_trnL.csv, asv_to_foodgroup_12S.csv
#   - Color theme: food_group_theme.csv
# Output:
#   - data/processed/foodseq_data.json (visualization format)
#
# Design Decisions:
#   1. Missing coordinates: Use county centroid as fallback
#   2. Sample aggregation: Average read counts for multiple samples per location/month
#   3. Normalization: CLR (Centered Log-Ratio) transformation for compositional data
#   4. Location handling: Keep all Charlotte plants (1-4) as separate locations
#   5. NA handling: Smart hybrid approach
#      - Keep NAs with valid metadata (genus-level IDs like "Allium NA")
#      - Aggregate true unknowns into "Unidentified" category

# ============================================================================
# SETUP
# ============================================================================

# Load required libraries
library(phyloseq)
library(tidyverse)
library(jsonlite)

# Set paths relative to project root
# Assumes script is run from project root: nc-foodseq-viz/
MANUSCRIPT_DATA_DIR <- "../Wastewater/NCWastewaterManuscript/20250408_NewFormatting/NCWW_ms_code/Data"
OUTPUT_FILE <- "data/processed/foodseq_data.json"

# Lab food group mapping files
PLANT_FOOD_MAP <- "data/raw/asv_to_foodgroup_trnL.csv"
ANIMAL_FOOD_MAP <- "data/raw/asv_to_foodgroup_12S.csv"
COLOR_THEME <- "data/raw/food_group_theme.csv"

cat("Starting phyloseq to JSON conversion...\n")
cat("Input directory:", MANUSCRIPT_DATA_DIR, "\n")
cat("Output file:", OUTPUT_FILE, "\n\n")

# ============================================================================
# LOAD LAB'S FOOD GROUP MAPPINGS
# ============================================================================

cat("Loading lab's food group mappings...\n")

# Load plant ASV -> food group mapping
plant_fg_map <- read_csv(PLANT_FOOD_MAP, show_col_types = FALSE) %>%
  rename(asv_seq = asv)
cat("  - Loaded", nrow(plant_fg_map), "plant ASV food group mappings\n")

# Load animal ASV -> food group mapping
animal_fg_map <- read_csv(ANIMAL_FOOD_MAP, show_col_types = FALSE) %>%
  rename(asv_seq = asv)
cat("  - Loaded", nrow(animal_fg_map), "animal ASV food group mappings\n")

# Load color theme
color_theme <- read_csv(COLOR_THEME, show_col_types = FALSE)
cat("  - Loaded", nrow(color_theme), "food group colors\n\n")

# ============================================================================
# NORMALIZE OLD FOOD GROUPS TO LAB'S CATEGORIES
# ============================================================================

# Function to normalize old detailed food groups to broad lab categories
normalize_food_group <- function(fg) {
  fg_lower <- tolower(as.character(fg))

  # Normalize to lab's broad categories
  normalized <- case_when(
    # Fruits
    grepl("^fruit", fg_lower) ~ "fruit",
    fg_lower %in% c("flavoringfruit") ~ "fruit",

    # Vegetables
    grepl("^vege", fg_lower) ~ "vegetable",
    fg_lower %in% c("asianfood") ~ "vegetable",

    # Grains
    grepl("grain", fg_lower) ~ "grain",

    # Legumes
    grepl("legume", fg_lower) ~ "legume",
    fg_lower %in% c("pulse") ~ "legume",

    # Seeds & nuts
    grepl("^nut", fg_lower) ~ "seed_nut",
    grepl("seed", fg_lower) ~ "seed_nut",
    fg_lower %in% c("teaseed", "flavoringseed") ~ "seed_nut",

    # Herbs & spices
    grepl("herb", fg_lower) ~ "herb_spice",
    fg_lower %in% c("garnish", "teaherb") ~ "herb_spice",

    # Meat & poultry (animals)
    grepl("^a_", fg_lower) & !grepl("fish|amphibian", fg_lower) ~ "meat_poultry",

    # Seafood (animals)
    grepl("fish|amphibian", fg_lower) ~ "seafood",

    # Other
    fg_lower %in% c("additivegum", "sweetener", "tea", "edibleflower",
                    "medflower", "medleaf", "medroot", "flavoringpod",
                    "wild/ forage") ~ "other",

    # Default
    TRUE ~ fg_lower
  )

  return(normalized)
}

# ============================================================================
# LOAD PHYLOSEQ DATA
# ============================================================================

cat("Loading phyloseq objects...\n")

# Load animal data
animal_path <- file.path(MANUSCRIPT_DATA_DIR, "NCWW_allsamples_animal.rds")
if (!file.exists(animal_path)) {
  stop("Animal RDS file not found at: ", animal_path)
}
NCWW_animal <- readRDS(animal_path)
cat("  - Animal data loaded:", ntaxa(NCWW_animal), "taxa,", nsamples(NCWW_animal), "samples\n")

# Load plant data (trnL)
plant_path <- file.path(MANUSCRIPT_DATA_DIR, "NCWW_allsamples_trnL.rds")
if (!file.exists(plant_path)) {
  stop("Plant RDS file not found at: ", plant_path)
}
NCWW_trnL <- readRDS(plant_path)
cat("  - Plant data loaded:", ntaxa(NCWW_trnL), "taxa,", nsamples(NCWW_trnL), "samples\n\n")

# ============================================================================
# EXTRACT SAMPLE METADATA
# ============================================================================

cat("Extracting sample metadata...\n")

# Get sample data from trnL (contains location info)
sam_data_trnL <- as(sample_data(NCWW_trnL), "data.frame")

# Extract unique locations with coordinates
sample_locations <- sam_data_trnL %>%
  select(Location, County, long, lat) %>%
  distinct(Location, .keep_all = TRUE)

# Fix Carrboro coordinates if present
if ("Carrboro" %in% sample_locations$Location) {
  sample_locations <- sample_locations %>%
    mutate(
      long = ifelse(Location == "Carrboro", -79.08076, long),
      lat = ifelse(Location == "Carrboro", 35.91471, lat)
    )
  cat("  - Fixed Carrboro coordinates\n")
}

cat("  - Found", nrow(sample_locations), "unique locations\n")
cat("  - Locations:", paste(sample_locations$Location, collapse = ", "), "\n\n")

# ============================================================================
# PROCESS PLANT DATA WITH LAB'S FOOD GROUPS
# ============================================================================

cat("Processing plant data with lab's food group mappings...\n")

# Filter to food plants only (Streptophyta phylum)
plant_food <- subset_taxa(NCWW_trnL, phylum == "Streptophyta")
cat("  - Food plants:", ntaxa(plant_food), "taxa\n")

# Extract data
plant_otu <- as(otu_table(plant_food), "matrix")
if (!taxa_are_rows(plant_food)) {
  plant_otu <- t(plant_otu)
}
plant_tax <- as.data.frame(tax_table(plant_food)@.Data)
colnames(plant_tax) <- colnames(tax_table(plant_food))
plant_sam <- as(sample_data(plant_food), "data.frame")

# Join with ASV-based food group mapping
plant_species_metadata <- plant_tax %>%
  rownames_to_column("asv_seq") %>%
  left_join(plant_fg_map, by = "asv_seq") %>%
  mutate(
    # Create scientific name
    scientific_name = paste(genus, species),

    # Smart NA handling
    has_valid_metadata = !is.na(CommonName) | !is.na(food_group),
    is_unknown_unknown = is.na(genus) & is.na(species) & !has_valid_metadata,

    # Display name: use common name if available, otherwise genus, otherwise "Unidentified"
    display_name = case_when(
      is_unknown_unknown ~ "Unidentified Plants",
      !is.na(CommonName) & CommonName != "" ~ CommonName,
      !is.na(genus) ~ genus,
      TRUE ~ "Unidentified Plants"
    ),

    # Food group from lab's mapping, fallback to normalized old FoodGroup
    final_food_group = case_when(
      is_unknown_unknown ~ "other",
      !is.na(food_group) ~ food_group,  # Use CSV mapping first (already in correct format)
      !is.na(FoodGroup) ~ normalize_food_group(FoodGroup),  # Normalize old detailed groups
      TRUE ~ "other"
    ),

    # Category (keep simplified)
    final_category = case_when(
      is_unknown_unknown ~ "Unidentified",
      !is.na(BigGroup) & BigGroup != "" ~ BigGroup,
      TRUE ~ "Other"
    )
  ) %>%
  select(asv_seq, scientific_name, display_name, final_food_group, final_category, is_unknown_unknown)

cat("  - Processed", nrow(plant_species_metadata), "plant species\n")
cat("  - Unknown/unknown species:", sum(plant_species_metadata$is_unknown_unknown), "\n\n")

# ============================================================================
# PROCESS ANIMAL DATA WITH LAB'S FOOD GROUPS
# ============================================================================

cat("Processing animal data with lab's food group mappings...\n")

# Filter to food animals only
animal_food <- subset_taxa(NCWW_animal, IsFood == "Y")
cat("  - Food animals:", ntaxa(animal_food), "taxa\n")

# Extract data
animal_otu <- as(otu_table(animal_food), "matrix")
if (!taxa_are_rows(animal_food)) {
  animal_otu <- t(animal_otu)
}
animal_tax <- as.data.frame(tax_table(animal_food)@.Data)
colnames(animal_tax) <- colnames(tax_table(animal_food))
animal_sam <- as(sample_data(animal_food), "data.frame")

# Join with ASV-based food group mapping
animal_species_metadata <- animal_tax %>%
  rownames_to_column("asv_seq") %>%
  left_join(animal_fg_map, by = "asv_seq") %>%
  mutate(
    # Create scientific name
    scientific_name = paste(genus, species),

    # Smart NA handling
    has_valid_metadata = !is.na(CommonName) | !is.na(food_group),
    is_unknown_unknown = is.na(genus) & is.na(species) & !has_valid_metadata,

    # Display name
    display_name = case_when(
      is_unknown_unknown ~ "Unidentified Animals",
      !is.na(CommonName) & CommonName != "" ~ CommonName,
      !is.na(genus) ~ genus,
      TRUE ~ "Unidentified Animals"
    ),

    # Food group from lab's mapping, fallback to normalized old FoodGroup or class
    final_food_group = case_when(
      is_unknown_unknown ~ "other",
      !is.na(food_group) ~ food_group,  # Use CSV mapping first (already in correct format)
      !is.na(FoodGroup) ~ normalize_food_group(FoodGroup),  # Normalize old detailed groups
      !is.na(class) ~ normalize_food_group(class),  # Normalize class names
      TRUE ~ "other"
    ),

    # Category
    final_category = case_when(
      is_unknown_unknown ~ "Unidentified",
      !is.na(BigGroup) & BigGroup != "" ~ BigGroup,
      !is.na(class) ~ class,
      TRUE ~ "Other"
    )
  ) %>%
  select(asv_seq, scientific_name, display_name, final_food_group, final_category, is_unknown_unknown)

cat("  - Processed", nrow(animal_species_metadata), "animal species\n")
cat("  - Unknown/unknown species:", sum(animal_species_metadata$is_unknown_unknown), "\n\n")

# ============================================================================
# AGGREGATE DATA BY LOCATION AND DATE
# ============================================================================

cat("Aggregating data by location and date...\n")

# Function to aggregate, with smart NA handling
aggregate_by_location_date <- function(otu_matrix, sample_data, species_metadata, type = "plant") {

  # Convert OTU to data frame (using ASV sequences as IDs)
  otu_df <- as.data.frame(otu_matrix) %>%
    rownames_to_column("asv_seq")

  # Pivot to long format
  otu_long <- otu_df %>%
    pivot_longer(-asv_seq, names_to = "sample_id", values_to = "abundance")

  # Join with sample metadata
  sample_meta <- sample_data %>%
    rownames_to_column("sample_id") %>%
    select(sample_id, Location, Date, Month) %>%
    mutate(
      Date_parsed = as.Date(Date, format = "%m/%d/%Y"),
      Year = as.numeric(format(Date_parsed, "%Y")),
      date_str = format(Date_parsed, "%Y-%m")
    )

  # Join with species metadata
  otu_with_meta <- otu_long %>%
    left_join(sample_meta, by = "sample_id") %>%
    left_join(species_metadata, by = "asv_seq")

  # Aggregate unknowns: sum abundances for all "Unidentified" species
  aggregated <- otu_with_meta %>%
    group_by(Location, date_str, display_name, final_food_group, final_category, is_unknown_unknown) %>%
    summarise(
      mean_abundance = mean(abundance, na.rm = TRUE),
      n_samples = n(),
      .groups = "drop"
    )

  return(aggregated)
}

# Aggregate plant data
plant_agg <- aggregate_by_location_date(plant_otu, plant_sam, plant_species_metadata, "plant")
cat("  - Plant data aggregated to", nrow(plant_agg), "location-date-taxa combinations\n")

# Aggregate animal data
animal_agg <- aggregate_by_location_date(animal_otu, animal_sam, animal_species_metadata, "animal")
cat("  - Animal data aggregated to", nrow(animal_agg), "location-date-taxa combinations\n\n")

# ============================================================================
# BUILD JSON STRUCTURE
# ============================================================================

cat("Building JSON structure...\n")

# Get all unique dates (sorted)
all_dates <- unique(c(plant_agg$date_str, animal_agg$date_str)) %>%
  sort()
cat("  - Found", length(all_dates), "unique dates:", paste(all_dates, collapse = ", "), "\n")

# Build plants object
plants_list <- list()

for (loc in sample_locations$Location) {

  # Get location metadata
  loc_meta <- sample_locations %>% filter(Location == loc)

  # Initialize timeseries
  timeseries <- list()

  for (date in all_dates) {

    # Get plant data for this location and date
    plant_data <- plant_agg %>%
      filter(Location == loc, date_str == date) %>%
      select(display_name, mean_abundance)

    # Get animal data for this location and date
    animal_data <- animal_agg %>%
      filter(Location == loc, date_str == date) %>%
      select(display_name, mean_abundance)

    # Convert to named lists (using display_name as key)
    plants_named <- setNames(
      as.list(plant_data$mean_abundance),
      plant_data$display_name
    )

    animals_named <- setNames(
      as.list(animal_data$mean_abundance),
      animal_data$display_name
    )

    # Add to timeseries
    timeseries[[date]] <- list(
      plants = plants_named,
      animals = animals_named
    )
  }

  # Create plant ID
  plant_id <- paste0("plant_", str_pad(which(sample_locations$Location == loc), 3, pad = "0"))

  # Add to plants list (only if coordinates are valid)
  if (!is.na(loc_meta$lat) && !is.na(loc_meta$long)) {
    plants_list[[plant_id]] <- list(
      name = paste(loc, "WWTP"),
      lat = loc_meta$lat,
      lng = loc_meta$long,
      county = loc_meta$County,
      timeseries = timeseries
    )
  } else {
    cat("  - Warning: Skipping", loc, "- missing coordinates\n")
  }
}

cat("  - Created data for", length(plants_list), "treatment plants\n")

# Build species metadata with lab's food groups and colors
all_species_metadata <- bind_rows(
  plant_agg %>%
    select(display_name, final_food_group, final_category) %>%
    distinct() %>%
    mutate(type = "plant"),
  animal_agg %>%
    select(display_name, final_food_group, final_category) %>%
    distinct() %>%
    mutate(type = "animal")
) %>%
  distinct(display_name, .keep_all = TRUE) %>%
  # Join with color theme
  left_join(
    color_theme %>% select(group_key, color_hex),
    by = c("final_food_group" = "group_key")
  ) %>%
  mutate(
    # Use color from theme, or default gray for "other"
    display_color = ifelse(!is.na(color_hex), color_hex, "#9BA4B4")
  )

# Create nested list structure for each species
species_metadata_list <- list()
for (i in 1:nrow(all_species_metadata)) {
  sp <- all_species_metadata[i, ]
  species_metadata_list[[sp$display_name]] <- list(
    common_name = sp$display_name,
    food_group = sp$final_food_group,
    category = sp$final_category,
    type = sp$type,
    color = sp$display_color
  )
}

cat("  - Created metadata for", length(species_metadata_list), "species\n\n")

# ============================================================================
# CREATE FINAL JSON OBJECT
# ============================================================================

cat("Creating final JSON object...\n")

# Calculate sample counts per date
date_sample_counts <- bind_rows(
  plant_agg %>% select(Location, date_str) %>% distinct(),
  animal_agg %>% select(Location, date_str) %>% distinct()
) %>%
  distinct() %>%
  group_by(date_str) %>%
  summarise(
    n_locations = n_distinct(Location),
    .groups = "drop"
  )

# Create time period metadata
time_periods <- list()
for (date in all_dates) {
  counts <- date_sample_counts %>% filter(date_str == date)
  time_periods[[date]] <- list(
    n_locations = ifelse(nrow(counts) > 0, counts$n_locations[1], 0),
    label = format(as.Date(paste0(date, "-01")), "%B %Y")
  )
}

# Add color theme to JSON
color_theme_list <- list()
for (i in 1:nrow(color_theme)) {
  theme <- color_theme[i, ]
  color_theme_list[[theme$group_key]] <- list(
    display = theme$display,
    color = theme$color_hex,
    icon_url = theme$icon_url
  )
}

foodseq_json <- list(
  dates = all_dates,
  time_periods = time_periods,
  plants = plants_list,
  species_metadata = species_metadata_list,
  color_theme = color_theme_list,
  metadata = list(
    generated_date = as.character(Sys.Date()),
    n_locations = length(plants_list),
    n_species = length(species_metadata_list),
    n_plant_species = sum(all_species_metadata$type == "plant"),
    n_animal_species = sum(all_species_metadata$type == "animal"),
    data_source = "NCWW manuscript phyloseq objects + lab food group mappings",
    date_range = paste(min(all_dates), "to", max(all_dates)),
    na_handling = "Smart hybrid: genus-level IDs kept, true unknowns aggregated"
  )
)

# ============================================================================
# WRITE JSON FILE
# ============================================================================

cat("Writing JSON to file...\n")

# Create output directory if it doesn't exist
output_dir <- dirname(OUTPUT_FILE)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Write JSON with pretty formatting
write_json(
  foodseq_json,
  path = OUTPUT_FILE,
  pretty = TRUE,
  auto_unbox = TRUE
)

cat("  - JSON file written to:", OUTPUT_FILE, "\n")

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================

cat("\n" , rep("=", 70), "\n", sep = "")
cat("CONVERSION COMPLETE\n")
cat(rep("=", 70), "\n\n", sep = "")

cat("Summary:\n")
cat("  - Treatment plants:", foodseq_json$metadata$n_locations, "\n")
cat("  - Total species:", foodseq_json$metadata$n_species, "\n")
cat("    - Plant species:", foodseq_json$metadata$n_plant_species, "\n")
cat("    - Animal species:", foodseq_json$metadata$n_animal_species, "\n")
cat("  - Date range:", min(all_dates), "to", max(all_dates), "\n")
cat("  - Food groups:", nrow(color_theme), "\n")
cat("  - Output file size:", format(file.size(OUTPUT_FILE), units = "KB"), "\n\n")

cat("NA Handling:\n")
cat("  - Genus-level IDs (kept separate):",
    sum(!plant_species_metadata$is_unknown_unknown & grepl("NA", plant_species_metadata$scientific_name)), "plants,",
    sum(!animal_species_metadata$is_unknown_unknown & grepl("NA", animal_species_metadata$scientific_name)), "animals\n")
cat("  - True unknowns (aggregated):",
    sum(plant_species_metadata$is_unknown_unknown), "plants,",
    sum(animal_species_metadata$is_unknown_unknown), "animals\n\n")

cat("Next steps:\n")
cat("  1. Copy JSON to data/ directory: cp", OUTPUT_FILE, "data/foodseq_data.json\n")
cat("  2. Update visualization colors in index.html\n")
cat("  3. Test visualization\n\n")
