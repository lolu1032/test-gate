---
name: gotcha
description: Gotcha — test router that catches what your AI agent missed. Detects testable surfaces (web/desktop/review) and delegates to the appropriate adapter
user_invocable: true
---

# Gotcha (Router)

> Caught you, AI. This is the router skill of **Gotcha** — an AI agent QA isolation harness for Claude Code.

This skill is a **router**. It does not run tests directly. It detects which surfaces (web/desktop/review) are testable in the current project, asks the user which surface(s) to test, and delegates to the corresponding adapter skill.

## Adapters (actual runners)

| Adapter | Surface | Implementation |
|---------|---------|----------------|
| `/test-web` | Web app reachable via browser | Playwright MCP |
| `/test-desktop` | Desktop app | Tauri MCP (currently the only option) |
| `/test-review` | Code diff review | Read + Grep |

## Execution

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT: $PROJECT_ROOT"

if [ -z "$PROJECT_ROOT" ] || ! git -C "$PROJECT_ROOT" rev-parse HEAD >/dev/null 2>&1; then
    echo "ERROR: not a git repo"
    exit 1
fi

HASH=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null)
echo "COMMIT: ${HASH:0:8} $(git -C "$PROJECT_ROOT" log -1 --format='%s')"

# Surface detection
echo ""
echo "=== Detected Surfaces ==="

# Web: package.json with dev script → web
HAS_WEB="no"
if [ -f "$PROJECT_ROOT/package.json" ] && grep -qE '"dev"|"start"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    HAS_WEB="yes"
    PORT=$(grep -oE '\-\-port[= ]+([0-9]+)' "$PROJECT_ROOT/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ -z "$PORT" ] && PORT="3000"
    echo "[web]      package.json detected, hint port: $PORT"
fi

# Desktop: src-tauri/ → desktop
HAS_DESKTOP="no"
if [ -f "$PROJECT_ROOT/src-tauri/tauri.conf.json" ] || [ -f "$PROJECT_ROOT/src-tauri/Cargo.toml" ]; then
    HAS_DESKTOP="yes"
    echo "[desktop]  src-tauri/ detected (Tauri)"
fi

# Review: any diff → review possible
DIFF_LINES=$(git -C "$PROJECT_ROOT" diff HEAD~1 HEAD --shortstat 2>/dev/null)
if [ -n "$DIFF_LINES" ]; then
    echo "[review]   diff available: $DIFF_LINES"
fi

if [ "$HAS_WEB" = "no" ] && [ "$HAS_DESKTOP" = "no" ]; then
    echo "(no testable surfaces detected — but you can still run /test-review for code review)"
fi
```

## Behavior

After detection, AskUserQuestion:

> **Gotcha** — {project name}
> Commit: {hash} {message}
>
> Detected surfaces:
> - [web]      {yes/no}
> - [desktop]  {yes/no}
> - [review]   {yes/no}
>
> Which test(s) to run? **Multiple selections allowed (multiSelect).**

multiSelect: true

Options (only show detected surfaces):
- A) `/test-web` — Web app QA (Playwright MCP)
- B) `/test-desktop` — Desktop app QA (Tauri MCP)
- C) `/test-review` — Code review (git diff)
- D) Cancel

## Delegation

For each selected option, read the corresponding skill file and follow its instructions:

- A: read `~/.claude/skills/test-web/SKILL.md` and execute
- B: read `~/.claude/skills/test-desktop/SKILL.md` and execute
- C: read `~/.claude/skills/test-review/SKILL.md` and execute

If multiple selected, run sequentially in order: web → desktop → review.

Each adapter handles its own scenario management and user confirmation. test-gate only routes.

## Router responsibilities

- Surface detection (only detection, no execution)
- Asking the user which surface(s) to run
- Delegating to the appropriate adapter

## Router non-responsibilities

- Running tests ❌
- Managing scenarios ❌
- Generating reports ❌
- Aggregating results (each adapter writes its own report) ❌

## Design principle

This skill is a thin router. Do not add execution logic here. When a new surface is added, create a new adapter skill, and only add detection + delegation here.
