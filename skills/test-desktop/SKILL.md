---
name: test-desktop
description: Run desktop app QA in a separate session (currently supports Tauri MCP)
user_invocable: true
---

# Test Desktop

Tests desktop apps in a **completely separate Claude session**. Currently supports Tauri MCP. Session isolation prevents the coding agent from rationalizing its own work.

## Detection

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT: $PROJECT_ROOT"
echo "COMMIT: $(git -C "$PROJECT_ROOT" log -1 --format='%h %s' 2>/dev/null || echo 'no commits')"

if [ -x "$HOME/.claude/test-harness/test-now.sh" ]; then
    echo "HARNESS: installed"
else
    echo "HARNESS: NOT INSTALLED"
fi

# Tauri project check
if [ -f "$PROJECT_ROOT/src-tauri/tauri.conf.json" ] || [ -f "$PROJECT_ROOT/src-tauri/Cargo.toml" ]; then
    echo "TAURI: detected"
    TAURI_APP=$(grep -oE '"productName":\s*"[^"]+"' "$PROJECT_ROOT/src-tauri/tauri.conf.json" 2>/dev/null | grep -oE '"[^"]+"\s*$' | tr -d '"' || echo "unknown")
    echo "APP_NAME: $TAURI_APP"
else
    echo "TAURI: NOT DETECTED"
fi

# Scenario detection (priority: new folder → legacy folder → legacy file)
SCENARIOS_NEW="$PROJECT_ROOT/.claude/test-scenarios/desktop"
SCENARIOS_OLD_DIR="$PROJECT_ROOT/.claude/tauri-test-scenarios"
SCENARIOS_OLD_FILE="$PROJECT_ROOT/.claude/tauri-test-scenarios.md"
setopt +o nomatch 2>/dev/null

if [ -d "$SCENARIOS_NEW" ]; then
    echo "SCENARIOS: folder (.claude/test-scenarios/desktop/)"
    for f in "$SCENARIOS_NEW"/*.md; do
        [ -f "$f" ] || continue
        lines=$(wc -l < "$f" | tr -d ' ')
        echo "  - $(basename "$f") ($lines lines)"
    done
elif [ -d "$SCENARIOS_OLD_DIR" ]; then
    echo "SCENARIOS: legacy folder (.claude/tauri-test-scenarios/) — consider migrating to test-scenarios/desktop/"
    for f in "$SCENARIOS_OLD_DIR"/*.md; do
        [ -f "$f" ] || continue
        lines=$(wc -l < "$f" | tr -d ' ')
        echo "  - $(basename "$f") ($lines lines)"
    done
elif [ -f "$SCENARIOS_OLD_FILE" ]; then
    echo "SCENARIOS: legacy single file (.claude/tauri-test-scenarios.md, $(wc -l < "$SCENARIOS_OLD_FILE" | tr -d ' ') lines)"
else
    echo "SCENARIOS: none (default prompt)"
fi

if [ -f "$PROJECT_ROOT/.claude/test-reports/HISTORY.md" ]; then
    echo "HISTORY:"
    head -9 "$PROJECT_ROOT/.claude/test-reports/HISTORY.md"
fi
```

## Behavior

If harness not installed:

> Test Gate harness is not installed.
> Install: `git clone https://github.com/lolu1032/test-gate.git && cd test-gate && ./install.sh`

If not a Tauri project:

> No `src-tauri/` directory found.
> If this is not a Tauri project, run `/test-web` for web testing instead.

### Scenario branches

**ALWAYS ask the user first. Never auto-execute.**

**If scenarios exist as folder:**

> **Desktop Test** — {app name}
> Commit: {hash} {message}
> Scenarios folder: .claude/test-scenarios/desktop/ ({N} files)
>
> Files: _always.md, window.md, ipc.md, ...

Options:
- A) Run as-is
- B) Add scenario file — user writes content
- C) Manage scenarios — edit/delete
- D) Run web tests too (/test-web + /test-desktop)
- E) Cancel

**If scenarios exist as single file:**

> **Desktop Test** — {app name}
> Commit: {hash} {message}
> Scenario file: .claude/tauri-test-scenarios.md ({N} lines)
>
> --- Preview ---
> {file content, full or first 30 lines}

Options:
- A) Run as-is
- B) Add scenarios — user writes
- C) Edit scenarios — user rewrites
- D) Migrate to folder structure
- E) Run web tests too
- F) Cancel

**If no scenarios** — must always ask user. No auto-default execution:

> **Desktop Test** — {app name}
> Commit: {hash} {message}
> Scenarios: none
>
> Without scenarios, the agent will navigate the app randomly.
> Writing scenarios is recommended for test quality.

Options:
- A) Write scenarios — single file (.claude/tauri-test-scenarios.md)
- B) Create scenario folder — feature-based (.claude/tauri-test-scenarios/)
- C) Run with default prompt — no scenarios (not recommended)
- D) Run web tests too
- E) Cancel

## Execution

### A) Run as-is (desktop only)

```bash
nohup ~/.claude/test-harness/run-all-tests.sh "$HASH" "$PROJECT_ROOT" \
    > /dev/null 2>&1 &
```

### B) Write or add scenarios

Always ask user. Never auto-fill.

Ask the user:
1. **App launch behavior to verify?**
2. **Native features to test?** (window/menu/tray/IPC)
3. **Webview content to verify?**
4. **Edge cases?**

Use the answers to fill this template:

```markdown
# {Feature Name} Tests

## Native Features
- {window/menu/tray/IPC} verification

## Webview
- {page/feature} check
```

### Single file → folder migration

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
mkdir -p "$PROJECT_ROOT/.claude/tauri-test-scenarios"
mv "$PROJECT_ROOT/.claude/tauri-test-scenarios.md" "$PROJECT_ROOT/.claude/tauri-test-scenarios/_always.md"
echo "Migrated to folder structure."
```

### Web + Desktop together

The default `run-all-tests.sh` auto-detects `src-tauri/` and runs both browser + Tauri.

## Recommended scenario folder structure

```
.claude/test-scenarios/desktop/
├── _always.md        # always run (app launch, basic window)
├── window.md         # window management (resize, minimize)
├── ipc.md            # Rust ↔ Frontend IPC
├── menu.md           # native menu
└── tray.md           # system tray
```

On execution, all `.md` files are concatenated: `_always.md` first, then alphabetical.
