# Gotcha

> Claude Code용 AI 에이전트 QA 격리 하네스 — 웹 + 데스크톱 + 코드 리뷰 + 멀티 에이전트 배심원단

**[English](README.md)**

AI 코딩 에이전트가 같은 세션에서 자기 코드를 테스트하면 "이 정도면 됐지" 하고 대충 넘어갑니다.
Gotcha는 **완전히 별도의 세션**에서 테스트를 돌려서 이 문제를 구조적으로 해결합니다.

- **웹앱**: `/test-web` — Playwright MCP
- **데스크톱앱**: `/test-desktop` — Tauri MCP (현재)
- **코드 리뷰**: `/test-review` — git diff 분석
- **멀티 에이전트 합의**: `/test-jury` — Claude + Codex 병렬 + 크로스체크 + 합성
- **라우터**: `/gotcha` — 표면 감지 + 위임

## 동작 흐름

```
[코딩 에이전트 세션]
    ↓ (/gotcha 또는 표면별 스킬 실행)
[/gotcha 라우터]
    ├── 프로젝트의 표면 감지
    └── 어댑터에 위임:
[별도 Claude 세션 — Haiku 4.5]
    ├── /test-web      → Playwright MCP → 페이지 탐색, 클릭, 검증
    ├── /test-desktop  → Tauri MCP → 윈도우, IPC, 웹뷰
    └── /test-review   → Read + Grep → git diff 분석
    ↓
[리포트 + macOS 알림 + VSCode 자동 열기]
    ↓
[사람이 확인 후 수정 결정]
```

## 아키텍처

Gotcha는 **표면(surface) 기반** 명명을 사용합니다 (프레임워크 기반 X):

| 스킬 | 표면 | 구현 |
|------|------|------|
| `/test-web` | 웹앱 (브라우저) | Playwright MCP |
| `/test-desktop` | 데스크톱 앱 | Tauri MCP |
| `/test-review` | 코드 diff | Read + Grep + git |
| `/test-jury` | 중요 리뷰 (합의) | Claude Opus + Codex GPT, 2 라운드 |
| `/gotcha` | 라우터 | 감지 + 위임 |

이렇게 하면 Go 웹서버, Java Spring 앱, Next.js 앱, Tauri 앱 모두 같은 스킬로 테스트 가능. 어댑터만 다름.

## 설치

```bash
git clone https://github.com/lolu1032/gotcha.git
cd gotcha
./install.sh
```

설치되는 것:
- 하네스 스크립트 → `~/.claude/test-harness/`

## 사용법

### `/gotcha` — 라우터 (추천)

```
/gotcha
```

프로젝트에 적용 가능한 표면을 감지하고, 여러 개 선택 가능, 각 어댑터에 위임.

### `/test-web` — 웹앱 테스트

localhost(또는 다른 URL)에서 돌아가는 웹앱을 Playwright MCP로 테스트.

- `package.json`에서 포트 자동 감지
- dev 서버 실행 여부 확인
- 시나리오는 항상 사용자에게 묻기 — 자동 생성 안 함
- 백그라운드 실행, 완료 시 macOS 알림

### `/test-desktop` — 데스크톱 테스트

Tauri 데스크톱 앱을 Tauri MCP로 테스트.

- Tauri 프로젝트 자동 감지 (`src-tauri/` 디렉토리)
- 네이티브 기능 테스트: 윈도우, 메뉴, 시스템 트레이, IPC
- 웹뷰 내부 콘텐츠 테스트


`/test-desktop`으로 리다이렉트. 호환성 유지용.

### `/test-review` — 코드 리뷰

별도 세션에서 git diff 리뷰.

- base ref 자동 감지 (feature 브랜치면 `origin/main..HEAD`, main이면 `HEAD~1`)
- 6개 카테고리: 정확성, 보안, 성능, 테스트 커버리지, 코드 품질, 일관성
- P1/P2/P3 심각도 + 신뢰도 점수
- 리포트는 `.claude/review-reports/`에 저장 (테스트 리포트와 분리)

### 명령줄 (스킬 없이)

```bash
~/.claude/test-harness/test-now.sh              # 현재 프로젝트
~/.claude/test-harness/test-now.sh ~/my-project  # 특정 프로젝트
```

## 결과 확인

| 위치 | 내용 |
|------|------|
| **macOS 알림** | 테스트 완료 팝업 |
| **VSCode** | 리포트 `.md` 자동으로 열림 |
| **테스트 리포트** | `{프로젝트}/.claude/test-reports/{hash}-report.md` |
| **리뷰 리포트** | `{프로젝트}/.claude/review-reports/{hash}-review.md` |
| **테스트 히스토리** | `{프로젝트}/.claude/test-reports/HISTORY.md` |
| **리뷰 히스토리** | `{프로젝트}/.claude/review-reports/HISTORY.md` |

## 프로젝트별 테스트 시나리오

**표면별 폴더 구조 (권장):**

```
.claude/test-scenarios/
├── web/              # /test-web 시나리오
│   ├── _always.md    # 항상 실행
│   ├── auth.md       # 기능별
│   └── posts.md
└── desktop/          # /test-desktop 시나리오
    ├── _always.md
    └── window.md
```

파일 로드 순서: `_always.md` 먼저, 나머지는 알파벳순.

**예시 `web/_always.md`:**

```markdown
# 항상 실행되는 웹 시나리오

## 로그인
- URL: http://localhost:3000
- 계정: admin@admin.com / 1234

## 필수 테스트
1. 로그인 후 대시보드 로드 확인
2. 모든 페이지에서 사이드바 네비게이션 동작 확인
```

**하위 호환성:** 구 경로도 자동 폴백:
- `.claude/test-scenarios/` (단일 폴더, web으로 처리)
- `.claude/test-scenarios.md` (단일 파일, web)
- `.claude/tauri-test-scenarios/` (폴더, desktop)
- `.claude/tauri-test-scenarios.md` (단일 파일, desktop)

## 자동 모드 (선택)

`~/.claude/settings.json`에 hook 추가하면 커밋마다 자동 실행:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/test-harness/check-and-run.sh"
          }
        ]
      }
    ]
  }
}
```

커밋 메시지에 `[skip-test]` 넣으면 스킵.

## 히스토리 기반 테스트

HISTORY.md를 읽고 활용:

- **리그레션 감지** — 이전 PASS가 FAIL이면 `[REGRESSION]` 표시
- **수정 검증** — 커밋 메시지에 `fix:`가 있으면 이전 FAIL 항목 집중
- **패턴 인식** — FAIL→PASS 영역을 리그레션 민감 영역으로 분류

## 파일 구조

```
~/.claude/test-harness/          # 하네스 (글로벌 설치)
├── test-now.sh                  # 수동 실행
├── check-and-run.sh             # 자동 모드 hook
├── run-all-tests.sh             # 테스트 러너
├── run-review.sh                # 코드 리뷰 러너
├── merge-reports.sh             # 리포트 합산
├── browser-test-prompt.md       # 기본 웹 프롬프트
├── browser-mcp.json             # Playwright MCP 설정
├── tauri-test-prompt.md         # 기본 데스크톱 프롬프트
├── tauri-mcp.json               # Tauri MCP 설정
└── code-review-prompt.md        # 기본 리뷰 프롬프트

~/.claude/skills/                # 스킬 (슬래시 커맨드)
├── test-gate/SKILL.md           # /gotcha (라우터)
├── test-web/SKILL.md            # /test-web
├── test-desktop/SKILL.md        # /test-desktop
└── test-review/SKILL.md         # /test-review

{프로젝트}/.claude/              # 프로젝트별 (자동 생성)
├── test-scenarios/
│   ├── web/                     # /test-web 시나리오
│   └── desktop/                 # /test-desktop 시나리오
├── test-reports/                # /test-web, /test-desktop 출력
│   ├── HISTORY.md
│   ├── {hash}-report.md
│   └── artifacts/{hash}/        # 스크린샷
└── review-reports/              # /test-review 출력
    ├── HISTORY.md
    └── {hash}-review.md
```

## 요구사항

- [Claude Code](https://claude.ai/claude-code) Max 구독 또는 API 키
- [Playwright MCP](https://www.npmjs.com/package/@playwright/mcp) — `/test-web`용
- Tauri MCP — `/test-desktop`용 (생태계 초기 단계)

## 비용

- **Max 구독**: 추가 비용 없음 (Haiku 4.5)
- **API 과금**: 테스트 1회당 약 $0.01-0.05

## 왜 만들었나

AI 코딩 에이전트가 같은 세션에서 자기 코드를 테스트하면 확증 편향이 생깁니다.
"이 정도면 됐지" — 프롬프트로 해결할 수 없는 구조적 문제.

Gotcha는 **세션 격리**로 해결:

1. **별도 프로세스** — 코딩 에이전트와 컨텍스트 공유 없음
2. **읽기 전용** — `--allowedTools`로 MCP + Read만 허용
3. **사람 게이트** — 리포트는 사람에게, 코딩 에이전트에 자동 전달 안 함
4. **히스토리** — 커밋 간 리그레션 패턴 추적

[Dual Quality Gates](https://www.sagarmandal.com/2026/03/15/agentic-engineering-part-7-dual-quality-gates-why-validation-and-testing-must-be-separate-processes/) 패턴 구현체.

## 로드맵

- [x] Phase 1: `/test-web` — Playwright MCP 브라우저 테스트
- [x] Phase 2: `/test-desktop` — Tauri MCP 데스크톱 테스트
- [x] Phase 3: 히스토리 기반 리그레션 감지
- [x] `/test-review` — git diff 코드 리뷰
- [x] `/gotcha`를 thin router로 (Phase A 리팩토링)
- [x] 표면별 시나리오 폴더 (`.claude/test-scenarios/{web,desktop}/`)
- [ ] Phase B: 공통 config 파일 (`.claude/gotcha.toml`)
- [ ] Phase C: `/test-api`, `/test-cli` 어댑터
- [ ] Adversarial test agent (실수 패턴 학습)

## 라이선스

MIT
