# CCPL — Claude Code Project Loader

```
   ██████╗ ██████╗██████╗ ██╗
  ██╔════╝██╔════╝██╔══██╗██║
  ██║     ██║     ██████╔╝██║
  ██║     ██║     ██╔═══╝ ██║
  ╚██████╗╚██████╗██║     ███████╗
   ╚═════╝ ╚═════╝╚═╝     ╚══════╝
  Claude Code Project Loader v2.0
```

A shell startup script for WSL that checks versions, environment health, and keeps your Claude Code development stack up to date — every time you open a terminal.

## Features

- **Version Checks** — Compares installed vs. latest for WSL Preview, Windows Terminal Canary, Claude Code, Node.js, npm, Git, and Python
- **Environment Health** — Disk space, `.wslconfig` presence, systemd status, APT upgradeable packages
- **Security & Best Practices** — Root user detection, `appendWindowsPath` check, SSH keys, GitHub CLI auth
- **Claude Code Readiness** — API key / credentials, settings.json, MCP servers, `CLAUDE.md`
- **Performance** — Filesystem location check (ext4 vs. NTFS), Anthropic API connectivity
- **Package Updates** — Auto-runs `npm update -g` and `claude update` when updates are available

## Install

One-liner (downloads and installs):

```bash
curl -fsSL https://raw.githubusercontent.com/freshdex/ccpl/main/install.sh | bash
```

### Manual install

```bash
git clone https://github.com/freshdex/ccpl.git
cd ccpl
bash install.sh
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/freshdex/ccpl/main/uninstall.sh | bash
```

Or from a local clone:

```bash
bash uninstall.sh
```

## Requirements

- **WSL** (Windows Subsystem for Linux)
- `curl`
- `python3`
- `node` and `npm`

## License

[MIT](LICENSE)
