#!/bin/bash
# PulseLauncher - Claude Code Project Loader
# Bleeding edge update checker, environment health, & package updater

PL_VERSION="2.1.0"

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
RED='\033[31m'
NC='\033[0m'

UPDATE_LABELS=()
UPDATE_CMDS=()
FIX_LABELS=()
FIX_CMDS=()

# ╔══════════════════════════════════════════╗
# ║            Rotating Debug Log            ║
# ╚══════════════════════════════════════════╝

LOG_DIR="$HOME/.local/share/pulselauncher"
LOG_FILE="$LOG_DIR/pulselauncher.log"
LOG_MAX_SIZE=102400  # 100 KB
LOG_KEEP=3           # number of rotated files to keep

mkdir -p "$LOG_DIR"

# Rotate logs if current file exceeds max size
if [ -f "$LOG_FILE" ]; then
    log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$log_size" -ge "$LOG_MAX_SIZE" ]; then
        for ((i=LOG_KEEP-1; i>=1; i--)); do
            [ -f "${LOG_FILE}.$i" ] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
        # Prune oldest beyond keep count
        rm -f "${LOG_FILE}.$((LOG_KEEP+1))"
    fi
fi

# Tee all output to log (with ANSI codes stripped in the log copy)
exec > >(tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1

# Run header
echo "═══ PulseLauncher run: $(date '+%Y-%m-%d %H:%M:%S') ═══"

# Detect Windows username for cross-filesystem checks
_pl_win_user=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
if [ -z "$_pl_win_user" ]; then
    _pl_win_user=$(wslvar USERNAME 2>/dev/null)
fi

# Compare two dotted version strings: returns 0 if equal, 1 if a>b, 2 if a<b
version_compare() {
    if [ "$1" = "$2" ]; then return 0; fi
    local IFS=.
    local i a=($1) b=($2)
    for ((i=0; i<${#a[@]} || i<${#b[@]}; i++)); do
        local va=${a[i]:-0} vb=${b[i]:-0}
        if ((va > vb)); then return 1; fi
        if ((va < vb)); then return 2; fi
    done
    return 0
}

fetch_latest_prerelease() {
    local repo="$1"
    curl -sf "https://api.github.com/repos/${repo}/releases" | \
        python3 -c "
import sys, json
try:
    for r in json.load(sys.stdin):
        if r.get('prerelease'):
            print(r['tag_name'].lstrip('v'))
            break
except: pass" 2>/dev/null
}


print_status() {
    local current="$1" latest="$2"
    if [ -n "$current" ] && [ -n "$latest" ]; then
        version_compare "$current" "$latest"
        local result=$?
        case $result in
            0) echo -e "    ${GREEN}Up to date${NC}" ;;
            1) echo -e "    ${CYAN}Ahead of release${NC}" ;;
            2) echo -e "    ${RED}Update available${NC}" ;;
        esac
        return $result
    fi
}

# One-line version display: NAME  current → latest  STATUS
print_version_line() {
    local name="$1" current="$2" latest="$3" width=24
    local pad=$(printf "%-${width}s" "$name")
    if [ -z "$current" ]; then
        echo -e "  ${BOLD}${pad}${NC} ${DIM}not found${NC}"
        return 3
    elif [ -z "$latest" ]; then
        echo -e "  ${BOLD}${pad}${NC} ${GREEN}${current}${NC}  ${DIM}(could not fetch latest)${NC}"
        return 3
    else
        version_compare "$current" "$latest"
        local result=$?
        case $result in
            0) echo -e "  ${BOLD}${pad}${NC} ${GREEN}${current}${NC}  ${GREEN}✓${NC}" ;;
            1) echo -e "  ${BOLD}${pad}${NC} ${GREEN}${current}${NC}  ${CYAN}ahead${NC}" ;;
            2) echo -e "  ${BOLD}${pad}${NC} ${YELLOW}${current}${NC} → ${GREEN}${latest}${NC}  ${RED}✗${NC}" ;;
        esac
        return $result
    fi
}

# Helper: print a passing check
pass_check() {
    echo -e "  ${GREEN}✓${NC} $1"
}

# Helper: print a warning check
warn_check() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

# Helper: print a failing check
fail_check() {
    echo -e "  ${RED}✗${NC} $1"
}

# ╔══════════════════════════════════════════╗
# ║              ASCII Header                ║
# ╚══════════════════════════════════════════╝

echo ""
echo -e "${CYAN}${BOLD}  ██████╗ ██╗   ██╗██╗     ███████╗███████╗${NC}"
echo -e "${CYAN}${BOLD}  ██╔══██╗██║   ██║██║     ██╔════╝██╔════╝${NC}"
echo -e "${CYAN}${BOLD}  ██████╔╝██║   ██║██║     ███████╗█████╗  ${NC}"
echo -e "${CYAN}${BOLD}  ██╔═══╝ ██║   ██║██║     ╚════██║██╔══╝  ${NC}"
echo -e "${CYAN}${BOLD}  ██║     ╚██████╔╝███████╗███████║███████╗${NC}"
echo -e "${CYAN}${BOLD}  ╚═╝      ╚═════╝ ╚══════╝╚══════╝╚══════╝${NC}"
echo -e "${DIM}  PulseLauncher v${PL_VERSION}${NC}"
echo ""

# ╔══════════════════════════════════════════╗
# ║        Section 1: Version Checks         ║
# ╚══════════════════════════════════════════╝

echo -e "${CYAN}${BOLD}  ── Version Checks ──────────────${NC}"
echo ""

# --- PulseLauncher ---
pl_current="$PL_VERSION"
pl_latest=$(curl -sf "https://raw.githubusercontent.com/freshdex/PulseLauncher/main/pulselauncher.sh" | \
    grep -m1 '^PL_VERSION=' | sed 's/PL_VERSION="//' | sed 's/"//')

print_version_line "PulseLauncher" "$pl_current" "$pl_latest"
if [ $? -eq 2 ]; then
    UPDATE_LABELS+=("PulseLauncher ${pl_current} → ${pl_latest}")
    UPDATE_CMDS+=("curl -fsSL https://raw.githubusercontent.com/freshdex/PulseLauncher/main/install.sh | bash")
fi

# --- Ubuntu LTS ---
ubuntu_current=$(. /etc/os-release 2>/dev/null && echo "$VERSION_ID")
ubuntu_latest=$(curl -sf "https://api.launchpad.net/devel/ubuntu/series" | \
    python3 -c "
import sys, json, re
try:
    for s in json.load(sys.stdin)['entries']:
        v = s.get('version', '')
        if re.fullmatch(r'\d+\.04', v) and s.get('status') in ('Current Stable Release', 'Supported'):
            print(v)
            break
except: pass" 2>/dev/null)

print_version_line "Ubuntu LTS" "$ubuntu_current" "$ubuntu_latest"
if [ $? -eq 2 ]; then
    UPDATE_LABELS+=("Ubuntu ${ubuntu_current} → ${ubuntu_latest}")
    UPDATE_CMDS+=("sudo do-release-upgrade -d")
fi

# --- WSL Preview ---
wsl_current=$(/mnt/c/Windows/System32/wsl.exe --version 2>/dev/null | head -1 | tr -d '\r\0' | awk '{print $NF}' | sed 's/\(.*\)\.0$/\1/')
wsl_latest=$(fetch_latest_prerelease "microsoft/WSL")

print_version_line "WSL Preview" "$wsl_current" "$wsl_latest"

# --- Windows Terminal Canary ---
term_current=$(PATH="/mnt/c/Windows/System32/WindowsPowerShell/v1.0:$PATH" \
    powershell.exe -NoProfile -Command \
    '(Get-AppxPackage Microsoft.WindowsTerminalCanary -ErrorAction SilentlyContinue).Version' \
    2>/dev/null | head -1 | tr -d '\r\0')
term_latest=$(curl -sfL "https://aka.ms/terminal-canary-installer" | \
    python3 -c "
import sys, re
m = re.search(r'MainBundle[^>]*Version=\"([^\"]+)\"', sys.stdin.read())
if m:
    parts = m.group(1).split('.')
    parts[0] = '1'
    print('.'.join(parts))" 2>/dev/null)

print_version_line "Terminal Canary" "$term_current" "$term_latest"

# --- Claude Code ---
claude_current=$(claude --version 2>/dev/null | awk '{print $1}')
claude_latest=$(curl -sf "https://registry.npmjs.org/@anthropic-ai/claude-code/latest" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null)

print_version_line "Claude Code" "$claude_current" "$claude_latest"
if [ $? -eq 2 ]; then
    UPDATE_LABELS+=("Claude Code ${claude_current} → ${claude_latest}")
    UPDATE_CMDS+=("npm install -g @anthropic-ai/claude-code@latest")
fi

# --- Node.js ---
node_current=$(node --version 2>/dev/null | sed 's/^v//')
node_latest=$(curl -sf "https://nodejs.org/dist/index.json" | \
    python3 -c "
import sys, json
try:
    for r in json.load(sys.stdin):
        if r.get('lts'):
            print(r['version'].lstrip('v'))
            break
except: pass" 2>/dev/null)

print_version_line "Node.js (LTS)" "$node_current" "$node_latest"

# --- npm ---
npm_current=$(npm --version 2>/dev/null)
npm_latest=$(curl -sf "https://registry.npmjs.org/npm/latest" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null)

print_version_line "npm" "$npm_current" "$npm_latest"
if [ $? -eq 2 ]; then
    UPDATE_LABELS+=("npm ${npm_current} → ${npm_latest}")
    UPDATE_CMDS+=("npm install -g npm@latest")
fi

# --- Git ---
git_current=$(git --version 2>/dev/null | awk '{print $3}')
git_latest=$(curl -sf "https://api.github.com/repos/git/git/tags?per_page=50" | \
    python3 -c "
import sys, json, re
try:
    for t in json.load(sys.stdin):
        name = t['name'].lstrip('v')
        if re.fullmatch(r'\d+\.\d+\.\d+', name):
            print(name)
            break
except: pass" 2>/dev/null)

print_version_line "Git" "$git_current" "$git_latest"
if [ $? -eq 2 ]; then
    UPDATE_LABELS+=("Git ${git_current} → ${git_latest}")
    UPDATE_CMDS+=("sudo add-apt-repository -y ppa:git-core/ppa && sudo apt-get update -y && sudo apt-get install -y git")
fi

# --- Python ---
# Check highest installed python3.x version (includes side-by-side installs)
python_current=$(ls /usr/bin/python3.[0-9]* 2>/dev/null | sed 's|.*/python||' | sort -t. -k1,1n -k2,2n | tail -1)
if [ -z "$python_current" ]; then
    python_current=$(python3 --version 2>/dev/null | awk '{print $2}')
fi
python_latest=$(curl -sf "https://api.github.com/repos/python/cpython/tags?per_page=50" | \
    python3 -c "
import sys, json, re
try:
    for t in json.load(sys.stdin):
        name = t['name'].lstrip('v')
        if re.fullmatch(r'\d+\.\d+\.\d+', name):
            print(name)
            break
except: pass" 2>/dev/null)

print_version_line "Python" "$python_current" "$python_latest"
if [ $? -eq 2 ]; then
    UPDATE_LABELS+=("Python ${python_current} → ${python_latest}")
    py_minor=$(echo "$python_latest" | cut -d. -f1-2)
    UPDATE_CMDS+=("sudo add-apt-repository -y ppa:deadsnakes/ppa && sudo apt-get update -y && sudo apt-get install -y python${py_minor}")
fi

echo ""

# ╔══════════════════════════════════════════╗
# ║      Section 2: Environment Health       ║
# ╚══════════════════════════════════════════╝

echo -e "${CYAN}${BOLD}  ── Environment Health ──────────${NC}"
echo ""

# --- Disk Space ---
disk_pct_used=$(df /home 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
if [ -n "$disk_pct_used" ]; then
    disk_free=$((100 - disk_pct_used))
    if [ "$disk_free" -lt 10 ]; then
        warn_check "Disk space: ${RED}${disk_free}% free${NC} on /home — consider cleaning up"
    else
        pass_check "Disk space: ${disk_free}% free on /home"
    fi
else
    warn_check "Disk space: could not check"
fi

# --- WSL Memory (.wslconfig) ---
if [ -n "$_pl_win_user" ] && [ -f "/mnt/c/Users/${_pl_win_user}/.wslconfig" ]; then
    pass_check ".wslconfig exists"
else
    warn_check ".wslconfig missing — WSL defaults to 50% RAM, no swap cap"
    FIX_LABELS+=("Create default .wslconfig (8GB RAM, 4GB swap, systemd)")
    FIX_CMDS+=("printf '[wsl2]\nmemory=8GB\nswap=4GB\n\n[boot]\nsystemd=true\n' > /mnt/c/Users/${_pl_win_user}/.wslconfig")
fi

# --- Systemd ---
init_proc=$(ps -p 1 -o comm= 2>/dev/null)
if [ "$init_proc" = "systemd" ]; then
    pass_check "Systemd is running as init"
else
    warn_check "Systemd not running (init: ${init_proc:-unknown}) — some services may not work"
    FIX_LABELS+=("Enable systemd in wsl.conf")
    FIX_CMDS+=("sudo bash -c 'printf \"\\n[boot]\\nsystemd=true\\n\" >> /etc/wsl.conf' && echo 'Restart WSL to apply: wsl --shutdown'")
fi

# --- APT Upgradeable ---
apt_count=$(apt list --upgradeable 2>/dev/null | grep -c 'upgradeable')
if [ "$apt_count" -gt 0 ] 2>/dev/null; then
    warn_check "${apt_count} APT package(s) upgradeable"
    FIX_LABELS+=("Upgrade ${apt_count} APT package(s)")
    FIX_CMDS+=("sudo apt-get upgrade -y")
else
    pass_check "APT packages up to date"
fi

echo ""

# ╔══════════════════════════════════════════╗
# ║   Section 3: Security & Best Practices   ║
# ╚══════════════════════════════════════════╝

echo -e "${CYAN}${BOLD}  ── Security & Best Practices ──${NC}"
echo ""

# --- Not Root ---
if [ "$EUID" -eq 0 ]; then
    fail_check "Running as root — use a regular user"
else
    pass_check "Running as regular user"
fi

# --- appendWindowsPath ---
if grep -qE '^\s*appendWindowsPath\s*=\s*false' /etc/wsl.conf 2>/dev/null; then
    pass_check "appendWindowsPath disabled in wsl.conf"
else
    warn_check "appendWindowsPath not disabled — Windows PATH leaks into WSL"
    FIX_LABELS+=("Disable appendWindowsPath in wsl.conf")
    FIX_CMDS+=("sudo bash -c 'printf \"\\n[interop]\\nappendWindowsPath=false\\n\" >> /etc/wsl.conf' && echo 'Restart WSL to apply: wsl --shutdown'")
fi

# --- SSH Keys ---
if ls ~/.ssh/id_* &>/dev/null; then
    pass_check "SSH keys found"
else
    warn_check "No SSH keys found"
    FIX_LABELS+=("Generate SSH key (ed25519)")
    FIX_CMDS+=("ssh-keygen -t ed25519 -C \"$(whoami)@$(hostname)\" -N '' -f ~/.ssh/id_ed25519")
fi

# --- GitHub CLI ---
if command -v gh &>/dev/null; then
    pass_check "GitHub CLI installed"

    # --- gh auth ---
    if gh auth status &>/dev/null; then
        pass_check "GitHub CLI authenticated"
    else
        warn_check "GitHub CLI not authenticated"
        FIX_LABELS+=("Authenticate GitHub CLI")
        FIX_CMDS+=("gh auth login")
    fi
else
    warn_check "GitHub CLI not installed"
    FIX_LABELS+=("Install GitHub CLI")
    _gh_arch=$(dpkg --print-architecture 2>/dev/null || echo amd64)
    FIX_CMDS+=("sudo mkdir -p -m 755 /etc/apt/keyrings && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && echo 'deb [arch=${_gh_arch} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null && sudo apt-get update -y && sudo apt-get install -y gh")
fi

echo ""

# ╔══════════════════════════════════════════╗
# ║    Section 4: Claude Code Readiness      ║
# ╚══════════════════════════════════════════╝

echo -e "${CYAN}${BOLD}  ── Claude Code Readiness ──────${NC}"
echo ""

# --- Auth ---
if [ -n "$ANTHROPIC_API_KEY" ]; then
    pass_check "ANTHROPIC_API_KEY is set"
elif [ -s "$HOME/.claude/.credentials.json" ]; then
    pass_check "Claude credentials found"
else
    warn_check "No Claude auth — set ANTHROPIC_API_KEY or log in"
    FIX_LABELS+=("Log in to Claude Code")
    FIX_CMDS+=("claude")
fi

# --- Settings ---
if [ -f "$HOME/.claude/settings.json" ]; then
    pass_check "Claude settings.json exists"
else
    warn_check "No Claude settings.json"
    FIX_LABELS+=("Initialize Claude Code settings")
    FIX_CMDS+=("claude")
fi

# --- MCP Servers ---
if [ -f "$HOME/.claude/settings.json" ]; then
    mcp_count=$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    servers = d.get('mcpServers', {})
    print(len(servers))
except: print(0)
" "$HOME/.claude/settings.json" 2>/dev/null)
    if [ "${mcp_count:-0}" -gt 0 ]; then
        pass_check "MCP servers configured: ${mcp_count}"
    else
        warn_check "No MCP servers configured"
    fi
fi

# --- CLAUDE.md ---
if [ -f "$HOME/CLAUDE.md" ]; then
    pass_check "~/CLAUDE.md found"
else
    warn_check "No ~/CLAUDE.md"
    FIX_LABELS+=("Create ~/CLAUDE.md template")
    FIX_CMDS+=("printf '# CLAUDE.md\n\nThis file provides guidance to Claude Code when working in this home directory.\n\n## Preferences\n\n- \n' > ~/CLAUDE.md")
fi

echo ""

# ╔══════════════════════════════════════════╗
# ║        Section 5: Performance            ║
# ╚══════════════════════════════════════════╝

echo -e "${CYAN}${BOLD}  ── Performance ────────────────${NC}"
echo ""

# --- Working Directory ---
if [[ "$HOME" == /mnt/c* ]]; then
    fail_check "HOME is on Windows filesystem (${HOME}) — severe I/O penalty"
else
    pass_check "HOME is on Linux filesystem"
fi

# --- API Connectivity ---
if curl -sf --max-time 3 https://api.anthropic.com >/dev/null 2>&1; then
    pass_check "Anthropic API reachable"
else
    warn_check "Anthropic API unreachable — check network/proxy"
fi

echo ""

# ╔══════════════════════════════════════════╗
# ║       Section 6: Package Updates         ║
# ╚══════════════════════════════════════════╝

echo -e "${CYAN}${BOLD}  ── Package Updates ────────────${NC}"
echo ""

if [ ${#UPDATE_LABELS[@]} -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Everything is up to date"
else
    count=${#UPDATE_LABELS[@]}
    for ((i=0; i<count; i++)); do
        echo -e "  ${BOLD}$((i+1)))${NC} ${UPDATE_LABELS[$i]}"
    done
    echo -e "  ${BOLD}$((count+1)))${NC} Update all"
    echo -e "  ${BOLD}0)${NC} Skip"
    echo ""
    echo -ne "  ${BOLD}Select [0-$((count+1))]:${NC} "
    read -r choice

    run_update() {
        local idx=$1
        echo -e "  ${UPDATE_LABELS[$idx]} ..."
        if eval "${UPDATE_CMDS[$idx]}"; then
            echo -e "  ${GREEN}done${NC}"
        else
            echo -e "  ${RED}failed${NC}"
        fi
    }

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        echo -e "  ${DIM}Skipped${NC}"
    elif [ "$choice" = "$((count+1))" ]; then
        for ((i=0; i<count; i++)); do
            run_update "$i"
        done
    elif [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$count" ] 2>/dev/null; then
        run_update "$((choice-1))"
    else
        echo -e "  ${YELLOW}Invalid choice — skipped${NC}"
    fi
fi

echo ""

# ╔══════════════════════════════════════════╗
# ║        Section 7: Recommended Fixes      ║
# ╚══════════════════════════════════════════╝

echo -e "${CYAN}${BOLD}  ── Recommended Fixes ──────────${NC}"
echo ""

if [ ${#FIX_LABELS[@]} -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} No issues to fix"
else
    fix_count=${#FIX_LABELS[@]}
    for ((i=0; i<fix_count; i++)); do
        echo -e "  ${BOLD}$((i+1)))${NC} ${FIX_LABELS[$i]}"
    done
    echo -e "  ${BOLD}$((fix_count+1)))${NC} Fix all"
    echo -e "  ${BOLD}0)${NC} Skip"
    echo ""
    echo -ne "  ${BOLD}Select [0-$((fix_count+1))]:${NC} "
    read -r fix_choice

    run_fix() {
        local idx=$1
        echo -e "  ${FIX_LABELS[$idx]} ..."
        if eval "${FIX_CMDS[$idx]}"; then
            echo -e "  ${GREEN}done${NC}"
        else
            echo -e "  ${RED}failed${NC}"
        fi
    }

    if [ "$fix_choice" = "0" ] || [ -z "$fix_choice" ]; then
        echo -e "  ${DIM}Skipped${NC}"
    elif [ "$fix_choice" = "$((fix_count+1))" ]; then
        for ((i=0; i<fix_count; i++)); do
            run_fix "$i"
        done
    elif [ "$fix_choice" -ge 1 ] 2>/dev/null && [ "$fix_choice" -le "$fix_count" ] 2>/dev/null; then
        run_fix "$((fix_choice-1))"
    else
        echo -e "  ${YELLOW}Invalid choice — skipped${NC}"
    fi
fi

echo ""
