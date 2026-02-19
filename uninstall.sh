#!/bin/bash
# CCPL Uninstaller — https://github.com/freshdex/ccpl
set -e

BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="ccpl.sh"
MARKER="# CCPL — Claude Code Project Loader"

echo ""
echo -e "${BOLD}CCPL Uninstaller${NC}"
echo ""

# --- Remove script ---
if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    rm "$INSTALL_DIR/$SCRIPT_NAME"
    echo -e "${GREEN}✓${NC} Removed $INSTALL_DIR/$SCRIPT_NAME"
else
    echo -e "${YELLOW}⚠${NC} $INSTALL_DIR/$SCRIPT_NAME not found — skipped"
fi

# --- Remove from shell rc files ---
remove_from_rc() {
    local rc="$1"
    if [ -f "$rc" ] && grep -qF "$MARKER" "$rc" 2>/dev/null; then
        # Remove the marker line and the source line that follows it
        sed -i "/$MARKER/,+1d" "$rc"
        # Clean up any trailing blank lines left behind
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$rc"
        echo -e "${GREEN}✓${NC} Removed from $(basename "$rc")"
    fi
}

remove_from_rc "$HOME/.bashrc"
remove_from_rc "$HOME/.zshrc"

echo ""
echo -e "${GREEN}Done!${NC} CCPL has been uninstalled."
echo ""
