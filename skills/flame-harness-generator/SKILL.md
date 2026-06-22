---
name: flame-harness-generator
description: Phase 5 — build the Flame game in 3 gated sub-phases (core loop → systems+components → UI+content), then self-evaluate against the contract.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep]
---

# flame-harness-generator

Phase 5 of the flutter-flame-harness pipeline. Builds the Flame game in three gated
sub-phases (5a → 5b → 5c). Each sub-phase ends with a HARD GATE (`flutter analyze` zero
issues + `flutter test` all pass) before the next sub-phase begins. On round N > 1, reads
the previous evaluator feedback and fixes only the listed failures.

All file schemas (`config.md`, `state.md`, `handoff/round-N-gen.md`, `feedback/round-N-qa.md`)
and the phase transition table are defined in `docs/harness-protocol.md` — that document is
the single source of truth (§2 for `state.md` schema; §4 for handoff layout; §5 for feedback
layout; §7 for the `generator → evaluator` transition). Do not redefine schemas here.

---

## Round Handling and Feedback Intake

### Determine current round

Read `docs/harness/state.md`. Extract `current_round` (integer, ≥ 1).

### Round 1 — build from scratch

When `current_round` is 1:

1. Read `docs/harness/config.md` (extract `app_slug`, `app_name`, `bundle_id`,
   `default_language`, `skip_admob`).
2. Read the latest PRD (`docs/harness/plans/*-prd.md`, sort descending, take first).
3. Read the latest design doc (`docs/harness/plans/*-design.md`, sort descending, take first).
4. Read `docs/harness/contract.md`. Confirm `## Status: AGREED` is present; abort with
   `flame-harness-generator: contract not AGREED — run flame-harness-contract first` if missing.
5. Proceed to Sub-phase 5a.

### Round N > 1 — fix only listed failures (feedback intake)

When `current_round` is greater than 1:

1. Read `docs/harness/feedback/round-<N-1>-qa.md` (per `docs/harness-protocol.md` §5 layout).
2. Parse the `## Failed Criteria` section to extract each failing criterion and its prescribed fix.
3. Do NOT redesign or refactor areas that were not listed as failures. Make only the minimum
   changes required to satisfy the listed fixes.
4. If `docs/harness/feedback/round-<N-1>-qa.md` does not exist, abort with:
   `flame-harness-generator: feedback file for round <N-1> not found — cannot determine fixes`.
5. Apply each fix, then run the HARD GATE for the affected sub-phase before writing the handoff.

---

## Sub-phase 5a — Scaffold + Core Loop

### 5a.1 Create the Flutter project (flutter create)

Run `flutter create` at the project root path derived from `app_slug`:

```bash
flutter create --org com.gonigon --project-name <app_slug> \
  /Users/ssg/AndroidStudioProjects/<app_slug>
```

Replace `<app_slug>` with the value from `config.md`.

**Important (per `docs/harness-protocol.md`):** After `flutter create` succeeds, move the
`docs/harness/` directory into the game project so all artifacts share one repository:

```bash
mv /Users/ssg/AndroidStudioProjects/flutter-flame-harness/docs/harness \
   /Users/ssg/AndroidStudioProjects/<app_slug>/docs/harness
```

All subsequent reads/writes of harness files use the new path inside the game project.

### 5a.2 Remove default template files

Delete the generated counter demo to start from a clean slate:

```bash
rm /Users/ssg/AndroidStudioProjects/<app_slug>/lib/main.dart
rm /Users/ssg/AndroidStudioProjects/<app_slug>/test/widget_test.dart
```

These files will be replaced by the game implementation below.

### 5a.3 Configure pubspec.yaml

Set the following fields in `pubspec.yaml`:

- `name`: `<app_slug>` (from `config.md`)
- `description`: `<app_name>` (from `config.md`)
- `publish_to: none`

Add to `dependencies` (use the latest compatible versions; minimum versions shown):

```yaml
dependencies:
  flutter:
    sdk: flutter
  flame: ^1.37.0
  flame_audio: ^2.0.0
  google_mobile_ads: ^5.0.0
  shared_preferences: ^2.0.0
```

Add asset directories to `flutter:`:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/audio/
    - assets/icons/
```

Run `flutter pub get` and confirm it exits 0.

### 5a.4 Create the lib/ directory structure

Create the following directories (and `assets/` directories):

```
lib/
  game/
    components/
    systems/
    data/
  screens/
  ui/
  l10n/
assets/
  images/
  audio/
  icons/
```

This structure matches the PRD's `lib/` layout.

### 5a.5 game_config.dart — all tuning constants

Create `lib/game/game_config.dart`. This file must centralize every tuning constant that
affects gameplay (speeds, spawn rates, scores, timings, physics). No magic numbers are
permitted in any other game file — all values must reference a constant in `GameConfig`.

Template:

```dart
// lib/game/game_config.dart
// All tuning constants for <app_name>. Edit here to tweak gameplay — do not
// hard-code numbers elsewhere.

abstract class GameConfig {
  // Screen / world
  static const double worldWidth  = 360.0;
  static const double worldHeight = 640.0;

  // Player
  static const double playerSpeed     = 200.0;
  static const double playerJumpForce = 500.0;

  // Scoring
  static const int scorePerEnemy    = 10;
  static const int scorePerDistance = 1;

  // Difficulty
  static const double initialSpawnInterval = 2.0;   // seconds
  static const double minSpawnInterval     = 0.4;
  static const double difficultyRampRate   = 0.02;  // per second

  // Audio
  static const double bgmVolume = 0.6;
  static const double sfxVolume = 0.9;

  // AdMob (non-credential tuning only — IDs come from config.md)
  static const int adShowIntervalSeconds = 120;
}
```

Fill all values from the PRD's game-mechanics section. Add more constants as needed; remove
any that the specific game does not use.

### 5a.6 GameState enum

Create `lib/game/game_state.dart`:

```dart
// lib/game/game_state.dart
enum GameState {
  menu,
  playing,
  paused,
  gameOver,
  // Add states as the PRD requires (e.g. levelComplete, shop)
}
```

### 5a.7 FlameGame subclass

Create `lib/game/<app_slug>_game.dart`. This is the root `FlameGame` (or `FlameGame` with
`HasCollisionDetection` when the PRD requires collision detection). Do **not** add the removed
`HasTappables` mixin — it was dropped in Flame 1.7 and will cause a compile error. Tap input is
handled via `TapCallbacks` on individual components (see §5a.8). It must:

- Declare `GameState _state = GameState.menu;` and a getter `GameState get state`.
- Expose `void startGame()`, `void pauseGame()`, `void resumeGame()`, `void gameOver()` methods
  that transition `_state` and show/hide Flutter overlays by name.
- Override `onLoad()` to load assets and add the background component.
- Register all overlay names needed by screens (e.g. `'menu'`, `'hud'`, `'pause'`, `'gameOver'`).

### 5a.8 Input handling

Wire up the input method specified in the PRD:

- Tap/click → `TapCallbacks` mixin on the player component (preferred for mobile).
- Drag → `DragCallbacks` mixin.
- Keyboard → `KeyboardEvents` mixin on the game class.

### 5a.9 main.dart entry point

Create `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/<app_slug>_game.dart';
// import overlay screens here in 5c

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
  runApp(GameWidget(game: <AppSlugGame>()));
}
```

Replace `<AppSlugGame>` with the actual class name.

### 5a.10 Minimal passing test

Create `test/game_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:<app_slug>/game/game_config.dart';

void main() {
  test('GameConfig constants are positive', () {
    expect(GameConfig.worldWidth,  greaterThan(0));
    expect(GameConfig.worldHeight, greaterThan(0));
    expect(GameConfig.bgmVolume,   inInclusiveRange(0.0, 1.0));
    expect(GameConfig.sfxVolume,   inInclusiveRange(0.0, 1.0));
  });
}
```

### 5a HARD GATE

After completing steps 5a.1–5a.10, run both commands and confirm both exit 0 before
proceeding to Sub-phase 5b:

```bash
cd /Users/ssg/AndroidStudioProjects/<app_slug>
flutter analyze
flutter test
```

`flutter analyze` must report **0 issues**. `flutter test` must report **0 failures**.

**If either command fails, fix all reported issues before proceeding. Do not start 5b until
this gate is green.**

---

## Sub-phase 5b — Systems and Components

Sub-phase 5b implements all game entities, systems, and data catalogs as specified in the PRD.
Start only after the 5a HARD GATE passes.

### 5b.1 Player component

Create `lib/game/components/player_component.dart`. The player component must:

- Extend `SpriteAnimationComponent` (or `SpriteComponent` for static sprites).
- Implement input callbacks from 5a.8.
- Use constants from `GameConfig` for speed, jump force, and any other tunable values.
- Include a hitbox for collision detection if the PRD requires it.

### 5b.2 Enemy / obstacle components

For each enemy or obstacle type named in the PRD, create a separate file under
`lib/game/components/`. Each component:

- Extends `SpriteAnimationComponent` or `SpriteComponent`.
- Uses `GameConfig` constants for speed and behaviour parameters.
- Calls a callback on collision.

### 5b.3 Spawning system

Create `lib/game/systems/spawn_system.dart`. This system:

- Reads spawn intervals and difficulty parameters from `GameConfig`.
- Implements the difficulty ramp defined in the PRD (increase spawn rate over time).
- Is registered on the game class with `add(SpawnSystem())`.
- Draws entity definitions from the data catalog (see 5b.6).

### 5b.4 Collision system

Create `lib/game/systems/collision_system.dart` (or integrate via `CollisionCallbacks` on
each component if simpler). Handle:

- Player vs enemy/obstacle: trigger game over or reduce health as the PRD specifies.
- Player vs collectible: increment score and play SFX.

### 5b.5 Scoring system

Create `lib/game/systems/score_system.dart`. This system:

- Maintains the current score as an `int`.
- Exposes `void addScore(int points)` and `int get score`.
- Fires a callback or `ValueNotifier` update when score changes so the HUD can update.
- Persists the high score via `shared_preferences` (key: `highScore`).

### 5b.6 Audio system

Create `lib/game/systems/audio_system.dart`. This system:

- Initialises `FlameAudio.bgm` in `onLoad()`.
- Plays background music with `FlameAudio.bgm.play('bgm.mp3', volume: GameConfig.bgmVolume)`.
- Exposes `void playSfx(String name)` that calls `FlameAudio.play(name, volume: GameConfig.sfxVolume)`.
- Respects mute toggles stored in `shared_preferences` (keys: `bgmEnabled`, `sfxEnabled`).

### 5b.7 Difficulty system

Create `lib/game/systems/difficulty_system.dart`. This system:

- Tracks elapsed play time.
- Updates spawn interval and enemy speed using `GameConfig.difficultyRampRate` and
  `GameConfig.minSpawnInterval`.

### 5b.8 Data catalogs

Create data files under `lib/game/data/` for each data-driven element the PRD defines
(enemies, levels, waves, collectibles, shop items). Each catalog is a Dart list of plain
data objects. No enemy/level/wave values may be hardcoded in spawning or component logic —
all values must come from the catalog.

### 5b.9 Tests for systems

Add tests under `test/` for:

- `ScoreSystem.addScore` increments correctly.
- `DifficultySystem` increases spawn rate over time.
- Data catalog entries are non-empty and all numeric fields are positive.

### 5b HARD GATE

After completing steps 5b.1–5b.9, run:

```bash
cd /Users/ssg/AndroidStudioProjects/<app_slug>
flutter analyze
flutter test
```

`flutter analyze` must report **0 issues**. `flutter test` must report **0 failures**.

**If either command fails, fix all reported issues before proceeding. Do not start 5c until
this gate is green.**

---

## Sub-phase 5c — UI, Content, and Polish

Sub-phase 5c wires up all Flutter screens and overlays, adds l10n, applies design tokens,
and completes `shared_preferences` persistence. Start only after the 5b HARD GATE passes.

### 5c.1 Design tokens

Create `lib/ui/design_tokens.dart` from the design doc's `## Design tokens` section, using
the exact file template specified in the design doc. Every colour, spacing, and radius value
must come from this file — no raw hex or numeric literals in UI code.

### 5c.2 Flutter screens and overlays

For each screen the PRD requires, create a file under `lib/screens/`. Each screen is a
`StatefulWidget` or `StatelessWidget` that receives the game instance and calls its state
transition methods. Required screens (add or remove based on PRD):

| File | Overlay name | Trigger |
|---|---|---|
| `lib/screens/main_menu_screen.dart` | `'menu'` | game starts |
| `lib/screens/hud_screen.dart` | `'hud'` | game playing |
| `lib/screens/pause_screen.dart` | `'pause'` | pause button tapped |
| `lib/screens/game_over_screen.dart` | `'gameOver'` | player dies |
| `lib/screens/settings_screen.dart` | `'settings'` | settings button |

If the PRD defines a shop, add `lib/screens/shop_screen.dart` with overlay name `'shop'`.

Register all overlay builder functions in `main.dart`'s `GameWidget.overlayBuilderMap`.

### 5c.3 HUD widget

Create `lib/ui/hud.dart` (a Flutter widget overlay, not a Flame component). The HUD must
display the current score, health or lives (if the PRD defines them), and a pause button.
All sizes and colours use `DesignTokens` constants.

### 5c.4 KO/EN localisation

Create ARB files:

- `lib/l10n/app_ko.arb` — Korean strings (primary language).
- `lib/l10n/app_en.arb` — English strings.

Every user-visible string in every screen and overlay must have an ARB entry. No string
literals in widget code — use `AppLocalizations.of(context).<key>`.

Add to `pubspec.yaml`:

```yaml
flutter:
  generate: true

dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
```

Verify l10n is complete:

```bash
cd /Users/ssg/AndroidStudioProjects/<app_slug>
flutter gen-l10n
```

### 5c.5 shared_preferences persistence

Persist high score, BGM/SFX enabled flags, and any economy totals through a single
`PreferencesService` class. No raw `SharedPreferences` calls outside that class.

### 5c.6 AdMob wiring (if skip_admob is false in config.md)

If `skip_admob` is `false`:

- Initialise `MobileAds.instance.initialize()` in `main.dart` before `runApp`.
- Read AdMob app ID and ad unit IDs from `config.md` — never hardcode in Dart source.
- Implement a banner ad widget in `lib/ui/banner_ad_widget.dart`.
- Show the banner in the HUD overlay at the bottom.

### 5c.7 Anti-stub verification

Before the final HARD GATE, run:

```bash
grep -rn "TODO\|stub\|placeholder\|스텁\|미구현" \
  /Users/ssg/AndroidStudioProjects/<app_slug>/lib/ --include="*.dart"
```

If this command returns any output, fix or remove every match. The contract requires zero
stubs in game logic (per `docs/harness-protocol.md` §3, Hard Gate 3).

### 5c.8 Full tests

Add or expand tests to cover:

- Main menu renders without throwing.
- Game-over screen shows the correct score.
- Localisation: all required ARB keys are present in both `app_ko.arb` and `app_en.arb`.
- `PreferencesService` read/write round-trip (use a mock `SharedPreferences`).

### 5c HARD GATE

After completing steps 5c.1–5c.8, run:

```bash
cd /Users/ssg/AndroidStudioProjects/<app_slug>
flutter analyze
flutter test
```

`flutter analyze` must report **0 issues**. `flutter test` must report **0 failures**.

**This is the final gate. Do not write the handoff until both commands pass. If either fails,
fix all reported issues and re-run both commands.**

---

## Self-evaluation and Handoff

After the 5c HARD GATE passes, write the generator handoff and update pipeline state.

### Write handoff/round-N-gen.md

Create `docs/harness/handoff/round-<N>-gen.md` inside the game project, following the layout
defined in `docs/harness-protocol.md` §4:

```markdown
# Generator Handoff — Round <N>

## What Was Built / Fixed

<!-- Bullet list of features implemented (round 1) or bugs fixed (round N>1). -->

## Contract Self-Assessment

| Criterion | Status | Notes |
|---|---|---|
| flutter analyze zero errors          | DONE / PARTIAL / FAIL | … |
| flutter test zero failures           | DONE / PARTIAL / FAIL | … |
| No TODO/stub in game logic           | DONE / PARTIAL / FAIL | … |
| game_config.dart for all tuning      | DONE / PARTIAL / FAIL | … |
| Content defined as data              | DONE / PARTIAL / FAIL | … |
| KO + EN l10n complete                | DONE / PARTIAL / FAIL | … |
| Core loop end-to-end                 | DONE / PARTIAL / FAIL | … |
| Zero crashes on simulator            | DONE / PARTIAL / FAIL | … |
| <game-specific criterion>            | DONE / PARTIAL / FAIL | … |

## Test Results

\`\`\`
<last 20 lines of flutter analyze output>
\`\`\`

\`\`\`
<last 20 lines of flutter test output>
\`\`\`

## Environment Detection

- Flutter version: <output of `flutter --version`>
- Dart version: <from above>
- Device/emulator used for smoke test: <name>

## Known Issues

<!-- List any known issues or deferred items. State "none" if clean. -->
```

Fill every section with actual output and real assessments. Do not leave placeholder text.

### Update state.md

Update `docs/harness/state.md` per `docs/harness-protocol.md` §2 and the `generator → evaluator`
transition in §7. Per §7 rule 2, a successful phase completion sets `status: running` in the
same atomic write:

```yaml
status: running
current_phase: generator
next_role: evaluator
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_round`, `created_at`, `resume_attempts`, and all other keys unchanged. Use
`Edit` for a targeted update.

> **Note:** `current_round` is incremented by the evaluator when it returns FAIL; the generator reads it but does not write it.

### Append to pipeline-log.md

Append one row to `docs/harness/pipeline-log.md` per `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | handoff | generator | round <N> built; analyze 0; test 0; next: evaluator |
```

---

## Error handling

- If `contract.md` is missing or does not contain `## Status: AGREED`, abort immediately.
- If any HARD GATE fails (non-zero `flutter analyze` issues or failing tests), stop at that
  sub-phase, fix the failures, and re-run the gate. Do not advance to the next sub-phase.
- If the feedback file for round N-1 is missing on a round > 1 run, abort with a clear message
  and set `state.md` to `status: paused`, `pause_reason: manual_action`.
- If `flutter create` fails, abort immediately and do not proceed to 5a.3.
- If `flutter pub get` fails, check `pubspec.yaml` for version conflicts and resolve before
  continuing.
