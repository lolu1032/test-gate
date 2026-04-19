#!/bin/bash
# run-review.sh "$HASH" "$PROJECT_ROOT" [BASE_REF]
# 별도 Claude 세션에서 git diff를 리뷰하고 리포트 생성.

HASH="$1"
PROJECT_ROOT="$2"
BASE_REF="${3:-HEAD~1}"  # 기본: 직전 커밋과 비교
HARNESS_DIR="$HOME/.claude/test-harness"
REPORT_DIR="$PROJECT_ROOT/.claude/review-reports"
LOCK_FILE="$HARNESS_DIR/.review-running"
LOG_FILE="$HARNESS_DIR/.last-review.log"

# Lock 생성
echo $$ > "$LOCK_FILE"

# 리포트 디렉토리 생성
mkdir -p "$REPORT_DIR"

# 프로젝트별 시나리오 있으면 사용
PROMPT_FILE="$PROJECT_ROOT/.claude/code-review-scenarios.md"
if [ ! -f "$PROMPT_FILE" ]; then
    PROMPT_FILE="$HARNESS_DIR/code-review-prompt.md"
fi

PROMPT=$(cat "$PROMPT_FILE")

# 커밋 정보
COMMIT_MSG=$(git -C "$PROJECT_ROOT" log -1 --format="%s" 2>/dev/null || echo "unknown")

# diff 통계
DIFF_STAT=$(git -C "$PROJECT_ROOT" diff --stat "$BASE_REF" "$HASH" 2>/dev/null | tail -1)
CHANGED_FILES=$(git -C "$PROJECT_ROOT" diff --name-only "$BASE_REF" "$HASH" 2>/dev/null)

COMMIT_INFO="Reviewing commit: $HASH ($COMMIT_MSG)
Base: $BASE_REF
Diff stats: $DIFF_STAT

Changed files:
$CHANGED_FILES"

# 히스토리 컨텍스트 — 테스트 히스토리 참조 (리그레션 민감 영역 파악용)
TEST_HISTORY_FILE="$PROJECT_ROOT/.claude/test-reports/HISTORY.md"
HISTORY_CONTEXT=""
if [ -f "$TEST_HISTORY_FILE" ]; then
    HISTORY_CONTEXT="
## Recent Test History (regression-sensitive areas)
$(head -14 "$TEST_HISTORY_FILE")"
fi

# 리뷰 실행
# --allowedTools: 읽기 + git diff 명령만 허용
# --add-dir: 프로젝트 루트 접근 허용
(cd "$PROJECT_ROOT" && claude --print \
    -p "$COMMIT_INFO
$HISTORY_CONTEXT

$PROMPT

Now run 'git diff $BASE_REF HEAD' and review." \
    --allowedTools "Read,Glob,Grep,Bash(git *)" \
    --model claude-haiku-4-5-20251001) \
    > "$REPORT_DIR/$HASH-review.md" 2>"$LOG_FILE"

EXIT_CODE=$?

# 실패 시 에러 리포트
if [ $EXIT_CODE -ne 0 ]; then
    {
        echo "# Code Review Report: $HASH"
        echo "Date: $(date)"
        echo ""
        echo "## ERROR"
        echo "claude --print exited with code $EXIT_CODE"
        echo ""
        echo "### stderr"
        cat "$LOG_FILE"
    } > "$REPORT_DIR/$HASH-review.md"
fi

# 리뷰 히스토리 업데이트 (review-reports 폴더 내 HISTORY.md)
REVIEW_HISTORY="$REPORT_DIR/HISTORY.md"
if [ ! -f "$REVIEW_HISTORY" ]; then
    {
        echo "# Code Review History"
        echo ""
        echo "| Date | Commit | Message | P1 | P2 | P3 | Report |"
        echo "|------|--------|---------|----|----|----|--------|"
    } > "$REVIEW_HISTORY"
fi

P1_COUNT=$(grep -cE '^### \[P1\]' "$REPORT_DIR/$HASH-review.md" 2>/dev/null)
P2_COUNT=$(grep -cE '^### \[P2\]' "$REPORT_DIR/$HASH-review.md" 2>/dev/null)
P3_COUNT=$(grep -cE '^### \[P3\]' "$REPORT_DIR/$HASH-review.md" 2>/dev/null)
[ -z "$P1_COUNT" ] && P1_COUNT=0
[ -z "$P2_COUNT" ] && P2_COUNT=0
[ -z "$P3_COUNT" ] && P3_COUNT=0

SHORT_HASH="${HASH:0:8}"
DATE=$(date '+%Y-%m-%d %H:%M')
NEW_ROW="| $DATE | \`$SHORT_HASH\` | $COMMIT_MSG | $P1_COUNT | $P2_COUNT | $P3_COUNT | [$SHORT_HASH-review]($HASH-review.md) |"

# 같은 커밋의 기존 행 제거 후 추가
if grep -q "\`$SHORT_HASH\`" "$REVIEW_HISTORY" 2>/dev/null; then
    sed -i.bak "/\`$SHORT_HASH\`/d" "$REVIEW_HISTORY" 2>/dev/null
    rm -f "$REVIEW_HISTORY.bak"
fi

TMP_FILE=$(mktemp)
awk -v row="$NEW_ROW" '
    /^\|------/ && !inserted {
        print
        print row
        inserted = 1
        next
    }
    { print }
' "$REVIEW_HISTORY" > "$TMP_FILE"

if grep -q "$SHORT_HASH" "$TMP_FILE"; then
    mv "$TMP_FILE" "$REVIEW_HISTORY"
else
    rm -f "$TMP_FILE"
    echo "$NEW_ROW" >> "$REVIEW_HISTORY"
fi

# Lock 해제
rm -f "$LOCK_FILE"

# 알림 + VSCode
SUMMARY="P1:$P1_COUNT P2:$P2_COUNT P3:$P3_COUNT"
osascript -e "display notification \"$SUMMARY\" with title \"Code Review [$SHORT_HASH]\" subtitle \"$(basename "$PROJECT_ROOT")\"" 2>/dev/null

if [ -n "$VSCODE_IPC_HOOK_CLI" ] || command -v code >/dev/null 2>&1; then
    code "$REPORT_DIR/$HASH-review.md" 2>/dev/null
fi

echo ""
echo "════════════════════════════════════════"
echo " CODE REVIEW REPORT: $SHORT_HASH"
echo " Project: $(basename "$PROJECT_ROOT")"
echo " Findings: P1=$P1_COUNT P2=$P2_COUNT P3=$P3_COUNT"
echo "════════════════════════════════════════"
cat "$REPORT_DIR/$HASH-review.md"
echo "════════════════════════════════════════"
