---
name: test-web
description: 별도 세션에서 Playwright MCP로 웹앱 QA 테스트 실행
user_invocable: true
---

# Test Web

별도 Claude 세션에서 Playwright MCP로 웹앱을 테스트하고 리포트를 생성한다.

## 실행

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT: $PROJECT_ROOT"
echo "COMMIT: $(git -C "$PROJECT_ROOT" log -1 --format='%h %s' 2>/dev/null || echo 'no commits')"

# 하네스 설치 확인
if [ -x "$HOME/.claude/test-harness/test-now.sh" ]; then
  echo "HARNESS: installed"
else
  echo "HARNESS: NOT INSTALLED"
fi

# 프로젝트별 시나리오 확인
if [ -f "$PROJECT_ROOT/.claude/test-scenarios.md" ]; then
  echo "SCENARIOS: project-specific"
else
  echo "SCENARIOS: default"
fi

# 포트 감지
PORT=$(grep -oE '\-\-port[= ]+([0-9]+)' "$PROJECT_ROOT/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1)
[ -z "$PORT" ] && PORT=$(grep -oE 'PORT[= ]+([0-9]+)' "$PROJECT_ROOT/.env" 2>/dev/null | grep -oE '[0-9]+' | head -1)
[ -z "$PORT" ] && PORT="3000"
echo "PORT: $PORT"

# dev 서버 실행 중인지 확인
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" 2>/dev/null | grep -qE "^[23]"; then
  echo "SERVER: running on :$PORT"
else
  echo "SERVER: NOT RUNNING on :$PORT"
fi

# 히스토리 확인
if [ -f "$PROJECT_ROOT/.claude/test-reports/HISTORY.md" ]; then
  echo "HISTORY:"
  head -9 "$PROJECT_ROOT/.claude/test-reports/HISTORY.md"
fi
```

## 동작

하네스가 설치되어 있지 않으면:

> Test Gate 하네스가 설치되어 있지 않습니다.
> 설치: `git clone https://github.com/lolu1032/test-gate.git && cd test-gate && ./install.sh`

서버가 실행 중이지 않으면 AskUserQuestion:

> localhost:{PORT}에 서버가 떠있지 않습니다. 테스트하려면 dev 서버가 필요해요.

Options:
- A) 내가 직접 띄울게 — 기다려
- B) 다른 포트 지정
- C) 취소

서버가 실행 중이면 AskUserQuestion:

> **웹 테스트** — {프로젝트명} (localhost:{PORT})
> 커밋: {hash} {message}
> 시나리오: {있음/없음}

Options:
- A) 테스트 시작
- B) 테스트 시나리오 먼저 설정 (.claude/test-scenarios.md 생성)
- C) 취소

### A) 테스트 시작

프로젝트별 시나리오가 없고 포트가 3000이 아니면, 포트를 바꾼 시나리오를 자동 생성:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SCENARIOS="$PROJECT_ROOT/.claude/test-scenarios.md"
if [ ! -f "$SCENARIOS" ] && [ "$PORT" != "3000" ]; then
  mkdir -p "$PROJECT_ROOT/.claude"
  sed "s/localhost:3000/localhost:$PORT/g" "$HOME/.claude/test-harness/browser-test-prompt.md" > "$SCENARIOS"
  echo "Created: $SCENARIOS (port $PORT)"
fi
```

**브라우저 테스트만 실행** (Tauri 제외):

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HASH=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
HARNESS_DIR="$HOME/.claude/test-harness"
REPORT_DIR="$PROJECT_ROOT/.claude/test-reports"
mkdir -p "$REPORT_DIR"

PROMPT_FILE="$PROJECT_ROOT/.claude/test-scenarios.md"
[ ! -f "$PROMPT_FILE" ] && PROMPT_FILE="$HARNESS_DIR/browser-test-prompt.md"

COMMIT_MSG=$(git -C "$PROJECT_ROOT" log -1 --format="%s")
CHANGED_FILES=$(git -C "$PROJECT_ROOT" diff-tree --no-commit-id --name-only -r "$HASH" 2>/dev/null | head -20)
HISTORY_CONTEXT=""
[ -f "$REPORT_DIR/HISTORY.md" ] && HISTORY_CONTEXT="$(head -14 "$REPORT_DIR/HISTORY.md")"

nohup bash -c "
claude --print \
  -p \"Testing commit: $HASH ($COMMIT_MSG)
Changed files:
$CHANGED_FILES

$HISTORY_CONTEXT

\$(cat '$PROMPT_FILE')\" \
  --mcp-config '$HARNESS_DIR/browser-mcp.json' \
  --allowedTools 'mcp__playwright__*,Read,Glob,Grep' \
  --model claude-haiku-4-5-20251001 \
  > '$REPORT_DIR/$HASH-browser.md' 2>'$HARNESS_DIR/.last-test.log'

'$HARNESS_DIR/merge-reports.sh' '$HASH' '$PROJECT_ROOT' \$?

osascript -e 'display notification \"Web test done\" with title \"Test Gate [${HASH:0:8}]\" subtitle \"$(basename "$PROJECT_ROOT")\"' 2>/dev/null
command -v code >/dev/null && code '$REPORT_DIR/$HASH-report.md' 2>/dev/null
" > /dev/null 2>&1 &

echo "PID: $!"
```

실행 후:

> 웹 테스트가 백그라운드에서 실행 중입니다.
> 완료되면 macOS 알림이 옵니다.
> 리포트: {PROJECT_ROOT}/.claude/test-reports/{hash}-report.md

### B) 테스트 시나리오 설정

`.claude/test-scenarios.md` 파일을 생성한다. 사용자에게 URL, 로그인 정보, 테스트할 페이지를 물어보고 시나리오를 작성한다.

작성 후 "테스트 시작할까요?" 로 돌아간다.
