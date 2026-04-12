#!/bin/bash
# Test Gate installer

HARNESS_DIR="$HOME/.claude/test-harness"
SKILL_DIR="$HOME/.claude/skills/test-gate"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Test Gate..."
echo ""

# Harness scripts
mkdir -p "$HARNESS_DIR"
cp "$SCRIPT_DIR/test-now.sh" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/check-and-run.sh" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/run-all-tests.sh" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/merge-reports.sh" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/browser-test-prompt.md" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/browser-mcp.json" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/tauri-test-prompt.md" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/tauri-mcp.json" "$HARNESS_DIR/"
chmod +x "$HARNESS_DIR"/*.sh
echo "  Harness: $HARNESS_DIR"

# Claude Code skill
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/"
echo "  Skill:   $SKILL_DIR"

echo ""
echo "Done! Usage:"
echo ""
echo "  /test-gate              # Claude Code skill"
echo "  ~/.claude/test-harness/test-now.sh   # Command line"
echo ""
echo "Run in any git project with a dev server running."
