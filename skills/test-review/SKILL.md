---
name: test-review
description: 별도 세션에서 git diff 기반 코드 리뷰 실행 — 보안, 성능, 정확성, 테스트 커버리지
user_invocable: true
---

# Test Review

별도 Claude 세션에서 git diff를 리뷰하고 리포트를 생성한다. 세션 격리로 코딩 에이전트의 확증 편향을 차단한다.

## 실행

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT: $PROJECT_ROOT"

# git repo 확인
if [ -z "$PROJECT_ROOT" ]; then
    echo "ERROR: not a git repo"
    exit 1
fi

HASH=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null)
echo "COMMIT: ${HASH:0:8} $(git -C "$PROJECT_ROOT" log -1 --format='%s')"

# 하네스 설치 확인
if [ -x "$HOME/.claude/test-harness/run-review.sh" ]; then
    echo "HARNESS: installed"
else
    echo "HARNESS: NOT INSTALLED"
fi

# 기본 base ref 감지
BASE_REF="HEAD~1"
MAIN_BRANCH=$(git -C "$PROJECT_ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
[ -z "$MAIN_BRANCH" ] && MAIN_BRANCH="main"
CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ] && git -C "$PROJECT_ROOT" rev-parse "origin/$MAIN_BRANCH" >/dev/null 2>&1; then
    BASE_REF="origin/$MAIN_BRANCH"
fi
echo "BASE_REF: $BASE_REF"

# diff 크기
DIFF_STAT=$(git -C "$PROJECT_ROOT" diff --stat "$BASE_REF" HEAD 2>/dev/null | tail -1)
echo "DIFF: $DIFF_STAT"

# 프로젝트별 시나리오 확인
if [ -f "$PROJECT_ROOT/.claude/code-review-scenarios.md" ]; then
    echo "SCENARIOS: project-specific"
else
    echo "SCENARIOS: default"
fi

# 리뷰 히스토리 확인
if [ -f "$PROJECT_ROOT/.claude/review-reports/HISTORY.md" ]; then
    echo "HISTORY:"
    head -9 "$PROJECT_ROOT/.claude/review-reports/HISTORY.md"
fi
```

## 동작

하네스가 설치되어 있지 않으면:

> Test Gate 하네스가 설치되어 있지 않습니다.
> 설치: `git clone https://github.com/lolu1032/test-gate.git && cd test-gate && ./install.sh`

diff가 비어있으면:

> BASE_REF와 HEAD 사이에 변경사항이 없습니다. 리뷰할 것이 없어요.

diff가 있으면 AskUserQuestion:

> **코드 리뷰** — {프로젝트명}
> 커밋: {hash} {message}
> Diff: {base}..HEAD ({N} files)
> 시나리오: {있음/없음}
>
> 별도 세션에서 git diff를 리뷰합니다. 보안, 성능, 정확성, 테스트 커버리지, 코드 품질, 일관성 6개 카테고리로 점검.

Options:
- A) 기본 base로 리뷰 (origin/main..HEAD 또는 HEAD~1)
- B) 다른 base 지정 (예: origin/main, HEAD~5)
- C) 시나리오 먼저 설정 (.claude/code-review-scenarios.md 생성)
- D) 취소

### A) 리뷰 시작

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
HASH=$(git rev-parse HEAD)

# base_ref 자동 감지 (위 로직)
BASE_REF="HEAD~1"
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
[ -z "$MAIN_BRANCH" ] && MAIN_BRANCH="main"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ] && git rev-parse "origin/$MAIN_BRANCH" >/dev/null 2>&1; then
    BASE_REF="origin/$MAIN_BRANCH"
fi

nohup ~/.claude/test-harness/run-review.sh "$HASH" "$PROJECT_ROOT" "$BASE_REF" \
    > /dev/null 2>&1 &

echo "PID: $!"
```

### B) 다른 base 지정

사용자에게 base ref를 입력받고 A)와 동일하게 실행.

### C) 시나리오 설정

`.claude/code-review-scenarios.md`를 생성한다. 프로젝트별 추가 리뷰 규칙을 정의:

```markdown
# Code Review Scenarios

## Additional Rules for This Project

### Project-specific patterns to enforce
- All API routes must use Zod validation
- No direct Prisma calls in route handlers (use service layer)
- Always use `@/lib/sanitize` for user-provided HTML

### Known anti-patterns to flag
- `useEffect` with empty deps for data fetching (use SWR/React Query)
- Inline styles (use Tailwind classes)
- `console.log` in committed code

### Files/areas requiring extra scrutiny
- `server/` — any SQL changes
- `lib/auth/` — session handling
```

작성 후 "리뷰 시작할까요?" 로 돌아간다.

## 출력

- **리포트**: `{프로젝트}/.claude/review-reports/{hash}-review.md`
- **히스토리**: `{프로젝트}/.claude/review-reports/HISTORY.md` (P1/P2/P3 카운트 테이블)
- **macOS 알림**: 완료 시 P1/P2/P3 요약
- **VSCode**: 리포트 자동 열기
