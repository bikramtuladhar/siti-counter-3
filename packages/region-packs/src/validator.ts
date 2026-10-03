import fs from 'node:fs';
import path from 'node:path';
import type {
  RegionPack,
  RegionPackManifest,
  SeasonalityData,
  Ingredient,
  Recipe,
  Festival
} from './types.js';

export interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
  stats: {
    ingredientsCount: number;
    recipesCount: number;
    festivalsCount: number;
    ritusCount: number;
  };
}

export function validateRegionPack(pack: RegionPack): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  // 1. Manifest Checks
  if (!pack.manifest) {
    errors.push('Manifest is missing');
  } else {
    if (!pack.manifest.id) errors.push('Manifest id is required');
    if (!pack.manifest.name) errors.push('Manifest name is required');
    if (typeof pack.manifest.elevationMeters !== 'number') {
      errors.push('Manifest elevationMeters must be a number');
    }
  }

  // 2. Ingredients Checks
  const ingredientIds = new Set<string>();
  if (!Array.isArray(pack.ingredients) || pack.ingredients.length === 0) {
    errors.push('Ingredients list must not be empty');
  } else {
    for (const ing of pack.ingredients) {
      if (!ing.id) errors.push(`Ingredient missing id`);
      if (ingredientIds.has(ing.id)) errors.push(`Duplicate ingredient id: ${ing.id}`);
      ingredientIds.add(ing.id);

      if (!ing.nameEn || !ing.nameNe) {
        errors.push(`Ingredient ${ing.id} missing nameEn or nameNe`);
      }
    }
  }

  // 3. Recipes Checks
  const recipeIds = new Set<string>();
  if (!Array.isArray(pack.recipes) || pack.recipes.length === 0) {
    errors.push('Recipes list must not be empty');
  } else {
    for (const r of pack.recipes) {
      if (!r.id) errors.push('Recipe missing id');
      if (recipeIds.has(r.id)) errors.push(`Duplicate recipe id: ${r.id}`);
      recipeIds.add(r.id);

      if (!r.titleEn || !r.titleNe) {
        errors.push(`Recipe ${r.id} missing titleEn or titleNe`);
      }

      // Check ingredient references
      if (!Array.isArray(r.ingredients) || r.ingredients.length === 0) {
        errors.push(`Recipe ${r.id} has no ingredients`);
      } else {
        for (const rIng of r.ingredients) {
          if (!ingredientIds.has(rIng.ingredientId)) {
            errors.push(`Recipe ${r.id} references undefined ingredient '${rIng.ingredientId}'`);
          }
        }
      }

      // Whistles validation
      if (r.pressureCooker?.enabled) {
        if (typeof r.pressureCooker.recommendedWhistles !== 'number' || r.pressureCooker.recommendedWhistles < 1) {
          errors.push(`Recipe ${r.id} has pressure cooker enabled but invalid whistle count`);
        }
      }
    }
  }

  // 4. Festivals Checks
  const festivalIds = new Set<string>();
  if (!Array.isArray(pack.festivals) || pack.festivals.length === 0) {
    errors.push('Festivals list must not be empty');
  } else {
    for (const f of pack.festivals) {
      if (!f.id) errors.push('Festival missing id');
      if (festivalIds.has(f.id)) errors.push(`Duplicate festival id: ${f.id}`);
      festivalIds.add(f.id);

      if (f.foodTraditions?.keyDishes) {
        for (const dishId of f.foodTraditions.keyDishes) {
          if (!recipeIds.has(dishId)) {
            warnings.push(`Festival ${f.id} references recipe '${dishId}' not found in pack`);
          }
        }
      }
    }
  }

  // 5. Seasonality Checks
  let ritusCount = 0;
  if (!pack.seasonality || !Array.isArray(pack.seasonality.ritus)) {
    errors.push('Seasonality data missing or invalid');
  } else {
    ritusCount = pack.seasonality.ritus.length;
    if (ritusCount !== 6 && pack.manifest?.seasonSystem === 'six-ritus') {
      errors.push(`Expected 6 ritus for six-ritus system, found ${ritusCount}`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
    stats: {
      ingredientsCount: pack.ingredients?.length ?? 0,
      recipesCount: pack.recipes?.length ?? 0,
      festivalsCount: pack.festivals?.length ?? 0,
      ritusCount
    }
  };
}

export function loadRegionPackFromDir(packDirPath: string): RegionPack {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(packDirPath, 'manifest.json'), 'utf-8')
  ) as RegionPackManifest;

  const seasonality = JSON.parse(
    fs.readFileSync(path.join(packDirPath, 'seasonality.json'), 'utf-8')
  ) as SeasonalityData;

  const ingredients = JSON.parse(
    fs.readFileSync(path.join(packDirPath, 'ingredients.json'), 'utf-8')
  ) as Ingredient[];

  const recipes = JSON.parse(
    fs.readFileSync(path.join(packDirPath, 'recipes.json'), 'utf-8')
  ) as Recipe[];

  const festivals = JSON.parse(
    fs.readFileSync(path.join(packDirPath, 'festivals.json'), 'utf-8')
  ) as Festival[];

  return {
    manifest,
    seasonality,
    ingredients,
    recipes,
    festivals
  };
}
