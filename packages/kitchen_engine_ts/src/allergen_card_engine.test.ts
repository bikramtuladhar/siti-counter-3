import { describe, it } from 'node:test'
import assert from 'node:assert'
import {
  EmergencyAllergyCard,
  InfantAllergenEngine,
  InfantAllergenLog
} from './allergen_card_engine.js'
import { AllergenCatalog } from './allergen_engine.js'

describe('AllergenCardEngine TypeScript Parity Tests', () => {
  it('generates comprehensive bilingual allergy card with emergency contacts and EpiPen advice', () => {
    const card = new EmergencyAllergyCard({
      memberName: 'Aarav Sharma',
      memberAge: 6,
      severeAllergens: [
        AllergenCatalog.peanuts,
        AllergenCatalog.milk,
        AllergenCatalog.mustardOil
      ],
      moderateAllergens: [
        AllergenCatalog.sesame
      ],
      carriesEpiPen: true,
      emergencyContacts: [
        {
          name: 'Pooja Sharma',
          relationship: 'Mother',
          phone: '+977-9801234567',
          secondaryPhone: '+977-9851000000'
        },
        {
          name: 'Bikram Sharma',
          relationship: 'Father',
          phone: '+977-9841234567'
        }
      ],
      doctorName: 'Dr. Ramesh Thapa',
      doctorPhone: '+977-1-4412345'
    })

    assert.strictEqual(EmergencyAllergyCard.allergenNameEn(AllergenCatalog.peanuts), 'Peanuts')
    assert.ok(EmergencyAllergyCard.allergenNameNe(AllergenCatalog.peanuts).includes('बदाम'))
    assert.ok(EmergencyAllergyCard.allergenNameNe(AllergenCatalog.milk).includes('दूध'))
    assert.ok(EmergencyAllergyCard.allergenNameNe(AllergenCatalog.mustardOil).includes('तोरीको तेल'))

    const hiddenEn = card.hiddenSourceWarningsEn
    assert.ok(hiddenEn.some((w) => w.includes('ghee') || w.includes('paneer')))
    assert.ok(hiddenEn.some((w) => w.includes('fenugreek') || w.includes('methi')))

    const hiddenNe = card.hiddenSourceWarningsNe
    assert.ok(hiddenNe.some((w) => w.includes('घिउ') || w.includes('पनिर')))

    const md = card.generateMarkdownCard()
    assert.ok(md.includes('Aarav Sharma'))
    assert.ok(md.includes('ATTENTION CHEF'))
    assert.ok(md.includes('शेफ / भान्से / वेटरको ध्यानाकर्षण'))
    assert.ok(md.includes('EPINEPHRINE AUTO-INJECTOR'))
    assert.ok(md.includes('+977-9801234567'))
    assert.ok(md.includes('Dr. Ramesh Thapa'))
  })

  it('contains mandatory pediatric disclaimers and choking hazard warnings', () => {
    assert.ok(InfantAllergenEngine.pediatricDisclaimerEn.includes('PEDIATRIC DISCLAIMER'))
    assert.ok(InfantAllergenEngine.pediatricDisclaimerNe.includes('बालरोग विशेषज्ञ'))

    const peanutChokingEn = InfantAllergenEngine.getChokingSafetyGuidanceEn(AllergenCatalog.peanuts)
    assert.ok(peanutChokingEn.includes('Never feed whole nuts'))
    assert.ok(peanutChokingEn.includes('Thin smooth peanut/nut butter'))

    const peanutChokingNe = InfantAllergenEngine.getChokingSafetyGuidanceNe(AllergenCatalog.peanuts)
    assert.ok(peanutChokingNe.includes('सिंगो बदाम वा काजु कहिल्यै नदिनुहोस्'))
    assert.ok(peanutChokingNe.includes('पातलो र नरम'))

    const eggChokingEn = InfantAllergenEngine.getChokingSafetyGuidanceEn(AllergenCatalog.eggs)
    assert.ok(eggChokingEn.includes('thoroughly cooked'))

    const fishChokingEn = InfantAllergenEngine.getChokingSafetyGuidanceEn(AllergenCatalog.fish)
    assert.ok(fishChokingEn.includes('remove all tiny bones'))
  })

  it('enforces spacing protocol and reaction safety gate', () => {
    const now = new Date('2026-10-04T10:00:00Z')
    const yesterday = new Date('2026-10-03T10:00:00Z')

    const logsWithAdverse: InfantAllergenLog[] = [
      {
        id: 'log-1',
        memberId: 'baby-maya',
        allergen: AllergenCatalog.eggs,
        foodDescription: 'Mashed egg yolk',
        exposureDate: yesterday.toISOString(),
        portionGrams: 2.0,
        reactionSeverity: 'mild',
        reactionSymptoms: 'Red hives around mouth'
      }
    ]

    const canIntroduce = InfantAllergenEngine.canIntroduceNewAllergen({
      recentLogs: logsWithAdverse,
      newAllergen: AllergenCatalog.peanuts,
      candidateDate: now
    })
    assert.strictEqual(canIntroduce, false)

    const fourDaysAgo = new Date('2026-09-30T10:00:00Z')
    const safeLogs: InfantAllergenLog[] = [
      {
        id: 'log-2',
        memberId: 'baby-maya',
        allergen: AllergenCatalog.peanuts,
        foodDescription: 'Thinned peanut butter in puree',
        exposureDate: fourDaysAgo.toISOString(),
        portionGrams: 2.5,
        reactionSeverity: 'none'
      }
    ]

    const canIntroduceAfterWait = InfantAllergenEngine.canIntroduceNewAllergen({
      recentLogs: safeLogs,
      newAllergen: AllergenCatalog.sesame,
      candidateDate: now
    })
    assert.strictEqual(canIntroduceAfterWait, true)
  })

  it('aggregates exposure logs into accurate clinical introduction summaries', () => {
    const logs: InfantAllergenLog[] = [
      {
        id: 'p-1',
        memberId: 'baby-1',
        allergen: AllergenCatalog.peanuts,
        foodDescription: 'Thinned peanut butter 1/4 tsp',
        exposureDate: '2026-09-27T10:00:00Z',
        portionGrams: 1.2,
        dayOfProtocol: 1,
        reactionSeverity: 'none'
      },
      {
        id: 'p-2',
        memberId: 'baby-1',
        allergen: AllergenCatalog.peanuts,
        foodDescription: 'Thinned peanut butter 1/2 tsp',
        exposureDate: '2026-09-29T10:00:00Z',
        portionGrams: 2.5,
        dayOfProtocol: 2,
        reactionSeverity: 'none'
      },
      {
        id: 'p-3',
        memberId: 'baby-1',
        allergen: AllergenCatalog.peanuts,
        foodDescription: 'Thinned peanut butter 1 tsp',
        exposureDate: '2026-10-02T10:00:00Z',
        portionGrams: 5.0,
        dayOfProtocol: 3,
        reactionSeverity: 'none'
      },
      {
        id: 'e-1',
        memberId: 'baby-1',
        allergen: AllergenCatalog.eggs,
        foodDescription: 'Hard boiled egg yolk puree',
        exposureDate: '2026-10-03T10:00:00Z',
        portionGrams: 2.0,
        dayOfProtocol: 1,
        reactionSeverity: 'mild',
        reactionSymptoms: 'Flushed cheeks and mild rash'
      }
    ]

    const summaries = InfantAllergenEngine.aggregateSummaries({ logs })

    assert.strictEqual(summaries[AllergenCatalog.peanuts].status, 'toleratedSafely')
    assert.strictEqual(summaries[AllergenCatalog.peanuts].totalExposures, 3)
    assert.strictEqual(summaries[AllergenCatalog.peanuts].worstReaction, 'none')

    assert.strictEqual(summaries[AllergenCatalog.eggs].status, 'adverseReaction')
    assert.strictEqual(summaries[AllergenCatalog.eggs].totalExposures, 1)
    assert.strictEqual(summaries[AllergenCatalog.eggs].worstReaction, 'mild')

    assert.strictEqual(summaries[AllergenCatalog.sesame].status, 'notIntroduced')
    assert.strictEqual(summaries[AllergenCatalog.sesame].totalExposures, 0)
  })
})
