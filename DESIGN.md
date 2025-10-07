# NC FoodSeq Wastewater Visualization - Design Document

## Project Overview

### Goal
Create an interactive web-based visualization of FoodSeq data from 39 wastewater treatment plants across North Carolina. The tool enables users to explore plant and animal species detected in different regions over time.

### Target Audience
Entrepreneurs and venture capitalists (specifically for Google VC pitch demo)

### Timeline
MVP needed ASAP for collaborator demonstration

---

## Architecture

### Tech Stack
- **Mapping**: Leaflet.js (lightweight, no API keys, runs offline)
- **Charts**: Chart.js (simple, professional-looking)
- **Framework**: Vanilla JavaScript + HTML/CSS (no build tools, maximum simplicity)
- **Deployment**: Local demo (single HTML file)

### Design Principles
1. **Simplicity over features** - MVP first, enhancements later
2. **Self-contained** - Runs entirely in browser, no server needed
3. **Professional appearance** - Suitable for VC pitch
4. **Fast implementation** - 6-8 hours total development time

---

## Data Structure

### File Organization
```
wastewater/src/
├── index.html                  # Main application (self-contained)
├── data/
│   ├── foodseq_data.json      # Main species abundance data
│   ├── nc_counties.geojson    # NC county boundaries
│   └── plant_locations.json   # Treatment plant coordinates
├── venv/                       # Python virtual environment (local)
├── generate_toy_data.py        # Data generation script
├── .gitignore                  # Git ignore file
└── DESIGN.md                   # This document
```

### Data Formats

#### foodseq_data.json
```json
{
  "dates": ["2024-01", "2024-02", ..., "2024-12"],
  "plants": {
    "plant_001": {
      "name": "Durham WWTP",
      "lat": 35.99,
      "lng": -78.90,
      "county": "Durham",
      "timeseries": {
        "2024-01": {
          "plants": {
            "Zea mays": 1250,
            "Glycine max": 890,
            ...
          },
          "animals": {
            "Bos taurus": 450,
            "Sus scrofa": 320,
            ...
          }
        },
        "2024-02": { ... }
      }
    },
    "plant_002": { ... }
  },
  "species_metadata": {
    "Zea mays": "Corn",
    "Glycine max": "Soybean",
    "Bos taurus": "Cattle",
    "Sus scrofa": "Pig",
    ...
  }
}
```

#### nc_counties.geojson
Standard GeoJSON with NC county polygons (100 counties)

---

## Data Specifications

### Scale
- **Treatment plants**: 39 across NC
- **Plant species**: ~198 detected
- **Animal species**: ~70 detected
- **Temporal resolution**: Monthly (12 time points)
- **Geographic**: 1 plant per county (simplified for MVP)

### Species Data
- Scientific names as primary keys
- Common names in metadata for display
- Abundance values (relative or absolute counts from FoodSeq)

---

## Features

### Core Features (MVP)

#### 1. Interactive Map
- Display NC with county boundaries
- Treatment plant markers at correct lat/long coordinates
- Click county to open data panel
- Multiple counties can be selected simultaneously

#### 2. Data Visualization
- Semi-transparent overlay panel per selected county
- Tabs: "Plants" | "Animals"
- Horizontal bar chart showing top 25 species by abundance
- Species labeled with common names (scientific names in tooltip)
- Chart updates based on timeline slider

#### 3. Temporal Navigation
- Slider at bottom of map (12 positions for months)
- Scrubbing updates all open panels in real-time
- Display current month/year

#### 4. Visual Design
- Professional color scheme
- Semi-transparent panels (don't obscure map)
- Clear typography
- Smooth transitions
- Legend explaining interaction

### Future Enhancements (Post-MVP)
- Side-by-side county comparison view
- Export data/charts as images
- Species search/filter
- Heatmap view of total diversity
- Aggregate regional statistics
- Multiple plants per county
- Weekly/daily temporal resolution
- Species detail pages with ecological info
- Animation mode (auto-play through timeline)

---

## Setup Instructions

### Python Environment Setup
```bash
# Create virtual environment (in project folder)
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On Mac/Linux
# or
venv\Scripts\activate  # On Windows

# Install dependencies (once created)
pip install -r requirements.txt
```

### Running the Application
1. Generate toy data: `python generate_toy_data.py`
2. Open `index.html` in your browser

---

## Implementation Plan

### Phase 1: Data Generation (1-2 hours)
**Tasks:**
1. Create Python script `generate_toy_data.py`
2. Generate 39 realistic NC treatment plant locations
3. Create realistic plant species list (~198 taxa)
4. Create realistic animal species list (~70 taxa)
5. Generate synthetic monthly abundance data (12 months)
6. Export to JSON format
7. Download/create NC county GeoJSON

**Deliverables:**
- `data/foodseq_data.json`
- `data/nc_counties.geojson`
- `generate_toy_data.py` (for future updates)

### Phase 2: Map Setup (1-2 hours)
**Tasks:**
1. Create `index.html` skeleton
2. Include Leaflet.js and Chart.js via CDN
3. Initialize Leaflet map centered on NC
4. Load and display county boundaries
5. Add treatment plant markers
6. Style map controls and basemap

**Deliverables:**
- Functional map with counties and plant markers

### Phase 3: Core Interactivity (2-3 hours)
**Tasks:**
1. Implement county click handler
2. Create overlay panel component
3. Build Plant/Animal tab switcher
4. Implement Chart.js bar chart (top 25 species)
5. Enable multiple simultaneous panels
6. Add close button for panels
7. Position panels to avoid overlap

**Deliverables:**
- Clickable counties showing species data

### Phase 4: Temporal Slider (1 hour)
**Tasks:**
1. Create timeline slider UI
2. Connect slider to data filtering
3. Update all open panels on slider change
4. Display current date label
5. Smooth transitions between time points

**Deliverables:**
- Working temporal navigation

### Phase 5: Polish & Testing (1-2 hours)
**Tasks:**
1. Professional color scheme (NC-themed)
2. Improve typography and spacing
3. Add legends and instructions
4. Test on different screen sizes
5. Optimize performance
6. Add loading states
7. Final bug fixes

**Deliverables:**
- Production-ready demo

---

## Technical Decisions

### Why Vanilla JS?
- No build process = faster development
- Single file = easy to share/demo
- No dependencies to manage
- Perfect for MVP scope

### Why Leaflet over Mapbox/Google Maps?
- Works offline
- No API keys needed
- Lightweight
- Open source
- Sufficient for our needs

### Why Chart.js?
- Simple API
- Good defaults
- Responsive
- Well-documented
- Fast rendering

### Data in JSON vs Database?
- Dataset is small (~39 plants × 12 months × ~268 species)
- No server required
- Easy to update
- Fast client-side filtering

---

## Data Generation Strategy

### Treatment Plant Locations
Use real NC cities with major WWTPs:
- Charlotte, Raleigh, Durham, Greensboro, Winston-Salem
- Asheville, Wilmington, Fayetteville, Cary, High Point
- ... (39 total across all regions)

### Species Selection
**Plants (198):**
- Common crops: corn, soybean, wheat, rice
- Vegetables: tomato, lettuce, carrot, broccoli
- Fruits: apple, orange, banana, strawberry
- Grains and legumes
- Nuts and seeds
- Herbs and spices

**Animals (70):**
- Livestock: cattle, pig, chicken, turkey
- Fish: salmon, tuna, tilapia, catfish
- Shellfish: shrimp, crab, oyster
- Other meats: lamb, goat, duck

### Abundance Patterns
- Realistic distributions (log-normal)
- Regional variation (coastal vs mountain)
- Seasonal patterns (higher produce in summer)
- Dominant species (corn, soy, cattle, chicken)
- Long tail of rare species

---

## User Interaction Flow

1. User opens `index.html` in browser
2. Map of NC appears with county boundaries and plant markers
3. User clicks a county (e.g., Durham)
4. Semi-transparent panel appears showing:
   - County name
   - Plant/Animal tabs
   - Bar chart of top 25 plant species (default view)
5. User clicks "Animals" tab → chart switches to animal species
6. User clicks another county → second panel appears
7. User drags timeline slider → both panels update to new month
8. User closes panels via X button

---

## Visual Design Specifications

### Color Scheme
- Map background: Light gray/tan
- Counties: Light blue stroke, white fill
- Selected county: Highlighted blue fill
- Plant markers: Green circles with white border
- Panel background: White with 85% opacity
- Charts: Sequential blue color scale (light to dark by abundance)

### Typography
- Headers: 18px, bold
- Labels: 14px, regular
- Chart text: 12px

### Layout
- Map: Full viewport
- Panels: 400px width, max 600px height
- Panels cascade from click location
- Timeline slider: Bottom center, 60% viewport width

---

## Testing Checklist

- [ ] Map renders correctly
- [ ] County boundaries visible and clickable
- [ ] Plant markers at correct locations
- [ ] Panels open on county click
- [ ] Multiple panels can be open
- [ ] Plant/Animal tabs switch correctly
- [ ] Charts show top 25 species
- [ ] Timeline slider updates data
- [ ] All 12 months have data
- [ ] Panel close buttons work
- [ ] Responsive on different screen sizes
- [ ] No console errors
- [ ] Smooth performance with multiple panels

---

## Known Limitations (MVP)

1. **No server**: All data must be loaded upfront
2. **Single plant per county**: Simplified geography
3. **No data export**: Users can only view
4. **No search**: Must browse species visually
5. **Static toy data**: Not real FoodSeq measurements yet
6. **No mobile optimization**: Designed for laptop/desktop demo

---

## Future Data Integration

When real FoodSeq data is available:

1. **Data pipeline:**
   - CSV → JSON conversion script
   - Taxonomic name standardization
   - Common name lookup
   - Quality filtering
   - Temporal aggregation

2. **Schema updates:**
   - Add confidence scores
   - Include sample sizes
   - Add metadata (sample dates, processing info)
   - Support multiple plants per county

3. **Validation:**
   - Cross-check with known food consumption patterns
   - Flag anomalies
   - Compare with dietary surveys

---

## Maintenance & Updates

### Updating Data
1. Modify `generate_toy_data.py` or create conversion script
2. Regenerate `foodseq_data.json`
3. Refresh browser to see changes

### Adding Features
- Document new features in this file first
- Update implementation plan
- Maintain backward compatibility with data format

### Version History
- **v0.1** (Current): MVP with toy data
- **v0.2** (Planned): Real data integration
- **v0.3** (Planned): Enhanced comparison features

---

## Contact & Collaboration

**Principal Investigator**: Lawrence David, Duke University
**Project**: NC FoodSeq Wastewater Monitoring
**Repository**: [Local development - will be hosted later]

---

*Last updated: 2025-10-07*
