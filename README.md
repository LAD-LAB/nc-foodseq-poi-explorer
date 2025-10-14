# NC FoodSeq Wastewater Visualization

Interactive web-based visualization of FoodSeq data from wastewater treatment plants across North Carolina.

## Quick Start

### Run Locally

```bash
# Clone the repository
git clone https://github.com/LAD-LAB/nc-foodseq-viz.git
cd nc-foodseq-viz

# Checkout the web-deploy branch
git checkout web-deploy

# Start a local web server
python3 -m http.server 8000

# Open in browser
open http://localhost:8000
```

Visit `http://localhost:8000` in your browser.

## Features

- **Interactive Map**: Click on NC counties or treatment plant markers to view species data
- **Dual Species Views**: Toggle between plant and animal species detection
- **Top 25 Display**: Color-coded bar charts showing most abundant species
- **Temporal Navigation**: Time period selector (May 2020 - June 2021)
- **Dynamic Markers**: Location markers change color based on data availability
  - Green: No data for selected time period
  - Red: Has data for selected time period
- **Census Data Overlays**: Multiple demographic and population layers
  - Population Density (block group level)
  - Median Income (census tract)
  - Race/Ethnicity percentages (census tract)
- **Multi-Panel Comparison**: View multiple counties simultaneously
- **Draggable Panels**: Rearrange panels for custom layouts

## Project Structure

```
nc-foodseq-viz/
├── index.html                         # Main application (single-file)
├── data/
│   ├── foodseq_data.json             # FoodSeq species data (2020-2021)
│   ├── nc_counties.geojson           # NC county boundaries
│   ├── nc_population_density.geojson # Population density by block group
│   └── nc_demographics.geojson       # Census demographic data
├── .gitignore
└── README.md
```

## Technology Stack

- **Leaflet.js 1.9.4** - Interactive mapping
- **Chart.js 4.4.0** - Data visualization
- **Vanilla JavaScript** - Application logic
- No build tools required - runs entirely in the browser

## Data Files

### foodseq_data.json (576 KB)
Real FoodSeq surveillance data containing:
- 20 wastewater treatment plants across NC
- 292 species (179 plants, 113 animals)
- 9 time periods (May 2020 - June 2021)
- Species metadata with common names and food group classifications

### nc_counties.geojson (82 KB)
North Carolina county boundaries for map overlay.

### nc_population_density.geojson (5.5 MB)
2020 Census block group-level population density data.

### nc_demographics.geojson (3.6 MB)
Census tract-level demographic data (ACS 2019-2023):
- Median household income
- Foreign born percentage
- Race/ethnicity percentages (White, Black, Asian, Hispanic/Latino)

## Usage

1. **View County Data**: Click any county or treatment plant marker
2. **Switch Species**: Use "Plants"/"Animals" tabs in the panel
3. **Compare Counties**: Click multiple counties to open multiple panels
4. **Navigate Time**: Click time period buttons at bottom
5. **Change Map View**: Use layer buttons on the right side
6. **Rearrange Panels**: Drag panels by their headers
7. **Close Panels**: Click the × button

## Development Notes

### Running the Application

The application **requires a local web server** to avoid CORS issues when loading JSON files. Options:

```bash
# Python 3
python3 -m http.server 8000

# Python 2
python -m SimpleHTTPServer 8000

# Node.js (if you have http-server installed)
npx http-server -p 8000
```

### Browser Compatibility

Tested on:
- Chrome/Edge (latest)
- Safari (latest)
- Firefox (latest)

### File Paths

All data files are loaded relative to `index.html`:
```javascript
fetch('data/foodseq_data.json')
fetch('data/nc_counties.geojson')
fetch('data/nc_population_density.geojson')
fetch('data/nc_demographics.geojson')
```

Ensure data files remain in the `data/` directory.

### External Dependencies

Loaded via CDN (no local installation needed):
- Leaflet CSS/JS: `unpkg.com/leaflet@1.9.4`
- Chart.js: `cdn.jsdelivr.net/npm/chart.js@4.4.0`

## Credits

**Principal Investigator**: Lawrence David, Duke University
**Lab**: [The David Lab](https://www.ladlab.org/)
**Technology**: FoodSeq - DNA-based dietary tracking

## License

Research use only. Contact the David Lab for collaboration opportunities.
