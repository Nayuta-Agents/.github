#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Branch = "dev",
    [string]$Org = "Nayuta-Agents",
    [string]$Token = $env:GITHUB_TOKEN
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$RepoDescriptions = [ordered]@{
    ".github" = "Organization profile, reusable CI workflows, and workspace scripts for Nayuta"
    "core"    = "Level 0 foundation: canonical types, lossy telemetry bus, config, and IPC protocol"
    "shaders" = "Level 0 WGSL shaders (MToon anime cel-shading, 3D Catmull-Rom spline, postfx bloom)"
    "vrm"     = "Level 0 CPU-only Rust port of @pixiv/three-vrm (VRMC_vrm, SpringBone, LookAt, VRMA)"
    "router"  = "Level 1 high-performance AI API gateway with auto-failover, circuit breaker, and KeyPool"
    "agent"   = "Level 1 autonomous ReAct agent runtime, parallel tools, memory store, and MCP"
    "sdk"     = "Level 1 Rust client SDK, WASM plugin WIT contract, and OpenAPI 3.1 specification"
    "spatial" = "Level 2 3D spatial telemetry scene, wgpu/winit renderer, egui HUD, and audio lip-sync"
    "nayuta"  = "Level 3 flagship 3D desktop app and GPU-free headless CLI/VPS daemon"
    "assets"  = "Git LFS repository for default VRM 1.0 avatars, VRMA animations, and textures"
    "docs"    = "Comprehensive architecture documentation (PRD, Use Cases, DAG, ERD, Flows, ADRs)"
}

if (-not $Token) {
    $credInput = "protocol=https`nhost=github.com`n`n"
    $credOut = $credInput | git credential fill 2>$null
    $match = $credOut | Select-String '^password=(.+)$'
    if ($match) {
        $Token = $match.Matches.Groups[1].Value
    }
}

if ($Token) {
    $headers = @{
        Authorization          = "Bearer $Token"
        Accept                 = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    try {
        $existing = @(Invoke-RestMethod -Uri "https://api.github.com/orgs/$Org/repos?per_page=100" -Headers $headers | ForEach-Object { $_.name })
        foreach ($r in $RepoDescriptions.Keys) {
            if ($existing -notcontains $r) {
                Write-Host "Creating repository $Org/$r on GitHub..." -ForegroundColor Cyan
                $body = @{
                    name         = $r
                    description  = $RepoDescriptions[$r]
                    private      = $false
                    has_issues   = $true
                    has_projects = $false
                    has_wiki     = $false
                } | ConvertTo-Json
                Invoke-RestMethod -Method Post -Uri "https://api.github.com/orgs/$Org/repos" -Headers $headers -Body $body -ContentType "application/json" | Out-Null
            }
        }
    }
    catch {
        Write-Host "Note: Could not auto-create repos via API ($($_.Exception.Message)). Ensure the 11 repos exist in https://github.com/$Org or pass -Token <PAT_WITH_REPO_SCOPE>." -ForegroundColor Yellow
    }
}

foreach ($r in $RepoDescriptions.Keys) {
    $repoPath = Join-Path $RootDir $r
    if (-not (Test-Path $repoPath)) { continue }
    Write-Host ">>> [$r] Pushing branch '$Branch' to origin..." -ForegroundColor Cyan
    git -C $repoPath push -u origin $Branch
}
