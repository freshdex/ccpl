#!/bin/bash
# PulseLauncher Uninstaller — https://github.com/freshdex/PulseLauncher
set -e

BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
BIN_NAME="pulselauncher"

echo ""
echo -e "${BOLD}PulseLauncher Uninstaller${NC}"
echo ""

# --- Remove binary ---
if [ -f "$INSTALL_DIR/$BIN_NAME" ]; then
    rm "$INSTALL_DIR/$BIN_NAME"
    echo -e "${GREEN}✓${NC} Removed $INSTALL_DIR/$BIN_NAME"
else
    echo -e "${YELLOW}⚠${NC} $INSTALL_DIR/$BIN_NAME not found — skipped"
fi

echo ""
echo -e "${GREEN}Done!${NC} PulseLauncher has been uninstalled."
echo ""
