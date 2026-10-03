import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const tokensDir = path.join(__dirname, 'tokens')
const distDir = path.join(__dirname, 'dist')

if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir, { recursive: true })
}

// 1. Load and merge all tokens
const tokenFiles = fs.readdirSync(tokensDir).filter(f => f.endsWith('.json'))
const tokens = {}

for (const file of tokenFiles) {
  const content = JSON.parse(fs.readFileSync(path.join(tokensDir, file), 'utf8'))
  Object.assign(tokens, content)
}

// 2. Generate CSS Variables
function generateCss(tokens) {
  let css = `/**
 * Siti Counter 3.0 — Generated Design Tokens
 * Source: W3C Design Tokens JSON
 */

:root {\n`

  function walk(obj, prefix = '') {
    for (const [key, item] of Object.entries(obj)) {
      if (item && typeof item === 'object') {
        if ('value' in item) {
          const varName = `--siti-${prefix}${key}`.replace(/([A-Z])/g, '-$1').toLowerCase()
          css += `  ${varName}: ${item.value};\n`
        } else {
          walk(item, `${prefix}${key}-`)
        }
      }
    }
  }

  walk(tokens)
  css += `}\n`
  return css
}

// 3. Generate TypeScript Constants
function generateTypeScript(tokens) {
  return `/**
 * Siti Counter 3.0 — Generated Design Tokens (TypeScript)
 */

export const SitiTokens = ${JSON.stringify(tokens, null, 2)} as const;

export type SitiTokensType = typeof SitiTokens;
`
}

// 4. Generate Dart Theme Constants for Flutter
function generateDart(tokens) {
  return `/// Siti Counter 3.0 — Generated Design Tokens (Dart / Flutter)
/// Generated from W3C Design Tokens JSON. Do not edit manually.
library;

import 'package:flutter/material.dart';

class SitiColors {
  // Brand & Accents
  static const Color terracotta = Color(0xFFD95328);
  static const Color terracottaDark = Color(0xFFB9421E);
  static const Color freshGreen = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color alert = Color(0xFFD32F2F);

  // Backgrounds
  static const Color warmWhite = Color(0xFFFAF9F6);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color dark = Color(0xFF1A1A1A);
  static const Color cardDark = Color(0xFF242424);
}

class SitiSpacing {
  static const double touchTargetMin = 48.0;
  static const double displayTouchTargetMin = 64.0;

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class SitiRadius {
  static const double none = 0.0;
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 9999.0;

  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(xl));
}

class SitiTypography {
  // Siti Counter font sizes for distance viewing
  static const double counterNear = 56.0;       // Phone handheld (<1m)
  static const double counterArmsLength = 80.0; // Kitchen counter (1-2m)
  static const double counterAcrossRoom = 120.0;// Smart display across room (>2m)

  static const TextStyle counterNearStyle = TextStyle(
    fontSize: counterNear,
    fontWeight: FontWeight.w800,
    color: SitiColors.terracotta,
  );

  static const TextStyle counterArmsLengthStyle = TextStyle(
    fontSize: counterArmsLength,
    fontWeight: FontWeight.w900,
    color: SitiColors.terracotta,
  );
}
`
}

// 5. Build and Write files
const cssContent = generateCss(tokens)
const tsContent = generateTypeScript(tokens)
const dartContent = generateDart(tokens)

fs.writeFileSync(path.join(distDir, 'tokens.css'), cssContent)
fs.writeFileSync(path.join(distDir, 'tokens.ts'), tsContent)
fs.writeFileSync(path.join(distDir, 'tokens.dart'), dartContent)

console.log('✓ Generated dist/tokens.css, dist/tokens.ts, dist/tokens.dart')

// 6. Sync to Flutter mobile and Vue web apps
const flutterThemeDir = path.join(__dirname, '../../apps/mobile/lib/theme')
if (!fs.existsSync(flutterThemeDir)) {
  fs.mkdirSync(flutterThemeDir, { recursive: true })
}
fs.writeFileSync(path.join(flutterThemeDir, 'tokens.dart'), dartContent)
console.log('✓ Synced to apps/mobile/lib/theme/tokens.dart')

const vueSrcDir = path.join(__dirname, '../../apps/web/src')
if (fs.existsSync(vueSrcDir)) {
  fs.writeFileSync(path.join(vueSrcDir, 'tokens.css'), cssContent)
  console.log('✓ Synced to apps/web/src/tokens.css')
}
