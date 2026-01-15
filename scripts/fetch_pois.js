const https = require('https');
const fs = require('fs');
const path = require('path');

// North Carolina bounding box
const NC_BBOX = '33.8,-84.4,36.6,-75.4';

// Overpass API query
const OVERPASS_QUERY = `
[out:json][timeout:120];
(
  node["shop"="supermarket"](${NC_BBOX});
  node["shop"="grocery"](${NC_BBOX});
  node["shop"="convenience"](${NC_BBOX});
  node["amenity"="restaurant"](${NC_BBOX});
  node["amenity"="fast_food"](${NC_BBOX});
  node["shop"="butcher"](${NC_BBOX});
  node["shop"="seafood"](${NC_BBOX});
  node["shop"="bakery"](${NC_BBOX});
  node["shop"="greengrocer"](${NC_BBOX});
  node["amenity"="marketplace"](${NC_BBOX});
  node["amenity"="university"](${NC_BBOX});
  node["amenity"="college"](${NC_BBOX});
  node["amenity"="charging_station"](${NC_BBOX});
  node["leisure"="fitness_centre"](${NC_BBOX});

  way["shop"="supermarket"](${NC_BBOX});
  way["amenity"="restaurant"](${NC_BBOX});
  way["amenity"="fast_food"](${NC_BBOX});
  way["amenity"="university"](${NC_BBOX});
  way["amenity"="college"](${NC_BBOX});
  way["amenity"="charging_station"](${NC_BBOX});
  way["leisure"="fitness_centre"](${NC_BBOX});
);
out center;
`;

async function fetchFromOverpass() {
  const url = 'https://overpass-api.de/api/interpreter';

  return new Promise((resolve, reject) => {
    console.log('Querying Overpass API...');

    const postData = `data=${encodeURIComponent(OVERPASS_QUERY)}`;

    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = https.request(url, options, (res) => {
      let data = '';

      res.on('data', chunk => {
        data += chunk;
        process.stdout.write('.');
      });

      res.on('end', () => {
        console.log('\nReceived response');
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error('Failed to parse JSON response'));
        }
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

function processPOIs(rawData) {
  console.log('Processing POI data...');

  const categories = {
    grocery: [],
    restaurant: [],
    fast_food: [],
    seafood: [],
    butcher: [],
    bakery: [],
    greengrocer: [],
    marketplace: [],
    university: [],
    ev_charging: [],
    gym: []
  };

  // Ethnic food group mapping
  const ethnicFoodGroups = {
    'chinese': 'Asian',
    'japanese': 'Asian',
    'thai': 'Asian',
    'vietnamese': 'Asian',
    'korean': 'Asian',
    'indian': 'South Asian',
    'pakistani': 'South Asian',
    'mexican': 'Latin American',
    'latin_american': 'Latin American',
    'spanish': 'Latin American',
    'italian': 'European',
    'french': 'European',
    'greek': 'Mediterranean',
    'mediterranean': 'Mediterranean',
    'middle_eastern': 'Middle Eastern',
    'ethiopian': 'African',
    'african': 'African',
    'caribbean': 'Caribbean',
    'american': 'American',
    'regional': 'American',
    'southern': 'American'
  };

  function getEthnicGroup(cuisine) {
    if (!cuisine) return 'Other';
    const cuisineLower = cuisine.toLowerCase();
    for (const [key, group] of Object.entries(ethnicFoodGroups)) {
      if (cuisineLower.includes(key)) {
        return group;
      }
    }
    return 'Other';
  }

  rawData.elements.forEach(element => {
    const cuisine = element.tags?.cuisine;
    const poi = {
      id: element.id,
      lat: element.lat || element.center?.lat,
      lon: element.lon || element.center?.lon,
      name: element.tags?.name,
      type: element.tags?.shop || element.tags?.amenity,
      address: {
        street: element.tags?.['addr:street'],
        city: element.tags?.['addr:city'],
        state: element.tags?.['addr:state'],
        postcode: element.tags?.['addr:postcode']
      },
      brand: element.tags?.brand,
      cuisine: cuisine,
      ethnic_group: getEthnicGroup(cuisine)
    };

    // Skip if no coordinates
    if (!poi.lat || !poi.lon) return;

    // Categorize
    if (element.tags?.shop === 'supermarket' ||
        element.tags?.shop === 'grocery' ||
        element.tags?.shop === 'convenience') {
      categories.grocery.push(poi);
    } else if (element.tags?.amenity === 'restaurant') {
      categories.restaurant.push(poi);
    } else if (element.tags?.amenity === 'fast_food') {
      categories.fast_food.push(poi);
    } else if (element.tags?.shop === 'seafood') {
      categories.seafood.push(poi);
    } else if (element.tags?.shop === 'butcher') {
      categories.butcher.push(poi);
    } else if (element.tags?.shop === 'bakery') {
      categories.bakery.push(poi);
    } else if (element.tags?.shop === 'greengrocer') {
      categories.greengrocer.push(poi);
    } else if (element.tags?.amenity === 'marketplace') {
      categories.marketplace.push(poi);
    } else if (element.tags?.amenity === 'university' || element.tags?.amenity === 'college') {
      categories.university.push(poi);
    } else if (element.tags?.amenity === 'charging_station') {
      poi.operator = element.tags?.operator;
      poi.capacity = element.tags?.capacity;
      categories.ev_charging.push(poi);
    } else if (element.tags?.leisure === 'fitness_centre') {
      poi.type = 'fitness_centre';
      categories.gym.push(poi);
    }
  });

  return {
    generated: new Date().toISOString(),
    source: 'OpenStreetMap via Overpass API',
    license: 'ODbL (OpenStreetMap)',
    attribution: '© OpenStreetMap contributors',
    categories
  };
}

async function main() {
  try {
    console.log('NC FoodSeq Viz - POI Data Generator');
    console.log('====================================\n');

    const rawData = await fetchFromOverpass();
    const processed = processPOIs(rawData);

    // Create data directory if it doesn't exist
    const dataDir = path.join(__dirname, '..', 'data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    const outputPath = path.join(dataDir, 'nc_pois.json');
    fs.writeFileSync(outputPath, JSON.stringify(processed, null, 2));

    console.log('\n✓ POI data saved to:', outputPath);
    console.log('\nSummary:');
    console.log('--------');
    let total = 0;
    Object.entries(processed.categories).forEach(([cat, pois]) => {
      console.log(`  ${cat}: ${pois.length}`);
      total += pois.length;
    });
    console.log(`  TOTAL: ${total}`);

  } catch (error) {
    console.error('\n✗ Error:', error.message);
    process.exit(1);
  }
}

main();
