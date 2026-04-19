#!/bin/bash
# merge-reports.sh "$HASH" "$PROJECT_ROOT" "$EXIT_CODE"
# 각 테스트 파이프라인의 리포트를 합산하여 최종 리포트 생성.

HASH="$1"
PROJECT_ROOT="$2"
EXIT_BROWSER="${3:-0}"
EXIT_TAURI="${4:--1}"  # -1 = not run
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

    # Tauri MCP 결과
    if [ -f "$REPORT_DIR/$HASH-tauri.md" ]; then
        echo ""
        echo "---"
        echo "## Tauri Tests (Tauri MCP)"
        echo ""
        if [ "$EXIT_TAURI" -eq 0 ] 2>/dev/null; then
            echo "Status: COMPLETED"
        elif [ "$EXIT_TAURI" -eq -1 ] 2>/dev/null; then
            echo "Status: NOT RUN"
        else
            echo "Status: ERROR (exit code $EXIT_TAURI)"
        fi
        echo ""
        cat "$REPORT_DIR/$HASH-tauri.md"
    fi

} > "$FINAL_REPORT"

echo "[test-harness] Report: $FINAL_REPORT"

# 리포트 검증: 스크린샷 경로가 실제 존재하는지 체크
ARTIFACTS_DIR="$REPORT_DIR/artifacts/$HASH"
if [ -f "$REPORT_DIR/$HASH-browser.md" ]; then
    MISSING_SCREENSHOTS=""
    # "Screenshot: /absolute/path" 형태에서 경로 추출
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        if [ ! -f "$path" ]; then
            MISSING_SCREENSHOTS="$MISSING_SCREENSHOTS$path\n"
        fi
    done < <(grep -oE 'Screenshot:[[:space:]]*[^[:space:]]+' "$REPORT_DIR/$HASH-browser.md" 2>/dev/null | sed 's/Screenshot:[[:space:]]*//')

    if [ -n "$MISSING_SCREENSHOTS" ]; then
        {
            echo ""
            echo "---"
            echo "## ⚠ Validation Warnings"
            echo ""
            echo "Report references screenshots that do not exist:"
            echo -e "$MISSING_SCREENSHOTS"
            echo "This usually means the test agent reported findings without actually capturing evidence."
        } >> "$FINAL_REPORT"
    fi

    # 관찰 서술 누락 검증: "[PASS] xxx" 로만 끝나는 라인 카운트
    SHALLOW_PASS=$(grep -cE '^\- \[PASS\] [^:]+$' "$REPORT_DIR/$HASH-browser.md" 2>/dev/null || echo 0)
    if [ "$SHALLOW_PASS" -gt 0 ] 2>/dev/null; then
        {
            echo ""
            echo "## ⚠ Shallow Pass Warnings"
            echo ""
            echo "$SHALLOW_PASS PASS entries have no observation description (just a checkmark)."
            echo "Consider tightening the test prompt to require observation sentences."
        } >> "$FINAL_REPORT"
    fi
fi

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

# Summary 라인에서 숫자 추출 시도, 없으면 grep으로 카운트
PASS_COUNT=$(grep -oE 'Pass: ([0-9]+)' "$REPORT_DIR/$HASH-browser.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
FAIL_COUNT=$(grep -oE 'Fail: ([0-9]+)' "$REPORT_DIR/$HASH-browser.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
# Summary 라인이 없으면 [PASS]/[FAIL] 카운트로 폴백
if [ -z "$PASS_COUNT" ]; then
    PASS_COUNT=$(grep -c '\[PASS\]' "$REPORT_DIR/$HASH-browser.md" 2>/dev/null)
    [ -z "$PASS_COUNT" ] && PASS_COUNT=0
fi
if [ -z "$FAIL_COUNT" ]; then
    FAIL_COUNT=$(grep -c '\[FAIL\]' "$REPORT_DIR/$HASH-browser.md" 2>/dev/null)
    [ -z "$FAIL_COUNT" ] && FAIL_COUNT=0
fi
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

# 같은 커밋 해시의 기존 행이 있으면 삭제 (재테스트 시 최신 결과만 유지)
if grep -q "\`$SHORT_HASH\`" "$HISTORY_FILE" 2>/dev/null; then
    # macOS/BSD sed와 GNU sed 모두 호환
    sed -i.bak "/\`$SHORT_HASH\`/d" "$HISTORY_FILE" 2>/dev/null
    rm -f "$HISTORY_FILE.bak"
fi

# 새 행 추가 — 테이블 구분자 라인 바로 아래에 삽입 (최신이 위로)
NEW_ROW="| $DATE | \`$SHORT_HASH\` | $COMMIT_MSG | **$RESULT** | $PASS_COUNT | $FAIL_COUNT | [$SHORT_HASH-report]($HASH-report.md) |"

# awk로 안전하게 삽입: |------| 라인 바로 다음에 새 행 추가
TMP_FILE=$(mktemp)
awk -v row="$NEW_ROW" '
    /^\|------/ && !inserted {
        print
        print row
        inserted = 1
        next
    }
    { print }
' "$HISTORY_FILE" > "$TMP_FILE"

# 삽입 성공 여부 확인 후 덮어쓰기
if grep -q "$SHORT_HASH" "$TMP_FILE"; then
    mv "$TMP_FILE" "$HISTORY_FILE"
else
    # awk 실패 시 append 폴백
    rm -f "$TMP_FILE"
    echo "$NEW_ROW" >> "$HISTORY_FILE"
fi
