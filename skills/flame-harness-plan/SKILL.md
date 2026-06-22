---
name: flame-harness-plan
description: Phase 2 — write a Korean game PRD (core loop, mechanics, content metrics, win/lose, scope guard), map the lib/ structure, and assign app name, slug, and bundle id.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---

# flame-harness-plan

Phase 2 of the flutter-flame-harness pipeline. Reads the research spec and `config.md`, then
produces a comprehensive Korean game PRD, maps the `lib/` directory structure, assigns the app
identity (`app_name`, `app_slug`, `bundle_id`), and advances the pipeline state to `design`.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) are defined in
`docs/harness-protocol.md` — refer to that document as the single source of truth. Do not
redefine schemas here.

---

## Input

### 1. Read `docs/harness/config.md`

Extract:

| Key | Use |
|---|---|
| `app_idea` | Refined concept tagline written by the research phase |
| `app_name` | Display name (may be blank — set it here if so) |
| `app_slug` | Kebab-case identifier (may be blank — derive it here if so) |
| `bundle_id` | App bundle ID (may be blank — set it here) |
| `default_language` | Should be `ko`; confirm before writing the PRD |

If `config.md` does not exist, abort with:
`flame-harness-plan: docs/harness/config.md not found — run the orchestrator to bootstrap first.`

### 2. Read the latest research spec

Find the most recent file matching `docs/harness/specs/*-research.md` (sort by filename
descending, take the first). If no spec file exists, abort with:
`flame-harness-plan: no research spec found in docs/harness/specs/ — run flame-harness-research first.`

Extract from the spec:

- **Chosen concept** — title, tagline, core mechanic, differentiator
- **Monetisation hook** — AdMob integration point (interstitial / rewarded / banner)
- **Clone-avoidance verdict** — confirm it is SAFE before proceeding

---

## Identity assignment

Derive and assign the app identity **before** writing the PRD so that the PRD can reference the
final values.

### app_name

Use the working title from the research spec as the display name. Capitalise each word. Example:
`"space hop"` → `"Space Hop"`.

### app_slug

The `app_slug` is a **kebab-case** identifier derived from `app_name`:

1. Lowercase the display name.
2. Replace all spaces and special characters with hyphens.
3. Strip leading/trailing hyphens and collapse consecutive hyphens to one.
4. Example: `"Space Hop!"` → `"space-hop"`.

The slug is used as the last segment of the bundle ID and as the directory name in CI/CD paths.
Do not use underscores — kebab-case only.

### bundle_id

Set `bundle_id` to `com.gonigon.<id>` where `<id>` is the `app_slug` with **all hyphens and
underscores removed** (lowercase alphanumeric only). Bundle IDs are reverse-DNS and each segment
must match `[a-z0-9]+` — hyphens/underscores are INVALID and will break iOS/Android signing.

Example: if `app_slug` is `space-hop`, then `bundle_id` is `com.gonigon.spacehop` (NOT
`com.gonigon.space-hop`). If `app_slug` is `swing-line`, `bundle_id` is `com.gonigon.swingline`.

The format `com.gonigon.<id>` is mandated by `docs/harness-protocol.md` §1. Never emit a hyphen or
underscore in the bundle id.

### Write to `config.md`

Use `Edit` to update `config.md` with the three identity keys:

```yaml
app_name: "<display name>"
app_slug: "<kebab-case-slug>"
bundle_id: "com.gonigon.<id>"   # <id> = app_slug with hyphens/underscores removed
```

Make targeted edits — do not rewrite the entire file.

---

## PRD content

Write the PRD **entirely in Korean** (한국어). The only exceptions are:
- Code identifiers, file paths, class names, and technical terms that have no Korean equivalent.
- Section headings may include the English technical term in parentheses after the Korean heading.

Use the following structure verbatim. A fresh Claude must be able to fill every section from the
research spec alone — no guessing required.

### PRD 구조 (required sections)

```markdown
# 게임 기획서 (PRD) — <app_name>

> **버전:** 1.0  
> **작성일:** <YYYY-MM-DD>  
> **작성자:** flame-harness-plan  
> **번들 ID:** com.gonigon.<id> (slug에서 하이픈·언더스코어 제거)

---

## 1. 장르 및 컨셉 (Genre & Concept)

- **장르:** <e.g. 하이퍼캐주얼 러너 / 타워 디펜스 / 퍼즐>
- **한 줄 설명:** <tagline from research spec, translated to Korean>
- **핵심 차별점:** <differentiator from research spec, in Korean>
- **대상 연령:** <target age group>

---

## 2. 코어 루프 (Core Loop)

플레이어가 10–30초마다 반복하는 핵심 행동을 단계별로 기술한다.

1. <단계 1>
2. <단계 2>
3. <단계 3>
   ...

---

## 3. 게임 메카닉 (Game Mechanics)

### 3.1 조작 방법 (Controls)

| 플랫폼 | 조작 | 결과 |
|---|---|---|
| iOS/Android | <tap / swipe / hold> | <action> |

### 3.2 핵심 메카닉 (Core Mechanic)

<2-4 sentences describing the primary mechanic in Korean>

### 3.3 보조 메카닉 (Secondary Mechanics)

<Bullet list of 2-4 secondary mechanics>

---

## 4. 콘텐츠 지표 (Content Metrics)

| 항목 | 목표값 |
|---|---|
| 레벨 수 | <number> |
| 적 종류 수 | <number> |
| 웨이브 수 (레벨당) | <number> |
| 스테이지 테마 수 | <number> |
| 아이템/파워업 종류 수 | <number> |

콘텐츠 수치는 MVP 기준이며, 업데이트를 통해 확장할 수 있다.

---

## 5. 진행 및 경제 (Progression & Economy)

### 5.1 진행 구조

<Describe how levels/stages unlock — linear, world-map, infinite, etc.>

### 5.2 점수 및 보상

- 기본 점수 단위: <e.g. 코인, 별, 포인트>
- 레벨 클리어 보상: <description>
- 광고 시청 보상 (리워드 애드): <description — maps to AdMob rewarded ad>

### 5.3 저장 및 영속성

- 로컬 저장: `SharedPreferences` (점수, 최고 기록, 설정)
- 클라우드 저장: 미포함 (스코프 외 — §8 참조)

---

## 6. 승리 및 패배 조건 (Win / Lose Conditions)

### 6.1 승리 조건

<Describe what the player must achieve to win a level/session>

### 6.2 패배 조건

<Describe what causes a game-over state>

### 6.3 게임 오버 화면

게임 오버 화면은 다음을 표시한다:
- 최종 점수
- 최고 기록 (갱신 여부 표시)
- 재시작 버튼
- 메인 메뉴 버튼
- 광고 시청으로 부활 옵션 (선택, 리워드 애드)

---

## 7. App Store 컴플라이언스 체크리스트

| 항목 | 상태 |
|---|---|
| 앱 심사 지침 4.3 클론 회피 확인 | SAFE (research spec 참조) |
| 개인정보 처리방침 URL 포함 | 필요 (config.md `privacy` 필드) |
| 연령 등급 적합성 (4+) | 확인 필요 |
| AdMob 광고 레이블 표시 | 광고 시청 버튼에 레이블 명시 |
| 인앱구매 없음 (MVP) | 스코프 외 |
| 위치 정보 미사용 | 해당 없음 |
| 카메라/마이크 미사용 | 해당 없음 |

---

## 8. 스코프 가드 (Scope Guard)

다음 항목은 **MVP 스코프 외**이다. 계획, 설계, 구현 단계에서 이 항목들을 구현하지 않는다.
스코프 확장이 필요한 경우 PRD를 개정한 후 진행한다.

**스코프 외 항목:**

- 온라인 멀티플레이어 / 소셜 기능
- 클라우드 저장 / 계정 시스템 (Google Play Games, Game Center)
- 인앱구매 (IAP) 및 프리미엄 콘텐츠
- 푸시 알림
- 커스텀 캐릭터 / 스킨 시스템
- 맵 에디터 또는 사용자 생성 콘텐츠
- 다국어 지원 (한국어 + 영어 이외의 언어)
- 태블릿 전용 레이아웃
- 백엔드 서버 / API

---
```

---

## lib/ structure map

The PRD must include a `lib/` directory map section immediately after the scope guard. This map
is the authoritative directory structure that the design and generator phases will follow.

Append the following section to the PRD (translated headings are fine; the paths must be exact):

```markdown
## 9. lib/ 디렉터리 구조

아래 구조는 design 및 generator 단계에서 그대로 따른다.

```
lib/
├── game/                    # FlameGame 서브클래스 및 게임 진입점
│   ├── components/          # Flame Component 클래스 (플레이어, 적, 장애물 등)
│   ├── systems/             # 게임 로직 시스템 (충돌, 스폰, 점수 등)
│   └── data/                # 레벨 데이터, 적 스탯, 게임 상수 (game_config.dart 포함)
├── screens/                 # Flutter 화면 (메인 메뉴, 게임 오버, 설정 등)
├── ui/                      # HUD 위젯, 오버레이, 공통 UI 컴포넌트
└── l10n/                    # 로컬라이제이션 ARB 파일 (ko.arb, en.arb)
```

> **규칙:** 게임 로직은 `game/` 아래에만 위치한다. Flutter 위젯은 `screens/` 또는 `ui/`에
> 위치한다. 매직 넘버는 `game/data/game_config.dart`에 집중한다 (contract.md 기준 §4 참조).
```

---

## Output

### 1. Write the PRD

Create `docs/harness/plans/<YYYY-MM-DD>-prd.md` (use today's UTC date).

If `docs/harness/plans/` does not exist, create it before writing.

Write the full Korean PRD using the structure defined in the **PRD content** section above,
filling every section from the research spec and `config.md`.

### 2. Update `config.md`

Apply the identity keys (`app_name`, `app_slug`, `bundle_id`) via `Edit` as described in
**Identity assignment** above.

### 3. Update `state.md`

Update `docs/harness/state.md` per the schema in `docs/harness-protocol.md` §2:

```yaml
status: running
current_phase: plan
next_role: design
updated_at: "<ISO-8601 UTC now>"
```

Leave all other keys unchanged. Use `Edit` for a targeted update.

### 4. Append to `pipeline-log.md`

Append one row to `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | complete | plan | PRD written; app_slug: <slug>; bundle_id: com.gonigon.<id> |
```

---

## Error handling

- If the research spec is missing or empty, abort with a clear message and set `state.md` to
  `status: paused`, `pause_reason: manual_action`.
- If `config.md` cannot be read, abort immediately (do not write partial output).
- If any required PRD section cannot be filled from the spec, write a clearly marked placeholder
  (`<!-- TODO: 작성 필요 -->`) rather than omitting the section — downstream validators grep for
  section headings.
