#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Org,

    [switch]$UseSsh
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

Write-Host "Updating <ORG> placeholder to '$Org' and configuring git remotes..." -ForegroundColor Cyan

foreach ($repo in $AllRepos) {
    $repoPath = Join-Path $RootDir $repo
    if (-not (Test-Path $repoPath)) { continue }

    # Replace <ORG> in Cargo.toml, book.toml, Markdown, and workflow YAML files
    $files = Get-ChildItem -Path $repoPath -Recurse -File -Include "Cargo.toml","book.toml","*.md","*.yml","*.yaml"
    foreach ($f in $files) {
        $content = Get-Content -Path $f.FullName -Raw
        if ($content -match '<ORG>') {
            $updated = $content -replace '<ORG>', $Org
            Set-Content -Path $f.FullName -Value $updated -NoNewline
            Write-Host "  Updated placeholder in: $($f.FullName)"
        }
    }

    # Configure git remote origin
    $remoteUrl = if ($UseSsh) {
        "git@github.com:$Org/$repo.git"
    } else {
        "https://github.com/$Org/$repo.git"
    }

    Push-Location $repoPath
    try {
        $existing = git remote 2>$null
        if ($existing -contains "origin") {
            git remote set-url origin $remoteUrl
        } else {
            git remote add origin $remoteUrl
        }
        Write-Host "  [$repo] origin -> $remoteUrl" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

Write-Host "`nDone! All 11 repositories are linked to github.com/$Org." -ForegroundColor Green
