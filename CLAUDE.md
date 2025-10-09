# FoodSeq Interactive Map Project

## Project Setup
- Create README

## Project Overview
Creating an interactive web-based map to visualize FoodSeq data. This project combines epidemiological data analysis with web-based data visualization.

**Primary Goal**: Develop a prototype interactive map that can be hosted locally and eventually deployed to the web.

## Background
- **Developer**: Epidemiologist transitioning from R/Python to web development
- **Data Source**: FoodSeq surveillance data
- **Current Workflow**: Data analysis primarily in R/Python, new to web development

## Tech Stack

### Data Processing
- **Python 3.x** or **R 4.x** for data cleaning and preparation
- **Libraries**: pandas, geopandas (Python) or sf, tidyverse (R)
- **Output**: GeoJSON or CSV files for web consumption

### Web Visualization
- **HTML/CSS/JavaScript** - core web technologies
- **Leaflet.js** or **Mapbox GL JS** - interactive mapping library
- **D3.js** (optional) - if we need custom data visualizations
- **Local Server**: Python's `http.server` or VS Code Live Server extension

### Version Control & Documentation
- **Git/GitHub** - version control
- **Markdown** - documentation format

## Coding Standards

### General Principles
- **Prioritize clarity over cleverness** - code should be readable by future you
- **Comment liberally** - explain the "why" behind data processing decisions
- **Keep it simple** - use straightforward approaches, avoid over-engineering
- **Document as you go** - update README and docs with each feature

### Python/R Code
- Use descriptive variable names that reflect epidemiological concepts
- Add docstrings/comments explaining statistical methods
- Keep data processing scripts modular and reusable
- Follow PEP 8 (Python) or tidyverse style guide (R)

### JavaScript/Web Code
- Use clear, descriptive variable names
- Add comments explaining data structure and mapping logic
- Keep functions small and focused
- Use `const` and `let`, avoid `var`
- Format code consistently (use Prettier if possible)

### Data Files
- **Keep raw data unchanged** - always work on copies
- **Document data transformations** - note what was done and why
- **Use standard formats**: GeoJSON for map data, CSV for tabular data
- **Include data dictionaries** - explain what each variable means

## File Organization

### Data Directory Structure
```
data/
├── raw/                    # Original, untouched data (git-ignored)
├── processed/              # Cleaned data ready for visualization
├── scripts/                # Data processing scripts
│   ├── 01_clean_data.py
│   ├── 02_geocode.py
│   └── 03_export_geojson.py
└── README.md              # Data documentation
```

### Source Code Structure
```
src/
├── index.html             # Main page
├── css/
│   └── styles.css         # Styling
├── js/
│   ├── map.js            # Map initialization and configuration
│   ├── data-loader.js    # Load and process data
│   └── utils.js          # Helper functions
└── data/                  # Processed data files for web (symlink or copy)
```

## Git Workflow

### Branch Strategy
- `main` - stable, working version
- `dev` - active development branch
- `feature/description` - for new features (e.g., `feature/add-filters`)
- `fix/description` - for bug fixes

### Commit Guidelines
**IMPORTANT**: Use clear, descriptive commit messages following this format:

```
<type>: <brief description>

<optional detailed explanation>

<optional references to issues/tickets>
```

**Types**:
- `feat:` - New feature (e.g., "feat: add date range filter to map")
- `fix:` - Bug fix (e.g., "fix: correct geocoding for US territories")
- `data:` - Data updates (e.g., "data: update FoodSeq dataset to Q4 2024")
- `docs:` - Documentation (e.g., "docs: add data dictionary for isolate types")
- `style:` - Formatting, no code change (e.g., "style: format Python scripts with black")
- `refactor:` - Code restructuring (e.g., "refactor: modularize data processing pipeline")
- `test:` - Adding tests
- `chore:` - Maintenance (e.g., "chore: update .gitignore")

**Examples of good commits**:
```bash
git commit -m "feat: add interactive legend to map showing isolate types"
git commit -m "data: add 2024 FoodSeq data and update processing script"
git commit -m "docs: document data processing workflow in README"
git commit -m "fix: resolve marker clustering issue at high zoom levels"
```

### Automatic Documentation Updates
When making changes, always update relevant documentation in the **same commit**:

**Rule**: If you modify code, update the corresponding documentation before committing.

Example workflow:
```bash
# 1. Make code changes
# 2. Update relevant docs (README, comments, data dictionary, etc.)
# 3. Stage both code and docs together
git add src/js/map.js docs/features.md README.md
git commit -m "feat: add date range filter

Added interactive date slider to filter outbreaks by time period.
Updated README with usage instructions and features.md with technical details."
```

### What to Document
- **README.md**: Project overview, setup instructions, how to use
- **docs/data-dictionary.md**: Explanation of all data fields
- **docs/features.md**: List of map features and how they work
- **Code comments**: Explain complex logic, data transformations, epidemiological context
- **Inline comments in data scripts**: Document assumptions, data cleaning decisions

### When to Commit
- After completing a discrete, working feature
- Before switching tasks or branches
- At the end of each work session
- Keep commits atomic (one logical change per commit)

### Push Frequency
- Push to GitHub at least once per day when actively working
- Always push before sharing with supervisor or collaborators
- Push after completing a feature, even if not perfect

## Documentation Requirements

### README.md Must Include
- Project description and goals
- Setup instructions (how to get the project running locally)
- Data sources and how to update them
- Usage instructions (how to view/interact with the map)
- Project status and roadmap

### Code Documentation
- Every data processing script should have a header explaining:
  - What it does
  - Input data expected
  - Output generated
  - Author and date
- Complex functions need docstrings/comments
- Document any epidemiological assumptions or methodologies

### Data Documentation
- Maintain a data dictionary explaining all variables
- Document data sources and collection methods
- Note any data quality issues or limitations
- Include metadata (date ranges, geographic coverage, etc.)

## Development Workflow

### Starting a New Feature
```bash
# 1. Ensure you're on dev branch
git checkout dev
git pull origin dev

# 2. Create feature branch
git checkout -b feature/description

# 3. Work on feature, committing regularly
# 4. Update documentation as you go
# 5. When complete, merge back to dev
git checkout dev
git merge feature/description
git push origin dev
```

### Daily Workflow
1. Pull latest changes: `git pull origin dev`
2. Work on your task
3. Test locally (open index.html in browser)
4. Update relevant documentation
5. Commit with clear message
6. Push to GitHub
7. Update project board or notes on progress

## Testing Checklist

Before committing major changes:
- [ ] Map loads without errors (check browser console)
- [ ] Data displays correctly
- [ ] Interactive features work (zoom, pan, click markers)
- [ ] Works in both Chrome and Safari
- [ ] Documentation updated
- [ ] No sensitive data exposed
- [ ] Code is commented

## Security & Data Privacy

### Critical Rules
- **NEVER commit sensitive/identifiable data to GitHub**
- Add `data/raw/` to `.gitignore`
- Only commit aggregated or anonymized data
- Review data files before committing
- Consider privacy implications of geographic precision

### .gitignore Essentials
```
# Data
data/raw/
*.csv
*.xlsx
!data/processed/aggregated_data.geojson  # Only commit safe files

# System files
.DS_Store
*.pyc
__pycache__/
.Rhistory
.RData

# Sensitive
.env
config/secrets.json
```

## Helpful Commands

### Git
```bash
git status                          # Check what's changed
git add .                          # Stage all changes
git commit -m "type: message"      # Commit with message
git push origin dev                # Push to GitHub
git log --oneline                  # View commit history
```

### Python Local Server
```bash
cd foodseq-map
python -m http.server 8000
# Then visit: http://localhost:8000
```

### R Local Server
```R
servr::httd(dir = ".", port = 8000)
```

## Learning Resources

### Map Libraries
- Leaflet.js Quick Start: https://leafletjs.com/examples/quick-start/
- Mapbox GL JS Documentation: https://docs.mapbox.com/mapbox-gl-js/

### General Web Development
- MDN Web Docs: https://developer.mozilla.org/
- JavaScript basics for your use case

## Communication with Claude

### What to tell Claude
- **Context**: "I'm working on the FoodSeq map project"
- **Background**: Mention if this relates to epidemiological analysis
- **Skill level**: "I'm comfortable with R/Python but new to web development"
- **Specific issue**: Provide error messages, describe unexpected behavior

### Good questions to ask
- "How do I convert this R dataframe to GeoJSON for the web map?"
- "Explain how this JavaScript code works - I'm used to Python"
- "What's the best way to visualize time-series outbreak data on a map?"
- "How can I make the map more accessible for public health users?"

## Project-Specific Notes

### FoodSeq Data Considerations
- Data typically includes: isolate IDs, dates, locations, pathogen types, sources
- Geographic precision: balance detail vs. privacy
- Temporal dimension: consider animated or time-filtered displays
- Categorical data: pathogen serotypes, food sources, outbreak clusters

### Visualization Goals
- Make patterns visible to public health practitioners
- Enable filtering by date, pathogen type, geographic region
- Show relationships between outbreaks/clusters
- Keep interface intuitive for non-technical users

## Before Every Commit - Checklist

- [ ] Code works locally without errors
- [ ] Comments added to explain new/complex code
- [ ] README updated if setup/usage changed
- [ ] Relevant documentation updated
- [ ] No sensitive data being committed
- [ ] Commit message is clear and follows format
- [ ] Changes are atomic (one logical change)

## Supervisor Collaboration

- Keep main branch stable for demos
- Use dev branch for active work
- Push regularly so supervisor can review progress
- Document features clearly for non-technical review
- Include screenshots in docs when helpful

---

**Remember**: Perfect is the enemy of good. Focus on getting something working, document it well, commit often, and iterate!