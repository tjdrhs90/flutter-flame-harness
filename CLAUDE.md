# flutter-flame-harness — 개발 가이드

이 문서는 **이 플러그인 레포 자체를 개발/기여할 때**의 작업 절차다. (하네스가 *생성하는 게임*이 아니라, `skills/`·`docs/`·`scripts/`·`templates/` 같은 플러그인 코드를 손볼 때 적용된다.)

철학: **"바이브 코딩이 아니라, 절차를 AI에 위임한다."** 질의 → 계획 → 구현 → 검수를 도구로 강제하고, 사람은 방향과 최종 QA를 맡는다.

> 참고로 이 하네스 자체가 이 철학의 *게임 특화판*이다: 하드 게이트/contract = karpathy 가드레일, research·plan = brainstorming·writing-plans, generator↔evaluator 루프 = ralph + code-review. 그래서 플러그인을 개발할 때도 같은 절차를 쓴다.

---

## 상시 가드레일 — karpathy (항상 적용)

모든 코드 작성·리뷰·리팩토링에 다음 4원칙을 **기본값으로** 따른다 (`/andrej-karpathy-skills:karpathy-guidelines`):

1. **가정 전에 질문** — 틀린 가정을 조용히 밀어붙이지 말 것. 모호하면 멈추고 묻는다.
2. **단순성 우선** — 요청한 최소한만. 추측성 추상화·설정·기능 금지.
3. **외과적 변경** — 요청에 직접 닿는 줄만 손댄다. 안 깨진 것 리팩토링 금지. 기존 스타일 따름.
4. **검증 가능한 목표** — "동작하게" 대신 "이 명령이 통과"로 성공 기준을 정의하고 통과할 때까지 돈다.

---

## 개발 흐름

```
① 질의 brainstorming → ② 계획 writing-plans → ③ 구현 subagent-driven → ④ 검수 code-review → ⑤ 사람 QA
```

- **① 질의** — `/superpowers:brainstorming`. 코드 전에 의도·제약·성공기준을 정하고 설계 승인을 받는다.
- **② 계획** — `/superpowers:writing-plans`. 태스크 단위 구현 계획을 `docs/superpowers/plans/`에 쓴다.
- **③ 구현** — `/superpowers:subagent-driven-development`(태스크당 새 서브에이전트 + 2단계 리뷰, 격리 컨텍스트) 또는 `/superpowers:executing-plans`(배치+체크포인트).
- **④ 검수** — `/code-review`(Claude Code 내장). 깨끗한 컨텍스트로 변경분을 다시 본다. 평소 `medium`, 중요한 변경엔 `high`~`max`. `--fix`는 결과 확인 후.
- **⑤ 사람 QA** — 설계 방향·비즈니스 부합은 사람 몫. 리뷰 false positive는 판단해서 수용.

오래 도는 반복 작업(예: 스크립트가 초록불 될 때까지)은 `/ralph-loop:ralph-loop ... --max-iterations N` — `--max-iterations` 필수(토큰 방지), 작은 단위로 쪼개서.

---

## 이 레포의 특성 (꼭 알 것)

- **산출물 = 프롬프트 문서**(`skills/*/SKILL.md`) + 셸 스크립트 + 템플릿. 코드 단위 TDD가 그대로 안 맞는다 → **구조/동작 검증**으로 사이클을 돈다.
- **검증 게이트 (변경 후 반드시 통과):**
  - `bash scripts/validate.sh` — 매니페스트 JSON 유효성 + 모든 스킬 frontmatter + 스킬별 필수 섹션.
  - `bash scripts/validate-fastlane.sh` — fastlane 템플릿 `ruby -c` 문법.
  - `bash scripts/test-hook.sh` — rate-limit 훅 동작.
- **`docs/harness-protocol.md` = 모든 파일 스키마·상태머신의 단일 출처.** 스킬은 스키마를 재정의하지 말고 이 문서를 인용(DRY). 새 상태 전이를 추가하면 **protocol §7을 먼저** 갱신한 뒤 스킬을 맞춘다.
- 스킬을 새로 만들거나 고칠 때 `/superpowers:writing-skills` 참고.

---

## 커밋 규칙

- **Conventional Commits** (`feat:`, `fix(scope):`, `docs:`, `chore:`, `refactor:`).
- **AI 작성 표기 금지** — `Co-Authored-By` 같은 트레일러나 "Generated with..." 줄을 절대 넣지 않는다.

---

## 플러그인 관리 (중요)

karpathy / superpowers / ralph-loop 는 **각각 별도로 설치·수동 업데이트**한다. 이 레포는 그것들에 **하드 의존하지 않는다** — 흐름(이 문서)만 공유하고, 파이프라인은 패턴을 네이티브로 구현한다. 커뮤니티 플러그인은 비공식이니 설치 전 레포 확인. (`code-review`는 Claude Code 내장이라 별도 설치 불필요.)
