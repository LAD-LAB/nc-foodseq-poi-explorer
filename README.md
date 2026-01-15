# NC FoodSeq POI Explorer

Interactive web-based visualization of FoodSeq wastewater data with OpenStreetMap Points of Interest overlay for dietary context analysis across North Carolina.

## Quick Start

### Run Locally

```bash
# Clone the repository
git clone https://github.com/LAD-LAB/nc-foodseq-poi-explorer.git
cd nc-foodseq-poi-explorer

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

### Points of Interest (POI) Overlays ✨ NEW

Explore the food retail environment with OpenStreetMap data overlays:

**9 POI Categories** (28,442 total locations):
- 🛒 **Grocery Stores** (5,014) - Supermarkets, grocery stores, convenience stores
- 🍽️ **Restaurants** (12,931) - Full-service dining with ethnic/culinary labels
- 🍔 **Fast Food** (9,453) - Quick service restaurants
- 🐟 **Seafood Markets** (51) - Fresh and frozen seafood retailers
- 🥩 **Butcher Shops** (72) - Meat markets
- 🥖 **Bakeries** (330) - Bread and pastry shops
- 🥬 **Produce Shops** (34) - Greengrocers and produce markets
- 🏪 **Farmers Markets** (82) - Local farmers markets
- 🎓 **Universities/Colleges** (475) - Higher education institutions

**Features:**
- **Zoom-Dependent Display**: POI markers only appear when zoomed in (≥ zoom level 11) to reduce clutter
- **Service Area Overlays**: Toggle button to show/hide approximate catchment areas (~15km radius) for each wastewater treatment plant
- Toggle POI layers on/off via control panel (left side of screen)
- Marker clustering for performance with large datasets
- Click individual POI markers to see details (name, type, address, cuisine, OSM link)
- Ethnic/culinary group labels for all restaurants (Asian, Latin American, European, etc.)
- "Show All" / "Hide All" quick toggles
- POI markers render below treatment plant markers (proper z-ordering)

**Research Applications:**
- Correlate seafood shop density with fish DNA detection patterns
- Identify food deserts and compare with dietary diversity indicators
- Analyze restaurant density impact on dietary complexity
- Study ethnic food markets and specialty ingredient detection (Asian, Latin American, etc.)
- Compare coastal vs inland food retail environments
- Analyze proximity to universities/colleges and specific demographic/retail patterns

## Project Structure

```
nc-foodseq-poi-explorer/
├── index.html                         # Main application (single-file)
├── data/
│   ├── foodseq_data.json             # FoodSeq species data (2020-2021)
│   ├── nc_counties.geojson           # NC county boundaries
│   ├── nc_population_density.geojson # Population density by block group
│   ├── nc_demographics.geojson       # Census demographic data
│   └── nc_pois.json                  # OpenStreetMap POI data (27,967 locations)
├── scripts/
│   └── fetch_pois.js                 # POI data generator script
├── .gitignore
└── README.md
```

## Technology Stack

- **Leaflet.js 1.9.4** - Interactive mapping
- **Leaflet.markercluster 1.5.3** - POI marker clustering
- **Chart.js 4.4.0** - Data visualization
- **Vanilla JavaScript** - Application logic
- **OpenStreetMap** - Free map tiles and POI data
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

### nc_pois.json (~8 MB)
OpenStreetMap Points of Interest data for North Carolina:
- 28,442 food-related locations and institutions
- 9 categories (grocery, restaurants, fast food, specialty food, farmers markets, universities)
- Includes: coordinates, names, addresses, types, ethnic/culinary groups for restaurants
- Source: OpenStreetMap via Overpass API
- License: ODbL (OpenStreetMap)
- Generated: January 2026

**To update POI data:**
```bash
cd scripts
node fetch_pois.js
```

## Usage

1. **View County Data**: Click any county or treatment plant marker
2. **Switch Species**: Use "Plants"/"Animals" tabs in the panel
3. **Compare Counties**: Click multiple counties to open multiple panels
4. **Navigate Time**: Click time period buttons at bottom
5. **Change Map View**: Use layer buttons on the right side
6. **Toggle Service Areas**: Click "Service Areas" button to show/hide wastewater treatment plant catchment areas
7. **Toggle POI Layers**: Use POI control panel on the left side
   - POI markers only appear when zoomed in (zoom level 11+)
   - Check/uncheck categories to show/hide POI markers
   - Click "Show All" or "Hide All" for quick toggling
   - Click POI markers to see location details (name, address, cuisine type, etc.)
8. **Rearrange Panels**: Drag panels by their headers
9. **Close Panels**: Click the × button

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
- Leaflet.markercluster CSS/JS: `unpkg.com/leaflet.markercluster@1.5.3`
- Chart.js: `cdn.jsdelivr.net/npm/chart.js@4.4.0`

All dependencies are free and open source. No API keys required.

## Credits

**Principal Investigator**: Lawrence David, Duke University
**Lab**: [The David Lab](https://www.ladlab.org/)
**Technology**: FoodSeq - DNA-based dietary tracking

## License

Research use only. Contact the David Lab for collaboration opportunities.
