---
name: test-gate
description: 테스트 라우터 — 프로젝트의 테스트 표면(web/desktop/review)을 감지하고 적절한 어댑터로 위임
user_invocable: true
---

# Test Gate (Router)

이 스킬은 **라우터**다. 직접 테스트를 실행하지 않는다. 프로젝트에서 테스트 가능한 표면(surface)을 감지하고, 사용자에게 어떤 표면을 테스트할지 묻고, 해당 어댑터 스킬에 위임한다.

## 어댑터 (실제 실행자)

| 어댑터 | 표면 | 구현 |
|--------|------|------|
| `/test-web` | 브라우저로 접근 가능한 웹앱 | Playwright MCP |
| `/test-desktop` | 데스크톱 앱 | Tauri MCP (현재 유일) |
| `/test-review` | git diff 코드 리뷰 | Read + Grep |

## 실행

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT: $PROJECT_ROOT"

if [ -z "$PROJECT_ROOT" ] || ! git -C "$PROJECT_ROOT" rev-parse HEAD >/dev/null 2>&1; then
    echo "ERROR: not a git repo"
    exit 1
fi

HASH=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null)
echo "COMMIT: ${HASH:0:8} $(git -C "$PROJECT_ROOT" log -1 --format='%s')"

# 표면 감지
echo ""
echo "=== Detected Surfaces ==="

# Web: package.json + dev script가 있으면 web
HAS_WEB="no"
if [ -f "$PROJECT_ROOT/package.json" ] && grep -qE '"dev"|"start"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    HAS_WEB="yes"
    PORT=$(grep -oE '\-\-port[= ]+([0-9]+)' "$PROJECT_ROOT/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ -z "$PORT" ] && PORT="3000"
    echo "[web]      package.json detected, hint port: $PORT"
fi

# Desktop: src-tauri/ 가 있으면 desktop
HAS_DESKTOP="no"
if [ -f "$PROJECT_ROOT/src-tauri/tauri.conf.json" ] || [ -f "$PROJECT_ROOT/src-tauri/Cargo.toml" ]; then
    HAS_DESKTOP="yes"
    echo "[desktop]  src-tauri/ detected (Tauri)"
fi

# Review: git diff 변경사항 있으면 review 가능
DIFF_LINES=$(git -C "$PROJECT_ROOT" diff HEAD~1 HEAD --shortstat 2>/dev/null)
if [ -n "$DIFF_LINES" ]; then
    echo "[review]   diff available: $DIFF_LINES"
fi

if [ "$HAS_WEB" = "no" ] && [ "$HAS_DESKTOP" = "no" ]; then
    echo "(no testable surfaces detected — but you can still run /test-review for code review)"
fi
```

## 동작

감지 결과를 보여준 후 AskUserQuestion:

> **Test Gate** — {프로젝트명}
> 커밋: {hash} {message}
>
> 감지된 표면:
> - [web]      {여부}
> - [desktop]  {여부}
> - [review]   {여부}
>
> 어떤 테스트를 실행할까요? **여러 개 선택 가능 (multiSelect).**

multiSelect: true

Options (감지된 것만 표시):
- A) `/test-web` — 웹앱 QA (Playwright MCP)
- B) `/test-desktop` — 데스크톱 앱 QA (Tauri MCP)
- C) `/test-review` — 코드 리뷰 (git diff)
- D) 취소

## 위임 로직

선택된 각 옵션에 대해, 해당 스킬 파일을 읽고 그 지시를 따른다:

- A 선택 시: `~/.claude/skills/test-web/SKILL.md` 읽고 실행
- B 선택 시: `~/.claude/skills/test-desktop/SKILL.md` 읽고 실행
- C 선택 시: `~/.claude/skills/test-review/SKILL.md` 읽고 실행

여러 개 선택 시 순차 실행 (web → desktop → review 순).

각 어댑터 스킬은 자체적으로 시나리오 관리, 사용자 확인을 처리한다. test-gate는 라우팅만 한다.

## 라우터의 책임

- 표면 감지 (감지 로직만, 실행 안 함)
- 사용자에게 어떤 표면 실행할지 묻기
- 적절한 어댑터로 위임

## 라우터의 비책임

- 테스트 실행 ❌
- 시나리오 관리 ❌
- 리포트 생성 ❌
- 결과 집계 (각 어댑터의 리포트는 따로 생성됨)

## 디자인 원칙

이 스킬은 thin router다. 실행 로직을 추가하지 마라. 새 표면이 생기면 새 어댑터 스킬을 만들고, 여기서는 감지 + 위임만 추가한다.
