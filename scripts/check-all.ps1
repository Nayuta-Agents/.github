#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$SkipFmt,
    [switch]$SkipSmoke
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$RustRepos = @(
    "core",
    "shaders",
    "vrm",
    "router",
    "agent",
    "sdk",
    "spatial",
    "nayuta"
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Nayuta Multi-Repo Verification & Architectural Guard Suite" -ForegroundColor Cyan
Write-Host " Root: $RootDir" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

foreach ($repo in $RustRepos) {
    $repoPath = Join-Path $RootDir $repo
    if (-not (Test-Path $repoPath)) {
        throw "Missing repository directory: $repoPath"
    }

    Write-Host "`n>>> [$repo] Running workspace checks..." -ForegroundColor Yellow
    Push-Location $repoPath
    try {
        if (-not $SkipFmt) {
            Write-Host "  [1/3] cargo fmt --all -- --check"
            cargo fmt --all -- --check
            if ($LASTEXITCODE -ne 0) { throw "cargo fmt failed in $repo" }
        }

        Write-Host "  [2/3] cargo clippy --workspace --all-targets -- -D warnings"
        cargo clippy --workspace --all-targets -- -D warnings
        if ($LASTEXITCODE -ne 0) { throw "cargo clippy failed in $repo" }

        Write-Host "  [3/3] cargo test --workspace"
        cargo test --workspace
        if ($LASTEXITCODE -ne 0) { throw "cargo test failed in $repo" }
    }
    finally {
        Pop-Location
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " Running 5 Architectural Fitness Guards (cargo tree)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# GUARD-01: core must not pull axum, reqwest, wgpu, winit, egui, or tokio rt
Push-Location (Join-Path $RootDir "core")
try {
    $coreTree = cargo tree -p nayuta-core-telemetry -e normal -f "{p} [{f}]"
    $forbiddenCore = $coreTree | Select-String -Pattern '(^|\s)(axum|reqwest|hyper|wgpu|winit|egui)\s|tokio v[^\[]*\[[^\]]*\brt\b'
    if ($forbiddenCore) {
        throw "GUARD-01 VIOLATION in core: forbidden dependency detected:`n$($forbiddenCore -join "`n")"
    }
    Write-Host "  [PASS] GUARD-01: nayuta-core-* is free of HTTP/GPU/tokio-rt dependencies." -ForegroundColor Green
}
finally {
    Pop-Location
}

# GUARD-02: vrm must be 100% CPU-only (no wgpu, winit, egui, nayuta-shader-*)
Push-Location (Join-Path $RootDir "vrm")
try {
    $vrmTree = cargo tree --workspace -e normal
    $forbiddenVrm = $vrmTree | Select-String -Pattern '(^|\s)(wgpu|winit|egui|nayuta-shader-)'
    if ($forbiddenVrm) {
        throw "GUARD-02 VIOLATION in vrm: GPU/window dependency detected:`n$($forbiddenVrm -join "`n")"
    }
    Write-Host "  [PASS] GUARD-02: nayuta-vrm-* is 100% CPU-only." -ForegroundColor Green
}
finally {
    Pop-Location
}

# GUARD-03: agent must not depend on router, wgpu, or winit
Push-Location (Join-Path $RootDir "agent")
try {
    $agentTree = cargo tree --workspace -e normal
    $forbiddenAgent = $agentTree | Select-String -Pattern '(^|\s)(nayuta-router-|axum|wgpu|winit)'
    if ($forbiddenAgent) {
        throw "GUARD-03 VIOLATION in agent: direct router/GPU dependency detected:`n$($forbiddenAgent -join "`n")"
    }
    Write-Host "  [PASS] GUARD-03: nayuta-agent-* is decoupled from nayuta-router-*." -ForegroundColor Green
}
finally {
    Pop-Location
}

# GUARD-04: nayuta-headless must not pull wgpu, winit, egui, spatial, or shaders
Push-Location (Join-Path $RootDir "nayuta")
try {
    $headlessTree = cargo tree -p nayuta-headless -e normal
    $forbiddenHeadless = $headlessTree | Select-String -Pattern '(^|\s)(wgpu|winit|egui|nayuta-spatial-|nayuta-shader-)'
    if ($forbiddenHeadless) {
        throw "GUARD-04 VIOLATION in nayuta-headless: GPU/window dependency detected:`n$($forbiddenHeadless -join "`n")"
    }
    Write-Host "  [PASS] GUARD-04: nayuta-headless is 100% GPU-free (VPS ready)." -ForegroundColor Green

    # GUARD-05: single version of wgpu and winit in nayuta workspace
    $dupTree = cargo tree -d
    $dupGraphics = $dupTree | Select-String -Pattern '^(wgpu|winit) v'
    if ($dupGraphics) {
        throw "GUARD-05 VIOLATION: duplicate wgpu or winit versions detected:`n$($dupGraphics -join "`n")"
    }
    Write-Host "  [PASS] GUARD-05: single unified version of wgpu & winit across workspace." -ForegroundColor Green

    if (-not $SkipSmoke) {
        Write-Host "`n>>> Running Smoke Test: nayuta-headless chat..." -ForegroundColor Yellow
        $smokeOut = cargo run -q -p nayuta-headless -- chat "Halo Nayuta" --provider mock
        if ($LASTEXITCODE -ne 0) { throw "nayuta-headless chat smoke test failed" }
        Write-Host $smokeOut
        Write-Host "  [PASS] Smoke Test: nayuta-headless chat streamed successfully." -ForegroundColor Green
    }
}
finally {
    Pop-Location
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " ALL REPOSITORIES, TESTS, AND ARCHITECTURAL GUARDS PASSED!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
