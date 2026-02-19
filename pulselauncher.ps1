#Requires -Version 5.1
<#
.SYNOPSIS
    PulseLauncher Windows Launcher — runs WSL health checks then opens a coding session.
.DESCRIPTION
    Phase 1: Runs PulseLauncher health checks via WSL (if installed).
    Phase 2: Presents a numbered session picker for custom presets,
             WSL distros, and Windows Terminal profiles.
#>

# ─── Data Sources ──────────────────────────────────────────────────────────────

function Get-PlPresets {
    $path = Join-Path $env:USERPROFILE '.pulselauncher\presets.json'
    if (-not (Test-Path $path)) { return @() }
    try {
        $content = Get-Content $path -Raw
        $parsed  = $content | ConvertFrom-Json
        if ($parsed -is [System.Array]) { return $parsed }
        return @($parsed)
    } catch {
        Write-Host "  [Warning] presets.json could not be parsed: $_" -ForegroundColor Yellow
        return @()
    }
}

function Get-WslDistros {
    try {
        $raw = & wsl -l -q 2>$null
        if (-not $raw) { return @() }
        $lines = @()
        foreach ($line in $raw) {
            $cleaned = ($line -replace '\x00', '').Trim()
            if ($cleaned -ne '') { $lines += $cleaned }
        }
        return $lines
    } catch {
        return @()
    }
}

function Get-WtProfiles {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:APPDATA      'Microsoft\Windows Terminal\settings.json')
    )
    foreach ($candidate in $candidates) {
        if (-not (Test-Path $candidate)) { continue }
        try {
            $s = Get-Content $candidate -Raw | ConvertFrom-Json
            $list = $s.profiles.list
            if ($list) {
                $visible = @($list | Where-Object { -not $_.hidden })
                if ($visible.Count -gt 0) { return $visible }
            }
        } catch { continue }
    }
    return @()
}

# ─── Phase 1: Health Checks ────────────────────────────────────────────────────

function Invoke-PlHealthChecks {
    Write-Host ''
    Write-Host '  Checking environment with PulseLauncher...' -ForegroundColor Cyan
    Write-Host ''

    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
        Write-Host '  WSL is not installed.' -ForegroundColor Yellow
        Write-Host '  See: https://learn.microsoft.com/windows/wsl/install' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    # Try pulselauncher from WSL PATH
    $found = (& wsl -- which pulselauncher 2>$null) -replace '\x00', ''
    if ($found -and $found.Trim() -ne '') {
        & wsl -- pulselauncher
        return
    }

    # Try adjacent pulselauncher.sh
    $plSh = Join-Path $PSScriptRoot 'pulselauncher.sh'
    if (Test-Path $plSh) {
        $wslPath = $null
        try {
            $raw = & wsl -- wslpath -u $plSh 2>$null
            $wslPath = ($raw -replace '\x00', '').Trim()
        } catch { }
        if (-not $wslPath -and $plSh -match '^([A-Za-z]):(.+)$') {
            $drive   = $Matches[1].ToLower()
            $rest    = $Matches[2] -replace '\\', '/'
            $wslPath = "/mnt/$drive$rest"
        }
        if ($wslPath) {
            & wsl -- bash "$wslPath"
            return
        }
    }

    Write-Host '  PulseLauncher is not installed in WSL.' -ForegroundColor Yellow
    Write-Host '  Run from inside WSL to install:' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '    curl -fsSL https://raw.githubusercontent.com/freshdex/PulseLauncher/main/install.sh | bash' -ForegroundColor White
    Write-Host ''
}

# ─── Phase 2: Session Picker ───────────────────────────────────────────────────

function Invoke-WtOrFallback {
    param(
        [string]$WslArgs,
        [string]$WtProfileName,
        [string]$ItemType
    )

    $wtCmd       = Get-Command wt.exe -ErrorAction SilentlyContinue
    $wtAvailable = ($null -ne $wtCmd)
    $inWt        = ($null -ne $env:WT_SESSION -and $env:WT_SESSION -ne '')

    if ($ItemType -eq 'preset-wt' -or $ItemType -eq 'wt-profile') {
        if (-not $wtAvailable) {
            Write-Host "  Windows Terminal is not installed; cannot open profile `"$WtProfileName`"." -ForegroundColor Yellow
            return
        }
        $wtArgs = "new-tab --profile `"$WtProfileName`""
        if ($inWt) {
            Start-Process wt.exe -ArgumentList "-w 0 $wtArgs"
        } else {
            Start-Process wt.exe -ArgumentList $wtArgs
        }
        return
    }

    # WSL session
    if ($wtAvailable -and $inWt) {
        Start-Process wt.exe -ArgumentList "-w 0 new-tab wsl $WslArgs"
    } elseif ($wtAvailable) {
        Start-Process wt.exe -ArgumentList "new-tab wsl $WslArgs"
    } else {
        Start-Process powershell.exe -ArgumentList "-NoExit -Command wsl $WslArgs"
    }
}

function Invoke-SessionLaunch {
    param($Item, [bool]$LaunchClaude)

    switch ($Item.type) {
        'distro' {
            $wslArgs = "-d `"$($Item.data)`""
            if ($LaunchClaude) { $wslArgs += ' -- claude' }
            Invoke-WtOrFallback -WslArgs $wslArgs -ItemType 'distro'
        }
        'preset' {
            $p = $Item.data
            if ($p.type -eq 'wt-profile') {
                Invoke-WtOrFallback -WtProfileName $p.profile -ItemType 'preset-wt'
                return
            }
            # WSL preset
            $wslArgs = if ($p.distro) { "-d `"$($p.distro)`"" } else { '' }
            if ($p.dir)     { $wslArgs += " --cd `"$($p.dir)`"" }
            if ($p.command) {
                $wslArgs += " -- $($p.command)"
            } elseif ($LaunchClaude) {
                $wslArgs += ' -- claude'
            }
            Invoke-WtOrFallback -WslArgs $wslArgs.Trim() -ItemType 'preset-wsl'
        }
        'wt-profile' {
            $profileName = if ($Item.data.name) { $Item.data.name } else { '' }
            Invoke-WtOrFallback -WtProfileName $profileName -ItemType 'wt-profile'
        }
    }
}

function Show-SessionPicker {
    $presets  = @(Get-PlPresets)
    $distros  = @(Get-WslDistros)
    $profiles = @(Get-WtProfiles)

    $items = @()

    if ($presets.Count -gt 0) {
        Write-Host ''
        Write-Host '  Custom Presets' -ForegroundColor Cyan
        foreach ($p in $presets) {
            $idx   = $items.Count + 1
            $label = if ($p.name) { $p.name } else { '(unnamed preset)' }
            Write-Host "    [$idx] $label"
            $items += @{ type = 'preset'; data = $p }
        }
    }

    if ($distros.Count -gt 0) {
        Write-Host ''
        Write-Host '  WSL Distros' -ForegroundColor Cyan
        foreach ($d in $distros) {
            $idx = $items.Count + 1
            Write-Host "    [$idx] $d"
            $items += @{ type = 'distro'; data = $d }
        }
    }

    if ($profiles.Count -gt 0) {
        Write-Host ''
        Write-Host '  Windows Terminal Profiles' -ForegroundColor Cyan
        foreach ($prof in $profiles) {
            $idx   = $items.Count + 1
            $label = if ($prof.name) { $prof.name } else { '(unnamed profile)' }
            Write-Host "    [$idx] $label"
            $items += @{ type = 'wt-profile'; data = $prof }
        }
    }

    if ($items.Count -eq 0) {
        Write-Host ''
        Write-Host '  No sessions available.' -ForegroundColor Yellow
        Write-Host '  Install WSL, configure Windows Terminal, or add presets at:' -ForegroundColor DarkGray
        Write-Host "    $env:USERPROFILE\.pulselauncher\presets.json" -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    Write-Host ''
    Write-Host '    [0] Exit'
    Write-Host ''

    # Claude toggle — only relevant if any WSL-capable items exist
    $hasWslItems = ($distros.Count -gt 0)
    if (-not $hasWslItems) {
        foreach ($p in $presets) {
            if ($p.type -eq 'wsl') { $hasWslItems = $true; break }
        }
    }

    $launchClaude = $false
    if ($hasWslItems) {
        $claudeAnswer = Read-Host '  Launch Claude Code in WSL sessions? [y/N]'
        $launchClaude = ($claudeAnswer -eq 'y' -or $claudeAnswer -eq 'Y')
    }

    $choice = Read-Host '  Select a session'
    $num    = 0
    if (-not [int]::TryParse($choice.Trim(), [ref]$num)) {
        Write-Host '  Invalid selection.' -ForegroundColor Red
        return
    }
    if ($num -eq 0) { return }
    if ($num -lt 1 -or $num -gt $items.Count) {
        Write-Host '  Invalid selection.' -ForegroundColor Red
        return
    }

    $selected = $items[$num - 1]
    Invoke-SessionLaunch -Item $selected -LaunchClaude $launchClaude
}

# ─── Entry Point ───────────────────────────────────────────────────────────────

function Main {
    Invoke-PlHealthChecks
    Show-SessionPicker
}

Main
