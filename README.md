# Gotcha

> AI agent QA isolation harness for Claude Code — Web + Desktop + Code Review + Multi-agent Jury

**[한국어 문서 (Korean)](README.ko.md)**

When AI coding agents test their own work in the same session, they cut corners — marking things "done" when quality is lacking. Gotcha solves this structurally by running tests in a **completely separate session**.

- **Web apps**: `/test-web` — Playwright MCP
- **Desktop apps**: `/test-desktop` — Tauri MCP (currently)
- **Code review**: `/test-review` — git diff analysis
- **Multi-agent consensus**: `/test-jury` — Claude + Codex parallel + cross-check + synthesis
- **Router**: `/gotcha` — detects surfaces and delegates

## How It Works

```
[Coding Agent Session]
    ↓ (you run /gotcha or surface-specific skill)
[/gotcha router]
    ├── detects surfaces in project
    └── delegates to adapter:
[Separate Claude Session — Haiku 4.5]
    ├── /test-web      → Playwright MCP → browse, click, verify
    ├── /test-desktop  → Tauri MCP → window, IPC, webview
    └── /test-review   → Read + Grep → git diff analysis
    ↓
[Test Report + macOS notification + VSCode auto-open]
    ↓
[You review, then decide what to fix]
```

## Architecture

Gotcha uses **surface-based** naming, not framework-based:

| Skill | Surface | Implementation |
|-------|---------|----------------|
| `/test-web` | Web app (browser) | Playwright MCP |
| `/test-desktop` | Desktop app | Tauri MCP |
| `/test-review` | Code diff | Read + Grep + git |
| `/test-jury` | Critical reviews (consensus) | Claude Opus + Codex GPT, 2 rounds |
| `/gotcha` | Router | Detects + delegates |

This means a Go web server, a Java Spring app, a Next.js app, and a Tauri app can all be tested through the same skills — only the runner adapter differs.

## Install

```bash
git clone https://github.com/lolu1032/gotcha.git
cd gotcha
./install.sh
```

This installs:
- Harness scripts → `~/.claude/test-harness/`

### Manual Install

```bash
mkdir -p ~/.claude/test-harness
cp *.sh *.md *.json ~/.claude/test-harness/
chmod +x ~/.claude/test-harness/*.sh

cp skills/*/SKILL.md ~/.claude/skills/  # adjust per-folder
```

## Usage

### `/gotcha` — Router (recommended)

```
/gotcha
```

Detects which surfaces apply to your project, lets you select multiple, delegates to each adapter.

### `/test-web` — Web App Testing

Tests your web app on localhost (or any URL) with Playwright MCP.

- Auto-detects port from `package.json`
- Checks if dev server is running
- Asks you about scenarios — never auto-generates without confirmation
- Runs in background, macOS notification on done

### `/test-desktop` — Desktop App Testing

Tests Tauri desktop apps with Tauri MCP.

- Auto-detects Tauri projects (`src-tauri/` directory)
- Tests native features: window, menus, system tray, IPC
- Tests webview content inside the app


Redirects to `/test-desktop`. Kept for backward compatibility.

### `/test-review` — Code Review

Reviews your git diff in a separate session.

- Auto-detects base ref (`origin/main..HEAD` on feature branch, `HEAD~1` on main)
- 6 categories: correctness, security, performance, test coverage, code quality, consistency
- P1/P2/P3 severity with confidence scores
- Reports save to `.claude/review-reports/` (separate from test reports)

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
| **Test reports** | `{project}/.claude/test-reports/{hash}-report.md` |
| **Review reports** | `{project}/.claude/review-reports/{hash}-review.md` |
| **Test history** | `{project}/.claude/test-reports/HISTORY.md` |
| **Review history** | `{project}/.claude/review-reports/HISTORY.md` |

## Project-Specific Test Scenarios

**Surface-based folder structure (recommended):**

```
.claude/test-scenarios/
├── web/              # /test-web scenarios
│   ├── _always.md    # always-run base scenarios
│   ├── auth.md       # feature-specific
│   └── posts.md
└── desktop/          # /test-desktop scenarios
    ├── _always.md
    └── window.md
```

Files load in order: `_always.md` first, then alphabetical.

**Example `web/_always.md`:**

```markdown
# Always-run Web Scenarios

## Login
- URL: http://localhost:3000
- Credentials: admin@admin.com / 1234

## Required
1. Login and verify dashboard loads
2. Check sidebar navigation works on all pages
```

**Backward compatibility:** old paths still work (auto-fallback):
- `.claude/test-scenarios/` (flat folder, treated as web)
- `.claude/test-scenarios.md` (single file, web)
- `.claude/tauri-test-scenarios/` (folder, desktop)
- `.claude/tauri-test-scenarios.md` (single file, desktop)

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

## History-Aware Testing

Gotcha reads `HISTORY.md` from previous runs:

- **Regression detection** — previously passing test now fails → `[REGRESSION]`
- **Fix verification** — commit message has `fix:` → focus on previously failed areas
- **Pattern awareness** — FAIL→PASS areas treated as regression-sensitive

## File Structure

```
~/.claude/test-harness/          # Harness (installed globally)
├── test-now.sh                  # Manual trigger
├── check-and-run.sh             # Auto mode hook
├── run-all-tests.sh             # Test runner
├── run-review.sh                # Code review runner
├── merge-reports.sh             # Report aggregation
├── browser-test-prompt.md       # Default web prompt
├── browser-mcp.json             # Playwright MCP config
├── tauri-test-prompt.md         # Default desktop prompt
├── tauri-mcp.json               # Tauri MCP config
└── code-review-prompt.md        # Default review prompt

~/.claude/skills/                # Skills (slash commands)
├── test-gate/SKILL.md           # /gotcha (router)
├── test-web/SKILL.md            # /test-web
├── test-desktop/SKILL.md        # /test-desktop
└── test-review/SKILL.md         # /test-review

{project}/.claude/               # Per-project (auto-generated)
├── test-scenarios/
│   ├── web/                     # /test-web scenarios
│   └── desktop/                 # /test-desktop scenarios
├── test-reports/                # /test-web, /test-desktop output
│   ├── HISTORY.md
│   ├── {hash}-report.md
│   └── artifacts/{hash}/        # screenshots
└── review-reports/              # /test-review output
    ├── HISTORY.md
    └── {hash}-review.md
```

## Requirements

- [Claude Code](https://claude.ai/claude-code) with Max subscription or API key
- [Playwright MCP](https://www.npmjs.com/package/@playwright/mcp) for `/test-web`
- Tauri MCP for `/test-desktop` (ecosystem is early-stage)

## Cost

- **Max subscription**: Included (uses Haiku 4.5)
- **API billing**: ~$0.01-0.05 per test run

## Why This Exists

AI coding agents in the same session have confirmation bias toward their own work. They declare "looks good" prematurely.

Gotcha fixes this with **session isolation**:

1. **Separate process** — zero shared context with the coding agent
2. **Read-only** — `--allowedTools` restricts to MCP + Read only
3. **Human gate** — reports go to you, not the coding agent
4. **History** — regression patterns tracked across commits

Implements the [Dual Quality Gates](https://www.sagarmandal.com/2026/03/15/agentic-engineering-part-7-dual-quality-gates-why-validation-and-testing-must-be-separate-processes/) pattern.

## Roadmap

- [x] Phase 1: `/test-web` — Playwright MCP browser testing
- [x] Phase 2: `/test-desktop` — Tauri MCP desktop testing
- [x] Phase 3: History-aware regression detection
- [x] `/test-review` — code review on git diff
- [x] `/gotcha` as thin router (Phase A refactor)
- [x] Surface-based scenario folders (`.claude/test-scenarios/{web,desktop}/`)
- [ ] Phase B: common config file (`.claude/gotcha.toml`)
- [ ] Phase C: `/test-api`, `/test-cli` adapters
- [ ] Adversarial test agent (learns mistake patterns)

## License

MIT
