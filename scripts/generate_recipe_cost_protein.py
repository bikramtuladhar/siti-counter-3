#!/usr/bin/env python3
"""Derive costEstimateNpr and proteinGramsPerServing for every recipe in a region pack.

Both fields are computed from the ingredient-level tables below rather than typed by
hand, so the dataset is reproducible and internally consistent: a recipe's cost is
the summed market cost of its ingredients, and its protein is the summed protein mass.

- costEstimateNpr: NPR per serving (the pack already reports `servings`, so cost is
  normalised per serving the same way `caloriesPerServing` is).
- proteinGramsPerServing: grams of protein per serving.

Price and density figures are Kathmandu wet-market / retail estimates for the
Nepal Bagmati pack. Re-run this script after editing recipes.json or the tables:

    python3 scripts/generate_recipe_cost_protein.py
"""

import collections
import json
import pathlib
import sys

from recipe_quantities import QUANTITIES_GRAMS

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACK = ROOT / "packages" / "region-packs" / "nepal-bagmati"

# Approximate retail price in NPR per kilogram of purchasable quantity.
PRICE_NPR_PER_KG = {
    "aromatics": 160,
    "dairy": 620,
    "fermented": 220,
    "flour": 90,
    "fruits": 260,
    "grains": 130,
    "greens": 110,
    "meat": 1100,
    "oils": 480,
    "pulses": 220,
    "seeds": 320,
    "spices": 700,
    "sweeteners": 340,
    "vegetables": 80,
}

# Per-category fallback. Individual ingredients override this where the category is
# too broad to be meaningful (e.g. `dairy` splits ghee from paneer).
PROTEIN_G_PER_100G = {
    "aromatics": 2.0,
    "dairy": 6.0,
    "fermented": 5.0,
    "flour": 10.0,
    "fruits": 1.0,
    "grains": 7.0,
    "greens": 3.0,
    "meat": 20.0,
    "oils": 0.0,
    "pulses": 22.0,
    "seeds": 20.0,
    "spices": 8.0,
    "sweeteners": 1.0,
    "vegetables": 1.5,
}

# Ingredient-level overrides, keyed by ingredient id.
PRICE_OVERRIDES = {
    "ghee": 1600,
    "paneer": 950,
    "yogurt": 220,
    "milk": 110,
    "goat_meat": 1400,
    "buff_meat": 950,
    "chicken": 780,
    "fish": 700,
    "chiura": 260,
    "mushroom": 700,
    "lapsi": 400,
    "chaku": 300,
    "cardamom": 6000,
    "cinnamon": 2200,
    "red_chili": 900,
    "turmeric": 500,
    "ajwain": 800,
    "corn_flour": 100,
    "banana": 120,
    "green_mango": 140,
    "lemon": 160,
    "egg": 300,
}

PROTEIN_OVERRIDES = {
    "ghee": 0.0,
    "paneer": 18.0,
    "yogurt": 3.5,
    "milk": 3.2,
    "goat_meat": 21.0,
    "buff_meat": 20.0,
    "chicken": 19.0,
    "fish": 18.0,
    "chiura": 8.0,
    "rice": 7.0,
    "wheat_flour": 11.0,
    "rice_flour": 6.0,
    "millet_flour": 11.0,
    "buckwheat_flour": 13.0,
    "semolina": 11.0,
    "corn_flour": 9.0,
    "banana": 1.1,
    "green_mango": 0.8,
    "lemon": 1.0,
    "egg": 13.0,
    "masuro_dal": 24.0,
    "kalo_dal": 24.0,
    "rahar_dal": 22.0,
    "mung_dal": 21.0,
    "chana": 19.0,
    "kwati_mix": 23.0,
    "bhatmas": 26.0,
    "sesame": 18.0,
    "mushroom": 3.0,
    "green_peas": 5.0,
}
SUPPORTED_UNITS = {"g": 1.0}


def load(name):
    with open(PACK / f"{name}.json", encoding="utf-8") as fh:
        return json.load(fh)


def price_per_kg(ingredient):
    if ingredient["id"] in PRICE_OVERRIDES:
        return PRICE_OVERRIDES[ingredient["id"]]
    return PRICE_NPR_PER_KG[ingredient["category"]]


def protein_per_100g(ingredient):
    if ingredient["id"] in PROTEIN_OVERRIDES:
        return PROTEIN_OVERRIDES[ingredient["id"]]
    return PROTEIN_G_PER_100G[ingredient["category"]]


def main():
    ingredients = {i["id"]: i for i in load("ingredients")}
    recipes = load("recipes")

    unknown = sorted(
        {
            item["ingredientId"]
            for recipe in recipes
            for item in recipe["ingredients"]
            if item["ingredientId"] not in ingredients
        }
    )
    if unknown:
        sys.exit(f"recipes reference unknown ingredients: {unknown}")

    bad_units = sorted(
        {
            item["unit"]
            for recipe in recipes
            for item in recipe["ingredients"]
            if item["unit"] not in SUPPORTED_UNITS
        }
    )
    if bad_units:
        sys.exit(f"unsupported ingredient units: {bad_units}")

    missing_recipes = sorted({r["id"] for r in recipes} - set(QUANTITIES_GRAMS))
    if missing_recipes:
        sys.exit(f"no authored quantities for: {missing_recipes}")
    stale_recipes = sorted(set(QUANTITIES_GRAMS) - {r["id"] for r in recipes})
    if stale_recipes:
        sys.exit(f"authored quantities for unknown recipes: {stale_recipes}")

    for recipe in recipes:
        authored = QUANTITIES_GRAMS[recipe["id"]]
        line_ids = [item["ingredientId"] for item in recipe["ingredients"]]

        missing = sorted(set(line_ids) - set(authored))
        if missing:
            sys.exit(f"{recipe['id']}: missing quantities for {missing}")
        extra = sorted(set(authored) - set(line_ids))
        if extra:
            sys.exit(f"{recipe['id']}: quantities for unused ingredients {extra}")

        # A repeated ingredient carries a list of per-step grams, consumed in order.
        remaining = {
            key: (list(value) if isinstance(value, list) else [value])
            for key, value in authored.items()
        }
        for item in recipe["ingredients"]:
            key = item["ingredientId"]
            if not remaining[key]:
                sys.exit(f"{recipe['id']}: no {key} quantity left for a repeated line")
            item["quantity"] = remaining[key].pop(0)
        leftovers = {key: value for key, value in remaining.items() if value}
        if leftovers:
            sys.exit(f"{recipe['id']}: unused quantities {leftovers}")

    for recipe in recipes:
        servings = recipe["servings"]
        cost = 0.0
        protein = 0.0
        for item in recipe["ingredients"]:
            grams = item["quantity"] * SUPPORTED_UNITS[item["unit"]]
            ingredient = ingredients[item["ingredientId"]]
            cost += grams / 1000.0 * price_per_kg(ingredient)
            protein += grams * protein_per_100g(ingredient) / 100.0
        recipe["costEstimateNpr"] = max(1, round(cost / servings))
        recipe["proteinGramsPerServing"] = round(protein / servings, 1)

    with open(PACK / "recipes.json", "w", encoding="utf-8") as fh:
        json.dump(recipes, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    costs = [r["costEstimateNpr"] for r in recipes]
    proteins = [r["proteinGramsPerServing"] for r in recipes]
    print(f"recipes: {len(recipes)}")
    print(f"cost NPR/serving   min={min(costs)} max={max(costs)} mean={sum(costs)/len(costs):.1f}")
    print(f"protein g/serving  min={min(proteins)} max={max(proteins)} mean={sum(proteins)/len(proteins):.1f}")

    by_category = collections.defaultdict(list)
    for recipe in recipes:
        by_category[recipe["category"]].append(recipe)
    for category in sorted(by_category):
        rows = by_category[category]
        print(
            f"  {category:<11} n={len(rows):<4}"
            f" cost {min(r['costEstimateNpr'] for r in rows):>4}-"
            f"{max(r['costEstimateNpr'] for r in rows):<4}"
            f" protein {min(r['proteinGramsPerServing'] for r in rows):>5}-"
            f"{max(r['proteinGramsPerServing'] for r in rows):<5}"
        )


if __name__ == "__main__":
    main()
