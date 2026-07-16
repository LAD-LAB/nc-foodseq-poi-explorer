# Merge new SwannLee RDS data into foodseq_data.json
# Also removes all reads from: Human, Mouse, Rat, Cat, Dog
#
# Usage: Rscript scripts/merge_new_rds.R

library(jsonlite)
library(phyloseq)

# File paths
project_dir <- "C:/Users/rache/Box/project_davidlab/LAD_LAB_Personnel/Rachel_Q/nc-foodseq-poi-explorer"
json_path <- file.path(project_dir, "data", "foodseq_data.json")
trnl_path <- "C:/Users/rache/Downloads/SwannLee-ps-trnL-merged-QC-contam_excluded.rds"
s12_path  <- "C:/Users/rache/Downloads/SwannLee-ps-12S-merged-QC-contam_excluded.rds"
gazetteer_path <- file.path(project_dir, "data", "nc_census_tracts_2020_gazetteer.txt")

DURHAM_FIPS <- "37063"

# Species to EXCLUDE (non-food / contaminant)
EXCLUDE_SPECIES <- c(
  "Human", "Homo sapiens", "Homo",
  "Mouse", "House mouse", "Mus musculus", "Mus",
  "Rat", "Black rat", "Brown rat", "Rattus rattus", "Rattus norvegicus", "Rattus",
  "Cat", "Felis catus", "Felis",
  "Dog", "Canis lupus", "Canis lupus familiaris", "Canis"
)

# ---- Load gazetteer ----
cat("Loading gazetteer...\n")
gaz <- read.delim(gazetteer_path, stringsAsFactors = FALSE)
durham_tracts <- gaz[grepl(paste0("^", DURHAM_FIPS), gaz$GEOID), ]
durham_tracts$short_tract <- sapply(durham_tracts$GEOID, function(g) {
  tract_part <- substring(g, 6)
  main <- as.integer(substring(tract_part, 1, 4))
  sub <- as.integer(substring(tract_part, 5, 6))
  if (sub == 0) return(as.character(main))
  return(paste0(main, ".", sprintf("%02d", sub)))
})
tract_coords <- setNames(
  lapply(1:nrow(durham_tracts), function(i) {
    list(lat = durham_tracts$INTPTLAT[i], lng = durham_tracts$INTPTLONG[i])
  }),
  durham_tracts$short_tract
)
cat("Loaded", length(tract_coords), "Durham tract centroids\n")

# ---- Helpers ----
parse_date_safe <- function(x) {
  if (is.na(x) || x == "" || x == "NA") return(NA)
  for (fmt in c("%m/%d/%y", "%m/%d/%Y", "%Y-%m-%d")) {
    parsed <- tryCatch(as.Date(x, format = fmt), error = function(e) NA)
    if (!is.na(parsed)) return(parsed)
  }
  tryCatch(as.Date(x), error = function(e) NA)
}

get_taxon_name <- function(tax_row) {
  for (level in c("species", "genus", "family", "order", "class")) {
    if (level %in% names(tax_row)) {
      val <- as.character(tax_row[level])
      if (!is.na(val) && val != "" && val != "NA" && !grepl("synthetic", val, ignore.case = TRUE)) {
        return(val)
      }
    }
  }
  return(NA_character_)
}

# ---- Name maps (same as original script) ----
plant_name_map <- list(
  "Solanum lycopersicum" = "Tomato", "Solanum tuberosum" = "Potato",
  "Solanum melongena" = "Eggplant", "Solanum" = "Nightshade",
  "Capsicum annuum" = "Pepper", "Capsicum" = "Chili peppers",
  "Zea mays" = "Corn", "Zea" = "Corn",
  "Oryza sativa" = "Rice", "Oryza" = "Rice",
  "Triticum aestivum" = "Wheat", "Triticum" = "Wheat",
  "Glycine max" = "Soybean", "Glycine" = "Soybean",
  "Musa" = "Banana", "Allium cepa" = "Onion", "Allium sativum" = "Garlic",
  "Allium" = "Onion/Garlic", "Coffea" = "Coffee", "Coffea arabica" = "Coffee",
  "Theobroma cacao" = "Cocoa", "Theobroma" = "Cocoa",
  "Camellia sinensis" = "Tea", "Camellia" = "Tea",
  "Pisum sativum" = "Pea", "Phaseolus vulgaris" = "Common bean",
  "Phaseolus" = "Beans", "Lens culinaris" = "Lentil",
  "Cicer arietinum" = "Chickpea", "Arachis hypogaea" = "Peanut",
  "Vitis vinifera" = "Grape", "Vitis" = "Grape",
  "Citrus" = "Citrus fruits", "Citrus sinensis" = "Orange",
  "Citrus limon" = "Lemon", "Malus domestica" = "Apple", "Malus" = "Apple",
  "Prunus" = "Stone fruit", "Prunus persica" = "Peach", "Prunus avium" = "Cherry",
  "Fragaria" = "Strawberry", "Cucumis sativus" = "Cucumber",
  "Cucumis melo" = "Melon", "Cucurbita" = "Squash/Pumpkin",
  "Brassica" = "Cabbage/Broccoli", "Brassica oleracea" = "Cabbage/Broccoli",
  "Brassica rapa" = "Turnip/Bok choy", "Brassica napus" = "Canola",
  "Daucus carota" = "Carrot", "Daucus" = "Carrot",
  "Beta vulgaris" = "Beet", "Spinacia oleracea" = "Spinach",
  "Lactuca sativa" = "Lettuce", "Lactuca" = "Lettuce",
  "Helianthus annuus" = "Sunflower", "Linum usitatissimum" = "Flax",
  "Cannabis sativa" = "Hemp", "Humulus lupulus" = "Hops",
  "Ipomoea batatas" = "Sweet potato", "Manihot esculenta" = "Cassava",
  "Cocos nucifera" = "Coconut", "Elaeis" = "Palm oil",
  "Saccharum officinarum" = "Sugarcane", "Hordeum vulgare" = "Barley",
  "Avena sativa" = "Oat", "Avena" = "Oat", "Sorghum bicolor" = "Sorghum",
  "Sesamum indicum" = "Sesame", "Zingiber officinale" = "Ginger",
  "Curcuma longa" = "Turmeric", "Piper nigrum" = "Black pepper",
  "Cinnamomum" = "Cinnamon", "Persea americana" = "Avocado",
  "Poaceae" = "Grass family", "Rosaceae" = "Rose family",
  "Fabaceae" = "Legume family", "Solanaceae" = "Nightshade family",
  "Apiaceae" = "Carrot/Celery family", "Brassicaceae" = "Mustard family",
  "Cucurbitaceae" = "Gourd family", "Asteraceae" = "Daisy family",
  "Musaceae" = "Banana family", "Salmonidae" = "Salmon family"
)

animal_name_map <- list(
  "Bos taurus" = "Cow", "Bos" = "Cow",
  "Sus scrofa" = "Pig (Pork)", "Sus" = "Pig",
  "Gallus gallus" = "Chicken", "Gallus" = "Chicken",
  "Ovis aries" = "Sheep (Lamb)", "Ovis" = "Sheep",
  "Capra hircus" = "Goat", "Capra" = "Goat",
  "Homo sapiens" = "Human", "Homo" = "Human",
  "Canis lupus" = "Dog", "Canis" = "Dog",
  "Felis catus" = "Cat", "Felis" = "Cat",
  "Mus musculus" = "Mouse", "Mus" = "Mouse",
  "Rattus rattus" = "Rat", "Rattus" = "Rat",
  "Meleagris gallopavo" = "Turkey", "Meleagris" = "Turkey",
  "Anas platyrhynchos" = "Duck", "Anas" = "Duck",
  "Salmo salar" = "Salmon", "Salmo" = "Salmon/Trout",
  "Oncorhynchus" = "Pacific salmon", "Thunnus" = "Tuna",
  "Mugil cephalus" = "Mullet", "Mugil" = "Mullet",
  "Odocoileus virginianus" = "White-tailed deer", "Odocoileus" = "Deer",
  "Cervidae" = "Deer family", "Bovidae" = "Cattle/Sheep/Goat family",
  "Suidae" = "Pig family", "Phasianidae" = "Pheasant family",
  "Columba livia" = "Pigeon", "Procyon lotor" = "Raccoon",
  "Didelphis virginiana" = "Opossum", "Sciurus" = "Squirrel"
)

# ---- Process phyloseq ----
process_phyloseq <- function(ps, data_type) {
  otu <- as.data.frame(otu_table(ps))
  if (!taxa_are_rows(ps)) otu <- as.data.frame(t(otu))
  meta <- as.data.frame(sample_data(ps))
  tax <- as.data.frame(tax_table(ps))

  name_map <- if (data_type == "animal") animal_name_map else plant_name_map

  seq_to_name <- sapply(rownames(tax), function(seq) {
    name <- get_taxon_name(tax[seq, ])
    if (!is.na(name) && name %in% names(name_map)) return(name_map[[name]])
    return(name)
  })

  samples <- meta[meta$type == "sample", ]
  results <- list()

  for (sample_id in rownames(samples)) {
    sample_meta <- samples[sample_id, ]
    raw_date <- as.character(sample_meta[["Sample.Date"]])
    parsed_date <- parse_date_safe(raw_date)
    if (is.na(parsed_date)) next

    sample_date <- format(parsed_date, "%Y-%m")
    sample_loc <- as.character(sample_meta[["Sample.Location"]])
    if (is.na(sample_loc) || sample_loc == "") next

    census_tract <- as.character(sample_meta[["X2020.Census.Tract"]])

    if (!(sample_loc %in% names(results))) {
      results[[sample_loc]] <- list(data = list(), tract = census_tract)
    }
    if (!(sample_date %in% names(results[[sample_loc]]$data))) {
      results[[sample_loc]]$data[[sample_date]] <- list()
    }

    if (sample_id %in% colnames(otu)) {
      sample_abundances <- otu[, sample_id]
      taxa_ids <- rownames(otu)
    } else {
      next
    }

    for (idx in seq_along(taxa_ids)) {
      abundance <- as.numeric(sample_abundances[idx])
      if (is.na(abundance) || abundance <= 0) next

      seq <- taxa_ids[idx]
      taxon_name <- seq_to_name[seq]
      if (is.na(taxon_name) || taxon_name == "") next

      # SKIP excluded species
      if (taxon_name %in% EXCLUDE_SPECIES) next

      current <- results[[sample_loc]]$data[[sample_date]][[taxon_name]]
      if (is.null(current)) current <- 0
      results[[sample_loc]]$data[[sample_date]][[taxon_name]] <- current + abundance
    }
  }

  return(results)
}

normalize_abundances <- function(species_list, target_sum = 500) {
  total <- sum(unlist(species_list))
  if (total <= 0) return(species_list)
  scale_factor <- target_sum / total
  lapply(species_list, function(x) round(x * scale_factor, 4))
}

# ---- MAIN ----
cat("Loading existing JSON...\n")
data <- fromJSON(json_path)
cat("Existing:", length(data$dates), "dates,", length(data$plants), "plants\n\n")

# Step 1: Remove excluded species from ALL existing data
cat("=== Removing Human/Mouse/Rat/Cat/Dog from existing data ===\n")
excluded_common <- c("Human", "Mouse", "House mouse", "Rat", "Black rat", "Brown rat",
                     "Cat", "Dog", "Canis", "Felis", "Mus", "Rattus", "Homo")
removed_count <- 0

for (pid in names(data$plants)) {
  plant <- data$plants[[pid]]
  for (d in names(plant$timeseries)) {
    ts <- plant$timeseries[[d]]
    # Remove from animals
    if (!is.null(ts$animals)) {
      to_remove <- names(ts$animals)[names(ts$animals) %in% excluded_common]
      if (length(to_remove) > 0) {
        for (r in to_remove) {
          data$plants[[pid]]$timeseries[[d]]$animals[[r]] <- NULL
          removed_count <- removed_count + 1
        }
      }
    }
    # Remove from plants (unlikely but check)
    if (!is.null(ts$plants)) {
      to_remove <- names(ts$plants)[names(ts$plants) %in% excluded_common]
      if (length(to_remove) > 0) {
        for (r in to_remove) {
          data$plants[[pid]]$timeseries[[d]]$plants[[r]] <- NULL
          removed_count <- removed_count + 1
        }
      }
    }
  }
}

# Also remove from species_metadata
for (sp in excluded_common) {
  if (sp %in% names(data$species_metadata)) {
    data$species_metadata[[sp]] <- NULL
    cat("  Removed metadata for:", sp, "\n")
  }
}
cat("Removed", removed_count, "excluded species entries from existing data\n\n")

# Step 2: Process new RDS files
cat("=== Processing new RDS files ===\n")
cat("Processing trnL (plants)...\n")
ps_trnl <- readRDS(trnl_path)
plant_results <- process_phyloseq(ps_trnl, "plant")
cat("Found", length(plant_results), "locations with plant data\n")

cat("Processing 12S (animals)...\n")
ps_12s <- readRDS(s12_path)
animal_results <- process_phyloseq(ps_12s, "animal")
cat("Found", length(animal_results), "locations with animal data\n")

# Combine locations
all_locations <- unique(c(names(plant_results), names(animal_results)))
skip_locations <- c("PreMiEr Home Sink")
all_locations <- setdiff(all_locations, skip_locations)
cat("Total new locations:", length(all_locations), "\n\n")

# Check which locations already exist
existing_locs <- sapply(data$plants, function(p) p$name)
new_locs <- setdiff(all_locations, existing_locs)
update_locs <- intersect(all_locations, existing_locs)
cat("New locations:", length(new_locs), "\n")
cat("Existing locations to update:", length(update_locs), "\n\n")

# Find next plant ID
existing_ids <- as.numeric(gsub("plant_", "", names(data$plants)))
next_id <- max(existing_ids, na.rm = TRUE) + 1

new_dates <- c()

# Update existing locations with new timepoints
for (loc in update_locs) {
  pid <- names(existing_locs)[existing_locs == loc]
  if (length(pid) == 0) next
  pid <- pid[1]

  all_loc_dates <- unique(c(
    if (loc %in% names(plant_results)) names(plant_results[[loc]]$data) else c(),
    if (loc %in% names(animal_results)) names(animal_results[[loc]]$data) else c()
  ))

  for (d in all_loc_dates) {
    plants_data <- list()
    animals_data <- list()

    if (loc %in% names(plant_results) && d %in% names(plant_results[[loc]]$data)) {
      plants_data <- normalize_abundances(plant_results[[loc]]$data[[d]])
    }
    if (loc %in% names(animal_results) && d %in% names(animal_results[[loc]]$data)) {
      animals_data <- normalize_abundances(animal_results[[loc]]$data[[d]])
    }

    # Merge with existing data for this date, or add new date
    if (d %in% names(data$plants[[pid]]$timeseries)) {
      # Merge: add new species, update existing
      existing_plants <- data$plants[[pid]]$timeseries[[d]]$plants
      existing_animals <- data$plants[[pid]]$timeseries[[d]]$animals
      for (sp in names(plants_data)) {
        existing_plants[[sp]] <- plants_data[[sp]]
      }
      for (sp in names(animals_data)) {
        existing_animals[[sp]] <- animals_data[[sp]]
      }
      data$plants[[pid]]$timeseries[[d]]$plants <- existing_plants
      data$plants[[pid]]$timeseries[[d]]$animals <- existing_animals
    } else {
      data$plants[[pid]]$timeseries[[d]] <- list(plants = plants_data, animals = animals_data)
    }
    new_dates <- c(new_dates, d)
  }
  cat("  Updated", loc, "(", pid, ") with", length(all_loc_dates), "timepoints\n")
}

# Add new locations
for (loc in new_locs) {
  tract <- NULL
  if (loc %in% names(plant_results)) tract <- plant_results[[loc]]$tract
  if (is.null(tract) && loc %in% names(animal_results)) tract <- animal_results[[loc]]$tract

  lat <- 35.98
  lng <- -78.90
  if (!is.null(tract) && !is.na(tract) && tract %in% names(tract_coords)) {
    lat <- tract_coords[[tract]]$lat
    lng <- tract_coords[[tract]]$lng
    seed_val <- sum(utf8ToInt(loc)) %% .Machine$integer.max
    set.seed(seed_val)
    lat <- lat + runif(1, -0.003, 0.003)
    lng <- lng + runif(1, -0.003, 0.003)
  }

  timeseries <- list()
  all_loc_dates <- unique(c(
    if (loc %in% names(plant_results)) names(plant_results[[loc]]$data) else c(),
    if (loc %in% names(animal_results)) names(animal_results[[loc]]$data) else c()
  ))

  for (d in all_loc_dates) {
    plants_data <- list()
    animals_data <- list()
    if (loc %in% names(plant_results) && d %in% names(plant_results[[loc]]$data)) {
      plants_data <- normalize_abundances(plant_results[[loc]]$data[[d]])
    }
    if (loc %in% names(animal_results) && d %in% names(animal_results[[loc]]$data)) {
      animals_data <- normalize_abundances(animal_results[[loc]]$data[[d]])
    }
    timeseries[[d]] <- list(plants = plants_data, animals = animals_data)
    new_dates <- c(new_dates, d)
  }

  plant_id <- sprintf("plant_%03d", next_id)
  next_id <- next_id + 1

  data$plants[[plant_id]] <- list(
    name = loc,
    lat = lat,
    lng = lng,
    county = "durham",
    census_tract = if (!is.null(tract) && !is.na(tract)) tract else "unknown",
    location_type = "manhole",
    timeseries = timeseries
  )
  cat("  Added", loc, "as", plant_id, "(tract:", tract, ")\n")
}

# Update dates
new_dates <- unique(new_dates)
all_dates <- unique(c(data$dates, new_dates))
all_dates <- sort(all_dates[grepl("^20[0-9]{2}-[0-9]{2}$", all_dates)])
data$dates <- all_dates

# Update time_periods
month_names <- c("January", "February", "March", "April", "May", "June",
                 "July", "August", "September", "October", "November", "December")
for (d in all_dates) {
  if (!(d %in% names(data$time_periods))) {
    date_parts <- strsplit(d, "-")[[1]]
    data$time_periods[[d]] <- list(
      n_locations = 0,
      label = paste(month_names[as.integer(date_parts[2])], date_parts[1])
    )
  }
}

# Add species metadata for new species
cat("\nAdding species metadata for new species...\n")
new_meta_count <- 0
for (loc in all_locations) {
  if (loc %in% names(plant_results)) {
    for (d in names(plant_results[[loc]]$data)) {
      for (taxon in names(plant_results[[loc]]$data[[d]])) {
        if (taxon %in% EXCLUDE_SPECIES) next
        if (!(taxon %in% names(data$species_metadata))) {
          data$species_metadata[[taxon]] <- list(
            common_name = taxon, food_group = "other",
            category = "Other", type = "plant", color = "#9BA4B4"
          )
          new_meta_count <- new_meta_count + 1
        }
      }
    }
  }
  if (loc %in% names(animal_results)) {
    for (d in names(animal_results[[loc]]$data)) {
      for (taxon in names(animal_results[[loc]]$data[[d]])) {
        if (taxon %in% EXCLUDE_SPECIES) next
        if (!(taxon %in% names(data$species_metadata))) {
          data$species_metadata[[taxon]] <- list(
            common_name = taxon, food_group = "meat",
            category = "A_Meat", type = "animal", color = "#E57373"
          )
          new_meta_count <- new_meta_count + 1
        }
      }
    }
  }
}
cat("Added", new_meta_count, "new species metadata entries\n")

# Recalculate n_locations
cat("Recalculating n_locations...\n")
for (date in data$dates) {
  count <- 0
  for (plant_id in names(data$plants)) {
    plant <- data$plants[[plant_id]]
    if (date %in% names(plant$timeseries)) {
      ts <- plant$timeseries[[date]]
      plant_vals <- unlist(ts$plants)
      animal_vals <- unlist(ts$animals)
      if (any(c(plant_vals, animal_vals) > 0, na.rm = TRUE)) {
        count <- count + 1
      }
    }
  }
  data$time_periods[[date]]$n_locations <- count
}

# Final verification: confirm no excluded species remain
cat("\n=== Final verification ===\n")
remaining <- 0
for (pid in names(data$plants)) {
  for (d in names(data$plants[[pid]]$timeseries)) {
    ts <- data$plants[[pid]]$timeseries[[d]]
    for (sp in c(names(ts$plants), names(ts$animals))) {
      if (sp %in% excluded_common) {
        cat("  WARNING: Still found", sp, "in", pid, "date", d, "\n")
        remaining <- remaining + 1
      }
    }
  }
}
if (remaining == 0) cat("  CLEAN: No Human/Mouse/Rat/Cat/Dog reads remain.\n")

# Summary
cat("\n--- Final Summary ---\n")
cat("Dates:", length(data$dates), "\n")
cat("Plants (locations):", length(data$plants), "\n")
cat("Species metadata:", length(data$species_metadata), "\n")
cat("New dates added:", paste(sort(new_dates), collapse = ", "), "\n")

# Save
cat("\nSaving to:", json_path, "\n")
write_json(data, json_path, pretty = TRUE, auto_unbox = TRUE)
cat("Done!\n")
