#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Branch = "dev"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$AllRepos = @(
    ".github",
    "core",
    "shaders",
    "vrm",
    "router",
    "agent",
    "sdk",
    "spatial",
    "nayuta",
    "assets",
    "docs"
)

foreach ($r in $AllRepos) {
    $repoPath = Join-Path $RootDir $r
    if (-not (Test-Path $repoPath)) { continue }
    Write-Host ">>> [$r] Pushing branch '$Branch' to origin (https://github.com/Nayuta-Agents/$r.git)..." -ForegroundColor Cyan
    git -C $repoPath push -u origin $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "git push failed for $r"
    }
}

Write-Host "`nAll 11 repositories pushed to origin/$Branch successfully!" -ForegroundColor Green
