#!/usr/bin/env python3
"""
Process USDA Food Access Research Atlas data for NC census tracts.

Downloads the USDA ERS Food Access Research Atlas Excel file,
filters to North Carolina (FIPS 37), and maps 2010 census tracts
to 2020 census tracts using Census Bureau crosswalk file.

Output: data/usda_food_deserts.json

Usage:
    python scripts/process_usda_food_atlas.py

Requirements:
    pip install pandas openpyxl requests
"""

import json
import os
import sys
import requests
import pandas as pd
from pathlib import Path

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
DATA_DIR = PROJECT_DIR / "data"
OUTPUT_FILE = DATA_DIR / "usda_food_deserts.json"

# USDA Food Access Research Atlas download URL
USDA_URL = "https://www.ers.usda.gov/webdocs/DataFiles/80591/FoodAccessResearchAtlasData2019.xlsx"

# Census Bureau 2020-to-2010 tract relationship file for NC
CROSSWALK_URL = "https://www2.census.gov/geo/docs/maps-data/data/rel2020/tract/tab20_tract20_tract10_natl.txt"
CROSSWALK_FILE = DATA_DIR / "nc_tract_relationship_2020_2010.txt"

# NC demographics GeoJSON (for 2020 tract list)
DEMOGRAPHICS_FILE = DATA_DIR / "nc_demographics.geojson"


def download_file(url, dest, description="file"):
    """Download a file with progress indication."""
    print(f"Downloading {description}...")
    print(f"  URL: {url}")
    try:
        resp = requests.get(url, stream=True, timeout=120)
        resp.raise_for_status()
        total = int(resp.headers.get('content-length', 0))
        downloaded = 0
        with open(dest, 'wb') as f:
            for chunk in resp.iter_content(chunk_size=8192):
                f.write(chunk)
                downloaded += len(chunk)
                if total:
                    pct = downloaded / total * 100
                    print(f"\r  Progress: {pct:.1f}%", end="", flush=True)
        print(f"\n  Saved to {dest}")
        return True
    except Exception as e:
        print(f"\n  Error downloading: {e}")
        return False


def load_crosswalk():
    """Load or download the Census Bureau tract crosswalk file."""
    if not CROSSWALK_FILE.exists():
        # Download national file and filter to NC
        national_file = DATA_DIR / "tab20_tract20_tract10_natl.txt"
        if not national_file.exists():
            if not download_file(CROSSWALK_URL, national_file, "Census tract crosswalk"):
                return None

        print("Filtering crosswalk to NC tracts...")
        df = pd.read_csv(national_file, sep="|", dtype=str)
        # Filter to NC (state FIPS 37)
        nc_df = df[df['GEOID_TRACT_20'].str.startswith('37')]
        nc_df.to_csv(CROSSWALK_FILE, sep="|", index=False)
        print(f"  Saved {len(nc_df)} NC crosswalk records")
        return nc_df
    else:
        return pd.read_csv(CROSSWALK_FILE, sep="|", dtype=str)


def load_usda_atlas():
    """Load or download USDA Food Access Research Atlas data."""
    cache_file = DATA_DIR / "FoodAccessResearchAtlasData2019.xlsx"
    if not cache_file.exists():
        if not download_file(USDA_URL, cache_file, "USDA Food Access Research Atlas"):
            return None

    print("Reading USDA Food Access Research Atlas...")
    df = pd.read_excel(cache_file, sheet_name="Food Access Research Atlas",
                       dtype={'CensusTract': str})
    # Filter to NC (state FIPS 37)
    nc_df = df[df['State'] == 'North Carolina'].copy()
    print(f"  Found {len(nc_df)} NC tracts (2010 census)")
    return nc_df


def get_2020_tracts():
    """Get list of 2020 census tract GEOIDs from demographics GeoJSON."""
    print("Loading 2020 census tract GEOIDs...")
    with open(DEMOGRAPHICS_FILE, 'r') as f:
        geojson = json.load(f)
    tracts = {}
    for feat in geojson['features']:
        geoid = feat['properties'].get('GEOID', '')
        if geoid:
            tracts[geoid] = {
                'name': feat['properties'].get('NAME', ''),
                'median_income': feat['properties'].get('median_income', None)
            }
    print(f"  Found {len(tracts)} tracts in demographics GeoJSON")
    return tracts


def build_crosswalk_map(crosswalk_df):
    """
    Build mapping from 2020 tract -> 2010 tract.
    For each 2020 tract, pick the 2010 tract with the largest AREALAND_PART overlap.
    """
    print("Building 2020 -> 2010 tract crosswalk...")
    # Group by 2020 tract, pick 2010 tract with max area overlap
    crosswalk_df['AREALAND_PART'] = pd.to_numeric(
        crosswalk_df.get('AREALAND_PART', crosswalk_df.get('AREALAND_PART_20', 0)),
        errors='coerce'
    ).fillna(0)

    mapping = {}
    for geoid_20, group in crosswalk_df.groupby('GEOID_TRACT_20'):
        best_row = group.loc[group['AREALAND_PART'].idxmax()]
        geoid_10 = best_row.get('GEOID_TRACT_10', '')
        mapping[geoid_20] = geoid_10

    print(f"  Mapped {len(mapping)} 2020 tracts to 2010 tracts")
    return mapping


def process():
    """Main processing pipeline."""
    os.makedirs(DATA_DIR, exist_ok=True)

    # Load 2020 tract list
    tracts_2020 = get_2020_tracts()

    # Load USDA data
    usda_df = load_usda_atlas()
    if usda_df is None:
        print("ERROR: Could not load USDA data. Run generate_usda_food_deserts.py instead.")
        sys.exit(1)

    # Load crosswalk
    crosswalk_df = load_crosswalk()
    if crosswalk_df is None:
        print("ERROR: Could not load crosswalk data.")
        sys.exit(1)

    # Build 2020 -> 2010 mapping
    tract_map = build_crosswalk_map(crosswalk_df)

    # Index USDA data by 2010 tract GEOID
    usda_by_tract = {}
    for _, row in usda_df.iterrows():
        geoid_10 = str(row['CensusTract']).zfill(11)
        usda_by_tract[geoid_10] = row

    # Map USDA data to 2020 tracts
    print("Mapping USDA designations to 2020 tracts...")
    result_tracts = {}
    matched = 0
    unmatched = 0

    for geoid_20, info in tracts_2020.items():
        geoid_10 = tract_map.get(geoid_20)
        usda_row = usda_by_tract.get(geoid_10) if geoid_10 else None

        if usda_row is not None:
            matched += 1
            urban = bool(usda_row.get('Urban', 0))
            low_income = bool(usda_row.get('LITracts', 0))
            low_access_1 = bool(usda_row.get('LA1and10', 0))
            poverty_rate = float(usda_row.get('PovertyRate', 0))
            median_income_val = float(usda_row.get('MedianFamilyIncome', 0))
            pop = int(usda_row.get('Pop2010', 0))

            result_tracts[geoid_20] = {
                "urban": urban,
                "lowIncome": low_income,
                "lowAccess_1_10": low_access_1,
                "foodDesert": low_income and low_access_1,
                "povertyRate": round(poverty_rate, 1),
                "medianFamilyIncome": int(median_income_val),
                "pop": pop
            }
        else:
            unmatched += 1
            # Use demographics data as fallback
            mi = info.get('median_income')
            is_low_income = mi is not None and mi < 40000
            result_tracts[geoid_20] = {
                "urban": True,
                "lowIncome": is_low_income,
                "lowAccess_1_10": False,
                "foodDesert": False,
                "povertyRate": 0,
                "medianFamilyIncome": int(mi) if mi else 0,
                "pop": 0
            }

    print(f"  Matched: {matched}, Unmatched: {unmatched}")

    # Count food deserts
    n_deserts = sum(1 for t in result_tracts.values() if t['foodDesert'])
    print(f"  Total food deserts: {n_deserts} / {len(result_tracts)}")

    # Write output
    output = {
        "source": "USDA ERS Food Access Research Atlas 2019",
        "tracts": result_tracts
    }

    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"\nOutput written to {OUTPUT_FILE}")
    print(f"Total tracts: {len(result_tracts)}")
    print(f"Food deserts: {n_deserts} ({n_deserts/len(result_tracts)*100:.1f}%)")


if __name__ == "__main__":
    process()
