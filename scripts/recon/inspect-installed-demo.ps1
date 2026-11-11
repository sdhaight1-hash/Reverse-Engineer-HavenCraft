# Analyze an already installed, lawfully obtained HavenCraft Demo with REA.
# It never executes the game, extracts proprietary assets or modifies the installation.
#
# Requires the official REA CLI ('rea') to already be installed and on PATH.
# REA documentation: https://github.com/morluto/rea
#
# Example from PowerShell:
# .\scripts\recon\inspect-installed-demo.ps1 -GameDir "C:\Program Files (x86)\Steam\steamapps\common\HavenCraft Demo"
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$GameDir,

    [string]$ReportDir = (Join-Path $env:LOCALAPPDATA "ReverseHavenCraft\recon")
)

$ErrorActionPreference = "Stop"

$source = (Resolve-Path -LiteralPath $GameDir).Path
if (-not (Test-Path -LiteralPath (Join-Path $source "HavenCraft.exe") -PathType Leaf)) {
    throw "HavenCraft.exe not found. Select the installed demo's root directory."
}
$rea = Get-Command rea -ErrorAction SilentlyContinue
if (-not $rea) {
    throw "REA CLI was not found. Obtain it from https://github.com/morluto/rea and confirm 'rea --version' works."
}

$target = [System.IO.Path]::GetFullPath($ReportDir)
if ($target.TrimEnd('\') -eq $source.TrimEnd('\')) {
    throw "Report directory must be outside the game installation."
}
New-Item -ItemType Directory -Force -Path $target | Out-Null

# Store complete REA evidence locally. It can contain paths and internal metadata;
# NEVER commit it or upload it to the public GitHub repository.
$desktop = Join-Path $target "private-desktop-summary.json"
$evidence = Join-Path $target "private-desktop-evidence.json"
Write-Host "Inspecting installed desktop application (read-only) ..."
& $rea.Source inspect-desktop-application $source --detail summary --evidence_output $evidence --json |
    Out-File -FilePath $desktop -Encoding utf8
if ($LASTEXITCODE -ne 0) {
    throw "REA desktop inspection failed with exit code $LASTEXITCODE; see $desktop"
}

$assemblies = Get-ChildItem -LiteralPath $source -Filter "Assembly-CSharp.dll" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '[\\/]Managed[\\/]' }
$metadata = Get-ChildItem -LiteralPath $source -Filter "global-metadata.dat" -Recurse -File -ErrorAction SilentlyContinue
$gameAssembly = Get-ChildItem -LiteralPath $source -Filter "GameAssembly.dll" -Recurse -File -ErrorAction SilentlyContinue

# Managed code identity can be inspected by REA without launching the game.
if ($assemblies.Count -gt 0) {
    Write-Host "Managed game assembly found; inspecting metadata without starting HavenCraft ..."
    $managedPath = Join-Path $target "private-managed-evidence.json"
    & $rea.Source inspect-managed-artifact $assemblies[0].FullName --json |
        Out-File -FilePath $managedPath -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        throw "REA managed assembly inspection failed with exit code $LASTEXITCODE; see $managedPath"
    }
}

$interesting = @("HavenCraft.exe", "UnityPlayer.dll", "GameAssembly.dll", "Assembly-CSharp.dll", "global-metadata.dat")
$fingerprints = @(
    Get-ChildItem -LiteralPath $source -Recurse -File |
    Where-Object { $interesting -contains $_.Name } |
    ForEach-Object {
        [PSCustomObject]@{
            filename = $_.Name
            size_bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
)

$summary = [PSCustomObject]@{
    tool = "REA local static inspection"
    game = "HavenCraft Demo"
    inspection_date_utc = [DateTime]::UtcNow.ToString("o")
    detected_unity_mono_game_assembly = ($assemblies.Count -gt 0)
    detected_unity_il2cpp_layout = (($gameAssembly.Count -gt 0) -and ($metadata.Count -gt 0))
    candidate_only = $true
    selected_binary_fingerprints = $fingerprints
    evidence_files_are_private = $true
    evidence_note = "No runtime observation or source equivalence established."
}
$summaryPath = Join-Path $target "shareable-install-fingerprint.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host "Inspection complete. Local report directory: $target"
Write-Host "Shareable metadata: $summaryPath"
Write-Host "Keep all private-* files local; do not commit game files or raw REA evidence."
