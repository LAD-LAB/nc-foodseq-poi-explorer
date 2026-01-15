const fs = require('fs');
const path = require('path');
const https = require('https');

// Manhole and pump station locations from spreadsheet
const samplingLocations = [
    { tract: "1.02", assetId: "29962", address: "310 W Club Blvd, Durham, NC 27704" },
    { tract: "3.01", assetId: "31067", address: "1210 Onslow St, Durham, NC 27705" },
    { tract: "3.02", assetId: "21349", address: "613 W Club Blvd, Durham, NC 27701" },
    { tract: "5", assetId: "27508", address: "1200-1250 Wells St, Durham, NC 27707" },
    { tract: "10.01", assetId: "29754", address: "Long Meadow Pool, Durham, NC" },
    { tract: "10.02", assetId: "30659", address: "1400 E Geer St, Durham, NC 27704" },
    { tract: "13.01", assetId: "28175", address: "Grant Park (South), off Dupree St, Durham, NC" },
    { tract: "16.03", assetId: "25387", address: "224 Latta Rd, Durham, NC" },
    { tract: "17.09", assetId: "PS213", address: "2420 Old Oxford Rd, Durham, NC" },
    { tract: "18.02", assetId: "PS103", address: "314 E End Ave, Durham, NC" },
    { tract: "20.17", assetId: "30804", address: "4232 Garrett Rd, Durham, NC" }
];

// Geocode an address using Nominatim (OpenStreetMap)
async function geocodeAddress(address) {
    return new Promise((resolve, reject) => {
        const encodedAddress = encodeURIComponent(address);
        const url = `https://nominatim.openstreetmap.org/search?q=${encodedAddress}&format=json&limit=1`;

        const options = {
            headers: {
                'User-Agent': 'NC-FoodSeq-POI-Explorer'
            }
        };

        https.get(url, options, (res) => {
            let data = '';

            res.on('data', chunk => {
                data += chunk;
            });

            res.on('end', () => {
                try {
                    const results = JSON.parse(data);
                    if (results.length > 0) {
                        resolve({
                            lat: parseFloat(results[0].lat),
                            lon: parseFloat(results[0].lon)
                        });
                    } else {
                        resolve(null);
                    }
                } catch (e) {
                    reject(e);
                }
            });
        }).on('error', reject);
    });
}

// Calculate distance between two points in meters (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3; // Earth's radius in meters
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ/2) * Math.sin(Δλ/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

    return R * c; // Distance in meters
}

// Count POIs within radius of a location
function countPOIsNearLocation(locationCoords, poiData, radius = 1000) {
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

    Object.entries(poiData.categories).forEach(([category, pois]) => {
        pois.forEach(poi => {
            const distance = calculateDistance(
                locationCoords.lat,
                locationCoords.lon,
                poi.lat,
                poi.lon
            );

            if (distance <= radius) {
                counts[category]++;
                counts.total++;
            }
        });
    });

    return counts;
}

// Sleep function to respect rate limits
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
    try {
        console.log('NC FoodSeq - Manhole POI Analysis');
        console.log('==================================\n');

        // Load POI data
        const poiDataPath = path.join(__dirname, '..', 'data', 'nc_pois.json');
        const poiData = JSON.parse(fs.readFileSync(poiDataPath, 'utf8'));

        console.log('Loaded POI data');
        console.log(`Total POIs: ${Object.values(poiData.categories).reduce((sum, cat) => sum + cat.length, 0)}\n`);

        const results = [];

        // Process each location
        for (let i = 0; i < samplingLocations.length; i++) {
            const location = samplingLocations[i];
            console.log(`[${i + 1}/${samplingLocations.length}] Processing ${location.tract} (${location.assetId})...`);

            // Geocode address
            const coords = await geocodeAddress(location.address);

            if (!coords) {
                console.log(`  ⚠ Could not geocode: ${location.address}`);
                results.push({
                    ...location,
                    lat: null,
                    lon: null,
                    error: 'Geocoding failed'
                });
                await sleep(1000); // Rate limit
                continue;
            }

            console.log(`  ✓ Coordinates: ${coords.lat.toFixed(4)}, ${coords.lon.toFixed(4)}`);

            // Count POIs within 1km radius
            const counts = countPOIsNearLocation(coords, poiData, 1000);

            console.log(`  POIs within 1km: ${counts.total}`);
            console.log(`    Grocery: ${counts.grocery}, Restaurants: ${counts.restaurant}, Fast Food: ${counts.fast_food}`);

            results.push({
                ...location,
                lat: coords.lat,
                lon: coords.lon,
                ...counts
            });

            // Rate limit: wait 1 second between requests
            await sleep(1000);
        }

        // Generate output
        console.log('\n\n=== RESULTS FOR SPREADSHEET ===\n');

        // CSV header
        const csvHeader = 'Tract,Asset ID,Address,Latitude,Longitude,Grocery,Restaurant,Fast Food,Seafood,Butcher,Bakery,Greengrocer,Marketplace,University,Total POIs (1km)';
        console.log(csvHeader);

        // CSV rows
        results.forEach(r => {
            if (r.error) {
                console.log(`${r.tract},${r.assetId},"${r.address}",,,,,,,,,,,ERROR`);
            } else {
                console.log(
                    `${r.tract},${r.assetId},"${r.address}",${r.lat.toFixed(6)},${r.lon.toFixed(6)},` +
                    `${r.grocery},${r.restaurant},${r.fast_food},${r.seafood},${r.butcher},` +
                    `${r.bakery},${r.greengrocer},${r.marketplace},${r.university},${r.total}`
                );
            }
        });

        // Save to file
        const outputPath = path.join(__dirname, '..', 'data', 'manhole_poi_analysis.csv');
        const csvContent = [csvHeader, ...results.map(r => {
            if (r.error) {
                return `${r.tract},${r.assetId},"${r.address}",,,,,,,,,,,ERROR`;
            }
            return `${r.tract},${r.assetId},"${r.address}",${r.lat.toFixed(6)},${r.lon.toFixed(6)},` +
                   `${r.grocery},${r.restaurant},${r.fast_food},${r.seafood},${r.butcher},` +
                   `${r.bakery},${r.greengrocer},${r.marketplace},${r.university},${r.total}`;
        })].join('\n');

        fs.writeFileSync(outputPath, csvContent);
        console.log(`\n✓ Results saved to: ${outputPath}`);
        console.log('\nYou can copy-paste these columns into your Google Sheet!');

    } catch (error) {
        console.error('\n✗ Error:', error.message);
        process.exit(1);
    }
}

main();
