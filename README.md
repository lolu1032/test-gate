# Test Gate

> AI agent QA isolation harness for Claude Code

**[한국어 문서 (Korean)](README.ko.md)**

When AI coding agents test their own work in the same session, they cut corners — marking things "done" when quality is lacking. Test Gate solves this structurally by running tests in a **completely separate session** using Playwright MCP.

The coding agent can't skip tests. The test agent can't modify code. A human reviews the report before any fixes happen.

## How It Works

```
[Coding Agent Session]
    ↓ (you run test-now.sh)
[Separate Claude Session — Haiku 4.5]
    ↓ (Playwright MCP)
[Browse your app, click around, verify]
    ↓
[Test Report + macOS notification]
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

Or manually:

```bash
mkdir -p ~/.claude/test-harness
cp *.sh *.md *.json ~/.claude/test-harness/
chmod +x ~/.claude/test-harness/*.sh
```

### 2. Run

```bash
# In your project directory (must have a running dev server)
~/.claude/test-harness/test-now.sh
```

That's it. You'll get a macOS notification when done.

### 3. Check Results

| Where | What |
|-------|------|
| **macOS notification** | Pass/fail summary popup |
| **VSCode** | Report opens automatically |
| **File** | `{project}/.claude/test-reports/{hash}-report.md` |
| **History** | `{project}/.claude/test-reports/HISTORY.md` |

## Project-Specific Tests

Create `.claude/test-scenarios.md` in your project root to override the default test prompt:

```markdown
# Test Scenarios

## Required Tests
1. Verify main page loads at localhost:3000
2. Login form submits correctly at /login
3. Dashboard data loads at /dashboard

## Focus Areas
- Sidebar navigation works on all pages
- Error messages display on API failure
```

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

## History-Aware Testing

Test Gate reads `HISTORY.md` from previous runs. The test agent uses this to:

- **Regression detection** — if a previously passing test now fails, it's marked `[REGRESSION]`
- **Fix verification** — when commit message contains `fix:`, the agent focuses on previously failed areas
- **Pattern awareness** — areas that went FAIL→PASS are treated as regression-sensitive

## File Structure

```
~/.claude/test-harness/
├── test-now.sh            # Manual trigger
├── check-and-run.sh       # Auto mode hook script
├── run-all-tests.sh       # Test runner (claude --print + Playwright MCP)
├── merge-reports.sh       # Report aggregation + history update
├── browser-test-prompt.md # Default test prompt
├── browser-mcp.json       # Playwright MCP config
└── install.sh             # Installer

{project}/
└── .claude/
    ├── test-scenarios.md      # (optional) Project-specific test scenarios
    └── test-reports/
        ├── HISTORY.md         # Test history table
        ├── {hash}-browser.md  # Playwright test results
        └── {hash}-report.md   # Combined report
```

## Requirements

- [Claude Code](https://claude.ai/claude-code) with Max subscription (or API key)
- [Playwright MCP](https://github.com/anthropics/mcp-server-playwright) plugin installed
- A web app running on localhost

## Cost

- **Max subscription**: Included in your plan (uses Haiku 4.5 for cost efficiency)
- **API billing**: ~$0.01-0.05 per test run with Haiku 4.5

## How It Prevents "Good Enough" Testing

The core problem: when an AI agent writes code and tests it in the same session, it has confirmation bias toward its own work. It tends to declare "looks good" prematurely.

Test Gate fixes this with **session isolation**:

1. **Separate process** — test agent has zero shared context with the coding agent
2. **Read-only** — `--allowedTools` restricts the test agent to MCP + Read only. No Edit, no Write
3. **Human gate** — reports go to you, not back to the coding agent
4. **History** — regression patterns are tracked across commits

This is an implementation of the [Dual Quality Gates](https://www.sagarmandal.com/2026/03/15/agentic-engineering-part-7-dual-quality-gates-why-validation-and-testing-must-be-separate-processes/) pattern.

## Roadmap

- [ ] **Phase 2**: Tauri MCP support (desktop app testing)
- [ ] **Phase 2**: Debounce (batch rapid commits)
- [ ] **Phase 3**: Adversarial test agent (learns repeated mistake patterns)
- [ ] **Phase 3**: Self-tests for the harness itself

## License

MIT
