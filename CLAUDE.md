# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PulseLauncher is a Bash utility (v2.1.0) for WSL environments that audits a Claude Code development stack: version checks, environment health, security best practices, Claude Code readiness, performance, and package updates. A companion PowerShell launcher (`pulselauncher.ps1`) runs the same checks from Windows Terminal and adds an interactive session picker.

## Running and Installing

```bash
# Run directly from repo
bash pulselauncher.sh

# Install to ~/.local/bin/pulselauncher (optionally also installs pulselauncher.ps1 to %USERPROFILE%\.pulselauncher)
bash install.sh

# Uninstall (removes ~/.local/bin/pulselauncher only — logs and Windows-side files are left in place)
bash uninstall.sh
```

```powershell
# Windows: run health checks + session picker from PowerShell
.\pulselauncher.ps1
```

There are no automated tests. Validate changes by running `bash pulselauncher.sh` inside a WSL environment.

## Architecture

Everything lives in `pulselauncher.sh` (~560 lines). The script runs sequentially through 7 sections, each printing a block of status lines then accumulating any fixable issues into menus at the end.

**Flow:**
1. Logging setup — rotating debug log at `$HOME/.local/share/pulselauncher/pulselauncher.log` (100KB max, 3 backups)
2. Utility layer — `version_compare()`, `fetch_latest_prerelease()`, `print_status()`, `print_version_line()`, `pass_check()`/`warn_check()`/`fail_check()`
3. Sections 1–5 run in order, each fetching data (GitHub API, npm registry, Launchpad API) and calling `print_version_line()` or `warn_check()`; fixable warnings append to `FIX_LABELS[]`/`FIX_CMDS[]`; available updates append to `UPDATE_LABELS[]`/`UPDATE_CMDS[]`
4. Sections 6–7 present numbered interactive menus driven by those arrays — Section 6 runs package updates, Section 7 runs environment fixes

**Key conventions:**
- `print_version_line()` is the main display helper: prints `NAME  current → latest  ✓/✗` and returns the same exit code as `version_compare()` (0 equal, 1 ahead, 2 older). `print_status()` is a simpler variant used for single-field checks.
- Warnings that have automated fixes are appended to `FIX_LABELS[]`/`FIX_CMDS[]`; available package updates go to `UPDATE_LABELS[]`/`UPDATE_CMDS[]`
- All ANSI color codes are stripped before writing to the log file
- API calls use `curl` with short timeouts (`-m 5` or `-m 3`) and fall back to "Unable to check" rather than failing hard
- `version_compare()` returns 0 (equal), 1 (first arg newer), or 2 (first arg older) — used throughout for update detection
- The script detects the Windows username via `cmd.exe /C "echo %USERNAME%"` (falls back to `wslvar USERNAME`) to construct Windows-side paths

**install.sh** uses `set -e`, validates WSL environment and required deps (curl, python3, node, npm), then copies `pulselauncher.sh` to `$HOME/.local/bin/pulselauncher` and makes it executable. If running from a local clone it copies the adjacent file; otherwise it downloads from GitHub. After the WSL install it prompts to optionally copy `pulselauncher.ps1` to `/mnt/c/Users/<user>/.pulselauncher/pulselauncher.ps1` (i.e. `%USERPROFILE%\.pulselauncher`).

**pulselauncher.ps1** (~200 lines, PowerShell 5.1+) runs as two sequential phases:
1. **Health checks** — probes `wsl -- which pulselauncher`; if found runs `wsl -- pulselauncher` interactively; else falls back to an adjacent `pulselauncher.sh` via `wslpath`; else prints the install one-liner.
2. **Session picker** — collects Custom Presets (`%USERPROFILE%\.pulselauncher\presets.json`), WSL distros (`wsl -l -q`), and Windows Terminal profiles (`Get-WtProfiles` reads `settings.json` from four candidate paths in priority order: canary → preview → stable → roaming appdata). Presents a numbered menu; optionally prepends `-- claude` to WSL launches. Opens sessions via `wt.exe` new-tab (or `Start-Process powershell.exe` fallback when WT is absent).

**presets.example.json** — template for `%USERPROFILE%\.pulselauncher\presets.json`. Two types: `wsl` (distro + dir + optional command) and `wt-profile` (Windows Terminal profile name).
