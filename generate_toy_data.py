"""
Generate toy FoodSeq data for NC wastewater treatment plants visualization.

This script creates realistic synthetic data including:
- 39 wastewater treatment plant locations across NC
- ~198 plant species and ~70 animal species
- 12 months of abundance data
- Outputs to JSON format for web visualization
"""

import json
import random
import os
from datetime import datetime, timedelta

# Set random seed for reproducibility
random.seed(42)

# NC cities and approximate coordinates for WWTPs
NC_PLANTS = [
    {"name": "Charlotte", "lat": 35.2271, "lng": -80.8431, "county": "Mecklenburg"},
    {"name": "Raleigh", "lat": 35.7796, "lng": -78.6382, "county": "Wake"},
    {"name": "Durham", "lat": 35.9940, "lng": -78.8986, "county": "Durham"},
    {"name": "Greensboro", "lat": 36.0726, "lng": -79.7920, "county": "Guilford"},
    {"name": "Winston-Salem", "lat": 36.0999, "lng": -80.2442, "county": "Forsyth"},
    {"name": "Fayetteville", "lat": 35.0527, "lng": -78.8784, "county": "Cumberland"},
    {"name": "Cary", "lat": 35.7915, "lng": -78.7811, "county": "Wake"},
    {"name": "Wilmington", "lat": 34.2257, "lng": -77.9447, "county": "New Hanover"},
    {"name": "High Point", "lat": 35.9557, "lng": -80.0053, "county": "Guilford"},
    {"name": "Concord", "lat": 35.4087, "lng": -80.5795, "county": "Cabarrus"},
    {"name": "Asheville", "lat": 35.5951, "lng": -82.5515, "county": "Buncombe"},
    {"name": "Gastonia", "lat": 35.2621, "lng": -81.1873, "county": "Gaston"},
    {"name": "Jacksonville", "lat": 34.7540, "lng": -77.4302, "county": "Onslow"},
    {"name": "Chapel Hill", "lat": 35.9132, "lng": -79.0558, "county": "Orange"},
    {"name": "Rocky Mount", "lat": 35.9382, "lng": -77.7905, "county": "Nash"},
    {"name": "Burlington", "lat": 36.0957, "lng": -79.4378, "county": "Alamance"},
    {"name": "Huntersville", "lat": 35.4107, "lng": -80.8428, "county": "Mecklenburg"},
    {"name": "Wilson", "lat": 35.7213, "lng": -77.9155, "county": "Wilson"},
    {"name": "Kannapolis", "lat": 35.4874, "lng": -80.6217, "county": "Cabarrus"},
    {"name": "Apex", "lat": 35.7327, "lng": -78.8503, "county": "Wake"},
    {"name": "Hickory", "lat": 35.7344, "lng": -81.3412, "county": "Catawba"},
    {"name": "Goldsboro", "lat": 35.3849, "lng": -77.9928, "county": "Wayne"},
    {"name": "Mooresville", "lat": 35.5848, "lng": -80.8101, "county": "Iredell"},
    {"name": "Salisbury", "lat": 35.6707, "lng": -80.4742, "county": "Rowan"},
    {"name": "Monroe", "lat": 34.9854, "lng": -80.5495, "county": "Union"},
    {"name": "Thomasville", "lat": 35.8826, "lng": -80.0820, "county": "Davidson"},
    {"name": "Sanford", "lat": 35.4799, "lng": -79.1803, "county": "Lee"},
    {"name": "Statesville", "lat": 35.7826, "lng": -80.8873, "county": "Iredell"},
    {"name": "Asheboro", "lat": 35.7079, "lng": -79.8136, "county": "Randolph"},
    {"name": "Kinston", "lat": 35.2627, "lng": -77.5816, "county": "Lenoir"},
    {"name": "Lumberton", "lat": 34.6182, "lng": -79.0086, "county": "Robeson"},
    {"name": "Shelby", "lat": 35.2921, "lng": -81.5357, "county": "Cleveland"},
    {"name": "Havelock", "lat": 34.8790, "lng": -76.9013, "county": "Craven"},
    {"name": "Lexington", "lat": 35.8240, "lng": -80.2534, "county": "Davidson"},
    {"name": "Elizabeth City", "lat": 36.2946, "lng": -76.2510, "county": "Pasquotank"},
    {"name": "Boone", "lat": 36.2168, "lng": -81.6746, "county": "Watauga"},
    {"name": "Henderson", "lat": 36.3298, "lng": -78.3992, "county": "Vance"},
    {"name": "Morganton", "lat": 35.7454, "lng": -81.6848, "county": "Burke"},
    {"name": "New Bern", "lat": 35.1085, "lng": -77.0441, "county": "Craven"},
]

# Common plant species detected in food (scientific name: common name)
PLANT_SPECIES = {
    # Grains and cereals
    "Zea mays": "Corn",
    "Triticum aestivum": "Wheat",
    "Oryza sativa": "Rice",
    "Hordeum vulgare": "Barley",
    "Avena sativa": "Oats",
    "Secale cereale": "Rye",
    "Sorghum bicolor": "Sorghum",
    "Panicum miliaceum": "Millet",

    # Legumes
    "Glycine max": "Soybean",
    "Phaseolus vulgaris": "Common bean",
    "Pisum sativum": "Pea",
    "Lens culinaris": "Lentil",
    "Cicer arietinum": "Chickpea",
    "Arachis hypogaea": "Peanut",
    "Vicia faba": "Fava bean",
    "Vigna unguiculata": "Black-eyed pea",

    # Vegetables - Solanaceae
    "Solanum lycopersicum": "Tomato",
    "Solanum tuberosum": "Potato",
    "Capsicum annuum": "Bell pepper",
    "Solanum melongena": "Eggplant",

    # Vegetables - Brassicaceae
    "Brassica oleracea": "Cabbage/Broccoli",
    "Brassica rapa": "Turnip",
    "Raphanus sativus": "Radish",
    "Armoracia rusticana": "Horseradish",

    # Vegetables - Other
    "Lactuca sativa": "Lettuce",
    "Spinacia oleracea": "Spinach",
    "Daucus carota": "Carrot",
    "Beta vulgaris": "Beet",
    "Allium cepa": "Onion",
    "Allium sativum": "Garlic",
    "Cucumis sativus": "Cucumber",
    "Cucurbita pepo": "Zucchini/Squash",
    "Cucurbita maxima": "Pumpkin",
    "Asparagus officinalis": "Asparagus",
    "Apium graveolens": "Celery",

    # Fruits - Rosaceae
    "Malus domestica": "Apple",
    "Prunus persica": "Peach",
    "Prunus avium": "Cherry",
    "Fragaria × ananassa": "Strawberry",
    "Rubus idaeus": "Raspberry",
    "Rubus fruticosus": "Blackberry",
    "Pyrus communis": "Pear",
    "Prunus domestica": "Plum",

    # Fruits - Citrus
    "Citrus × sinensis": "Orange",
    "Citrus limon": "Lemon",
    "Citrus × paradisi": "Grapefruit",
    "Citrus reticulata": "Mandarin",
    "Citrus × latifolia": "Lime",

    # Fruits - Tropical
    "Musa × paradisiaca": "Banana",
    "Ananas comosus": "Pineapple",
    "Mangifera indica": "Mango",
    "Carica papaya": "Papaya",
    "Persea americana": "Avocado",
    "Cocos nucifera": "Coconut",
    "Passiflora edulis": "Passion fruit",

    # Fruits - Other
    "Vitis vinifera": "Grape",
    "Vaccinium corymbosum": "Blueberry",
    "Vaccinium macrocarpon": "Cranberry",
    "Actinidia deliciosa": "Kiwi",
    "Ficus carica": "Fig",
    "Punica granatum": "Pomegranate",
    "Citrullus lanatus": "Watermelon",
    "Cucumis melo": "Cantaloupe",

    # Nuts and seeds
    "Juglans regia": "Walnut",
    "Carya illinoinensis": "Pecan",
    "Prunus dulcis": "Almond",
    "Corylus avellana": "Hazelnut",
    "Pistacia vera": "Pistachio",
    "Anacardium occidentale": "Cashew",
    "Helianthus annuus": "Sunflower",
    "Sesamum indicum": "Sesame",
    "Linum usitatissimum": "Flax",
    "Papaver somniferum": "Poppy seed",
    "Cucurbita pepo (seeds)": "Pumpkin seeds",

    # Herbs and spices
    "Mentha × piperita": "Peppermint",
    "Ocimum basilicum": "Basil",
    "Petroselinum crispum": "Parsley",
    "Coriandrum sativum": "Cilantro",
    "Origanum vulgare": "Oregano",
    "Thymus vulgaris": "Thyme",
    "Rosmarinus officinalis": "Rosemary",
    "Salvia officinalis": "Sage",
    "Anethum graveolens": "Dill",
    "Curcuma longa": "Turmeric",
    "Zingiber officinale": "Ginger",
    "Piper nigrum": "Black pepper",
    "Capsicum frutescens": "Chili pepper",
    "Vanilla planifolia": "Vanilla",
    "Cinnamomum verum": "Cinnamon",

    # Other common plants
    "Theobroma cacao": "Cocoa",
    "Coffea arabica": "Coffee",
    "Camellia sinensis": "Tea",
    "Ipomoea batatas": "Sweet potato",
    "Manihot esculenta": "Cassava",
    "Dioscorea alata": "Yam",
    "Hordeum vulgare (malt)": "Barley malt",
    "Cannabis sativa": "Hemp seed",
    "Humulus lupulus": "Hops",

    # Leafy greens
    "Brassica rapa (greens)": "Bok choy",
    "Brassica juncea": "Mustard greens",
    "Beta vulgaris (greens)": "Swiss chard",
    "Amaranthus cruentus": "Amaranth",
    "Chenopodium quinoa": "Quinoa",
    "Eruca vesicaria": "Arugula",

    # Additional vegetables
    "Abelmoschus esculentus": "Okra",
    "Cynara cardunculus": "Artichoke",
    "Allium ampeloprasum": "Leek",
    "Bambusa vulgaris": "Bamboo shoots",
    "Brassica napus": "Rutabaga",

    # Additional fruits
    "Phoenix dactylifera": "Date",
    "Diospyros kaki": "Persimmon",
    "Morus alba": "Mulberry",
    "Prunus armeniaca": "Apricot",
    "Ribes rubrum": "Red currant",
    "Ribes nigrum": "Black currant",
    "Lycium barbarum": "Goji berry",
    "Sambucus nigra": "Elderberry",
    "Hippophae rhamnoides": "Sea buckthorn",

    # Melons
    "Cucumis melo (honeydew)": "Honeydew melon",
    "Benincasa hispida": "Winter melon",

    # Root vegetables
    "Pastinaca sativa": "Parsnip",
    "Arracacia xanthorrhiza": "Arracacha",
    "Brassica rapa (root)": "Turnip root",

    # Additional grains
    "Fagopyrum esculentum": "Buckwheat",
    "Eragrostis tef": "Teff",
    "Setaria italica": "Foxtail millet",
    "Eleusine coracana": "Finger millet",

    # Squashes
    "Cucurbita moschata": "Butternut squash",
    "Cucurbita ficifolia": "Fig-leaf gourd",
    "Lagenaria siceraria": "Bottle gourd",

    # Additional legumes
    "Vigna radiata": "Mung bean",
    "Vigna mungo": "Black gram",
    "Lablab purpureus": "Hyacinth bean",
    "Psophocarpus tetragonolobus": "Winged bean",
    "Cajanus cajan": "Pigeon pea",

    # Leafy vegetables
    "Ipomoea aquatica": "Water spinach",
    "Tetragonia tetragonioides": "New Zealand spinach",
    "Portulaca oleracea": "Purslane",
    "Nasturtium officinale": "Watercress",

    # Additional nuts
    "Castanea sativa": "Chestnut",
    "Bertholletia excelsa": "Brazil nut",
    "Macadamia integrifolia": "Macadamia",
    "Pinus pinea": "Pine nut",

    # Miscellaneous
    "Moringa oleifera": "Moringa",
    "Opuntia ficus-indica": "Prickly pear",
    "Tamarindus indica": "Tamarind",
    "Actinidia arguta": "Hardy kiwi",
    "Physalis peruviana": "Cape gooseberry",
    "Solanum quitoense": "Naranjilla",
    "Psidium guajava": "Guava",
    "Litchi chinensis": "Lychee",
    "Dimocarpus longan": "Longan",
    "Nephelium lappaceum": "Rambutan",
    "Durio zibethinus": "Durian",
    "Artocarpus heterophyllus": "Jackfruit",
    "Annona muricata": "Soursop",
    "Annona squamosa": "Sugar apple",
    "Syzygium aromaticum": "Clove",
    "Myristica fragrans": "Nutmeg",
    "Illicium verum": "Star anise",
    "Elettaria cardamomum": "Cardamom",
    "Crocus sativus": "Saffron",
}

# Common animal species detected in food (scientific name: common name)
ANIMAL_SPECIES = {
    # Livestock - Mammals
    "Bos taurus": "Cattle",
    "Sus scrofa domesticus": "Pig",
    "Ovis aries": "Sheep",
    "Capra aegagrus hircus": "Goat",
    "Bos bubalis": "Water buffalo",

    # Poultry
    "Gallus gallus domesticus": "Chicken",
    "Meleagris gallopavo": "Turkey",
    "Anas platyrhynchos domesticus": "Duck",
    "Anser anser domesticus": "Goose",
    "Coturnix japonica": "Quail",
    "Numida meleagris": "Guinea fowl",
    "Columba livia domestica": "Pigeon",

    # Fish - Freshwater
    "Oncorhynchus mykiss": "Rainbow trout",
    "Salmo salar": "Atlantic salmon",
    "Ictalurus punctatus": "Channel catfish",
    "Oreochromis niloticus": "Nile tilapia",
    "Cyprinus carpio": "Common carp",
    "Micropterus salmoides": "Largemouth bass",
    "Esox lucius": "Northern pike",
    "Perca fluviatilis": "European perch",

    # Fish - Marine
    "Thunnus albacares": "Yellowfin tuna",
    "Thunnus thynnus": "Bluefin tuna",
    "Gadus morhua": "Atlantic cod",
    "Scomber scombrus": "Atlantic mackerel",
    "Clupea harengus": "Atlantic herring",
    "Engraulis encrasicolus": "European anchovy",
    "Merluccius merluccius": "European hake",
    "Sebastes norvegicus": "Redfish",
    "Hippoglossus hippoglossus": "Atlantic halibut",
    "Pleuronectes platessa": "European plaice",
    "Solea solea": "Common sole",
    "Squalus acanthias": "Spiny dogfish",

    # Fish - Tropical/Other
    "Pangasianodon hypophthalmus": "Pangasius",
    "Lates calcarifer": "Barramundi",
    "Mugil cephalus": "Flathead mullet",

    # Shellfish - Crustaceans
    "Penaeus vannamei": "Whiteleg shrimp",
    "Pandalus borealis": "Northern prawn",
    "Homarus americanus": "American lobster",
    "Cancer pagurus": "Brown crab",
    "Callinectes sapidus": "Blue crab",
    "Paralithodes camtschaticus": "Red king crab",
    "Procambarus clarkii": "Red swamp crayfish",

    # Shellfish - Mollusks
    "Crassostrea gigas": "Pacific oyster",
    "Mytilus edulis": "Blue mussel",
    "Pecten maximus": "Great scallop",
    "Ruditapes philippinarum": "Manila clam",
    "Mercenaria mercenaria": "Hard clam",
    "Haliotis rufescens": "Red abalone",
    "Loligo vulgaris": "European squid",
    "Octopus vulgaris": "Common octopus",
    "Sepia officinalis": "Common cuttlefish",

    # Other aquatic animals
    "Rana catesbeiana": "American bullfrog",
    "Lithodes santolla": "Southern king crab",

    # Game animals
    "Cervus elaphus": "Red deer",
    "Odocoileus virginianus": "White-tailed deer",
    "Sus scrofa": "Wild boar",
    "Lepus europaeus": "European hare",
    "Oryctolagus cuniculus": "European rabbit",

    # Exotic meats
    "Struthio camelus": "Ostrich",
    "Dromaius novaehollandiae": "Emu",
    "Crocodylus niloticus": "Nile crocodile",
    "Bison bison": "American bison",
    "Lama glama": "Llama",
    "Vicugna pacos": "Alpaca",
    "Rangifer tarandus": "Reindeer",
    "Alces alces": "Moose",
}

def generate_abundance_value(species_rank, time_index, is_plant=True):
    """
    Generate realistic abundance values with seasonal and ranking patterns.

    Args:
        species_rank: Lower rank = more common (0 = most common)
        time_index: Month index (0-11)
        is_plant: Whether this is a plant species

    Returns:
        Abundance value (higher = more abundant)
    """
    # Base abundance follows log-normal distribution
    # Most common species have high baseline, rare species have low
    base_abundance = 10000 / (species_rank + 1)

    # Add seasonal variation (more produce in summer months for plants)
    if is_plant:
        seasonal_factor = 1.0 + 0.3 * (1 - abs(time_index - 6) / 6)
    else:
        # Less seasonal variation for animal products
        seasonal_factor = 1.0 + 0.1 * random.random()

    # Add random variation
    random_factor = random.uniform(0.7, 1.3)

    # Calculate final abundance
    abundance = base_abundance * seasonal_factor * random_factor

    # Add some noise - some species might not be detected in some months
    if random.random() < 0.1:  # 10% chance of very low detection
        abundance *= 0.1

    return max(1, int(abundance))

def generate_foodseq_data():
    """Generate complete FoodSeq dataset."""

    # Generate monthly dates for 2024
    dates = []
    start_date = datetime(2024, 1, 1)
    for i in range(12):
        month_date = start_date + timedelta(days=30 * i)
        dates.append(month_date.strftime("%Y-%m"))

    # Prepare plant species list (shuffle to add variety to rankings)
    plant_list = list(PLANT_SPECIES.keys())
    random.shuffle(plant_list)

    # Prepare animal species list
    animal_list = list(ANIMAL_SPECIES.keys())
    random.shuffle(animal_list)

    # Generate data for each plant
    plants_data = {}
    for i, plant_info in enumerate(NC_PLANTS):
        plant_id = f"plant_{i+1:03d}"

        # Create timeseries data
        timeseries = {}
        for time_idx, date in enumerate(dates):
            # Generate plant species abundances
            plant_abundances = {}
            for rank, species in enumerate(plant_list):
                abundance = generate_abundance_value(rank, time_idx, is_plant=True)
                plant_abundances[species] = abundance

            # Generate animal species abundances
            animal_abundances = {}
            for rank, species in enumerate(animal_list):
                abundance = generate_abundance_value(rank, time_idx, is_plant=False)
                animal_abundances[species] = abundance

            timeseries[date] = {
                "plants": plant_abundances,
                "animals": animal_abundances
            }

        plants_data[plant_id] = {
            "name": f"{plant_info['name']} WWTP",
            "lat": plant_info["lat"],
            "lng": plant_info["lng"],
            "county": plant_info["county"],
            "timeseries": timeseries
        }

    # Combine species metadata
    species_metadata = {**PLANT_SPECIES, **ANIMAL_SPECIES}

    # Create final data structure
    data = {
        "dates": dates,
        "plants": plants_data,
        "species_metadata": species_metadata
    }

    return data

def save_json(data, filename):
    """Save data to JSON file."""
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Saved: {filename}")

def main():
    """Generate all toy data files."""
    print("Generating toy FoodSeq data...")

    # Generate main dataset
    foodseq_data = generate_foodseq_data()
    save_json(foodseq_data, "data/foodseq_data.json")

    # Print summary statistics
    print(f"\nDataset summary:")
    print(f"- Treatment plants: {len(foodseq_data['plants'])}")
    print(f"- Plant species: {len(PLANT_SPECIES)}")
    print(f"- Animal species: {len(ANIMAL_SPECIES)}")
    print(f"- Time points: {len(foodseq_data['dates'])}")
    print(f"- Total data points: {len(foodseq_data['plants']) * len(foodseq_data['dates']) * (len(PLANT_SPECIES) + len(ANIMAL_SPECIES))}")

    print("\nDone! You can now open index.html to view the visualization.")

if __name__ == "__main__":
    main()
