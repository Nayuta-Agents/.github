#!/usr/bin/env bash
set -euo pipefail

SKIP_FMT=0
SKIP_SMOKE=0

usage() {
  printf '%s\n' \
    'Usage: check-all.sh [--skip-fmt] [--skip-smoke] [-h|--help]' \
    '' \
    '  --skip-fmt     Skip cargo fmt --all -- --check' \
    '  --skip-smoke   Skip the nayuta-headless mock chat smoke test' \
    '  -h, --help     Show this help message'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-fmt) SKIP_FMT=1; shift ;;
    --skip-smoke) SKIP_SMOKE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/.github/scripts/verification.sh"
RUST_REPOS=(core shaders vrm router agent sdk spatial nayuta)

printf 'Nayuta Multi-Repo Verification & Architectural Guard Suite\nRoot: %s\n' "$ROOT_DIR"
bash "$ROOT_DIR/.github/scripts/test-verification.sh"

for repo in "${RUST_REPOS[@]}"; do
  repo_path="$ROOT_DIR/$repo"
  if [[ ! -d "$repo_path" ]]; then
    printf 'Missing repository directory: %s\n' "$repo_path" >&2
    exit 1
  fi
  printf '\n>>> [%s] Running workspace checks...\n' "$repo"
  (
    cd "$repo_path"
    if [[ "$SKIP_FMT" -eq 0 ]]; then
      checked_cargo fmt --all -- --check
    fi
    checked_cargo clippy --workspace --all-targets -- -D warnings
    checked_cargo test --workspace
  )
done

printf '\nRunning 5 Architectural Fitness Guards...\n'
for repo in "${RUST_REPOS[@]}"; do
  run_architectural_guards "$repo" "$ROOT_DIR"
done

if [[ "$SKIP_SMOKE" -eq 0 ]]; then
  printf '\nRunning nayuta-headless mock chat smoke test...\n'
  (
    cd "$ROOT_DIR/nayuta"
    checked_cargo run -q -p nayuta-headless -- chat "Halo Nayuta" --provider mock
  )
  printf '[PASS] nayuta-headless mock chat.\n'
fi

printf '\nALL REPOSITORIES, TESTS, AND ARCHITECTURAL GUARDS PASSED WITHOUT CARGO WARNINGS!\n'
