# Data Processing Workflow

## Overview

This document describes the data processing pipeline for converting raw FoodSeq phyloseq data from the NC Wastewater manuscript into JSON format for web visualization.

## Data Flow

```
Manuscript Phyloseq RDS Files
    ↓
01_convert_phyloseq_to_json.R
    ↓
data/processed/foodseq_data.json
    ↓
data/foodseq_data.json (copied for visualization)
    ↓
Interactive Web Visualization
```

## Source Data

### Location
`../Wastewater/NCWastewaterManuscript/20250408_NewFormatting/NCWW_ms_code/Data/`

### Files
- **NCWW_allsamples_animal.rds**: Phyloseq object with animal food species
  - 129 taxa (116 food animals after filtering)
  - 183 samples
  - Contains livestock, fish, and shellfish DNA

- **NCWW_allsamples_trnL.rds**: Phyloseq object with plant species (trnL marker)
  - 793 taxa (185 food plants after filtering to Streptophyta phylum)
  - 182 samples
  - Contains crops, fruits, vegetables, nuts, herbs

### Data Collection
- **Study period**: May-December 2020 (8 months)
- **Locations**: 21 wastewater treatment plants across North Carolina
- **Sample types**: Wastewater influent
- **Sequencing markers**:
  - trnL for plants
  - 12S/16S for animals

## Processing Pipeline

### Script: `data/scripts/01_convert_phyloseq_to_json.R`

#### 1. Data Loading
Loads both phyloseq objects from the manuscript directory.

#### 2. Metadata Extraction
- Extracts unique locations with coordinates (lat/long)
- Fixes known coordinate errors (e.g., Carrboro)
- Preserves all Charlotte treatment plants (1-4) as separate locations
- Associates samples with counties

#### 3. Species Filtering
- **Plants**: Filters to `phylum == "Streptophyta"` (food plants)
- **Animals**: Filters to `IsFood == "Y"` (food animals)
- Creates scientific name → common name mappings

#### 4. Sample Aggregation
When multiple samples exist for the same location and month:
- Calculates mean abundance across samples
- Tracks number of samples averaged
- Preserves temporal resolution at monthly level

**Design Decision**: Averaging provides more robust estimates and reduces noise from sampling variation while maintaining biological signal.

#### 5. Data Transformation
- Abundances are exported as-is from phyloseq (already normalized in manuscript pipeline)
- Date formatting: `YYYY-MM` format
- Geographic coordinates: decimal degrees (WGS84)

#### 6. JSON Output Structure
```json
{
  "dates": ["2020-05", ..., "2020-12"],
  "plants": {
    "plant_001": {
      "name": "Newport WWTP",
      "lat": 34.7842,
      "lng": -76.8637,
      "county": "carteret",
      "timeseries": {
        "2020-05": {
          "plants": {"Genus species": abundance, ...},
          "animals": {"Genus species": abundance, ...}
        },
        ...
      }
    },
    ...
  },
  "species_metadata": {
    "Scientific name": "Common name",
    ...
  },
  "metadata": {
    "generated_date": "2025-10-09",
    "n_locations": 21,
    "n_species": 248,
    "n_plant_species": 185,
    "n_animal_species": 116,
    "data_source": "NCWW manuscript phyloseq objects"
  }
}
```

## Running the Pipeline

### Prerequisites
```r
# R packages required
library(phyloseq)
library(tidyverse)
library(jsonlite)
```

### Execution
```bash
# From project root directory
cd /path/to/nc-foodseq-viz

# Run conversion script
Rscript data/scripts/01_convert_phyloseq_to_json.R

# Expected output:
# - data/processed/foodseq_data.json (703KB)
# - Console output with summary statistics
```

### Deployment
```bash
# Copy processed JSON to data directory for visualization
cp data/processed/foodseq_data.json data/foodseq_data.json

# Start local server to view visualization
python3 -m http.server 8000

# Open browser to http://localhost:8000/index.html
```

## Output Summary

### Real Data Statistics (2020 Manuscript Data)
- **Treatment Plants**: 21 locations across NC
- **Species Detected**: 248 total (185 plants, 116 animals)
- **Temporal Coverage**: 8 months (May-December 2020)
- **Geographic Coverage**: Coastal to mountain regions
- **File Size**: ~700KB JSON

### Key Locations
- Charlotte (4 separate plants)
- Durham, Raleigh, Greensboro (Piedmont)
- Wilmington, Beaufort, Morehead City (Coastal)
- Asheville, Marion (Mountain)
- Winston-Salem, Carrboro, Fayetteville, and others

## Data Quality Notes

### Coordinate Fixes Applied
- **Carrboro**: Corrected from coastal misplacement to correct piedmont coordinates
  - Correct: lat = 35.91471, long = -79.08076

### Known Limitations
1. **Temporal gaps**: Not all locations have samples for all 8 months
2. **Species names**: Some taxa have "NA" in genus or species fields
3. **Common names**: Currently using genus as common name (can be enhanced)
4. **Seasonal bias**: Data only covers May-December (no winter months)

## Connection to Manuscript Analysis

This pipeline preserves the data processing decisions from the manuscript:

1. **Normalization**: Uses phyloseq objects that were already normalized for compositional analysis
2. **Species classification**: Same phylum-based filtering (Streptophyta/Chordata)
3. **Location metadata**: Coordinates and county assignments from manuscript Figure 1
4. **Quality control**: Food vs. non-food filtering applied as in manuscript methods

## Future Enhancements

### Short-term
- [ ] Add proper common names lookup (scientific → vernacular)
- [ ] Handle "NA NA" species names more gracefully
- [ ] Add confidence scores or read counts
- [ ] Include sample size metadata per location-date

### Long-term
- [ ] Integrate additional timepoints when available
- [ ] Add CLR transformation option for compositional data
- [ ] Support multiple data sources (merge with newer datasets)
- [ ] Add data validation and quality checks

## Troubleshooting

### Common Issues

**Error: "Month_Date column doesn't exist"**
- **Solution**: Updated script to use `Date` and `Month` columns instead
- The phyloseq sample metadata uses these column names

**Error: "no method for coercing taxonomyTable to data.frame"**
- **Solution**: Use `tax_table(ps)@.Data` to extract raw matrix first
- Then convert to data frame and restore column names

**Missing coordinates**
- **Solution**: Script will use county centroids as fallback (not yet implemented)
- Check sample metadata for lat/long columns

## References

- **Manuscript**: NC Wastewater FoodSeq Study (2020 data)
- **Manuscript Code**: `Rcode_AnnaUpdates20250408.Rmd`
- **Original Data**: `NCWW_allsamples_animal.rds`, `NCWW_allsamples_trnL.rds`
- **Visualization Project**: `nc-foodseq-viz` GitHub repository

---

*Last updated: 2025-10-09*
*Author: Anna Bauer*
