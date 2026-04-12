#!/bin/bash
# Test Gate installer

HARNESS_DIR="$HOME/.claude/test-harness"
SKILL_DIR="$HOME/.claude/skills"
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

# Claude Code skills
mkdir -p "$SKILL_DIR/test-web" "$SKILL_DIR/test-tauri" "$SKILL_DIR/test-gate"
cp "$SCRIPT_DIR/skills/test-web/SKILL.md" "$SKILL_DIR/test-web/"
cp "$SCRIPT_DIR/skills/test-tauri/SKILL.md" "$SKILL_DIR/test-tauri/"
cp "$SCRIPT_DIR/skills/test-gate/SKILL.md" "$SKILL_DIR/test-gate/"
echo "  Skills:  /test-web, /test-tauri, /test-gate"

echo ""
echo "Done! Commands:"
echo ""
echo "  /test-web     Web app testing (Playwright MCP)"
echo "  /test-tauri   Tauri desktop testing (Tauri MCP)"
echo "  /test-gate    Both (auto-detect)"
echo ""
echo "Or from command line:"
echo "  ~/.claude/test-harness/test-now.sh"
