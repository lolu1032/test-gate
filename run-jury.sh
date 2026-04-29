#!/bin/bash
# run-jury.sh "$HASH" "$PROJECT_ROOT" "$MODE"
# MODE: review (git diff) | web (Playwright MCP)
# Multi-agent consensus testing: Claude + Codex run in parallel, cross-check, re-run, synthesize.

HASH="$1"
PROJECT_ROOT="$2"
MODE="${3:-review}"  # default to code review (no Playwright contention)
HARNESS_DIR="$HOME/.claude/test-harness"
REPORT_DIR="$PROJECT_ROOT/.claude/jury-reports"
WORK_DIR="$REPORT_DIR/.work-$HASH"
LOCK_FILE="$HARNESS_DIR/.jury-running"

if [ -z "$HASH" ] || [ -z "$PROJECT_ROOT" ]; then
    echo "Usage: run-jury.sh HASH PROJECT_ROOT [review|web]"
    exit 1
fi

# Codex check
if ! command -v codex >/dev/null 2>&1; then
    echo "[jury] ERROR: codex CLI not found. Install: https://github.com/openai/codex"
    exit 1
fi

# Lock + dirs
echo $$ > "$LOCK_FILE"
mkdir -p "$REPORT_DIR" "$WORK_DIR"

SHORT_HASH="${HASH:0:8}"
COMMIT_MSG=$(git -C "$PROJECT_ROOT" log -1 --format="%s" 2>/dev/null || echo "unknown")

# ---- Build the scenario prompt based on MODE ----
JURY_BASE=$(cat "$HARNESS_DIR/jury-prompt.md")

if [ "$MODE" = "review" ]; then
    BASE_REF="HEAD~1"
    MAIN_BRANCH=$(git -C "$PROJECT_ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    [ -z "$MAIN_BRANCH" ] && MAIN_BRANCH="main"
    CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ] && git -C "$PROJECT_ROOT" rev-parse "origin/$MAIN_BRANCH" >/dev/null 2>&1; then
        BASE_REF="origin/$MAIN_BRANCH"
    fi
    CHANGED_FILES=$(git -C "$PROJECT_ROOT" diff --name-only "$BASE_REF" HEAD 2>/dev/null)
    DIFF_STAT=$(git -C "$PROJECT_ROOT" diff --stat "$BASE_REF" HEAD 2>/dev/null | tail -1)

    SCENARIO_PROMPT=$(cat "$HARNESS_DIR/code-review-prompt.md" 2>/dev/null || echo "Review the git diff for correctness, security, performance, test coverage, code quality, consistency.")

    TARGET_INFO="MODE: code review
Commit: $HASH ($COMMIT_MSG)
Base: $BASE_REF
Diff stats: $DIFF_STAT
Changed files:
$CHANGED_FILES

Run \`git diff $BASE_REF HEAD\` to read the diff."
else
    # web mode
    SCENARIOS_NEW="$PROJECT_ROOT/.claude/test-scenarios/web"
    SCENARIOS_OLD_DIR="$PROJECT_ROOT/.claude/test-scenarios"
    SCENARIOS_OLD_FILE="$PROJECT_ROOT/.claude/test-scenarios.md"
    if [ -d "$SCENARIOS_NEW" ]; then
        SCENARIO_PROMPT=$(cat "$SCENARIOS_NEW"/*.md 2>/dev/null)
    elif [ -d "$SCENARIOS_OLD_DIR" ] && find "$SCENARIOS_OLD_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | grep -q .; then
        SCENARIO_PROMPT=$(cat "$SCENARIOS_OLD_DIR"/*.md 2>/dev/null)
    elif [ -f "$SCENARIOS_OLD_FILE" ]; then
        SCENARIO_PROMPT=$(cat "$SCENARIOS_OLD_FILE")
    else
        SCENARIO_PROMPT=$(cat "$HARNESS_DIR/browser-test-prompt.md")
    fi

    TARGET_INFO="MODE: web QA via Playwright MCP
Commit: $HASH ($COMMIT_MSG)
Note: Codex agent may not have full Playwright MCP support — its findings may be code-level rather than browser-level."
fi

ARTIFACTS_DIR="$WORK_DIR/artifacts"
mkdir -p "$ARTIFACTS_DIR"
SCENARIO_INJECTED=$(echo "$SCENARIO_PROMPT" | sed "s|\$ARTIFACTS_DIR|$ARTIFACTS_DIR|g")

# ---- ROUND 1: parallel independent runs ----
echo "[jury] Round 1: dispatching Claude + Codex in parallel..."

PHASE1_PROMPT="$(echo "$JURY_BASE" | sed 's|{PHASE}|round 1 (independent first pass, no peer report yet)|g')

---

$TARGET_INFO

---

$SCENARIO_INJECTED"

# Claude round 1
if [ "$MODE" = "web" ]; then
    (cd "$ARTIFACTS_DIR" && claude --print \
        -p "$PHASE1_PROMPT" \
        --mcp-config "$HARNESS_DIR/browser-mcp.json" \
        --allowedTools "mcp__playwright__*,Read,Glob,Grep,Bash(git *)" \
        --model claude-opus-4-7) \
        > "$WORK_DIR/round1_claude.md" 2>"$WORK_DIR/round1_claude.log" &
else
    (cd "$PROJECT_ROOT" && claude --print \
        -p "$PHASE1_PROMPT" \
        --allowedTools "Read,Glob,Grep,Bash(git *)" \
        --model claude-opus-4-7) \
        > "$WORK_DIR/round1_claude.md" 2>"$WORK_DIR/round1_claude.log" &
fi
PID_CLAUDE=$!

# Codex round 1
TMPERR_CODEX=$(mktemp)
(cd "$PROJECT_ROOT" && codex exec "$PHASE1_PROMPT" \
    -C "$PROJECT_ROOT" \
    -s read-only \
    -c 'model_reasoning_effort="high"' \
    > "$WORK_DIR/round1_codex.md" 2>"$TMPERR_CODEX") &
PID_CODEX=$!

wait $PID_CLAUDE
wait $PID_CODEX
cat "$TMPERR_CODEX" >> "$WORK_DIR/round1_codex.log" 2>/dev/null
rm -f "$TMPERR_CODEX"

echo "[jury] Round 1 complete."

# ---- ROUND 2: peer-aware re-run ----
echo "[jury] Round 2: each agent reviews the other's report, re-runs..."

CLAUDE_R1=$(cat "$WORK_DIR/round1_claude.md")
CODEX_R1=$(cat "$WORK_DIR/round1_codex.md")

PHASE2_CLAUDE_PROMPT="$(echo "$JURY_BASE" | sed 's|{PHASE}|round 2 (informed by peer report)|g')

---

$TARGET_INFO

---

$SCENARIO_INJECTED

---

## Peer Report (Codex GPT, round 1)

$CODEX_R1"

PHASE2_CODEX_PROMPT="$(echo "$JURY_BASE" | sed 's|{PHASE}|round 2 (informed by peer report)|g')

---

$TARGET_INFO

---

$SCENARIO_INJECTED

---

## Peer Report (Claude Opus, round 1)

$CLAUDE_R1"

# Claude round 2
if [ "$MODE" = "web" ]; then
    (cd "$ARTIFACTS_DIR" && claude --print \
        -p "$PHASE2_CLAUDE_PROMPT" \
        --mcp-config "$HARNESS_DIR/browser-mcp.json" \
        --allowedTools "mcp__playwright__*,Read,Glob,Grep,Bash(git *)" \
        --model claude-opus-4-7) \
        > "$WORK_DIR/round2_claude.md" 2>"$WORK_DIR/round2_claude.log" &
else
    (cd "$PROJECT_ROOT" && claude --print \
        -p "$PHASE2_CLAUDE_PROMPT" \
        --allowedTools "Read,Glob,Grep,Bash(git *)" \
        --model claude-opus-4-7) \
        > "$WORK_DIR/round2_claude.md" 2>"$WORK_DIR/round2_claude.log" &
fi
PID_CLAUDE=$!

# Codex round 2
TMPERR_CODEX=$(mktemp)
(cd "$PROJECT_ROOT" && codex exec "$PHASE2_CODEX_PROMPT" \
    -C "$PROJECT_ROOT" \
    -s read-only \
    -c 'model_reasoning_effort="high"' \
    > "$WORK_DIR/round2_codex.md" 2>"$TMPERR_CODEX") &
PID_CODEX=$!

wait $PID_CLAUDE
wait $PID_CODEX
cat "$TMPERR_CODEX" >> "$WORK_DIR/round2_codex.log" 2>/dev/null
rm -f "$TMPERR_CODEX"

echo "[jury] Round 2 complete."

# ---- FINAL SYNTHESIS by orchestrator (Claude Opus) ----
echo "[jury] Synthesizing final verdict..."

CLAUDE_R2=$(cat "$WORK_DIR/round2_claude.md")
CODEX_R2=$(cat "$WORK_DIR/round2_codex.md")

SYNTH_PROMPT="You are the orchestrator of a 2-agent jury QA process. Two AI agents (Claude Opus 4.7 and Codex GPT) each ran two rounds of independent review on the same target. Your job is to synthesize a single final verdict.

## Target
$TARGET_INFO

## Inputs
- round1_claude.md: Claude's first independent pass
- round1_codex.md: Codex's first independent pass
- round2_claude.md: Claude after seeing Codex round 1
- round2_codex.md: Codex after seeing Claude round 1

## Your Task

Produce a single Markdown report with these sections:

### Verdict (top of report)
- Total findings consolidated: N
- Both agents agreed on: N
- Only one agent caught: N (list which)
- Disagreements (one said PASS, other said FAIL): N
- Confidence: high / medium / low

### Confirmed Findings (both agents agreed in round 2)
{numbered list, with severity if available}

### One-Sided Findings (only one agent reported)
- Claude saw, Codex missed: ...
- Codex saw, Claude missed: ...
{for each, briefly evaluate which is more likely correct}

### Disagreements
- Topic: {description}
  - Claude: {position}
  - Codex: {position}
  - Your call: {which is more likely correct, reasoning}

### Action Required
- {YES/NO with one-line justification}

### Round Evolution
- Did agents converge after seeing peer reports? Brief note.

## Source Reports

### Round 1 — Claude
$CLAUDE_R1

### Round 1 — Codex
$CODEX_R1

### Round 2 — Claude
$CLAUDE_R2

### Round 2 — Codex
$CODEX_R2

End with a Summary block:

\`\`\`
## Summary
Total: N
Pass: N
Fail: N
Confidence: high/med/low
Action Required: YES/NO
\`\`\`"

(cd "$PROJECT_ROOT" && claude --print \
    -p "$SYNTH_PROMPT" \
    --allowedTools "Read" \
    --model claude-opus-4-7) \
    > "$REPORT_DIR/$HASH-jury.md" 2>"$WORK_DIR/synth.log"

# ---- Update history ----
HISTORY_FILE="$REPORT_DIR/HISTORY.md"
if [ ! -f "$HISTORY_FILE" ]; then
    {
        echo "# Jury History"
        echo ""
        echo "| Date | Commit | Mode | Confidence | Action | Report |"
        echo "|------|--------|------|------------|--------|--------|"
    } > "$HISTORY_FILE"
fi

CONFIDENCE=$(grep -oE "Confidence: (high|med|medium|low)" "$REPORT_DIR/$HASH-jury.md" 2>/dev/null | head -1 | awk '{print $2}')
[ -z "$CONFIDENCE" ] && CONFIDENCE="?"
ACTION=$(grep -oE "Action Required: (YES|NO)" "$REPORT_DIR/$HASH-jury.md" 2>/dev/null | head -1 | awk '{print $3}')
[ -z "$ACTION" ] && ACTION="?"
DATE=$(date '+%Y-%m-%d %H:%M')

echo "| $DATE | \`$SHORT_HASH\` | $MODE | $CONFIDENCE | $ACTION | [$SHORT_HASH-jury]($HASH-jury.md) |" >> "$HISTORY_FILE"

# ---- Cleanup + notification ----
rm -f "$LOCK_FILE"

osascript -e "display notification \"Jury verdict ready ($CONFIDENCE confidence)\" with title \"Gotcha Jury [$SHORT_HASH]\" subtitle \"$(basename "$PROJECT_ROOT")\"" 2>/dev/null

if [ -n "$VSCODE_IPC_HOOK_CLI" ] || command -v code >/dev/null 2>&1; then
    code "$REPORT_DIR/$HASH-jury.md" 2>/dev/null
fi

echo ""
echo "════════════════════════════════════════"
echo " GOTCHA JURY VERDICT: $SHORT_HASH"
echo " Mode: $MODE  Confidence: $CONFIDENCE  Action: $ACTION"
echo "════════════════════════════════════════"
echo "Final report: $REPORT_DIR/$HASH-jury.md"
echo "Working files: $WORK_DIR/"
