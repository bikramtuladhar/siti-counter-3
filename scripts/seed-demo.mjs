#!/usr/bin/env node
/**
 * Seeds a running API with a demo household so the glanceable surfaces have real data.
 *
 * Creates a guest session, then pushes today's meal plan, a live cooking session and a
 * grocery list through `POST /v1/sync` — the same path the mobile app uses, so this
 * exercises the real write path and the feed is built from genuinely synced state.
 *
 * Usage: node scripts/seed-demo.mjs [baseUrl]
 *   baseUrl defaults to http://127.0.0.1:8787
 *
 * Re-running with the same deviceId reuses the same household and replaces its data, so it
 * is safe to run repeatedly while iterating.
 */

const baseUrl = process.argv[2] ?? 'http://127.0.0.1:8787';

function uuidV7() {
  // RFC 9562 layout: 48-bit ms timestamp, version nibble 7, then the variant bits in the
  // top two bits of byte 8 (must be 0b10, i.e. 8/9/a/b in the 4th group) and random tail.
  // Omitting the variant bits makes ~75% of ids fail the server's UUIDv7 check.
  const bytes = new Uint8Array(16);
  let ts = BigInt(Date.now());
  for (let i = 5; i >= 0; i--) {
    bytes[i] = Number(ts & 0xffn);
    ts >>= 8n;
  }
  bytes[6] = 0x70 | (Math.random() * 0x0f);
  bytes[7] = Math.random() * 0xff;
  bytes[8] = 0x80 | (Math.random() * 0x3f);
  for (let i = 9; i < 16; i++) bytes[i] = Math.random() * 0xff;

  const hex = [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

async function post(path, body, headers = {}) {
  const res = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    throw new Error(`${path} -> ${res.status} ${JSON.stringify(json)}`);
  }
  return json;
}

async function get(path, headers = {}) {
  const res = await fetch(`${baseUrl}${path}`, { headers });
  const text = await res.text();
  if (res.status === 304) return { notModified: true };
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  if (!res.ok) throw new Error(`${path} -> ${res.status} ${JSON.stringify(json)}`);
  return json;
}

const TODAY = new Date().toISOString().split('T')[0];

/**
 * Monotonic version for this run.
 *
 * The sync resolver is last-write-wins on `version`, and an equal version is treated as
 * "server already has this" and rejected as a conflict. A wall-clock-derived version makes
 * every run strictly newer than the last, so re-seeding an existing household replaces its
 * data instead of conflicting.
 */
const RUN_VERSION = Math.floor(Date.now() / 1000);

async function main() {
  console.log(`Seeding ${baseUrl}`);

  // Stable device id so repeat runs hit the same household.
  const auth = await post('/v1/auth/guest', { deviceId: 'demo-seed-device' });
  const token = auth.tokens.accessToken;
  const householdId = auth.user.householdId;
  console.log(`  household: ${householdId}`);

  const headers = { Authorization: `Bearer ${token}` };

  const changes = [
    {
      id: uuidV7(),
      entityType: 'meal_plan',
      entityId: 'slot_breakfast',
      version: RUN_VERSION,
      payload: {
        dateIso: TODAY,
        slotId: 'breakfast',
        slotTitleEn: 'Breakfast',
        slotTitleNe: 'बिहानीको खाना',
        recipeTitleEn: 'Masyang Dal & Bhat',
        recipeTitleNe: 'मास्याङ दाल र भात',
        servings: 4,
        sortOrder: 1,
        rituNameEn: 'Sharad',
        rituNameNe: 'शरद',
      },
    },
    {
      id: uuidV7(),
      entityType: 'meal_plan',
      entityId: 'slot_lunch',
      version: RUN_VERSION,
      payload: {
        dateIso: TODAY,
        slotId: 'lunch',
        slotTitleEn: 'Lunch',
        slotTitleNe: 'दिउँसोको खाना',
        recipeTitleEn: 'Aloo Tama Tarkari',
        recipeTitleNe: 'आलु तामा तरकारी',
        servings: 4,
        sortOrder: 2,
      },
    },
    {
      id: uuidV7(),
      entityType: 'meal_plan',
      entityId: 'slot_dinner',
      version: RUN_VERSION,
      payload: {
        dateIso: TODAY,
        slotId: 'dinner',
        slotTitleEn: 'Dinner',
        slotTitleNe: 'रातिको खाना',
        recipeTitleEn: 'Khasi ko Masu',
        recipeTitleNe: 'खसीको मासु',
        servings: 3,
        sortOrder: 3,
      },
    },
    {
      id: uuidV7(),
      entityType: 'batch',
      entityId: 'session_demo',
      version: RUN_VERSION,
      payload: {
        dishTitleEn: 'Khasi ko Masu',
        dishTitleNe: 'खसीको मासु',
        currentWhistles: 2,
        targetWhistles: 4,
        currentStepIndex: 1,
        updatedAt: Date.now(),
        stepsEn: [
          'Wash and trim the meat',
          'Fry spices with ghee',
          'Add water and pressure cook',
          'Let the pressure release naturally',
        ],
        stepsNe: [
          'मासु सफा गरी काट्नुहोस्',
          'घिउमा मसला कार्नुहोस्',
          'पानी हालेर कुकरमा पकाउनुहोस्',
          'बाफ आफैँ निस्कन दिनुहोस्',
        ],
      },
    },
    ...[
      ['Coriander Seeds', 'धनियाँको गेडा', '100g', true],
      ['Mustard Oil', 'तोरीको तेल', '1L', true],
      ['Salt', 'नुन', '1 pkt', true],
      ['Cauliflower', 'काउली', '2 kg', false],
      ['Fresh Ginger', 'अदुवा', '200g', false],
      ['Tomato', 'भण्डा', '1 kg', false],
    ].map(([nameEn, nameNe, quantityStr, isCompleted], index) => ({
      id: uuidV7(),
      entityType: 'grocery_item',
      entityId: `grocery_${index + 1}`,
      version: RUN_VERSION,
      payload: { nameEn, nameNe, quantityStr, isCompleted },
    })),
  ];

  const sync = await post(
    '/v1/sync',
    { householdId, changes },
    headers,
  );
  console.log(
    `  synced: applied=${sync.applied} conflicts=${sync.conflicts.length}`,
  );
  if (sync.conflicts.length > 0) {
    for (const conflict of sync.conflicts) {
      console.error(
        `    conflict ${conflict.entityType}:${conflict.entityId} — ${conflict.reason}`,
      );
    }
    throw new Error(
      `${sync.conflicts.length} change(s) were rejected; the dataset is incomplete.`,
    );
  }

  const feed = await get('/v1/displays/feed', headers);
  console.log('\nFeed preview:');
  console.log(`  meals:        ${feed.todaysMeals.totalPlannedMeals} planned`);
  console.log(
    `  active siti:  ${feed.activeSiti ? `${feed.activeSiti.currentWhistles}/${feed.activeSiti.targetWhistles} whistles` : 'none'}`,
  );
  console.log(
    `  grocery:      ${feed.groceryChecklist.completedItems}/${feed.groceryChecklist.totalItems} done`,
  );
  console.log(`  etag:         ${feed.etag}`);

  const revalidated = await get('/v1/displays/feed', {
    ...headers,
    'If-None-Match': feed.etag,
  });
  console.log(
    `  revalidate:   ${revalidated.notModified ? '304 not modified (no payload bytes)' : 'unexpected 200'}`,
  );

  console.log(`\nHousehold token for manual testing:`);
  console.log(`  ${token}`);
}

main().catch((err) => {
  console.error(`\nSeed failed: ${err.message}`);
  console.error(`Is the API running at ${baseUrl}? Start it with: pnpm --filter @siti-counter/api dev`);
  process.exit(1);
});