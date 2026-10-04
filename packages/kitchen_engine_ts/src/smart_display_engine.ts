/**
 * Smart Display Engine: Alexa Skill (APL) & Google Cast Web Receiver Protocols
 *
 * Implements:
 * - Google Cast Receiver message framing for Nest Hub and Cast screens
 * - Alexa Presentation Language (APL 1.4+) document builders for Echo Show displays
 * - Alexa Skill intent routing for hands-free kitchen display control
 */

// ============================================================================
// 1. Google Cast Protocol (Nest Hub & Smart Displays)
// ============================================================================

export const SITI_CAST_NAMESPACE = 'urn:x-cast:com.siticounter.cooking';

export type FlameLevel = 'high' | 'medium' | 'low' | 'off';

export interface CastCookingSessionState {
  sessionId: string;
  recipeNameEn: string;
  recipeNameNe?: string;
  currentStepIndex: number;
  totalSteps: number;
  stepInstructionEn: string;
  stepInstructionNe?: string;
  whistlesTarget: number;
  whistlesCurrent: number;
  timerSecondsRemaining?: number;
  flameLevel: FlameLevel;
  isPaused: boolean;
  targetReached: boolean;
}

export type CastMessageType =
  | 'COOKING_SESSION_UPDATE'
  | 'SITI_COUNT_UPDATE'
  | 'TIMER_UPDATE'
  | 'TARGET_REACHED'
  | 'HEARTBEAT';

export interface CastMessage<T = unknown> {
  type: CastMessageType;
  timestamp: number;
  payload: T;
}

export class CastProtocolEngine {
  public static createSessionUpdate(state: CastCookingSessionState): CastMessage<CastCookingSessionState> {
    return {
      type: 'COOKING_SESSION_UPDATE',
      timestamp: Date.now(),
      payload: state,
    };
  }

  public static createSitiCountUpdate(current: number, target: number): CastMessage<{ current: number; target: number; reached: boolean }> {
    return {
      type: 'SITI_COUNT_UPDATE',
      timestamp: Date.now(),
      payload: {
        current,
        target,
        reached: current >= target && target > 0,
      },
    };
  }

  public static createTimerUpdate(remainingSeconds: number, isPaused: boolean): CastMessage<{ remainingSeconds: number; isPaused: boolean }> {
    return {
      type: 'TIMER_UPDATE',
      timestamp: Date.now(),
      payload: { remainingSeconds, isPaused },
    };
  }

  public static createTargetReachedCelebration(recipeName: string, whistles: number): CastMessage<{ recipeName: string; whistles: number }> {
    return {
      type: 'TARGET_REACHED',
      timestamp: Date.now(),
      payload: { recipeName, whistles },
    };
  }

  public static serialize(message: CastMessage): string {
    return JSON.stringify(message);
  }

  public static deserialize(raw: string): CastMessage {
    try {
      const parsed = JSON.parse(raw);
      if (!parsed || typeof parsed.type !== 'string' || typeof parsed.timestamp !== 'number') {
        throw new Error('Invalid Cast message structure');
      }
      return parsed as CastMessage;
    } catch (err) {
      throw new Error(`Failed to parse Cast message: ${(err as Error).message}`);
    }
  }
}

// ============================================================================
// 2. Alexa Skill & Alexa Presentation Language (APL) Models
// ============================================================================

export interface AlexaSlot {
  name: string;
  value?: string;
}

export interface AlexaIntent {
  name: string;
  confirmationStatus?: string;
  slots?: Record<string, AlexaSlot>;
}

export interface AlexaRequestBody {
  version: string;
  session?: {
    new?: boolean;
    sessionId: string;
    attributes?: Record<string, unknown>;
  };
  context?: {
    System?: {
      device?: {
        deviceId?: string;
        supportedInterfaces?: {
          'Alexa.Presentation.APL'?: {
            runtime?: {
              maxVersion: string;
            };
          };
        };
      };
    };
    Viewport?: {
      shape?: 'RECTANGLE' | 'ROUND';
      pixelWidth?: number;
      pixelHeight?: number;
      dpi?: number;
    };
  };
  request: {
    type: 'LaunchRequest' | 'IntentRequest' | 'SessionEndedRequest';
    requestId: string;
    timestamp: string;
    locale?: string;
    intent?: AlexaIntent;
  };
}

export interface APLDirective {
  type: 'Alexa.Presentation.APL.RenderDocument';
  token?: string;
  document: Record<string, unknown>;
  datasources: Record<string, unknown>;
}

export interface AlexaResponseBody {
  version: '1.0';
  response: {
    outputSpeech?: {
      type: 'PlainText' | 'SSML';
      text?: string;
      ssml?: string;
    };
    reprompt?: {
      outputSpeech: {
        type: 'PlainText' | 'SSML';
        text?: string;
        ssml?: string;
      };
    };
    shouldEndSession: boolean;
    directives?: APLDirective[];
  };
  sessionAttributes?: Record<string, unknown>;
}

// ============================================================================
// 3. APL Document Builders for Echo Show
// ============================================================================

export interface TodayMealItem {
  slot: string; // e.g., 'Bihanko Dal Bhat', 'Khaja', 'Belukako Bhat'
  recipeName: string;
  timeEstimateMinutes: number;
  whistlesTarget?: number;
}

export class AlexaAPLBuilder {
  /**
   * Generates an APL 1.4 document for Today's Planned Menu.
   */
  public static buildTodayMenuDocument(meals: TodayMealItem[]): { document: Record<string, unknown>; datasources: Record<string, unknown> } {
    const document = {
      type: 'APL',
      version: '1.4',
      import: [{ name: 'alexa-layouts', version: '1.2.0' }],
      theme: 'dark',
      styles: {
        headerTitle: {
          values: [{ color: '#FFD700', fontSize: '28dp', fontWeight: 'bold' }],
        },
        cardTitle: {
          values: [{ color: '#FFFFFF', fontSize: '22dp', fontWeight: 'bold' }],
        },
      },
      mainTemplate: {
        parameters: ['payload'],
        items: [
          {
            type: 'Container',
            width: '100vw',
            height: '100vh',
            paddingLeft: '32dp',
            paddingRight: '32dp',
            paddingTop: '24dp',
            paddingBottom: '24dp',
            items: [
              {
                type: 'Text',
                text: 'Siti Counter - Today’s Kitchen Menu',
                style: 'headerTitle',
              },
              {
                type: 'Sequence',
                scrollDirection: 'horizontal',
                width: '100%',
                height: '80%',
                marginTop: '16dp',
                data: '${payload.menuData.meals}',
                items: [
                  {
                    type: 'Container',
                    width: '300dp',
                    height: '100%',
                    marginRight: '20dp',
                    backgroundColor: '#1E1E1E',
                    borderRadius: '16dp',
                    padding: '20dp',
                    items: [
                      {
                        type: 'Text',
                        text: '${data.slot}',
                        color: '#D9534F',
                        fontSize: '16dp',
                        fontWeight: 'bold',
                      },
                      {
                        type: 'Text',
                        text: '${data.recipeName}',
                        style: 'cardTitle',
                        marginTop: '10dp',
                      },
                      {
                        type: 'Text',
                        text: '⏱ ~${data.timeEstimateMinutes} mins',
                        color: '#B0B0B0',
                        fontSize: '18dp',
                        marginTop: '12dp',
                      },
                      {
                        type: 'Text',
                        text: '${data.whistlesTarget > 0 ? "🔔 Target: " + data.whistlesTarget + " whistles" : "⏲ Regular Cook"}',
                        color: '#4CAF50',
                        fontSize: '16dp',
                        marginTop: '8dp',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    };

    const datasources = {
      menuData: {
        meals: meals.map((m) => ({
          slot: m.slot,
          recipeName: m.recipeName,
          timeEstimateMinutes: m.timeEstimateMinutes,
          whistlesTarget: m.whistlesTarget ?? 0,
        })),
      },
    };

    return { document, datasources };
  }

  /**
   * Generates an APL document for Step-by-Step cooking on Echo Show.
   */
  public static buildCookingStepDocument(params: {
    recipeName: string;
    stepIndex: number;
    totalSteps: number;
    instruction: string;
    whistlesCount?: number;
    whistlesTarget?: number;
    timerSecondsRemaining?: number;
  }): { document: Record<string, unknown>; datasources: Record<string, unknown> } {
    const document = {
      type: 'APL',
      version: '1.4',
      theme: 'dark',
      mainTemplate: {
        parameters: ['payload'],
        items: [
          {
            type: 'Container',
            width: '100vw',
            height: '100vh',
            paddingLeft: '32dp',
            paddingRight: '32dp',
            paddingTop: '24dp',
            items: [
              {
                type: 'Row',
                justifyContent: 'spaceBetween',
                width: '100%',
                items: [
                  {
                    type: 'Text',
                    text: '${payload.stepData.recipeName}',
                    color: '#FF9800',
                    fontSize: '24dp',
                    fontWeight: 'bold',
                  },
                  {
                    type: 'Text',
                    text: 'Step ${payload.stepData.stepIndex + 1} of ${payload.stepData.totalSteps}',
                    color: '#FFFFFF',
                    fontSize: '20dp',
                  },
                ],
              },
              {
                type: 'Container',
                marginTop: '32dp',
                padding: '24dp',
                backgroundColor: '#262626',
                borderRadius: '20dp',
                width: '100%',
                items: [
                  {
                    type: 'Text',
                    text: '${payload.stepData.instruction}',
                    color: '#FFFFFF',
                    fontSize: '32dp',
                    fontWeight: 'bold',
                    maxLines: 4,
                  },
                ],
              },
              {
                type: 'Row',
                marginTop: '32dp',
                justifyContent: 'spaceAround',
                width: '100%',
                items: [
                  {
                    type: 'Container',
                    padding: '16dp',
                    backgroundColor: '#1E1E1E',
                    borderRadius: '16dp',
                    items: [
                      {
                        type: 'Text',
                        text: 'Siti Count',
                        color: '#B0B0B0',
                        fontSize: '16dp',
                      },
                      {
                        type: 'Text',
                        text: '${payload.stepData.whistlesCount} / ${payload.stepData.whistlesTarget}',
                        color: '#4CAF50',
                        fontSize: '36dp',
                        fontWeight: 'bold',
                      },
                    ],
                  },
                  {
                    type: 'Container',
                    padding: '16dp',
                    backgroundColor: '#1E1E1E',
                    borderRadius: '16dp',
                    items: [
                      {
                        type: 'Text',
                        text: 'Timer',
                        color: '#B0B0B0',
                        fontSize: '16dp',
                      },
                      {
                        type: 'Text',
                        text: '${payload.stepData.timerFormatted}',
                        color: '#2196F3',
                        fontSize: '36dp',
                        fontWeight: 'bold',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    };

    const remaining = params.timerSecondsRemaining ?? 0;
    const mins = Math.floor(remaining / 60);
    const secs = remaining % 60;
    const timerFormatted = `${mins}:${secs.toString().padStart(2, '0')}`;

    const datasources = {
      stepData: {
        recipeName: params.recipeName,
        stepIndex: params.stepIndex,
        totalSteps: params.totalSteps,
        instruction: params.instruction,
        whistlesCount: params.whistlesCount ?? 0,
        whistlesTarget: params.whistlesTarget ?? 0,
        timerFormatted,
      },
    };

    return { document, datasources };
  }

  /**
   * Generates a Giant Siti Whistle Monitor APL Document.
   */
  public static buildWhistleMonitorDocument(params: {
    currentWhistles: number;
    targetWhistles: number;
    flameStatus: string;
    isFinished: boolean;
  }): { document: Record<string, unknown>; datasources: Record<string, unknown> } {
    const document = {
      type: 'APL',
      version: '1.4',
      theme: 'dark',
      mainTemplate: {
        parameters: ['payload'],
        items: [
          {
            type: 'Container',
            width: '100vw',
            height: '100vh',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: '${payload.whistleData.isFinished ? "#1B5E20" : "#121212"}',
            items: [
              {
                type: 'Text',
                text: '${payload.whistleData.isFinished ? "COOKING COMPLETE! TURN OFF FLAME" : "PRESSURE COOKER SITI COUNTER"}',
                color: '${payload.whistleData.isFinished ? "#FFFFFF" : "#FF9800"}',
                fontSize: '28dp',
                fontWeight: 'bold',
              },
              {
                type: 'Text',
                text: '${payload.whistleData.currentWhistles}',
                color: '#FFFFFF',
                fontSize: '120dp',
                fontWeight: 'bold',
                marginTop: '10dp',
              },
              {
                type: 'Text',
                text: 'Target: ${payload.whistleData.targetWhistles} Whistles | Flame: ${payload.whistleData.flameStatus}',
                color: '#E0E0E0',
                fontSize: '24dp',
                marginTop: '10dp',
              },
            ],
          },
        ],
      },
    };

    const datasources = {
      whistleData: {
        currentWhistles: params.currentWhistles,
        targetWhistles: params.targetWhistles,
        flameStatus: params.flameStatus.toUpperCase(),
        isFinished: params.isFinished,
      },
    };

    return { document, datasources };
  }
}

// ============================================================================
// 4. Alexa Skill Request Handler
// ============================================================================

export interface AlexaSkillHandlerOptions {
  getTodayMenu?: () => TodayMealItem[];
  getActiveCookingSession?: () => {
    recipeName: string;
    stepIndex: number;
    totalSteps: number;
    instruction: string;
    whistlesCount: number;
    whistlesTarget: number;
    timerRemainingSeconds: number;
    flameLevel: FlameLevel;
  } | null;
}

export class AlexaSkillHandler {
  constructor(private readonly options: AlexaSkillHandlerOptions = {}) {}

  public handleRequest(body: AlexaRequestBody): AlexaResponseBody {
    const supportsAPL =
      !!body.context?.System?.device?.supportedInterfaces?.['Alexa.Presentation.APL'];

    const reqType = body.request.type;

    if (reqType === 'LaunchRequest') {
      return this.handleLaunch(supportsAPL);
    }

    if (reqType === 'IntentRequest') {
      const intentName = body.request.intent?.name;
      switch (intentName) {
        case 'TodaysMenuIntent':
          return this.handleTodaysMenu(supportsAPL);
        case 'CookingStepIntent':
          return this.handleCookingStep(supportsAPL);
        case 'WhistleCountIntent':
          return this.handleWhistleCount(supportsAPL);
        case 'SetTimerIntent':
          return this.handleSetTimer(body.request.intent?.slots);
        case 'AMAZON.HelpIntent':
          return {
            version: '1.0',
            response: {
              outputSpeech: {
                type: 'PlainText',
                text: 'You can ask what is on today\'s menu, check your siti count, navigate cooking steps, or set a kitchen timer. What would you like to do?',
              },
              reprompt: {
                outputSpeech: {
                  type: 'PlainText',
                  text: 'You can ask: what\'s on the menu today?',
                },
              },
              shouldEndSession: false,
            },
          };
        case 'AMAZON.CancelIntent':
        case 'AMAZON.StopIntent':
          return {
            version: '1.0',
            response: {
              outputSpeech: {
                type: 'PlainText',
                text: 'Happy cooking with Siti Counter! Goodbye.',
              },
              shouldEndSession: true,
            },
          };
        default:
          return {
            version: '1.0',
            response: {
              outputSpeech: {
                type: 'PlainText',
                text: 'I didn\'t understand that. You can ask what\'s on the menu or check cooking progress.',
              },
              shouldEndSession: false,
            },
          };
      }
    }

    // Default SessionEndedRequest or fallback
    return {
      version: '1.0',
      response: {
        shouldEndSession: true,
      },
    };
  }

  private handleLaunch(supportsAPL: boolean): AlexaResponseBody {
    const active = this.options.getActiveCookingSession ? this.options.getActiveCookingSession() : null;

    let speechText = 'Welcome to Siti Counter! ';
    let directives: APLDirective[] | undefined;

    if (active) {
      speechText += `You are currently cooking ${active.recipeName} on step ${active.stepIndex + 1} with ${active.whistlesCount} of ${active.whistlesTarget} whistles counted. Would you like the next step or siti count?`;
      if (supportsAPL) {
        const apl = AlexaAPLBuilder.buildCookingStepDocument({
          recipeName: active.recipeName,
          stepIndex: active.stepIndex,
          totalSteps: active.totalSteps,
          instruction: active.instruction,
          whistlesCount: active.whistlesCount,
          whistlesTarget: active.whistlesTarget,
          timerSecondsRemaining: active.timerRemainingSeconds,
        });
        directives = [
          {
            type: 'Alexa.Presentation.APL.RenderDocument',
            document: apl.document,
            datasources: apl.datasources,
          },
        ];
      }
    } else {
      speechText += 'What would you like to cook today? You can ask what\'s on today\'s menu or start counting whistles.';
      if (supportsAPL) {
        const meals = this.options.getTodayMenu ? this.options.getTodayMenu() : this.getDefaultMeals();
        const apl = AlexaAPLBuilder.buildTodayMenuDocument(meals);
        directives = [
          {
            type: 'Alexa.Presentation.APL.RenderDocument',
            document: apl.document,
            datasources: apl.datasources,
          },
        ];
      }
    }

    return {
      version: '1.0',
      response: {
        outputSpeech: {
          type: 'PlainText',
          text: speechText,
        },
        reprompt: {
          outputSpeech: {
            type: 'PlainText',
            text: 'You can ask what is on today\'s menu or check your siti count.',
          },
        },
        shouldEndSession: false,
        directives,
      },
    };
  }

  private handleTodaysMenu(supportsAPL: boolean): AlexaResponseBody {
    const meals = this.options.getTodayMenu ? this.options.getTodayMenu() : this.getDefaultMeals();
    const names = meals.map((m) => `${m.slot}: ${m.recipeName}`).join(', ');
    const speech = `Today's planned meals are: ${names}. Which meal would you like to start?`;

    let directives: APLDirective[] | undefined;
    if (supportsAPL) {
      const apl = AlexaAPLBuilder.buildTodayMenuDocument(meals);
      directives = [
        {
          type: 'Alexa.Presentation.APL.RenderDocument',
          document: apl.document,
          datasources: apl.datasources,
        },
      ];
    }

    return {
      version: '1.0',
      response: {
        outputSpeech: {
          type: 'PlainText',
          text: speech,
        },
        reprompt: {
          outputSpeech: {
            type: 'PlainText',
            text: 'Would you like to start cooking one of today\'s dishes?',
          },
        },
        shouldEndSession: false,
        directives,
      },
    };
  }

  private handleCookingStep(supportsAPL: boolean): AlexaResponseBody {
    const active = this.options.getActiveCookingSession ? this.options.getActiveCookingSession() : null;

    if (!active) {
      return {
        version: '1.0',
        response: {
          outputSpeech: {
            type: 'PlainText',
            text: 'There is no active cooking session right now. You can pick a recipe from today\'s menu to begin.',
          },
          shouldEndSession: false,
        },
      };
    }

    const speech = `Step ${active.stepIndex + 1} for ${active.recipeName}: ${active.instruction}`;
    let directives: APLDirective[] | undefined;

    if (supportsAPL) {
      const apl = AlexaAPLBuilder.buildCookingStepDocument({
        recipeName: active.recipeName,
        stepIndex: active.stepIndex,
        totalSteps: active.totalSteps,
        instruction: active.instruction,
        whistlesCount: active.whistlesCount,
        whistlesTarget: active.whistlesTarget,
        timerSecondsRemaining: active.timerRemainingSeconds,
      });
      directives = [
        {
          type: 'Alexa.Presentation.APL.RenderDocument',
          document: apl.document,
          datasources: apl.datasources,
        },
      ];
    }

    return {
      version: '1.0',
      response: {
        outputSpeech: {
          type: 'PlainText',
          text: speech,
        },
        shouldEndSession: false,
        directives,
      },
    };
  }

  private handleWhistleCount(supportsAPL: boolean): AlexaResponseBody {
    const active = this.options.getActiveCookingSession ? this.options.getActiveCookingSession() : null;

    if (!active) {
      return {
        version: '1.0',
        response: {
          outputSpeech: {
            type: 'PlainText',
            text: 'No cooker is currently running. Start a dish in Siti Counter to begin counting whistles.',
          },
          shouldEndSession: false,
        },
      };
    }

    const isDone = active.whistlesCount >= active.whistlesTarget && active.whistlesTarget > 0;
    const speech = isDone
      ? `Target reached! The cooker has blown ${active.whistlesCount} whistles for ${active.recipeName}. Turn off the flame now.`
      : `The cooker has blown ${active.whistlesCount} of ${active.whistlesTarget} whistles for ${active.recipeName}. Flame is on ${active.flameLevel}.`;

    let directives: APLDirective[] | undefined;
    if (supportsAPL) {
      const apl = AlexaAPLBuilder.buildWhistleMonitorDocument({
        currentWhistles: active.whistlesCount,
        targetWhistles: active.whistlesTarget,
        flameStatus: active.flameLevel,
        isFinished: isDone,
      });
      directives = [
        {
          type: 'Alexa.Presentation.APL.RenderDocument',
          document: apl.document,
          datasources: apl.datasources,
        },
      ];
    }

    return {
      version: '1.0',
      response: {
        outputSpeech: {
          type: 'PlainText',
          text: speech,
        },
        shouldEndSession: false,
        directives,
      },
    };
  }

  private handleSetTimer(slots?: Record<string, AlexaSlot>): AlexaResponseBody {
    const rawVal = slots?.['duration']?.value || slots?.['minutes']?.value || '5';
    const minutes = parseInt(rawVal, 10) || 5;

    return {
      version: '1.0',
      response: {
        outputSpeech: {
          type: 'PlainText',
          text: `Setting a kitchen timer for ${minutes} minutes.`,
        },
        shouldEndSession: false,
      },
    };
  }

  private getDefaultMeals(): TodayMealItem[] {
    return [
      {
        slot: 'Morning Dal Bhat',
        recipeName: 'Yellow Lentil Dal & Basmati Rice',
        timeEstimateMinutes: 25,
        whistlesTarget: 3,
      },
      {
        slot: 'Afternoon Khaja',
        recipeName: 'Chiura Tarkari with Aloo Chana',
        timeEstimateMinutes: 15,
        whistlesTarget: 2,
      },
      {
        slot: 'Evening Dinner',
        recipeName: 'Saag, Chicken Curry & Roti',
        timeEstimateMinutes: 35,
        whistlesTarget: 4,
      },
    ];
  }
}
