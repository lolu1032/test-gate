---
name: test-web
description: Run web app QA in a separate session with Playwright MCP
user_invocable: true
---

# Test Web

Tests the project's web app in a **completely separate Claude session** using Playwright MCP, then writes a structured report. Session isolation prevents the coding agent from rationalizing its own work.

## Detection

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT: $PROJECT_ROOT"
echo "COMMIT: $(git -C "$PROJECT_ROOT" log -1 --format='%h %s' 2>/dev/null || echo 'no commits')"

# Harness check
if [ -x "$HOME/.claude/test-harness/test-now.sh" ]; then
  echo "HARNESS: installed"
else
  echo "HARNESS: NOT INSTALLED"
fi

# Scenario detection (priority: new folder → legacy folder → legacy file)
SCENARIOS_NEW="$PROJECT_ROOT/.claude/test-scenarios/web"
SCENARIOS_OLD_DIR="$PROJECT_ROOT/.claude/test-scenarios"
SCENARIOS_FILE="$PROJECT_ROOT/.claude/test-scenarios.md"
setopt +o nomatch 2>/dev/null

if [ -d "$SCENARIOS_NEW" ]; then
  echo "SCENARIOS: folder (.claude/test-scenarios/web/)"
  for f in "$SCENARIOS_NEW"/*.md; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" | tr -d ' ')
    echo "  - $(basename "$f") ($lines lines)"
  done
elif [ -d "$SCENARIOS_OLD_DIR" ] && find "$SCENARIOS_OLD_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | grep -q .; then
  echo "SCENARIOS: legacy folder (.claude/test-scenarios/) — consider migrating to test-scenarios/web/"
  for f in "$SCENARIOS_OLD_DIR"/*.md; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" | tr -d ' ')
    echo "  - $(basename "$f") ($lines lines)"
  done
elif [ -f "$SCENARIOS_FILE" ]; then
  echo "SCENARIOS: legacy single file (.claude/test-scenarios.md, $(wc -l < "$SCENARIOS_FILE" | tr -d ' ') lines) — consider migrating"
else
  echo "SCENARIOS: none"
fi

# Port detection
PORT=$(grep -oE '\-\-port[= ]+([0-9]+)' "$PROJECT_ROOT/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1)
[ -z "$PORT" ] && PORT=$(grep -oE 'PORT[= ]+([0-9]+)' "$PROJECT_ROOT/.env" 2>/dev/null | grep -oE '[0-9]+' | head -1)
[ -z "$PORT" ] && PORT="3000"
echo "PORT: $PORT"

# Server check
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" 2>/dev/null | grep -qE "^[23]"; then
  echo "SERVER: running on :$PORT"
else
  echo "SERVER: NOT RUNNING on :$PORT"
fi

# History
if [ -f "$PROJECT_ROOT/.claude/test-reports/HISTORY.md" ]; then
  echo "HISTORY:"
  head -9 "$PROJECT_ROOT/.claude/test-reports/HISTORY.md"
fi
```

## Behavior

If harness not installed:

> Test Gate harness is not installed.
> Install: `git clone https://github.com/lolu1032/test-gate.git && cd test-gate && ./install.sh`

If server not running, AskUserQuestion:

> No server detected on localhost:{PORT}.

Options:
- A) I'll start it myself — wait for me
- B) Use a different port
- C) Cancel

### Scenario branches

**ALWAYS ask the user first. Never auto-execute.**

**If scenarios exist as folder:**

> **Web Test** — {project name} (localhost:{PORT})
> Commit: {hash} {message}
> Scenarios: .claude/test-scenarios/web/ ({N} files)
>
> Files: _always.md, auth.md, posts.md, ...

Options:
- A) Run as-is — combines all scenario files
- B) Add scenario file — user writes content
- C) Manage scenarios — edit/delete/rename
- D) Cancel

**If scenarios exist as single file:**

> **Web Test** — {project name} (localhost:{PORT})
> Commit: {hash} {message}
> Scenario file: .claude/test-scenarios.md ({N} lines)
>
> --- Preview ---
> {file content, full or first 30 lines}

Options:
- A) Run as-is
- B) Add scenarios — user writes content
- C) Edit scenarios — user rewrites
- D) Migrate to folder structure
- E) Delete and start fresh — backup then no scenarios
- F) Cancel

**If no scenarios exist** — must always ask user. No auto-default execution:

> **Web Test** — {project name} (localhost:{PORT})
> Commit: {hash} {message}
> Scenarios: none
>
> Without scenarios, the agent will browse pages randomly.
> Writing scenarios is recommended for test quality.

Options:
- A) Write scenarios — single file (.claude/test-scenarios.md)
- B) Create scenario folder — feature-based (.claude/test-scenarios/)
- C) Run with default prompt — no scenarios (not recommended)
- D) Cancel

## Execution Logic

### A) Run as-is

**No auto-generation.** Run with current state:

```bash
~/.claude/test-harness/test-now.sh "$PROJECT_ROOT"
```

After execution:

> Test running in background.
> macOS notification when done.
> Report: {PROJECT_ROOT}/.claude/test-reports/{hash}-report.md

### B/C) Write or add scenarios

**Always ask the user. Never auto-fill.**

Ask via AskUserQuestion or free input:

1. **Which URL/page to test?** (e.g., localhost:3001, /admin, /dashboard)
2. **Login required? Credentials?** (e.g., admin@admin.com / 1234)
3. **What specifically to verify?** (user describes)
4. **Edge/error cases to check?** (user describes)

Use the answers to fill this template:

```markdown
# {Feature Name} Tests

## URL & Auth
- URL: {user-provided}
- Account: {user-provided or "none"}

## Scenarios
{user-provided list}

## Edge/Error Cases
{user-provided list}
```

**Folder mode**: ask filename first (e.g., `auth.md`, `posts.md`), then ask above questions → create `.claude/test-scenarios/{name}.md`.

**Single file mode**: append new section to existing file.

After writing, return to "Start test?" prompt.

## Recommended scenario folder structure

```
.claude/test-scenarios/
├── _always.md        # always run (login, basic navigation)
├── auth.md           # auth-related changes
├── posts.md          # posts CRUD
├── dashboard.md      # dashboard
└── performance.md    # performance measurement
```

On execution, all `.md` files are concatenated: `_always.md` first, then alphabetical.
