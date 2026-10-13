#requires -Version 5.1
# doctor.ps1 -- read-only Windows health check for the Zed dev setup.
#
# Verifies every component install.ps1 deploys (or that a second box is
# expected to have) by resolving each tool from PATH first, then from
# its usual install location, then running its --version equivalent.
# Prints a Check | Result | Detail table with PASS / FAIL / SKIP rows
# (SKIP = optional tool absent, never a failure) and exits 0 only when
# no required check failed.
#
# Standalone by design: no dot-sourcing from install.ps1, no writes, no
# installs, safe to run any time. install.ps1 runs it as a child process
# so the child inherits the parent's refreshed session PATH.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

function Get-CommandOrNull {
    param([Parameter(Mandatory)][string]$Name)
    try {
        $cmd = Get-Command $Name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    } catch { }
    return $null
}

# The python.org stub in WindowsApps is not a real interpreter (it opens
# the Store); treat any WindowsApps path as "not installed".
function Test-WindowsAppsStub {
    param([string]$Path)
    return ($null -ne $Path -and $Path -match '\\WindowsApps\\')
}

function Find-Exe {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string[]]$Candidates = @()
    )
    $path = Get-CommandOrNull $Name
    if ($path -and -not (Test-WindowsAppsStub $path)) { return $path }
    foreach ($c in $Candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

function Invoke-ToolCapture {
    param(
        [Parameter(Mandatory)][string]$ExePath,
        [string[]]$ToolArgs = @('--version')
    )
    if (-not $ExePath) { return $null }
    try {
        $out = & $ExePath @ToolArgs 2>&1
        $lines = @($out | Where-Object { "$_" -match '\S' } | ForEach-Object { "$_" })
        if (@($lines).Count -gt 0) { return ($lines[0].Trim()) }
    } catch { }
    return $null
}

function Get-ProgramFilesx86 {
    $pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if (-not $pf86) { $pf86 = $env:ProgramFiles }
    return $pf86
}

$Script:Rows = New-Object System.Collections.Generic.List[object]

function Add-Row {
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][string]$Result,
        [string]$Detail = ''
    )
    $Script:Rows.Add([pscustomobject]@{ Check = $Check; Result = $Result; Detail = $Detail })
}

# A plain tool check: resolve exe, run --version, PASS/FAIL.
function Test-Tool {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$Candidates = @(),
        [string[]]$ToolArgs = @('--version'),
        [switch]$Optional
    )
    $exePath = Find-Exe -Name $Exe -Candidates $Candidates
    if (-not $exePath) {
        if ($Optional) {
            Add-Row $Name 'SKIP' "not found (optional)"
        } else {
            Add-Row $Name 'FAIL' "$Exe not found on PATH"
        }
        return
    }
    $ver = Invoke-ToolCapture -ExePath $exePath -ToolArgs $ToolArgs
    if ($ver) {
        Add-Row $Name 'PASS' $ver
    } else {
        Add-Row $Name 'FAIL' "found at $exePath but failed to run $(($ToolArgs -join ' '))"
    }
}

# ---------------------------------------------------------------------------
# checks
# ---------------------------------------------------------------------------

Write-Host "==> Zed dev setup health check (scripts/doctor.ps1)" -ForegroundColor Cyan
Write-Host ""

$zedCandidates = @(
    (Join-Path $env:ProgramFiles 'Zed\zed.exe'),
    (Join-Path $env:ProgramFiles 'Zed Preview\zed.exe'),
    (Join-Path (Get-ProgramFilesx86) 'Zed\zed.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Zed\zed.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Zed Preview\zed.exe')
)
Test-Tool -Name 'Zed' -Exe 'zed' -Candidates $zedCandidates

Test-Tool -Name 'Git' -Exe 'git' -Candidates @((Join-Path $env:ProgramFiles 'Git\cmd\git.exe'))

$llvmBin = Join-Path $env:ProgramFiles 'LLVM\bin'
Test-Tool -Name 'Clang' -Exe 'clang' -Candidates @((Join-Path $llvmBin 'clang.exe'))
Test-Tool -Name 'Clangd' -Exe 'clangd' -Candidates @((Join-Path $llvmBin 'clangd.exe'))
Test-Tool -Name 'ClangFormat' -Exe 'clang-format' -Candidates @((Join-Path $llvmBin 'clang-format.exe'))

Test-Tool -Name 'CMake' -Exe 'cmake' -Candidates @((Join-Path $env:ProgramFiles 'CMake\bin\cmake.exe'))
Test-Tool -Name 'Ninja' -Exe 'ninja' -ToolArgs @('--version') -Candidates @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\ninja.exe')
)

# MSVC Build Tools (or a full VS with the C++ workload): vswhere is the
# supported detection route; missing vswhere means no VS Installer at all.
$vswhere = Join-Path (Get-ProgramFilesx86) 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path -LiteralPath $vswhere) {
    $vsPath = (& $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath) 2>$null
    $vsPath = if ($vsPath) { @($vsPath)[0] } else { $null }
    if ($vsPath) {
        $vsVersion = (& $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion) 2>$null
        $vsVersion = if ($vsVersion) { @($vsVersion)[0] } else { '' }
        Add-Row 'MSVC' 'PASS' "VC tools $vsVersion at $vsPath"
    } else {
        Add-Row 'MSVC' 'FAIL' 'no Visual Studio product with the C++ workload (VC.Tools.x86.x64)'
    }
} else {
    Add-Row 'MSVC' 'FAIL' 'vswhere.exe not found -- no Visual Studio installer on this machine'
}

$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
Test-Tool -Name 'Rustup' -Exe 'rustup' -Candidates @((Join-Path $cargoBin 'rustup.exe'))
Test-Tool -Name 'Rustc' -Exe 'rustc' -Candidates @((Join-Path $cargoBin 'rustc.exe'))
Test-Tool -Name 'Cargo' -Exe 'cargo' -Candidates @((Join-Path $cargoBin 'cargo.exe'))

# The MSVC target rustup installs (required to link on Windows).
$rustup = Find-Exe -Name 'rustup' -Candidates @((Join-Path $cargoBin 'rustup.exe'))
if ($rustup) {
    $targets = @(& $rustup target list --toolchain stable-x86_64-pc-windows-msvc --installed 2>$null | ForEach-Object { "$_" })
    if ($targets -match 'x86_64-pc-windows-msvc') {
        Add-Row 'Rust msvc target' 'PASS' 'x86_64-pc-windows-msvc installed for stable'
    } else {
        Add-Row 'Rust msvc target' 'FAIL' "run: rustup target add --toolchain stable-x86_64-pc-windows-msvc x86_64-pc-windows-msvc"
    }
} else {
    Add-Row 'Rust msvc target' 'FAIL' 'rustup not found'
}

Test-Tool -Name 'Python' -Exe 'python' -Candidates @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'),
    (Join-Path $env:ProgramFiles 'Python313\python.exe')
)
$wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
Test-Tool -Name 'uv' -Exe 'uv' -Candidates @((Join-Path $wingetLinks 'uv.exe'))
Test-Tool -Name 'Ruff' -Exe 'ruff' -Candidates @((Join-Path $wingetLinks 'ruff.exe'))

Test-Tool -Name 'LuaJIT' -Exe 'luajit' -ToolArgs @('-v') -Candidates @(
    (Join-Path $env:ProgramFiles 'LuaJIT\bin\luajit.exe'),
    (Join-Path $env:ProgramFiles 'LuaJIT\luajit.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\LuaJIT\luajit.exe')
)
Test-Tool -Name 'lua-language-server' -Exe 'lua-language-server' -Candidates @((Join-Path $wingetLinks 'lua-language-server.exe'))
Test-Tool -Name 'StyLua' -Exe 'stylua' -Candidates @((Join-Path $wingetLinks 'stylua.exe'))
Test-Tool -Name 'Luacheck' -Exe 'luacheck' -Optional -Candidates @(
    (Join-Path $env:LOCALAPPDATA 'Programs\luacheck\luacheck.exe')
)

# Deployed config files (%APPDATA%\Zed via install.ps1).
$zedDir = Join-Path $env:APPDATA 'Zed'
$configFiles = @('settings.json', 'keymap.json', 'tasks.json', 'debug.json')
foreach ($f in $configFiles) {
    $p = Join-Path $zedDir $f
    if (Test-Path -LiteralPath $p) {
        Add-Row "Zed config: $f" 'PASS' $p
    } else {
        Add-Row "Zed config: $f" 'FAIL' "missing from $zedDir (run install.ps1, or -Skip config was used)"
    }
}
$pywalTheme = Join-Path $zedDir 'themes\pywal.json'
if (Test-Path -LiteralPath $pywalTheme) {
    Add-Row 'Zed theme: Pywal' 'PASS' $pywalTheme
} else {
    Add-Row 'Zed theme: Pywal' 'FAIL' "missing -- settings.json selects theme 'Pywal'; install.ps1 seeds it from the mocha preset"
}
$snippetsDir = Join-Path $zedDir 'snippets'
if (Test-Path -LiteralPath $snippetsDir) {
    $n = @(Get-ChildItem -LiteralPath $snippetsDir -Filter '*.json' -ErrorAction SilentlyContinue).Count
    Add-Row 'Zed snippets' 'PASS' "$n snippet file(s) in $snippetsDir"
} else {
    Add-Row 'Zed snippets' 'FAIL' "missing snippets dir under $zedDir"
}

# ---------------------------------------------------------------------------
# table + exit code
# ---------------------------------------------------------------------------

Write-Host ""
$checkWidth = 24
$resultWidth = 8
foreach ($row in $Script:Rows) {
    $checkCell = $row.Check.PadRight($checkWidth)
    $resultCell = $row.Result.PadRight($resultWidth)
    $color = 'Gray'
    if ($row.Result -eq 'PASS') { $color = 'Green' }
    elseif ($row.Result -eq 'FAIL') { $color = 'Red' }
    elseif ($row.Result -eq 'SKIP') { $color = 'Yellow' }
    $line = "$checkCell$resultCell$($row.Detail)"
    if ($line.Length -gt 110) { $line = $line.Substring(0, 110) + '...' }
    Write-Host $line -ForegroundColor $color
}

$fails = @($Script:Rows | Where-Object { $_.Result -eq 'FAIL' }).Count
$passes = @($Script:Rows | Where-Object { $_.Result -eq 'PASS' }).Count
$skips = @($Script:Rows | Where-Object { $_.Result -eq 'SKIP' }).Count
Write-Host ""
if ($fails -eq 0) {
    Write-Host "==> DOCTOR: PASS ($passes passed, $skips skipped)" -ForegroundColor Green
    exit 0
}
Write-Host "==> DOCTOR: FAIL ($fails failed, $passes passed, $skips skipped)" -ForegroundColor Red
exit 1
