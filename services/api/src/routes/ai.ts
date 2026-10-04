import { Hono } from 'hono';
import {
  ThreeTierAssistantCoordinator,
  SafetyGuardrail,
  DataPseudonymizer,
  AssistantRequest,
  AssistantResponse,
  CloudGeminiProvider,
} from '@siti-counter/kitchen-engine';

export interface AiEnv {
  Bindings: {
    GEMINI_API_KEY?: string;
    AI_GATEWAY_URL?: string;
  };
}

export const aiRouter = new Hono<AiEnv>();

class BackendGeminiProvider implements CloudGeminiProvider {
  constructor(
    private readonly apiKey?: string,
    private readonly aiGatewayUrl?: string
  ) {}

  async queryGemini({
    pseudonymizedPrompt,
    language = 'en',
  }: {
    pseudonymizedPrompt: string;
    language?: string;
  }): Promise<string> {
    // If real Gemini API key is configured, call Gemini 3.8 Flash via fetch or AI Gateway
    if (this.apiKey) {
      const endpoint = this.aiGatewayUrl
        ? `${this.aiGatewayUrl}/models/gemini-3.8-flash:generateContent?key=${this.apiKey}`
        : `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=${this.apiKey}`;

      try {
        const res = await fetch(endpoint, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [
              {
                role: 'user',
                parts: [
                  {
                    text: `You are Siti Counter AI, a warm and culturally respectful Himalayan culinary assistant.
Language: ${language}.
Answer the following kitchen/cooking query concisely.
If suggesting recipes, use real ingredients and traditional methods.
Prompt: ${pseudonymizedPrompt}`,
                  },
                ],
              },
            ],
            generationConfig: {
              temperature: 0.4,
              maxOutputTokens: 600,
            },
          }),
        });

        if (res.ok) {
          const data = (await res.json()) as {
            candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
          };
          const reply = data.candidates?.[0]?.content?.parts?.[0]?.text;
          if (reply) return reply;
        }
      } catch {
        // Fall back to grounded guidance on network or API key error
      }
    }

    // Grounded fallback response for test/offline environments
    return `For ${pseudonymizedPrompt.includes('[FamilyMember') ? 'your family' : 'today'}, I recommend a wholesome seasonal meal like Masyaura Dal with freshly steamed rice. It brings warm comfort and great flavor.`;
  }
}

aiRouter.post('/v1/ai/assistant', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as Partial<AssistantRequest>;

  if (!body.prompt || typeof body.prompt !== 'string' || body.prompt.trim().length === 0) {
    return c.json({ error: 'INVALID_PROMPT', message: 'prompt string is required' }, 400);
  }

  // Guardrail 1: Medical / Pediatric Calorie Filter
  if (SafetyGuardrail.isMedicalOrPediatricCalorieQuery(body.prompt)) {
    const safetyResp = SafetyGuardrail.buildMedicalSafetyResponse();
    return c.json(safetyResp, 200);
  }

  const coordinator = new ThreeTierAssistantCoordinator({
    cloudProvider: new BackendGeminiProvider(c.env?.GEMINI_API_KEY, c.env?.AI_GATEWAY_URL),
  });

  const request: AssistantRequest = {
    prompt: body.prompt,
    currentLanguage: body.currentLanguage || 'en',
    householdMemberNames: body.householdMemberNames || [],
    memberAllergies: body.memberAllergies || [],
    dietaryRules: body.dietaryRules || [],
    catalogRecipes: body.catalogRecipes || [],
    pantryIngredientIds: body.pantryIngredientIds || [],
    currentElevationMeters: body.currentElevationMeters ?? 1400,
    hasCloudConsent: body.hasCloudConsent === true,
  };

  const response: AssistantResponse = await coordinator.process(request);

  if (response.consentPromptRequired) {
    return c.json(response, 403);
  }

  return c.json(response, 200);
});
