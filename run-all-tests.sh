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

# 프로젝트별 테스트 시나리오가 있으면 사용, 없으면 기본 프롬프트
PROMPT_FILE="$PROJECT_ROOT/.claude/test-scenarios.md"
if [ ! -f "$PROMPT_FILE" ]; then
    PROMPT_FILE="$HARNESS_DIR/browser-test-prompt.md"
fi

PROMPT=$(cat "$PROMPT_FILE")

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

# Browser MCP 테스트 실행
# --print: 비대화형 모드
# --allowedTools: MCP + 읽기 도구만 허용 (수정 불가)
# --model: Haiku로 비용 절약
claude --print \
    -p "$COMMIT_INFO
$HISTORY_CONTEXT

$PROMPT" \
    --mcp-config "$HARNESS_DIR/browser-mcp.json" \
    --allowedTools "mcp__playwright__*,Read,Glob,Grep" \
    --model claude-haiku-4-5-20251001 \
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

# 합산 리포트 생성
"$HARNESS_DIR/merge-reports.sh" "$HASH" "$PROJECT_ROOT" "$EXIT_CODE"

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
