#!/bin/bash
# CCPL Installer — https://github.com/freshdex/ccpl
set -e

BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="ccpl.sh"
SOURCE_LINE="source \"$INSTALL_DIR/$SCRIPT_NAME\""
MARKER="# CCPL — Claude Code Project Loader"

echo ""
echo -e "${BOLD}CCPL Installer${NC}"
echo ""

# --- Check WSL ---
if [ ! -f /proc/version ] || ! grep -qi microsoft /proc/version 2>/dev/null; then
    echo -e "${RED}Error:${NC} CCPL requires WSL (Windows Subsystem for Linux)."
    exit 1
fi

# --- Check dependencies ---
missing=()
for cmd in curl python3 node npm; do
    if ! command -v "$cmd" &>/dev/null; then
        missing+=("$cmd")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}Error:${NC} Missing required dependencies: ${missing[*]}"
    echo "Install them and re-run this script."
    exit 1
fi

echo -e "${GREEN}✓${NC} WSL detected"
echo -e "${GREEN}✓${NC} Dependencies satisfied"

# --- Download / copy script ---
mkdir -p "$INSTALL_DIR"

# If running from a local clone, copy the adjacent ccpl.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/$SCRIPT_NAME" ]; then
    cp "$SCRIPT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
else
    curl -fsSL "https://raw.githubusercontent.com/freshdex/ccpl/main/ccpl.sh" \
        -o "$INSTALL_DIR/$SCRIPT_NAME"
fi

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo -e "${GREEN}✓${NC} Installed to $INSTALL_DIR/$SCRIPT_NAME"

# --- Add to shell rc files ---
add_to_rc() {
    local rc="$1"
    if [ -f "$rc" ]; then
        if ! grep -qF "$MARKER" "$rc" 2>/dev/null; then
            printf '\n%s\n%s\n' "$MARKER" "$SOURCE_LINE" >> "$rc"
            echo -e "${GREEN}✓${NC} Added to $(basename "$rc")"
        else
            echo -e "${YELLOW}⚠${NC} Already in $(basename "$rc") — skipped"
        fi
    fi
}

add_to_rc "$HOME/.bashrc"
add_to_rc "$HOME/.zshrc"

echo ""
echo -e "${GREEN}Done!${NC} Open a new terminal or run:"
echo -e "  source $INSTALL_DIR/$SCRIPT_NAME"
echo ""
