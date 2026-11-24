#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/verification.sh"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_OUTPUT=""
FIXTURE_STATUS=0
EXPECT_WORKSPACE=0

cargo() {
  if [[ "$EXPECT_WORKSPACE" -eq 1 && " $* " != *" --workspace "* ]]; then
    printf 'fixture: expected a whole-workspace dependency tree\n' >&2
    return 42
  fi
  printf '%s\n' "$FIXTURE_OUTPUT"
  return "$FIXTURE_STATUS"
}

expect_pass() {
  local label="$1"
  shift
  "$@" >/dev/null
  printf '[PASS] %s\n' "$label"
}

expect_failure() {
  local label="$1" expected="$2" output status
  shift 2
  if output="$("$@" 2>&1)"; then
    printf '[FAIL] %s unexpectedly passed\n' "$label" >&2
    return 1
  else
    status=$?
  fi
  if [[ "$status" -ne "$expected" ]]; then
    printf '[FAIL] %s returned %s, expected %s: %s\n' "$label" "$status" "$expected" "$output" >&2
    return 1
  fi
  printf '[PASS] %s\n' "$label"
}

EXPECT_WORKSPACE=1
FIXTURE_OUTPUT=$'nayuta-core-config v0.1.0 []\nnayuta-core-telemetry v0.1.0 []\n└── tokio v1.53.3 [sync]'
expect_pass 'all core roots with sync-only Tokio' run_architectural_guards core "$ROOT_DIR"
FIXTURE_OUTPUT=$'nayuta-core-config v0.1.0 []\n└── reqwest v0.12.28 []'
expect_failure 'HTTP dependency in core-config' 1 run_architectural_guards core "$ROOT_DIR"
for feature in time rt rt-multi-thread macros net; do
  FIXTURE_OUTPUT="└── tokio v1.53.3 [sync,$feature]"
  expect_failure "forbidden Tokio feature $feature" 1 run_architectural_guards core "$ROOT_DIR"
done
FIXTURE_OUTPUT=$'nayuta-vrm-core v0.1.0\n└── wgpu v30.0.1'
expect_failure 'GPU dependency in VRM' 1 run_architectural_guards vrm "$ROOT_DIR"
FIXTURE_OUTPUT=$'nayuta-agent-runtime v0.1.0\n└── nayuta-router-client v0.1.0'
expect_failure 'router dependency in agent' 1 run_architectural_guards agent "$ROOT_DIR"
EXPECT_WORKSPACE=0
FIXTURE_OUTPUT=$'nayuta-headless v0.1.0\n└── nayuta-spatial-avatar v0.1.0'
expect_failure 'GPU bridge in headless' 1 run_headless_guard "$ROOT_DIR"
EXPECT_WORKSPACE=1
FIXTURE_OUTPUT=$'wgpu v30.0.1\nwgpu v30.0.1 (*)\nwinit v0.30.13\nwinit v0.30.13 (*)'
expect_pass 'repeated singleton GPU versions' run_graphics_guard spatial "$ROOT_DIR"
FIXTURE_OUTPUT=$'wgpu v30.0.1\nwgpu v29.0.1\nwinit v0.30.13'
expect_failure 'two wgpu versions' 1 run_graphics_guard spatial "$ROOT_DIR"
FIXTURE_OUTPUT=$'wgpu v30.0.1\nwinit v0.30.13\nwinit v0.31.0'
expect_failure 'two winit versions' 1 run_graphics_guard spatial "$ROOT_DIR"
EXPECT_WORKSPACE=0
FIXTURE_OUTPUT='cargo fixture failed'
FIXTURE_STATUS=37
for repo in core vrm agent spatial nayuta; do
  expect_failure "cargo tree failure in $repo" 37 run_architectural_guards "$repo" "$ROOT_DIR"
done
FIXTURE_STATUS=0
FIXTURE_OUTPUT='warning: unused workspace dependency `unused`'
expect_failure 'successful Cargo command with manifest warning' 1 checked_cargo check --workspace
expect_failure 'tree with manifest warning' 1 run_architectural_guards core "$ROOT_DIR"
FIXTURE_STATUS=13
expect_failure 'Cargo failure preserves its exit status' 13 checked_cargo test --workspace
printf 'All Bash verification fixtures passed.\n'
