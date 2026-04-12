---
name: test-tauri
description: 별도 세션에서 Tauri MCP로 데스크톱앱 QA 테스트 실행
user_invocable: true
---

# Test Tauri

별도 Claude 세션에서 Tauri MCP로 데스크톱앱을 테스트하고 리포트를 생성한다.

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

# Tauri 프로젝트인지 확인
if [ -f "$PROJECT_ROOT/src-tauri/tauri.conf.json" ] || [ -f "$PROJECT_ROOT/src-tauri/Cargo.toml" ]; then
  echo "TAURI: detected"
  # 앱 이름 추출
  TAURI_APP=$(grep -oE '"productName":\s*"[^"]+"' "$PROJECT_ROOT/src-tauri/tauri.conf.json" 2>/dev/null | grep -oE '"[^"]+"\s*$' | tr -d '"' || echo "unknown")
  echo "APP_NAME: $TAURI_APP"
else
  echo "TAURI: NOT DETECTED"
fi

# Tauri 시나리오 확인
if [ -f "$PROJECT_ROOT/.claude/tauri-test-scenarios.md" ]; then
  echo "SCENARIOS: project-specific"
else
  echo "SCENARIOS: default"
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

Tauri 프로젝트가 아니면:

> 이 프로젝트에서 `src-tauri/` 디렉토리를 찾을 수 없습니다.
> Tauri 프로젝트가 아니라면 `/test-web`으로 웹 테스트를 실행하세요.

Tauri 프로젝트이면 AskUserQuestion:

> **Tauri 테스트** — {앱이름}
> 커밋: {hash} {message}
> 시나리오: {있음/없음}
>
> Tauri 앱을 빌드하고 실행한 뒤 네이티브 기능(창, 메뉴, IPC 등)을 테스트합니다.
> 빌드에 시간이 걸릴 수 있습니다.

Options:
- A) 테스트 시작
- B) 테스트 시나리오 먼저 설정 (.claude/tauri-test-scenarios.md 생성)
- C) 웹 테스트도 같이 (/test-web + /test-tauri)
- D) 취소

### A) 테스트 시작

**Tauri 테스트만 실행** (브라우저 제외):

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HASH=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
HARNESS_DIR="$HOME/.claude/test-harness"
REPORT_DIR="$PROJECT_ROOT/.claude/test-reports"
mkdir -p "$REPORT_DIR"

PROMPT_FILE="$PROJECT_ROOT/.claude/tauri-test-scenarios.md"
[ ! -f "$PROMPT_FILE" ] && PROMPT_FILE="$HARNESS_DIR/tauri-test-prompt.md"

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
  --mcp-config '$HARNESS_DIR/tauri-mcp.json' \
  --allowedTools 'mcp__tauri__*,Read,Glob,Grep' \
  --model claude-haiku-4-5-20251001 \
  > '$REPORT_DIR/$HASH-tauri.md' 2>'$HARNESS_DIR/.last-tauri-test.log'

'$HARNESS_DIR/merge-reports.sh' '$HASH' '$PROJECT_ROOT' -1 \$?

osascript -e 'display notification \"Tauri test done\" with title \"Test Gate [${HASH:0:8}]\" subtitle \"$(basename "$PROJECT_ROOT")\"' 2>/dev/null
command -v code >/dev/null && code '$REPORT_DIR/$HASH-report.md' 2>/dev/null
" > /dev/null 2>&1 &

echo "PID: $!"
```

실행 후:

> Tauri 테스트가 백그라운드에서 실행 중입니다.
> 완료되면 macOS 알림이 옵니다.
> 리포트: {PROJECT_ROOT}/.claude/test-reports/{hash}-report.md

### B) 테스트 시나리오 설정

`.claude/tauri-test-scenarios.md` 파일을 생성한다. 사용자에게 어떤 네이티브 기능을 테스트할지 물어보고 시나리오를 작성한다.

예시:
```markdown
# Tauri 테스트 시나리오

## 앱 실행
1. 앱이 정상적으로 실행되는지 확인
2. 윈도우 타이틀이 올바른지 확인

## 네이티브 기능
1. 시스템 트레이 아이콘 표시 확인
2. 메뉴바 항목 동작 확인
3. 파일 열기 다이얼로그 동작 확인

## 웹뷰 콘텐츠
1. 메인 페이지 로드 확인
2. IPC 통신 테스트 (Rust ↔ Frontend)
```

작성 후 "테스트 시작할까요?" 로 돌아간다.

### C) 웹 + Tauri 동시

`/test-web`과 `/test-tauri`를 순차 실행한다. 먼저 웹 테스트를 실행하고, 완료 후 Tauri 테스트를 실행한다.
