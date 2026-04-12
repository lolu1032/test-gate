#!/bin/bash
# Test Gate installer

HARNESS_DIR="$HOME/.claude/test-harness"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Test Gate to $HARNESS_DIR ..."

mkdir -p "$HARNESS_DIR"

# Copy files
cp "$SCRIPT_DIR/test-now.sh" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/check-and-run.sh" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/run-all-tests.sh" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/merge-reports.sh" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/browser-test-prompt.md" "$HARNESS_DIR/"
cp "$SCRIPT_DIR/browser-mcp.json" "$HARNESS_DIR/"

# Make executable
chmod +x "$HARNESS_DIR"/*.sh

echo ""
echo "Done! Usage:"
echo ""
echo "  ~/.claude/test-harness/test-now.sh"
echo ""
echo "Run this in any git project with a dev server running."
