#Requires -Version 5.1
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "verification.ps1")
$RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:FixtureLines = @()
$script:FixtureStatus = 0
$script:ExpectWorkspace = $false

function cargo {
    if ($script:ExpectWorkspace -and "--workspace" -notin $args) {
        $global:LASTEXITCODE = 42
        Write-Output "fixture: expected a whole-workspace dependency tree"
        return
    }
    $global:LASTEXITCODE = $script:FixtureStatus
    $script:FixtureLines | ForEach-Object { Write-Output $_ }
}

function Assert-Passes {
    param([string]$Label, [scriptblock]$Action)
    & $Action | Out-Null
    Write-Host "[PASS] $Label"
}

function Assert-Fails {
    param([string]$Label, [string]$Expected, [scriptblock]$Action)
    $failed = $false
    try { & $Action | Out-Null }
    catch {
        if ($_.Exception.Message -notmatch $Expected) {
            throw ("{0}: unexpected failure: {1}" -f $Label, $_.Exception.Message)
        }
        $failed = $true
    }
    if (-not $failed) { throw "$Label unexpectedly passed" }
    Write-Host "[PASS] $Label"
}

$script:ExpectWorkspace = $true
$script:FixtureLines = @("nayuta-core-config v0.1.0 []", "tokio v1.53.3 [sync]")
Assert-Passes "all core roots with sync-only Tokio" { Invoke-ArchitecturalGuards -Repo core -Root $RootDir }
$script:FixtureLines = @("nayuta-core-config v0.1.0 []", "  reqwest v0.12.28 []")
Assert-Fails "HTTP dependency in core-config" "GUARD-01" { Invoke-ArchitecturalGuards -Repo core -Root $RootDir }
foreach ($feature in @("time", "rt", "rt-multi-thread", "macros", "net")) {
    $script:FixtureLines = @("tokio v1.53.3 [sync,$feature]")
    Assert-Fails "forbidden Tokio feature $feature" "GUARD-01" { Invoke-ArchitecturalGuards -Repo core -Root $RootDir }
}
$script:FixtureLines = @("nayuta-vrm-core v0.1.0", "  wgpu v30.0.1")
Assert-Fails "GPU dependency in VRM" "GUARD-02" { Invoke-ArchitecturalGuards -Repo vrm -Root $RootDir }
$script:FixtureLines = @("nayuta-agent-runtime v0.1.0", "  nayuta-router-client v0.1.0")
Assert-Fails "router dependency in agent" "GUARD-03" { Invoke-ArchitecturalGuards -Repo agent -Root $RootDir }
$script:ExpectWorkspace = $false
$script:FixtureLines = @("nayuta-headless v0.1.0", "  nayuta-spatial-avatar v0.1.0")
Assert-Fails "GPU bridge in headless" "GUARD-04" { Invoke-HeadlessGuard -Root $RootDir }
$script:ExpectWorkspace = $true
$script:FixtureLines = @("wgpu v30.0.1", "wgpu v30.0.1 (*)", "winit v0.30.13", "winit v0.30.13 (*)")
Assert-Passes "repeated singleton GPU versions" { Invoke-GraphicsGuard -Repo spatial -Root $RootDir }
$script:FixtureLines = @("wgpu v30.0.1", "wgpu v29.0.1", "winit v0.30.13")
Assert-Fails "two wgpu versions" "GUARD-05" { Invoke-GraphicsGuard -Repo spatial -Root $RootDir }
$script:FixtureLines = @("wgpu v30.0.1", "winit v0.30.13", "winit v0.31.0")
Assert-Fails "two winit versions" "GUARD-05" { Invoke-GraphicsGuard -Repo spatial -Root $RootDir }
$script:ExpectWorkspace = $false
$script:FixtureStatus = 37
$script:FixtureLines = @("cargo fixture failed")
foreach ($repo in @("core", "vrm", "agent", "spatial", "nayuta")) {
    Assert-Fails "cargo tree failure in $repo" "Cargo exited with code 37" { Invoke-ArchitecturalGuards -Repo $repo -Root $RootDir }
}
$script:FixtureStatus = 0
$script:FixtureLines = @('warning: unused workspace dependency `unused`')
Assert-Fails "successful Cargo command with manifest warning" "Cargo emitted warnings" { Invoke-CheckedCargo -Arguments @("check", "--workspace") }
Assert-Fails "tree with manifest warning" "Cargo emitted warnings" { Invoke-ArchitecturalGuards -Repo core -Root $RootDir }
$script:FixtureStatus = 13
Assert-Fails "Cargo failure preserves its exit status" "Cargo exited with code 13" { Invoke-CheckedCargo -Arguments @("test", "--workspace") }
$global:LASTEXITCODE = 0
Write-Host "All PowerShell verification fixtures passed."
