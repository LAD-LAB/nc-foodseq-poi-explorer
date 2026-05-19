#!/usr/bin/env python3
"""
Price scraper for NC FoodSeq Explorer — Food Near Me feature.

Sources:
  1. Kroger API (Harris Teeter) — real store-specific prices
  2. Playwright (Walmart, ALDI, Food Lion) — headless browser scraping
  3. USDA baseline — fallback for stores/items that can't be scraped

Usage:
    python scripts/scrape_prices.py

Output:
    data/prices.json
"""

import json
import os
import sys
import time
import base64
import random
from datetime import datetime
from pathlib import Path

try:
    import requests
except ImportError:
    os.system("pip install requests")
    import requests

try:
    from dotenv import load_dotenv
except ImportError:
    os.system("pip install python-dotenv")
    from dotenv import load_dotenv

# Load environment
script_dir = Path(__file__).parent
project_dir = script_dir.parent
load_dotenv(project_dir / '.env')

# ========== FOOD SEARCH TERMS ==========
with open(script_dir / 'food_search_terms.json') as f:
    FOOD_TERMS = json.load(f)

# ========== USDA BASELINE PRICES (fallback) ==========
USDA_PRICES = {
    "banana": 0.65, "tomatoes": 2.15, "chicken breast": 3.99, "white rice": 1.09,
    "romaine lettuce": 2.49, "atlantic salmon fillet": 9.99, "pork chops": 4.29,
    "ground beef": 5.49, "sesame seeds": 0.35, "blueberries": 3.99, "oats": 1.49,
    "broccoli": 2.29, "asparagus": 3.49, "green tea": 4.29, "chickpeas canned": 1.29,
    "lentils dry": 1.99, "wheat bread": 3.49, "turkey breast": 5.99, "peanuts": 3.49,
    "tofu": 2.49, "green peas frozen": 1.79, "black beans canned": 1.19, "garlic": 0.79,
    "yellow onion": 1.29, "apples": 1.89, "jalapeno peppers": 1.99, "cocoa powder": 4.99,
    "flax seeds": 5.49, "barley": 2.29, "beets": 2.99, "lamb chops": 12.99,
    "bell peppers": 1.29, "strawberries": 3.49, "carrots": 1.29, "kale": 2.49,
    "potatoes": 1.09, "lima beans": 1.39, "okra": 3.49, "kiwi": 0.69,
    "pistachios": 8.99, "cashews": 7.99, "sweet potato": 1.49, "turmeric": 0.99,
    "pineapple": 3.49,
    # New additions
    "catfish fillet": 6.99, "tilapia fillet": 5.49, "canned tuna": 1.49,
    "anchovies": 2.99, "shrimp": 8.99, "crab meat": 14.99, "rainbow trout": 8.99,
    "cod fillet": 7.99, "sardines canned": 2.49, "herring": 4.99, "mackerel": 5.99,
    "barramundi fillet": 10.99, "artichoke": 2.49, "arugula": 3.49, "fresh basil": 2.49,
    "avocado": 1.49, "hazelnuts": 7.99, "persimmon": 1.99, "mango": 1.49,
    "pomegranate": 2.99, "figs": 5.99, "coconut": 2.49, "peaches": 2.49,
    "walnuts": 6.99, "pecans": 8.99, "fresh ginger": 4.99, "grapes": 2.49,
    "cucumber": 0.79, "fresh spinach": 3.49, "corn on the cob": 0.79,
    "whole wheat flour": 0.69, "adzuki beans": 3.49, "bass fillet": 9.99,
    "bluefish fillet": 7.99,
}

STORE_TIERS = {
    "food-lion": {"name": "Food Lion", "tier": "budget", "factor": 0.90},
    "aldi": {"name": "ALDI", "tier": "budget", "factor": 0.82},
    "walmart": {"name": "Walmart", "tier": "budget", "factor": 0.85},
    "publix": {"name": "Publix", "tier": "mid", "factor": 1.08},
    "lowes-foods": {"name": "Lowes Foods", "tier": "mid", "factor": 1.02},
    "fresh-market": {"name": "The Fresh Market", "tier": "premium", "factor": 1.25},
    "whole-foods": {"name": "Whole Foods Market", "tier": "premium", "factor": 1.35},
    "weaver-street": {"name": "Weaver Street Market", "tier": "premium", "factor": 1.30},
    "compare-foods": {"name": "Compare Foods", "tier": "budget", "factor": 0.88},
}


# ========== KROGER API (Harris Teeter) ==========
class KrogerScraper:
    def __init__(self):
        self.client_id = os.getenv('KROGER_CLIENT_ID')
        self.client_secret = os.getenv('KROGER_CLIENT_SECRET')
        self.token = None
        self.stores = {}  # locationId -> store info

    def authenticate(self):
        if not self.client_id or not self.client_secret:
            print("  [Kroger] No API credentials found in .env")
            return False
        auth = base64.b64encode(f'{self.client_id}:{self.client_secret}'.encode()).decode()
        resp = requests.post('https://api.kroger.com/v1/connect/oauth2/token',
            headers={'Authorization': f'Basic {auth}', 'Content-Type': 'application/x-www-form-urlencoded'},
            data={'grant_type': 'client_credentials', 'scope': 'product.compact'})
        if resp.status_code == 200:
            self.token = resp.json()['access_token']
            print("  [Kroger] Authenticated successfully")
            return True
        print(f"  [Kroger] Auth failed: {resp.status_code}")
        return False

    def find_stores(self, zipcode='27701', radius=10):
        resp = requests.get('https://api.kroger.com/v1/locations',
            headers={'Authorization': f'Bearer {self.token}'},
            params={'filter.zipCode.near': zipcode, 'filter.radiusInMiles': radius, 'filter.limit': 10})
        if resp.status_code == 200:
            for loc in resp.json().get('data', []):
                self.stores[loc['locationId']] = {
                    'name': loc['name'],
                    'address': loc['address']['addressLine1'],
                    'city': loc['address']['city'],
                    'chain': loc.get('chain', 'HART'),
                    'lat': loc['geolocation']['latitude'],
                    'lon': loc['geolocation']['longitude'],
                }
            print(f"  [Kroger] Found {len(self.stores)} Harris Teeter stores")

    def search_product(self, search_term, location_id):
        """Search for a product at a specific store, return best match with price."""
        resp = requests.get('https://api.kroger.com/v1/products',
            headers={'Authorization': f'Bearer {self.token}'},
            params={'filter.term': search_term, 'filter.locationId': location_id, 'filter.limit': 3})
        if resp.status_code != 200:
            return None
        products = resp.json().get('data', [])
        for p in products:
            items = p.get('items', [])
            if not items:
                continue
            price_info = items[0].get('price', {})
            regular = price_info.get('regular')
            promo = price_info.get('promo')
            if regular:
                return {
                    'product_name': p.get('description', search_term),
                    'price': promo if promo and promo > 0 else regular,
                    'regular_price': regular,
                    'promo_price': promo if promo and promo > 0 else None,
                    'size': items[0].get('size', ''),
                    'source': 'kroger_api',
                }
        return None

    def scrape_all(self, food_terms):
        """Scrape prices for all foods across all stores."""
        prices = []
        for store_id, store_info in self.stores.items():
            print(f"  [Kroger] Scraping {store_info['name']}...")
            for food_id, food_info in food_terms.items():
                search = food_info.get('search')
                if not search:
                    continue
                result = self.search_product(search, store_id)
                if result:
                    prices.append({
                        'food_id': food_id,
                        'store_id': f"harris-teeter-{store_id}",
                        'store_name': store_info['name'],
                        'store_brand': 'Harris Teeter',
                        'store_address': store_info['address'],
                        'store_lat': store_info['lat'],
                        'store_lon': store_info['lon'],
                        'product_name': result['product_name'],
                        'price': result['price'],
                        'regular_price': result['regular_price'],
                        'promo_price': result['promo_price'],
                        'unit': food_info.get('unit', ''),
                        'size': result['size'],
                        'source': 'kroger_api',
                        'scraped_at': datetime.now().strftime('%Y-%m-%d'),
                    })
                time.sleep(0.15)  # Rate limiting
        return prices


# ========== PLAYWRIGHT SCRAPER (multiple stores) ==========
PLAYWRIGHT_STORES = {
    'walmart': {
        'brand': 'Walmart',
        'tier': 'budget',
        'search_url': 'https://www.walmart.com/search?q={query}',
        'price_selectors': [
            '[data-automation-id="product-price"] .f2',
            '[itemprop="price"]',
            'span[data-testid="price-wrap"] .f2',
        ],
        'name_selectors': [
            '[data-automation-id="product-title"] span',
            'span.lh-title',
        ],
        'locations': [
            {'id': 'walmart-durham-1', 'name': 'Walmart Supercenter', 'address': '1525 Glenn School Rd', 'lat': 35.954, 'lon': -78.876},
            {'id': 'walmart-durham-2', 'name': 'Walmart Supercenter', 'address': '5450 New Hope Commons Dr', 'lat': 35.903, 'lon': -78.996},
        ],
    },
    'foodlion': {
        'brand': 'Food Lion',
        'tier': 'budget',
        'search_url': 'https://www.foodlion.com/search/?searchTerm={query}',
        'price_selectors': [
            '[class*="price"] [class*="amount"]',
            '[data-testid="product-price"]',
            '.product-price',
            'span.price',
        ],
        'name_selectors': [
            '[class*="product-title"]',
            '[data-testid="product-name"]',
            '.product-name',
        ],
        'locations': [
            {'id': 'food-lion-1', 'name': 'Food Lion', 'address': '3500 Witherspoon Blvd', 'lat': 35.972, 'lon': -78.912},
            {'id': 'food-lion-2', 'name': 'Food Lion', 'address': '2011 Chapel Hill Rd', 'lat': 35.976, 'lon': -78.930},
            {'id': 'food-lion-3', 'name': 'Food Lion', 'address': '4711 Hope Valley Rd', 'lat': 35.936, 'lon': -78.946},
        ],
    },
    'aldi': {
        'brand': 'ALDI',
        'tier': 'budget',
        'search_url': 'https://www.aldi.us/products/?q={query}',
        'price_selectors': [
            '[class*="price"]',
            '.product-price',
            'span.base-price',
        ],
        'name_selectors': [
            '[class*="product-title"]',
            '.product-name',
        ],
        'locations': [
            {'id': 'aldi-durham-1', 'name': 'ALDI', 'address': '3460 Hillsborough Rd', 'lat': 35.995, 'lon': -78.935},
            {'id': 'aldi-durham-2', 'name': 'ALDI', 'address': '4037 Durham Chapel Hill Blvd', 'lat': 35.952, 'lon': -78.968},
        ],
    },
    'wholefoods': {
        'brand': 'Whole Foods Market',
        'tier': 'premium',
        'search_url': 'https://www.amazon.com/s?k={query}&i=wholefoods',
        'price_selectors': [
            '.a-price .a-offscreen',
            'span.a-price span',
        ],
        'name_selectors': [
            'h2 a span',
            '.a-text-normal',
        ],
        'locations': [
            {'id': 'whole-foods-1', 'name': 'Whole Foods Market', 'address': '621 Broad St', 'lat': 36.007, 'lon': -78.921},
        ],
    },
    'publix': {
        'brand': 'Publix',
        'tier': 'mid',
        'search_url': 'https://www.publix.com/shop/search/{query}',
        'price_selectors': [
            '[class*="price"]',
            '.product-price',
        ],
        'name_selectors': [
            '[class*="product-name"]',
            '.product-title',
        ],
        'locations': [
            {'id': 'publix-durham-1', 'name': 'Publix', 'address': '621 Ninth St', 'lat': 36.003, 'lon': -78.916},
            {'id': 'publix-durham-2', 'name': 'Publix', 'address': '4600 Chapel Hill Blvd', 'lat': 35.948, 'lon': -78.973},
        ],
    },
}

import re

class PlaywrightScraper:
    def __init__(self):
        self.browser = None
        self.context = None

    def init_browser(self):
        try:
            from playwright.sync_api import sync_playwright
            self.pw = sync_playwright().start()
            self.browser = self.pw.chromium.launch(headless=True)
            self.context = self.browser.new_context(
                user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                viewport={'width': 1280, 'height': 720}
            )
            print("  [Playwright] Browser launched")
            return True
        except Exception as e:
            print(f"  [Playwright] Browser failed: {e}")
            return False

    def extract_price(self, text):
        """Extract a numeric price from text like '$3.49', '3.49/lb', 'current price $3.49'."""
        matches = re.findall(r'(\d+\.\d{2})', text)
        for m in matches:
            price = float(m)
            if 0.01 < price < 500:
                return price
        return None

    def scrape_store(self, store_key, store_config, food_terms):
        """Scrape one store chain for all food items."""
        prices = []
        brand = store_config['brand']
        page = self.context.new_page()
        success = 0
        fail = 0

        print(f"  [Playwright] Scraping {brand}...")

        for food_id, food_info in food_terms.items():
            search = food_info.get('search')
            if not search:
                continue

            try:
                url = store_config['search_url'].format(query=search.replace(' ', '+'))
                page.goto(url, timeout=15000, wait_until='domcontentloaded')
                time.sleep(2.5)

                # Try each price selector
                price_val = None
                for selector in store_config['price_selectors']:
                    try:
                        els = page.query_selector_all(selector)
                        for el in els[:3]:
                            text = el.inner_text().strip()
                            p = self.extract_price(text)
                            if p:
                                price_val = p
                                break
                        if price_val:
                            break
                    except:
                        continue

                # Try to get product name
                prod_name = search.title()
                for selector in store_config['name_selectors']:
                    try:
                        el = page.query_selector(selector)
                        if el:
                            prod_name = el.inner_text().strip()[:80]
                            break
                    except:
                        continue

                if price_val:
                    success += 1
                    for loc in store_config['locations']:
                        prices.append({
                            'food_id': food_id,
                            'store_id': loc['id'],
                            'store_name': loc['name'],
                            'store_brand': brand,
                            'store_address': loc['address'],
                            'store_lat': loc['lat'],
                            'store_lon': loc['lon'],
                            'product_name': prod_name,
                            'price': price_val,
                            'unit': food_info.get('unit', ''),
                            'source': f'playwright_{store_key}',
                            'scraped_at': datetime.now().strftime('%Y-%m-%d'),
                        })
                    sys.stdout.write('.')
                    sys.stdout.flush()
                else:
                    fail += 1

            except Exception as e:
                fail += 1

            time.sleep(1)

        page.close()
        print(f"\n    {brand}: {success} found, {fail} missed")
        return prices

    def scrape_all(self, food_terms):
        all_prices = []
        for store_key, config in PLAYWRIGHT_STORES.items():
            try:
                prices = self.scrape_store(store_key, config, food_terms)
                all_prices.extend(prices)
            except Exception as e:
                print(f"    {config['brand']} failed: {e}")
        return all_prices

    def close(self):
        if self.context:
            self.context.close()
        if self.browser:
            self.browser.close()
        if hasattr(self, 'pw'):
            self.pw.stop()


# ========== USDA FALLBACK ==========
def generate_usda_fallback(food_terms):
    """Generate estimated prices for stores we can't scrape."""
    prices = []
    rng = random.Random(42)

    for store_id, store_info in STORE_TIERS.items():
        for food_id, food_info in food_terms.items():
            search = food_info.get('search')
            if not search or search not in USDA_PRICES:
                continue
            base = USDA_PRICES[search]
            variation = rng.uniform(-0.08, 0.08)
            price = base * store_info['factor'] * (1 + variation)
            price = round(price, 2)
            # Round to common price points
            cents = int((price % 1) * 100)
            if cents > 85: price = int(price) + 0.99
            elif cents > 60: price = int(price) + 0.79
            elif cents > 35: price = int(price) + 0.49
            elif cents > 15: price = int(price) + 0.29
            else: price = int(price) + 0.09
            price = max(0.09, price)

            prices.append({
                'food_id': food_id,
                'store_id': store_id,
                'store_name': store_info['name'],
                'store_brand': store_info['name'],
                'product_name': search.title(),
                'price': price,
                'unit': food_info.get('unit', ''),
                'source': 'usda_estimate',
                'scraped_at': datetime.now().strftime('%Y-%m-%d'),
            })
    return prices


# ========== MAIN ==========
def main():
    output_path = project_dir / 'data' / 'prices.json'
    all_prices = []
    stores = {}
    scraped_sources = []

    print("=== NC FoodSeq Price Scraper ===\n")

    # 1. Kroger API (Harris Teeter)
    print("[1/3] Kroger API (Harris Teeter)...")
    kroger = KrogerScraper()
    if kroger.authenticate():
        kroger.find_stores()
        kroger_prices = kroger.scrape_all(FOOD_TERMS)
        all_prices.extend(kroger_prices)
        scraped_sources.append(f"Kroger API: {len(kroger_prices)} prices from {len(kroger.stores)} Harris Teeter stores")
        # Add stores
        for store_id, info in kroger.stores.items():
            sid = f"harris-teeter-{store_id}"
            stores[sid] = {'name': info['name'], 'brand': 'Harris Teeter', 'tier': 'mid',
                           'address': info['address'], 'lat': info['lat'], 'lon': info['lon'],
                           'source': 'kroger_api'}
        print(f"  -> {len(kroger_prices)} prices collected\n")
    else:
        print("  -> Skipped (no credentials)\n")

    # 2. Playwright (Walmart, Food Lion, ALDI, Whole Foods, Publix)
    print("[2/3] Playwright (Walmart, Food Lion, ALDI, Whole Foods, Publix)...")
    pw_scraper = PlaywrightScraper()
    if pw_scraper.init_browser():
        try:
            pw_prices = pw_scraper.scrape_all(FOOD_TERMS)
            all_prices.extend(pw_prices)
            # Collect store info
            pw_brands = set()
            for config in PLAYWRIGHT_STORES.values():
                for loc in config['locations']:
                    stores[loc['id']] = {
                        'name': loc['name'], 'brand': config['brand'], 'tier': config['tier'],
                        'address': loc['address'], 'lat': loc['lat'], 'lon': loc['lon'],
                        'source': 'playwright'
                    }
                pw_brands.add(config['brand'])
            scraped_sources.append(f"Playwright: {len(pw_prices)} prices from {', '.join(sorted(pw_brands))}")
            print(f"  -> {len(pw_prices)} prices collected\n")
        except Exception as e:
            print(f"  -> Failed: {e}\n")
        finally:
            pw_scraper.close()
    else:
        print("  -> Skipped (browser not available)\n")

    # 3. USDA fallback for stores that weren't scraped at all
    print("[3/3] USDA estimates for remaining stores...")
    scraped_brands = set(p['store_brand'] for p in all_prices)
    fallback_stores = {k: v for k, v in STORE_TIERS.items()
                       if v['name'] not in scraped_brands}
    if fallback_stores:
        fallback_food_terms = {k: v for k, v in FOOD_TERMS.items() if v.get('search')}
        # Temporarily replace STORE_TIERS for fallback
        orig = dict(STORE_TIERS)
        STORE_TIERS.clear()
        STORE_TIERS.update(fallback_stores)
        fallback_prices = generate_usda_fallback(fallback_food_terms)
        STORE_TIERS.clear()
        STORE_TIERS.update(orig)

        all_prices.extend(fallback_prices)
        scraped_sources.append(f"USDA estimates: {len(fallback_prices)} prices for {len(fallback_stores)} stores")
        for sid, info in fallback_stores.items():
            stores[sid] = {'name': info['name'], 'brand': info['name'], 'tier': info['tier'],
                           'source': 'usda_estimate'}
        print(f"  -> {len(fallback_prices)} estimated prices\n")

    # Save
    output = {
        'scraped_at': datetime.now().isoformat(),
        'sources': scraped_sources,
        'stores': stores,
        'prices': all_prices,
    }

    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"=== Done! ===")
    print(f"Total: {len(all_prices)} prices across {len(stores)} stores")
    print(f"Foods: {len(set(p['food_id'] for p in all_prices))}")
    print(f"Sources: {', '.join(scraped_sources)}")
    print(f"Saved to: {output_path}")


if __name__ == '__main__':
    main()
