#!/bin/bash
# PulseLauncher Installer — https://github.com/freshdex/PulseLauncher
set -e

BOLD='\033[1m'
GREEN='\033[32m'
RED='\033[31m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
BIN_NAME="pulselauncher"

echo ""
echo -e "${BOLD}PulseLauncher Installer${NC}"
echo ""

# --- Check WSL ---
if [ ! -f /proc/version ] || ! grep -qi microsoft /proc/version 2>/dev/null; then
    echo -e "${RED}Error:${NC} PulseLauncher requires WSL (Windows Subsystem for Linux)."
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

# If running from a local clone, copy the adjacent pulselauncher.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/pulselauncher.sh" ]; then
    cp "$SCRIPT_DIR/pulselauncher.sh" "$INSTALL_DIR/$BIN_NAME"
else
    curl -fsSL "https://raw.githubusercontent.com/freshdex/PulseLauncher/main/pulselauncher.sh" \
        -o "$INSTALL_DIR/$BIN_NAME"
fi

chmod +x "$INSTALL_DIR/$BIN_NAME"
echo -e "${GREEN}✓${NC} Installed to $INSTALL_DIR/$BIN_NAME"

# --- Ensure ~/.local/bin is in PATH for future shells ---
# Check .bashrc content, not the current session PATH (which may already
# include it via a login shell even if .bashrc hasn't been written yet)
if ! grep -qF '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
    echo -e "${GREEN}✓${NC} Added $INSTALL_DIR to PATH in ~/.bashrc"
fi

echo ""
echo -e "${GREEN}Done!${NC} Open a new WSL tab and run ${BOLD}pulselauncher${NC}."

# --- Optional: Windows PowerShell launcher ---
_win_user=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
[ -z "$_win_user" ] && _win_user=$(wslvar USERNAME 2>/dev/null)
[ -z "$_win_user" ] && _win_user=$(ls /mnt/c/Users/ 2>/dev/null | grep -Ev '^(Public|Default|Default User|All Users)$' | head -1)
if [ -n "$_win_user" ]; then
    _win_pl_dir="/mnt/c/Users/${_win_user}/.pulselauncher"

    _install_ps1() {
        if [ -f "$SCRIPT_DIR/pulselauncher.ps1" ]; then
            _ps1_src="$SCRIPT_DIR/pulselauncher.ps1"
        else
            _ps1_tmp=$(mktemp /tmp/pl_ps1.XXXXXX)
            curl -fsSL "https://raw.githubusercontent.com/freshdex/PulseLauncher/main/pulselauncher.ps1" \
                -o "$_ps1_tmp" || { echo "Download failed"; rm -f "$_ps1_tmp"; return 1; }
            _ps1_src="$_ps1_tmp"
        fi
        mkdir -p "$_win_pl_dir"
        cp "$_ps1_src" "$_win_pl_dir/pulselauncher.ps1"
        [ -n "${_ps1_tmp:-}" ] && rm -f "$_ps1_tmp"
        echo -e "${GREEN}✓${NC} Installed to %USERPROFILE%\\.pulselauncher\\pulselauncher.ps1"
        echo "  PowerShell hint: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
        echo "  PATH hint:       [Environment]::SetEnvironmentVariable('PATH', \$env:PATH + ';\$env:USERPROFILE\\.pulselauncher', 'User')"
    }

    # Stdin is a terminal — prompt interactively
    if [ -t 0 ]; then
        echo -ne "\n  Install Windows PowerShell launcher to %USERPROFILE%\\.pulselauncher? [y/N]: "
        read -r _ps_choice
        if [ "$_ps_choice" = "y" ] || [ "$_ps_choice" = "Y" ]; then
            _install_ps1
        fi
    # Stdin is a pipe (e.g. curl | bash) — auto-install the PS1 launcher
    else
        echo ""
        _install_ps1
    fi
fi

echo ""
