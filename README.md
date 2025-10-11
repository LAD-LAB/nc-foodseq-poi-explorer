# NC FoodSeq Wastewater Visualization

Interactive web-based visualization of FoodSeq data from 39 wastewater treatment plants across North Carolina.

![NC FoodSeq Demo](https://img.shields.io/badge/status-MVP-green)

## Overview

This tool enables exploration of plant and animal species detected in wastewater treatment plants across North Carolina. Users can click on counties to view the most abundant species and scrub through time to see temporal patterns.

## Features

- **Interactive Map**: Click on NC counties or treatment plant markers to view data
- **Dual Species Views**: Toggle between plant and animal species detection
- **Top 25 Display**: Color-coded bar charts using **lab's standardized food group colors**
- **Temporal Navigation**: Discrete time period selector with data availability indicators
- **Dynamic Marker Colors**: Location markers change color based on data availability
  - **Green markers**: Default/no data for selected time period
  - **Red markers**: Has data available for selected time period
- **Population Density Overlay**: Real 2020 Census data heatmap (YlGnBu color scheme)
- **Multi-Panel**: View multiple counties simultaneously for comparison
- **Draggable Panels**: Rearrange panels for custom layouts
- **Responsive Design**: Professional appearance suitable for presentations

## Quick Start

### 1. Generate Data

```bash
# Activate virtual environment
source venv/bin/activate

# Generate toy FoodSeq data
python3 generate_toy_data.py
```

### 2. View Visualization

Start a local web server (required to avoid CORS issues):

```bash
# Start server
python3 -m http.server 8000

# Open in browser
open http://localhost:8000/index.html
```

Or visit `http://localhost:8000/index.html` in your browser.

## Data

### Current Dataset (Real FoodSeq Data - 2020-2021)

The visualization uses **real FoodSeq data** from the NC Wastewater manuscript:

- **20 wastewater treatment plants** across NC (Charlotte 4 excluded due to missing coordinates)
- **292 species total:**
  - **179 plant species** (Streptophyta phylum - food plants)
  - **113 animal species** (food animals marked as IsFood = "Y")
- **9 standardized food groups** using lab's color palette (91.1% color coverage):
  - Seafood (85 species) - Pink (#EB88D1)
  - Vegetable (39 species) - Purple (#B26EB6)
  - Fruit (35 species) - Blue (#8593C6)
  - Meat & Poultry (28 species) - Red (#DC7775)
  - Herb & Spice (25 species) - Brown (#B79888)
  - Seed & Nut (24 species) - Yellow (#FFEA99)
  - Legume (17 species) - Green (#9CAF6A)
  - Grain (13 species) - Orange (#FCC77C)
  - Other (26 species) - Gray (#9BA4B4)
- **9 timepoints** (May-December 2020, June 2021)
  - Default view: **June 2021** (most comprehensive with 19/20 locations)
  - Visual indicators show data sparsity for early months
- **Geographic coverage**: Coastal (Wilmington, Beaufort) to Mountain (Asheville, Marion) regions
- **Species metadata**: Common names, standardized food groups, categories

### Data Processing Pipeline

Real FoodSeq data is processed from phyloseq format (RDS files) to JSON using an R script:

**Input**:
- `NCWW_allsamples_animal.rds` (animal species from manuscript)
- `NCWW_allsamples_trnL.rds` (plant species from manuscript)

**Output**: `data/processed/foodseq_data.json` → `data/foodseq_data.json`

**Script**: `data/scripts/01_convert_phyloseq_to_json.R`

**Design Decisions**:
1. **Missing coordinates**: Use county centroid as fallback for treatment plants without lat/long
2. **Sample aggregation**: Average read counts when multiple samples exist for same location/month
3. **Normalization**: Apply CLR (Centered Log-Ratio) transformation for compositional data
4. **Location handling**: Keep all Charlotte treatment plants (1-4) as separate locations

**Species Classification**:
- **Plants**: Taxa with phylum = "Streptophyta"
- **Animals**: Taxa with phylum = "Chordata"

#### JSON Format

To use real FoodSeq data, modify `generate_toy_data.py` or create a new conversion script that outputs JSON in the following format:

```json
{
  "dates": ["2024-01", "2024-02", ...],
  "plants": {
    "plant_001": {
      "name": "Durham WWTP",
      "lat": 35.99,
      "lng": -78.90,
      "county": "Durham",
      "timeseries": {
        "2024-01": {
          "plants": {"Species name": abundance, ...},
          "animals": {"Species name": abundance, ...}
        }
      }
    }
  },
  "species_metadata": {
    "Scientific name": "Common name"
  }
}
```

## Project Structure

```
nc-foodseq-viz/
├── index.html                           # Main visualization (single-file app)
├── data/
│   ├── foodseq_data.json               # Real FoodSeq data (2020-2021, 703KB)
│   ├── nc_counties.geojson             # NC county boundaries
│   ├── nc_population_density.geojson   # Census block groups with density (5.5MB)
│   ├── raw/                            # Raw data (git-ignored)
│   │   └── NCWW_allsamples_02142025.rds
│   ├── processed/                      # Processed data outputs
│   │   └── foodseq_data.json
│   ├── scripts/                        # Data processing scripts
│   │   ├── 01_convert_phyloseq_to_json.R
│   │   └── 02_create_population_density_geojson.R
│   └── WORKFLOW.md                     # Data processing documentation
├── generate_toy_data.py                 # Toy data generation (testing)
├── create_nc_geojson.py                 # GeoJSON filter script
├── DESIGN.md                            # Design documentation
├── CLAUDE.md                            # Development workflow guide
├── REMINDME.md                          # Session notes and next steps
├── TODO_POPULATION_DATA.md              # Instructions for real Census data
└── README.md                            # This file
```

## Technology Stack

- **Leaflet.js** - Interactive mapping
- **Chart.js** - Data visualization
- **Vanilla JavaScript** - Application logic
- **Python** - Data generation/processing

No build tools or server required - runs entirely in the browser!

## Usage

1. **View County Data**: Click on any NC county or treatment plant marker
2. **Switch Species Type**: Use the "Plants" / "Animals" tabs in the panel
3. **Compare Counties**: Click multiple counties to open multiple panels
4. **Navigate Time**: Click time period buttons to switch between May 2020 - June 2021
5. **View Population Density**: Click "Heatmap" to see rural/urban context
6. **Rearrange Panels**: Drag panels by their headers to reposition
7. **Close Panels**: Click the × button on any panel

**Note**: June 2021 is the default view (19 of 20 treatment plants). Earlier months have fewer locations (indicated by dashed borders on time buttons).

## Development

### Setup

```bash
# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate  # Mac/Linux
# or
venv\Scripts\activate     # Windows

# Install dependencies (if needed)
pip install -r requirements.txt
```

### Process Real Data

**FoodSeq Data:**
```bash
# Run R script to convert manuscript phyloseq data to JSON
Rscript data/scripts/01_convert_phyloseq_to_json.R

# Copy processed data to visualization directory
cp data/processed/foodseq_data.json data/foodseq_data.json
```

**Population Density Data:**

✅ **Using Real Census Data**: The population density layer now uses **real 2020 Census data** via the Census API, matching the methodology in manuscript Figure 1a.

To regenerate the population density GeoJSON:
```bash
Rscript data/scripts/02_create_population_density_geojson.R
```

The script fetches data from the Census API using your API key stored in `.env`.

### Generate Toy Data (for testing)

```bash
# Generate synthetic data (optional, for testing)
python3 generate_toy_data.py
```

## Future Enhancements

**Completed:**
- [x] Real FoodSeq data integration ✅
- [x] Time period selector with data availability indicators ✅
- [x] Lab's standardized food group classifications and colors ✅
- [x] Dynamic marker colors showing data availability ✅
- [x] Population density heatmap overlay ✅
- [x] Draggable multi-panel comparison ✅
- [x] Real Census population data (2020 Census via API) ✅

**Planned:**
- [ ] Population density legend showing density bins (recommended next)
- [ ] Species search and filtering
- [ ] Data export functionality
- [ ] Animation mode for temporal visualization
- [ ] Side-by-side panel comparison view
- [ ] Weekly/daily temporal resolution (if data available)

## Credits

**Principal Investigator**: Lawrence David, Duke University
**Lab**: [The David Lab](https://www.ladlab.org/)
**Technology**: FoodSeq - DNA-based dietary tracking

## License

Research use only. Contact the David Lab for collaboration opportunities.

---

*For detailed design decisions and implementation notes, see [DESIGN.md](DESIGN.md)*
