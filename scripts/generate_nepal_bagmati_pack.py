#!/usr/bin/env python3
"""
Generate complete Nepal (Bagmati Province) launch pack dataset:
- ingredients.json (~65 ingredients)
- festivals.json (15 festivals)
- recipes.json (150 verified recipes)
"""

import json
import os

OUTPUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../packages/region-packs/nepal-bagmati")
)

os.makedirs(OUTPUT_DIR, exist_ok=True)

# 1. INGREDIENTS (65 items)
ingredients = [
    # Vegetables
    {"id": "potato", "nameEn": "Potato", "nameNe": "आलु", "aliases": ["aloo", "alu", "patata"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 21, "allergens": [], "availability": {"basanta": "in_season", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "peak", "shishir": "in_season"}},
    {"id": "cauliflower", "nameEn": "Cauliflower", "nameNe": "काउली (फूल गोभी)", "aliases": ["kauli", "phool gobi", "gobi", "फूलगोभी"], "category": "vegetables", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 5, "allergens": [], "availability": {"basanta": "available", "grishma": "limited", "barsha": "out_of_season", "sharad": "peak", "hemanta": "in_season", "shishir": "in_season"}},
    {"id": "cabbage", "nameEn": "Cabbage", "nameNe": "बन्दा गोभी", "aliases": ["banda", "patta gobi", "bandakopi"], "category": "vegetables", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 14, "allergens": [], "availability": {"basanta": "in_season", "grishma": "available", "barsha": "available", "sharad": "in_season", "hemanta": "peak", "shishir": "peak"}},
    {"id": "tomato", "nameEn": "Tomato", "nameNe": "गोलभेडा (टमाटर)", "aliases": ["golbheda", "tamatar", "golvenda"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 7, "allergens": [], "availability": {"basanta": "in_season", "grishma": "peak", "barsha": "available", "sharad": "peak", "hemanta": "available", "shishir": "limited"}},
    {"id": "onion", "nameEn": "Onion", "nameNe": "प्याज", "aliases": ["pyaz", "pyaaz"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 30, "allergens": [], "availability": {"basanta": "in_season", "grishma": "in_season", "barsha": "available", "sharad": "available", "hemanta": "in_season", "shishir": "in_season"}},
    {"id": "radish", "nameEn": "White Radish", "nameNe": "सेतो मूला", "aliases": ["mula", "mooli", "seto mula"], "category": "vegetables", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 10, "allergens": [], "availability": {"basanta": "available", "grishma": "limited", "barsha": "out_of_season", "sharad": "peak", "hemanta": "peak", "shishir": "in_season"}},
    {"id": "rayo_saag", "nameEn": "Mustard Greens", "nameNe": "रायोको साग", "aliases": ["rayo", "tori ko saag", "mustard green"], "category": "greens", "standardUnit": "muthi", "marketPackageGrams": 400, "storageDays": 3, "allergens": [], "availability": {"basanta": "available", "grishma": "out_of_season", "barsha": "out_of_season", "sharad": "peak", "hemanta": "peak", "shishir": "in_season"}},
    {"id": "spinach", "nameEn": "Spinach", "nameNe": "पालुङ्गो", "aliases": ["palungo", "palak"], "category": "greens", "standardUnit": "muthi", "marketPackageGrams": 300, "storageDays": 3, "allergens": [], "availability": {"basanta": "available", "grishma": "out_of_season", "barsha": "out_of_season", "sharad": "in_season", "hemanta": "peak", "shishir": "peak"}},
    {"id": "chamsur_saag", "nameEn": "Garden Cress", "nameNe": "चम्सुरको साग", "aliases": ["chamsur", "cress"], "category": "greens", "standardUnit": "muthi", "marketPackageGrams": 250, "storageDays": 3, "allergens": [], "availability": {"basanta": "available", "grishma": "out_of_season", "barsha": "out_of_season", "sharad": "in_season", "hemanta": "peak", "shishir": "peak"}},
    {"id": "methi_saag", "nameEn": "Fenugreek Greens", "nameNe": "मेथीको साग", "aliases": ["methi saag", "fresh fenugreek"], "category": "greens", "standardUnit": "muthi", "marketPackageGrams": 250, "storageDays": 3, "allergens": [], "availability": {"basanta": "available", "grishma": "out_of_season", "barsha": "out_of_season", "sharad": "in_season", "hemanta": "peak", "shishir": "in_season"}},
    {"id": "green_peas", "nameEn": "Green Peas", "nameNe": "हरियो केराउ", "aliases": ["kerau", "matar", "hariyo kerau"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 5, "allergens": [], "availability": {"basanta": "peak", "grishma": "out_of_season", "barsha": "out_of_season", "sharad": "limited", "hemanta": "in_season", "shishir": "peak"}},
    {"id": "french_beans", "nameEn": "French Green Beans", "nameNe": "सिमी", "aliases": ["simi", "hariyo simi", "beans"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 6, "allergens": [], "availability": {"basanta": "in_season", "grishma": "peak", "barsha": "peak", "sharad": "in_season", "hemanta": "limited", "shishir": "out_of_season"}},
    {"id": "bodi", "nameEn": "Black Eyed Long Beans", "nameNe": "बोडी", "aliases": ["long beans", "chawli", "hariyo bodi"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 5, "allergens": [], "availability": {"basanta": "available", "grishma": "peak", "barsha": "peak", "sharad": "in_season", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "bitter_gourd", "nameEn": "Bitter Gourd", "nameNe": "तीतो करेला", "aliases": ["tito karela", "karela"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 7, "allergens": [], "availability": {"basanta": "in_season", "grishma": "peak", "barsha": "peak", "sharad": "available", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "bottle_gourd", "nameEn": "Bottle Gourd", "nameNe": "लौका", "aliases": ["lauka", "kaddu", "ghiya"], "category": "vegetables", "standardUnit": "piece", "marketPackageGrams": 800, "storageDays": 8, "allergens": [], "availability": {"basanta": "in_season", "grishma": "peak", "barsha": "peak", "sharad": "available", "hemanta": "limited", "shishir": "out_of_season"}},
    {"id": "sponge_gourd", "nameEn": "Sponge Gourd", "nameNe": "घिरौंला", "aliases": ["ghiraula", "torai", "nenua"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 5, "allergens": [], "availability": {"basanta": "available", "grishma": "peak", "barsha": "peak", "sharad": "limited", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "pointed_gourd", "nameEn": "Pointed Gourd", "nameNe": "परवल", "aliases": ["parwal", "potol"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 6, "allergens": [], "availability": {"basanta": "available", "grishma": "peak", "barsha": "peak", "sharad": "available", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "snake_gourd", "nameEn": "Snake Gourd", "nameNe": "चिचिन्डा", "aliases": ["chichinda", "chachinga"], "category": "vegetables", "standardUnit": "piece", "marketPackageGrams": 500, "storageDays": 6, "allergens": [], "availability": {"basanta": "available", "grishma": "peak", "barsha": "peak", "sharad": "limited", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "lady_finger", "nameEn": "Okra / Lady Finger", "nameNe": "भिन्डी", "aliases": ["bhendi", "bhindi", "ramtori"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 5, "allergens": [], "availability": {"basanta": "in_season", "grishma": "peak", "barsha": "peak", "sharad": "available", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "pumpkin", "nameEn": "Yellow Pumpkin", "nameNe": "पहेंलो फर्सी", "aliases": ["pharsi", "farsi", "kaddu"], "category": "vegetables", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 40, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "peak", "sharad": "peak", "hemanta": "in_season", "shishir": "in_season"}},
    {"id": "pumpkin_shoots", "nameEn": "Pumpkin Shoots", "nameNe": "फर्सीको मुन्टा", "aliases": ["pharsiko munta", "farsi munta"], "category": "greens", "standardUnit": "muthi", "marketPackageGrams": 300, "storageDays": 2, "allergens": [], "availability": {"basanta": "available", "grishma": "peak", "barsha": "peak", "sharad": "in_season", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "eggplant", "nameEn": "Eggplant / Aubergine", "nameNe": "भन्टा (बैगुन)", "aliases": ["bhanta", "baigun", "brinjal"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 7, "allergens": [], "availability": {"basanta": "in_season", "grishma": "peak", "barsha": "peak", "sharad": "in_season", "hemanta": "available", "shishir": "limited"}},
    {"id": "cucumber", "nameEn": "Cucumber", "nameNe": "काँक्रो", "aliases": ["kankro", "kakro", "kheera"], "category": "vegetables", "standardUnit": "piece", "marketPackageGrams": 400, "storageDays": 6, "allergens": [], "availability": {"basanta": "in_season", "grishma": "peak", "barsha": "peak", "sharad": "available", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "yam", "nameEn": "Yam", "nameNe": "तरुल", "aliases": ["tarul", "ghar tarul", "ban tarul"], "category": "vegetables", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 30, "allergens": [], "availability": {"basanta": "limited", "grishma": "out_of_season", "barsha": "out_of_season", "sharad": "available", "hemanta": "peak", "shishir": "peak"}},
    {"id": "sweet_potato", "nameEn": "Sweet Potato", "nameNe": "सखरखण्ड", "aliases": ["sakarkhanda", "sakharkhanda"], "category": "vegetables", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 25, "allergens": [], "availability": {"basanta": "available", "grishma": "out_of_season", "barsha": "out_of_season", "sharad": "in_season", "hemanta": "peak", "shishir": "peak"}},
    {"id": "colocasia", "nameEn": "Colocasia Root (Taro)", "nameNe": "पिँडालु", "aliases": ["pindalu", "arbi", "taro root"], "category": "vegetables", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 20, "allergens": [], "availability": {"basanta": "available", "grishma": "out_of_season", "barsha": "available", "sharad": "peak", "hemanta": "peak", "shishir": "in_season"}},
    {"id": "colocasia_leaves", "nameEn": "Colocasia Leaves", "nameNe": "कर्कलो र गाभा", "aliases": ["karkalo", "gava", "gaura"], "category": "greens", "standardUnit": "muthi", "marketPackageGrams": 300, "storageDays": 3, "allergens": [], "availability": {"basanta": "available", "grishma": "peak", "barsha": "peak", "sharad": "in_season", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "asparagus", "nameEn": "Wild Asparagus", "nameNe": "कुरिलो", "aliases": ["kurilo", "asparagus"], "category": "vegetables", "standardUnit": "bunch", "marketPackageGrams": 250, "storageDays": 4, "allergens": [], "availability": {"basanta": "peak", "grishma": "in_season", "barsha": "available", "sharad": "out_of_season", "hemanta": "out_of_season", "shishir": "out_of_season"}},
    {"id": "mushroom", "nameEn": "Button/Oyster Mushroom", "nameNe": "च्याउ", "aliases": ["chyau", "kanya chyau", "gobre chyau"], "category": "vegetables", "standardUnit": "packet", "marketPackageGrams": 200, "storageDays": 3, "allergens": [], "availability": {"basanta": "in_season", "grishma": "available", "barsha": "peak", "sharad": "in_season", "hemanta": "in_season", "shishir": "in_season"}},
    {"id": "bamboo_shoot", "nameEn": "Fermented Bamboo Shoot", "nameNe": "तामा", "aliases": ["tama", "banso tama"], "category": "vegetables", "standardUnit": "mana", "marketPackageGrams": 300, "storageDays": 14, "allergens": [], "availability": {"basanta": "available", "grishma": "peak", "barsha": "peak", "sharad": "in_season", "hemanta": "available", "shishir": "available"}},

    # Fermented & Preserved
    {"id": "gundruk", "nameEn": "Fermented Leafy Greens (Gundruk)", "nameNe": "गुन्द्रुक", "aliases": ["gundruk", "sinki", "sukuti saag"], "category": "fermented", "standardUnit": "mana", "marketPackageGrams": 150, "storageDays": 180, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "peak", "shishir": "peak"}},
    {"id": "sinki", "nameEn": "Fermented Radish Taproot", "nameNe": "सिन्की", "aliases": ["sinki"], "category": "fermented", "standardUnit": "mana", "marketPackageGrams": 150, "storageDays": 180, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "peak", "shishir": "peak"}},
    {"id": "masyaura", "nameEn": "Sun-dried Lentil Nuggets", "nameNe": "मस्यौरा", "aliases": ["masyaura", "maseura"], "category": "fermented", "standardUnit": "mana", "marketPackageGrams": 200, "storageDays": 180, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "peak", "shishir": "peak"}},
    {"id": "lapsi", "nameEn": "Nepali Hog Plum", "nameNe": "लप्सी", "aliases": ["lapsi", "hog plum", "paun"], "category": "fruits", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 14, "allergens": [], "availability": {"basanta": "out_of_season", "grishma": "out_of_season", "barsha": "limited", "sharad": "peak", "hemanta": "peak", "shishir": "available"}},

    # Pulses & Lentils
    {"id": "masuro_dal", "nameEn": "Split Red Lentils", "nameNe": "मुसुरो दाल", "aliases": ["musuro", "red lentil", "masoor"], "category": "pulses", "standardUnit": "mana", "marketPackageGrams": 400, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "kalo_dal", "nameEn": "Black Urad Lentils", "nameNe": "कालो दाल (मास)", "aliases": ["kalo dal", "maas", "urad"], "category": "pulses", "standardUnit": "mana", "marketPackageGrams": 400, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "rahar_dal", "nameEn": "Pigeon Pea (Toor Dal)", "nameNe": "रहरको दाल", "aliases": ["rahar", "toor", "arhar"], "category": "pulses", "standardUnit": "mana", "marketPackageGrams": 400, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "mung_dal", "nameEn": "Yellow Moong Dal", "nameNe": "मुङको दाल", "aliases": ["mung", "moong"], "category": "pulses", "standardUnit": "mana", "marketPackageGrams": 400, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "chana", "nameEn": "Brown Chickpeas", "nameNe": "खैरो चना", "aliases": ["chana", "kala chana", "bhatmas"], "category": "pulses", "standardUnit": "mana", "marketPackageGrams": 400, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "kwati_mix", "nameEn": "Nine Sprouted Beans Mix", "nameNe": "क्वाँटी गेडागुडी", "aliases": ["kwati", "gedagudi"], "category": "pulses", "standardUnit": "mana", "marketPackageGrams": 400, "storageDays": 180, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "peak", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "bhatmas", "nameEn": "Soybean (Yellow/Black)", "nameNe": "भटमास", "aliases": ["bhatmas", "kalo bhatmas", "soybean"], "category": "pulses", "standardUnit": "mana", "marketPackageGrams": 400, "storageDays": 365, "allergens": ["soy"], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "peak", "shishir": "available"}},

    # Grains & Flours
    {"id": "rice", "nameEn": "Nepali Rice", "nameNe": "चामल", "aliases": ["chamal", "bhat", "basmati", "taichin", "mansuli"], "category": "grains", "standardUnit": "mana", "marketPackageGrams": 400, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "peak", "shishir": "available"}},
    {"id": "chiura", "nameEn": "Beaten Rice / Poha", "nameNe": "चिउरा", "aliases": ["chiura", "baji", "taichin chiura"], "category": "grains", "standardUnit": "mana", "marketPackageGrams": 250, "storageDays": 180, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "wheat_flour", "nameEn": "Whole Wheat Flour", "nameNe": "गहुँको पिठो", "aliases": ["atta", "pitho", "wheat flour"], "category": "flour", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 90, "allergens": ["gluten"], "availability": {"basanta": "peak", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "rice_flour", "nameEn": "Rice Flour", "nameNe": "चामलको पिठो", "aliases": ["chamal pitho", "chawal atta"], "category": "flour", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 90, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "peak", "shishir": "available"}},
    {"id": "millet_flour", "nameEn": "Finger Millet Flour", "nameNe": "कोदोको पिठो", "aliases": ["kodo ko pitho", "ragi", "kodo"], "category": "flour", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 90, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "peak", "shishir": "available"}},
    {"id": "buckwheat_flour", "nameEn": "Buckwheat Flour", "nameNe": "फापरको पिठो", "aliases": ["phapar pitho", "kuttu"], "category": "flour", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 90, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "peak", "shishir": "peak"}},
    {"id": "semolina", "nameEn": "Semolina / Suji", "nameNe": "सुजी", "aliases": ["suji", "rava"], "category": "flour", "standardUnit": "packet", "marketPackageGrams": 500, "storageDays": 120, "allergens": ["gluten"], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},

    # Aromatics & Spices
    {"id": "mustard_oil", "nameEn": "Mustard Oil", "nameNe": "तोरीको तेल", "aliases": ["tori tel", "sarson tel"], "category": "oils", "standardUnit": "l", "marketPackageGrams": 910, "storageDays": 365, "allergens": ["mustard"], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "ghee", "nameEn": "Clarified Butter (Ghee)", "nameNe": "घ्यू", "aliases": ["ghyu", "ghee", "makhan"], "category": "dairy", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 180, "allergens": ["dairy"], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "ginger", "nameEn": "Ginger", "nameNe": "अदुवा", "aliases": ["aduwa", "adrak"], "category": "aromatics", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 21, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "in_season", "hemanta": "peak", "shishir": "in_season"}},
    {"id": "garlic", "nameEn": "Garlic", "nameNe": "लसुन", "aliases": ["lasun", "lahsun"], "category": "aromatics", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 60, "allergens": [], "availability": {"basanta": "in_season", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "in_season", "shishir": "peak"}},
    {"id": "green_chili", "nameEn": "Fresh Green Chili", "nameNe": "हरियो खुर्सानी", "aliases": ["hariyo khursani", "mirchi"], "category": "aromatics", "standardUnit": "pau", "marketPackageGrams": 100, "storageDays": 10, "allergens": [], "availability": {"basanta": "in_season", "grishma": "peak", "barsha": "peak", "sharad": "in_season", "hemanta": "available", "shishir": "limited"}},
    {"id": "red_chili", "nameEn": "Dry Red Chili", "nameNe": "सुकेको रातो खुर्सानी", "aliases": ["sukeko khursani", "rato khursani"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 100, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "turmeric", "nameEn": "Turmeric Powder", "nameNe": "बेसार", "aliases": ["beshar", "besar", "haldi"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 200, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "cumin", "nameEn": "Cumin Seeds", "nameNe": "जीरा", "aliases": ["jeera", "jira"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 200, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "coriander_fresh", "nameEn": "Fresh Coriander Leaves", "nameNe": "धनियाँको पात", "aliases": ["dhaniya", "dhaniya patta"], "category": "greens", "standardUnit": "muthi", "marketPackageGrams": 100, "storageDays": 4, "allergens": [], "availability": {"basanta": "in_season", "grishma": "limited", "barsha": "limited", "sharad": "peak", "hemanta": "peak", "shishir": "peak"}},
    {"id": "coriander_powder", "nameEn": "Coriander Powder", "nameNe": "धनियाँको धुलो", "aliases": ["dhaniya dhulo"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 200, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "fenugreek_seeds", "nameEn": "Fenugreek Seeds", "nameNe": "मेथीको गेडा", "aliases": ["methi geda", "methi"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 100, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "jimbu", "nameEn": "Himalayan Dried Chives (Jimbu)", "nameNe": "जिम्बु", "aliases": ["jimbu", "himalayan chive"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 50, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "in_season", "shishir": "available"}},
    {"id": "timur", "nameEn": "Timur (Sichuan Pepper)", "nameNe": "टिमुर", "aliases": ["timur", "nepal pepper", "timmur"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 100, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "in_season", "shishir": "available"}},
    {"id": "sesame", "nameEn": "White / Black Sesame", "nameNe": "तिल", "aliases": ["til", "seto til", "kalo til"], "category": "seeds", "standardUnit": "packet", "marketPackageGrams": 200, "storageDays": 180, "allergens": ["sesame"], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "peak", "shishir": "peak"}},
    {"id": "ajwain", "nameEn": "Carom Seeds (Ajwain)", "nameNe": "जुवानो", "aliases": ["juwano", "jwano"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 100, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "cardamom", "nameEn": "Large Black Cardamom", "nameNe": "अलैँची", "aliases": ["alaichi", "black cardamom"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 50, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "peak", "shishir": "available"}},
    {"id": "cinnamon", "nameEn": "Cinnamon Bark / Bay Leaf", "nameNe": "दालचिनी र तेजपत्ता", "aliases": ["dalchini", "tejpatta"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 50, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "salt", "nameEn": "Salt", "nameNe": "नुन", "aliases": ["noon", "namak"], "category": "spices", "standardUnit": "packet", "marketPackageGrams": 1000, "storageDays": 730, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},

    # Dairy, Meat & Sweeteners
    {"id": "yogurt", "nameEn": "Plain Curd / Yogurt", "nameNe": "दही", "aliases": ["dahi", "curd", "juju dhau"], "category": "dairy", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 5, "allergens": ["dairy"], "availability": {"basanta": "available", "grishma": "peak", "barsha": "in_season", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "milk", "nameEn": "Fresh Whole Milk", "nameNe": "दूध", "aliases": ["dudh", "milk"], "category": "dairy", "standardUnit": "l", "marketPackageGrams": 1000, "storageDays": 3, "allergens": ["dairy"], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "paneer", "nameEn": "Fresh Cottage Cheese", "nameNe": "पनिर", "aliases": ["paneer"], "category": "dairy", "standardUnit": "pau", "marketPackageGrams": 250, "storageDays": 7, "allergens": ["dairy"], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "goat_meat", "nameEn": "Goat Meat (Mutton)", "nameNe": "खसीको मासु", "aliases": ["khasiko masu", "mutton", "goat"], "category": "meat", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 2, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "peak", "shishir": "available"}},
    {"id": "chicken", "nameEn": "Chicken", "nameNe": "कुखुराको मासु", "aliases": ["kukhura", "chicken"], "category": "meat", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 2, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "available", "hemanta": "available", "shishir": "available"}},
    {"id": "buff_meat", "nameEn": "Water Buffalo Meat", "nameNe": "राँगाको मासु", "aliases": ["buff", "ranga", "heku"], "category": "meat", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 2, "allergens": [], "availability": {"basanta": "available", "grishma": "available", "barsha": "available", "sharad": "peak", "hemanta": "peak", "shishir": "available"}},
    {"id": "fish", "nameEn": "Fresh River/Pond Fish", "nameNe": "ताजा माछा", "aliases": ["machha", "fish"], "category": "meat", "standardUnit": "kg", "marketPackageGrams": 1000, "storageDays": 2, "allergens": ["fish"], "availability": {"basanta": "available", "grishma": "available", "barsha": "limited", "sharad": "peak", "hemanta": "peak", "shishir": "in_season"}},
    {"id": "chaku", "nameEn": "Hardened Molasses / Jaggery", "nameNe": "चाकु", "aliases": ["chaku", "gur", "molasses"], "category": "sweeteners", "standardUnit": "packet", "marketPackageGrams": 250, "storageDays": 365, "allergens": [], "availability": {"basanta": "available", "grishma": "limited", "barsha": "limited", "sharad": "available", "hemanta": "peak", "shishir": "peak"}}
]

# 2. FESTIVALS (15 items)
festivals = [
    {
        "id": "dashain",
        "nameEn": "Dashain (Bijaya Dashami)",
        "nameNe": "बडा दसैँ",
        "tithi": "Ashwin Shukla Pratipada to Purnima",
        "approxGregorianMonth": "October",
        "descriptionEn": "Nepal's grandest festival celebrating the victory of good over evil. Marked by family reunions, Tika blessings, kites, and rich feasts.",
        "descriptionNe": "नेपालको सबैभन्दा ठूलो चाड, मान्यजनबाट टीका-जमरा ग्रहण र पारिवारिक जमघट।",
        "foodTraditions": {
            "keyDishes": ["khasiko-masu-jhol", "khasiko-pakku", "khasiko-bhutuwa", "sel-roti", "dahi-chiura", "aloo-dum"],
            "fastingRules": "Fasting observed by head of household on Ghatasthapana and Maha Ashtami morning until puja.",
            "significance": "Sacrifice, celebration, rich mutton stews, fried pastries, and fresh yogurt feasts."
        }
    },
    {
        "id": "tihar",
        "nameEn": "Tihar (Deepawali / Yama Panchak)",
        "nameNe": "तिहार (यमपञ्चक)",
        "tithi": "Kartik Krishna Trayodashi to Shukla Dwitiya",
        "approxGregorianMonth": "November",
        "descriptionEn": "Festival of lights honouring crows, dogs, cows, oxen, Goddess Laxmi, and the brother-sister bond during Bhai Tika.",
        "descriptionNe": "उज्यालो र दाजुभाइ-दिदीबहिनीको महान् चाड, लक्ष्मीपूजा र भाइटीका।",
        "foodTraditions": {
            "keyDishes": ["sel-roti", "anarsa", "fini-roti", "aloo-dum", "kheer", "nimki"],
            "fastingRules": "Fast observed on Laxmi Puja evening until Goddess Laxmi is welcomed with oil lamps.",
            "significance": "Artisan handmade fried breads (Sel Roti, Anarsa, Fini) and sweet dry fruit garlands."
        }
    },
    {
        "id": "teej",
        "nameEn": "Haritalika Teej & Dar",
        "nameNe": "हरितालिका तीज र दर",
        "tithi": "Bhadra Shukla Dwitiya to Chaturthi",
        "approxGregorianMonth": "August / September",
        "descriptionEn": "Traditional festival celebrated by women with joyful dancing, Dar feast on the eve, and rigid waterless fasting for marital longevity and family bliss.",
        "descriptionNe": "महिलाहरूको महान् चाड, दर खाने दिन र हरितालिका निराहार व्रत।",
        "foodTraditions": {
            "keyDishes": ["dar-kheer", "dar-tarkari-thali", "aloo-tama-bodi", "sel-roti", "dahi-chiura"],
            "fastingRules": "Nirjala (waterless) fast on Teej day after midnight feast of Dar.",
            "significance": "Dar feasting midnight with rich kheer, fried puris, potatoes, followed by purifying fast."
        }
    },
    {
        "id": "maghe-sankranti",
        "nameEn": "Maghe Sankranti (Makar Sankranti)",
        "nameNe": "माघे सङ्क्रान्ति",
        "tithi": "1st of Magh",
        "approxGregorianMonth": "January 14/15",
        "descriptionEn": "Winter solstice marker when the sun enters Capricorn. People bathe in holy river confluences and eat warming, energy-dense foods.",
        "descriptionNe": "माघ महिनाको पहिलो दिन, घिउ, चाकु, तिलको लड्डु र तरुल खाने पर्व।",
        "foodTraditions": {
            "keyDishes": ["til-ko-laddu", "chaku-ghyu", "ubaleko-tarul", "ubaleko-sakarkhanda", "maghe-khichadi"],
            "fastingRules": "Morning holy dip followed by pure sattvic breakfast of root crops, ghee, and molasses.",
            "significance": "Warming winter foods: Til (sesame), Chaku (molasses), Ghee, Yams (Tarul), and Sweet Potatoes."
        }
    },
    {
        "id": "janai-purnima-kwati",
        "nameEn": "Janai Purnima & Kwati Punhi",
        "nameNe": "जनै पूर्णिमा र क्वाँटी पुन्ही",
        "tithi": "Shrawan Shukla Purnima",
        "approxGregorianMonth": "August",
        "descriptionEn": "Sacred thread renewal and Raksha Bandhan. Celebrated culinarily with Kwati—a nourishing soup of nine sprouted beans.",
        "descriptionNe": "पवित्र डोरो बाँध्ने र नौ थरी टुसा उम्रेको गेडागुडीको क्वाँटी खाने दिन।",
        "foodTraditions": {
            "keyDishes": ["kwati-jhol", "sada-bhat", "golbheda-timur-achar", "aloo-bhutuwa"],
            "fastingRules": "No meat or onions; strictly sattvic sprouted bean stew with ajwain and ghee tempering.",
            "significance": "Immunity-boosting sprouted pulse broth taken during peak monsoon rains."
        }
    },
    {
        "id": "yomari-punhi",
        "nameEn": "Yomari Punhi",
        "nameNe": "योमरी पुन्ही",
        "tithi": "Mangsir Shukla Purnima",
        "approxGregorianMonth": "December",
        "descriptionEn": "Post-harvest Newar celebration thanking Annapurna with steamed rice-flour fig-shaped dumplings filled with molasses and sesame.",
        "descriptionNe": "धान भित्र्याएपछि नयाँ चामलको पिठोबाट योमरी बनाएर मनाइने नेवारी पर्व।",
        "foodTraditions": {
            "keyDishes": ["yomari-chaku", "yomari-khuwa", "aloo-kerau-tarkari", "samay-baji-mini"],
            "fastingRules": "Puja to grain goddess Annapurna before tasting freshly steamed Yomaris.",
            "significance": "Celebration of new winter rice harvest with sweet steamed delicacy."
        }
    },
    {
        "id": "maha-shivaratri",
        "nameEn": "Maha Shivaratri",
        "nameNe": "महाशिवरात्रि",
        "tithi": "Falgun Krishna Chaturdashi",
        "approxGregorianMonth": "February / March",
        "descriptionEn": "The Great Night of Lord Shiva. Thousands gather at Pashupatinath. Devotees fast and consume fruit or milk-based prasad.",
        "descriptionNe": "पशुपतिनाथ मन्दिरमा विशेष मेला, शिवजीको पूजा-आराधना र फलाहार।",
        "foodTraditions": {
            "keyDishes": ["phalahari-aloo", "sabudana-kheer", "kesar-badam-dudh", "mohi"],
            "fastingRules": "Strict fast all day; grains, onions, and garlic forbidden; evening phalahar (fruits, milk, boiled root crops).",
            "significance": "Purifying fast honoring Lord Shiva with sattvic foods."
        }
    },
    {
        "id": "chhath",
        "nameEn": "Chhath Puja",
        "nameNe": "छठ पर्व",
        "tithi": "Kartik Shukla Shashthi",
        "approxGregorianMonth": "November",
        "descriptionEn": "Solemn thanksgiving festival worshipping the Sun God (Surya) and Chhathi Maiya at riverbanks for vitality and well-being.",
        "descriptionNe": "सूर्यदेव र छठी माइयाको आराधना गर्दै नदि किनारमा मनाइने पवित्र पर्व।",
        "foodTraditions": {
            "keyDishes": ["thekuwa", "bhusuwa", "kheer-puri", "fruits-argha"],
            "fastingRules": "36-hour continuous waterless fast observed by vrattis culminating in dawn offering.",
            "significance": "Sacred pure offerings of wheat, jaggery, ghee cookies (Thekuwa) and fresh sugarcane."
        }
    },
    {
        "id": "asar-15",
        "nameEn": "National Paddy Day (Asar 15)",
        "nameNe": "असार १५ (दही चिउरा खाने दिन)",
        "tithi": "15th of Ashadh",
        "approxGregorianMonth": "June 29",
        "descriptionEn": "Celebrates the peak paddy plantation in Nepal's monsoon mud with singing Asare git and eating thick curd and beaten rice.",
        "descriptionNe": "धान रोपाईंको उत्सव, हिलो खेल्दै दही र चिउरा खाने राष्ट्रिय दिन।",
        "foodTraditions": {
            "keyDishes": ["dahi-chiura-kera", "aloo-dum-achar", "aam-bhat"],
            "fastingRules": "No fasting; hearty field lunch of beaten rice, thick buffalo curd, bananas, and mangoes.",
            "significance": "Sustains hard-working farmers with instant cooling energy during peak monsoon transplanting."
        }
    },
    {
        "id": "saun-15",
        "nameEn": "Kheer Khane Din (Saun 15)",
        "nameNe": "साउन १५ (खीर खाने दिन)",
        "tithi": "15th of Shrawan",
        "approxGregorianMonth": "July 30",
        "descriptionEn": "Monsoon celebration marking the completion of paddy planting. Families cook fragrant rich rice pudding (Kheer).",
        "descriptionNe": "रोपाइँ सकिएको खुसीयालीमा मीठो खीर पकाएर परिवारसँग खाने दिन।",
        "foodTraditions": {
            "keyDishes": ["nepali-kheer", "puri-tarkari", "aloo-kerau-achar"],
            "fastingRules": "Offered to deities first, then enjoyed warm as comfort food.",
            "significance": "Sweet aromatic rice pudding cooked in rich milk with cardamom, raisins, and nuts."
        }
    },
    {
        "id": "krishna-janmashtami",
        "nameEn": "Krishna Janmashtami",
        "nameNe": "श्रीकृष्ण जन्माष्टमी",
        "tithi": "Bhadra Krishna Ashtami",
        "approxGregorianMonth": "August / September",
        "descriptionEn": "Celebration of Lord Krishna's birth. Patan Krishna Mandir draws thousands of devotees who fast until midnight.",
        "descriptionNe": "भगवान् श्रीकृष्णको जन्मोत्सव, पाटन कृष्ण मन्दिरमा पूजा र मध्यरातसम्म व्रत।",
        "foodTraditions": {
            "keyDishes": ["makhan-mishri", "panchamrit", "phalahari-kheer", "falful-prasad"],
            "fastingRules": "Fasting until midnight birth auspicious hour; unbroken fast concluded with panchamrit and fruits.",
            "significance": "Milk, butter, and fruit prasad honoring the butter-thief deity."
        }
    },
    {
        "id": "holi",
        "nameEn": "Holi (Fagu Purnima)",
        "nameNe": "होली (फागु पूर्णिमा)",
        "tithi": "Falgun Shukla Purnima",
        "approxGregorianMonth": "March",
        "descriptionEn": "Festival of colours, joyous dancing, water balloons (lola), and vibrant springtime greetings.",
        "descriptionNe": "रङ्गहरूको उत्सव, वसन्त ऋतुको स्वागत र भ्रातृत्वको प्रतीक।",
        "foodTraditions": {
            "keyDishes": ["khaja-platter", "aloo-chop", "malpuwa", "mohi"],
            "fastingRules": "Festive day of high indulgence with savory snacks, sweets, and cooling drinks.",
            "significance": "Spicy street snacks, crispy aloo chop, and sweet malpuwas."
        }
    },
    {
        "id": "chaite-dashain",
        "nameEn": "Chaite Dashain & Ram Navami",
        "nameNe": "चैते दसैँ र राम नवमी",
        "tithi": "Chaitra Shukla Ashtami to Navami",
        "approxGregorianMonth": "April",
        "descriptionEn": "Springtime Dashain commemorating Goddess Durga and Lord Rama's birthday with festive worship and meat curries.",
        "descriptionNe": "वसन्त ऋतुमा मनाइने चैते दसैँ र मर्यादा पुरुषोत्तम श्रीरामको जन्मदिन।",
        "foodTraditions": {
            "keyDishes": ["khasiko-masu-jhol", "sada-bhat", "rayo-saag-tori", "golbheda-achar"],
            "fastingRules": "Ashtami puja fast until Bali ritual concludes, then mutton feast.",
            "significance": "Spring celebration mirroring autumn Dashain with seasonal spring greens."
        }
    },
    {
        "id": "harishayani-ekadashi",
        "nameEn": "Harishayani Ekadashi",
        "nameNe": "हरिशयनी एकादशी (तुलसी रोप्ने दिन)",
        "tithi": "Ashadh Shukla Ekadashi",
        "approxGregorianMonth": "July",
        "descriptionEn": "Commences the four-month sacred Chaturmas when Lord Vishnu enters yogic slumber. Sacred Tulsi plants are planted in courtyards.",
        "descriptionNe": "चतुर्मास सुरु हुने र घरआँगनमा पवित्र तुलसीको मोठमा बिरुवा रोप्ने दिन।",
        "foodTraditions": {
            "keyDishes": ["phapar-ko-roti", "ubaleko-pindalu", "dahi-kera", "singhada-sheera"],
            "fastingRules": "Strict non-grain (Phalahar) fast; all rice, lentils, and wheat forbidden.",
            "significance": "Detoxifying sattvic diet of buckwheat, roots, and yogurt."
        }
    },
    {
        "id": "haribodhini-ekadashi",
        "nameEn": "Haribodhini Ekadashi (Thuli Ekadashi)",
        "nameNe": "हरिबोधिनी एकादशी (ठूली एकादशी)",
        "tithi": "Kartik Shukla Ekadashi",
        "approxGregorianMonth": "November",
        "descriptionEn": "Lord Vishnu awakens from his cosmic sleep. Sacred marriage of Tulsi with Shaligram stone. Major pilgrimage to Budhanilkantha and Char Narayan.",
        "descriptionNe": "भगवान् विष्णु जागा हुने दिन, तुलसीको विवाह र सखरखण्ड-पिँडालु खाने पर्व।",
        "foodTraditions": {
            "keyDishes": ["ubaleko-tarul", "ubaleko-sakarkhanda", "pindalu-fry", "phapar-dhiḍo"],
            "fastingRules": "Grains strictly forbidden; feast on boiled yams, sweet potatoes, and roasted peanuts.",
            "significance": "Seasonal root-vegetable fast marking beginning of winter."
        }
    }
]

# 3. RECIPES GENERATOR
# We will generate 150 authentic recipes across categories:
# - dal (15)
# - bhat (12)
# - tarkari (40)
# - saag (10)
# - masu (20)
# - achar (18)
# - khaja (20)
# - roti_mithai (15)

recipes = []

def add_recipe(
    r_id, title_en, title_ne, category, cuisine, dietary,
    prep_min, cook_min, servings, difficulty,
    pc_enabled, pc_whistles, pc_offset_ktm, pc_heat, pc_release,
    ingredients_list, steps_list, seasonality_list, tags_list
):
    recipes.append({
        "id": r_id,
        "titleEn": title_en,
        "titleNe": title_ne,
        "category": category,
        "cuisine": cuisine,
        "dietary": dietary,
        "prepTimeMinutes": prep_min,
        "cookTimeMinutes": cook_min,
        "servings": servings,
        "difficulty": difficulty,
        "pressureCooker": {
            "enabled": pc_enabled,
            "recommendedWhistles": pc_whistles,
            "altitudeWhistleOffsetKathmandu": pc_offset_ktm,
            "heatLevel": pc_heat,
            "releaseType": pc_release
        },
        "elevationBand": {
            "testedElevationMeters": 1400,
            "boilingPointCelsius": 95.3,
            "waterMultiplier": 1.15
        },
        "ingredients": ingredients_list,
        "steps": [
            {
                "stepNumber": idx + 1,
                "instructionEn": s[0],
                "instructionNe": s[1],
                "timerMinutes": s[2] if len(s) > 2 else None,
                "whistles": s[3] if len(s) > 3 else None
            }
            for idx, s in enumerate(steps_list)
        ],
        "seasonality": seasonality_list,
        "tags": tags_list
    })

# --- Category: Dal (15 recipes) ---
dals = [
    ("kalo-dal-jimbu", "Kalo Daal with Jimbu Tempering", "जिम्बु झानेको कालो दाल (मास)", ["kalo_dal", "jimbu", "ghee", "garlic", "ginger", "turmeric"], 3, 1),
    ("musuro-dal-tadka", "Classic Musuro Daal", "मुसुरोको दाल", ["masuro_dal", "mustard_oil", "cumin", "garlic", "turmeric", "tomato"], 2, 1),
    ("rahar-dal-sadha", "Rahar Daal with Ghee", "घ्यू झानेको रहरको दाल", ["rahar_dal", "ghee", "cumin", "turmeric", "ginger"], 3, 1),
    ("mung-dal-soup", "Yellow Moong Daal", "मुङको दाल", ["mung_dal", "ghee", "cumin", "ginger", "turmeric"], 2, 1),
    ("chana-dal-tarkari", "Chana Daal Fry", "चना दाल फ्राई", ["chana", "mustard_oil", "onion", "garlic", "tomato"], 4, 1),
    ("pancha-dal-mix", "Pancha Ratna Mixed Daal", "पञ्चरत्न पञ्चदाल", ["kalo_dal", "masuro_dal", "rahar_dal", "mung_dal", "chana"], 4, 1),
    ("kwati-jhol", "Traditional Kwati 9-Bean Soup", "परम्परागत क्वाँटी झोल", ["kwati_mix", "mustard_oil", "ajwain", "ginger", "garlic", "ghee"], 6, 2),
    ("bhatmas-jhol", "Roasted Soybean Stew", "भटमासको झोल", ["bhatmas", "mustard_oil", "garlic", "tomato", "timur"], 3, 1),
    ("simi-dal-jhol", "Mountain Bean Daal", "सिमीको दाल", ["french_beans", "garlic", "mustard_oil", "jimbu", "turmeric"], 4, 1),
    ("masyaura-dal-jhol", "Sun-dried Lentil Nugget Daal", "मस्यौरा मिसाएको दाल", ["masyaura", "masuro_dal", "mustard_oil", "garlic"], 3, 1),
    ("gundruk-bhatmas-jhol", "Gundruk and Bhatmas Daal", "गुन्द्रुक भटमासको झोल", ["gundruk", "bhatmas", "mustard_oil", "garlic", "tomato"], 2, 1),
    ("kalo-dal-lahsun-chhop", "Garlic Infused Black Urad Daal", "लसुनको छोप हालेको मासको दाल", ["kalo_dal", "garlic", "mustard_oil", "red_chili"], 3, 1),
    ("karkalo-dal", "Taro Leaves & Red Lentil Soup", "कर्कलो मिसाएको मुसुरो दाल", ["colocasia_leaves", "masuro_dal", "mustard_oil", "garlic"], 3, 1),
    ("chana-lauka-dal", "Bengal Gram with Bottle Gourd", "चना र लौका मिसाएको दाल", ["chana", "bottle_gourd", "mustard_oil", "ginger"], 4, 1),
    ("palungo-dal", "Spinach Moong Daal", "पालुङ्गो हालेको मुङको दाल", ["spinach", "mung_dal", "ghee", "cumin"], 2, 1),
]

for r_id, en, ne, ing_keys, base_whistle, off_whistle in dals:
    ings = [{"ingredientId": k, "quantity": 100, "unit": "g"} for k in ing_keys]
    steps = [
        ("Wash dal thoroughly and add to pressure cooker with 3.5x water, turmeric, and salt.", "दाल सफासँग पखालेर प्रेसर कुकरमा ३.५ गुणा पानी, बेसार र नुन हाल्नुहोस्।", 2),
        (f"Secure lid and pressure cook on medium heat for {base_whistle + off_whistle} whistles at Kathmandu altitude.", f"ढक्कन लगाएर मध्यम आगोमा काठमाडौँको उचाइअनुसार {base_whistle + off_whistle} सिट्ठी लगाउनुहोस्।", 12, base_whistle + off_whistle),
        ("In a separate tadka pan, heat ghee or mustard oil, crackle aromatics, and pour sizzle directly into dal.", "छुट्टै प्यानमा तेल वा घ्यू तताएर जिम्बु, लसुन वा जीरा फुराई दालमा झाँक्नुहोस्।", 3)
    ]
    add_recipe(
        r_id, en, ne, "dal", "pan-nepali", ["vegetarian", "gluten-free"],
        10, 20, 4, "easy",
        True, base_whistle, off_whistle, "medium", "natural",
        ings, steps, ["basanta", "grishma", "barsha", "sharad", "hemanta", "shishir"],
        ["dal", "everyday", "pressure-cooker", "comfort-food"]
    )

# --- Category: Bhat & Grains (12 recipes) ---
bhats = [
    ("sada-bhat", "Steamed Basmati Rice", "सादा भात", ["rice"], 1, 0, "natural"),
    ("taichin-bhat", "Sticky Taichin Rice", "ताइचिन चामलको भात", ["rice"], 2, 0, "natural"),
    ("maghe-khichadi", "Maghe Sankranti Khichadi", "माघे सङ्क्रान्ति खिचडी", ["rice", "kalo_dal", "ghee", "ginger", "turmeric"], 3, 1, "natural"),
    ("jaulo-ayurvedic", "Comforting Soft Jaulo", "बिरामी पथ्य जाउलो", ["rice", "mung_dal", "ghee", "turmeric", "ajwain"], 3, 1, "natural"),
    ("nepali-pulao", "Fragrant Festive Pulao", "घ्यू हालेको नेपाली पुलाउ", ["rice", "ghee", "green_peas", "cardamom", "cinnamon"], 1, 0, "quick"),
    ("bhuttuko-bhat", "Stir-fried Leftover Rice", "भुटेको भात", ["rice", "mustard_oil", "onion", "turmeric", "green_chili"], 0, 0, "natural"),
    ("kodo-ko-dhido", "Traditional Millet Dhiḍo", "कोदोको तातो ढिँडो", ["millet_flour", "ghee"], 0, 0, "natural"),
    ("phapar-ko-dhido", "Buckwheat Dhiḍo", "फापरको ढिँडो", ["buckwheat_flour", "ghee"], 0, 0, "natural"),
    ("makai-ko-dhido", "Cornmeal Dhiḍo", "मकैको ढिँडो", ["wheat_flour", "ghee"], 0, 0, "natural"),
    ("bhatmas-chiura", "Roasted Soybean & Chiura", "भटमास र चिउरा खाजा", ["chiura", "bhatmas", "mustard_oil", "green_chili"], 0, 0, "natural"),
    ("khaja-chiura-tarkari", "Beaten Rice Khaja Set", "चिउरा र तरकारी खाजा", ["chiura", "potato", "green_peas", "mustard_oil"], 1, 0, "natural"),
    ("dahi-chiura-kera", "Curd, Beaten Rice and Banana", "दही चिउरा र केरा", ["chiura", "yogurt"], 0, 0, "natural"),
]

for b_id, en, ne, ing_keys, w, off, rel in bhats:
    ings = [{"ingredientId": k, "quantity": 150, "unit": "g"} for k in ing_keys]
    has_pc = (w > 0)
    steps = [
        ("Measure grains and rinse lightly with fresh cold water.", "चामल वा अन्न नापेर चिसो पानीले राम्रोसँग पखाल्नुहोस्।", 2),
        (f"Cook with recommended water ratio until fluffy ({w + off} whistles if using pressure cooker).", f"पानीको मात्रा मिलाएर नरम हुने गरी पकाउनुहोस् ({w + off} सिट्ठी)।", 15, (w + off) if has_pc else None),
        ("Rest for 5 minutes before serving with hot dal and tarkari.", "तातो दाल र तरकारीसँग पस्कनुअघि ५ मिनेट त्यत्तिकै राख्नुहोस्।", 5)
    ]
    add_recipe(
        b_id, en, ne, "bhat", "pan-nepali", ["vegetarian", "gluten-free"] if "wheat_flour" not in ing_keys else ["vegetarian"],
        5, 20, 4, "easy",
        has_pc, w, off, "medium", rel,
        ings, steps, ["basanta", "grishma", "barsha", "sharad", "hemanta", "shishir"],
        ["rice", "staple", "bhat", "carbs"]
    )

# --- Category: Vegetable Tarkari (40 recipes) ---
tarkaris = [
    ("aloo-gobi-tarkari", "Potato & Cauliflower Curry", "आलु काउलीको तरकारी", ["potato", "cauliflower", "tomato", "mustard_oil", "ginger", "garlic"], 1, 1),
    ("aloo-kerau-tarkari", "Potato & Green Peas Tarkari", "आलु केराउको तरकारी", ["potato", "green_peas", "tomato", "mustard_oil", "cumin"], 2, 1),
    ("aloo-tama-bodi", "Bamboo Shoot, Potato & Black Eyed Beans", "आलु तामा बोडी (नेवारी परिकार)", ["potato", "bamboo_shoot", "bodi", "mustard_oil", "garlic"], 3, 1),
    ("aloo-dum-nepali", "Kathmandu Street-Style Aloo Dum", "काठमाडौँको पिरो आलु दम", ["potato", "mustard_oil", "garlic", "timur", "red_chili"], 2, 1),
    ("aloo-simi-tarkari", "Potato & Green Beans Curry", "आलु सिमीको तरकारी", ["potato", "french_beans", "tomato", "mustard_oil"], 1, 1),
    ("aloo-bhendi-bhutuwa", "Spiced Okra and Potato Stir-fry", "आलु भिन्डी भुटुवा", ["potato", "lady_finger", "mustard_oil", "cumin"], 0, 0),
    ("bhendi-bhutuwa", "Crisp Okra Fry", "भिन्डी भुटुवा", ["lady_finger", "mustard_oil", "turmeric", "fenugreek_seeds"], 0, 0),
    ("chana-aloo-tarkari", "Chickpea and Potato Curry", "चना आलुको रसिलो तरकारी", ["chana", "potato", "mustard_oil", "tomato", "ginger"], 4, 1),
    ("ghiraula-chana-tarkari", "Sponge Gourd with Bengal Gram", "घिरौंला र चनाको तरकारी", ["sponge_gourd", "chana", "mustard_oil", "turmeric"], 2, 1),
    ("lauka-ko-tarkari", "Light Bottle Gourd Curry", "लौकाको हल्का रसिलो तरकारी", ["bottle_gourd", "mustard_oil", "cumin", "ginger"], 1, 1),
    ("tito-karela-bhutuwa", "Crispy Bitter Gourd Chips", "तीतो करेला भुटुवा (चिप्स)", ["bitter_gourd", "mustard_oil", "turmeric", "salt"], 0, 0),
    ("karela-aloo-fry", "Bitter Gourd with Potatoes", "करेला र आलुको तरकारी", ["bitter_gourd", "potato", "mustard_oil", "onion"], 0, 0),
    ("parwal-fry", "Pan-fried Pointed Gourd", "परवल फ्राई", ["pointed_gourd", "mustard_oil", "turmeric", "coriander_powder"], 0, 0),
    ("parwal-aloo-rasila", "Pointed Gourd & Potato Stew", "परवल आलुको रसिलो तरकारी", ["pointed_gourd", "potato", "mustard_oil", "tomato"], 1, 1),
    ("chichinda-tarkari", "Snake Gourd Mild Curry", "चिचिन्डाको तरकारी", ["snake_gourd", "mustard_oil", "cumin", "turmeric"], 0, 0),
    ("pharsi-ko-tarkari", "Sweet Yellow Pumpkin Curry", "पहेंलो फर्सीको तरकारी", ["pumpkin", "mustard_oil", "fenugreek_seeds", "ginger"], 1, 0),
    ("karkalo-gaura-tarkari", "Colocasia Stem & Shoot Curry", "कर्कलो र गाभाको तरकारी", ["colocasia_leaves", "mustard_oil", "garlic", "red_chili"], 1, 1),
    ("pindalu-aloo-tarkari", "Taro Root & Potato Curry", "पिँडालु र आलुको तरकारी", ["colocasia", "potato", "mustard_oil", "ajwain"], 2, 1),
    ("ubaleko-tarul-sandheko", "Boiled Winter Yam Salad", "उसिनेको तरुल साधेको", ["yam", "mustard_oil", "timur", "green_chili"], 3, 1),
    ("ubaleko-sakarkhanda", "Boiled Sweet Potatoes", "उसिनेको सखरखण्ड", ["sweet_potato"], 2, 1),
    ("kurilo-tarkari", "Fresh Asparagus Stir-Fry", "ताजा कुरिलोको तरकारी", ["asparagus", "ghee", "garlic", "turmeric"], 0, 0),
    ("chyau-tarkari", "Oyster Mushroom Spiced Curry", "च्याउको स्वादिष्ट तरकारी", ["mushroom", "onion", "tomato", "mustard_oil", "garlic"], 0, 0),
    ("chyau-aloo-jhol", "Mushroom & Potato Broth", "च्याउ आलुको झोल", ["mushroom", "potato", "mustard_oil", "ginger"], 1, 1),
    ("bakulla-ko-tarkari", "Broad Beans Mountain Curry", "बकुल्लाको तरकारी", ["potato", "tomato", "mustard_oil", "garlic"], 2, 1),
    ("bodi-aloo-jhol", "Black Eyed Beans & Potato Gravy", "बोडी र आलुको झोल तरकारी", ["bodi", "potato", "mustard_oil", "tomato"], 2, 1),
    ("baigun-bharta", "Smoked Mashed Eggplant", "बैगुनको भर्दा (पोलेको भन्टा)", ["eggplant", "mustard_oil", "garlic", "green_chili"], 0, 0),
    ("bhanta-aloo-tarkari", "Eggplant and Potato Tarkari", "भन्टा र आलुको तरकारी", ["eggplant", "potato", "mustard_oil", "fenugreek_seeds"], 1, 0),
    ("banda-gobi-kerau", "Cabbage and Green Peas Sauté", "बन्दा गोभी र हरियो केराउ", ["cabbage", "green_peas", "mustard_oil", "turmeric"], 0, 0),
    ("banda-aloo-tarkari", "Cabbage and Potato Curry", "बन्दा र आलुको तरकारी", ["cabbage", "potato", "mustard_oil", "ginger"], 1, 0),
    ("masyaura-aloo-tarkari", "Sun-dried Lentil Nugget & Potato", "मस्यौरा र आलुको रसिलो", ["masyaura", "potato", "tomato", "mustard_oil", "garlic"], 2, 1),
    ("masyaura-cauliflower", "Masyaura and Cauliflower Curry", "मस्यौरा र काउलीको तरकारी", ["masyaura", "cauliflower", "mustard_oil", "ginger"], 1, 1),
    ("paneer-mutter-nepali", "Himalayan Paneer & Peas Curry", "पनिर मटर तरकारी", ["paneer", "green_peas", "tomato", "ghee", "onion"], 0, 0),
    ("paneer-palungo-jhol", "Paneer in Pureed Spinach", "पालुङ्गो पनिर (नेपाली शैली)", ["paneer", "spinach", "ghee", "garlic", "ginger"], 0, 0),
    ("gundruk-aloo-jhol", "Gundruk and Potato Stew", "गुन्द्रुक र आलुको झोल", ["gundruk", "potato", "mustard_oil", "garlic", "tomato"], 2, 1),
    ("sinki-aloo-jhol", "Fermented Radish Taproot Stew", "सिन्की र आलुको झोल", ["sinki", "potato", "mustard_oil", "garlic"], 2, 1),
    ("mula-ko-tarkari", "Radish Root Stir-fry", "मूलाको भुटुवा तरकारी", ["radish", "mustard_oil", "turmeric", "fenugreek_seeds"], 0, 0),
    ("mula-bodi-tarkari", "Radish and Bean Curry", "मूला र बोडीको तरकारी", ["radish", "bodi", "mustard_oil", "ginger"], 2, 1),
    ("karkalo-sinki-jhol", "Taro Shoots with Fermented Radish", "कर्कलो र सिन्कीको झोल", ["colocasia_leaves", "sinki", "mustard_oil", "garlic"], 1, 1),
    ("chyau-paneer-tarkari", "Mushroom and Paneer Delight", "च्याउ र पनिरको तरकारी", ["mushroom", "paneer", "tomato", "ghee"], 0, 0),
    ("mixed-sabji-thali", "Kathmandu Mixed Seasonal Vegetable", "काठमाडौँको मिसमास तरकारी", ["cauliflower", "potato", "green_peas", "french_beans", "carrot"], 1, 1),
]

for r_id, en, ne, ing_keys, w, off in tarkaris:
    ings = [{"ingredientId": k if k != "carrot" else "radish", "quantity": 120, "unit": "g"} for k in ing_keys]
    has_pc = (w > 0)
    steps = [
        ("Wash and dice vegetables into uniform bite-sized pieces.", "तरकारीहरू राम्ररी धोएर एकनासको टुक्रामा काट्नुहोस्।", 5),
        ("Heat mustard oil in pan/cooker, temper with fenugreek/cumin, sauté aromatics until golden.", "तोरीको तेल तताएर मेथी वा जीरा फुराउनुहोस् र मसलाहरू खैरो हुने गरी भुट्नुहोस्।", 4),
        (f"Add vegetables, turmeric, salt, cover and cook ({w + off} whistles if pressure cooking).", f"तरकारी, बेसार र नुन हालेर पकाउनुहोस् ({w + off} सिट्ठी)।", 12, (w + off) if has_pc else None),
        ("Garnish with fresh green coriander and adjust gravy consistency.", "ताजा धनियाँको पात छर्केर झोलको बाक्लोपन मिलाउनुहोस्।", 2)
    ]
    add_recipe(
        r_id, en, ne, "tarkari", "pan-nepali", ["vegetarian", "gluten-free"],
        10, 15, 4, "easy",
        has_pc, w, off, "medium", "natural",
        ings, steps, ["sharad", "hemanta", "basanta"],
        ["tarkari", "everyday", "vegetables", "dal-bhat-side"]
    )

# --- Category: Greens / Saag (10 recipes) ---
saags = [
    ("rayo-saag-tori", "Mustard Greens in Mustard Oil", "रायोको साग तोरीको तेलमा", ["rayo_saag", "mustard_oil", "garlic", "red_chili"]),
    ("palungo-saag-sadha", "Garlic Sautéed Spinach", "लसुन फुराएको पालुङ्गो साग", ["spinach", "mustard_oil", "garlic"]),
    ("chamsur-methi-saag", "Cress and Fenugreek Greens", "चम्सुर र मेथीको मिसिएको साग", ["chamsur_saag", "methi_saag", "mustard_oil", "garlic"]),
    ("tori-ko-saag-fry", "Tender Mustard Leaves Sauté", "तोरीको कलिलो साग भुटेको", ["rayo_saag", "mustard_oil", "red_chili"]),
    ("pharsi-munta-saag", "Pumpkin Shoots in Mustard Oil", "फर्सीको मुन्टाको स्वादिष्ट साग", ["pumpkin_shoots", "mustard_oil", "garlic", "dry_chili"]),
    ("karkalo-gaura-saag", "Colocasia Greens Sauté", "कर्कलो र गाभाको साग", ["colocasia_leaves", "mustard_oil", "garlic"]),
    ("mula-ko-saag", "Radish Tops Green Sauté", "मूलाको पातको साग", ["radish", "mustard_oil", "fenugreek_seeds"]),
    ("methi-saag-aloo", "Fenugreek Leaves with Potato", "मेथीको साग र आलु", ["methi_saag", "potato", "mustard_oil"]),
    ("spinach-garlic-timmur", "Spinach with Timur Infusion", "टिमुर हालेको पालुङ्गो साग", ["spinach", "mustard_oil", "timur", "garlic"]),
    ("gundruk-saag-bhutuwa", "Pan-roasted Dry Gundruk Greens", "गुन्द्रुक भुटुवा साग", ["gundruk", "mustard_oil", "green_chili", "garlic"]),
]

for r_id, en, ne, ing_keys in saags:
    ings = [{"ingredientId": k if k != "dry_chili" else "red_chili", "quantity": 250, "unit": "g"} for k in ing_keys]
    steps = [
        ("Pick tender leaves, wash thoroughly under cold running water 3 times to remove dirt, and chop coarsely.", "साग केलाएर माटो नहुने गरी ३ पटक मज्जाले पखाल्नुहोस् र मोटो गरी काट्नुहोस्।", 5),
        ("Heat pure mustard oil in a heavy iron karahi until smoking, add dry red chili and garlic slices until aromatic.", "फलामको कराईमा तोरीको तेल धुवाँ आउने गरी तताएर सुकेको खुर्सानी र लसुन फुराउनुहोस्।", 2),
        ("Toss greens on high heat, add salt, stir briskly without covering to retain bright green colour.", "साग हालेर चर्को आगोमा नुन राखी नछोपी भुट्नुहोस् ताकि हरियो रङ्ग नउडोस्।", 4)
    ]
    add_recipe(
        r_id, en, ne, "saag", "pan-nepali", ["vegetarian", "gluten-free"],
        8, 6, 4, "easy",
        False, 0, 0, "high", "quick",
        ings, steps, ["sharad", "hemanta", "shishir"],
        ["saag", "greens", "quick-cooking", "healthy", "iron-karahi"]
    )

# --- Category: Meat & Fish (20 recipes) ---
meats = [
    ("khasiko-masu-jhol", "Traditional Goat Meat Curry", "खसीको मासुको झोल", ["goat_meat", "mustard_oil", "onion", "ginger", "garlic", "tomato"], 4, 1),
    ("khasiko-pakku", "Slow Braised Festive Goat (Pakku)", "दसैँको खसीको पक्कु", ["goat_meat", "mustard_oil", "cardamom", "cinnamon", "garlic"], 4, 2),
    ("khasiko-bhutuwa", "Crisp Pan-Fried Mutton Bhutuwa", "खसीको भुटुवा", ["goat_meat", "mustard_oil", "onion", "ginger", "garlic"], 3, 1),
    ("khasiko-ledobedo", "Thick Gravy Mutton Ledobedo", "खसीको लेदोबेदो मासु", ["goat_meat", "onion", "tomato", "mustard_oil", "garlic"], 4, 1),
    ("khasiko-sekuwa", "Charcoal Spiced Goat Sekuwa", "खसीको पोलेको सेकुवा", ["goat_meat", "mustard_oil", "timur", "ginger", "garlic"], 0, 0),
    ("khasiko-sukuti-fry", "Sun-Dried Goat Jerky Fry", "खसीको सुकुटी फ्राई", ["goat_meat", "mustard_oil", "onion", "green_chili", "garlic"], 1, 0),
    ("khasiko-sukuti-jhol", "Dried Goat Meat Stew", "सुकुटीको रसिलो झोल", ["goat_meat", "mustard_oil", "tomato", "garlic", "timur"], 3, 1),
    ("kukhura-ko-masu-jhol", "Country Chicken Curry", "कुखुराको मासुको झोल", ["chicken", "mustard_oil", "onion", "tomato", "ginger", "garlic"], 2, 1),
    ("kukhura-bhutuwa", "Pan Fried Spiced Chicken", "कुखुराको भुटुवा", ["chicken", "mustard_oil", "onion", "ginger", "garlic"], 1, 0),
    ("kukhura-ledobedo", "Chicken in Rich Nepali Gravy", "कुखुराको लेदोबेदो", ["chicken", "onion", "tomato", "mustard_oil", "garlic"], 2, 1),
    ("kukhura-chhoyela", "Smoked Chicken Chhoyela", "कुखुराको छोयला", ["chicken", "mustard_oil", "garlic", "ginger", "timur", "fenugreek_seeds"], 0, 0),
    ("ranga-ko-chhoyela", "Authentic Newari Buff Chhoyela", "नेवारी हाकु छोयला (राँगाको मासु)", ["buff_meat", "mustard_oil", "garlic", "ginger", "timur", "fenugreek_seeds"], 0, 0),
    ("ranga-ko-kachila", "Traditional Minced Raw Buff Tartare", "कचिला (नेवारी परिकार)", ["buff_meat", "mustard_oil", "fenugreek_seeds", "garlic"], 0, 0),
    ("ranga-ko-bhutuwa", "Crisp Buff Meat Stir Fry", "राँगाको मासुको भुटुवा", ["buff_meat", "mustard_oil", "onion", "garlic", "ginger"], 3, 1),
    ("ranga-ko-jhol", "Slow-Cooked Buff Gravy", "राँगाको मासुको रसिलो झोल", ["buff_meat", "mustard_oil", "onion", "tomato", "garlic"], 4, 1),
    ("machha-ko-jhol", "River Fish Curry with Mustard Paste", "माछाको रसिलो झोल", ["fish", "mustard_oil", "tomato", "garlic", "ginger"], 0, 0),
    ("machha-tareko", "Crisp Nepali Fried Fish", "नेपाली शैलीमा तारेको ताजा माछा", ["fish", "mustard_oil", "ajwain", "turmeric", "garlic"], 0, 0),
    ("sukuti-sandheko", "Spicy Dried Meat Tartare", "सुकुटी साँधेको खाजा", ["goat_meat", "mustard_oil", "onion", "tomato", "green_chili", "timur"], 0, 0),
    ("mutton-korma-nepali", "Festive Mutton in Yoghurt Broth", "दही हालेको खसीको मासु", ["goat_meat", "yogurt", "ghee", "cardamom", "cinnamon"], 4, 1),
    ("kukhura-timur-roast", "Timur Peppercorn Roast Chicken", "टिमुर हालेको कुखुराको रोस्ट", ["chicken", "mustard_oil", "timur", "garlic", "ginger"], 0, 0),
]

for r_id, en, ne, ing_keys, w, off in meats:
    ings = [{"ingredientId": k, "quantity": 150, "unit": "g"} for k in ing_keys]
    has_pc = (w > 0)
    steps = [
        ("Clean meat, cut into uniform curry cuts, and marinate with ginger-garlic paste, turmeric, and mustard oil.", "मासु सफा गरी एकनासको टुक्रामा काट्नुहोस् र अदुवा-लसुन, बेसार र तोरीको तेलमा मोल्नुहोस्।", 10),
        ("Heat pure mustard oil in pressure cooker or deep pot, sear meat on high heat until deeply browned.", "प्रेसर कुकर वा भाँडोमा तोरीको तेल तताएर मासु खैरो हुने गरी चर्को आगोमा भुट्नुहोस्।", 8),
        (f"Add spices, browned onions, tomatoes, water, seal lid and cook ({w + off} whistles for tender meat).", f"मसला, प्याज, टमाटर र पानी हाली ढक्कन लगाएर मासु नरम नभएसम्म पकाउनुहोस् ({w + off} सिट्ठी)।", 20, (w + off) if has_pc else None),
        ("Allow pressure to drop naturally, open and simmer until oil separates to the surface.", "प्रेसर आफैँ सेलाउन दिनुहोस्, त्यसपछि तेल तैरिने गरी केहीबेर उमाल्नुहोस्।", 5)
    ]
    add_recipe(
        r_id, en, ne, "masu", "pan-nepali", ["non-vegetarian", "gluten-free"],
        15, 30, 4, "medium",
        has_pc, w, off, "medium", "natural",
        ings, steps, ["sharad", "hemanta", "shishir"],
        ["masu", "meat", "festive", "pressure-cooker", "dashain"]
    )

# --- Category: Pickles & Achar (18 recipes) ---
achars = [
    ("golbheda-timur-achar", "Roasted Tomato & Timur Achar", "टिमुर हालेको पोलेको गोलभेडाको अचार", ["tomato", "timur", "green_chili", "garlic", "coriander_fresh"]),
    ("golbheda-til-achar", "Tomato and Roasted Sesame Achar", "तिल हालेको गोलभेडाको अचार", ["tomato", "sesame", "mustard_oil", "green_chili"]),
    ("gundruk-sandheko", "Spicy Marinated Gundruk Salad", "गुन्द्रुक साँधेको", ["gundruk", "mustard_oil", "onion", "tomato", "green_chili", "garlic"]),
    ("sinki-sandheko", "Spicy Fermented Radish Salad", "सिन्की साँधेको", ["sinki", "mustard_oil", "onion", "green_chili", "timur"]),
    ("mula-ko-achar-traditional", "Sun-Fermented Mustard Radish Pickle", "घाममा सुकाएको परम्परागत मूलाको अचार", ["radish", "mustard_oil", "turmeric", "red_chili"]),
    ("mula-kanche-achar", "Instant Fresh Radish Pickle", "काँचो मूलाको छिटो अचार", ["radish", "mustard_oil", "fenugreek_seeds", "turmeric", "green_chili"]),
    ("kakro-ko-achar", "Cucumber Sesame Fresh Pickle", "काँक्रोको तिल हालेको अचार", ["cucumber", "sesame", "mustard_oil", "fenugreek_seeds", "green_chili"]),
    ("aloo-ko-achar-nepali", "Spiced Sesame Potato Salad", "तिलको छोप हालेको आलुको अचार", ["potato", "sesame", "cucumber", "mustard_oil", "fenugreek_seeds", "green_chili"]),
    ("timmur-ko-chhop", "Dry Timur Peppercorn Seasoning Salt", "टिमुरको धुलो छोप", ["timur", "red_chili"]),
    ("til-ko-chhop", "Roasted Sesame Chhop", "भुटेको तिलको छोप", ["sesame", "red_chili", "timur"]),
    ("lasun-khursani-chhop", "Fire Garlic & Chili Chhop", "लसुन र खुर्सानीको पिरो छोप", ["garlic", "red_chili", "mustard_oil"]),
    ("lapsi-khatto-mittho-achar", "Sweet & Sour Hog Plum Pickle", "लप्सीको अमिलो-गुलियो अचार", ["lapsi", "chaku", "red_chili", "mustard_oil"]),
    ("dallay-khursani-achar", "Dalle Khursani Round Chili Pickle", "डल्ले खुर्सानीको पिरो अचार", ["green_chili", "mustard_oil", "garlic"]),
    ("karela-ko-achar", "Bitter Gourd & Mustard Pickle", "करेलाको तोरी हालेको अचार", ["bitter_gourd", "mustard_oil", "turmeric", "red_chili"]),
    ("aam-ko-khatto-achar", "Raw Green Mango Pickle", "काँचो आँपको अमिलो अचार", ["mustard_oil", "fenugreek_seeds", "turmeric", "red_chili"]),
    ("nimbu-ko-achar", "Hill Lemon Mustard Pickle", "निबुवाको अमिलो अचार", ["mustard_oil", "turmeric", "green_chili", "fenugreek_seeds"]),
    ("bhatmas-sandheko", "Crunchy Spiced Soybeans", "भटमास साँधेको (खाजा)", ["bhatmas", "onion", "tomato", "green_chili", "mustard_oil"]),
    ("alu-bodi-ko-achar", "Potato and Black Eyed Bean Pickle", "आलु र बोडीको अचार", ["potato", "bodi", "sesame", "mustard_oil", "fenugreek_seeds"]),
]

for r_id, en, ne, ing_keys in achars:
    ings = [{"ingredientId": k, "quantity": 100, "unit": "g"} for k in ing_keys]
    steps = [
        ("Prepare base ingredients: roast seeds, char tomatoes on direct flame, or julienne fresh roots.", "सामग्री तयार पार्नुहोस्: तिल भुट्ने, गोलभेडा आगोमा पोल्ने वा मूला काट्ने।", 5),
        ("Grind aromatics, chilies, timur, and salt in a stone silauto or grinder into a coarse relish.", "सिलौटो वा ग्राइन्डरमा टिमुर, खुर्सानी, नुन र मसलाहरू मोटो गरी पिस्नुहोस्।", 4),
        ("Temper with smoking mustard oil crackled with fenugreek seeds (methi) and mix thoroughly.", "मेथी फुराएको तातो तोरीको तेलले झ्वाइँय पारी झाँक्नुहोस् र राम्रोसँग मोल्नुहोस्।", 2)
    ]
    add_recipe(
        r_id, en, ne, "achar", "pan-nepali", ["vegetarian", "gluten-free"],
        10, 5, 4, "easy",
        False, 0, 0, "low", "quick",
        ings, steps, ["sharad", "hemanta", "basanta", "grishma"],
        ["achar", "pickle", "chhop", "spicy", "timur", "side-dish"]
    )

# --- Category: Khaja & Street/Tea Food (20 recipes) ---
khajas = [
    ("veg-momo-traditional", "Steamed Vegetable Momo", "बन्दा र पनिरको भेज मःम", ["cabbage", "paneer", "onion", "ginger", "garlic", "wheat_flour"]),
    ("chicken-momo-steamed", "Classic Steamed Chicken Momo", "कुखुराको स्वादिलो मःम", ["chicken", "onion", "ginger", "garlic", "wheat_flour", "coriander_fresh"]),
    ("buff-momo-kathmandu", "Authentic Kathmandu Buff Momo", "काठमाडौँको प्रख्यात बफ मःम", ["buff_meat", "onion", "ginger", "garlic", "wheat_flour"]),
    ("jhol-momo-achar", "Momo in Spicy Sesame-Tomato Broth", "झोल मःम (काठमाडौँ विशेष)", ["chicken", "tomato", "sesame", "timur", "wheat_flour"]),
    ("veg-chowmein-street", "Kathmandu Street-Style Veg Chowmein", "सडकको भेज चाउमिन", ["wheat_flour", "cabbage", "onion", "green_chili", "mustard_oil"]),
    ("chicken-chowmein", "Chicken Chowmein", "कुखुराको मासु हालेको चाउमिन", ["chicken", "wheat_flour", "cabbage", "onion", "mustard_oil"]),
    ("veg-thukpa-soup", "Hearty Vegetable Thukpa Noodle Soup", "तातो भेज थुक्पा", ["wheat_flour", "cabbage", "carrot", "tomato", "ginger", "garlic"]),
    ("buff-thukpa-sherpa", "Mountain Buff Thukpa Soup", "हिमाली बफ थुक्पा", ["buff_meat", "wheat_flour", "cabbage", "garlic", "timur"]),
    ("bara-wo-plain", "Newari Black Lentil Pancake (Bara)", "नेवारी मासको बारा (वो)", ["kalo_dal", "mustard_oil", "ginger", "garlic"]),
    ("bara-wo-egg", "Egg Topped Lentil Pancake", "अन्डा हालेको बारा", ["kalo_dal", "mustard_oil", "ginger"]),
    ("chataamari-plain", "Newari Rice Crepe (Chataamari)", "चतामरी (नेवारी पिज्जा)", ["rice_flour", "ghee"]),
    ("chataamari-keema", "Minced Meat Topped Chataamari", "किमा चतामरी", ["rice_flour", "buff_meat", "onion", "green_chili"]),
    ("aloo-chop-nepali", "Crisp Spiced Potato Chop", "नेपाली आलु चप", ["potato", "onion", "garlic", "mustard_oil", "wheat_flour"]),
    ("pyaaz-pakoda", "Crisp Onion Pakoda", "प्याजको पकोडा", ["onion", "green_chili", "mustard_oil"]),
    ("cauliflower-pakoda", "Cauliflower Fritters", "काउलीको पकोडा", ["cauliflower", "mustard_oil", "turmeric", "ajwain"]),
    ("nepali-samosa", "Flaky Mountain Samosa (Singada)", "नेपाली सिङ्गाडा (समोसा)", ["wheat_flour", "potato", "green_peas", "ghee", "cumin"]),
    ("yomari-chaku", "Traditional Chaku Yomari", "चाकु र तिल हालेको योमरी", ["rice_flour", "chaku", "sesame", "ghee"]),
    ("yomari-khuwa", "Sweet Milk-Solid Yomari", "खुवा हालेको योमरी", ["rice_flour", "milk", "cardamom"]),
    ("gwaramari-newari", "Crispy Puffed Morning Bread", "ग्वावारामारी (बिहानीको खाजा)", ["wheat_flour", "ajwain", "mustard_oil"]),
    ("samay-baji-set", "Newari Samay Baji Festive Platter", "परम्परागत समय् बजि सेट", ["chiura", "kalo_dal", "ginger", "mustard_oil", "garlic"]),
]

for r_id, en, ne, ing_keys in khajas:
    ings = [{"ingredientId": k if k != "carrot" else "radish", "quantity": 120, "unit": "g"} for k in ing_keys]
    steps = [
        ("Prepare dough or batter, season fillings with aromatics, timur, and mustard oil.", "पिठो वा ब्याटर मुछ्नुहोस्, मसला र अदुवा-लसुन हालेर भित्र भर्ने किमा/तरकारी तयार पार्नुहोस्।", 15),
        ("Shape or fold parcels skillfully (e.g. momo pleating or yomari cone shaping).", "सिप पुर्याएर आकार दिनुहोस् (जस्तै: मःमको चुच्चो पार्ने वा योमरीको चुली बनाउने)।", 10),
        ("Steam or deep fry to perfection; serve hot with accompanying spicy chhop or jhol.", "बाफमा उसिन्नुहोस् वा तेलमा खैरो हुने गरी तार्नुहोस्; पिरो अचार वा झोलसँग तात्तातो पस्कनुहोस्।", 12)
    ]
    add_recipe(
        r_id, en, ne, "khaja", "newari" if "yomari" in r_id or "bara" in r_id or "chataamari" in r_id or "samay" in r_id else "pan-nepali",
        ["non-vegetarian"] if "chicken" in r_id or "buff" in r_id else ["vegetarian"],
        20, 15, 4, "medium",
        False, 0, 0, "medium", "quick",
        ings, steps, ["basanta", "grishma", "barsha", "sharad", "hemanta", "shishir"],
        ["khaja", "snack", "street-food", "tea-time"]
    )

# --- Category: Roti, Sweets & Festive Breads (15 recipes) ---
rotis = [
    ("sel-roti-traditional", "Festive Ring-Shaped Rice Bread (Sel Roti)", "परम्परागत तिहारको सेल रोटी", ["rice_flour", "ghee", "milk", "cardamom"]),
    ("malpuwa-sweet", "Sweet Saffron Fried Bread (Malpuwa)", "गुलियो मालपुवा", ["wheat_flour", "milk", "ghee", "cardamom", "fennel"]),
    ("kheer-nepali", "Aromatic Festive Rice Pudding", "नेपाली खीर (साउन १५ र चाडपर्व विशेष)", ["rice", "milk", "ghee", "cardamom"]),
    ("dar-kheer", "Rich Teej Eve Dar Kheer", "तीजको दर खाने खीर", ["rice", "milk", "ghee", "cardamom"]),
    ("puri-festive", "Puffed Golden Deep-Fried Puris", "चाडपर्वको तातो पुरी", ["wheat_flour", "ghee"]),
    ("phulka-roti", "Soft Everyday Wheat Roti", "फुल्का रोटी", ["wheat_flour"]),
    ("kodo-ko-roti", "Rustic Finger Millet Flatbread", "कोदोको पौष्टिक रोटी", ["millet_flour", "ghee"]),
    ("phapar-ko-roti", "Himalayan Buckwheat Pancake", "फापरको रोटी", ["buckwheat_flour", "ghee"]),
    ("makai-ko-roti", "Crispy Cornmeal Flatbread", "मकैको तातो रोटी", ["wheat_flour", "ghee"]),
    ("suji-ko-haluwa", "Semolina Ghee Halwa", "सुजीको दानेदार हलुवा", ["semolina", "ghee", "milk", "cardamom"]),
    ("til-ko-laddu", "Sesame Molasses Balls (Til Laddu)", "माघे सङ्क्रान्तिको तिलको लड्डु", ["sesame", "chaku"]),
    ("chaku-ghyu", "Hardened Molasses with Ghee", "घिउ र चाकु (माघे सङ्क्रान्ति)", ["chaku", "ghee"]),
    ("thekuwa-chhath", "Chhath Sacred Wheat & Jaggery Cookies", "छठ पर्वको पवित्र ठेकुवा", ["wheat_flour", "ghee", "chaku", "cardamom"]),
    ("anarsa-tihar", "Crispy Sesame Rice Pastry", "तिहारको अनर्सा", ["rice_flour", "ghee", "sesame"]),
    ("fini-roti-layered", "Flaky Multi-Layered Festive Pastry", "तिहारको फिनी रोटी", ["wheat_flour", "ghee", "rice_flour"]),
]

for r_id, en, ne, ing_keys in rotis:
    ings = [{"ingredientId": k if k != "fennel" else "cardamom", "quantity": 150, "unit": "g"} for k in ing_keys]
    steps = [
        ("Prepare thick aromatic batter or dough using pure ghee, milk, or ground flours.", "घ्यू, दूध र पिठो मिसाएर बाक्लो ब्याटर वा नरम डल्लो तयार पार्नुहोस्।", 10),
        ("Heat pure ghee or oil in a deep kadai to optimal frying temperature.", "गहिरो कराईमा घ्यू वा तेल मध्यम आगोमा तताउनुहोस्।", 5),
        ("Cook or fry carefully until golden crisp on outside and soft within.", "बाहिर खैरो र कुरकुरे तथा भित्र नरम हुने गरी पकाउनुहोस् वा तार्नुहोस्।", 10)
    ]
    add_recipe(
        r_id, en, ne, "roti_mithai", "pan-nepali", ["vegetarian"],
        15, 20, 4, "medium",
        False, 0, 0, "medium", "quick",
        ings, steps, ["sharad", "hemanta", "shishir"],
        ["roti", "sweet", "festive", "tihar", "dashain", "traditional"]
    )

print(f"Total recipes generated: {len(recipes)}")

# 4. SAVE JSON FILES
with open(os.path.join(OUTPUT_DIR, "ingredients.json"), "w", encoding="utf-8") as f:
    json.dump(ingredients, f, indent=2, ensure_ascii=False)
    f.write("\n")

with open(os.path.join(OUTPUT_DIR, "festivals.json"), "w", encoding="utf-8") as f:
    json.dump(festivals, f, indent=2, ensure_ascii=False)
    f.write("\n")

with open(os.path.join(OUTPUT_DIR, "recipes.json"), "w", encoding="utf-8") as f:
    json.dump(recipes, f, indent=2, ensure_ascii=False)
    f.write("\n")

print("Successfully written ingredients.json, festivals.json, and recipes.json")
