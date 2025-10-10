# NC FoodSeq Wastewater Visualization

Interactive web-based visualization of FoodSeq data from 39 wastewater treatment plants across North Carolina.

![NC FoodSeq Demo](https://img.shields.io/badge/status-MVP-green)

## Overview

This tool enables exploration of plant and animal species detected in wastewater treatment plants across North Carolina. Users can click on counties to view the most abundant species and scrub through time to see temporal patterns.

## Features

- **Interactive Map**: Click on NC counties or treatment plant markers to view data
- **Dual Species Views**: Toggle between plant and animal species detection
- **Top 25 Display**: Bar charts showing the most abundant species
- **Temporal Navigation**: Slider to explore 12 months of data
- **Multi-Panel**: View multiple counties simultaneously for comparison
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

### Current Dataset (Real FoodSeq Data - 2020)

The visualization now uses **real FoodSeq data** from the NC Wastewater manuscript:

- **21 wastewater treatment plants** across NC
- **185 plant species** (Streptophyta phylum - food plants)
- **116 animal species** (food animals)
- **8 monthly time points** (May-December 2020)
- **Geographic coverage**: Coastal (Wilmington, Beaufort) to Mountain (Asheville, Marion) regions

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
│   ├── foodseq_data.json               # Current data (real 2020 data)
│   ├── nc_counties.geojson             # NC county boundaries
│   ├── raw/                            # Raw data (git-ignored)
│   │   └── NCWW_allsamples_02142025.rds
│   ├── processed/                      # Processed data outputs
│   │   └── foodseq_data.json
│   ├── scripts/                        # Data processing scripts
│   │   └── 01_convert_phyloseq_to_json.R
│   └── WORKFLOW.md                     # Data processing documentation
├── generate_toy_data.py                 # Toy data generation (testing)
├── create_nc_geojson.py                 # GeoJSON filter script
├── DESIGN.md                            # Design documentation
├── CLAUDE.md                            # Development workflow guide
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
4. **Navigate Time**: Use the timeline slider at the bottom
5. **Close Panels**: Click the × button on any panel

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

```bash
# Run R script to convert manuscript phyloseq data to JSON
Rscript data/scripts/01_convert_phyloseq_to_json.R

# Copy processed data to visualization directory
cp data/processed/foodseq_data.json data/foodseq_data.json
```

### Generate Toy Data (for testing)

```bash
# Generate synthetic data (optional, for testing)
python3 generate_toy_data.py
```

## Future Enhancements

- [x] Real FoodSeq data integration ✅ **Complete!**
- [ ] Enhanced species names (scientific → proper common names)
- [ ] Side-by-side county comparison
- [ ] Species search and filtering
- [ ] Data export functionality
- [ ] Heatmap view of diversity
- [ ] Animation mode for temporal visualization
- [ ] Multiple plants per county
- [ ] Weekly/daily temporal resolution

## Credits

**Principal Investigator**: Lawrence David, Duke University
**Lab**: [The David Lab](https://www.ladlab.org/)
**Technology**: FoodSeq - DNA-based dietary tracking

## License

Research use only. Contact the David Lab for collaboration opportunities.

---

*For detailed design decisions and implementation notes, see [DESIGN.md](DESIGN.md)*
