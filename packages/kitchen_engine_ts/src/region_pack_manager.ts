import { AltitudeCalculator } from './index.js'

export type RegionPackStatus = 'verified' | 'community' | 'custom'

export interface RegionPackCatalogEntry {
  id: string
  name: string
  nativeName: string
  country: string
  countryCode: string
  status: RegionPackStatus
  version: string
  description: string
  elevationMeters: number
  climateZone: string
  seasonSystem: string
  defaultLanguage: string
  calendar: string
  currencyCode: string
  currencySymbol: string
  marketUnits: string[]
  sizeBytes: number
  recipeCount: number
  ingredientCount: number
  isBuiltIn: boolean
  downloadUrl?: string
  isInstalled: boolean
}

export interface ActiveRegionConfig {
  primaryPackId: string
  secondaryPackIds: string[]
}

export interface HouseholdPackOverride {
  elevationMeters?: number
  preferredUnits?: string[]
  customIngredients?: RegionIngredient[]
  whistleOffsets?: Record<string, number>
}

export interface RegionIngredient {
  id: string
  nameEn: string
  nameNe: string
  aliases: string[]
  category: string
  standardUnit: string
  marketPackageGrams: number
  storageDays: number
  allergens: string[]
  availability: Record<string, string>
}

export interface RecipeIngredientItem {
  ingredientId: string
  quantity: number
  unit: string
  notes?: string
}

export interface RecipeWhistleProfile {
  enabled: boolean
  recommendedWhistles: number
  altitudeWhistleOffsetKathmandu: number
  heatLevel: string
  releaseType: string
}

export interface RegionRecipe {
  id: string
  titleEn: string
  titleNe: string
  category: string
  cuisine: string
  dietary: string[]
  prepTimeMinutes: number
  cookTimeMinutes: number
  servings: number
  difficulty: string
  pressureCooker: RecipeWhistleProfile
  ingredients: RecipeIngredientItem[]
  seasonality: string[]
  tags: string[]
  originPackId?: string
}

export interface RegionFestival {
  id: string
  nameEn: string
  nameNe: string
  tithi: string
  approxGregorianMonth: string
  descriptionEn: string
  descriptionNe: string
  keyDishes: string[]
}

export interface RituSeason {
  id: string
  name: string
  monthsBS: string[]
  monthsGregorian: string[]
  signatureProduce: string[]
}

export interface RegionPackManifest {
  id: string
  version: string
  name: string
  country: string
  countryCode: string
  region: string
  status: RegionPackStatus
  elevationMeters: number
  defaultLanguage: string
  calendar: string
  seasonSystem: string
  currencyCode: string
  currencySymbol: string
  marketUnits: string[]
}

export interface RegionPack {
  manifest: RegionPackManifest
  seasonality: {
    regionId: string
    ritus: RituSeason[]
  }
  ingredients: RegionIngredient[]
  recipes: RegionRecipe[]
  festivals: RegionFestival[]
}

export interface CustomRegionInput {
  id: string
  name: string
  nativeName: string
  country: string
  countryCode: string
  elevationMeters: number
  climateZone: string
  seasonSystem: string
  marketUnits: string[]
  defaultLanguage?: string
  calendar?: string
  currencyCode?: string
  currencySymbol?: string
  seasons?: RituSeason[]
  customIngredients?: RegionIngredient[]
  customRecipes?: RegionRecipe[]
}

export interface ResolvedRegionContext {
  primaryPack: RegionPack
  secondaryPacks: RegionPack[]
  override?: HouseholdPackOverride
  effectiveElevationMeters: number
  effectiveBoilingPointCelsius: number
  activeSeasonId: string
  activeSeasonName: string
  combinedRecipes: RegionRecipe[]
  combinedIngredients: RegionIngredient[]
  combinedFestivals: RegionFestival[]
  effectiveMarketUnits: string[]
  currencyCode: string
  currencySymbol: string
  getIngredientAvailability(ingredientId: string): string
  adjustWhistlesForRecipe(recipe: RegionRecipe): number
}

export class RegionPackManager {
  private _installedPacks: Map<string, RegionPack> = new Map()
  private _catalog: RegionPackCatalogEntry[] = []
  private _activeConfig: ActiveRegionConfig
  private _householdOverride?: HouseholdPackOverride

  constructor(options?: {
    catalog?: RegionPackCatalogEntry[]
    initialInstalledPacks?: Map<string, RegionPack> | Record<string, RegionPack>
    activeConfig?: ActiveRegionConfig
    householdOverride?: HouseholdPackOverride
  }) {
    this._activeConfig = options?.activeConfig ?? {
      primaryPackId: 'nepal-bagmati',
      secondaryPackIds: []
    }
    this._householdOverride = options?.householdOverride

    if (options?.catalog) {
      this._catalog = [...options.catalog]
    } else {
      this._catalog = [...RegionPackManager.defaultCatalog]
    }

    if (options?.initialInstalledPacks) {
      if (options.initialInstalledPacks instanceof Map) {
        this._installedPacks = new Map(options.initialInstalledPacks)
      } else {
        this._installedPacks = new Map(Object.entries(options.initialInstalledPacks))
      }
    }
  }

  get installedPacks(): Map<string, RegionPack> {
    return new Map(this._installedPacks)
  }

  get activeConfig(): ActiveRegionConfig {
    return { ...this._activeConfig }
  }

  get householdOverride(): HouseholdPackOverride | undefined {
    return this._householdOverride ? { ...this._householdOverride } : undefined
  }

  get catalog(): RegionPackCatalogEntry[] {
    return this._catalog.map(entry => ({
      ...entry,
      isInstalled: this._installedPacks.has(entry.id)
    }))
  }

  isInstalled(packId: string): boolean {
    return this._installedPacks.has(packId)
  }

  getPack(packId: string): RegionPack | undefined {
    return this._installedPacks.get(packId)
  }

  loadBuiltInPack(pack: RegionPack): void {
    this._installedPacks.set(pack.manifest.id, pack)
  }

  async installPack(pack: RegionPack): Promise<void> {
    this._installedPacks.set(pack.manifest.id, pack)
  }

  async installFromCatalog(packId: string, downloadedPack?: RegionPack): Promise<void> {
    const pack = downloadedPack ?? RegionPackManager.getSamplePack(packId)
    if (!pack) {
      throw new Error(`Region pack not found in catalog: ${packId}`)
    }
    await this.installPack(pack)
  }

  uninstallPack(packId: string): void {
    const entry = this._catalog.find(c => c.id === packId)
    if (entry?.isBuiltIn) {
      throw new Error(`Built-in region pack ${packId} cannot be uninstalled.`)
    }
    this._installedPacks.delete(packId)

    if (this._activeConfig.primaryPackId === packId) {
      this._activeConfig.primaryPackId = 'nepal-bagmati'
    }
    this._activeConfig.secondaryPackIds = this._activeConfig.secondaryPackIds.filter(
      id => id !== packId
    )
  }

  setPrimaryPack(packId: string): void {
    if (!this._installedPacks.has(packId)) {
      const entry = this._catalog.find(c => c.id === packId)
      if (entry) {
        const sample = RegionPackManager.getSamplePack(packId)
        if (sample) {
          this._installedPacks.set(packId, sample)
        } else {
          throw new Error(`Pack ${packId} is not installed.`)
        }
      } else {
        throw new Error(`Pack ${packId} not found in catalog.`)
      }
    }

    this._activeConfig.primaryPackId = packId
    this._activeConfig.secondaryPackIds = this._activeConfig.secondaryPackIds.filter(
      id => id !== packId
    )
  }

  addSecondaryPack(packId: string): void {
    if (packId === this._activeConfig.primaryPackId) return
    if (this._activeConfig.secondaryPackIds.includes(packId)) return

    if (!this._installedPacks.has(packId)) {
      const sample = RegionPackManager.getSamplePack(packId)
      if (sample) {
        this._installedPacks.set(packId, sample)
      }
    }

    this._activeConfig.secondaryPackIds.push(packId)
  }

  removeSecondaryPack(packId: string): void {
    this._activeConfig.secondaryPackIds = this._activeConfig.secondaryPackIds.filter(
      id => id !== packId
    )
  }

  createCustomRegion(input: CustomRegionInput): RegionPack {
    const errors: string[] = []
    if (!input.id || input.id.trim().length === 0) errors.push('Region ID is required')
    if (!input.name || input.name.trim().length === 0) errors.push('Region name is required')
    if (!input.country || input.country.trim().length === 0) errors.push('Country is required')
    if (input.elevationMeters < 0) errors.push('Elevation must be 0 meters or higher')
    if (!input.marketUnits || input.marketUnits.length === 0) errors.push('At least one market unit is required')

    if (errors.length > 0) {
      throw new Error(`Invalid custom region input: ${errors.join(', ')}`)
    }

    const defaultSeasons = input.seasons && input.seasons.length > 0
      ? input.seasons
      : RegionPackManager.buildDefaultSeasons(input.seasonSystem)

    const manifest: RegionPackManifest = {
      id: input.id,
      version: '1.0.0',
      name: input.name,
      country: input.country,
      countryCode: input.countryCode,
      region: input.name,
      status: 'custom',
      elevationMeters: input.elevationMeters,
      defaultLanguage: input.defaultLanguage ?? 'en',
      calendar: input.calendar ?? 'gregorian',
      seasonSystem: input.seasonSystem,
      currencyCode: input.currencyCode ?? 'USD',
      currencySymbol: input.currencySymbol ?? '$',
      marketUnits: input.marketUnits
    }

    const pack: RegionPack = {
      manifest,
      seasonality: {
        regionId: input.id,
        ritus: defaultSeasons
      },
      ingredients: input.customIngredients ?? [],
      recipes: input.customRecipes ?? [],
      festivals: []
    }

    this._installedPacks.set(input.id, pack)

    // Update catalog
    this._catalog = this._catalog.filter(c => c.id !== input.id)
    this._catalog.push({
      id: input.id,
      name: input.name,
      nativeName: input.nativeName,
      country: input.country,
      countryCode: input.countryCode,
      status: 'custom',
      version: '1.0.0',
      description: `User authored custom region: ${input.name}`,
      elevationMeters: input.elevationMeters,
      climateZone: input.climateZone,
      seasonSystem: input.seasonSystem,
      defaultLanguage: input.defaultLanguage ?? 'en',
      calendar: input.calendar ?? 'gregorian',
      currencyCode: input.currencyCode ?? 'USD',
      currencySymbol: input.currencySymbol ?? '$',
      marketUnits: input.marketUnits,
      sizeBytes: 15360,
      recipeCount: input.customRecipes?.length ?? 0,
      ingredientCount: input.customIngredients?.length ?? 0,
      isBuiltIn: false,
      isInstalled: true
    })

    return pack
  }

  deleteCustomRegion(packId: string): void {
    const entry = this._catalog.find(c => c.id === packId)
    if (entry?.status !== 'custom') {
      throw new Error('Only custom region packs can be deleted via this method.')
    }
    this._catalog = this._catalog.filter(c => c.id !== packId)
    this._installedPacks.delete(packId)

    if (this._activeConfig.primaryPackId === packId) {
      this._activeConfig.primaryPackId = 'nepal-bagmati'
    }
    this._activeConfig.secondaryPackIds = this._activeConfig.secondaryPackIds.filter(
      id => id !== packId
    )
  }

  setHouseholdOverride(override?: HouseholdPackOverride): void {
    this._householdOverride = override
  }

  resolveContext(options?: { forDate?: Date }): ResolvedRegionContext {
    const targetDate = options?.forDate ?? new Date()

    const primaryPack =
      this._installedPacks.get(this._activeConfig.primaryPackId) ??
      RegionPackManager.getSamplePack(this._activeConfig.primaryPackId) ??
      RegionPackManager.getSamplePack('nepal-bagmati')!

    const secondaryPacks: RegionPack[] = []
    for (const id of this._activeConfig.secondaryPackIds) {
      const sPack = this._installedPacks.get(id) ?? RegionPackManager.getSamplePack(id)
      if (sPack) {
        secondaryPacks.push(sPack)
      }
    }

    const effectiveElevation =
      this._householdOverride?.elevationMeters ?? primaryPack.manifest.elevationMeters
    const effectiveBoilingPoint = AltitudeCalculator.boilingPointCelsius(effectiveElevation)

    const activeSeason = RegionPackManager.resolveSeason(
      primaryPack.manifest.seasonSystem,
      primaryPack.seasonality.ritus,
      targetDate
    )

    // Combine recipes
    const recipeMap = new Map<string, RegionRecipe>()
    for (const r of primaryPack.recipes) {
      recipeMap.set(r.id, { ...r, originPackId: primaryPack.manifest.id })
    }
    for (const sec of secondaryPacks) {
      for (const r of sec.recipes) {
        if (!recipeMap.has(r.id)) {
          recipeMap.set(r.id, { ...r, originPackId: sec.manifest.id })
        }
      }
    }

    // Combine ingredients
    const ingredientMap = new Map<string, RegionIngredient>()
    for (const ing of primaryPack.ingredients) {
      ingredientMap.set(ing.id, ing)
    }
    for (const sec of secondaryPacks) {
      for (const ing of sec.ingredients) {
        if (!ingredientMap.has(ing.id)) {
          ingredientMap.set(ing.id, ing)
        }
      }
    }
    if (this._householdOverride?.customIngredients) {
      for (const ing of this._householdOverride.customIngredients) {
        ingredientMap.set(ing.id, ing)
      }
    }

    // Combine festivals
    const festivalMap = new Map<string, RegionFestival>()
    for (const f of primaryPack.festivals) {
      festivalMap.set(f.id, f)
    }
    for (const sec of secondaryPacks) {
      for (const f of sec.festivals) {
        if (!festivalMap.has(f.id)) {
          festivalMap.set(f.id, f)
        }
      }
    }

    const effectiveUnits =
      this._householdOverride?.preferredUnits ?? primaryPack.manifest.marketUnits

    const overrideWhistleOffsets = this._householdOverride?.whistleOffsets

    return {
      primaryPack,
      secondaryPacks,
      override: this._householdOverride,
      effectiveElevationMeters: effectiveElevation,
      effectiveBoilingPointCelsius: effectiveBoilingPoint,
      activeSeasonId: activeSeason.id,
      activeSeasonName: activeSeason.name,
      combinedRecipes: Array.from(recipeMap.values()),
      combinedIngredients: Array.from(ingredientMap.values()),
      combinedFestivals: Array.from(festivalMap.values()),
      effectiveMarketUnits: effectiveUnits,
      currencyCode: primaryPack.manifest.currencyCode,
      currencySymbol: primaryPack.manifest.currencySymbol,

      getIngredientAvailability(ingredientId: string): string {
        const ing = primaryPack.ingredients.find(i => i.id === ingredientId)
        if (!ing) return 'out_of_season'
        return ing.availability[activeSeason.id] ?? 'out_of_season'
      },

      adjustWhistlesForRecipe(recipe: RegionRecipe): number {
        if (!recipe.pressureCooker?.enabled) return 0
        const base = recipe.pressureCooker.recommendedWhistles
        const adjusted = AltitudeCalculator.adjustSitiCount(base, effectiveElevation)
        const offset = overrideWhistleOffsets?.[recipe.id] ?? 0
        return adjusted + offset
      }
    }
  }

  static resolveSeason(
    seasonSystem: string,
    seasons: RituSeason[],
    date: Date
  ): RituSeason {
    const month = date.getMonth() + 1 // 1-12

    if (seasonSystem === 'six-ritus') {
      let targetId: string
      if (month === 3 || month === 4) targetId = 'basanta'
      else if (month === 5 || month === 6) targetId = 'grishma'
      else if (month === 7 || month === 8) targetId = 'barsha'
      else if (month === 9 || month === 10) targetId = 'sharad'
      else if (month === 11 || month === 12) targetId = 'hemanta'
      else targetId = 'shishir'

      return (
        seasons.find(s => s.id === targetId) ??
        seasons[0] ?? {
          id: 'sharad',
          name: 'शरद् ऋतु (Sharad)',
          monthsBS: ['Ashwin', 'Kartik'],
          monthsGregorian: ['September', 'October'],
          signatureProduce: ['cauliflower', 'radish', 'mustard_greens']
        }
      )
    }

    if (seasonSystem === 'four-seasons-southern') {
      let targetId: string
      if (month >= 9 && month <= 11) targetId = 'spring'
      else if (month === 12 || month === 1 || month === 2) targetId = 'summer'
      else if (month >= 3 && month <= 5) targetId = 'autumn'
      else targetId = 'winter'

      return (
        seasons.find(s => s.id === targetId) ??
        seasons[0] ?? {
          id: targetId,
          name: targetId[0].toUpperCase() + targetId.slice(1),
          monthsBS: [],
          monthsGregorian: [],
          signatureProduce: []
        }
      )
    }

    if (seasonSystem === 'four-seasons') {
      let targetId: string
      if (month >= 3 && month <= 5) targetId = 'spring'
      else if (month >= 6 && month <= 8) targetId = 'summer'
      else if (month >= 9 && month <= 11) targetId = 'autumn'
      else targetId = 'winter'

      return (
        seasons.find(s => s.id === targetId) ??
        seasons[0] ?? {
          id: targetId,
          name: targetId[0].toUpperCase() + targetId.slice(1),
          monthsBS: [],
          monthsGregorian: [],
          signatureProduce: []
        }
      )
    }

    if (seasonSystem === 'wet-dry') {
      const isRainy = month >= 4 && month <= 10
      const targetId = isRainy ? 'rainy' : 'dry'
      return (
        seasons.find(s => s.id === targetId) ??
        seasons[0] ?? {
          id: targetId,
          name: isRainy ? 'Rainy Season' : 'Dry Season',
          monthsBS: [],
          monthsGregorian: [],
          signatureProduce: []
        }
      )
    }

    return (
      seasons[0] ?? {
        id: 'default',
        name: 'Standard Season',
        monthsBS: [],
        monthsGregorian: [],
        signatureProduce: []
      }
    )
  }

  static buildDefaultSeasons(seasonSystem: string): RituSeason[] {
    if (seasonSystem === 'four-seasons' || seasonSystem === 'four-seasons-southern') {
      return [
        {
          id: 'spring',
          name: 'Spring',
          monthsBS: [],
          monthsGregorian: ['September', 'October', 'November'],
          signatureProduce: ['asparagus', 'spinach', 'peas', 'strawberries']
        },
        {
          id: 'summer',
          name: 'Summer',
          monthsBS: [],
          monthsGregorian: ['December', 'January', 'February'],
          signatureProduce: ['tomatoes', 'corn', 'zucchini', 'stone_fruit']
        },
        {
          id: 'autumn',
          name: 'Autumn',
          monthsBS: [],
          monthsGregorian: ['March', 'April', 'May'],
          signatureProduce: ['pumpkin', 'apples', 'mushrooms', 'sweet_potato']
        },
        {
          id: 'winter',
          name: 'Winter',
          monthsBS: [],
          monthsGregorian: ['June', 'July', 'August'],
          signatureProduce: ['kale', 'broccoli', 'citrus', 'root_vegetables']
        }
      ]
    } else if (seasonSystem === 'wet-dry') {
      return [
        {
          id: 'rainy',
          name: 'Rainy Season',
          monthsBS: [],
          monthsGregorian: ['April', 'May', 'June', 'July', 'August', 'September', 'October'],
          signatureProduce: ['yam', 'plantain', 'cassava', 'peppers']
        },
        {
          id: 'dry',
          name: 'Dry Season',
          monthsBS: [],
          monthsGregorian: ['November', 'December', 'January', 'February', 'March'],
          signatureProduce: ['beans', 'groundnuts', 'millet', 'onions']
        }
      ]
    } else {
      return [
        {
          id: 'basanta',
          name: 'वसन्तः (Basanta / Spring)',
          monthsBS: ['Chaitra', 'Baisakh'],
          monthsGregorian: ['March', 'April'],
          signatureProduce: ['green_garlic', 'pointed_gourd', 'spinach']
        },
        {
          id: 'grishma',
          name: 'ग्रीष्मः (Grishma / Summer)',
          monthsBS: ['Jestha', 'Ashadh'],
          monthsGregorian: ['May', 'June'],
          signatureProduce: ['okra', 'cucumber', 'bitter_gourd']
        },
        {
          id: 'barsha',
          name: 'वर्षा (Barsha / Monsoon)',
          monthsBS: ['Shrawan', 'Bhadra'],
          monthsGregorian: ['July', 'August'],
          signatureProduce: ['taro_leaves', 'bamboo_shoots', 'bottle_gourd']
        },
        {
          id: 'sharad',
          name: 'शरद् (Sharad / Autumn)',
          monthsBS: ['Ashwin', 'Kartik'],
          monthsGregorian: ['September', 'October'],
          signatureProduce: ['cauliflower', 'radish', 'mustard_greens']
        },
        {
          id: 'hemanta',
          name: 'हेमन्तः (Hemanta / Late Autumn)',
          monthsBS: ['Mangsir', 'Poush'],
          monthsGregorian: ['November', 'December'],
          signatureProduce: ['green_peas', 'broad_beans', 'coriander']
        },
        {
          id: 'shishir',
          name: 'शिशिरः (Shishir / Winter)',
          monthsBS: ['Magh', 'Falgun'],
          monthsGregorian: ['January', 'February'],
          signatureProduce: ['spinach', 'mustard_greens', 'carrots']
        }
      ]
    }
  }

  static get defaultCatalog(): RegionPackCatalogEntry[] {
    return [
      {
        id: 'nepal-bagmati',
        name: 'Nepal (Bagmati Province)',
        nativeName: 'नेपाल (बागमती प्रदेश - काठमाडौँ)',
        country: 'Nepal',
        countryCode: 'NP',
        status: 'verified',
        version: '1.0.0',
        description:
          'Kathmandu Valley and Bagmati mid-hills with 6 ritus, Bikram Sambat calendar, and haat bazaar market units (pau, dharni, mana).',
        elevationMeters: 1400,
        climateZone: 'subtropical',
        seasonSystem: 'six-ritus',
        defaultLanguage: 'ne',
        calendar: 'bikram-sambat',
        currencyCode: 'NPR',
        currencySymbol: 'रू',
        marketUnits: ['pau', 'dharni', 'mana', 'muthi', 'kg', 'g'],
        sizeBytes: 245760,
        recipeCount: 30,
        ingredientCount: 68,
        isBuiltIn: true,
        isInstalled: true
      },
      {
        id: 'nepal-terai',
        name: 'Nepal (Terai Plains)',
        nativeName: 'नेपाल (तराई-मधेस प्रदेश)',
        country: 'Nepal',
        countryCode: 'NP',
        status: 'verified',
        version: '1.0.0',
        description:
          'Southern plains of Nepal (Janakpur, Biratnagar, Chitwan) with river fish, seasonal parwal, sattu, and Mithila cuisine.',
        elevationMeters: 200,
        climateZone: 'tropical',
        seasonSystem: 'six-ritus',
        defaultLanguage: 'ne',
        calendar: 'bikram-sambat',
        currencyCode: 'NPR',
        currencySymbol: 'रू',
        marketUnits: ['kg', 'g', 'pau', 'bunch'],
        sizeBytes: 184320,
        recipeCount: 15,
        ingredientCount: 42,
        isBuiltIn: false,
        isInstalled: false
      },
      {
        id: 'australia-nsw',
        name: 'Australia (New South Wales / Sydney)',
        nativeName: 'Australia (NSW - Sydney)',
        country: 'Australia',
        countryCode: 'AU',
        status: 'verified',
        version: '1.0.0',
        description:
          'Sydney and NSW coast featuring Southern Hemisphere inverted seasons, metric units, fresh spring asparagus and seafood.',
        elevationMeters: 50,
        climateZone: 'temperate',
        seasonSystem: 'four-seasons-southern',
        defaultLanguage: 'en',
        calendar: 'gregorian',
        currencyCode: 'AUD',
        currencySymbol: '$',
        marketUnits: ['kg', 'g', 'cup', 'bunch', 'punnet'],
        sizeBytes: 198656,
        recipeCount: 12,
        ingredientCount: 38,
        isBuiltIn: false,
        isInstalled: false
      },
      {
        id: 'uk-london',
        name: 'United Kingdom (London & SE)',
        nativeName: 'UK (Greater London)',
        country: 'United Kingdom',
        countryCode: 'GB',
        status: 'verified',
        version: '1.0.0',
        description:
          'London metropolitan area with British seasonal produce, farmers market punnets, leeks, root vegetables and autumn bramley apples.',
        elevationMeters: 35,
        climateZone: 'temperate',
        seasonSystem: 'four-seasons',
        defaultLanguage: 'en',
        calendar: 'gregorian',
        currencyCode: 'GBP',
        currencySymbol: '£',
        marketUnits: ['kg', 'g', 'punnet', 'pack', 'bunch'],
        sizeBytes: 172032,
        recipeCount: 10,
        ingredientCount: 35,
        isBuiltIn: false,
        isInstalled: false
      },
      {
        id: 'nigeria-lagos',
        name: 'Nigeria (Lagos State)',
        nativeName: 'Nigeria (Ìpínlẹ̀ Èkó / Lagos)',
        country: 'Nigeria',
        countryCode: 'NG',
        status: 'community',
        version: '1.0.0',
        description:
          'Lagos coastal metropolis with rainy/dry tropical seasons, local market volume units (derica, mudu, olodo), yams, and plantains.',
        elevationMeters: 10,
        climateZone: 'tropical',
        seasonSystem: 'wet-dry',
        defaultLanguage: 'en',
        calendar: 'gregorian',
        currencyCode: 'NGN',
        currencySymbol: '₦',
        marketUnits: ['kg', 'derica', 'olodo', 'mudu', 'heap', 'piece'],
        sizeBytes: 153600,
        recipeCount: 8,
        ingredientCount: 30,
        isBuiltIn: false,
        isInstalled: false
      },
      {
        id: 'bolivia-lapaz',
        name: 'Bolivia (La Paz & Altiplano)',
        nativeName: 'Bolivia (Nuestra Señora de La Paz)',
        country: 'Bolivia',
        countryCode: 'BO',
        status: 'community',
        version: '1.0.0',
        description:
          'High-altitude Andean plateau (3,600m) where water boils at 87°C requiring specialized pressure cooker timings, quinoa and chuño.',
        elevationMeters: 3600,
        climateZone: 'highland',
        seasonSystem: 'four-seasons-southern',
        defaultLanguage: 'es',
        calendar: 'gregorian',
        currencyCode: 'BOB',
        currencySymbol: 'Bs',
        marketUnits: ['kg', 'g', 'libra', 'arroba'],
        sizeBytes: 163840,
        recipeCount: 8,
        ingredientCount: 28,
        isBuiltIn: false,
        isInstalled: false
      }
    ]
  }

  static getSamplePack(id: string): RegionPack | undefined {
    switch (id) {
      case 'nepal-bagmati':
        return {
          manifest: {
            id: 'nepal-bagmati',
            version: '1.0.0',
            name: 'Nepal (Bagmati Province)',
            country: 'Nepal',
            countryCode: 'NP',
            region: 'Bagmati',
            status: 'verified',
            elevationMeters: 1400,
            defaultLanguage: 'ne',
            calendar: 'bikram-sambat',
            seasonSystem: 'six-ritus',
            currencyCode: 'NPR',
            currencySymbol: 'रू',
            marketUnits: ['pau', 'dharni', 'mana', 'muthi', 'kg', 'g']
          },
          seasonality: {
            regionId: 'nepal-bagmati',
            ritus: [
              {
                id: 'sharad',
                name: 'शरद् ऋतु (Sharad)',
                monthsBS: ['Ashwin', 'Kartik'],
                monthsGregorian: ['September', 'October'],
                signatureProduce: ['cauliflower', 'radish', 'mustard_greens']
              },
              {
                id: 'barsha',
                name: 'वर्षा ऋतु (Barsha)',
                monthsBS: ['Shrawan', 'Bhadra'],
                monthsGregorian: ['July', 'August'],
                signatureProduce: ['taro_leaves', 'bamboo_shoots']
              }
            ]
          },
          ingredients: [
            {
              id: 'cauliflower',
              nameEn: 'Cauliflower',
              nameNe: 'काउली',
              aliases: ['phool gobi'],
              category: 'vegetables',
              standardUnit: 'kg',
              marketPackageGrams: 1000,
              storageDays: 5,
              allergens: [],
              availability: { sharad: 'peak', barsha: 'out_of_season' }
            },
            {
              id: 'kalo_dal',
              nameEn: 'Black Lentils (Urad)',
              nameNe: 'मासको दाल',
              aliases: ['urad dal'],
              category: 'pulses',
              standardUnit: 'kg',
              marketPackageGrams: 1000,
              storageDays: 180,
              allergens: [],
              availability: { sharad: 'available', barsha: 'available' }
            }
          ],
          recipes: [
            {
              id: 'kalo-dal',
              titleEn: 'Kathmandu Kalo Dal',
              titleNe: 'कालो दाल (झारेको)',
              category: 'dal',
              cuisine: 'Newari/Nepali',
              dietary: ['vegetarian', 'gluten-free'],
              prepTimeMinutes: 10,
              cookTimeMinutes: 25,
              servings: 4,
              difficulty: 'easy',
              pressureCooker: {
                enabled: true,
                recommendedWhistles: 4,
                altitudeWhistleOffsetKathmandu: 1,
                heatLevel: 'medium',
                releaseType: 'natural'
              },
              ingredients: [{ ingredientId: 'kalo_dal', quantity: 200, unit: 'g' }],
              seasonality: ['sharad', 'hemanta'],
              tags: ['dal', 'comfort']
            }
          ],
          festivals: [
            {
              id: 'dashain',
              nameEn: 'Dashain',
              nameNe: 'बडा दसैँ',
              tithi: 'Ashwin Shukla Pratipada to Purnima',
              approxGregorianMonth: 'October',
              descriptionEn: 'The biggest festival of Nepal celebrating victory of good over evil.',
              descriptionNe: 'असत्यमाथि सत्यको विजयको प्रतीक महान् पर्व।',
              keyDishes: ['kalo-dal']
            }
          ]
        }

      case 'australia-nsw':
        return {
          manifest: {
            id: 'australia-nsw',
            version: '1.0.0',
            name: 'Australia (New South Wales / Sydney)',
            country: 'Australia',
            countryCode: 'AU',
            region: 'New South Wales',
            status: 'verified',
            elevationMeters: 50,
            defaultLanguage: 'en',
            calendar: 'gregorian',
            seasonSystem: 'four-seasons-southern',
            currencyCode: 'AUD',
            currencySymbol: '$',
            marketUnits: ['kg', 'g', 'cup', 'bunch', 'punnet']
          },
          seasonality: {
            regionId: 'australia-nsw',
            ritus: [
              {
                id: 'spring',
                name: 'Spring',
                monthsBS: [],
                monthsGregorian: ['September', 'October', 'November'],
                signatureProduce: ['asparagus', 'spinach', 'peas', 'strawberries']
              },
              {
                id: 'summer',
                name: 'Summer',
                monthsBS: [],
                monthsGregorian: ['December', 'January', 'February'],
                signatureProduce: ['tomatoes', 'zucchini', 'stone_fruit']
              }
            ]
          },
          ingredients: [
            {
              id: 'asparagus',
              nameEn: 'Fresh Asparagus',
              nameNe: 'कुरिलो (Asparagus)',
              aliases: ['spears'],
              category: 'vegetables',
              standardUnit: 'bunch',
              marketPackageGrams: 250,
              storageDays: 4,
              allergens: [],
              availability: { spring: 'peak', summer: 'available' }
            },
            {
              id: 'salmon',
              nameEn: 'Atlantic Salmon Fillet',
              nameNe: 'साल्मन माछा',
              aliases: ['salmon'],
              category: 'meat',
              standardUnit: 'g',
              marketPackageGrams: 400,
              storageDays: 2,
              allergens: ['fish'],
              availability: { spring: 'available', summer: 'available' }
            }
          ],
          recipes: [
            {
              id: 'sydney-spring-salmon',
              titleEn: 'Pan-seared Salmon with Spring Asparagus',
              titleNe: 'साल्मन माछा र कुरिलो (Spring Special)',
              category: 'tarkari',
              cuisine: 'Modern Australian',
              dietary: ['gluten-free'],
              prepTimeMinutes: 10,
              cookTimeMinutes: 15,
              servings: 2,
              difficulty: 'easy',
              pressureCooker: {
                enabled: false,
                recommendedWhistles: 0,
                altitudeWhistleOffsetKathmandu: 0,
                heatLevel: 'medium',
                releaseType: 'quick'
              },
              ingredients: [
                { ingredientId: 'salmon', quantity: 350, unit: 'g' },
                { ingredientId: 'asparagus', quantity: 200, unit: 'g' }
              ],
              seasonality: ['spring'],
              tags: ['high-protein', 'spring', 'quick']
            }
          ],
          festivals: []
        }

      case 'bolivia-lapaz':
        return {
          manifest: {
            id: 'bolivia-lapaz',
            version: '1.0.0',
            name: 'Bolivia (La Paz & Altiplano)',
            country: 'Bolivia',
            countryCode: 'BO',
            region: 'La Paz',
            status: 'community',
            elevationMeters: 3600,
            defaultLanguage: 'es',
            calendar: 'gregorian',
            seasonSystem: 'four-seasons-southern',
            currencyCode: 'BOB',
            currencySymbol: 'Bs',
            marketUnits: ['kg', 'g', 'libra', 'arroba']
          },
          seasonality: {
            regionId: 'bolivia-lapaz',
            ritus: [
              {
                id: 'spring',
                name: 'Primavera (Spring)',
                monthsBS: [],
                monthsGregorian: ['September', 'October', 'November'],
                signatureProduce: ['quinoa', 'potato']
              }
            ]
          },
          ingredients: [
            {
              id: 'quinoa',
              nameEn: 'Royal White Quinoa',
              nameNe: 'किनोवा',
              aliases: ['quinua real'],
              category: 'grains',
              standardUnit: 'kg',
              marketPackageGrams: 500,
              storageDays: 365,
              allergens: [],
              availability: { spring: 'peak' }
            }
          ],
          recipes: [
            {
              id: 'pesque-de-quinua',
              titleEn: 'Pesque de Quinua (High Altitude Stew)',
              titleNe: 'पेस्के दे किनोवा (उच्च उचाइको खाना)',
              category: 'khaja',
              cuisine: 'Andean',
              dietary: ['vegetarian', 'gluten-free'],
              prepTimeMinutes: 10,
              cookTimeMinutes: 30,
              servings: 4,
              difficulty: 'medium',
              pressureCooker: {
                enabled: true,
                recommendedWhistles: 4,
                altitudeWhistleOffsetKathmandu: 0,
                heatLevel: 'medium',
                releaseType: 'natural'
              },
              ingredients: [{ ingredientId: 'quinoa', quantity: 250, unit: 'g' }],
              seasonality: ['spring'],
              tags: ['high-altitude', 'superfood']
            }
          ],
          festivals: []
        }

      default:
        return undefined
    }
  }
}
