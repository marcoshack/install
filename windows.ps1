#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows PowerShell Setup Script

.DESCRIPTION
    Sets up PowerShell with Oh My Posh, Nerd Fonts, and custom configuration.
    Designed for Windows environments where development is primarily done in WSL.

.NOTES
    Usage: irm https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/windows.ps1 | iex
#>

#region Setup and Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

Write-Info "Starting Windows PowerShell setup..."

# Check if running on Windows
if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
    # PowerShell Core on non-Windows
    Write-Err "This script is designed for Windows PowerShell, but you're running on a non-Windows system."
    Write-Info ""
    Write-Info "For Linux distributions, use one of these scripts instead:"
    Write-Info "  - Ubuntu:  sh -c `"`$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/ubuntu.sh)`""
    Write-Info "  - Fedora:  sh -c `"`$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/fedora.sh)`""
    exit 1
}

if ($PSVersionTable.PSVersion.Major -lt 6 -and -not [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    # Windows PowerShell on non-Windows (unlikely, but let's be thorough)
    Write-Err "This script is designed for Windows PowerShell on Windows."
    Write-Info ""
    Write-Info "For Linux distributions, use one of these scripts instead:"
    Write-Info "  - Ubuntu:  sh -c `"`$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/ubuntu.sh)`""
    Write-Info "  - Fedora:  sh -c `"`$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/fedora.sh)`""
    exit 1
}

Write-Info "✓ Detected Windows - continuing with setup..."
#endregion

#region Winget Installation Check
Write-Info "Checking winget availability..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Err "winget is not installed. Please install App Installer from the Microsoft Store."
    exit 1
}
Write-Info "✓ winget is available"
#endregion

#region Install Oh My Posh
Write-Info "Installing Oh My Posh..."
try {
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Info "Oh My Posh is already installed, upgrading..."
        winget upgrade JanDeDobbeleer.OhMyPosh --silent --accept-source-agreements --accept-package-agreements
    } else {
        winget install JanDeDobbeleer.OhMyPosh --silent --accept-source-agreements --accept-package-agreements
    }
    Write-Info "✓ Oh My Posh installed successfully"
} catch {
    Write-Warn "Oh My Posh installation had issues, but continuing..."
}

# Refresh environment variables to pick up Oh My Posh
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
#endregion

#region Install Nerd Fonts
Write-Info "Installing FiraCode Nerd Font..."
try {
    # Oh My Posh has a built-in font installer
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        # Use headless mode to install without TUI
        oh-my-posh font install FiraCode --headless
        Write-Info "✓ FiraCode Nerd Font installed"
    } else {
        Write-Warn "Could not install Nerd Font automatically (oh-my-posh not in PATH yet)"
        Write-Warn "You can manually install it later with: oh-my-posh font install FiraCode --headless"
    }
} catch {
    Write-Warn "Nerd Font installation had issues, you can install it manually later"
    Write-Warn "Run: oh-my-posh font install FiraCode --headless"
}
#endregion

#region Install Terminal-Icons
Write-Info "Installing Terminal-Icons module..."
try {
    if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser -AllowClobber
        Write-Info "✓ Terminal-Icons installed"
    } else {
        Write-Info "Terminal-Icons is already installed"
    }
} catch {
    Write-Warn "Terminal-Icons installation failed, but continuing..."
}
#endregion

#region Install PSReadLine
Write-Info "Ensuring PSReadLine is up to date..."
try {
    $psReadLine = Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
    if ($psReadLine.Version -lt [Version]"2.2.0") {
        Install-Module -Name PSReadLine -Repository PSGallery -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck
        Write-Info "✓ PSReadLine updated"
    } else {
        Write-Info "✓ PSReadLine is up to date"
    }
} catch {
    Write-Warn "PSReadLine update failed, but continuing..."
}
#endregion

#region Install PSFzf
Write-Info "Installing PSFzf module..."
try {
    if (-not (Get-Module -ListAvailable -Name PSFzf)) {
        Install-Module -Name PSFzf -Repository PSGallery -Force -Scope CurrentUser -AllowClobber
        Write-Info "✓ PSFzf installed"
    } else {
        Write-Info "PSFzf is already installed"
    }
} catch {
    Write-Warn "PSFzf installation failed, but continuing..."
}
#endregion

#region Install fzf via winget
Write-Info "Installing fzf..."
try {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        winget install fzf --silent --accept-source-agreements --accept-package-agreements
        Write-Info "✓ fzf installed"
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } else {
        Write-Info "fzf is already installed"
    }
} catch {
    Write-Warn "fzf installation failed, but continuing..."
}
#endregion

#region Install Python 3.14 and uv via winget
Write-Info "Installing Python 3.14..."
try {
    if (-not (Get-Command python3.14 -ErrorAction SilentlyContinue)) {
        winget install Python.Python.3.14 --silent --accept-source-agreements --accept-package-agreements
        Write-Info "✓ Python 3.14 installed"
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } else {
        Write-Info "Python 3.14 is already installed"
    }
} catch {
    Write-Warn "Python 3.14 installation failed, but continuing..."
}

Write-Info "Installing uv (Python package manager)..."
try {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        Write-Info "✓ uv installed"
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } else {
        Write-Info "uv is already installed"
    }
} catch {
    Write-Warn "uv installation failed, but continuing..."
}
#endregion

#region Create PowerShell Profile
Write-Info "Setting up PowerShell profile..."

$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Create Oh My Posh theme configuration
$themeConfig = @{
    '$schema' = 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json'
    'blocks' = @(
        @{
            'type' = 'prompt'
            'alignment' = 'left'
            'segments' = @(
                @{
                    'properties' = @{
                        'prefix' = ' '
                        'style' = 'folder'
                    }
                    'leading_diamond' = ''
                    'trailing_diamond' = ''
                    'foreground' = '#ffffff'
                    'powerline_symbol' = ''
                    'background' = '#ff479c'
                    'type' = 'path'
                    'style' = 'diamond'
                },
                @{
                    'properties' = @{
                        'display_stash_count' = $true
                        'display_status' = $true
                        'display_upstream_icon' = $true
                    }
                    'foreground' = '#193549'
                    'powerline_symbol' = ''
                    'background' = '#fffb38'
                    'type' = 'git'
                    'style' = 'powerline'
                },
                @{
                    'properties' = @{
                        'display_version' = $true
                        'prefix' = ' '
                    }
                    'foreground' = '#ffffff'
                    'powerline_symbol' = ''
                    'background' = '#6CA35E'
                    'type' = 'dotnet'
                    'style' = 'powerline'
                },
                @{
                    'foreground' = '#ffffff'
                    'powerline_symbol' = ''
                    'background' = '#ffff66'
                    'type' = 'root'
                    'style' = 'powerline'
                },
                @{
                    'properties' = @{
                        'always_enabled' = $false
                        'color_background' = $true
                        'display_exit_code' = $false
                        'error_color' = '#f1184c'
                        'prefix' = ' '
                    }
                    'trailing_diamond' = ''
                    'foreground' = '#ffffff'
                    'powerline_symbol' = ''
                    'background' = '#2e9599'
                    'type' = 'exit'
                    'style' = 'powerline'
                }
            )
        }
    )
    'version' = 3
    'final_space' = $true
}

$themeConfigPath = Join-Path $profileDir "ohmyposh.json"
$themeConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $themeConfigPath -Encoding UTF8
Write-Info "✓ Oh My Posh theme configuration created at: $themeConfigPath"

# Create PowerShell profile
$profileContent = @'
# Oh My Posh
$ohmyposhConfig = Join-Path $PSScriptRoot "ohmyposh.json"
if (Test-Path $ohmyposhConfig) {
    oh-my-posh init pwsh --config $ohmyposhConfig | Invoke-Expression
} else {
    oh-my-posh init pwsh | Invoke-Expression
}

# Terminal-Icons
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module -Name Terminal-Icons
}

# PSFzf configuration
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
                    -PSReadlineChordReverseHistory 'Ctrl+r'
}

# PSReadLine configuration
if (Get-Module -ListAvailable -Name PSReadLine) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -MaximumHistoryCount 100000

    # Key bindings
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# Git aliases
function gst { git.exe status -sb $args }
function glo { git.exe log --oneline --decorate $args }
function gd { git.exe diff $args }
function gpr { git.exe pull --rebase $args }
function gdiff { git.exe diff --color=auto --no-index $args }
function gb { git.exe branch $args }
function gba { git.exe branch -a $args }
function gch { git.exe checkout $args }
function gdiffdump {
    $date = Get-Date -Format 'yyyy-MM-dd---HH-mm-ss'
    $branch = git rev-parse --abbrev-ref HEAD
    git.exe diff master > "$date-$branch.diff"
}

# Utility aliases
Set-Alias -Name ll -Value Get-ChildItem
function .. { Set-Location .. }
function ... { Set-Location ../.. }

# WSL shortcut
function wsl-here { wsl.exe --cd $PWD }

'@

Set-Content -Path $PROFILE -Value $profileContent -Encoding UTF8
Write-Info "✓ PowerShell profile created at: $PROFILE"
#endregion

#region Configure Windows Terminal (if exists)
Write-Info "Checking for Windows Terminal..."
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (Test-Path $wtSettingsPath) {
    Write-Info "Windows Terminal detected. Updating settings..."
    try {
        $wtSettings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json

        # Update default profile font
        $fontFace = "FiraCode Nerd Font"

        if ($wtSettings.profiles.defaults) {
            $wtSettings.profiles.defaults | Add-Member -MemberType NoteProperty -Name "font" -Value @{
                "face" = $fontFace
            } -Force
        } else {
            $wtSettings.profiles | Add-Member -MemberType NoteProperty -Name "defaults" -Value @{
                "font" = @{
                    "face" = $fontFace
                }
            } -Force
        }

        $wtSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $wtSettingsPath -Encoding UTF8
        Write-Info "✓ Windows Terminal font configured to use $fontFace"
    } catch {
        Write-Warn "Could not automatically configure Windows Terminal font"
        Write-Warn "You may need to manually set the font to 'FiraCode Nerd Font' in Windows Terminal settings"
    }
} else {
    Write-Warn "Windows Terminal not found at expected location"
}
#endregion

#region Verify Installations
Write-Info ""
Write-Info "Verifying installations..."

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $version = oh-my-posh --version
    Write-Info "✓ Oh My Posh: $version"
} else {
    Write-Err "✗ Oh My Posh installation failed"
}

if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Write-Info "✓ Terminal-Icons module installed"
} else {
    Write-Warn "✗ Terminal-Icons module not found"
}

if (Get-Module -ListAvailable -Name PSReadLine) {
    $version = (Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1).Version
    Write-Info "✓ PSReadLine: $version"
} else {
    Write-Warn "✗ PSReadLine not found"
}

if (Get-Module -ListAvailable -Name PSFzf) {
    Write-Info "✓ PSFzf module installed"
} else {
    Write-Warn "✗ PSFzf module not found"
}

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    Write-Info "✓ fzf installed"
} else {
    Write-Warn "✗ fzf not found"
}

if (Get-Command python3.14 -ErrorAction SilentlyContinue) {
    $version = python3.14 --version
    Write-Info "✓ Python: $version"
} else {
    Write-Warn "✗ Python 3.14 not found"
}

if (Get-Command uv -ErrorAction SilentlyContinue) {
    $version = uv --version
    Write-Info "✓ uv: $version"
} else {
    Write-Warn "✗ uv not found"
}

if (Test-Path $PROFILE) {
    Write-Info "✓ PowerShell profile configured"
} else {
    Write-Err "✗ PowerShell profile creation failed"
}

if (Test-Path $themeConfigPath) {
    Write-Info "✓ Oh My Posh theme configured"
} else {
    Write-Err "✗ Oh My Posh theme creation failed"
}
#endregion

#region Summary
Write-Info ""
Write-Info "=========================================="
Write-Info "Setup completed successfully!"
Write-Info "=========================================="
Write-Info ""
Write-Info "IMPORTANT: Close and reopen Windows Terminal NOW to load the new font!"
Write-Info ""
Write-Info "Next steps:"
Write-Info "1. CLOSE this Windows Terminal window completely (X button or Ctrl+Shift+W)"
Write-Info "2. Reopen Windows Terminal - your beautiful new prompt should appear!"
Write-Info "3. If you see a font warning, Windows Terminal needs to be fully restarted"
Write-Info "   (Close ALL Windows Terminal windows and open a fresh one)"
Write-Info ""
Write-Info "Installed components:"
Write-Info "  - Oh My Posh (prompt theme engine)"
Write-Info "  - FiraCode Nerd Font (for icons and glyphs)"
Write-Info "  - Terminal-Icons (colorful file/folder icons)"
Write-Info "  - PSReadLine (enhanced command-line editing with 100k history)"
Write-Info "  - PSFzf (fuzzy finder integration with Ctrl+T and Ctrl+R)"
Write-Info "  - fzf (command-line fuzzy finder)"
Write-Info "  - Python 3.14"
Write-Info "  - uv (Python package manager)"
Write-Info ""
Write-Info "PSFzf Key Bindings:"
Write-Info "  Ctrl+T - Fuzzy find files/folders in current directory"
Write-Info "  Ctrl+R - Fuzzy search through command history"
Write-Info ""
Write-Info "Available Git aliases:"
Write-Info "  gst    - git status (short)"
Write-Info "  glo    - git log (oneline)"
Write-Info "  gd     - git diff"
Write-Info "  gpr    - git pull --rebase"
Write-Info "  gdiff  - git diff (no-index)"
Write-Info "  gb     - git branch"
Write-Info "  gba    - git branch -a"
Write-Info "  gch    - git checkout"
Write-Info "  gdiffdump - dump diff to file"
Write-Info ""
Write-Info "PowerShell profile: $PROFILE"
Write-Info "Oh My Posh theme: $themeConfigPath"
Write-Info ""
Write-Info "Happy coding!"
#endregion
