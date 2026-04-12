---
name: test-gate
description: AI 에이전트 테스트 격리 — 별도 세션에서 Playwright MCP(웹) + Tauri MCP(데스크톱) QA 실행
user_invocable: true
---

# Test Gate

별도 Claude 세션에서 웹앱(Playwright MCP) 또는 Tauri 데스크톱앱(Tauri MCP)을 테스트하고 리포트를 생성한다.

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

# Tauri 프로젝트인지 확인
if [ -f "$PROJECT_ROOT/src-tauri/tauri.conf.json" ] || [ -f "$PROJECT_ROOT/src-tauri/Cargo.toml" ]; then
  echo "TAURI: detected"
  if [ -f "$PROJECT_ROOT/.claude/tauri-test-scenarios.md" ]; then
    echo "TAURI_SCENARIOS: project-specific"
  else
    echo "TAURI_SCENARIOS: default"
  fi
else
  echo "TAURI: not detected"
fi

# 포트 감지 (package.json에서 dev 스크립트 확인)
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
```

## 동작

하네스가 설치되어 있지 않으면:

> Test Gate 하네스가 설치되어 있지 않습니다.
> 설치하려면: `git clone https://github.com/lolu1032/test-gate.git && cd test-gate && ./install.sh`

서버가 실행 중이지 않으면 AskUserQuestion:

> localhost:{PORT}에 서버가 떠있지 않습니다. 테스트하려면 dev 서버가 필요해요.

Options:
- A) 내가 직접 띄울게 — 기다려
- B) 다른 포트 지정
- C) 취소

B를 선택하면 포트 번호를 입력받는다.

서버가 실행 중이면 AskUserQuestion:

> {프로젝트명}의 localhost:{PORT}을 테스트합니다.
> 커밋: {hash} {message}
>
> 테스트 에이전트가 별도 세션에서 Playwright MCP로 앱을 돌아보고 리포트를 만듭니다.
> 프로젝트별 시나리오: {있음/없음 (.claude/test-scenarios.md)}

Options:
- A) 테스트 시작
- B) 테스트 시나리오 먼저 설정 (.claude/test-scenarios.md 생성)
- C) 취소

### A) 테스트 시작

프로젝트별 시나리오가 없고 포트가 3000이 아니면, 임시 시나리오를 자동 생성한다:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SCENARIOS="$PROJECT_ROOT/.claude/test-scenarios.md"
if [ ! -f "$SCENARIOS" ] && [ "$PORT" != "3000" ]; then
  mkdir -p "$PROJECT_ROOT/.claude"
  # 포트만 바꾼 기본 프롬프트를 생성
  sed "s/localhost:3000/localhost:$PORT/g" "$HOME/.claude/test-harness/browser-test-prompt.md" > "$SCENARIOS"
  echo "Created: $SCENARIOS (port $PORT)"
fi
```

테스트 실행:

```bash
~/.claude/test-harness/test-now.sh "$PROJECT_ROOT"
```

실행 후 사용자에게:

> 테스트가 백그라운드에서 실행 중입니다.
> 완료되면 macOS 알림이 옵니다.
> 리포트: {PROJECT_ROOT}/.claude/test-reports/{hash}-report.md
>
> 이전 테스트 히스토리가 있으면 표시:
> (HISTORY.md의 최근 5개 행)

### B) 테스트 시나리오 설정

`.claude/test-scenarios.md` 파일을 생성한다. 사용자에게 어떤 페이지와 기능을 테스트할지 물어보고 시나리오를 작성한다.

작성 후 "테스트 시작할까요?" 로 돌아간다.
