# flutter-flame-harness — 설계 스펙

> 작성일: 2026-06-22 · 상태: 승인됨(브레인스토밍 합의)

## 1. 목적

Flutter/Flame 게임을 **아이디어 선정부터 App Store / Google Play 배포까지** 자동으로 끌고 가는 Claude Code 플러그인. 기존 `rn-launch-harness`(React Native)의 검증된 하네스 머신을 그대로 재사용하되, RN/Expo/백엔드-앱 개념을 Flutter/Flame **게임** 개념으로 교체한다.

Anthropic의 "Building agentic systems for long-running apps"(harness design) 원칙을 따른다: Generator↔Evaluator 분리, 파일 기반 핸드오프, 회의적 평가자, 계약 협상, 컨텍스트 리셋.

## 2. 범위

- **대상:** Flame 엔진 게임 전용 (오프라인, 백엔드 API 없음).
- **이번 스펙/계획 사이클 = Phase A (MVP):** 아이디어 → 계획 → 디자인 → 계약 → Generator↔Evaluator 루프 → `flutter analyze` + `flutter test` 통과하는 **플레이 가능한 게임**.
- **Phase B (배포)** = 별도 사이클: admob, build, screenshot, submit, retro. 본 문서 §7에 개요만.
- **결과물 게임 위치:** `<projects-dir>/<game-slug>/` (기존 7개 게임과 나란히).

## 3. 전역 제약 (Global Constraints)

- **플러그인 이름:** `flutter-flame-harness` · 스킬 접두사 `flame-harness-*`.
- **플러그인 소스 위치:** `<projects-dir>/flutter-flame-harness/` (자체 git 저장소).
- **GitHub:** `tjdrhs90/flutter-flame-harness` 공개 레포 (`gh` CLI, 계정 `tjdrhs90`).
- **커밋 규칙:** Conventional Commits (commitlint 스타일) — `feat:`, `fix(scope):`, `docs:`, `chore:`, `refactor:`. **AI 작성 표기(Co-Authored-By 등) 절대 금지.**
- **Flutter/Flame 스택:** Dart 3.11+, Flame 1.37+, `flame_audio`, `google_mobile_ads`, `shared_preferences`. 손수 작성 KO/EN l10n (codegen 없음).
- **중앙 인증키 금고:** `<projects-dir>/credentials/` — `AuthKey_<asc-key-id>.p8`, `play-store-key.json`, `upload-keystore.jks`, `store-metadata.md`.
- **게임별 키 복사본:** `<game>/secrets/` (gitignore).
- **보안:** `credentials/`, 게임별 `secrets/`, `key.properties`, `*.jks`, `*.p8`, 키 `*.json`은 모든 레포에서 `.gitignore`. 플러그인 공개 레포에 키 절대 미포함.
- **iOS 자격:** Issuer `<asc-issuer-id>`, Key `<asc-key-id>`, Team `<apple-team-id>`.
- **개발자 정보(store-metadata.md):** <your-name> / <support-email> / privacy `<privacy-policy-url>` / 지원 `<support-and-marketing-url>` / `Copyright <year>. <company> all rights reserved.`
- **번들 ID:** `com.<company>.<slug>` (plan 단계 확정, iOS/Android 동일).
- **Android 서명:** 공유 `upload-keystore.jks` (alias `upload`, store/key pw `<keystore-password>`) 전 게임 공유. 누락 시에만 keytool로 신규 생성.
- **빌드/제출:** fastlane 레인 (iOS deliver / Android supply).
- **세션 연속성:** 각 게임에 `HANDOFF.md` 자동 유지.

## 4. 하네스 머신 (rn-harness에서 그대로 재사용)

- 오케스트레이터 + **페이즈당 스킬 1개**, 각 스킬은 **컨텍스트 리셋** 상태로 실행.
- `docs/harness/` 파일 기반 상태:
  - `config.md` — 파이프라인 설정(앱 아이디어, 이름, slug, 번들ID, 모드, 자격 경로 등).
  - `state.md` — `status`(running|paused|completed), `current_phase`, `current_round`, `next_role`, `pause_reason`.
  - `contract.md` — Generator↔Evaluator 합의 기준 (`Status: AGREED`).
  - `handoff/round-N-gen.md` — Generator 산출·자기평가.
  - `feedback/round-N-qa.md` — Evaluator 판정·구체 수정 지시.
  - `build-log.md` — 라운드별 점수/소요/노트.
  - `pipeline-log.md` — 이벤트 타임라인.
- **Generator ↔ Evaluator 루프:** 회의적 평가자가 *게임을 실제 실행해 관찰한 뒤* 판정. PASS→다음 페이즈, FAIL→Generator 재작업(`current_round`+1, `max_rounds`까지, 기본 3).
- **모드:** 기본(기능 QA만, 토큰 절약) / `--strict`(품질·엣지 QA 포함, 에이전트 팀).
- **자동 재개:** rate limit 시 `StopFailure` 훅이 `state.md`를 `paused`로 두고 재개 예약.

## 5. RN → Flame 교체 매핑

| rn-harness | flutter-flame-harness |
| --- | --- |
| FSD + TanStack Query + API 트랙 | Flame game-loop / components / systems / data-catalog |
| NativeWind 테마 | Flutter `design_tokens.dart` + 게임 아트/비주얼 컨셉 |
| EAS Build/Submit | fastlane 레인 (deliver/supply) |
| Generator: scaffold→API→UI | Generator: 코어루프 → 시스템+컴포넌트 → UI+컨텐츠 |
| NativeWind 6-체크 게이트 | `game_config.dart` 중앙화 + 컨텐츠 데이터화 + l10n 완비 게이트 |
| `tsc`/`eslint` 게이트 | `flutter analyze`(0건) / `flutter test`(통과) 게이트 |

## 6. Phase A 스킬 (MVP — 본 계획 사이클 대상)

각 스킬 = `skills/<name>/SKILL.md` (frontmatter: `name`, `description`, `argument-hint`, `allowed-tools`).

### 6.0 `flame-harness` (오케스트레이터)
- 인자 파싱: `--strict`, `--rounds N`, `--skip-research`, `--skip-admob`, `--resume`.
- `config.md` / `state.md` 초기 생성, `credentials/store-metadata.md` 읽어 개발자/자격 정보 주입.
- `state.md.next_role`을 읽어 다음 스킬을 `Skill("flame-harness-<phase>")`로 디스패치. 페이즈 전이마다 `state.md`·`pipeline-log.md` 갱신.

### 6.1 `flame-harness-research` (아이디어 선정 + 질의)
- Play/App Store 게임 차트·경쟁작 조사 → 게임 컨셉 2~3개 제안 → `AskUserQuestion`으로 사용자에게 질의 후 1개 확정. App Store 4.3(클론) 회피 점검.
- `--skip-research` 시 사용자가 직접 장르/컨셉 제공.
- 출력: `docs/harness/specs/YYYY-MM-DD-research.md`, `config.md`에 확정 컨셉 기록. `next_role: flame-harness-plan`.

### 6.2 `flame-harness-plan` (게임 PRD)
- 한글 PRD: 장르, 코어 루프, 메커니즘, 컨텐츠 지표(레벨/적/웨이브 수), 진행·경제, 조작, 승패 조건, **스코프 가드**, App Store 컴플라이언스 체크리스트.
- `lib/` 구조 매핑(`game/`, `game/components/`, `game/systems/`, `game/data/`, `screens/`, `ui/`, `l10n/`), 앱이름·slug·번들ID `com.<company>.<slug>` 확정 → `config.md`.
- 출력: `docs/harness/plans/YYYY-MM-DD-prd.md`. `next_role: flame-harness-design`.

### 6.3 `flame-harness-design` (디자인 컨셉)
- Flutter `design_tokens.dart` 사양(팔레트/타이포/스페이싱) + 게임 아트 방향·비주얼 컨셉 + 에셋/오디오 소싱 계획(`flutter_launcher_icons`/`flutter_native_splash` 포함).
- 출력: `docs/harness/plans/YYYY-MM-DD-design.md`. `next_role: flame-harness-contract`.

### 6.4 `flame-harness-contract` (완료 기준 협상)
- Generator가 검증 가능한 기준 제안 → 기본 모드 1-pass `AGREED`, `--strict` 시 Evaluator와 다회 협상.
- **필수 하드 게이트(모든 계약 포함):**
  - `flutter analyze` 0건 / `flutter test` 통과 / TODO·스텁 0.
  - `game_config.dart` 중앙화(매직넘버 금지) / 컨텐츠 데이터화(적·레벨을 데이터로) / KO·EN l10n 완비.
  - 코어 루프(시작→플레이→승/패→재시작) 동작 / 시뮬레이터 크래시·콘솔 에러 0.
  - 기능 기준(게임별 커스텀): 각 기준은 명령·스크린샷·코드 경로로 검증 가능해야 함.
- 출력: `docs/harness/contract.md` (`Status: AGREED`). `next_role: flame-harness-generator`, `current_round: 1`.

### 6.5 `flame-harness-generator` (3 서브페이즈 빌드)
- **5a 스캐폴드+코어루프:** `flutter create`, pubspec(Flame 1.37 + 코어 deps), `lib/` 구조, `game_config.dart`, `GameState` enum, `FlameGame` 서브클래스, 입력. 게이트: `flutter analyze` + `flutter test`.
- **5b 시스템+컴포넌트:** 엔티티(플레이어/적 등), 시스템(스폰/충돌/스코어/오디오/난이도), 데이터 카탈로그. 게이트.
- **5c UI+컨텐츠+폴리시:** 화면/오버레이(메뉴/HUD/일시정지/게임오버/상점), l10n, 컨텐츠 데이터, 디자인 토큰 적용, `shared_preferences` 저장. 게이트.
- **하드 게이트:** 각 서브페이즈 `analyze+test` 미통과 시 다음 서브페이즈 진행 금지. 기본 템플릿 파일 제거.
- 자기평가 → `handoff/round-N-gen.md` (빌드 내역, 계약 자기평가, 테스트 결과, 환경 감지, 알려진 이슈). `next_role: flame-harness-evaluator`.

### 6.6 `flame-harness-evaluator` (회의적 QA)
- **6.1 기능(기본):** `flutter analyze`(0) → `flutter test`(통과) → 스텁 grep → `game_config` 중앙화 체크 → l10n 완비 → 계약 기준 증거 확인 → **게임을 시뮬레이터에서 실제 실행, 코어 루프 플레이, 스크린샷 캡처·관찰**. *코드 리뷰만으로 PASS 금지. 스텁 감지=자동 FAIL.*
- **6.2 품질(`--strict`):** 게임 필(juice)·독창성·완성도·기능 4축 점수 + 인터랙션 상태(로딩/에러/빈) + 반응형. 임계값 가중 ≥7/10(strict 8/10).
- **6.3 엣지(`--strict`):** 에이전트 팀 — 게임플레이 엣지 / 밸런스 / 생명주기·크래시 / 성능 / 테스트 생성 / 적대적 리뷰. 전원 PASS 필요.
- 판정 → `feedback/round-N-qa.md`. PASS → `next_phase: admob`(Phase B). FAIL → `next_role: flame-harness-generator`, `current_round: N+1`. `max_rounds` 도달 시 현 상태로 강제 판정.

### 6.7 유틸 (양 페이즈 공통)
- `flame-harness-status`: `state.md`/`build-log.md` 읽어 현재 페이즈·라운드·점수 출력(읽기 전용).
- `flame-harness-resume`: `state.md` 읽어 `pause_reason`별 재개(rate_limit / manual_action / error).

## 7. Phase B 스킬 (배포 — 다음 사이클 개요)

- **`flame-harness-admob`:** 리워드 광고 위주 전략, 광고 유닛 수동 생성 안내 + 코드 자동 주입, ATT(iOS)·UMP(GDPR) 필수, SafeArea 배너 갭 패턴.
- **`flame-harness-build`:** `credentials/`→`secrets/` 복사, `key.properties`·fastlane `Appfile`/`Fastfile` 생성, iOS .ipa / Android AAB 빌드.
- **`flame-harness-screenshot`:** `integration_test`로 게임 구동, KO·EN 기기 사이즈 스크린샷 자동 캡처(광고 숨김), ASO 키워드 100자.
- **`flame-harness-submit`:** fastlane `deliver`(iOS 전자동) + `supply`(Android), Play 콘솔 수동 단계는 `paused`로 안내 후 재개.
- **`flame-harness-retro`:** Anthropic 9원칙 + 게임 품질 회고 → `docs/harness/retro.md`.

## 8. 플러그인 구조

```
flutter-flame-harness/
├── .claude-plugin/
│   ├── plugin.json          # 메타데이터, StopFailure 훅
│   └── marketplace.json      # 로컬 마켓플레이스 등록
├── skills/
│   ├── flame-harness/                 # 오케스트레이터 (Phase A)
│   ├── flame-harness-research/
│   ├── flame-harness-plan/
│   ├── flame-harness-design/
│   ├── flame-harness-contract/
│   ├── flame-harness-generator/
│   ├── flame-harness-evaluator/
│   ├── flame-harness-status/
│   └── flame-harness-resume/
│   # (Phase B에서 admob/build/screenshot/submit/retro 추가)
├── hooks/
│   └── stop-failure-handler.sh
├── templates/
│   ├── gitignore.template            # 게임용 .gitignore (secrets 등)
│   ├── key.properties.template
│   ├── fastlane-ios.template
│   └── fastlane-android.template
├── docs/superpowers/{specs,plans}/
└── README.md
```

## 9. 검증 전략

플러그인 산출물의 대부분은 **SKILL.md 프롬프트 문서 + 템플릿 + 셸 스크립트**라 전통적 단위 TDD가 그대로 맞지 않는다. 대신:
- **구조 검증:** 각 `SKILL.md`의 frontmatter 유효성(`name`/`description` 필수), 참조 파일 존재, `plugin.json`/`marketplace.json` JSON 유효성 — 셸 스크립트로 자동 점검(`scripts/validate.sh`).
- **상태 머신 검증:** `state.md` 전이 규칙(페이즈 순서, PASS/FAIL 분기)을 표로 명세하고 점검 스크립트로 확인.
- **스모크 테스트:** 플러그인 설치 후 아주 작은 게임 1개로 Phase A 1라운드 드라이런(수동 확인 항목 체크리스트).
- 셸 스크립트(`stop-failure-handler.sh`, `validate.sh`)는 `bats` 혹은 단순 assert로 검증.

## 10. 비범위 (YAGNI)

- 비-Flame/일반 Flutter 앱, 백엔드 API 트랙.
- 게임별 고유 키스토어(공유 키 사용).
- CI에서의 자동 제출(로컬 fastlane 우선; CI는 추후).
- Phase B 상세 구현(다음 사이클).
