import { describe, it } from 'node:test'
import assert from 'node:assert'
import {
  RegionPackManager,
  type CustomRegionInput,
  type HouseholdPackOverride
} from './region_pack_manager.js'

describe('RegionPackManager TS - Catalog & Discovery', () => {
  it('default catalog contains verified and community packs with correct metadata', () => {
    const manager = new RegionPackManager()
    const catalog = manager.catalog

    assert.ok(catalog.length >= 6)

    const bagmati = catalog.find(c => c.id === 'nepal-bagmati')
    assert.strictEqual(bagmati?.status, 'verified')
    assert.strictEqual(bagmati?.isBuiltIn, true)
    assert.strictEqual(bagmati?.elevationMeters, 1400)
    assert.strictEqual(bagmati?.seasonSystem, 'six-ritus')

    const nsw = catalog.find(c => c.id === 'australia-nsw')
    assert.strictEqual(nsw?.status, 'verified')
    assert.strictEqual(nsw?.isBuiltIn, false)
    assert.strictEqual(nsw?.elevationMeters, 50)
    assert.strictEqual(nsw?.seasonSystem, 'four-seasons-southern')

    const lagos = catalog.find(c => c.id === 'nigeria-lagos')
    assert.strictEqual(lagos?.status, 'community')
    assert.ok(lagos?.marketUnits.includes('derica'))
    assert.strictEqual(lagos?.seasonSystem, 'wet-dry')

    const lapaz = catalog.find(c => c.id === 'bolivia-lapaz')
    assert.strictEqual(lapaz?.status, 'community')
    assert.strictEqual(lapaz?.elevationMeters, 3600)
  })
})

describe('RegionPackManager TS - Installation & Offline Caching', () => {
  it('installs and uninstalls packs from catalog', async () => {
    const manager = new RegionPackManager()
    assert.strictEqual(manager.isInstalled('australia-nsw'), false)

    await manager.installFromCatalog('australia-nsw')
    assert.strictEqual(manager.isInstalled('australia-nsw'), true)
    assert.strictEqual(manager.getPack('australia-nsw')?.manifest.countryCode, 'AU')

    const entry = manager.catalog.find(c => c.id === 'australia-nsw')
    assert.strictEqual(entry?.isInstalled, true)

    // Uninstall
    manager.uninstallPack('australia-nsw')
    assert.strictEqual(manager.isInstalled('australia-nsw'), false)
  })

  it('refuses to uninstall built-in bagmati pack', () => {
    const manager = new RegionPackManager()
    manager.loadBuiltInPack(RegionPackManager.getSamplePack('nepal-bagmati')!)

    assert.throws(() => manager.uninstallPack('nepal-bagmati'))
  })
})

describe('RegionPackManager TS - Multi-Pack Diaspora Setup (Journey 19.3)', () => {
  it('Nepali family in Sydney: dual packs, southern spring, altitude whistle adjustment', async () => {
    const manager = new RegionPackManager()
    await manager.installFromCatalog('australia-nsw')
    manager.loadBuiltInPack(RegionPackManager.getSamplePack('nepal-bagmati')!)

    manager.setPrimaryPack('australia-nsw')
    manager.addSecondaryPack('nepal-bagmati')

    assert.strictEqual(manager.activeConfig.primaryPackId, 'australia-nsw')
    assert.ok(manager.activeConfig.secondaryPackIds.includes('nepal-bagmati'))

    const octoberDate = new Date(2026, 9, 15) // Month 9 = October in JS
    const context = manager.resolveContext({ forDate: octoberDate })

    assert.strictEqual(context.effectiveElevationMeters, 50)
    assert.strictEqual(context.activeSeasonId, 'spring')
    assert.ok(Math.abs(context.effectiveBoilingPointCelsius - 99.8) < 0.3)
    assert.strictEqual(context.currencyCode, 'AUD')

    const recipeIds = context.combinedRecipes.map(r => r.id)
    assert.ok(recipeIds.includes('sydney-spring-salmon'))
    assert.ok(recipeIds.includes('kalo-dal'))

    const kaloDal = context.combinedRecipes.find(r => r.id === 'kalo-dal')!
    const whistlesInSydney = context.adjustWhistlesForRecipe(kaloDal)
    assert.strictEqual(whistlesInSydney, 4) // 4 whistles at sea level vs 5 in KTM

    const asparagusAvailability = context.getIngredientAvailability('asparagus')
    assert.strictEqual(asparagusAvailability, 'peak')
  })

  it('High altitude cooking in La Paz (3,600m - Journey 19.4)', async () => {
    const manager = new RegionPackManager()
    await manager.installFromCatalog('bolivia-lapaz')
    manager.setPrimaryPack('bolivia-lapaz')

    const context = manager.resolveContext()
    assert.strictEqual(context.effectiveElevationMeters, 3600)
    assert.ok(Math.abs(context.effectiveBoilingPointCelsius - 87.4) < 0.3)

    const pesque = context.combinedRecipes.find(r => r.id === 'pesque-de-quinua')!
    const whistles = context.adjustWhistlesForRecipe(pesque)
    assert.strictEqual(whistles, 5)
  })
})

describe('RegionPackManager TS - Custom Region Authoring', () => {
  it('validates input and authors custom region pack', () => {
    const manager = new RegionPackManager()

    const invalidInput: CustomRegionInput = {
      id: '',
      name: '',
      nativeName: '',
      country: '',
      countryCode: '',
      elevationMeters: -50,
      climateZone: 'temperate',
      seasonSystem: 'four-seasons',
      marketUnits: []
    }
    assert.throws(() => manager.createCustomRegion(invalidInput))

    const customInput: CustomRegionInput = {
      id: 'germany-bavaria',
      name: 'Germany (Bavaria / Munich)',
      nativeName: 'Bayern (München)',
      country: 'Germany',
      countryCode: 'DE',
      elevationMeters: 520,
      climateZone: 'temperate',
      seasonSystem: 'four-seasons',
      marketUnits: ['kg', 'g', 'bund', 'stuck'],
      currencyCode: 'EUR',
      currencySymbol: '€',
      customIngredients: [
        {
          id: 'baerlauch',
          nameEn: 'Wild Garlic (Bärlauch)',
          nameNe: 'जङ्गली लसुन (Bärlauch)',
          aliases: ['ramsons'],
          category: 'herbs',
          standardUnit: 'bund',
          marketPackageGrams: 100,
          storageDays: 3,
          allergens: [],
          availability: { spring: 'peak' }
        }
      ]
    }

    const customPack = manager.createCustomRegion(customInput)
    assert.strictEqual(customPack.manifest.id, 'germany-bavaria')
    assert.strictEqual(customPack.manifest.status, 'custom')
    assert.strictEqual(customPack.manifest.currencyCode, 'EUR')
    assert.strictEqual(manager.isInstalled('germany-bavaria'), true)

    const entry = manager.catalog.find(c => c.id === 'germany-bavaria')
    assert.strictEqual(entry?.status, 'custom')
    assert.strictEqual(entry?.isInstalled, true)

    manager.setPrimaryPack('germany-bavaria')
    const context = manager.resolveContext({ forDate: new Date(2026, 3, 15) }) // April
    assert.strictEqual(context.effectiveElevationMeters, 520)
    assert.strictEqual(context.activeSeasonId, 'spring')
    assert.strictEqual(context.currencySymbol, '€')
    assert.ok(context.combinedIngredients.map(i => i.id).includes('baerlauch'))

    manager.deleteCustomRegion('germany-bavaria')
    assert.strictEqual(manager.isInstalled('germany-bavaria'), false)
    assert.strictEqual(manager.activeConfig.primaryPackId, 'nepal-bagmati')
  })
})

describe('RegionPackManager TS - Household Overrides', () => {
  it('layers elevation and unit overrides without mutating pack files', () => {
    const manager = new RegionPackManager()
    manager.loadBuiltInPack(RegionPackManager.getSamplePack('nepal-bagmati')!)
    manager.setPrimaryPack('nepal-bagmati')

    const override: HouseholdPackOverride = {
      elevationMeters: 2100,
      preferredUnits: ['kg', 'g', 'dharni'],
      whistleOffsets: { 'kalo-dal': 1 }
    }
    manager.setHouseholdOverride(override)

    const context = manager.resolveContext()
    assert.strictEqual(context.effectiveElevationMeters, 2100)
    assert.ok(Math.abs(context.effectiveBoilingPointCelsius - 92.6) < 0.3)
    assert.deepStrictEqual(context.effectiveMarketUnits, ['kg', 'g', 'dharni'])

    const kaloDal = context.combinedRecipes.find(r => r.id === 'kalo-dal')!
    const whistles = context.adjustWhistlesForRecipe(kaloDal)
    assert.strictEqual(whistles, 6)
  })
})
