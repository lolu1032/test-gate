#!/bin/bash
# merge-reports.sh "$HASH" "$PROJECT_ROOT" "$EXIT_CODE"
# 각 테스트 파이프라인의 리포트를 합산하여 최종 리포트 생성.

HASH="$1"
PROJECT_ROOT="$2"
EXIT_BROWSER="${3:-0}"
REPORT_DIR="$PROJECT_ROOT/.claude/test-reports"
FINAL_REPORT="$REPORT_DIR/$HASH-report.md"

{
    echo "# Test Gate Report: ${HASH:0:8}"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Commit: $HASH"
    echo "Message: $(git -C "$PROJECT_ROOT" log -1 --format='%s' 2>/dev/null || echo 'unknown')"
    echo ""

    # Browser MCP 결과
    if [ -f "$REPORT_DIR/$HASH-browser.md" ]; then
        echo "---"
        echo "## Browser Tests (Playwright MCP)"
        echo ""
        if [ "$EXIT_BROWSER" -eq 0 ]; then
            echo "Status: COMPLETED"
        else
            echo "Status: ERROR (exit code $EXIT_BROWSER)"
        fi
        echo ""
        cat "$REPORT_DIR/$HASH-browser.md"
    else
        echo "## Browser Tests"
        echo "Status: NOT RUN"
    fi

    # Phase 2: Tauri MCP 결과 (나중에 추가)
    # if [ -f "$REPORT_DIR/$HASH-tauri.md" ]; then
    #     echo ""
    #     echo "---"
    #     echo "## Tauri Tests (Tauri MCP)"
    #     cat "$REPORT_DIR/$HASH-tauri.md"
    # fi

} > "$FINAL_REPORT"

echo "[test-harness] Report: $FINAL_REPORT"

# 히스토리 인덱스 업데이트
HISTORY_FILE="$REPORT_DIR/HISTORY.md"

# 결과 판별 (PASS/FAIL/ERROR)
if [ "$EXIT_BROWSER" -ne 0 ]; then
    RESULT="ERROR"
elif grep -q "\[FAIL\]" "$REPORT_DIR/$HASH-browser.md" 2>/dev/null; then
    RESULT="FAIL"
else
    RESULT="PASS"
fi

PASS_COUNT=$(grep -c "\[PASS\]" "$REPORT_DIR/$HASH-browser.md" 2>/dev/null || echo "0")
FAIL_COUNT=$(grep -c "\[FAIL\]" "$REPORT_DIR/$HASH-browser.md" 2>/dev/null || echo "0")
SHORT_HASH="${HASH:0:8}"
COMMIT_MSG=$(git -C "$PROJECT_ROOT" log -1 --format='%s' 2>/dev/null || echo "unknown")
DATE=$(date '+%Y-%m-%d %H:%M')

# 헤더가 없으면 생성
if [ ! -f "$HISTORY_FILE" ]; then
    {
        echo "# Test Gate History"
        echo ""
        echo "| Date | Commit | Message | Result | Pass | Fail | Report |"
        echo "|------|--------|---------|--------|------|------|--------|"
    } > "$HISTORY_FILE"
fi

# 새 행 추가 (헤더 바로 다음에 삽입 — 최신이 위로)
sed -i '' "5a\\
| $DATE | \`$SHORT_HASH\` | $COMMIT_MSG | **$RESULT** | $PASS_COUNT | $FAIL_COUNT | [$SHORT_HASH-report]($HASH-report.md) |
" "$HISTORY_FILE" 2>/dev/null || {
    # sed -i '' 실패 시 (GNU sed 등) 그냥 append
    echo "| $DATE | \`$SHORT_HASH\` | $COMMIT_MSG | **$RESULT** | $PASS_COUNT | $FAIL_COUNT | [$SHORT_HASH-report]($HASH-report.md) |" >> "$HISTORY_FILE"
}
