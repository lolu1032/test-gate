---
name: test-jury
description: Multi-agent consensus QA — Claude Opus + Codex GPT both review in parallel, cross-check, re-run with peer awareness, then synthesize a verdict
user_invocable: true
---

# Test Jury

> Two judges. Independent verdicts. Cross-examination. Final ruling.

When you really need to be sure — **two AI models** review the same target in parallel, then see each other's reports and re-evaluate. The orchestrator (Claude Opus, in this session) synthesizes a final verdict.

## Why use this instead of `/test-web` or `/test-review`?

- Each model has different blind spots. Claude misses things Codex catches, and vice versa.
- After they see each other's reports, they push back or confirm — exposing flaky judgments.
- The final report shows confirmed vs one-sided vs disputed findings.
- **4 sessions per run** (2 agents × 2 rounds), so it's expensive. Use only when the cost of being wrong is high.

## Cost reality

- Round 1: Claude Opus + Codex GPT in parallel
- Round 2: Both re-run with peer reports as context (longer prompts)
- Synthesis: Orchestrator (Claude Opus) reads all 4 reports
- **Total: ~5 model calls** (4 × QA + 1 × synthesis)
- Time: typically 3–6 minutes
- Use sparingly — for code reviews on critical PRs, not every commit.

## Detection

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT: $PROJECT_ROOT"

if [ -z "$PROJECT_ROOT" ] || ! git -C "$PROJECT_ROOT" rev-parse HEAD >/dev/null 2>&1; then
    echo "ERROR: not a git repo"
    exit 1
fi

HASH=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null)
echo "COMMIT: ${HASH:0:8} $(git -C "$PROJECT_ROOT" log -1 --format='%s')"

# Harness check
if [ -x "$HOME/.claude/test-harness/run-jury.sh" ]; then
    echo "HARNESS: installed"
else
    echo "HARNESS: NOT INSTALLED"
fi

# Codex check (required)
if command -v codex >/dev/null 2>&1; then
    echo "CODEX: $(codex --version 2>&1 | head -1)"
else
    echo "CODEX: NOT INSTALLED — required. https://github.com/openai/codex"
fi

# History
if [ -f "$PROJECT_ROOT/.claude/jury-reports/HISTORY.md" ]; then
    echo "HISTORY:"
    head -9 "$PROJECT_ROOT/.claude/jury-reports/HISTORY.md"
fi
```

## Behavior

If Codex not installed:

> Codex CLI is required for /test-jury (one of the two jurors).
> Install: https://github.com/openai/codex

Otherwise, AskUserQuestion:

> **Test Jury** — {project name}
> Commit: {hash} {message}
>
> This will run 4 model sessions (Claude Opus + Codex, two rounds each), then synthesize.
> Cost: ~4× a normal /test-review. Time: 3–6 min.
>
> Which mode?

Options:
- A) Code review (safest — both agents read git diff, no external state)
- B) Web QA (experimental — Codex's Playwright MCP support is limited; expect skewed perspectives)
- C) Cancel

### A) Code review

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
HASH=$(git rev-parse HEAD)
nohup ~/.claude/test-harness/run-jury.sh "$HASH" "$PROJECT_ROOT" review \
    > /dev/null 2>&1 &
echo "PID: $!"
```

### B) Web QA

Same as A but mode = `web`. Note that Codex may report code-level findings rather than browser-level since its Playwright MCP integration varies by version.

```bash
nohup ~/.claude/test-harness/run-jury.sh "$HASH" "$PROJECT_ROOT" web \
    > /dev/null 2>&1 &
```

After spawning:

> Jury is deliberating in the background.
> macOS notification when verdict is ready.
> Final report: {PROJECT_ROOT}/.claude/jury-reports/{hash}-jury.md
> Working files: {PROJECT_ROOT}/.claude/jury-reports/.work-{hash}/

## Output Structure

```
{project}/.claude/jury-reports/
├── HISTORY.md              # all jury runs (date, commit, mode, confidence, action)
├── {hash}-jury.md          # final synthesized verdict
└── .work-{hash}/
    ├── round1_claude.md    # Claude's first independent pass
    ├── round1_codex.md     # Codex's first independent pass
    ├── round2_claude.md    # Claude after seeing Codex round 1
    ├── round2_codex.md     # Codex after seeing Claude round 1
    └── artifacts/          # screenshots, etc.
```

## When to use which

| Need | Use |
|------|-----|
| Quick smoke test | `/test-web` |
| Quick code review | `/test-review` |
| Critical PR before merge | `/test-jury review` |
| Releasing to production | `/test-jury web` |
| Suspect AI is rationalizing | `/test-jury` (any mode) |

## Final Verdict Sections

The orchestrator's report includes:

- **Verdict**: total findings, agreement count, disagreements, confidence
- **Confirmed Findings**: both agents agreed → high confidence
- **One-Sided Findings**: only one agent caught → orchestrator evaluates which is more likely correct
- **Disagreements**: explicit conflicts → orchestrator picks a side with reasoning
- **Action Required**: YES/NO with one-line justification
- **Round Evolution**: did the agents converge after seeing peer reports?

Plus all 4 raw reports embedded for transparency.
