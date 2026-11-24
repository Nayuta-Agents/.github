#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$SkipFmt,
    [switch]$SkipSmoke
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "verification.ps1")
$RustRepos = @("core", "shaders", "vrm", "router", "agent", "sdk", "spatial", "nayuta")

Write-Host "Nayuta Multi-Repo Verification & Architectural Guard Suite"
Write-Host "Root: $RootDir"
& (Join-Path $PSScriptRoot "test-verification.ps1")

foreach ($repo in $RustRepos) {
    $repoPath = Join-Path $RootDir $repo
    if (-not (Test-Path $repoPath)) { throw "Missing repository directory: $repoPath" }
    Write-Host "`n>>> [$repo] Running workspace checks..."
    Push-Location $repoPath
    try {
        if (-not $SkipFmt) {
            Invoke-CheckedCargo -Arguments @("fmt", "--all", "--", "--check") | ForEach-Object { Write-Host $_ }
        }
        Invoke-CheckedCargo -Arguments @("clippy", "--workspace", "--all-targets", "--", "-D", "warnings") | ForEach-Object { Write-Host $_ }
        Invoke-CheckedCargo -Arguments @("test", "--workspace") | ForEach-Object { Write-Host $_ }
    }
    finally { Pop-Location }
}

Write-Host "`nRunning 5 Architectural Fitness Guards..."
foreach ($repo in $RustRepos) {
    Invoke-ArchitecturalGuards -Repo $repo -Root $RootDir
}

if (-not $SkipSmoke) {
    Write-Host "`nRunning nayuta-headless mock chat smoke test..."
    Push-Location (Join-Path $RootDir "nayuta")
    try {
        Invoke-CheckedCargo -Arguments @("run", "-q", "-p", "nayuta-headless", "--", "chat", "Halo Nayuta", "--provider", "mock") | ForEach-Object { Write-Host $_ }
    }
    finally { Pop-Location }
    Write-Host "[PASS] nayuta-headless mock chat."
}

Write-Host "`nALL REPOSITORIES, TESTS, AND ARCHITECTURAL GUARDS PASSED WITHOUT CARGO WARNINGS!"
