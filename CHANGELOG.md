# Changelog

All notable changes to **Gotcha** are documented here.

## [Unreleased]

### Fixed
- **Scenario priority**: User scenarios were being de-prioritized by overly strict default rules in `browser-test-prompt.md`. Restructured prompt with clear priority order:
  1. User scenarios (primary source of truth)
  2. Safety rules (never violate)
  3. Default behavior (only when no scenarios exist)
- **Default behavior is now intentionally minimal smoke test** — pushing users toward writing real scenarios for serious testing.
- Same restructure applied to `tauri-test-prompt.md`.

### Added
- This `CHANGELOG.md` file.

---

## [0.5.0] — 2026-04-19

### Renamed
- **Project: Test Gate → Gotcha**. Catchier, more memorable name.
  - Tagline: *"Caught you, AI."*
- **Router skill: `/test-gate` → `/gotcha`**. The brand command.
- Adapter skills unchanged: `/test-web`, `/test-desktop`, `/test-review`.
- GitHub repo: `lolu1032/test-gate` → `lolu1032/gotcha`.

### Updated
- README.md / README.ko.md fully rebranded.
- Clone URLs updated everywhere.
- `install.sh` updated.

---

## [0.4.0] — 2026-04-19

### Removed
- **`/test-tauri` (deprecated alias)** — use `/test-desktop` directly.

### Added
- **English SKILL.md as primary** for all 4 skills (gotcha, test-web, test-desktop, test-review).
- Korean versions preserved as `SKILL.ko.md` companion docs.
- `install.sh` now installs both English (`SKILL.md`) and Korean (`SKILL.ko.md`).

### Why
- Targets international audience (Reddit, Hacker News).
- Korean docs preserved for original users.

---

## [0.3.0] — 2026-04-19 (Phase A refactor)

### Refactored — surface-based architecture

Core insight: name skills by **test surface** (web/desktop/review), not by **framework** (next/tauri/go).

- **`test-tauri` → `test-desktop`** (rename, kept alias).
  - Reasoning: "Tauri" is the implementation; "desktop" is the surface. Other desktop frameworks could plug in later (Electron, native, etc.).
- **`test-gate` → thin router**: only detects surfaces and delegates. No execution logic.
- **Scenario folders organized by surface**:
  - `.claude/test-scenarios/web/` (was `.claude/test-scenarios/`)
  - `.claude/test-scenarios/desktop/` (was `.claude/tauri-test-scenarios/`)
- **Backward-compatible**: legacy paths still work as fallback.

### Added
- `/test-review` skill — code review on git diff in a separate session.
  - 6 categories: correctness, security, performance, test coverage, code quality, consistency.
  - P1/P2/P3 severity with confidence scores.
  - Reports save to `.claude/review-reports/` (separate from test reports).

---

## [0.2.0] — 2026-04-12 (Phase 2+3)

### Added
- **`/test-desktop`** (originally named `/test-tauri`) — Tauri MCP desktop app QA.
- **History-aware testing**: test agent reads `HISTORY.md` to detect regressions and focus on previously failed areas.
- Single-skill `/test-gate` split into `/test-web`, `/test-tauri`, `/test-gate`.
- macOS notifications + VSCode auto-open of reports.
- Per-project test scenarios (`.claude/test-scenarios.md`).

### Fixed
- HISTORY.md count parsing bug (PASS/FAIL counts were sometimes captured as multi-line strings).

---

## [0.1.0] — 2026-04-12 (Initial release)

### Added
- **Test Gate** harness — bash + skill system that spawns separate Claude sessions for QA.
- `claude --print` + Playwright MCP integration.
- `/test-gate` skill for one-command testing.
- Test reports written to `.claude/test-reports/{commit-hash}-report.md`.
- macOS notification on completion.
- README in English + Korean.
- MIT license.

### Why this exists
AI coding agents in the same session have confirmation bias toward their own work. They declare "looks good" prematurely.

Test Gate / Gotcha solves this with **session isolation**:
1. Separate process — zero shared context with the coding agent.
2. Read-only — `--allowedTools` restricts to MCP + Read only.
3. Human gate — reports go to you, not the coding agent.
4. History — regression patterns tracked across commits.

Implements the [Dual Quality Gates](https://www.sagarmandal.com/2026/03/15/agentic-engineering-part-7-dual-quality-gates-why-validation-and-testing-must-be-separate-processes/) pattern.
