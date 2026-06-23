# flutter-flame-harness

[English](README.md) | **한국어**

아이디어부터 앱스토어 출시까지, Flutter/Flame 게임 제작 전 과정을 끌고 가는 Claude Code 플러그인입니다. 하네스가 스킬들의 구조화된 파이프라인 — 리서치, 기획, 디자인, 계약 협상, 그리고 generator–evaluator 빌드 루프 — 을 조율하여, 각 단계가 검증되고 인수인계 가능한 산출물을 낸 뒤에야 다음 단계로 넘어갑니다.

## 왜

AI 코딩 도구는 보통 지루한 부분을 건너뜁니다 — 요구사항을 굳히기 전에 코드부터 짜고, 테스트를 생략하고, 덜 끝난 채 손을 뗍니다. 이 하네스는 **코드가 아니라 절차를 위임**합니다: 가드레일 → 계획 → generator↔evaluator 빌드 루프(*게임을 실제로 띄워보고 판정하는 회의적 QA*) → 사람 검수. 그리고 이론이 아니라, **실제로 Flame 게임을 출시하며 얻은 픽스**(오디오 풀링·햅틱·생명주기·성능·스토어/빌드 함정)가 처음부터 들어가 있어, 생성된 게임이 같은 함정을 다시 밟지 않습니다.

## 단계 (Phases)

**Phase A (완료): 리서치 → 계획 → 디자인 → 계약 → generator ↔ evaluator → 플레이 가능한 게임**

generator와 evaluator가 코드를 작성하기 전에 완료 기준을 먼저 협상하고, Flutter/Flame 프로젝트를 3개 서브페이즈(스캐폴드 → 시스템/컴포넌트 → UI/컨텐츠)로 빌드하며, 각 인수인계를 evaluator가 게이트합니다.

전체 수동 스모크 테스트 절차는 [`docs/SMOKE-TEST.md`](docs/SMOKE-TEST.md) 참고.

**Phase B (완료): admob, build, screenshot, submit, retro**

AdMob 연동, 릴리스 빌드(Android + iOS), App Store / Play Store 스크린샷, 제출, 출시 후 회고를 자동화합니다.

전체 수동 배포 드라이런 절차는 [`docs/SMOKE-TEST-phaseB.md`](docs/SMOKE-TEST-phaseB.md) 참고.

## 설치

```bash
/plugin marketplace add /Users/ssg/AndroidStudioProjects/flutter-flame-harness
/plugin install flutter-flame-harness
```

## 사용법

```
/flame-harness "<아이디어>"
/flame-harness
```

아이디어를 따옴표로 넘기면 그걸로 바로 시작합니다. 아이디어 없이 실행하면 AI가 시장을 조사해 게임 컨셉 2~3개를 추천하고, 당신이 하나 고를 때까지 기다립니다. `--auto-idea`를 붙이면 그 질문을 건너뛰어요: 아이디어 없음 + `--auto-idea` → AI가 컨셉을 생성·점수화·자동 선택(완전 핸즈오프).

> **언어:** PRD·카피·게임 UI는 **당신이 대화하는 언어**로 만들어집니다. 한국어로 요청하면 한국어, 영어로 요청하면 영어가 기본이 됩니다.

플래그:

| 플래그 | 기본 | 설명 |
|------|---------|-------------|
| `--strict` | off | evaluator를 strict 3단계 QA 모드로 실행 |
| `--rounds N` | 3 | generator–evaluator 협상 최대 라운드 |
| `--skip-research` | off | 시장조사 단계 건너뛰기 |
| `--skip-admob` | off | AdMob 단계 건너뛰기 |
| `--auto-idea` | off | 생성한 컨셉을 점수화해 최선을 자동 선택 — 선택 질문 없음 |
| `--auto-deploy` | off | QA 후 사람 검수 일시정지를 건너뛰고 PASS 시 바로 배포 |
| `--resume` | — | 일시정지된 실행 재개 |

기본적으로, 빌드가 QA를 통과하면 하네스는 배포 작업 전에 **당신이 게임을 직접 플레이하고 승인하도록 멈춥니다**(`cd <slug> && flutter run`). `/flame-harness --resume`로 admob→build→screenshot→submit을 이어갑니다. `--auto-deploy`는 이 게이트를 건너뛰며, `--auto-idea --auto-deploy`를 함께 쓰면 아이디어부터 배포까지 완전 핸즈오프로 돕니다.

## Phase A 스킬

| 스킬 | 트리거 | 역할 |
|-------|----------------|---------|
| `flame-harness-research` | `/flame-harness-research` | 시장조사 및 장르 분석 |
| `flame-harness-plan` | `/flame-harness-plan` | PRD(당신의 언어로), Flame 컴포넌트 맵, lib/ 구조 |
| `flame-harness-design` | `/flame-harness-design` | 비주얼 스타일 시스템 및 컴포넌트 명세 |
| `flame-harness-contract` | `/flame-harness-contract` | generator/evaluator가 완료 기준 협상 |
| `flame-harness-generator` | `/flame-harness-generator` | Flutter/Flame 프로젝트를 3개 서브페이즈로 빌드 |
| `flame-harness-evaluator` | `/flame-harness-evaluator` | QA 게이트 — 기능 검수 또는 strict 3단계 |

## Phase B 스킬

| 스킬 | 트리거 | 역할 |
|-------|----------------|---------|
| `flame-harness-admob` | `/flame-harness-admob` | 리워드 광고 전략, AdMob 유닛 생성 안내, ATT/UMP 코드 주입 |
| `flame-harness-build` | `/flame-harness-build` | 자격 부트스트랩, fastlane 설정 생성, IPA → TestFlight, AAB → 내부 트랙 |
| `flame-harness-screenshot` | `/flame-harness-screenshot` | integration_test로 게임 로케일 스크린샷, ASO 메타데이터, fastlane 업로드 |
| `flame-harness-submit` | `/flame-harness-submit` | fastlane으로 스토어 텍스트 메타데이터+카테고리 업로드 후 수동 제출을 위해 일시정지 |
| `flame-harness-retro` | `/flame-harness-retro` | 완료된 파이프라인을 9가지 하네스 원칙으로 평가, 회고 작성 |

## 파일 프로토콜

스킬 간 파일 인수인계 프로토콜 전체는 [`docs/harness-protocol.md`](docs/harness-protocol.md) 참고.

## 보안

자격 증명·시크릿은 이 저장소에 절대 들어가지 않습니다. `.gitignore`가 `credentials/`, `secrets/`, `*.jks`, `*.p8`, `play-store-key.json`, `sheets-key.json`을 영구 제외합니다. 서명 키·API 자격·서비스 계정 파일을 커밋하지 말고, 런타임에 환경변수나 시크릿 매니저로 전달하세요.
