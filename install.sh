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
cp "$SCRIPT_DIR/run-review.sh" "$HARNESS_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/merge-reports.sh" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/browser-test-prompt.md" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/browser-mcp.json" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/tauri-test-prompt.md" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/tauri-mcp.json" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/code-review-prompt.md" "$HARNESS_DIR/" 2>/dev/null || true
chmod +x "$HARNESS_DIR"/*.sh
echo "  Harness: $HARNESS_DIR"

# Claude Code skills (4 skills, no more test-tauri alias)
mkdir -p "$SKILL_DIR/test-web" "$SKILL_DIR/test-desktop" "$SKILL_DIR/test-gate" "$SKILL_DIR/test-review"
cp "$SCRIPT_DIR/skills/test-web/SKILL.md" "$SKILL_DIR/test-web/"
cp "$SCRIPT_DIR/skills/test-desktop/SKILL.md" "$SKILL_DIR/test-desktop/"
cp "$SCRIPT_DIR/skills/test-gate/SKILL.md" "$SKILL_DIR/test-gate/"
cp "$SCRIPT_DIR/skills/test-review/SKILL.md" "$SKILL_DIR/test-review/"
# Korean reference docs
cp "$SCRIPT_DIR/skills/test-web/SKILL.ko.md" "$SKILL_DIR/test-web/" 2>/dev/null || true
cp "$SCRIPT_DIR/skills/test-desktop/SKILL.ko.md" "$SKILL_DIR/test-desktop/" 2>/dev/null || true
cp "$SCRIPT_DIR/skills/test-gate/SKILL.ko.md" "$SKILL_DIR/test-gate/" 2>/dev/null || true
cp "$SCRIPT_DIR/skills/test-review/SKILL.ko.md" "$SKILL_DIR/test-review/" 2>/dev/null || true
echo "  Skills:  /test-gate (router), /test-web, /test-desktop, /test-review"

echo ""
echo "Done! Commands:"
echo ""
echo "  /test-gate       Router — detects surfaces, delegates to adapter"
echo "  /test-web        Web app testing (Playwright MCP)"
echo "  /test-desktop    Desktop app testing (Tauri MCP)"
echo "  /test-review     Code review on git diff"
echo ""
echo "Or from command line:"
echo "  ~/.claude/test-harness/test-now.sh"
