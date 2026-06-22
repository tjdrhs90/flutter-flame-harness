---
name: flame-harness-design
description: Phase 3 — define the Flutter design_tokens.dart spec (palette, typography, spacing), the game's art/visual concept, and the asset/audio sourcing plan.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---

# flame-harness-design

Phase 3 of the flutter-flame-harness pipeline. Reads the latest PRD and `config.md`, then
produces a design document that specifies the `lib/ui/design_tokens.dart` constants, the
game's visual/art concept, and the asset and audio sourcing plan (including launcher icon and
splash screen intent). Advances pipeline state to `contract`.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) and the phase transition table
are defined in `docs/harness-protocol.md` — refer to that document as the single source of
truth (§2 for `state.md` schema; §7 for the `design → contract` transition). Do not redefine
schemas here.

---

## Input

### 1. Read `docs/harness/config.md`

Extract:

| Key | Use |
|---|---|
| `app_idea` | Informs visual tone (action vs. casual vs. puzzle) |
| `app_name` | Used in splash screen heading and icon badge |
| `app_slug` | Used to derive asset directory naming conventions |
| `default_language` | Should be `ko`; confirm before writing copy samples |

If `config.md` does not exist, abort with:
`flame-harness-design: docs/harness/config.md not found — run the orchestrator to bootstrap first.`

### 2. Read the latest PRD

Find the most recent file matching `docs/harness/plans/*-prd.md` (sort descending by filename,
take the first). If no PRD exists, abort with:
`flame-harness-design: no PRD found in docs/harness/plans/ — run flame-harness-plan first.`

Extract from the PRD:

- **Genre & core mechanic** — informs colour mood (e.g., dark sci-fi vs. bright hyper-casual)
- **Target age / tone** — age rating and energy level of the visual style
- **Monetisation hook** — AdMob placement type (banner at bottom → affects HUD spacing)
- **Win/lose conditions** — informs what UI states need distinct visual treatment

---

## Design tokens

Write a specification for `lib/ui/design_tokens.dart` that a generator phase Claude can
implement verbatim as `const` Dart values. The spec must cover every sub-section below.

### Colour palette

Derive a palette from the genre and tone. Use the following template — replace every
`<...>` with a real hex colour and rationale:

```
Primary       <#RRGGBB>  — main brand / call-to-action colour
PrimaryDark   <#RRGGBB>  — pressed / shadow state of primary
Accent        <#RRGGBB>  — highlights, score text, power-up glows
Background    <#RRGGBB>  — game canvas and screen background
Surface       <#RRGGBB>  — card, dialog, overlay background
OnBackground  <#RRGGBB>  — text / icon colour on background
OnSurface     <#RRGGBB>  — text / icon colour on surface
Error         <#RRGGBB>  — error states, health loss flash
```

Rules:
- Minimum contrast ratio of 4.5:1 for any text colour against its background.
- Background and Primary must share the same temperature (both warm or both cool).
- Accent must differ from Primary by at least 60° of hue to provide visual pop.
- For dark-themed games (sci-fi, horror) set Background ≤ `#333333`; for bright
  hyper-casual games set Background ≥ `#E0E0E0`.

### Typography scale

Specify font family, weight, and size for each role. If the game uses a custom font,
name the Google Font and its import path; otherwise default to `Roboto`.

```
Display   family: <FontName>  weight: 900  size: 48 sp  — game title on main menu
Heading1  family: <FontName>  weight: 700  size: 32 sp  — screen headings
Heading2  family: <FontName>  weight: 700  size: 24 sp  — section headings, score
Body      family: <FontName>  weight: 400  size: 16 sp  — general UI text
Caption   family: <FontName>  weight: 400  size: 12 sp  — labels, tooltips
Button    family: <FontName>  weight: 600  size: 18 sp  — primary buttons
HUD       family: <FontName>  weight: 700  size: 20 sp  — in-game HUD counters
```

Use `sp` (Flutter `TextScaler`-aware) for all sizes. Game HUD text should use
`fontFeatures: [FontFeature.tabularFigures()]` for score counters.

### Spacing scale

Define a base unit and derive the full spacing scale. Typical base is 4 dp:

```
xs:   4 dp   — tight padding (icon labels)
sm:   8 dp   — inner card padding
md:  16 dp   — standard screen margin
lg:  24 dp   — section gap
xl:  32 dp   — screen top/bottom padding
xxl: 48 dp   — hero area padding
```

All layout constants in `design_tokens.dart` use these named values — no raw numbers in
UI code. Spacing values are applied as `const double` fields.

### Radius and elevation

```
radiusSm:   4 dp   — chip, small badge
radiusMd:   8 dp   — card, dialog
radiusLg:  16 dp   — bottom sheet, hero card
radiusFull: 999 dp — pill buttons

elevationSurface:  2 dp
elevationDialog:   8 dp
elevationFab:     12 dp
```

### `design_tokens.dart` file template

The generator must emit a file with this exact structure:

```dart
// lib/ui/design_tokens.dart
// AUTO-GENERATED by flame-harness-design — do not edit manually.
// See docs/harness/plans/<date>-design.md for rationale.

import 'package:flutter/material.dart';

abstract class DesignTokens {
  // --- Colours ---
  static const Color primary       = Color(0xFF______);
  static const Color primaryDark   = Color(0xFF______);
  static const Color accent        = Color(0xFF______);
  static const Color background    = Color(0xFF______);
  static const Color surface       = Color(0xFF______);
  static const Color onBackground  = Color(0xFF______);
  static const Color onSurface     = Color(0xFF______);
  static const Color error         = Color(0xFF______);

  // --- Spacing ---
  static const double spaceXs  =  4;
  static const double spaceSm  =  8;
  static const double spaceMd  = 16;
  static const double spaceLg  = 24;
  static const double spaceXl  = 32;
  static const double spaceXxl = 48;

  // --- Radius ---
  static const double radiusSm   =   4;
  static const double radiusMd   =   8;
  static const double radiusLg   =  16;
  static const double radiusFull = 999;

  // --- Elevation ---
  static const double elevationSurface = 2;
  static const double elevationDialog  = 8;
  static const double elevationFab     = 12;

  // --- Typography helpers ---
  static const String fontFamily = '______';
}
```

Fill every `______` from the palette and typography spec written above.

---

## Visual concept

### Art direction

Describe the overall visual style in 3–5 sentences covering:

1. **Art style** — pixel art / vector flat / hand-drawn / 3-D rendered sprites
2. **Colour mood** — how the palette reinforces the genre's emotional tone
3. **World / environment** — background theme (city, space, forest, dungeon, etc.)
4. **Character / enemy design** — silhouette language (cute rounded vs. angular menacing)
5. **UI chrome style** — whether overlays feel like HUD panels, storybook pages, arcade
   bezels, etc.

The description must be concrete enough that a sprite artist (or an AI image prompt)
could reproduce the style without further guidance.

### Sprite list (MVP)

List every sprite needed for the MVP core loop. For each sprite, specify:

| Sprite | Dimensions (dp) | Frames | Source |
|---|---|---|---|
| Player idle | 64×64 | 4 | <see Asset plan below> |
| Player run  | 64×64 | 8 | — |
| Enemy A     | 48×48 | 4 | — |
| Background layer 1 | screen width × 256 | 1 | — |
| ... | ... | ... | ... |

Dimensions are in dp at 1× scale; the asset pipeline should export at 1×, 2×, and 3×.

### Overlay and HUD layout

Describe the layout of each Flutter overlay:

- **Main menu** — what elements are visible and their rough positions
- **In-game HUD** — score, lives/health, pause button placement
- **Pause overlay** — resume, restart, settings
- **Game-over screen** — score, best score, restart, AdMob rewarded-ad revival button
- **Settings screen** — BGM toggle, SFX toggle, language toggle

Each description maps directly to a Flutter widget in `lib/screens/` or `lib/ui/`.

---

## Asset/audio plan

### Sprite and image assets

State for each visual asset whether it will be:

| Strategy | When to use |
|---|---|
| **Free pack** (itch.io / OpenGameArt / Kenney.nl) | Hyper-casual games, generic shapes |
| **AI-generated** (Midjourney / DALL-E prompt) | Custom style with specific prompt given |
| **Custom drawn** | Unique brand-critical characters |

For every free pack named, provide the pack URL and its license (CC0, CC-BY, etc.).
For AI-generated assets, write the exact prompt template to use (substituting `<genre>`
and `<style>` from the art direction above).

Assets must be declared in `pubspec.yaml` under `flutter: assets:`. Provide the
directory entry (e.g., `assets/images/`) not individual file names — so that adding
sprites does not require `pubspec.yaml` edits.

### Audio assets

| Sound | Type | Source | License |
|---|---|---|---|
| Background music | loop (60–90 s) | <free pack URL or AI prompt> | <license> |
| Jump / tap SFX   | one-shot (< 1 s) | — | — |
| Hit / damage SFX | one-shot | — | — |
| Level complete   | jingle (3–5 s) | — | — |
| Game over        | sting (2–4 s) | — | — |

Recommended free sources: `freesound.org` (CC0 filter), `opengameart.org` audio section,
`itch.io` free audio packs.

Audio files go in `assets/audio/`. Add `assets/audio/` as a top-level assets entry in
`pubspec.yaml`.

Package: `flame_audio` (wraps `audioplayers`). BGM uses `FlameAudio.bgm.play()`; SFX
uses `FlameAudio.play()`.

### flutter_launcher_icons

Specify the icon intent so the generator can configure `flutter_launcher_icons`:

```yaml
# pubspec.yaml excerpt (dev_dependencies)
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/icon.png"          # 1024×1024 PNG, no alpha on Android
  adaptive_icon_background: "<hex colour>"     # Android adaptive icon background
  adaptive_icon_foreground: "assets/icons/icon-fg.png"  # foreground layer
  min_sdk_android: 21
  web:
    generate: false
```

The icon must:
- Be 1024×1024 pixels, PNG format.
- Follow the app's art direction (character portrait or logo on the `Primary` background).
- Android adaptive icon: foreground layer uses character/logo; background uses `Primary`.

### flutter_native_splash

Specify the splash screen intent for `flutter_native_splash`:

```yaml
# pubspec.yaml excerpt
flutter_native_splash:
  color: "<Background hex>"          # matches DesignTokens.background
  image: assets/images/splash.png    # centred logo/character, 288×288 px recommended
  android_12:
    color: "<Background hex>"
    image: assets/images/splash.png
    icon_background_color: "<Primary hex>"
  ios: true
  android: true
  web: false
```

The splash image must:
- Be 288×288 pixels, PNG with transparent background.
- Show the app logo or the main character on a transparent field.
- Feel consistent with the main menu's visual style.

---

## Output

### 1. Write the design document

Create `docs/harness/plans/<YYYY-MM-DD>-design.md` (use today's UTC date).

If `docs/harness/plans/` does not exist, create it before writing.

The document must include all of the following sections (downstream validators grep for these
headings):

- `## Design tokens` — with palette table, typography scale, spacing scale
- `## Visual concept` — with art direction, sprite list, overlay/HUD layout
- `## Asset/audio plan` — with sprite sourcing table, audio table, `flutter_launcher_icons`
  config, `flutter_native_splash` config

Fill every section from the PRD and `config.md`; do not leave placeholder text.

### 2. Update `state.md`

Update `docs/harness/state.md` per `docs/harness-protocol.md` §2 and the transition rule
in §7 (`design` → `contract`). Per §7 rule 2, a skill that completes successfully and
advances the pipeline sets `status: running` together with `current_phase` and `next_role`
in the same atomic write:

```yaml
status: running
current_phase: design
next_role: contract
updated_at: "<ISO-8601 UTC now>"
```

Leave all other keys unchanged. Use `Edit` for a targeted update.

### 3. Append to `pipeline-log.md`

Append one row to `docs/harness/pipeline-log.md` per `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | complete | design | design_tokens spec written; next: contract |
```

---

## Error handling

- If the PRD is missing or empty, abort with a clear message and set `state.md` to
  `status: paused`, `pause_reason: manual_action`.
- If `config.md` cannot be read, abort immediately (do not write partial output).
- If the genre or tone cannot be determined from the PRD, choose a neutral palette
  (dark background `#1A1A2E`, bright accent `#E94560`) and note the assumption in the
  design document under a `## Assumptions` heading.
