#!/usr/bin/env bash
set -euo pipefail

SKIP_FMT=0
SKIP_SMOKE=0

usage() {
  cat <<'EOF'
Usage: check-all.sh [--skip-fmt] [--skip-smoke] [-h|--help]

Options:
  --skip-fmt     Skip `cargo fmt --all -- --check` across repositories
  --skip-smoke   Skip `nayuta-headless` mock chat smoke test
  -h, --help     Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-fmt)
      SKIP_FMT=1
      shift
      ;;
    --skip-smoke)
      SKIP_SMOKE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RUST_REPOS=(
  "core"
  "shaders"
  "vrm"
  "router"
  "agent"
  "sdk"
  "spatial"
  "nayuta"
)

echo "============================================================"
echo " Nayuta Multi-Repo Verification & Architectural Guard Suite"
echo " Root: $ROOT_DIR"
echo "============================================================"

for repo in "${RUST_REPOS[@]}"; do
  repo_path="$ROOT_DIR/$repo"
  if [[ ! -d "$repo_path" ]]; then
    echo "Missing repository directory: $repo_path" >&2
    exit 1
  fi

  echo ""
  echo ">>> [$repo] Running workspace checks..."
  (
    cd "$repo_path"
    if [[ "$SKIP_FMT" -eq 0 ]]; then
      echo "  [1/3] cargo fmt --all -- --check"
      cargo fmt --all -- --check
    fi

    echo "  [2/3] cargo clippy --workspace --all-targets -- -D warnings"
    cargo clippy --workspace --all-targets -- -D warnings

    echo "  [3/3] cargo test --workspace"
    cargo test --workspace
  )
done

echo ""
echo "============================================================"
echo " Running 5 Architectural Fitness Guards (cargo tree)"
echo "============================================================"

check_guard() {
  local guard_id="$1"
  local repo="$2"
  local pattern="$3"
  local pass_msg="$4"
  local fail_msg="$5"
  shift 5

  local tree_out
  tree_out="$(
    cd "$ROOT_DIR/$repo" || exit 1
    "$@"
  )"

  local matches=""
  local grep_status=0
  matches="$(printf '%s\n' "$tree_out" | grep -E -- "$pattern")" || grep_status=$?

  if [[ "$grep_status" -eq 0 ]]; then
    echo "  [FAIL] ${guard_id} VIOLATION in ${repo}: ${fail_msg}:" >&2
    printf '%s\n' "$matches" >&2
    exit 1
  elif [[ "$grep_status" -gt 1 ]]; then
    echo "  [ERROR] ${guard_id}: grep failed with exit status ${grep_status}" >&2
    exit "$grep_status"
  fi

  echo "  [PASS] ${guard_id}: ${pass_msg}"
}

# GUARD-01: core must not pull axum, reqwest, hyper, wgpu, winit, egui, or tokio rt
check_guard \
  "GUARD-01" \
  "core" \
  '(^|[[:space:]])(axum|reqwest|hyper|wgpu|winit|egui)[[:space:]]|tokio v[^[]*\[[^]]*\brt\b' \
  "nayuta-core-* is free of HTTP/GPU/tokio-rt dependencies." \
  "forbidden dependency detected" \
  cargo tree -p nayuta-core-telemetry -e normal -f "{p} [{f}]"

# GUARD-02: vrm must be 100% CPU-only (no wgpu, winit, egui, nayuta-shader-*)
check_guard \
  "GUARD-02" \
  "vrm" \
  '(^|[[:space:]])(wgpu|winit|egui|nayuta-shader-)' \
  "nayuta-vrm-* is 100% CPU-only." \
  "GPU/window dependency detected" \
  cargo tree --workspace -e normal

# GUARD-03: agent must not depend on router, wgpu, or winit
check_guard \
  "GUARD-03" \
  "agent" \
  '(^|[[:space:]])(nayuta-router-|axum|wgpu|winit)' \
  "nayuta-agent-* is decoupled from nayuta-router-*." \
  "direct router/GPU dependency detected" \
  cargo tree --workspace -e normal

# GUARD-04: nayuta-headless must not pull wgpu, winit, egui, spatial, or shaders
check_guard \
  "GUARD-04" \
  "nayuta" \
  '(^|[[:space:]])(wgpu|winit|egui|nayuta-spatial-|nayuta-shader-)' \
  "nayuta-headless is 100% GPU-free (VPS ready)." \
  "GPU/window dependency detected" \
  cargo tree -p nayuta-headless -e normal

# GUARD-05: single version of wgpu and winit in spatial and nayuta workspaces
for graphics_repo in spatial nayuta; do
  check_guard \
    "GUARD-05" \
    "$graphics_repo" \
    '^(wgpu|winit) v' \
    "single unified version of wgpu & winit in ${graphics_repo}." \
    "duplicate wgpu or winit versions detected" \
    cargo tree -d
done

if [[ "$SKIP_SMOKE" -eq 0 ]]; then
  echo ""
  echo ">>> Running Smoke Test: nayuta-headless chat..."
  (cd "$ROOT_DIR/nayuta" && cargo run -q -p nayuta-headless -- chat "Halo Nayuta" --provider mock)
  echo "  [PASS] Smoke Test: nayuta-headless chat streamed successfully."
fi

echo ""
echo "============================================================"
echo " ALL REPOSITORIES, TESTS, AND ARCHITECTURAL GUARDS PASSED!"
echo "============================================================"
