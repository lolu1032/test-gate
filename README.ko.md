# Test Gate

> Claude Code용 AI 에이전트 QA 격리 하네스 — 브라우저 + Tauri 데스크톱 테스트

**[English](README.md)**

AI 코딩 에이전트가 같은 세션에서 자기 코드를 테스트하면 "이 정도면 됐지" 하고 대충 넘어갑니다.
Test Gate는 **완전히 별도의 세션**에서 테스트를 돌려서 이 문제를 구조적으로 해결합니다.

- **웹앱**: Playwright MCP (자동)
- **Tauri 데스크톱앱**: Tauri MCP (`src-tauri/` 감지 시 자동)

코딩 에이전트는 테스트를 스킵할 수 없고, 테스트 에이전트는 코드를 수정할 수 없습니다.
사람이 리포트를 확인한 후 수정 여부를 결정합니다.

## 빠른 시작

### 1. 설치

```bash
git clone https://github.com/lolu1032/test-gate.git
cd test-gate
./install.sh
```

### 2. 실행

```bash
# 방법 A: Claude Code 스킬 (추천)
/test-gate

# 방법 B: 명령줄
~/.claude/test-harness/test-now.sh
```

### 3. 결과 확인

| 방법 | 위치 |
|------|------|
| **macOS 알림** | 테스트 완료 시 자동 팝업 |
| **VSCode** | 리포트 `.md` 파일이 에디터에 자동 열림 |
| **파일** | `{프로젝트}/.claude/test-reports/{hash}-report.md` |
| **히스토리** | `{프로젝트}/.claude/test-reports/HISTORY.md` |

## Claude Code 스킬

`SKILL.md`를 `~/.claude/skills/test-gate/SKILL.md`에 복사하면 스킬로 사용 가능:

```
/test-gate
```

포트 자동 감지, 서버 상태 확인, 프로젝트별 테스트 시나리오 설정까지 안내해줍니다.

## 프로젝트별 테스트 시나리오

프로젝트 루트에 `.claude/test-scenarios.md`를 만드세요:

```markdown
# 테스트 시나리오

## 로그인
- URL: http://localhost:3000
- 계정: admin@admin.com / 1234

## 필수 테스트
1. 로그인 후 대시보드 로드 확인
2. /posts 페이지에서 목록 표시 확인
3. /posts/new 에서 폼 제출 테스트
```

Tauri 프로젝트는 `.claude/tauri-test-scenarios.md`도 만들 수 있습니다.

## 자동 모드 (선택)

`~/.claude/settings.json`에 hook을 추가하면 커밋마다 자동 실행:

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

커밋 메시지에 `[skip-test]`를 넣으면 해당 커밋은 스킵합니다.

## Tauri 데스크톱앱 테스트

`src-tauri/tauri.conf.json` 또는 `src-tauri/Cargo.toml`이 있으면 자동 감지:

- 브라우저 테스트 먼저 실행 (웹뷰 콘텐츠)
- Tauri 테스트 실행 (네이티브 창, 메뉴, IPC, 시스템 트레이)
- 두 결과를 합산 리포트로 생성

## 히스토리 기반 테스트

HISTORY.md를 읽고 이전 결과를 활용:

- **리그레션 감지** — 이전 PASS가 FAIL이 되면 `[REGRESSION]` 표시
- **수정 검증** — 커밋 메시지에 `fix:`가 있으면 이전 FAIL 항목 집중 테스트
- **패턴 인식** — FAIL→PASS 영역은 리그레션 민감 영역으로 분류

## 파일 구조

```
~/.claude/test-harness/
├── test-now.sh              # 수동 실행
├── check-and-run.sh         # 자동 모드 hook
├── run-all-tests.sh         # 테스트 러너 (Playwright + Tauri MCP)
├── merge-reports.sh         # 리포트 합산 + 히스토리
├── browser-test-prompt.md   # 기본 브라우저 테스트 프롬프트
├── browser-mcp.json         # Playwright MCP 설정
├── tauri-test-prompt.md     # 기본 Tauri 테스트 프롬프트
├── tauri-mcp.json           # Tauri MCP 설정
└── install.sh               # 설치 스크립트

~/.claude/skills/test-gate/
└── SKILL.md                 # /test-gate 스킬

{프로젝트}/
└── .claude/
    ├── test-scenarios.md         # (선택) 브라우저 테스트 시나리오
    ├── tauri-test-scenarios.md   # (선택) Tauri 테스트 시나리오
    └── test-reports/
        ├── HISTORY.md            # 테스트 히스토리
        ├── {hash}-browser.md     # 브라우저 테스트 결과
        ├── {hash}-tauri.md       # Tauri 테스트 결과
        └── {hash}-report.md      # 합산 리포트
```

## 요구사항

- [Claude Code](https://claude.ai/claude-code) Max 구독 또는 API 키
- [Playwright MCP](https://www.npmjs.com/package/@playwright/mcp) 플러그인
- Tauri 테스트: Tauri MCP (개발 중)

## 비용

- **Max 구독**: 추가 비용 없음 (Haiku 4.5 사용)
- **API 과금**: 테스트 1회당 약 $0.01-0.05

## 왜 만들었나

AI 코딩 에이전트가 같은 세션에서 자기 코드를 테스트하면 확증 편향이 생깁니다.
"이 정도면 됐지" — 이건 프롬프트로 해결할 수 없는 구조적 문제입니다.

Test Gate는 **세션 격리**로 해결합니다:

1. **별도 프로세스** — 코딩 에이전트와 컨텍스트 공유 없음
2. **읽기 전용** — `--allowedTools`로 MCP + Read만 허용
3. **사람 게이트** — 리포트는 사람에게, 코딩 에이전트에게 자동 전달 안 함
4. **히스토리** — 커밋 간 리그레션 패턴 추적

## 로드맵

- [x] Phase 1: 브라우저 MCP (Playwright) 테스트
- [x] Phase 2: Tauri MCP 데스크톱앱 테스트
- [x] Phase 3: 히스토리 기반 리그레션 감지
- [x] `/test-gate` Claude Code 스킬
- [ ] Adversarial test agent (반복 실수 패턴 학습)
- [ ] 연속 커밋 디바운스

## 라이선스

MIT
