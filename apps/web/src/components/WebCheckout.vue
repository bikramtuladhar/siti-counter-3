<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import {
  PppPricingResolver,
  PREMIUM_FEATURES
} from '@siti-counter/kitchen-engine'

const props = defineProps<{
  householdId: string
  language?: 'ne' | 'en'
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'subscription-updated', entitlement: Record<string, unknown>): void
}>()

type ActiveTab = 'subscribe' | 'gift' | 'redeem'
type PaymentProvider = 'khalti' | 'esewa' | 'stripe'

const activeTab = ref<ActiveTab>('subscribe')
const selectedCountry = ref<string>('NP')
const selectedProvider = ref<PaymentProvider>('khalti')

// Gifting form state
const giftRecipientName = ref('')
const giftRecipientEmail = ref('')
const giftPurchaserEmail = ref('')
const giftMessage = ref('')
const generatedGiftCode = ref<string | null>(null)

// Redemption form state
const redemptionCodeInput = ref('')
const redemptionStatus = ref<{
  success?: boolean
  error?: string
  purchaserEmail?: string
  giftMessage?: string
} | null>(null)

// Current entitlement state
const currentEntitlement = ref<Record<string, unknown> | null>(null)
const isSubmitting = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const isNepali = computed(() => (props.language ?? 'ne') === 'ne')

const pricing = computed(() => {
  return PppPricingResolver.resolvePrice(selectedCountry.value)
})

const supportedProviders = computed<PaymentProvider[]>(() => {
  if (selectedCountry.value === 'NP') {
    return ['khalti', 'esewa', 'stripe']
  }
  return ['stripe']
})

const isAlreadySubscribed = computed(() => {
  return currentEntitlement.value?.tier === 'householdAnnual'
})

onMounted(async () => {
  // Check if gift code is present in query parameters (e.g. ?gift=GIFT-SITI-...)
  try {
    const urlParams = new URLSearchParams(window.location.search)
    const giftParam = urlParams.get('gift')
    if (giftParam) {
      activeTab.value = 'redeem'
      redemptionCodeInput.value = giftParam.toUpperCase()
    }
  } catch (_) {}

  // Fetch current entitlement
  await checkEntitlements()
})

async function checkEntitlements() {
  try {
    const res = await fetch(`/v1/entitlements/${props.householdId}`)
    if (res.ok) {
      const data = await res.json()
      currentEntitlement.value = data
    }
  } catch (_) {
    // Local / offline fallback
    const cached = localStorage.getItem(`siti_entitlement_${props.householdId}`)
    if (cached) {
      try {
        currentEntitlement.value = JSON.parse(cached)
      } catch (_) {}
    }
  }
}

async function handleCheckout() {
  isSubmitting.value = true
  errorMessage.value = null
  successMessage.value = null

  try {
    if (activeTab.value === 'gift') {
      await processGiftCheckout()
    } else {
      await processDirectCheckout()
    }
  } catch (err: any) {
    errorMessage.value = err?.message || (isNepali.value ? 'भुक्तानी प्रक्रियामा त्रुटि भयो।' : 'Checkout error occurred.')
  } finally {
    isSubmitting.value = false
  }
}

async function processDirectCheckout() {
  if (selectedProvider.value === 'khalti') {
    const initRes = await fetch('/v1/checkout/khalti/initiate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId: props.householdId,
        amount: pricing.value.amount,
        returnUrl: window.location.href
      })
    })
    const initData = await initRes.json()
    if (!initRes.ok) throw new Error(initData.message || 'Khalti initiate failed')

    // Simulate verification completion
    const verifyRes = await fetch('/v1/checkout/khalti/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        pidx: initData.pidx,
        transactionId: `kht_web_${Date.now()}`
      })
    })
    const verifyData = await verifyRes.json()
    if (!verifyRes.ok) throw new Error(verifyData.message || 'Verification failed')

    handleSuccessfulEntitlement(verifyData.entitlementToken)
  } else if (selectedProvider.value === 'esewa') {
    const initRes = await fetch('/v1/checkout/esewa/initiate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId: props.householdId,
        amount: pricing.value.amount
      })
    })
    const initData = await initRes.json()
    if (!initRes.ok) throw new Error(initData.message || 'eSewa initiate failed')

    const verifyRes = await fetch('/v1/checkout/esewa/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        transaction_uuid: initData.transactionUuid,
        transaction_code: `esw_web_${Date.now()}`,
        total_amount: pricing.value.amount
      })
    })
    const verifyData = await verifyRes.json()
    if (!verifyRes.ok) throw new Error(verifyData.message || 'eSewa verification failed')

    handleSuccessfulEntitlement(verifyData.entitlementToken)
  } else {
    // Stripe
    const sessionRes = await fetch('/v1/checkout/stripe/create-session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        householdId: props.householdId,
        country: selectedCountry.value,
        currency: pricing.value.currencyCode
      })
    })
    const sessionData = await sessionRes.json()
    if (!sessionRes.ok) throw new Error(sessionData.message || 'Stripe session creation failed')

    const verifyRes = await fetch('/v1/checkout/stripe/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        sessionId: sessionData.sessionId
      })
    })
    const verifyData = await verifyRes.json()
    if (!verifyRes.ok) throw new Error(verifyData.message || 'Stripe verification failed')

    handleSuccessfulEntitlement(verifyData.entitlementToken)
  }
}

async function processGiftCheckout() {
  if (!giftPurchaserEmail.value) {
    throw new Error(isNepali.value ? 'कृपया तपाईंको इमेल ठेगाना लेख्नुहोस्।' : 'Please enter your email address.')
  }

  const endpoint = selectedProvider.value === 'stripe'
    ? '/v1/checkout/stripe/create-session'
    : selectedProvider.value === 'khalti'
    ? '/v1/checkout/khalti/initiate'
    : '/v1/checkout/esewa/initiate'

  const bodyPayload = {
    isGift: true,
    amount: pricing.value.amount,
    currency: pricing.value.currencyCode,
    country: selectedCountry.value,
    purchaserEmail: giftPurchaserEmail.value,
    recipientEmail: giftRecipientEmail.value,
    recipientName: giftRecipientName.value,
    giftMessage: giftMessage.value
  }

  const initRes = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(bodyPayload)
  })
  const initData = await initRes.json()
  if (!initRes.ok) throw new Error(initData.message || 'Gift initiation failed')

  // Verify
  const verifyEndpoint = selectedProvider.value === 'stripe'
    ? '/v1/checkout/stripe/verify'
    : selectedProvider.value === 'khalti'
    ? '/v1/checkout/khalti/verify'
    : '/v1/checkout/esewa/verify'

  const verifyBody = selectedProvider.value === 'stripe'
    ? { sessionId: initData.sessionId }
    : selectedProvider.value === 'khalti'
    ? { pidx: initData.pidx }
    : { transaction_uuid: initData.transactionUuid, total_amount: pricing.value.amount }

  const verifyRes = await fetch(verifyEndpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(verifyBody)
  })
  const verifyData = await verifyRes.json()
  if (!verifyRes.ok) throw new Error(verifyData.message || 'Gift verification failed')

  generatedGiftCode.value = verifyData.giftCode
  successMessage.value = isNepali.value
    ? 'उपहार खरिद सफल भयो! तल दिइएको उपहार कोड आफ्नो परिवारलाई पठाउनुहोस्।'
    : 'Gift purchase complete! Share the gift code below with your family in Nepal.'
}

async function handleRedeemGift() {
  if (!redemptionCodeInput.value.trim()) return

  isSubmitting.value = true
  errorMessage.value = null
  redemptionStatus.value = null

  try {
    const res = await fetch('/v1/checkout/gift/redeem', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        giftCode: redemptionCodeInput.value.trim().toUpperCase(),
        householdId: props.householdId
      })
    })
    const data = await res.json()
    if (!res.ok) {
      throw new Error(data.message || 'Gift redemption failed')
    }

    redemptionStatus.value = {
      success: true,
      purchaserEmail: data.purchaserEmail,
      giftMessage: data.giftMessage
    }

    handleSuccessfulEntitlement(data.entitlementToken)
  } catch (err: any) {
    redemptionStatus.value = {
      success: false,
      error: err?.message || (isNepali.value ? 'उपहार कोड रिडिम गर्न सकिएन।' : 'Failed to redeem gift code.')
    }
  } finally {
    isSubmitting.value = false
  }
}

function handleSuccessfulEntitlement(tokenData: Record<string, unknown>) {
  currentEntitlement.value = {
    tier: 'householdAnnual',
    status: 'active',
    features: PREMIUM_FEATURES,
    offlineToken: tokenData
  }
  localStorage.setItem(`siti_entitlement_${props.householdId}`, JSON.stringify(currentEntitlement.value))
  emit('subscription-updated', currentEntitlement.value)
  successMessage.value = isNepali.value
    ? 'बधाई छ! वार्षिक प्रिमियम सदस्यता सक्रिय भयो।'
    : 'Congratulations! Annual Premium Subscription is now active.'
}

function copyGiftCode() {
  if (generatedGiftCode.value) {
    navigator.clipboard?.writeText(generatedGiftCode.value)
    alert(isNepali.value ? 'उपहार कोड कपी गरियो!' : 'Gift code copied to clipboard!')
  }
}
</script>

<template>
  <div class="checkout-modal-backdrop" @click.self="emit('close')">
    <div class="checkout-modal">
      <!-- Modal Header -->
      <div class="modal-header">
        <div class="header-title">
          <h2>⭐️ {{ isNepali ? 'सिट्ठी काउन्टर प्रिमियम सदस्यता' : 'Siti Counter Premium Household' }}</h2>
          <span class="ppp-badge">
            🌏 {{ isNepali ? 'क्रय-शक्ति समता (PPP) दर' : 'Purchasing Power Parity' }}
          </span>
        </div>
        <button class="close-btn" @click="emit('close')" aria-label="Close">✕</button>
      </div>

      <!-- Navigation Tabs -->
      <div class="tab-bar">
        <button
          :class="['tab-btn', { active: activeTab === 'subscribe' }]"
          @click="activeTab = 'subscribe'"
        >
          {{ isNepali ? 'वार्षिक योजना' : 'Annual Plan' }}
        </button>
        <button
          :class="['tab-btn', { active: activeTab === 'gift' }]"
          @click="activeTab = 'gift'"
        >
          🎁 {{ isNepali ? 'नेपालमा परिवारलाई उपहार' : 'Gift to Family in Nepal' }}
        </button>
        <button
          :class="['tab-btn', { active: activeTab === 'redeem' }]"
          @click="activeTab = 'redeem'"
        >
          🎟️ {{ isNepali ? 'कोड रिडिम' : 'Redeem Gift' }}
        </button>
      </div>

      <div class="modal-body">
        <!-- Active Subscription Banner -->
        <div v-if="isAlreadySubscribed" class="active-subscription-banner">
          <span class="icon">✨</span>
          <div>
            <strong>{{ isNepali ? 'तपाईंको प्रिमियम सदस्यता सक्रिय छ!' : 'Your Premium Household is Active!' }}</strong>
            <p>{{ isNepali ? 'सबै सुविधाहरू र अफलाइन प्रमाणीकरण उपलब्ध छन्।' : 'All features and verified offline tokens are active.' }}</p>
          </div>
        </div>

        <!-- TAB 1: SUBSCRIBE / TAB 2: GIFT -->
        <div v-if="activeTab === 'subscribe' || activeTab === 'gift'">
          <!-- Country / PPP Selector -->
          <div class="form-row">
            <label>{{ isNepali ? 'देश / क्षेत्र चयन:' : 'Select Country / Region:' }}</label>
            <select v-model="selectedCountry" class="select-input">
              <option value="NP">🇳🇵 Nepal (रु ९९९ / वर्ष)</option>
              <option value="IN">🇮🇳 India (₹499 / year)</option>
              <option value="US">🇺🇸 United States ($14.99 / year)</option>
              <option value="GB">🇬🇧 United Kingdom (£12.99 / year)</option>
              <option value="AU">🇦🇺 Australia (A$19.99 / year)</option>
              <option value="EU">🇪🇺 Europe (€13.99 / year)</option>
            </select>
          </div>

          <!-- Price Display Card -->
          <div class="pricing-card">
            <div class="price-header">
              <span class="plan-name">{{ isNepali ? 'वार्षिक सम्पूर्ण घरपरिवार योजना' : 'Annual Household Plan' }}</span>
              <div class="price-tag">
                <span class="amount">{{ isNepali ? pricing.formattedPriceNe : pricing.formattedPriceEn }}</span>
              </div>
            </div>
            <p class="plan-sub">
              {{ isNepali ? 'घरका सबै सदस्यहरू (५ उपकरणसम्म) र अफलाइन मोड समावेश' : 'Includes all household members (up to 5 devices) & offline mode' }}
            </p>
          </div>

          <!-- Family Gifting Notice & Fields -->
          <div v-if="activeTab === 'gift'" class="gifting-section">
            <div class="gifting-info">
              💡 {{ isNepali
                ? 'विदेशमा बस्ने नेपालीहरूले नेपालमा रहेका बुबाआमा र परिवारको भान्सा सहज बनाउन उपहार दिन सक्नुहुन्छ।'
                : 'Diaspora abroad can gift an annual subscription to parents and family back home in Nepal.' }}
            </div>

            <div class="form-row">
              <label>{{ isNepali ? 'तपाईंको इमेल (खरिदकर्ता):' : 'Your Email (Purchaser):' }} *</label>
              <input v-model="giftPurchaserEmail" type="email" class="text-input" placeholder="e.g. diaspora@example.com" />
            </div>

            <div class="form-row">
              <label>{{ isNepali ? 'उपहार पाउने व्यक्तिको नाम:' : 'Recipient Name:' }}</label>
              <input v-model="giftRecipientName" type="text" class="text-input" placeholder="e.g. Aama (Kathmandu)" />
            </div>

            <div class="form-row">
              <label>{{ isNepali ? 'उपहार पाउने व्यक्तिको इमेल (वैकल्पिक):' : 'Recipient Email (Optional):' }}</label>
              <input v-model="giftRecipientEmail" type="email" class="text-input" placeholder="e.g. aama@example.com" />
            </div>

            <div class="form-row">
              <label>{{ isNepali ? 'तपाईंको व्यक्तिगत सन्देश:' : 'Personal Gift Message:' }}</label>
              <textarea v-model="giftMessage" class="textarea-input" rows="2" placeholder="e.g. दशैंको धेरै धेरै शुभकामना आमा!"></textarea>
            </div>
          </div>

          <!-- Feature Lists Comparison -->
          <div class="features-comparison">
            <!-- Premium List -->
            <div class="feature-col premium-col">
              <h4>⭐️ {{ isNepali ? 'प्रिमियम सुविधाहरू' : 'Premium Features' }}</h4>
              <ul>
                <li>✓ {{ isNepali ? 'असीमित एआई भान्सा सहायक (Unlimited AI Assistant)' : 'Unlimited AI Kitchen Assistant' }}</li>
                <li>✓ {{ isNepali ? 'कालीमाटी दैनिक बजार भाउ (Kalimati Market Board)' : 'Kalimati Live Daily Market Prices' }}</li>
                <li>✓ {{ isNepali ? 'भोज पार्टी मोड मल्टि-लेन योजना (Party Mode Bhoj)' : 'Party Mode Bhoj Multi-Pot Planner' }}</li>
                <li>✓ {{ isNepali ? 'पारिवारिक गोप्य कुकबुक (Family Cookbook)' : 'Family Recipe Vault & Shared Cookbook' }}</li>
                <li>✓ {{ isNepali ? 'हस्ताक्षरित अफलाइन टोकन (Signed Offline Token)' : 'Cryptographic HMAC Offline Entitlements' }}</li>
              </ul>
            </div>

            <!-- Free Guarantee List -->
            <div class="feature-col free-col">
              <h4>🛡️ {{ isNepali ? 'सधैं निःशुल्क रहने सुविधाहरू' : 'Always Free Core Loop' }}</h4>
              <ul>
                <li>✓ {{ isNepali ? 'सिट्ठी काउन्टर र ताप नियन्त्रण' : 'Whistle Counter & Heat Control' }}</li>
                <li>✓ {{ isNepali ? 'नेपाल बागमती परिकार संग्रह' : 'Nepal Bagmati Recipe Pack' }}</li>
                <li>✓ {{ isNepali ? 'हप्ताको खाना तालिका र हाटबजार' : 'Weekly Meal Planner & Groceries' }}</li>
                <li>✓ {{ isNepali ? 'एलर्जी सुरक्षा चेतावनी' : 'Zero-Miss Allergen Safety Engine' }}</li>
                <li>✓ {{ isNepali ? 'स्थानीय अफलाइन सिंक' : 'Peer-to-Peer Offline Sync' }}</li>
              </ul>
            </div>
          </div>

          <!-- Payment Provider Selector -->
          <div class="payment-method-section">
            <label>{{ isNepali ? 'भुक्तानी माध्यम चयन गर्नुहोस्:' : 'Select Payment Method:' }}</label>
            <div class="provider-grid">
              <div
                v-if="supportedProviders.includes('khalti')"
                :class="['provider-card', { selected: selectedProvider === 'khalti' }]"
                @click="selectedProvider = 'khalti'"
              >
                <span class="provider-icon">🟣</span>
                <div class="provider-details">
                  <strong>Khalti (खल्ती)</strong>
                  <span>{{ isNepali ? 'डिजिटल वालेट / ई-बैंकिङ' : 'Digital Wallet & eBanking' }}</span>
                </div>
              </div>

              <div
                v-if="supportedProviders.includes('esewa')"
                :class="['provider-card', { selected: selectedProvider === 'esewa' }]"
                @click="selectedProvider = 'esewa'"
              >
                <span class="provider-icon">🟢</span>
                <div class="provider-details">
                  <strong>eSewa (ईसेवा)</strong>
                  <span>{{ isNepali ? 'नेपालको पहिलो वालेट' : 'ePay Digital Wallet' }}</span>
                </div>
              </div>

              <div
                v-if="supportedProviders.includes('stripe')"
                :class="['provider-card', { selected: selectedProvider === 'stripe' }]"
                @click="selectedProvider = 'stripe'"
              >
                <span class="provider-icon">💳</span>
                <div class="provider-details">
                  <strong>Credit / Debit Card</strong>
                  <span>{{ isNepali ? 'अन्तर्राष्ट्रिय कार्ड (Stripe)' : 'Visa / MasterCard / Amex' }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Gift Code Display (if just generated) -->
          <div v-if="generatedGiftCode" class="gift-code-success-box">
            <h4>🎉 {{ isNepali ? 'तपाईंको उपहार कोड तयार छ:' : 'Your Gift Code is Ready:' }}</h4>
            <div class="code-badge">
              <code>{{ generatedGiftCode }}</code>
              <button class="copy-btn" @click="copyGiftCode">📋 {{ isNepali ? 'कपी' : 'Copy' }}</button>
            </div>
            <p class="share-hint">
              {{ isNepali
                ? 'यो कोड वा https://sitiecounter.app/?gift=' + generatedGiftCode + ' लिङ्क परिवारलाई पठाउनुहोस्।'
                : 'Send this code or link to your family in Nepal to activate their annual premium.' }}
            </p>
          </div>

          <!-- Action Button -->
          <div class="action-footer">
            <button
              class="primary-checkout-btn"
              :disabled="isSubmitting"
              @click="handleCheckout"
            >
              {{ isSubmitting
                ? (isNepali ? 'प्रशोधन हुँदैछ...' : 'Processing...')
                : activeTab === 'gift'
                ? (isNepali ? 'उपहार खरिद गर्नुहोस् (' + pricing.formattedPriceNe + ')' : 'Purchase Gift (' + pricing.formattedPriceEn + ')')
                : (isNepali ? 'अहिले सदस्यता लिनुहोस् (' + pricing.formattedPriceNe + ')' : 'Subscribe Now (' + pricing.formattedPriceEn + ')')
              }}
            </button>
          </div>
        </div>

        <!-- TAB 3: REDEEM GIFT CODE -->
        <div v-if="activeTab === 'redeem'" class="redeem-section">
          <div class="redeem-box">
            <h3>🎁 {{ isNepali ? 'उपहार कोड रिडिम गर्नुहोस्' : 'Redeem Your Gift Subscription' }}</h3>
            <p>{{ isNepali
              ? 'विदेशमा रहेका परिवारले पठाएको उपहार कोड यहाँ लेखी आफ्नो वार्षिक प्रिमियम तुरुन्त सक्रिय गर्नुहोस्।'
              : 'Enter the gift code sent by your family abroad to immediately activate your Annual Premium.'
            }}</p>

            <div class="form-row">
              <input
                v-model="redemptionCodeInput"
                type="text"
                class="code-input"
                placeholder="GIFT-SITI-XXXX-XXXX"
                maxlength="25"
              />
            </div>

            <button
              class="primary-checkout-btn"
              :disabled="isSubmitting || !redemptionCodeInput.trim()"
              @click="handleRedeemGift"
            >
              {{ isSubmitting ? (isNepali ? 'जाँच हुँदैछ...' : 'Verifying...') : (isNepali ? 'कोड रिडिम गर्नुहोस्' : 'Redeem Gift Code') }}
            </button>
          </div>

          <!-- Redemption Feedback -->
          <div v-if="redemptionStatus?.success" class="redeem-success-box">
            <h4>✨ {{ isNepali ? 'उपहार सफलतापूर्वक सक्रिय भयो!' : 'Gift Subscription Activated!' }}</h4>
            <p v-if="redemptionStatus.purchaserEmail">
              <strong>{{ isNepali ? 'पठाउने व्यक्ति:' : 'From:' }}</strong> {{ redemptionStatus.purchaserEmail }}
            </p>
            <p v-if="redemptionStatus.giftMessage" class="gift-msg-quote">
              "{{ redemptionStatus.giftMessage }}"
            </p>
            <span class="entitlement-badge">
              🔒 {{ isNepali ? 'अफलाइन प्रमाणीकरण टोकन सुरक्षित गरियो' : 'Signed Offline Entitlement Stored' }}
            </span>
          </div>

          <div v-if="redemptionStatus?.error" class="error-banner">
            ⚠️ {{ redemptionStatus.error }}
          </div>
        </div>

        <!-- Global Error & Success Messages -->
        <div v-if="errorMessage" class="error-banner">
          ⚠️ {{ errorMessage }}
        </div>
        <div v-if="successMessage && !generatedGiftCode" class="success-banner">
          🎉 {{ successMessage }}
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.checkout-modal-backdrop {
  position: fixed;
  inset: 0;
  background-color: rgba(0, 0, 0, 0.65);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 16px;
  overflow-y: auto;
}

.checkout-modal {
  background: var(--siti-color-background-warm-white, #FAF9F6);
  color: #1A1A1A;
  border-radius: var(--siti-radius-xl, 16px);
  width: 100%;
  max-width: 680px;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  box-shadow: var(--siti-elevation-modal, 0 12px 32px rgba(0, 0, 0, 0.2));
  overflow: hidden;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 24px;
  background: #FFFFFF;
  border-bottom: 1px solid #ECECEC;
}

.header-title h2 {
  margin: 0;
  font-size: 1.25rem;
  color: var(--siti-color-primary-terracotta, #D95328);
}

.ppp-badge {
  display: inline-block;
  font-size: 0.75rem;
  background: #E8F5E9;
  color: #2E7D32;
  padding: 2px 8px;
  border-radius: 999px;
  font-weight: 600;
  margin-top: 4px;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.25rem;
  cursor: pointer;
  color: #666;
  padding: 8px;
}

.tab-bar {
  display: flex;
  background: #F0EEE9;
  border-bottom: 1px solid #E0DED9;
}

.tab-btn {
  flex: 1;
  padding: 12px 8px;
  background: none;
  border: none;
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
  color: #666;
  transition: all 0.2s ease;
  border-bottom: 3px solid transparent;
}

.tab-btn.active {
  color: var(--siti-color-primary-terracotta, #D95328);
  background: #FAF9F6;
  border-bottom-color: var(--siti-color-primary-terracotta, #D95328);
}

.modal-body {
  padding: 24px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.active-subscription-banner {
  display: flex;
  gap: 12px;
  align-items: center;
  background: #E8F5E9;
  color: #1B5E20;
  padding: 12px 16px;
  border-radius: 8px;
  border: 1px solid #C8E6C9;
}

.form-row {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-row label {
  font-weight: 600;
  font-size: 0.875rem;
  color: #333;
}

.select-input, .text-input, .textarea-input, .code-input {
  padding: 10px 14px;
  border-radius: 8px;
  border: 1px solid #CCC;
  font-size: 0.95rem;
  background: #FFF;
}

.code-input {
  font-family: monospace;
  font-size: 1.2rem;
  font-weight: 700;
  letter-spacing: 2px;
  text-align: center;
}

.pricing-card {
  background: #FFF;
  border-radius: 12px;
  padding: 16px 20px;
  border: 2px solid #E8E6DF;
}

.price-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.plan-name {
  font-weight: 700;
  font-size: 1.1rem;
}

.amount {
  font-size: 1.35rem;
  font-weight: 800;
  color: var(--siti-color-primary-terracotta, #D95328);
}

.plan-sub {
  margin: 6px 0 0 0;
  font-size: 0.85rem;
  color: #666;
}

.gifting-info {
  background: #FFF8E1;
  color: #795548;
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 0.85rem;
  margin-bottom: 12px;
  border: 1px solid #FFE082;
}

.features-comparison {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

@media (max-width: 600px) {
  .features-comparison {
    grid-template-columns: 1fr;
  }
}

.feature-col {
  background: #FFF;
  border-radius: 10px;
  padding: 14px;
  border: 1px solid #E4E2DC;
}

.feature-col h4 {
  margin: 0 0 10px 0;
  font-size: 0.95rem;
}

.premium-col h4 {
  color: var(--siti-color-primary-terracotta, #D95328);
}

.free-col h4 {
  color: #2E7D32;
}

.feature-col ul {
  list-style: none;
  padding: 0;
  margin: 0;
  font-size: 0.825rem;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.payment-method-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.provider-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px;
}

.provider-card {
  display: flex;
  align-items: center;
  gap: 10px;
  background: #FFF;
  border: 2px solid #E0DED9;
  border-radius: 10px;
  padding: 12px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.provider-card:hover {
  border-color: #BBB;
}

.provider-card.selected {
  border-color: var(--siti-color-primary-terracotta, #D95328);
  background: #FFF5F2;
}

.provider-icon {
  font-size: 1.5rem;
}

.provider-details {
  display: flex;
  flex-direction: column;
}

.provider-details strong {
  font-size: 0.9rem;
}

.provider-details span {
  font-size: 0.75rem;
  color: #666;
}

.gift-code-success-box, .redeem-success-box {
  background: #E8F5E9;
  border: 2px solid #A5D6A7;
  border-radius: 10px;
  padding: 16px;
  text-align: center;
}

.code-badge {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  background: #FFF;
  padding: 8px 16px;
  border-radius: 8px;
  border: 1px dashed #2E7D32;
  margin: 12px 0;
}

.code-badge code {
  font-size: 1.25rem;
  font-weight: 800;
  letter-spacing: 2px;
  color: #1B5E20;
}

.copy-btn {
  background: #2E7D32;
  color: #FFF;
  border: none;
  padding: 6px 12px;
  border-radius: 6px;
  font-weight: 600;
  cursor: pointer;
}

.primary-checkout-btn {
  width: 100%;
  padding: 14px;
  background: var(--siti-color-primary-terracotta, #D95328);
  color: #FFFFFF;
  border: none;
  border-radius: 10px;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.2s ease;
}

.primary-checkout-btn:hover:not(:disabled) {
  background: var(--siti-color-primary-terracotta-dark, #B9421E);
}

.primary-checkout-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error-banner {
  background: #FFEBEE;
  color: #C62828;
  padding: 12px;
  border-radius: 8px;
  font-size: 0.875rem;
  border: 1px solid #FFCDD2;
}

.success-banner {
  background: #E8F5E9;
  color: #2E7D32;
  padding: 12px;
  border-radius: 8px;
  font-size: 0.875rem;
  border: 1px solid #C8E6C9;
}
</style>
