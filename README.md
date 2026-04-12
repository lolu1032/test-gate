# Test Gate

> AI agent QA isolation harness for Claude Code — Browser + Tauri desktop testing

**[한국어 문서 (Korean)](README.ko.md)**

When AI coding agents test their own work in the same session, they cut corners — marking things "done" when quality is lacking. Test Gate solves this structurally by running tests in a **completely separate session**.

- **Web apps**: Playwright MCP (automatic)
- **Tauri desktop apps**: Tauri MCP (auto-detected via `src-tauri/`)

The coding agent can't skip tests. The test agent can't modify code. A human reviews the report before any fixes happen.

## How It Works

```
[Coding Agent Session]
    ↓ (you run /test-gate or test-now.sh)
[Separate Claude Session — Haiku 4.5]
    ├── [Playwright MCP] → browse web app, click, verify
    └── [Tauri MCP]      → test desktop app (if src-tauri/ exists)
    ↓
[Test Report + macOS notification + VSCode auto-open]
    ↓
[You review, then decide what to fix]
```

## Quick Start

### 1. Install

```bash
git clone https://github.com/lolu1032/test-gate.git
cd test-gate
./install.sh
```

### 2. Run

```bash
# Option A: Claude Code skill (recommended)
/test-gate

# Option B: Command line
~/.claude/test-harness/test-now.sh
```

### 3. Check Results

| Where | What |
|-------|------|
| **macOS notification** | Pass/fail summary popup |
| **VSCode** | Report opens automatically |
| **File** | `{project}/.claude/test-reports/{hash}-report.md` |
| **History** | `{project}/.claude/test-reports/HISTORY.md` |

## Claude Code Skill

Install `SKILL.md` to `~/.claude/skills/test-gate/SKILL.md`, then use:

```
/test-gate
```

The skill auto-detects port, checks if dev server is running, and offers to create project-specific test scenarios.

## Project-Specific Tests

Create `.claude/test-scenarios.md` in your project root:

```markdown
# Test Scenarios

## Login
- URL: http://localhost:3000
- Credentials: admin@admin.com / 1234

## Required Tests
1. Login and verify dashboard loads
2. Navigate to /posts and verify list
3. Test form submission on /posts/new
```

For Tauri projects, also create `.claude/tauri-test-scenarios.md`.

## Auto Mode (Optional)

Add to `~/.claude/settings.json` to run tests on every commit:

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

Skip specific commits with `[skip-test]` in the commit message.

## Tauri Desktop App Testing

Test Gate auto-detects Tauri projects by checking for `src-tauri/tauri.conf.json` or `src-tauri/Cargo.toml`. When detected:

- Browser tests run first (web content in webview)
- Tauri tests run next (native window, menus, IPC, system tray)
- Both results merge into a single report

## History-Aware Testing

Test Gate reads `HISTORY.md` from previous runs:

- **Regression detection** — previously passing test now fails → `[REGRESSION]`
- **Fix verification** — commit message has `fix:` → focus on previously failed areas
- **Pattern awareness** — FAIL→PASS areas are regression-sensitive

## File Structure

```
~/.claude/test-harness/
├── test-now.sh              # Manual trigger
├── check-and-run.sh         # Auto mode hook
├── run-all-tests.sh         # Test runner (Playwright + Tauri MCP)
├── merge-reports.sh         # Report aggregation + history
├── browser-test-prompt.md   # Default browser test prompt
├── browser-mcp.json         # Playwright MCP config
├── tauri-test-prompt.md     # Default Tauri test prompt
├── tauri-mcp.json           # Tauri MCP config
└── install.sh               # Installer

~/.claude/skills/test-gate/
└── SKILL.md                 # /test-gate slash command

{project}/
└── .claude/
    ├── test-scenarios.md         # (optional) Browser test scenarios
    ├── tauri-test-scenarios.md   # (optional) Tauri test scenarios
    └── test-reports/
        ├── HISTORY.md            # Test history table
        ├── {hash}-browser.md     # Browser test results
        ├── {hash}-tauri.md       # Tauri test results
        └── {hash}-report.md      # Combined report
```

## Requirements

- [Claude Code](https://claude.ai/claude-code) with Max subscription (or API key)
- [Playwright MCP](https://www.npmjs.com/package/@playwright/mcp) plugin installed
- For Tauri testing: Tauri MCP (in development)

## Cost

- **Max subscription**: Included in your plan (Haiku 4.5)
- **API billing**: ~$0.01-0.05 per test run

## Why This Exists

The core problem: when an AI agent writes code and tests it in the same session, it has confirmation bias. It tends to declare "looks good" prematurely — the "good enough" problem.

Test Gate fixes this with **session isolation**:

1. **Separate process** — zero shared context with the coding agent
2. **Read-only** — `--allowedTools` restricts to MCP + Read only
3. **Human gate** — reports go to you, not back to the coding agent
4. **History** — regression patterns tracked across commits

This implements the [Dual Quality Gates](https://www.sagarmandal.com/2026/03/15/agentic-engineering-part-7-dual-quality-gates-why-validation-and-testing-must-be-separate-processes/) pattern.

## Roadmap

- [x] Phase 1: Browser MCP (Playwright) testing
- [x] Phase 2: Tauri MCP desktop app testing
- [x] Phase 3: History-aware regression detection
- [x] `/test-gate` Claude Code skill
- [ ] Adversarial test agent (learns repeated mistake patterns)
- [ ] Debounce for rapid commits

## License

MIT
