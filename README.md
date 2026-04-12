# Test Gate

> AI agent QA isolation harness for Claude Code — Browser + Tauri desktop testing

**[한국어 문서 (Korean)](README.ko.md)**

When AI coding agents test their own work in the same session, they cut corners — marking things "done" when quality is lacking. Test Gate solves this structurally by running tests in a **completely separate session**.

- **Web apps**: `/test-web` — Playwright MCP
- **Tauri desktop apps**: `/test-tauri` — Tauri MCP
- **Both at once**: `/test-gate` — auto-detects and runs both

## How It Works

```
[Coding Agent Session]
    ↓ (you type /test-web or /test-tauri)
[Separate Claude Session — Haiku 4.5]
    ├── /test-web   → Playwright MCP → browse, click, verify
    └── /test-tauri  → Tauri MCP → window, menu, IPC, webview
    ↓
[Test Report + macOS notification + VSCode auto-open]
    ↓
[You review, then decide what to fix]
```

## Install

```bash
git clone https://github.com/lolu1032/test-gate.git
cd test-gate
./install.sh
```

This installs:
- Harness scripts → `~/.claude/test-harness/`
- Claude Code skills → `~/.claude/skills/test-web/`, `test-tauri/`, `test-gate/`

### Manual Install

```bash
# Harness
mkdir -p ~/.claude/test-harness
cp *.sh *.md *.json ~/.claude/test-harness/
chmod +x ~/.claude/test-harness/*.sh

# Skills
mkdir -p ~/.claude/skills/test-web ~/.claude/skills/test-tauri ~/.claude/skills/test-gate
cp skills/test-web/SKILL.md ~/.claude/skills/test-web/
cp skills/test-tauri/SKILL.md ~/.claude/skills/test-tauri/
cp skills/test-gate/SKILL.md ~/.claude/skills/test-gate/
```

## Usage

### `/test-web` — Web App Testing

```
/test-web
```

Tests your web app running on localhost with Playwright MCP.

- Auto-detects port from `package.json` (`--port 3001` etc.)
- Checks if dev server is running
- Offers to create project-specific test scenarios
- Runs in background, macOS notification when done

### `/test-tauri` — Tauri Desktop App Testing

```
/test-tauri
```

Tests your Tauri desktop app with Tauri MCP.

- Auto-detects Tauri projects (`src-tauri/` directory)
- Tests native features: window, menus, system tray, IPC
- Tests webview content inside the app
- Option to run web + Tauri tests together

### `/test-gate` — Both (Auto-detect)

```
/test-gate
```

Runs web tests, then Tauri tests if `src-tauri/` exists.

### Command Line (without skills)

```bash
~/.claude/test-harness/test-now.sh              # current project
~/.claude/test-harness/test-now.sh ~/my-project  # specific project
```

## Results

| Where | What |
|-------|------|
| **macOS notification** | Pass/fail summary popup |
| **VSCode** | Report `.md` opens automatically |
| **File** | `{project}/.claude/test-reports/{hash}-report.md` |
| **History** | `{project}/.claude/test-reports/HISTORY.md` |

### History Table

Every test run adds a row to `HISTORY.md`:

```
| Date | Commit | Message | Result | Pass | Fail | Report |
|------|--------|---------|--------|------|------|--------|
| 2026-04-12 23:10 | a1b2c3d4 | fix: login form | PASS | 11 | 0 | link |
| 2026-04-12 22:30 | e5f6g7h8 | feat: dashboard | FAIL | 8 | 3 | link |
```

The test agent reads this history and:
- Marks `[REGRESSION]` when a PASS becomes FAIL
- Focuses on previously failed areas when commit message has `fix:`
- Treats FAIL→PASS areas as regression-sensitive

## Project-Specific Test Scenarios

### Web (`/test-web`)

Create `.claude/test-scenarios.md` in your project root:

```markdown
# Test Scenarios

## Login
- URL: http://localhost:3000
- Credentials: admin@admin.com / 1234

## Required Tests
1. Login and verify dashboard loads
2. Navigate to /posts and check list renders
3. Submit form on /posts/new
4. Check responsive layout at 768px and 375px
```

### Tauri (`/test-tauri`)

Create `.claude/tauri-test-scenarios.md`:

```markdown
# Tauri Test Scenarios

## App Launch
1. Window opens with correct title
2. Window dimensions match config

## Native Features
1. System tray icon displays
2. Menu bar items work
3. File open dialog functions

## Webview
1. Main page renders inside webview
2. IPC calls from frontend reach Rust backend
```

## Auto Mode (Optional)

Add to `~/.claude/settings.json` to trigger tests on every commit:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/test-harness/check-and-run.sh"
          }
        ]
      }
    ]
  }
}
```

Skip with `[skip-test]` in commit message.

## File Structure

```
~/.claude/test-harness/          # Harness (installed globally)
├── test-now.sh                  # Manual trigger (CLI)
├── check-and-run.sh             # Auto mode hook
├── run-all-tests.sh             # Test runner
├── merge-reports.sh             # Report aggregation + history
├── browser-test-prompt.md       # Default web test prompt
├── browser-mcp.json             # Playwright MCP config
├── tauri-test-prompt.md         # Default Tauri test prompt
├── tauri-mcp.json               # Tauri MCP config
└── install.sh                   # Installer

~/.claude/skills/                # Skills (slash commands)
├── test-web/SKILL.md            # /test-web
├── test-tauri/SKILL.md          # /test-tauri
└── test-gate/SKILL.md           # /test-gate (both)

{project}/.claude/               # Per-project (auto-generated)
├── test-scenarios.md            # (optional) Web test scenarios
├── tauri-test-scenarios.md      # (optional) Tauri test scenarios
└── test-reports/
    ├── HISTORY.md               # Test history table
    ├── {hash}-browser.md        # Web test results
    ├── {hash}-tauri.md          # Tauri test results
    └── {hash}-report.md         # Combined report
```

## Requirements

- [Claude Code](https://claude.ai/claude-code) with Max subscription or API key
- [Playwright MCP](https://www.npmjs.com/package/@playwright/mcp) plugin for `/test-web`
- Tauri MCP for `/test-tauri` (ecosystem is early-stage)

## Cost

- **Max subscription**: Included (uses Haiku 4.5)
- **API billing**: ~$0.01-0.05 per test run

## Why This Exists

AI coding agents in the same session have confirmation bias toward their own work. They declare "looks good" prematurely.

Test Gate fixes this with **session isolation**:

1. **Separate process** — zero shared context with coding agent
2. **Read-only** — `--allowedTools` restricts to MCP + Read only
3. **Human gate** — reports go to you, not the coding agent
4. **History** — regression patterns tracked across commits

Implements the [Dual Quality Gates](https://www.sagarmandal.com/2026/03/15/agentic-engineering-part-7-dual-quality-gates-why-validation-and-testing-must-be-separate-processes/) pattern.

## Roadmap

- [x] `/test-web` — Playwright MCP browser testing
- [x] `/test-tauri` — Tauri MCP desktop testing
- [x] `/test-gate` — combined auto-detect
- [x] History-aware regression detection
- [x] macOS notifications + VSCode auto-open
- [ ] Adversarial test agent (learns mistake patterns)
- [ ] Debounce for rapid commits

## License

MIT
