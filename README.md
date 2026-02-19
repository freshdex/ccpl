# PulseLauncher

```
  ██████╗ ██╗   ██╗██╗     ███████╗███████╗
  ██╔══██╗██║   ██║██║     ██╔════╝██╔════╝
  ██████╔╝██║   ██║██║     ███████╗█████╗
  ██╔═══╝ ██║   ██║██║     ╚════██║██╔══╝
  ██║     ╚██████╔╝███████╗███████║███████╗
  ╚═╝      ╚═════╝ ╚══════╝╚══════╝╚══════╝
```

A single command for WSL that audits your Claude Code stack, flags issues, and keeps everything up to date.

## What it checks

| Section | Checks |
|---|---|
| **Version Checks** | PulseLauncher, Ubuntu LTS, WSL Preview, Windows Terminal Canary, Claude Code, Node.js, npm, Git, Python |
| **Environment Health** | Disk space, `.wslconfig`, systemd, APT upgradeable packages |
| **Security** | Root user, `appendWindowsPath`, SSH keys, GitHub CLI auth |
| **Claude Code Readiness** | API key / credentials, `settings.json`, MCP servers, `~/CLAUDE.md` |
| **Performance** | Filesystem location (ext4 vs NTFS), Anthropic API connectivity |

At the end, two interactive menus let you apply any available updates or fixes in one step.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/freshdex/PulseLauncher/main/install.sh | bash
```

Or from a local clone:

```bash
git clone https://github.com/freshdex/PulseLauncher.git
cd PulseLauncher
bash install.sh
```

Then run `pulselauncher` any time you want to audit your environment.

## Windows launcher

`pulselauncher.ps1` is a companion PowerShell script that runs the WSL health checks and then presents an interactive session picker — letting you open WSL distros, Windows Terminal profiles, or saved project presets in a new tab.

**Install** — run `bash install.sh` from WSL and answer **y** when prompted, or copy manually:

```bash
cp pulselauncher.ps1 /mnt/c/Users/$USER/.pulselauncher/pulselauncher.ps1
```

**One-time PowerShell setup:**

```powershell
# Allow local scripts
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# Optional: add to PATH so you can run 'pulselauncher' from anywhere
[Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';' + $env:USERPROFILE + '\.pulselauncher', 'User')
```

**Usage:**

```powershell
pulselauncher
```

Phase 1 runs the full health-check report in WSL. Phase 2 shows a session picker:

```
  Custom Presets
    [1] My WSL Project
    [2] Work Ubuntu

  WSL Distros
    [3] Ubuntu

  Windows Terminal Profiles
    [4] Windows PowerShell
    [5] Ubuntu

    [0] Exit

  Launch Claude Code in WSL sessions? [y/N]
  Select a session:
```

Sessions open in a new Windows Terminal tab (`wt.exe`), or fall back to a new PowerShell window if Windows Terminal isn't installed.

## Presets

Copy `presets.example.json` to `%USERPROFILE%\.pulselauncher\presets.json` and edit it:

```json
[
  { "name": "My WSL Project",  "type": "wsl",        "distro": "Ubuntu", "dir": "~/projects/myproject", "command": "claude" },
  { "name": "Work Ubuntu",     "type": "wsl",        "distro": "Ubuntu-22.04", "dir": "~/work" },
  { "name": "PowerShell Core", "type": "wt-profile", "profile": "PowerShell" }
]
```

| Field | Type | Description |
|---|---|---|
| `name` | all | Display label in the picker |
| `type` | all | `wsl` or `wt-profile` |
| `distro` | wsl | WSL distro name (e.g. `Ubuntu-22.04`) |
| `dir` | wsl | Starting directory inside the distro |
| `command` | wsl | Command to run on launch; if omitted, the Claude toggle applies |
| `profile` | wt-profile | Windows Terminal profile name |

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/freshdex/PulseLauncher/main/uninstall.sh | bash
```

## Requirements

- WSL (Windows Subsystem for Linux)
- `curl`, `python3`, `node`, `npm`

## License

[MIT](LICENSE)
