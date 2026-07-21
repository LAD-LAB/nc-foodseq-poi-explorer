# NC Wastewater FoodSeq — Project README

Dietary-DNA (FoodSeq) surveillance of North Carolina wastewater, paired with an
interactive map explorer, a food-environment (POI) layer, and a set of temporal
and demographic analyses. Maintained by the **David Lab, Duke University**
([ladlab.org](https://www.ladlab.org/)).

> **Live site:** [nc-foodseq-poi-explorer-community-h.vercel.app](https://nc-foodseq-poi-explorer-community-h.vercel.app/)

> **What this is.** FoodSeq amplifies food-derived DNA in wastewater to estimate
> what a community is eating — cheaply (`<$0.01`/person) and at population scale.
> This repo holds the sequencing→phyloseq pipeline, the reference databases, the
> downstream statistical analyses, and the web app that visualizes the results.

---

## At a glance

| | |
|---|---|
| Samples | 183 (147 longitudinal 2020–21 · 39 spatial 2021) |
| Municipalities | 19 · ~2.1M people monitored |
| Food taxa detected | 113 animal · 185 plant |
| Amplicons | **12S** (animal) · **_trnL_** (plant) |
| Food-read fraction | 98.9% animal · 76.5% plant |

Consolidated findings live in **`FoodSeq Results.html`** (slide deck) — open it in
a browser.

---

## Repository layout

This working directory currently holds **two related project trees**. See
`CLEANUP_PLAN.md` for a proposed consolidation.

```
.
├── nc-foodseq-poi-explorer/      # Web app + downstream analysis
│   ├── index.html                #   → single-file Leaflet/Chart.js map explorer
│   ├── data/                     #   GeoJSON, POI JSON, FoodSeq JSON, USDA/NOAA refs
│   ├── analysis/                 #   Python time-series, Mann–Kendall, POI correlation
│   ├── scripts/                  #   R/JS/Python data-prep & scraping utilities
│   ├── api/                      #   Vercel serverless (login, price scraping)
│   ├── 2023 Sushi Project/       #   Earlier sushi/salmon correlation study
│   ├── heatmap prediction validation/
│   ├── Photo Inventory/ · Receipts/   # Field documentation
│   └── README.md                 #   App-specific docs (run instructions, POI details)
│
└── Code and Data/                # Manuscript pipeline (NCWW paper)
    ├── code/                     #   R analysis + figure scripts (Figure_2A/2B, PCA, tobacco)
    ├── data/                     #   phyloseq .rds objects, taxa & metadata tables
    ├── food-dbs/                 #   12SV5 / trnL reference-database build (Rmd)
    └── mb-pipeline/              #   raw-reads → phyloseq pipeline (shell + Rmd) + protocols
```

---

## The web app — NC FoodSeq POI Explorer

Interactive map of FoodSeq wastewater data with an OpenStreetMap food-environment
overlay. **Single file, no build step.**

```bash
python3 -m http.server 8000      # a local server is required (CORS on local JSON)
open http://localhost:8000        # or visit in your browser
```

- **Stack:** Leaflet 1.9.4 · Leaflet.markercluster 1.5.3 · Chart.js 4.4.0 · vanilla JS
- **Features:** county / treatment-plant selection, plant vs animal species views,
  top-25 bar charts, time-period navigation, census overlays (density, income,
  race/ethnicity), draggable multi-panel comparison, POI categories
  (~28k locations), community health layers (food pantries, no-cost kids meals,
  community gardens), service-area catchments.

---

## The analysis pipeline

**Upstream — sequencing to phyloseq** (`Code and Data/mb-pipeline/`)
Demultiplex → trim → DADA2 → assign taxonomy against the 12SV5 / _trnL_ reference
databases (`Code and Data/food-dbs/`) → phyloseq `.rds` objects.

**Downstream — statistics & figures**
| Analysis | Location | Key output |
|---|---|---|
| Seafood detection ranking & consumption mismatch | `analysis/generate_seafood_report.py` | ρ ≈ 0.75 detection vs consumption |
| Species × food-environment POI correlations | `analysis/poi_species_correlation.py` | `poi_species_correlation.png` |
| Mann–Kendall temporal trends (daily & monthly) | `analysis/mann_kendall_*.py` | `mann_kendall_output/` |
| Seafood % of animal reads over time | `analysis/seafood_pct_durham_2025.py` | `seafood_pct_durham_2025.png` |
| Salmon / tilapia time-series | `analysis/foodseq_sushi_salmon_analysis.py` | report `.docx` |
| Manuscript figures (PCA, seasonal fish) | `Code and Data/code/Figure_2*.R` | manuscript figures |

Python analyses expect `pandas`, `numpy`, `scipy`, `matplotlib`, `python-docx`.
R scripts expect `phyloseq`, `tidyverse`, `Kendall`, `DECIPHER`.

---

## Data sources

- **FoodSeq sequencing** — David Lab wastewater surveillance (12S + _trnL_)
- **POIs** — OpenStreetMap via Overpass API (ODbL)
- **Consumption references** — NOAA/NFI per-capita seafood; USDA ERS food availability
- **Geography / demographics** — US Census (TIGER, ACS), NC OneMap

---

## Credits & license

**PI:** Lawrence David · **Lab:** [The David Lab](https://www.ladlab.org/), Duke University.
Research use only — contact the lab for collaboration. POI data © OpenStreetMap
contributors (ODbL).
