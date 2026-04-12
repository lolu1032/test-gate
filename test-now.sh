#!/bin/bash
# test-now.sh — 수동으로 테스트 게이트 실행
# 사용법: ~/.claude/test-harness/test-now.sh [프로젝트 경로]
# 프로젝트 경로 생략 시 현재 디렉토리의 git root 사용

HARNESS_DIR="$HOME/.claude/test-harness"

if [ -n "$1" ]; then
    PROJECT_ROOT="$1"
else
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
fi

if [ -z "$PROJECT_ROOT" ]; then
    echo "[test-harness] ERROR: git repo가 아닙니다."
    exit 1
fi

HASH=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null)
if [ -z "$HASH" ]; then
    echo "[test-harness] ERROR: 커밋이 없습니다."
    exit 1
fi

SHORT_HASH="${HASH:0:8}"
COMMIT_MSG=$(git -C "$PROJECT_ROOT" log -1 --format="%s" 2>/dev/null)

echo "════════════════════════════════════════"
echo " TEST GATE: $SHORT_HASH"
echo " Project: $(basename "$PROJECT_ROOT")"
echo " Commit: $COMMIT_MSG"
echo "════════════════════════════════════════"
echo ""
echo "테스트 시작... (백그라운드 실행)"

# 백그라운드로 실행
nohup "$HARNESS_DIR/run-all-tests.sh" "$HASH" "$PROJECT_ROOT" \
    > /dev/null 2>&1 &

echo "PID: $!"
echo "완료되면 macOS 알림이 옵니다."
echo "리포트: $PROJECT_ROOT/.claude/test-reports/$HASH-report.md"
