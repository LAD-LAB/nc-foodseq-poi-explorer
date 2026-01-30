const fs = require('fs');
const path = require('path');

// Durham County census tracts to analyze
const targetTracts = [
    "1.02", "3.01", "3.02", "5", "7", "10.01", "10.02", "13.01", "14",
    "16.03", "16.04", "17.05", "17.12", "17.09", "18.02", "18.06", "18.08",
    "19", "20.29", "20.2", "20.23", "23"
];

// Convert tract number to GEOID format
// Durham County code is 063, NC is 37
// Example: "17.06" -> "37063001706"
function tractToGEOID(tract) {
    // Remove decimal, pad with zeros to 6 digits
    const tractNum = tract.replace('.', '').padStart(6, '0');
    return `37063${tractNum}`;
}

// Calculate polygon centroid
function calculateCentroid(coordinates) {
    // Handle MultiPolygon and Polygon
    let coords = coordinates;
    if (coordinates[0][0][0] && Array.isArray(coordinates[0][0][0])) {
        // MultiPolygon - use first polygon
        coords = coordinates[0];
    }

    // Get outer ring
    const ring = coords[0];

    let xSum = 0;
    let ySum = 0;
    let count = ring.length;

    ring.forEach(point => {
        xSum += point[0]; // longitude
        ySum += point[1]; // latitude
    });

    return {
        lon: xSum / count,
        lat: ySum / count
    };
}

// Check if point is inside polygon
function pointInPolygon(point, polygon) {
    const [x, y] = point;
    let inside = false;

    for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
        const xi = polygon[i][0], yi = polygon[i][1];
        const xj = polygon[j][0], yj = polygon[j][1];

        const intersect = ((yi > y) !== (yj > y))
            && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
        if (intersect) inside = !inside;
    }

    return inside;
}

// Count POIs within census tract boundary
function countPOIsInTract(tractGeometry, poiData) {
    const counts = {
        grocery: 0,
        restaurant: 0,
        fast_food: 0,
        seafood: 0,
        butcher: 0,
        bakery: 0,
        greengrocer: 0,
        marketplace: 0,
        university: 0,
        total: 0
    };

    // Get polygon coordinates
    let polygon;
    if (tractGeometry.type === 'Polygon') {
        polygon = tractGeometry.coordinates[0];
    } else if (tractGeometry.type === 'MultiPolygon') {
        polygon = tractGeometry.coordinates[0][0];
    }

    // Check each POI
    Object.entries(poiData.categories).forEach(([category, pois]) => {
        pois.forEach(poi => {
            if (pointInPolygon([poi.lon, poi.lat], polygon)) {
                counts[category]++;
                counts.total++;
            }
        });
    });

    return counts;
}

async function main() {
    try {
        console.log('NC FoodSeq - Census Tract POI Analysis');
        console.log('======================================\n');

        // Load data files
        const demographicsPath = path.join(__dirname, '..', 'data', 'nc_demographics.geojson');
        const poiDataPath = path.join(__dirname, '..', 'data', 'nc_pois.json');

        const demographics = JSON.parse(fs.readFileSync(demographicsPath, 'utf8'));
        const poiData = JSON.parse(fs.readFileSync(poiDataPath, 'utf8'));

        console.log('Loaded census tract data:', demographics.features.length, 'total tracts');
        console.log('Loaded POI data:', Object.values(poiData.categories).reduce((sum, cat) => sum + cat.length, 0), 'total POIs\n');

        const results = [];
        let foundCount = 0;
        let notFoundCount = 0;

        // Process each target tract
        for (const tract of targetTracts) {
            const geoid = tractToGEOID(tract);
            console.log(`Processing Tract ${tract} (GEOID: ${geoid})...`);

            // Find tract in demographics data
            const tractFeature = demographics.features.find(f => f.properties.GEOID === geoid);

            if (!tractFeature) {
                console.log(`  ⚠ Not found in census data`);
                results.push({
                    tract: tract,
                    geoid: geoid,
                    found: false,
                    error: 'Not found in census data'
                });
                notFoundCount++;
                continue;
            }

            foundCount++;

            // Calculate centroid
            const centroid = calculateCentroid(tractFeature.geometry.coordinates);
            console.log(`  ✓ Centroid: ${centroid.lat.toFixed(4)}, ${centroid.lon.toFixed(4)}`);

            // Count POIs within tract boundary
            const countsInBoundary = countPOIsInTract(tractFeature.geometry, poiData);
            console.log(`  POIs in tract boundary: ${countsInBoundary.total}`);
            console.log(`    Grocery: ${countsInBoundary.grocery}, Restaurants: ${countsInBoundary.restaurant}, Fast Food: ${countsInBoundary.fast_food}`);

            results.push({
                tract: tract,
                geoid: geoid,
                found: true,
                lat: centroid.lat,
                lon: centroid.lon,
                median_income: tractFeature.properties.median_income,
                pct_foreign_born: tractFeature.properties.pct_foreign_born,
                pct_white: tractFeature.properties.pct_white,
                pct_black: tractFeature.properties.pct_black,
                pct_asian: tractFeature.properties.pct_asian,
                pct_hispanic: tractFeature.properties.pct_hispanic,
                ...countsInBoundary
            });
        }

        console.log(`\n\nSummary: Found ${foundCount}/${targetTracts.length} tracts`);
        if (notFoundCount > 0) {
            console.log(`⚠ ${notFoundCount} tracts not found - they may use different naming in 2020 census\n`);
        }

        // Generate CSV output
        console.log('\n=== RESULTS FOR SPREADSHEET ===\n');

        const csvHeader = 'Tract,GEOID,Latitude,Longitude,Median Income,% Foreign Born,% White,% Black,% Asian,% Hispanic,Grocery,Restaurant,Fast Food,Seafood,Butcher,Bakery,Greengrocer,Marketplace,University,Total POIs';
        console.log(csvHeader);

        results.forEach(r => {
            if (!r.found) {
                console.log(`${r.tract},${r.geoid},,,,,,,,,,,,,,,,,,ERROR: Not Found`);
            } else {
                console.log(
                    `${r.tract},${r.geoid},${r.lat.toFixed(6)},${r.lon.toFixed(6)},` +
                    `${r.median_income || ''},${r.pct_foreign_born?.toFixed(2) || ''},` +
                    `${r.pct_white?.toFixed(2) || ''},${r.pct_black?.toFixed(2) || ''},` +
                    `${r.pct_asian?.toFixed(2) || ''},${r.pct_hispanic?.toFixed(2) || ''},` +
                    `${r.grocery},${r.restaurant},${r.fast_food},${r.seafood},${r.butcher},` +
                    `${r.bakery},${r.greengrocer},${r.marketplace},${r.university},` +
                    `${r.total}`
                );
            }
        });

        // Save to file
        const outputPath = path.join(__dirname, '..', 'data', 'census_tract_poi_analysis.csv');
        const csvContent = [csvHeader, ...results.map(r => {
            if (!r.found) {
                return `${r.tract},${r.geoid},,,,,,,,,,,,,,,,,,ERROR: Not Found`;
            }
            return `${r.tract},${r.geoid},${r.lat.toFixed(6)},${r.lon.toFixed(6)},` +
                   `${r.median_income || ''},${r.pct_foreign_born?.toFixed(2) || ''},` +
                   `${r.pct_white?.toFixed(2) || ''},${r.pct_black?.toFixed(2) || ''},` +
                   `${r.pct_asian?.toFixed(2) || ''},${r.pct_hispanic?.toFixed(2) || ''},` +
                   `${r.grocery},${r.restaurant},${r.fast_food},${r.seafood},${r.butcher},` +
                   `${r.bakery},${r.greengrocer},${r.marketplace},${r.university},` +
                   `${r.total}`;
        })].join('\n');

        fs.writeFileSync(outputPath, csvContent);
        console.log(`\n✓ Results saved to: ${outputPath}`);
        console.log('\nYou can import this CSV into your Google Sheet!');

    } catch (error) {
        console.error('\n✗ Error:', error.message);
        console.error(error.stack);
        process.exit(1);
    }
}

main();
