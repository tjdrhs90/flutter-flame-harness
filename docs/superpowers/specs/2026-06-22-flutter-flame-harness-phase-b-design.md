# flutter-flame-harness Phase B — 설계 스펙 (배포)

> 작성일: 2026-06-22 · 상태: 승인됨(브레인스토밍 합의) · 선행: Phase A(완료)

## 1. 목적

Phase A가 만든 "플레이 가능 + `flutter analyze`/`flutter test` 통과" 게임을 **App Store / Google Play 업로드까지** 끌고 간다. fastlane은 새로 발명하지 않고 사용자의 검증된 기존 설정(`/Users/ssg/AndroidStudioProjects/flame_endless_runner/{ios,android}/fastlane`)을 게임별로 파라미터화해 생성한다.

## 2. 범위

- 신규 스킬 5개: `flame-harness-admob`, `-build`, `-screenshot`, `-submit`, `-retro`.
- Phase A 통합 변경 3군데(surgical): orchestrator 디스패치, protocol §7 전이표, `config.md` admob 필드.
- 본 스펙/계획 = 한 사이클(Phase A와 동일 방식).

## 3. 핵심 결정 (브레인스토밍 확정)

- **제출 경계 = 업로드 자동 / 최종 제출 수동** (기존 fastlane 패턴 미러링). iOS는 TestFlight 업로드 후 ASC에서 "심사 제출"을 사용자가 클릭; Android는 내부 트랙 업로드 + production은 draft 유지(수동 승격). `submit` 스킬이 `state`를 `paused`(manual_action)로 두고 정확한 수동 단계를 안내한다.
- **iOS 서명 = ASC API 키 기반** (`get_certificates` + `get_provisioning_profile`), fastlane match repo 미사용.
- **광고 = 리워드 위주** + iOS ATT + UMP/GDPR 동의. 광고 유닛은 AdMob 콘솔에서 **수동 생성**(Google API 미지원), 코드는 자동 주입.
- **스크린샷 = `integration_test`** (`screenshots_test.dart`), maestro 미사용. KO+EN.

## 4. Global Constraints (Phase A 상속 + Phase B 추가)

- 커밋: Conventional Commits, **AI 작성 표기 금지**. 커밋 신원: `git -c user.name='Seonggon Sim' -c user.email='tjdrhs90@gmail.com'`.
- 보안: `credentials/`·게임 `secrets/`·`*.jks`·`*.p8`·`*.p12`·키 `*.json` 전부 gitignore. 플러그인 공개 레포에 키 미포함.
- 자격(검증된 실제 값):
  - iOS: `app_identifier com.gonigon.<slug>`, `apple_id tjdrhs90@gmail.com`, `team_id 8DHJJJ66LY`, ASC `key_id 339MZ7CUZ5`, `issuer_id f9a69502-1e93-4fd1-9f53-5eb4db1b637a`, key 파일 `AuthKey_339MZ7CUZ5.p8`.
  - Android: `package_name com.gonigon.<slug>`, `json_key_file fastlane/play-store-key.json`, 서명 `key.properties`(alias `upload`, storeFile `upload-keystore.jks`, pw `111111`).
- 스택: Dart 3.11+, Flame 1.37+, `google_mobile_ads`, `app_tracking_transparency`/UMP, `integration_test`. fastlane(ruby 3.2). flutter·Xcode 26.5 로컬 존재.

## 5. 기존 fastlane 미러링 (템플릿 소스)

생성할 fastlane 설정은 아래 검증된 lanes를 그대로 따르고, `APP_ID`/`APP_NAME`/`scheme output_name`/`provisioning profile 이름`만 게임별로 치환한다.

**iOS Fastfile lanes** (출처 `flame_endless_runner/ios/fastlane/Fastfile`):
- `auth_check` — ASC 인증 + 앱 레코드 도달 확인.
- `certs` — `get_certificates` + `get_provisioning_profile`(ASC API).
- `beta` — 기존 키체인 배포 인증서 + 프로비저닝 프로필로 수동 서명(Runner 타깃만), `build_app`(export `app-store`) → `upload_to_testflight(skip_waiting_for_build_processing: true)`.
- `metadata` — `upload_to_app_store`(binary/screenshots skip, 텍스트만).
- `categories` — `upload_to_app_store`로 GAMES 1차/2차 서브카테고리 설정.
- `screenshots` — `upload_to_app_store`(metadata skip, `overwrite_screenshots: true`).

**Android Fastfile lanes** (출처 `flame_endless_runner/android/fastlane/Fastfile`):
- `metadata` — `upload_to_play_store`(aab/apk/images/changelogs skip, 텍스트만).
- `images` — `upload_to_play_store`(aab/apk/changelogs skip; 아이콘·피처그래픽은 metadata와 함께 업로드).
- `release_notes` — `upload_to_play_store(track: production, version_code: 1, release_status: draft, changelogs only)`.
- `internal` — `upload_to_play_store(track: internal, aab: ../build/app/outputs/bundle/release/app-release.aab)`.

**Appfile**: iOS `app_identifier/apple_id/team_id`; Android `json_key_file/package_name`.

## 6. 신규 스킬 (각 `skills/<name>/SKILL.md`)

### 6.7 `flame-harness-admob` (Phase 7)
- 입력: PRD, `config.md`(`skip_admob`). `skip_admob: true`면 즉시 스킵하고 `next_role: build`.
- 게임 분석 → 리워드 광고 배치 전략 결정.
- AdMob 콘솔 **수동 유닛 생성 안내**(앱 ID + 리워드 유닛 ID, iOS/Android 각각) → `AskUserQuestion`/일시정지로 ID 수집.
- 코드 자동 주입: `google_mobile_ads` 리워드 헬퍼, iOS ATT 요청, UMP 동의 흐름. (배너 사용 시 SafeArea 갭 패턴.)
- 출력: `config.md`에 `admob.ios_app_id`/`android_app_id`/`ad_units` 기록. `status: running`, `current_phase: admob`, `next_role: build`.

### 6.8 `flame-harness-build` (Phase 8)
- **자격 부트스트랩**(기존 게임 배치 미러링):
  - `credentials/AuthKey_339MZ7CUZ5.p8` → `<game>/ios/fastlane/AuthKey_339MZ7CUZ5.p8`.
  - `credentials/play-store-key.json` → `<game>/android/fastlane/play-store-key.json`.
  - `credentials/upload-keystore.jks` → `<game>/android/upload-keystore.jks` (없으면 keytool 신규 생성, alias `upload`).
  - 생성: `android/key.properties`, iOS/Android `Appfile`/`Fastfile`(§5 lanes 치환), iOS `certs/` 디렉터리.
- fastlane 실행: iOS `beta`(서명 IPA → TestFlight), Android `internal`(서명 AAB → 내부 트랙).
- 출력: `handoff/build-result.md`(IPA/AAB 경로, 업로드 결과, 빌드번호). `status: running`, `current_phase: build`, `next_role: screenshot`.

### 6.9 `flame-harness-screenshot` (Phase 9)
- `integration_test/screenshots_test.dart` 하네스(기존 미러링)로 게임 구동, **KO+EN** 필수 기기 사이즈(iOS 6.7" iPhone, Android phone) 캡처. 캡처 중 광고 숨김.
- ASO: iOS `keywords.txt` 100자(쉼표 포함) 꽉 채움.
- 업로드: iOS `screenshots` lane, Android `images` lane.
- 출력: `store-assets/`(스크린샷+메타데이터). `status: running`, `current_phase: screenshot`, `next_role: submit`.

### 6.10 `flame-harness-submit` (Phase 10)
- 텍스트 메타데이터 업로드: iOS `metadata`+`categories`, Android `metadata`+`release_notes`.
- 그 후 `state`를 `paused`(`pause_reason: manual_action`)로 두고 **정확한 수동 단계** 출력:
  - iOS: ASC → "심사 제출"(Submit for Review).
  - Android: Play 콘솔 → 콘텐츠 등급/데이터 안전/타깃 연령 설문(API 미지원) + 내부→production 승격.
- 사용자가 `flame-harness-resume`로 재개하면 → `status: running`, `next_role: retro`.

### 6.11 `flame-harness-retro` (Phase 11)
- Anthropic 9원칙(Generator-Evaluator 분리, 평가자 회의주의, 계약 협상, 파일 핸드오프, no-sprints, screenshot-and-study, 단순성, 비용-품질, 테스트 중복제거) + 게임 품질 회고.
- 출력: `docs/harness/retro.md`. `status: completed`.

## 7. Phase A 통합 변경 (surgical, 3군데)

1. **orchestrator** (`skills/flame-harness/SKILL.md`): `admob` 경계에서 멈추고 "Phase B 미구현" 출력하던 로직을, `admob`을 디스패치하고 dispatch 루프를 `admob→build→screenshot→submit→retro`까지 잇도록 변경. 루프 정지 지점은 `submit`의 manual 일시정지(`status: paused`)와 `retro` 후 `status: completed`.
2. **protocol** (`docs/harness-protocol.md` §7 전이표): 행 추가 — `admob complete→build`, `build complete→screenshot`, `screenshot complete→submit`, `submit metadata-done→paused(manual_action)`, `(resume)→retro`, `retro complete→completed`. `skip_admob: true`면 `evaluator PASS→build`.
3. **config.md** (protocol §1 스키마): `admob:` 블록(`ios_app_id`, `android_app_id`, `ad_units: []`) 추가.

## 8. 검증

- 구조 검증: `scripts/validate.sh`에 신규 5개 스킬 frontmatter/필수섹션 assertion 추가(Phase A 패턴).
- fastlane 템플릿: 생성될 `Fastfile` 템플릿을 `ruby -c`로 문법 체크하는 스크립트(`scripts/validate-fastlane.sh` 또는 validate.sh 확장).
- 라이브 배포 스모크: 실게임 + 스토어 앱 레코드가 있어야 하므로 `docs/SMOKE-TEST-phaseB.md`로 수동 절차 문서화(사용자 세션에서 실행). 비대화/비배포 부분만 자동 검증.

## 9. 비범위 (YAGNI)

- fastlane match repo(인증서 git 저장) — ASC API 키 사용.
- 완전 자동 심사 제출/ production 직행 — 수동 경계 유지.
- iPad/태블릿 스크린샷 — 게임이 universal이 아니면 필수 최소 세트만.
- CI 자동 배포 — 로컬 fastlane 우선.
- AdMob 미디에이션/배너·전면 광고 — 리워드 위주.
