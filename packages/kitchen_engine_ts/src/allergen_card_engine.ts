/**
 * Advanced Allergy Protection Engine:
 * 1. Offline bilingual emergency allergy chef/travel cards (Nepali, English, etc.)
 * 2. Evidence-based baby & toddler allergen introduction tracker & pediatric safety rules.
 */

import { AllergenCatalog } from './allergen_engine.js'

export interface EmergencyContact {
  name: string
  relationship: string
  phone: string
  secondaryPhone?: string
}

export class EmergencyAllergyCard {
  readonly memberName: string
  readonly memberAge?: number
  readonly severeAllergens: string[]
  readonly moderateAllergens: string[]
  readonly emergencyContacts: EmergencyContact[]
  readonly medicalNotes?: string
  readonly carriesEpiPen: boolean
  readonly doctorName?: string
  readonly doctorPhone?: string

  constructor(options: {
    memberName: string
    memberAge?: number
    severeAllergens: string[]
    moderateAllergens?: string[]
    emergencyContacts: EmergencyContact[]
    medicalNotes?: string
    carriesEpiPen?: boolean
    doctorName?: string
    doctorPhone?: string
  }) {
    this.memberName = options.memberName
    this.memberAge = options.memberAge
    this.severeAllergens = options.severeAllergens
    this.moderateAllergens = options.moderateAllergens ?? []
    this.emergencyContacts = options.emergencyContacts
    this.medicalNotes = options.medicalNotes
    this.carriesEpiPen = options.carriesEpiPen ?? false
    this.doctorName = options.doctorName
    this.doctorPhone = options.doctorPhone
  }

  static allergenNameEn(allergenKey: string): string {
    switch (allergenKey.toLowerCase()) {
      case AllergenCatalog.peanuts:
        return 'Peanuts'
      case AllergenCatalog.nuts:
        return 'Tree Nuts (Walnuts, Almonds, Cashews, Pistachios)'
      case AllergenCatalog.milk:
        return 'Dairy / Cow\'s Milk'
      case AllergenCatalog.eggs:
        return 'Eggs'
      case AllergenCatalog.fish:
        return 'Fish'
      case AllergenCatalog.crustaceans:
        return 'Crustaceans (Shrimp, Prawns, Crab, Lobster)'
      case AllergenCatalog.molluscs:
        return 'Molluscs (Clams, Mussels, Oysters, Squid)'
      case AllergenCatalog.gluten:
        return 'Gluten / Wheat / Barley / Rye'
      case AllergenCatalog.soy:
        return 'Soy / Soya Beans'
      case AllergenCatalog.sesame:
        return 'Sesame Seeds / Sesame Oil'
      case AllergenCatalog.mustard:
        return 'Mustard Seeds / Powder'
      case AllergenCatalog.mustardOil:
        return 'Mustard Oil (तोरीको तेल)'
      case AllergenCatalog.buckwheat:
        return 'Buckwheat (फापर)'
      case AllergenCatalog.fenugreek:
        return 'Fenugreek (मेथी)'
      case AllergenCatalog.celery:
        return 'Celery'
      case AllergenCatalog.lupin:
        return 'Lupin'
      case AllergenCatalog.sulphites:
        return 'Sulphites'
      default:
        return allergenKey
    }
  }

  static allergenNameNe(allergenKey: string): string {
    switch (allergenKey.toLowerCase()) {
      case AllergenCatalog.peanuts:
        return 'बदाम / मूंगफली (Peanuts)'
      case AllergenCatalog.nuts:
        return 'ओखर, काजु, बदाम, पिस्ता (Tree Nuts)'
      case AllergenCatalog.milk:
        return 'दूध, दही, घिउ, पनिर (Dairy / Milk products)'
      case AllergenCatalog.eggs:
        return 'अण्डा (Eggs)'
      case AllergenCatalog.fish:
        return 'माछा (Fish)'
      case AllergenCatalog.crustaceans:
        return 'झिँगे माछा, गँगटो (Shrimp, Crab)'
      case AllergenCatalog.molluscs:
        return 'घोङ्गी, शङ्खेकिरा (Molluscs)'
      case AllergenCatalog.gluten:
        return 'गहुँ, मैदा, जौ, ग्लुटेन (Wheat, Gluten)'
      case AllergenCatalog.soy:
        return 'भटमास, सोया सस, टोफु (Soy, Tofu)'
      case AllergenCatalog.sesame:
        return 'तिल, तिलको तेल (Sesame)'
      case AllergenCatalog.mustard:
        return 'सर्स्युँ, तोरी (Mustard)'
      case AllergenCatalog.mustardOil:
        return 'तोरीको तेल (Mustard Oil)'
      case AllergenCatalog.buckwheat:
        return 'फापर (Buckwheat)'
      case AllergenCatalog.fenugreek:
        return 'मेथी (Fenugreek)'
      case AllergenCatalog.celery:
        return 'सेलरी (Celery)'
      case AllergenCatalog.lupin:
        return 'लुपिन (Lupin)'
      case AllergenCatalog.sulphites:
        return 'सल्फाइट (Sulphites)'
      default:
        return allergenKey
    }
  }

  get hiddenSourceWarningsEn(): string[] {
    const warnings: string[] = []
    for (const a of this.severeAllergens) {
      switch (a.toLowerCase()) {
        case AllergenCatalog.milk:
          warnings.push('Dairy: Also avoid butter, ghee, milk powder, paneer, whey, and cheese.')
          break
        case AllergenCatalog.peanuts:
          warnings.push('Peanut: Also avoid peanut oil, groundnut paste, and cross-reactive fenugreek (methi).')
          break
        case AllergenCatalog.nuts:
          warnings.push('Tree Nuts: Watch out for nut pastes, pesto, sweets (halwa, barfi), and marzipan.')
          break
        case AllergenCatalog.gluten:
          warnings.push('Gluten: Watch out for maida, semolina (suji), soy sauce with wheat, and hing diluted with wheat.')
          break
        case AllergenCatalog.mustard:
        case AllergenCatalog.mustardOil:
          warnings.push('Mustard: Watch out for mixed vegetable oils, pickles (achar), and spice blends.')
          break
        case AllergenCatalog.sesame:
          warnings.push('Sesame: Watch out for sesame oil, tahini, til ko chukauni, and achar tempering.')
          break
      }
    }
    return warnings
  }

  get hiddenSourceWarningsNe(): string[] {
    const warnings: string[] = []
    for (const a of this.severeAllergens) {
      switch (a.toLowerCase()) {
        case AllergenCatalog.milk:
          warnings.push('दूधजन्य: घिउ, नौनी, खुवा, पनिर, बटर, दूधको धुलो र चीजबाट पनि पूर्ण टाढा राख्नुहोस्।')
          break
        case AllergenCatalog.peanuts:
          warnings.push('बदाम: बदामको तेल, पेष्ट र यससँग मिल्दोजुल्दो मेथी (Fenugreek) बाट पनि जोगिनुहोस्।')
          break
        case AllergenCatalog.nuts:
          warnings.push('ओखर/काजु: मिठाई (बर्फी, हलुवा), पेस्ट र ग्रेभीमा प्रयोग हुने काजुको पेस्टबाट जोगिनुहोस्।')
          break
        case AllergenCatalog.gluten:
          warnings.push('ग्लुटेन: मैदा, सुजी, गहुँको पिठो, र मैदा मिसाइएको हिंगबाट पूर्ण परहेज गर्नुहोस्।')
          break
        case AllergenCatalog.mustard:
        case AllergenCatalog.mustardOil:
          warnings.push('तोरी: तोरीको तेल, अचार, झान्न प्रयोग गरिने सर्स्युँ र मिश्रित खानेतेलबाट जोगिनुहोस्।')
          break
        case AllergenCatalog.sesame:
          warnings.push('तिल: तिलको तेल, चुकाउनी, छोप र अचारमा हालिएको तिलबाट परहेज गर्नुहोस्।')
          break
      }
    }
    return warnings
  }

  generateMarkdownCard(): string {
    const lines: string[] = []
    lines.push('# 🚨 EMERGENCY ALLERGY CARD / आकस्मिक एलर्जी कार्ड')
    lines.push(`**Name / नाम:** ${this.memberName}${this.memberAge != null ? ` (Age: ${this.memberAge})` : ''}`)
    lines.push('')
    lines.push('## 🛑 SEVERE LIFE-THREATENING ALLERGIES / गम्भीर एलर्जीहरू')
    lines.push('> **ATTENTION CHEF / SERVER / RESTAURANT:**')
    lines.push('> I have severe, life-threatening food allergies. Please ensure that my food, cooking surfaces, pans, utensils, and oil DO NOT come into contact with:')
    for (const a of this.severeAllergens) {
      lines.push(`> • **${EmergencyAllergyCard.allergenNameEn(a)}** (${EmergencyAllergyCard.allergenNameNe(a)})`)
    }
    lines.push('> Even trace cross-contact can cause severe anaphylactic shock. Thank you for your care.')
    lines.push('')
    lines.push('> **शेफ / भान्से / वेटरको ध्यानाकर्षण:**')
    lines.push('> मलाई यी खाद्य पदार्थहरूबाट ज्यान जोखिममा पर्न सक्ने गम्भीर एलर्जी छ। कृपया मेरो खाना, भाँडाकुँडा, डाडु, पन्यु, चुलो र तेल यी परिकारहरूसँग पटक्कै नछुन दिनुहोला:')
    for (const a of this.severeAllergens) {
      lines.push(`> • **${EmergencyAllergyCard.allergenNameNe(a)}**`)
    }
    lines.push('> अलिकति मात्र सम्पर्क वा लसपस भए पनि गम्भीर खतरा हुन सक्छ। सहयोगको लागि धन्यवाद।')
    lines.push('')

    if (this.moderateAllergens.length > 0) {
      lines.push('### ⚠️ Moderate Allergies / अन्य एलर्जीहरू:')
      for (const a of this.moderateAllergens) {
        lines.push(`- ${EmergencyAllergyCard.allergenNameEn(a)} / ${EmergencyAllergyCard.allergenNameNe(a)}`)
      }
      lines.push('')
    }

    const hiddenEn = this.hiddenSourceWarningsEn
    if (hiddenEn.length > 0) {
      lines.push('### 🔍 Hidden Ingredients & Cross-Contact / लुकेका सामग्रीहरू:')
      for (const h of hiddenEn) {
        lines.push(`- ${h}`)
      }
      lines.push('')
    }

    if (this.carriesEpiPen) {
      lines.push('### 💉 EMERGENCY MEDICAL ACTION / आकस्मिक उपचार:')
      lines.push('**THIS PERSON CARRIES AN EPINEPHRINE AUTO-INJECTOR (EpiPen).**')
      lines.push('In case of breathing difficulty, swelling, or allergic collapse:')
      lines.push('1. Administer Epinephrine auto-injector into outer mid-thigh immediately.')
      lines.push('2. Call Emergency Ambulance immediately (Nepal: 102, Intl: 911 / 112).')
      lines.push('3. Keep person lying down with legs elevated.')
      lines.push('')
    }

    if (this.emergencyContacts.length > 0) {
      lines.push('### 📞 EMERGENCY CONTACTS / आकस्मिक सम्पर्क:')
      for (const c of this.emergencyContacts) {
        lines.push(`• **${c.name}** (${c.relationship}): [${c.phone}](tel:${c.phone})${c.secondaryPhone ? ` / ${c.secondaryPhone}` : ''}`)
      }
      lines.push('')
    }

    if (this.doctorName) {
      lines.push(`**Physician / चिकित्सक:** ${this.doctorName}${this.doctorPhone ? ` (${this.doctorPhone})` : ''}`)
    }

    return lines.join('\n')
  }
}

export type ReactionSeverity = 'none' | 'mild' | 'moderate' | 'severe'
export type InfantIntroductionStatus = 'notIntroduced' | 'introducing' | 'toleratedSafely' | 'adverseReaction'

export interface InfantAllergenLog {
  id: string
  memberId: string
  allergen: string
  foodDescription: string
  exposureDate: string
  portionGrams: number
  portionUnitLabel?: string
  dayOfProtocol?: number
  reactionSeverity: ReactionSeverity
  reactionSymptoms?: string
  notes?: string
}

export interface InfantAllergenSummary {
  allergen: string
  status: InfantIntroductionStatus
  totalExposures: number
  firstExposed?: string
  lastExposed?: string
  worstReaction: ReactionSeverity
  logs: InfantAllergenLog[]
}

export class InfantAllergenEngine {
  static readonly pediatricDisclaimerEn =
    'PEDIATRIC DISCLAIMER: This tracker provides educational guidelines based on clinical pediatric protocols. ' +
    'Always consult your pediatrician or pediatric allergist before starting early allergen introduction, ' +
    'especially if your infant has severe eczema or existing egg allergy. Never feed whole nuts or thick paste (choking hazard). ' +
    'If your child develops facial swelling, wheezing, vomiting, or breathing difficulty, seek immediate emergency medical care.'

  static readonly pediatricDisclaimerNe =
    'बालरोग विशेषज्ञ सल्लाह: यो ट्र्याकर चिकित्सकीय बालरोग निर्देशिकामा आधारित शैक्षिक जानकारी मात्र हो। ' +
    'बच्चालाई नयाँ खाना वा एलर्जी हुने तत्व खुवाउनु अघि बालरोग विशेषज्ञ (Pediatrician) सँग परामर्श लिनुहोस्, ' +
    'विशेष गरी बच्चालाई कडा दाद (Eczema) वा छालाको समस्या छ भने। सिंगो दाना वा बाक्लो पेस्ट कहिल्यै नखुवाउनुहोस् (घाँटीमा अड्किने जोखिम)। ' +
    'यदि बच्चाको अनुहार सुन्निने, सास फेर्न गाह्रो हुने वा बान्ता हुने भएमा तुरुन्त आकस्मिक अस्पताल लैजानुहोस्।'

  static readonly priorityBabyAllergens: string[] = [
    AllergenCatalog.peanuts,
    AllergenCatalog.eggs,
    AllergenCatalog.milk,
    AllergenCatalog.sesame,
    AllergenCatalog.fish,
    AllergenCatalog.gluten,
    AllergenCatalog.soy,
    AllergenCatalog.nuts,
  ]

  static getChokingSafetyGuidanceEn(allergenKey: string): string {
    switch (allergenKey.toLowerCase()) {
      case AllergenCatalog.peanuts:
      case AllergenCatalog.nuts:
        return 'CHOKING HAZARD: Never feed whole nuts or thick sticky nut butter to infants. ' +
          'Thin smooth peanut/nut butter with warm water, breastmilk, or fruit puree until loose and runny.'
      case AllergenCatalog.eggs:
        return 'Ensure egg is thoroughly cooked. Mash hard-boiled egg yolk or soft scrambled egg thoroughly into a smooth puree.'
      case AllergenCatalog.fish:
        return 'Thoroughly check for and remove all tiny bones. Puree or flake cooked white fish into fine pieces.'
      default:
        return 'Offer small age-appropriate soft textures. Always supervise baby closely during eating.'
    }
  }

  static getChokingSafetyGuidanceNe(allergenKey: string): string {
    switch (allergenKey.toLowerCase()) {
      case AllergenCatalog.peanuts:
      case AllergenCatalog.nuts:
        return 'घाँटीमा अड्किने चेतावनी: शिशुलाई सिंगो बदाम वा काजु कहिल्यै नदिनुहोस्। ' +
          'बदामको पेस्टलाई तातो पानी, आमाको दूध वा फलफूलको प्युरीमा मिसाएर पातलो र नरम बनाएर मात्र चटाउनुहोस्।'
      case AllergenCatalog.eggs:
        return 'अण्डा राम्ररी पाकेको हुनुपर्छ। उसिनेको अण्डाको पहेंलो भागलाई आमाको दूध वा तरकारीको रसमा राम्ररी मिचेर नरम बनाउनुहोस्।'
      case AllergenCatalog.fish:
        return 'माछाको काँडा राम्ररी छानेर हटाउनुहोस्। काँडा नभएको उसिनेको माछालाई मसिनो गरी मुछेर मात्र दिनुहोस्।'
      default:
        return 'बच्चाको उमेर अनुसार नरम र पातलो बनाएर मात्र खुवाउनुहोस्। खुवाउँदा सधैं बच्चासँगै बस्नुहोस्।'
    }
  }

  static canIntroduceNewAllergen(params: {
    recentLogs: InfantAllergenLog[]
    newAllergen: string
    candidateDate: Date
  }): boolean {
    const { recentLogs, newAllergen, candidateDate } = params
    if (recentLogs.length === 0) return true

    for (const log of recentLogs) {
      if (log.allergen !== newAllergen) {
        const logDate = new Date(log.exposureDate)
        const diffDays = Math.abs((candidateDate.getTime() - logDate.getTime()) / (1000 * 60 * 60 * 24))
        if (diffDays < 3 && log.reactionSeverity !== 'none') {
          return false
        }
      }
    }
    return true
  }

  static aggregateSummaries(params: {
    logs: InfantAllergenLog[]
    targetAllergens?: string[]
  }): Record<string, InfantAllergenSummary> {
    const allergens = params.targetAllergens ?? this.priorityBabyAllergens
    const map: Record<string, InfantAllergenSummary> = {}

    const severityRank: Record<ReactionSeverity, number> = {
      none: 0,
      mild: 1,
      moderate: 2,
      severe: 3,
    }

    for (const allergen of allergens) {
      const matching = params.logs
        .filter((l) => l.allergen === allergen)
        .sort((a, b) => new Date(a.exposureDate).getTime() - new Date(b.exposureDate).getTime())

      if (matching.length === 0) {
        map[allergen] = {
          allergen,
          status: 'notIntroduced',
          totalExposures: 0,
          worstReaction: 'none',
          logs: [],
        }
      } else {
        const hasAdverse = matching.some((l) => l.reactionSeverity !== 'none')
        let worst: ReactionSeverity = 'none'
        for (const l of matching) {
          if (severityRank[l.reactionSeverity] > severityRank[worst]) {
            worst = l.reactionSeverity
          }
        }

        let status: InfantIntroductionStatus
        if (hasAdverse) {
          status = 'adverseReaction'
        } else if (matching.length >= 3) {
          status = 'toleratedSafely'
        } else {
          status = 'introducing'
        }

        map[allergen] = {
          allergen,
          status,
          totalExposures: matching.length,
          firstExposed: matching[0].exposureDate,
          lastExposed: matching[matching.length - 1].exposureDate,
          worstReaction: worst,
          logs: matching,
        }
      }
    }

    return map
  }
}
