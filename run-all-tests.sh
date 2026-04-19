#!/bin/bash
# run-all-tests.sh "$HASH" "$PROJECT_ROOT"
# 백그라운드에서 실행됨. claude --print로 Playwright MCP 테스트를 돌리고 리포트 생성.

HASH="$1"
PROJECT_ROOT="$2"
HARNESS_DIR="$HOME/.claude/test-harness"
REPORT_DIR="$PROJECT_ROOT/.claude/test-reports"
LOCK_FILE="$HARNESS_DIR/.test-running"
LOG_FILE="$HARNESS_DIR/.last-test.log"

# Lock 생성
echo $$ > "$LOCK_FILE"

# 리포트 디렉토리 생성
mkdir -p "$REPORT_DIR"

# 시나리오 로드 헬퍼: 폴더에서 _always.md 먼저, 나머지 알파벳순으로 합침
load_scenarios_from_dir() {
    local dir="$1"
    local result=""
    if [ -f "$dir/_always.md" ]; then
        result="$(cat "$dir/_always.md")

---

"
    fi
    for file in $(find "$dir" -maxdepth 1 -name "*.md" ! -name "_always.md" | sort); do
        result="${result}$(cat "$file")

---

"
    done
    echo "$result"
}

# 웹 시나리오 로드 (우선순위)
# 1. .claude/test-scenarios/web/        (신규 표면별 폴더)
# 2. .claude/test-scenarios/            (구 폴더 — 호환)
# 3. .claude/test-scenarios.md          (구 단일 파일 — 호환)
# 4. 기본 프롬프트
WEB_SCENARIOS_NEW="$PROJECT_ROOT/.claude/test-scenarios/web"
WEB_SCENARIOS_OLD_DIR="$PROJECT_ROOT/.claude/test-scenarios"
WEB_SCENARIOS_OLD_FILE="$PROJECT_ROOT/.claude/test-scenarios.md"

if [ -d "$WEB_SCENARIOS_NEW" ]; then
    PROMPT=$(load_scenarios_from_dir "$WEB_SCENARIOS_NEW")
elif [ -d "$WEB_SCENARIOS_OLD_DIR" ] && [ ! -d "$WEB_SCENARIOS_NEW" ]; then
    # 구 폴더가 직접 .md 파일을 가지고 있으면 (web/ 하위 폴더가 아닌 경우)
    if find "$WEB_SCENARIOS_OLD_DIR" -maxdepth 1 -name "*.md" -type f | grep -q .; then
        PROMPT=$(load_scenarios_from_dir "$WEB_SCENARIOS_OLD_DIR")
    else
        PROMPT=$(cat "$HARNESS_DIR/browser-test-prompt.md")
    fi
elif [ -f "$WEB_SCENARIOS_OLD_FILE" ]; then
    PROMPT=$(cat "$WEB_SCENARIOS_OLD_FILE")
else
    PROMPT=$(cat "$HARNESS_DIR/browser-test-prompt.md")
fi
[ -z "$PROMPT" ] && PROMPT=$(cat "$HARNESS_DIR/browser-test-prompt.md")

# 커밋 정보를 프롬프트에 추가
COMMIT_MSG=$(git -C "$PROJECT_ROOT" log -1 --format="%s" 2>/dev/null || echo "unknown")
CHANGED_FILES=$(git -C "$PROJECT_ROOT" diff-tree --no-commit-id --name-only -r "$HASH" 2>/dev/null | head -20)
COMMIT_INFO="Testing commit: $HASH ($COMMIT_MSG)

Changed files:
$CHANGED_FILES"

# 테스트 히스토리가 있으면 프롬프트에 포함
HISTORY_FILE="$REPORT_DIR/HISTORY.md"
HISTORY_CONTEXT=""
if [ -f "$HISTORY_FILE" ]; then
    # 최근 10개만 포함 (프롬프트 크기 제한)
    HISTORY_CONTEXT="
## Recent Test History
$(head -14 "$HISTORY_FILE")"
fi

# 스크린샷/부산물을 담을 폴더 (프로젝트 루트 오염 방지)
ARTIFACTS_DIR="$REPORT_DIR/artifacts/$HASH"
mkdir -p "$ARTIFACTS_DIR"

# 프롬프트에 ARTIFACTS_DIR 절대경로 주입 ($ARTIFACTS_DIR 플레이스홀더 치환)
PROMPT_INJECTED=$(echo "$PROMPT" | sed "s|\$ARTIFACTS_DIR|$ARTIFACTS_DIR|g")

# Browser MCP 테스트 실행
# --print: 비대화형 모드
# --allowedTools: MCP + 읽기 도구만 허용 (수정 불가)
# --model: Haiku로 비용 절약
# CWD를 artifacts 폴더로 바꿔서 스크린샷/console 로그가 거기에 저장되게
(cd "$ARTIFACTS_DIR" && claude --print \
    -p "$COMMIT_INFO
$HISTORY_CONTEXT

ARTIFACTS_DIR=$ARTIFACTS_DIR

$PROMPT_INJECTED" \
    --mcp-config "$HARNESS_DIR/browser-mcp.json" \
    --allowedTools "mcp__playwright__*,Read,Glob,Grep" \
    --model claude-haiku-4-5-20251001) \
    > "$REPORT_DIR/$HASH-browser.md" 2>"$LOG_FILE"

EXIT_CODE=$?

# 실패 시 에러 리포트 생성
if [ $EXIT_CODE -ne 0 ]; then
    {
        echo "# Test Report: $HASH"
        echo "Date: $(date)"
        echo ""
        echo "## ERROR"
        echo "claude --print exited with code $EXIT_CODE"
        echo ""
        echo "### stderr"
        cat "$LOG_FILE"
    } > "$REPORT_DIR/$HASH-browser.md"
fi

# Tauri MCP 테스트 (Tauri 프로젝트인 경우에만)
EXIT_TAURI=-1
if [ -f "$PROJECT_ROOT/src-tauri/tauri.conf.json" ] || [ -f "$PROJECT_ROOT/src-tauri/Cargo.toml" ]; then
    # 데스크톱 시나리오 로드 (우선순위)
    # 1. .claude/test-scenarios/desktop/    (신규 표면별 폴더)
    # 2. .claude/tauri-test-scenarios/      (구 폴더 — 호환)
    # 3. .claude/tauri-test-scenarios.md    (구 단일 파일 — 호환)
    # 4. 기본 프롬프트
    DESKTOP_SCENARIOS_NEW="$PROJECT_ROOT/.claude/test-scenarios/desktop"
    DESKTOP_SCENARIOS_OLD_DIR="$PROJECT_ROOT/.claude/tauri-test-scenarios"
    DESKTOP_SCENARIOS_OLD_FILE="$PROJECT_ROOT/.claude/tauri-test-scenarios.md"

    if [ -d "$DESKTOP_SCENARIOS_NEW" ]; then
        TAURI_PROMPT=$(load_scenarios_from_dir "$DESKTOP_SCENARIOS_NEW")
    elif [ -d "$DESKTOP_SCENARIOS_OLD_DIR" ]; then
        TAURI_PROMPT=$(load_scenarios_from_dir "$DESKTOP_SCENARIOS_OLD_DIR")
    elif [ -f "$DESKTOP_SCENARIOS_OLD_FILE" ]; then
        TAURI_PROMPT=$(cat "$DESKTOP_SCENARIOS_OLD_FILE")
    else
        TAURI_PROMPT=$(cat "$HARNESS_DIR/tauri-test-prompt.md")
    fi
    [ -z "$TAURI_PROMPT" ] && TAURI_PROMPT=$(cat "$HARNESS_DIR/tauri-test-prompt.md")
    TAURI_PROMPT_INJECTED=$(echo "$TAURI_PROMPT" | sed "s|\$ARTIFACTS_DIR|$ARTIFACTS_DIR|g")

    (cd "$ARTIFACTS_DIR" && claude --print \
        -p "$COMMIT_INFO
$HISTORY_CONTEXT

ARTIFACTS_DIR=$ARTIFACTS_DIR

$TAURI_PROMPT_INJECTED" \
        --mcp-config "$HARNESS_DIR/tauri-mcp.json" \
        --allowedTools "mcp__tauri__*,Read,Glob,Grep" \
        --model claude-haiku-4-5-20251001) \
        > "$REPORT_DIR/$HASH-tauri.md" 2>"$HARNESS_DIR/.last-tauri-test.log"

    EXIT_TAURI=$?

    if [ $EXIT_TAURI -ne 0 ]; then
        {
            echo "# Tauri Test Report: $HASH"
            echo "Date: $(date)"
            echo ""
            echo "## ERROR"
            echo "claude --print exited with code $EXIT_TAURI"
            echo ""
            echo "### stderr"
            cat "$HARNESS_DIR/.last-tauri-test.log"
        } > "$REPORT_DIR/$HASH-tauri.md"
    fi
fi

# 합산 리포트 생성
"$HARNESS_DIR/merge-reports.sh" "$HASH" "$PROJECT_ROOT" "$EXIT_CODE" "$EXIT_TAURI"

# 부산물 정리 (artifacts 폴더에 쌓인 것 처리)
HAS_FAIL=0
if grep -q "\[FAIL\]" "$REPORT_DIR/$HASH-browser.md" 2>/dev/null; then
    HAS_FAIL=1
fi
if [ -f "$REPORT_DIR/$HASH-tauri.md" ] && grep -q "\[FAIL\]" "$REPORT_DIR/$HASH-tauri.md" 2>/dev/null; then
    HAS_FAIL=1
fi

if [ $HAS_FAIL -eq 0 ]; then
    # PASS면 artifacts 폴더 전부 삭제
    rm -rf "$ARTIFACTS_DIR"
else
    # FAIL이면 console 로그만 삭제, 스크린샷은 디버깅용으로 남김
    find "$ARTIFACTS_DIR" -name 'console-*' -delete 2>/dev/null
fi

# 만약 예전 버전이 프로젝트 루트에 남긴 파일이 있으면 정리
cd "$PROJECT_ROOT" || exit 0
rm -f console-*.md console-*.txt 2>/dev/null
if [ $HAS_FAIL -eq 0 ]; then
    rm -f page-*.png page-*.jpg page-*.jpeg 2>/dev/null
else
    mkdir -p "$ARTIFACTS_DIR"
    mv page-*.png page-*.jpg page-*.jpeg "$ARTIFACTS_DIR/" 2>/dev/null
fi

# Lock 해제
rm -f "$LOCK_FILE"

# 리포트 요약 추출 (Summary 라인 찾기)
REPORT_FILE="$REPORT_DIR/$HASH-report.md"
SUMMARY=$(grep -E "^Total:|^Status:" "$REPORT_DIR/$HASH-browser.md" 2>/dev/null | head -1)
[ -z "$SUMMARY" ] && SUMMARY="Test completed"
SHORT_HASH="${HASH:0:8}"

# macOS 알림
osascript -e "display notification \"$SUMMARY\" with title \"Test Gate [$SHORT_HASH]\" subtitle \"$(basename "$PROJECT_ROOT")\"" 2>/dev/null

# VSCode에서 실행 중이면 리포트를 자동으로 열기
if [ -n "$VSCODE_IPC_HOOK_CLI" ] || command -v code >/dev/null 2>&1; then
    code "$REPORT_FILE" 2>/dev/null
fi

# 터미널용: 리포트 내용을 stdout에 출력
echo ""
echo "════════════════════════════════════════"
echo " TEST GATE REPORT: $SHORT_HASH"
echo " Project: $(basename "$PROJECT_ROOT")"
echo "════════════════════════════════════════"
cat "$REPORT_FILE"
echo "════════════════════════════════════════"
