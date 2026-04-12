# Test Gate

> Claude Code용 AI 에이전트 QA 격리 하네스 — 브라우저 + Tauri 데스크톱 테스트

**[English](README.md)**

AI 코딩 에이전트가 같은 세션에서 자기 코드를 테스트하면 "이 정도면 됐지" 하고 대충 넘어갑니다.
Test Gate는 **완전히 별도의 세션**에서 테스트를 돌려서 이 문제를 구조적으로 해결합니다.

- **웹앱**: `/test-web` — Playwright MCP
- **Tauri 데스크톱앱**: `/test-tauri` — Tauri MCP
- **둘 다**: `/test-gate` — 자동 감지

## 설치

```bash
git clone https://github.com/lolu1032/test-gate.git
cd test-gate
./install.sh
```

설치되는 것:
- 하네스 스크립트 → `~/.claude/test-harness/`
- Claude Code 스킬 → `~/.claude/skills/test-web/`, `test-tauri/`, `test-gate/`

### 수동 설치

```bash
# 하네스
mkdir -p ~/.claude/test-harness
cp *.sh *.md *.json ~/.claude/test-harness/
chmod +x ~/.claude/test-harness/*.sh

# 스킬
mkdir -p ~/.claude/skills/test-web ~/.claude/skills/test-tauri ~/.claude/skills/test-gate
cp skills/test-web/SKILL.md ~/.claude/skills/test-web/
cp skills/test-tauri/SKILL.md ~/.claude/skills/test-tauri/
cp skills/test-gate/SKILL.md ~/.claude/skills/test-gate/
```

## 사용법

### `/test-web` — 웹앱 테스트

```
/test-web
```

localhost에서 실행 중인 웹앱을 Playwright MCP로 테스트합니다.

- `package.json`에서 포트 자동 감지 (`--port 3001` 등)
- dev 서버 실행 여부 확인
- 프로젝트별 테스트 시나리오 설정 제안
- 백그라운드 실행, 완료 시 macOS 알림

### `/test-tauri` — Tauri 데스크톱앱 테스트

```
/test-tauri
```

Tauri 데스크톱앱을 Tauri MCP로 테스트합니다.

- `src-tauri/` 디렉토리로 Tauri 프로젝트 자동 감지
- 네이티브 기능 테스트: 윈도우, 메뉴, 시스템 트레이, IPC
- 웹뷰 내부 콘텐츠 테스트
- 웹 + Tauri 동시 실행 옵션

### `/test-gate` — 둘 다 (자동 감지)

```
/test-gate
```

웹 테스트 실행 후, `src-tauri/`가 있으면 Tauri 테스트도 실행.

### 명령줄 (스킬 없이)

```bash
~/.claude/test-harness/test-now.sh              # 현재 프로젝트
~/.claude/test-harness/test-now.sh ~/my-project  # 특정 프로젝트
```

## 결과 확인

| 방법 | 위치 |
|------|------|
| **macOS 알림** | 테스트 완료 시 자동 팝업 |
| **VSCode** | 리포트 `.md` 파일이 자동으로 열림 |
| **파일** | `{프로젝트}/.claude/test-reports/{hash}-report.md` |
| **히스토리** | `{프로젝트}/.claude/test-reports/HISTORY.md` |

### 히스토리 테이블

테스트할 때마다 `HISTORY.md`에 한 줄 추가:

```
| Date | Commit | Message | Result | Pass | Fail | Report |
|------|--------|---------|--------|------|------|--------|
| 2026-04-12 23:10 | a1b2c3d4 | fix: 로그인 폼 | PASS | 11 | 0 | link |
| 2026-04-12 22:30 | e5f6g7h8 | feat: 대시보드 | FAIL | 8 | 3 | link |
```

테스트 에이전트는 히스토리를 읽고:
- 이전 PASS가 FAIL이면 `[REGRESSION]` 표시
- 커밋 메시지에 `fix:`가 있으면 이전 FAIL 항목 집중 테스트
- FAIL→PASS 영역을 리그레션 민감 영역으로 분류

## 프로젝트별 테스트 시나리오

### 웹 (`/test-web`)

프로젝트 루트에 `.claude/test-scenarios.md` 생성:

```markdown
# 테스트 시나리오

## 로그인
- URL: http://localhost:3000
- 계정: admin@admin.com / 1234

## 필수 테스트
1. 로그인 후 대시보드 로드 확인
2. /posts 페이지에서 목록 확인
3. /posts/new 에서 폼 제출 테스트
4. 768px, 375px 반응형 확인
```

### Tauri (`/test-tauri`)

`.claude/tauri-test-scenarios.md` 생성:

```markdown
# Tauri 테스트 시나리오

## 앱 실행
1. 윈도우가 올바른 타이틀로 열리는지
2. 윈도우 크기가 설정과 일치하는지

## 네이티브 기능
1. 시스템 트레이 아이콘 표시
2. 메뉴바 항목 동작
3. 파일 열기 다이얼로그

## 웹뷰
1. 메인 페이지 렌더링
2. IPC 통신 (Rust ↔ Frontend)
```

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

커밋 메시지에 `[skip-test]`를 넣으면 스킵.

## 파일 구조

```
~/.claude/test-harness/          # 하네스 (글로벌 설치)
├── test-now.sh                  # 수동 실행 (CLI)
├── check-and-run.sh             # 자동 모드 hook
├── run-all-tests.sh             # 테스트 러너
├── merge-reports.sh             # 리포트 합산 + 히스토리
├── browser-test-prompt.md       # 기본 웹 테스트 프롬프트
├── browser-mcp.json             # Playwright MCP 설정
├── tauri-test-prompt.md         # 기본 Tauri 테스트 프롬프트
├── tauri-mcp.json               # Tauri MCP 설정
└── install.sh                   # 설치 스크립트

~/.claude/skills/                # 스킬 (슬래시 커맨드)
├── test-web/SKILL.md            # /test-web
├── test-tauri/SKILL.md          # /test-tauri
└── test-gate/SKILL.md           # /test-gate (둘 다)

{프로젝트}/.claude/              # 프로젝트별 (자동 생성)
├── test-scenarios.md            # (선택) 웹 테스트 시나리오
├── tauri-test-scenarios.md      # (선택) Tauri 테스트 시나리오
└── test-reports/
    ├── HISTORY.md               # 테스트 히스토리
    ├── {hash}-browser.md        # 웹 테스트 결과
    ├── {hash}-tauri.md          # Tauri 테스트 결과
    └── {hash}-report.md         # 합산 리포트
```

## 요구사항

- [Claude Code](https://claude.ai/claude-code) Max 구독 또는 API 키
- [Playwright MCP](https://www.npmjs.com/package/@playwright/mcp) — `/test-web`용
- Tauri MCP — `/test-tauri`용 (생태계 초기 단계)

## 비용

- **Max 구독**: 추가 비용 없음 (Haiku 4.5 사용)
- **API 과금**: 테스트 1회당 약 $0.01-0.05

## 왜 만들었나

AI 코딩 에이전트가 같은 세션에서 자기 코드를 테스트하면 확증 편향이 생깁니다.
"이 정도면 됐지" — 프롬프트로 해결할 수 없는 구조적 문제.

Test Gate는 **세션 격리**로 해결합니다:

1. **별도 프로세스** — 코딩 에이전트와 컨텍스트 공유 없음
2. **읽기 전용** — `--allowedTools`로 MCP + Read만 허용
3. **사람 게이트** — 리포트는 사람에게, 코딩 에이전트에게 자동 전달 안 함
4. **히스토리** — 커밋 간 리그레션 패턴 추적

## 로드맵

- [x] `/test-web` — Playwright MCP 브라우저 테스트
- [x] `/test-tauri` — Tauri MCP 데스크톱 테스트
- [x] `/test-gate` — 통합 자동 감지
- [x] 히스토리 기반 리그레션 감지
- [x] macOS 알림 + VSCode 자동 열기
- [ ] Adversarial test agent (반복 실수 패턴 학습)
- [ ] 연속 커밋 디바운스

## 라이선스

MIT
