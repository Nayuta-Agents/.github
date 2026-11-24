#Requires -Version 5.1

function Invoke-CheckedCargo {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    Get-Command cargo -ErrorAction Stop | Out-Null
    $previousPreference = $ErrorActionPreference
    $previousColor = $env:CARGO_TERM_COLOR
    try {
        $ErrorActionPreference = "Continue"
        $env:CARGO_TERM_COLOR = "never"
        $lines = @(& cargo @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $status = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
        $env:CARGO_TERM_COLOR = $previousColor
    }
    if ($status -ne 0) {
        $lines | ForEach-Object { Write-Host $_ }
        throw ("Cargo exited with code {0}: cargo {1}" -f $status, ($Arguments -join " "))
    }
    if ($lines | Where-Object { $_ -match '^warning:' }) {
        $lines | ForEach-Object { Write-Host $_ }
        throw ("Cargo emitted warnings: cargo {0}" -f ($Arguments -join " "))
    }
    return $lines
}

function Assert-DependencyGuard {
    param([string]$Guard, [string]$Pattern, [string[]]$Tree)

    foreach ($line in $Tree) {
        if ($line -match $Pattern) {
            throw ("{0}: forbidden dependency: {1}" -f $Guard, $line)
        }
    }
}

function Invoke-CoreGuard {
    param([string]$Root)

    $tree = @(Invoke-CheckedCargo -Arguments @(
        "tree", "--manifest-path", (Join-Path $Root "core/Cargo.toml"),
        "--workspace", "-e", "normal", "-f", "{p} [{f}]"
    ))
    Assert-DependencyGuard -Guard "GUARD-01" -Pattern '(^|\s)(axum|reqwest|hyper|wgpu|winit|egui)\s' -Tree $tree
    foreach ($line in $tree) {
        if ($line -match '(^|\s)tokio\sv[^\[]*\[(?<features>[^\]]*)\]') {
            foreach ($feature in $Matches.features.Split(',')) {
                $feature = $feature.Trim()
                if ($feature -and $feature -ne "sync") {
                    throw ("GUARD-01: forbidden Tokio feature {0}: {1}" -f $feature, $line)
                }
            }
        }
    }
    Write-Host "[PASS] GUARD-01: all core crates are HTTP/GPU-free and Tokio sync-only."
}

function Invoke-HeadlessGuard {
    param([string]$Root)

    $tree = @(Invoke-CheckedCargo -Arguments @(
        "tree", "--manifest-path", (Join-Path $Root "nayuta/Cargo.toml"),
        "-p", "nayuta-headless", "-e", "normal"
    ))
    Assert-DependencyGuard -Guard "GUARD-04" -Pattern '(^|\s)(wgpu|winit|egui|nayuta-spatial-|nayuta-shader-)' -Tree $tree
    Write-Host "[PASS] GUARD-04: nayuta-headless is GPU/window-free."
}

function Invoke-GraphicsGuard {
    param([string]$Repo, [string]$Root)

    $tree = @(Invoke-CheckedCargo -Arguments @(
        "tree", "--manifest-path", (Join-Path $Root "$Repo/Cargo.toml"),
        "--workspace", "-e", "normal", "--prefix", "none"
    ))
    $versions = @{}
    foreach ($line in $tree) {
        if ($line -match '^(wgpu|winit)\s+(\S+)') {
            $package = $Matches[1]
            $version = $Matches[2]
            if ($versions.ContainsKey($package) -and $versions[$package] -ne $version) {
                throw ("GUARD-05: multiple {0} versions in {1}: {2}, {3}" -f $package, $Repo, $versions[$package], $version)
            }
            $versions[$package] = $version
        }
    }
    Write-Host "[PASS] GUARD-05: single wgpu/winit versions in $Repo."
}

function Invoke-ArchitecturalGuards {
    param([string]$Repo, [string]$Root)

    switch ($Repo) {
        "core" { Invoke-CoreGuard -Root $Root; return }
        "vrm" { $guard = "GUARD-02"; $pattern = '(^|\s)(wgpu|winit|egui|nayuta-shader-)' }
        "agent" { $guard = "GUARD-03"; $pattern = '(^|\s)(nayuta-router-|axum|wgpu|winit)' }
        "spatial" { Invoke-GraphicsGuard -Repo $Repo -Root $Root; return }
        "nayuta" {
            Invoke-HeadlessGuard -Root $Root
            Invoke-GraphicsGuard -Repo $Repo -Root $Root
            return
        }
        { $_ -in @("shaders", "router", "sdk") } { return }
        default { throw "Unknown Rust repository: $Repo" }
    }
    $tree = @(Invoke-CheckedCargo -Arguments @(
        "tree", "--manifest-path", (Join-Path $Root "$Repo/Cargo.toml"), "--workspace", "-e", "normal"
    ))
    Assert-DependencyGuard -Guard $guard -Pattern $pattern -Tree $tree
    Write-Host "[PASS] ${guard}: dependency boundary holds in $Repo."
}
