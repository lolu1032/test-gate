#!/bin/bash
# check-and-run.sh — Claude Code PostToolUse hook에서 호출됨
# 새 커밋이 있으면 테스트를 백그라운드로 spawn한다.
# hook 자체는 즉시 반환 (코딩 에이전트 블로킹 없음).

HARNESS_DIR="$HOME/.claude/test-harness"
LAST_HASH_FILE="$HARNESS_DIR/.last-tested-hash"
LOCK_FILE="$HARNESS_DIR/.test-running"

# git repo인지 확인
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

HASH=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null) || exit 0
LAST_HASH=$(cat "$LAST_HASH_FILE" 2>/dev/null || echo "")

# 같은 커밋이면 스킵
[ "$HASH" = "$LAST_HASH" ] && exit 0

# 이미 테스트 실행 중이면 스킵 (동시 실행 방지)
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        exit 0
    fi
    # 죽은 프로세스의 lock file 정리
    rm -f "$LOCK_FILE"
fi

# 커밋 메시지에 [skip-test]가 있으면 스킵
COMMIT_MSG=$(git -C "$PROJECT_ROOT" log -1 --format="%s" 2>/dev/null || echo "")
echo "$COMMIT_MSG" | grep -q "\[skip-test\]" && exit 0

# 해시 저장
echo "$HASH" > "$LAST_HASH_FILE"

# 테스트를 백그라운드로 spawn
nohup "$HARNESS_DIR/run-all-tests.sh" "$HASH" "$PROJECT_ROOT" \
    > /dev/null 2>&1 &
