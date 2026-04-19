---
name: test-desktop
description: 별도 세션에서 데스크톱앱 QA 테스트 실행 (현재 Tauri MCP 지원)
user_invocable: true
---

# Test Desktop

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
    TAURI_APP=$(grep -oE '"productName":\s*"[^"]+"' "$PROJECT_ROOT/src-tauri/tauri.conf.json" 2>/dev/null | grep -oE '"[^"]+"\s*$' | tr -d '"' || echo "unknown")
    echo "APP_NAME: $TAURI_APP"
else
    echo "TAURI: NOT DETECTED"
fi

# 시나리오 감지 (우선순위: 신규 폴더 → 구 폴더 → 구 단일 파일)
SCENARIOS_NEW="$PROJECT_ROOT/.claude/test-scenarios/desktop"
SCENARIOS_OLD_DIR="$PROJECT_ROOT/.claude/tauri-test-scenarios"
SCENARIOS_OLD_FILE="$PROJECT_ROOT/.claude/tauri-test-scenarios.md"
setopt +o nomatch 2>/dev/null

if [ -d "$SCENARIOS_NEW" ]; then
    echo "SCENARIOS: folder (.claude/test-scenarios/desktop/)"
    for f in "$SCENARIOS_NEW"/*.md; do
        [ -f "$f" ] || continue
        lines=$(wc -l < "$f" | tr -d ' ')
        echo "  - $(basename "$f") ($lines lines)"
    done
elif [ -d "$SCENARIOS_OLD_DIR" ]; then
    echo "SCENARIOS: legacy folder (.claude/tauri-test-scenarios/) — consider migrating to test-scenarios/desktop/"
    for f in "$SCENARIOS_OLD_DIR"/*.md; do
        [ -f "$f" ] || continue
        lines=$(wc -l < "$f" | tr -d ' ')
        echo "  - $(basename "$f") ($lines lines)"
    done
elif [ -f "$SCENARIOS_OLD_FILE" ]; then
    echo "SCENARIOS: legacy single file (.claude/tauri-test-scenarios.md, $(wc -l < "$SCENARIOS_OLD_FILE" | tr -d ' ') lines)"
else
    echo "SCENARIOS: none (default prompt)"
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

### 시나리오 상태별 분기

**모든 경우 항상 사용자에게 먼저 묻는다. 자동으로 진행하지 않는다.**

**시나리오가 폴더인 경우** — 파일 목록 + AskUserQuestion:

> **Tauri 테스트** — {앱이름}
> 커밋: {hash} {message}
> 시나리오 폴더: .claude/tauri-test-scenarios/ ({N}개 파일)
>
> 파일: _always.md, window.md, ipc.md, ... 등

Options:
- A) 그대로 실행
- B) 시나리오 파일 추가 — 사용자가 직접 내용 작성
- C) 시나리오 관리 (편집/삭제)
- D) 웹 테스트도 함께 (/test-web + /test-tauri)
- E) 취소

**시나리오가 단일 파일인 경우** — 미리보기 + AskUserQuestion:

> **Tauri 테스트** — {앱이름}
> 커밋: {hash} {message}
> 시나리오 파일: .claude/tauri-test-scenarios.md ({N}줄)
>
> --- 미리보기 ---
> {파일 내용 전체 또는 앞 30줄}

Options:
- A) 그대로 실행
- B) 시나리오 추가 — 사용자가 직접 작성
- C) 시나리오 수정 — 사용자가 직접 재작성
- D) 폴더 방식으로 분할
- E) 웹 테스트도 함께
- F) 취소

**시나리오가 없는 경우** — 반드시 사용자에게 먼저 묻는다. 자동으로 기본 프롬프트 실행 금지:

> **Tauri 테스트** — {앱이름}
> 커밋: {hash} {message}
> 시나리오: 없음
>
> 시나리오 없이 돌리면 에이전트가 앱을 무작위로 돌아봅니다.
> 테스트 품질을 위해 시나리오를 직접 작성하는 것을 권장해요.

Options:
- A) 시나리오 직접 작성 — 단일 파일 (.claude/tauri-test-scenarios.md)
- B) 시나리오 폴더 만들기 — 기능별 분할 (.claude/tauri-test-scenarios/)
- C) 기본 프롬프트로 그냥 돌리기 — 시나리오 없이 (비추천)
- D) 웹 테스트도 함께
- E) 취소

## 실행 로직

### A) 그대로 실행 (Tauri만)

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
HASH=$(git rev-parse HEAD)
HARNESS_DIR="$HOME/.claude/test-harness"
REPORT_DIR="$PROJECT_ROOT/.claude/test-reports"
mkdir -p "$REPORT_DIR"

# run-all-tests.sh가 폴더/단일/기본 시나리오 자동 감지
# Tauri만 실행하려면 browser 스킵 플래그가 필요하지만 현재는 run-all-tests.sh 사용
nohup ~/.claude/test-harness/run-all-tests.sh "$HASH" "$PROJECT_ROOT" \
    > /dev/null 2>&1 &

echo "PID: $!"
```

### B) 시나리오 추가

**단일 파일 상태**: 현재 파일 끝에 새 섹션 append.

**폴더 상태**: 새 파일 이름 물어보고 `.claude/tauri-test-scenarios/{name}.md` 생성.

예시:
```markdown
# {Feature Name} Tests

## 네이티브 기능
- {창 관리 / 메뉴 / 트레이 / IPC} 테스트

## 웹뷰
- {페이지/기능} 확인
```

### C) 시나리오 관리 (폴더)

폴더 내 파일 목록 보여주고 편집/삭제/이름변경 진행.

### 단일 파일 → 폴더 마이그레이션

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
mkdir -p "$PROJECT_ROOT/.claude/tauri-test-scenarios"
mv "$PROJECT_ROOT/.claude/tauri-test-scenarios.md" "$PROJECT_ROOT/.claude/tauri-test-scenarios/_always.md"
echo "Migrated to folder structure."
```

### 웹 + Tauri 동시 실행

기본 `run-all-tests.sh`가 `src-tauri/`를 감지하면 자동으로 브라우저 + Tauri 둘 다 돌린다.

## 시나리오 폴더 구조 (권장)

```
.claude/tauri-test-scenarios/
├── _always.md        # 항상 실행 (앱 실행, 윈도우 기본)
├── window.md         # 창 관리 (리사이즈, 최소화 등)
├── ipc.md            # Rust ↔ Frontend IPC
├── menu.md           # 네이티브 메뉴
└── tray.md           # 시스템 트레이
```

실행 시 폴더 내 모든 `.md` 파일이 `_always.md` 먼저, 나머지는 알파벳 순으로 합쳐져 프롬프트로 전달된다.
