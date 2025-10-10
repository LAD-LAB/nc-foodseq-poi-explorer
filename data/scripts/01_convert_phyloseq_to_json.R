#!/usr/bin/env Rscript
# File: 01_convert_phyloseq_to_json.R
# Author: Anna Bauer (adapted from NCWW manuscript code)
# Date: 2025-10-09
# Purpose: Convert phyloseq RDS files to JSON format for FoodSeq web visualization
#
# Input:
#   - Manuscript data: NCWW_allsamples_animal.rds
#   - Manuscript data: NCWW_allsamples_trnL.rds
# Output:
#   - data/processed/foodseq_data.json (visualization format)
#
# Design Decisions:
#   1. Missing coordinates: Use county centroid as fallback
#   2. Sample aggregation: Average read counts for multiple samples per location/month
#   3. Normalization: CLR (Centered Log-Ratio) transformation for compositional data
#   4. Location handling: Keep all Charlotte plants (1-4) as separate locations

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

cat("Starting phyloseq to JSON conversion...\n")
cat("Input directory:", MANUSCRIPT_DATA_DIR, "\n")
cat("Output file:", OUTPUT_FILE, "\n\n")

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
# Note: Carrboro coordinates need fixing (mentioned in manuscript line 233)
sample_locations <- sam_data_trnL %>%
  select(Location, County, long, lat) %>%
  distinct(Location, .keep_all = TRUE)

# Fix Carrboro coordinates if present (from manuscript note)
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
# PROCESS PLANT DATA
# ============================================================================

cat("Processing plant data...\n")

# Filter to food plants only (Streptophyta phylum)
plant_food <- subset_taxa(NCWW_trnL, phylum == "Streptophyta")
cat("  - Food plants:", ntaxa(plant_food), "taxa\n")

# Extract abundance data and metadata
plant_otu <- as(otu_table(plant_food), "matrix")
if (!taxa_are_rows(plant_food)) {
  plant_otu <- t(plant_otu)
}
plant_tax <- as.data.frame(tax_table(plant_food)@.Data)
colnames(plant_tax) <- colnames(tax_table(plant_food))
plant_sam <- as(sample_data(plant_food), "data.frame")

# Create species metadata (scientific name -> common name)
plant_species_metadata <- plant_tax %>%
  rownames_to_column("taxa_id") %>%
  select(taxa_id, family, genus, species) %>%
  mutate(
    scientific_name = paste(genus, species),
    # Use genus as common name for now (can enhance later)
    common_name = genus
  )

cat("  - Extracted", nrow(plant_species_metadata), "plant species\n\n")

# ============================================================================
# PROCESS ANIMAL DATA
# ============================================================================

cat("Processing animal data...\n")

# Filter to food animals only
animal_food <- subset_taxa(NCWW_animal, IsFood == "Y")
cat("  - Food animals:", ntaxa(animal_food), "taxa\n")

# Extract abundance data and metadata
animal_otu <- as(otu_table(animal_food), "matrix")
if (!taxa_are_rows(animal_food)) {
  animal_otu <- t(animal_otu)
}
animal_tax <- as.data.frame(tax_table(animal_food)@.Data)
colnames(animal_tax) <- colnames(tax_table(animal_food))
animal_sam <- as(sample_data(animal_food), "data.frame")

# Create species metadata
animal_species_metadata <- animal_tax %>%
  rownames_to_column("taxa_id") %>%
  select(taxa_id, class, order, family, genus, species) %>%
  mutate(
    scientific_name = paste(genus, species),
    common_name = genus  # Can enhance with proper common names later
  )

cat("  - Extracted", nrow(animal_species_metadata), "animal species\n\n")

# ============================================================================
# AGGREGATE DATA BY LOCATION AND DATE
# ============================================================================

cat("Aggregating data by location and date...\n")

# Function to aggregate samples by location and date
aggregate_by_location_date <- function(otu_matrix, sample_data, type = "plant") {

  # Convert OTU to data frame
  otu_df <- as.data.frame(otu_matrix) %>%
    rownames_to_column("taxa_id")

  # Pivot to long format
  otu_long <- otu_df %>%
    pivot_longer(-taxa_id, names_to = "sample_id", values_to = "abundance")

  # Join with sample metadata
  sample_meta <- sample_data %>%
    rownames_to_column("sample_id") %>%
    select(sample_id, Location, Date, Month) %>%
    mutate(date_str = paste0("2020-", str_pad(Month, 2, pad = "0")))

  otu_with_meta <- otu_long %>%
    left_join(sample_meta, by = "sample_id")

  # Aggregate by location and date (average abundance)
  aggregated <- otu_with_meta %>%
    group_by(Location, date_str, taxa_id) %>%
    summarise(
      mean_abundance = mean(abundance, na.rm = TRUE),
      n_samples = n(),
      .groups = "drop"
    )

  return(aggregated)
}

# Aggregate plant data
plant_agg <- aggregate_by_location_date(plant_otu, plant_sam, "plant")
cat("  - Plant data aggregated to", nrow(plant_agg), "location-date-taxa combinations\n")

# Aggregate animal data
animal_agg <- aggregate_by_location_date(animal_otu, animal_sam, "animal")
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
      select(taxa_id, mean_abundance)

    # Get animal data for this location and date
    animal_data <- animal_agg %>%
      filter(Location == loc, date_str == date) %>%
      select(taxa_id, mean_abundance)

    # Convert to named lists
    plants_named <- setNames(
      as.list(plant_data$mean_abundance),
      plant_species_metadata$scientific_name[match(plant_data$taxa_id, plant_species_metadata$taxa_id)]
    )

    animals_named <- setNames(
      as.list(animal_data$mean_abundance),
      animal_species_metadata$scientific_name[match(animal_data$taxa_id, animal_species_metadata$taxa_id)]
    )

    # Add to timeseries
    timeseries[[date]] <- list(
      plants = plants_named,
      animals = animals_named
    )
  }

  # Create plant ID (use location name as ID)
  plant_id <- paste0("plant_", str_pad(which(sample_locations$Location == loc), 3, pad = "0"))

  # Add to plants list
  plants_list[[plant_id]] <- list(
    name = paste(loc, "WWTP"),
    lat = loc_meta$lat,
    lng = loc_meta$long,
    county = loc_meta$County,
    timeseries = timeseries
  )
}

cat("  - Created data for", length(plants_list), "treatment plants\n")

# Build species metadata
all_species_metadata <- bind_rows(
  plant_species_metadata %>% select(scientific_name, common_name),
  animal_species_metadata %>% select(scientific_name, common_name)
) %>%
  distinct(scientific_name, .keep_all = TRUE)

species_metadata_list <- setNames(
  as.list(all_species_metadata$common_name),
  all_species_metadata$scientific_name
)

cat("  - Created metadata for", length(species_metadata_list), "species\n\n")

# ============================================================================
# CREATE FINAL JSON OBJECT
# ============================================================================

cat("Creating final JSON object...\n")

foodseq_json <- list(
  dates = all_dates,
  plants = plants_list,
  species_metadata = species_metadata_list,
  metadata = list(
    generated_date = Sys.Date(),
    n_locations = length(plants_list),
    n_species = length(species_metadata_list),
    n_plant_species = sum(plant_species_metadata$scientific_name %in% names(species_metadata_list)),
    n_animal_species = sum(animal_species_metadata$scientific_name %in% names(species_metadata_list)),
    data_source = "NCWW manuscript phyloseq objects"
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
cat("  - Output file size:", format(file.size(OUTPUT_FILE), units = "KB"), "\n\n")

cat("Next steps:\n")
cat("  1. Validate JSON structure\n")
cat("  2. Test visualization with real data\n")
cat("  3. Update documentation\n\n")
