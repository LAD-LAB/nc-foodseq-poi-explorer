const fs = require('fs');
const path = require('path');

// Durham County census tracts to analyze
const targetTracts = [
    "1.02", "3.01", "3.02", "5", "7", "10.01", "10.02", "13.01", "14",
    "16.03", "16.04", "17.05", "17.12", "17.09", "18.02", "18.06", "18.08",
    "19", "20.29", "20.2", "20.23", "23"
];

// Convert tract number to GEOID format
// Examples: "5" -> "37063000500", "10.01" -> "37063001001", "20.29" -> "37063002029", "20.2" -> "37063002020"
function tractToGEOID(tract) {
    if (tract.includes('.')) {
        const parts = tract.split('.');
        const whole = parseInt(parts[0]);
        const decimal = parts[1];

        // Pad decimal part to 2 digits (e.g., "20.2" -> "20.20")
        const decimalPadded = decimal.padEnd(2, '0');

        // Combine: "20.20" -> "002020"
        const tractNum = (whole * 100 + parseInt(decimalPadded)).toString().padStart(6, '0');
        return `37063${tractNum}`;
    } else {
        // No decimal: "5" -> "000500", "14" -> "001400", "23" -> "002300"
        const num = parseInt(tract);
        const tractNum = (num * 100).toString().padStart(6, '0');
        return `37063${tractNum}`;
    }
}

// Parse gazetteer file (tab-delimited)
function parseGazetteer(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    const gazetteer = {};

    // Skip header line
    for (let i = 1; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue;

        const parts = line.split('\t');
        if (parts.length >= 8) {
            const geoid = parts[1];
            const lat = parseFloat(parts[6]);
            const lon = parseFloat(parts[7]);

            if (geoid && !isNaN(lat) && !isNaN(lon)) {
                gazetteer[geoid] = { lat, lon };
            }
        }
    }

    return gazetteer;
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
        console.log('NC FoodSeq - Census Tract POI Analysis with Gazetteer');
        console.log('======================================================\n');

        // Load gazetteer
        const gazetteerPath = path.join(__dirname, '..', 'data', 'nc_census_tracts_2020_gazetteer.txt');
        const gazetteer = parseGazetteer(gazetteerPath);
        console.log(`Loaded gazetteer with ${Object.keys(gazetteer).length} census tracts\n`);

        // Load data files
        const demographicsPath = path.join(__dirname, '..', 'data', 'nc_demographics.geojson');
        const poiDataPath = path.join(__dirname, '..', 'data', 'nc_pois.json');

        const demographics = JSON.parse(fs.readFileSync(demographicsPath, 'utf8'));
        const poiData = JSON.parse(fs.readFileSync(poiDataPath, 'utf8'));

        console.log('Loaded census tract data:', demographics.features.length, 'total tracts');
        console.log('Loaded POI data:', Object.values(poiData.categories).reduce((sum, cat) => sum + cat.length, 0), 'total POIs');

        // Verify POI categories
        console.log('\nPOI Categories:');
        Object.entries(poiData.categories).forEach(([cat, pois]) => {
            console.log(`  ${cat}: ${pois.length} POIs`);
        });
        console.log('');

        const results = [];
        let foundCount = 0;
        let notFoundInDemographics = 0;
        let foundInGazetteer = 0;

        // Process each target tract
        for (const tract of targetTracts) {
            const geoid = tractToGEOID(tract);
            console.log(`Processing Tract ${tract} (GEOID: ${geoid})...`);

            // Try to find in demographics data
            const tractFeature = demographics.features.find(f => f.properties.GEOID === geoid);

            if (tractFeature) {
                // Found in demographics - use existing method
                foundCount++;

                const countsInBoundary = countPOIsInTract(tractFeature.geometry, poiData);

                // Calculate centroid from geometry
                let coords = tractFeature.geometry.coordinates;
                if (coords[0][0][0] && Array.isArray(coords[0][0][0])) {
                    coords = coords[0];
                }
                const ring = coords[0];
                let xSum = 0, ySum = 0;
                ring.forEach(point => {
                    xSum += point[0];
                    ySum += point[1];
                });
                const centroid = {
                    lon: xSum / ring.length,
                    lat: ySum / ring.length
                };

                console.log(`  ✓ Found in demographics, Centroid: ${centroid.lat.toFixed(4)}, ${centroid.lon.toFixed(4)}`);
                console.log(`  POIs in tract boundary: ${countsInBoundary.total}`);

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
            } else {
                // Not found in demographics - check gazetteer
                notFoundInDemographics++;

                if (gazetteer[geoid]) {
                    foundInGazetteer++;
                    console.log(`  ✓ Found in gazetteer: ${gazetteer[geoid].lat.toFixed(6)}, ${gazetteer[geoid].lon.toFixed(6)}`);
                    console.log(`  ⚠ No boundary data - cannot count POIs accurately`);

                    results.push({
                        tract: tract,
                        geoid: geoid,
                        found: true,
                        lat: gazetteer[geoid].lat,
                        lon: gazetteer[geoid].lon,
                        median_income: null,
                        pct_foreign_born: null,
                        pct_white: null,
                        pct_black: null,
                        pct_asian: null,
                        pct_hispanic: null,
                        grocery: 0,
                        restaurant: 0,
                        fast_food: 0,
                        seafood: 0,
                        butcher: 0,
                        bakery: 0,
                        greengrocer: 0,
                        marketplace: 0,
                        university: 0,
                        total: 0,
                        note: 'No boundary data'
                    });
                } else {
                    console.log(`  ✗ Not found in demographics or gazetteer`);
                    results.push({
                        tract: tract,
                        geoid: geoid,
                        found: false,
                        error: 'Not found'
                    });
                }
            }
        }

        console.log(`\n\nSummary:`);
        console.log(`  Found in demographics with boundaries: ${foundCount}`);
        console.log(`  Found in gazetteer only (no boundaries): ${foundInGazetteer}`);
        console.log(`  Not found anywhere: ${notFoundInDemographics - foundInGazetteer}`);
        console.log(`  Total: ${targetTracts.length}\n`);

        // Generate CSV output
        console.log('\n=== RESULTS FOR SPREADSHEET ===\n');

        const csvHeader = 'Tract,GEOID,Latitude,Longitude,Median Income,% Foreign Born,% White,% Black,% Asian,% Hispanic,Grocery,Restaurant,Fast Food,Seafood,Butcher,Bakery,Greengrocer,Marketplace,University,Total POIs,Note';
        console.log(csvHeader);

        results.forEach(r => {
            if (!r.found) {
                console.log(`${r.tract},${r.geoid},,,,,,,,,,,,,,,,,ERROR: Not Found,`);
            } else {
                const note = r.note || '';
                console.log(
                    `${r.tract},${r.geoid},${r.lat.toFixed(6)},${r.lon.toFixed(6)},` +
                    `${r.median_income || ''},${r.pct_foreign_born?.toFixed(2) || ''},` +
                    `${r.pct_white?.toFixed(2) || ''},${r.pct_black?.toFixed(2) || ''},` +
                    `${r.pct_asian?.toFixed(2) || ''},${r.pct_hispanic?.toFixed(2) || ''},` +
                    `${r.grocery},${r.restaurant},${r.fast_food},${r.seafood},${r.butcher},` +
                    `${r.bakery},${r.greengrocer},${r.marketplace},${r.university},` +
                    `${r.total},${note}`
                );
            }
        });

        // Save to file
        const outputPath = path.join(__dirname, '..', 'data', 'census_tract_poi_analysis.csv');
        const csvContent = [csvHeader, ...results.map(r => {
            if (!r.found) {
                return `${r.tract},${r.geoid},,,,,,,,,,,,,,,,,ERROR: Not Found,`;
            }
            const note = r.note || '';
            return `${r.tract},${r.geoid},${r.lat.toFixed(6)},${r.lon.toFixed(6)},` +
                   `${r.median_income || ''},${r.pct_foreign_born?.toFixed(2) || ''},` +
                   `${r.pct_white?.toFixed(2) || ''},${r.pct_black?.toFixed(2) || ''},` +
                   `${r.pct_asian?.toFixed(2) || ''},${r.pct_hispanic?.toFixed(2) || ''},` +
                   `${r.grocery},${r.restaurant},${r.fast_food},${r.seafood},${r.butcher},` +
                   `${r.bakery},${r.greengrocer},${r.marketplace},${r.university},` +
                   `${r.total},${note}`;
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
