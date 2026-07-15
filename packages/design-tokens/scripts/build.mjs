// NOCTA design-tokens build — tek kaynak tokens.json → CSS vars + Tailwind preset + Dart theme.
// docs/06 (token kaynağı) ve docs/01 §3 (Style Dictionary) uyarınca. Elle çıktı düzenlemek yasak.
import StyleDictionary from 'style-dictionary';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { copyFileSync, existsSync, mkdirSync } from 'node:fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

/** color.bg.base → --color-bg-base */
const cssVar = (path) => `--${path.join('-')}`;
/** color.bg.base → bgBase ; font.size.h1 → h1 (grup bazında) */
const camel = (parts) =>
  parts
    .map((p, i) => (i === 0 ? p : p.charAt(0).toUpperCase() + p.slice(1)))
    .join('')
    .replace(/-([a-z])/g, (_, c) => c.toUpperCase());

const isLight = (t) => t.path[0] === 'color' && t.path[1] === 'light';
const hexToDart = (hex) => {
  const h = hex.replace('#', '').toUpperCase();
  return `Color(0xFF${h})`;
};
const pxToNum = (v) => Number(String(v).replace('px', '')) || 0;

// --- CSS: :root (dark) + :root[data-theme='light'] override ---------------------------------
StyleDictionary.registerFormat({
  name: 'nocta/css',
  format: ({ dictionary }) => {
    const root = dictionary.allTokens
      .filter((t) => !isLight(t))
      .map((t) => `  ${cssVar(t.path)}: ${t.value};`)
      .join('\n');
    const lightBg = dictionary.allTokens.find((t) => isLight(t) && t.path[2] === 'bg');
    const lightInk = dictionary.allTokens.find((t) => isLight(t) && t.path[2] === 'ink');
    const light = [
      lightBg ? `  --color-bg-base: ${lightBg.value};` : '',
      lightInk ? `  --color-ink-primary: ${lightInk.value};` : '',
    ]
      .filter(Boolean)
      .join('\n');
    return (
      `/* GENERATED — tokens.json'dan üretildi, elle düzenleme. */\n` +
      `:root {\n${root}\n}\n\n` +
      `/* Light tema yalnızca marketing + admin (docs/06). Mobil uygulama dark-only. */\n` +
      `:root[data-theme='light'] {\n${light}\n}\n`
    );
  },
});

// --- Tailwind preset (CSS var referanslı → tema data-theme ile çalışır) ----------------------
StyleDictionary.registerFormat({
  name: 'nocta/tailwind',
  format: ({ dictionary }) => {
    const colors = {};
    const spacing = {};
    const radius = {};
    const fontFamily = {};
    const fontSize = {};
    const lineByKey = {};
    for (const t of dictionary.allTokens) {
      const [group, ...rest] = t.path;
      if (group === 'color') {
        if (t.path[1] === 'light') continue;
        if (t.path[1] === 'archetype') continue; // gradyanlar Tailwind color değil
        colors[rest.join('-')] = `var(${cssVar(t.path)})`;
      } else if (group === 'space') {
        spacing[rest.join('-')] = t.value;
      } else if (group === 'radius') {
        radius[rest.join('-')] = t.value;
      } else if (group === 'font' && rest[0] === 'family') {
        fontFamily[rest[1]] = t.value.split(',').map((s) => s.trim());
      } else if (group === 'font' && rest[0] === 'size') {
        fontSize[rest[1]] = t.value;
      } else if (group === 'font' && rest[0] === 'line') {
        lineByKey[rest[1]] = t.value;
      }
    }
    const fontSizeWithLine = {};
    for (const [k, v] of Object.entries(fontSize)) {
      fontSizeWithLine[k] = lineByKey[k] ? [v, { lineHeight: lineByKey[k] }] : v;
    }
    const preset = {
      theme: {
        extend: {
          colors,
          spacing,
          borderRadius: radius,
          fontFamily,
          fontSize: fontSizeWithLine,
        },
      },
    };
    return (
      `// GENERATED — tokens.json'dan üretildi, elle düzenleme.\n` +
      `/** @type {import('tailwindcss').Config} */\n` +
      `module.exports = ${JSON.stringify(preset, null, 2)};\n`
    );
  },
});

// --- Dart theme (mobil, dark-first) ----------------------------------------------------------
StyleDictionary.registerFormat({
  name: 'nocta/dart',
  format: ({ dictionary }) => {
    const colorLines = [];
    const archetype = {};
    const spaceLines = [];
    const radiusLines = [];
    const fontSizeLines = [];
    for (const t of dictionary.allTokens) {
      const [group] = t.path;
      if (group === 'color') {
        if (t.path[1] === 'light') continue;
        if (t.path[1] === 'archetype') {
          const name = camel([t.path[2]]);
          archetype[name] ??= {};
          archetype[name][t.path[3]] = hexToDart(t.value);
          continue;
        }
        const name = camel(t.path.slice(1));
        colorLines.push(`  static const Color ${name} = ${hexToDart(t.value)};`);
      } else if (group === 'space') {
        spaceLines.push(`  static const double s${t.path[1]} = ${pxToNum(t.value)};`);
      } else if (group === 'radius') {
        radiusLines.push(`  static const double ${camel([t.path[1]])} = ${pxToNum(t.value)};`);
      } else if (group === 'font' && t.path[1] === 'size') {
        fontSizeLines.push(`  static const double ${camel([t.path[2]])} = ${pxToNum(t.value)};`);
      }
    }
    const gradients = Object.entries(archetype)
      .map(
        ([name, v]) =>
          `  static const LinearGradient ${name} = LinearGradient(\n` +
          `    begin: Alignment.topLeft, end: Alignment.bottomRight,\n` +
          `    colors: [${v.from}, ${v.to}],\n  );`,
      )
      .join('\n');
    return `// GENERATED — packages/design-tokens/tokens.json'dan üretildi. Elle düzenleme.
// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';

/// NOCTA renk token'ları (dark-first — uygulama gece yaşar).
class NoctaColors {
  NoctaColors._();
${colorLines.join('\n')}
}

/// Archetype gradyanları — yalnızca kimlik kartı, rapor başlığı, archetype vurgusu.
class NoctaArchetypeGradient {
  NoctaArchetypeGradient._();
${gradients}
}

/// Boşluk ölçeği (4px birim).
class NoctaSpace {
  NoctaSpace._();
${spaceLines.join('\n')}
}

/// Köşe yarıçapları.
class NoctaRadius {
  NoctaRadius._();
${radiusLines.join('\n')}
}

/// Tipografi ölçeği (punto).
class NoctaFontSize {
  NoctaFontSize._();
${fontSizeLines.join('\n')}
}

/// Uygulamanın dark tema ThemeData'sı — token'lardan üretilir.
ThemeData buildNoctaDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: NoctaColors.bgBase,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: NoctaColors.accentAurora,
      secondary: NoctaColors.accentDeep,
      surface: NoctaColors.bgRaised,
      error: NoctaColors.danger,
      onSurface: NoctaColors.inkPrimary,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: NoctaColors.inkPrimary,
      displayColor: NoctaColors.inkPrimary,
      fontFamily: 'Inter',
    ),
  );
}
`;
  },
});

const sd = new StyleDictionary({
  source: [resolve(ROOT, 'tokens.json')],
  platforms: {
    css: {
      transforms: ['attribute/cti'],
      buildPath: 'build/css/',
      files: [{ destination: 'tokens.css', format: 'nocta/css' }],
    },
    tailwind: {
      transforms: ['attribute/cti'],
      buildPath: 'build/tailwind/',
      files: [{ destination: 'preset.cjs', format: 'nocta/tailwind' }],
    },
    dart: {
      transforms: ['attribute/cti'],
      buildPath: 'build/dart/',
      files: [{ destination: 'nocta_tokens.dart', format: 'nocta/dart' }],
    },
  },
  log: { verbosity: 'silent' },
});

await sd.buildAllPlatforms();

// Dart çıktısını Flutter uygulamasına da kopyala (mobil pnpm workspace dışında).
const mobileDir = resolve(ROOT, '..', '..', 'apps', 'mobile', 'lib', 'core', 'design_system', 'generated');
if (existsSync(resolve(ROOT, '..', '..', 'apps', 'mobile'))) {
  mkdirSync(mobileDir, { recursive: true });
  copyFileSync(
    resolve(ROOT, 'build', 'dart', 'nocta_tokens.dart'),
    resolve(mobileDir, 'nocta_tokens.dart'),
  );
  console.warn('[design-tokens] Dart token → apps/mobile/.../generated/nocta_tokens.dart');
}

console.warn('[design-tokens] build tamam → build/{css,tailwind,dart}');
