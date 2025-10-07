"""
Create a simplified NC counties GeoJSON from the full US counties dataset.
Filters to only NC counties (FIPS codes starting with 37).
"""

import json

# Load the full US counties GeoJSON
with open('data/nc_counties.geojson', 'r') as f:
    us_data = json.load(f)

# Filter to only NC counties (FIPS code starts with "37")
nc_features = []
for feature in us_data['features']:
    fips = feature['id']
    if fips.startswith('37'):
        nc_features.append(feature)

# Create NC-specific GeoJSON
nc_geojson = {
    "type": "FeatureCollection",
    "features": nc_features
}

# Save NC counties
with open('data/nc_counties.geojson', 'w') as f:
    json.dump(nc_geojson, f)

print(f"Created NC counties GeoJSON with {len(nc_features)} counties")
