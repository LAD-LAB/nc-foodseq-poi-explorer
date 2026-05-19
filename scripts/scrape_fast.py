#!/usr/bin/env python3
"""Fast scraper: Kroger API + Whole Foods + USDA fallback. Skips blocked stores."""
import json, os, sys, time, base64, re, random
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv
import requests

load_dotenv(Path(__file__).parent.parent / '.env')

with open(Path(__file__).parent / 'food_search_terms.json') as f:
    FOOD_TERMS = {k: v for k, v in json.load(f).items() if v.get('search')}

print(f'Foods to scrape: {len(FOOD_TERMS)}', flush=True)
all_prices = []
all_stores = {}

# ===== KROGER API =====
print('[1/3] Kroger API (Harris Teeter)...', flush=True)
client_id = os.getenv('KROGER_CLIENT_ID')
client_secret = os.getenv('KROGER_CLIENT_SECRET')
auth = base64.b64encode(f'{client_id}:{client_secret}'.encode()).decode()
resp = requests.post('https://api.kroger.com/v1/connect/oauth2/token',
    headers={'Authorization': f'Basic {auth}', 'Content-Type': 'application/x-www-form-urlencoded'},
    data={'grant_type': 'client_credentials', 'scope': 'product.compact'})
token = resp.json()['access_token']
print('  Authenticated', flush=True)

loc_resp = requests.get('https://api.kroger.com/v1/locations',
    headers={'Authorization': f'Bearer {token}'},
    params={'filter.zipCode.near': '27701', 'filter.radiusInMiles': 10, 'filter.limit': 10})
stores_data = loc_resp.json().get('data', [])
print(f'  {len(stores_data)} stores', flush=True)

for store in stores_data:
    sid = f"harris-teeter-{store['locationId']}"
    sname = store['name']
    addr = store['address']['addressLine1']
    lat = store['geolocation']['latitude']
    lon = store['geolocation']['longitude']
    all_stores[sid] = {'name': sname, 'brand': 'Harris Teeter', 'tier': 'mid',
        'address': addr, 'lat': lat, 'lon': lon, 'source': 'kroger_api'}
    count = 0
    for food_id, food_info in FOOD_TERMS.items():
        try:
            r = requests.get('https://api.kroger.com/v1/products',
                headers={'Authorization': f'Bearer {token}'},
                params={'filter.term': food_info['search'], 'filter.locationId': store['locationId'], 'filter.limit': 1})
            if r.status_code == 200:
                for p in r.json().get('data', []):
                    items = p.get('items', [])
                    if items:
                        price = items[0].get('price', {}).get('regular')
                        promo = items[0].get('price', {}).get('promo')
                        if price:
                            all_prices.append({
                                'food_id': food_id, 'store_id': sid, 'store_name': sname,
                                'store_brand': 'Harris Teeter', 'store_address': addr,
                                'store_lat': lat, 'store_lon': lon,
                                'product_name': p.get('description', ''),
                                'price': promo if promo and promo > 0 else price,
                                'unit': food_info.get('unit', ''), 'source': 'kroger_api',
                                'scraped_at': datetime.now().strftime('%Y-%m-%d')})
                            count += 1
                            break
        except:
            pass
        time.sleep(0.12)
    print(f'  {sname}: {count} prices', flush=True)

print(f'  -> {len(all_prices)} HT prices total', flush=True)

# ===== WHOLE FOODS =====
print('[2/3] Whole Foods (Playwright)...', flush=True)
try:
    from playwright.sync_api import sync_playwright
    pw = sync_playwright().start()
    browser = pw.chromium.launch(headless=True)
    page = browser.new_page(user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
    wf_count = 0
    wf = {'id': 'whole-foods-1', 'name': 'Whole Foods Market', 'address': '621 Broad St', 'lat': 36.007, 'lon': -78.921}
    all_stores[wf['id']] = {'name': wf['name'], 'brand': 'Whole Foods Market', 'tier': 'premium',
        'address': wf['address'], 'lat': wf['lat'], 'lon': wf['lon'], 'source': 'playwright'}

    for food_id, food_info in FOOD_TERMS.items():
        try:
            url = f"https://www.amazon.com/s?k={food_info['search'].replace(' ', '+')}&i=wholefoods"
            page.goto(url, timeout=12000, wait_until='domcontentloaded')
            time.sleep(2)
            els = page.query_selector_all('.a-price .a-offscreen')
            for el in els[:1]:
                txt = el.inner_text().strip()
                matches = re.findall(r'(\d+\.\d{2})', txt)
                if matches:
                    price = float(matches[0])
                    if 0.01 < price < 500:
                        name_el = page.query_selector('h2 a span')
                        pname = name_el.inner_text().strip()[:80] if name_el else food_info['search']
                        all_prices.append({
                            'food_id': food_id, 'store_id': wf['id'], 'store_name': wf['name'],
                            'store_brand': 'Whole Foods Market', 'store_address': wf['address'],
                            'store_lat': wf['lat'], 'store_lon': wf['lon'],
                            'product_name': pname, 'price': price,
                            'unit': food_info.get('unit', ''), 'source': 'playwright_wholefoods',
                            'scraped_at': datetime.now().strftime('%Y-%m-%d')})
                        wf_count += 1
                        sys.stdout.write('.')
                        sys.stdout.flush()
                        break
        except:
            pass
        time.sleep(1)
    browser.close()
    pw.stop()
    print(f'\n  -> {wf_count} Whole Foods prices', flush=True)
except Exception as e:
    print(f'  Failed: {e}', flush=True)

# ===== USDA FALLBACK =====
print('[3/3] USDA fallback...', flush=True)
USDA = {
    'banana':0.65,'tomatoes':2.15,'chicken breast':3.99,'white rice':1.09,'romaine lettuce':2.49,
    'atlantic salmon fillet':9.99,'pork chops':4.29,'ground beef':5.49,'sesame seeds':0.35,'blueberries':3.99,
    'oats':1.49,'broccoli':2.29,'asparagus':3.49,'green tea':4.29,'chickpeas canned':1.29,'lentils dry':1.99,
    'wheat bread':3.49,'turkey breast':5.99,'peanuts':3.49,'tofu':2.49,'green peas frozen':1.79,
    'black beans canned':1.19,'garlic':0.79,'yellow onion':1.29,'apples':1.89,'jalapeno peppers':1.99,
    'cocoa powder':4.99,'flax seeds':5.49,'barley':2.29,'beets':2.99,'lamb chops':12.99,'bell peppers':1.29,
    'strawberries':3.49,'carrots':1.29,'kale':2.49,'potatoes':1.09,'lima beans':1.39,'okra':3.49,'kiwi':0.69,
    'pistachios':8.99,'cashews':7.99,'sweet potato':1.49,'turmeric':0.99,'pineapple':3.49,
    'catfish fillet':6.99,'tilapia fillet':5.49,'canned tuna':1.49,'anchovies':2.99,'shrimp':8.99,
    'crab meat':14.99,'rainbow trout':8.99,'cod fillet':7.99,'sardines canned':2.49,'herring':4.99,
    'mackerel':5.99,'barramundi fillet':10.99,'artichoke':2.49,'arugula':3.49,'fresh basil':2.49,
    'avocado':1.49,'hazelnuts':7.99,'persimmon':1.99,'mango':1.49,'pomegranate':2.99,'figs':5.99,
    'coconut':2.49,'peaches':2.49,'walnuts':6.99,'pecans':8.99,'fresh ginger':4.99,'grapes':2.49,
    'cucumber':0.79,'fresh spinach':3.49,'corn on the cob':0.79,'whole wheat flour':0.69,
    'adzuki beans':3.49,'bass fillet':9.99,'bluefish fillet':7.99,
}
FALLBACK = {
    'food-lion': ('Food Lion', 'budget', 0.90),
    'aldi': ('ALDI', 'budget', 0.82),
    'walmart': ('Walmart', 'budget', 0.85),
    'publix': ('Publix', 'mid', 1.08),
    'lowes-foods': ('Lowes Foods', 'mid', 1.02),
    'fresh-market': ('The Fresh Market', 'premium', 1.25),
    'weaver-street': ('Weaver Street Market', 'premium', 1.30),
    'compare-foods': ('Compare Foods', 'budget', 0.88),
}
scraped_brands = set(p['store_brand'] for p in all_prices)
rng = random.Random(42)
fb_count = 0
for sid, (name, tier, factor) in FALLBACK.items():
    if name in scraped_brands:
        continue
    all_stores[sid] = {'name': name, 'brand': name, 'tier': tier, 'source': 'usda_estimate'}
    for food_id, food_info in FOOD_TERMS.items():
        base = USDA.get(food_info['search'])
        if not base:
            continue
        price = round(base * factor * (1 + rng.uniform(-0.08, 0.08)), 2)
        cents = int((price % 1) * 100)
        if cents > 85: price = int(price) + 0.99
        elif cents > 60: price = int(price) + 0.79
        elif cents > 35: price = int(price) + 0.49
        elif cents > 15: price = int(price) + 0.29
        else: price = int(price) + 0.09
        all_prices.append({
            'food_id': food_id, 'store_id': sid, 'store_name': name,
            'store_brand': name, 'product_name': food_info['search'].title(),
            'price': max(0.09, price), 'unit': food_info.get('unit', ''),
            'source': 'usda_estimate', 'scraped_at': datetime.now().strftime('%Y-%m-%d')})
        fb_count += 1
print(f'  -> {fb_count} USDA fallback prices', flush=True)

# Save
ht_count = sum(1 for p in all_prices if p['source'] == 'kroger_api')
wf_total = sum(1 for p in all_prices if 'playwright' in p['source'])
output = {
    'scraped_at': datetime.now().isoformat(),
    'sources': [
        f'Kroger API: {ht_count} Harris Teeter prices',
        f'Playwright: {wf_total} Whole Foods prices',
        f'USDA estimates: {fb_count} prices',
    ],
    'stores': all_stores,
    'prices': all_prices,
}
with open('data/prices.json', 'w') as f:
    json.dump(output, f, indent=2)

print(f'\n=== Done! {len(all_prices)} prices, {len(set(p["food_id"] for p in all_prices))} foods, {len(all_stores)} stores ===', flush=True)
