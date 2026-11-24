#!/usr/bin/env bash

checked_cargo() {
  local output status
  if output="$(CARGO_TERM_COLOR=never cargo "$@" 2>&1)"; then
    status=0
  else
    status=$?
  fi
  if [[ "$status" -ne 0 ]]; then
    printf '%s\n' "$output" >&2
    return "$status"
  fi
  local line
  while IFS= read -r line; do
    if [[ "$line" == warning:* ]]; then
      printf '%s\n' "$output" >&2
      printf '[FAIL] Cargo emitted warnings: cargo %s\n' "$*" >&2
      return 1
    fi
  done <<< "$output"
  printf '%s\n' "$output"
}

assert_dependency_guard() {
  local guard="$1" pattern="$2" tree="$3" line
  while IFS= read -r line; do
    if [[ "$line" =~ $pattern ]]; then
      printf '[FAIL] %s: forbidden dependency: %s\n' "$guard" "$line" >&2
      return 1
    fi
  done <<< "$tree"
}

run_core_guard() {
  local root="$1" tree line feature
  if tree="$(checked_cargo tree --manifest-path "$root/core/Cargo.toml" --workspace -e normal -f '{p} [{f}]')"; then
    :
  else
    return $?
  fi
  assert_dependency_guard GUARD-01 '(^|[[:space:]])(axum|reqwest|hyper|wgpu|winit|egui)[[:space:]]' "$tree" || return $?
  local tokio_pattern='(^|[[:space:]])tokio[[:space:]]v[^[]*\[([^]]*)\]'
  local features
  local -a feature_names
  while IFS= read -r line; do
    if [[ "$line" =~ $tokio_pattern ]]; then
      features="${BASH_REMATCH[2]}"
      IFS=',' read -r -a feature_names <<< "$features"
      for feature in "${feature_names[@]}"; do
        feature="${feature//[[:space:]]/}"
        if [[ -n "$feature" && "$feature" != sync ]]; then
          printf '[FAIL] GUARD-01: forbidden Tokio feature %s: %s\n' "$feature" "$line" >&2
          return 1
        fi
      done
    fi
  done <<< "$tree"
  printf '[PASS] GUARD-01: all core crates are HTTP/GPU-free and Tokio sync-only.\n'
}

run_headless_guard() {
  local root="$1" tree
  if tree="$(checked_cargo tree --manifest-path "$root/nayuta/Cargo.toml" -p nayuta-headless -e normal)"; then
    :
  else
    return $?
  fi
  assert_dependency_guard GUARD-04 '(^|[[:space:]])(wgpu|winit|egui|nayuta-spatial-|nayuta-shader-)' "$tree" || return $?
  printf '[PASS] GUARD-04: nayuta-headless is GPU/window-free.\n'
}

run_graphics_guard() {
  local repo="$1" root="$2" tree package version rest
  if tree="$(checked_cargo tree --manifest-path "$root/$repo/Cargo.toml" --workspace -e normal --prefix none)"; then
    :
  else
    return $?
  fi
  local wgpu_version='' winit_version=''
  while read -r package version rest; do
    case "$package" in
      wgpu)
        if [[ -n "$wgpu_version" && "$version" != "$wgpu_version" ]]; then
          printf '[FAIL] GUARD-05: multiple wgpu versions in %s: %s, %s\n' "$repo" "$wgpu_version" "$version" >&2
          return 1
        fi
        wgpu_version="$version"
        ;;
      winit)
        if [[ -n "$winit_version" && "$version" != "$winit_version" ]]; then
          printf '[FAIL] GUARD-05: multiple winit versions in %s: %s, %s\n' "$repo" "$winit_version" "$version" >&2
          return 1
        fi
        winit_version="$version"
        ;;
    esac
  done <<< "$tree"
  printf '[PASS] GUARD-05: single wgpu/winit versions in %s.\n' "$repo"
}

run_architectural_guards() {
  local repo="$1" root="$2" tree guard pattern
  case "$repo" in
    core) run_core_guard "$root"; return $? ;;
    vrm) guard=GUARD-02; pattern='(^|[[:space:]])(wgpu|winit|egui|nayuta-shader-)' ;;
    agent) guard=GUARD-03; pattern='(^|[[:space:]])(nayuta-router-|axum|wgpu|winit)' ;;
    spatial) run_graphics_guard "$repo" "$root"; return $? ;;
    nayuta)
      run_headless_guard "$root" || return $?
      run_graphics_guard "$repo" "$root"
      return $?
      ;;
    shaders|router|sdk) return 0 ;;
    *) printf '[FAIL] Unknown Rust repository: %s\n' "$repo" >&2; return 2 ;;
  esac
  if tree="$(checked_cargo tree --manifest-path "$root/$repo/Cargo.toml" --workspace -e normal)"; then
    :
  else
    return $?
  fi
  assert_dependency_guard "$guard" "$pattern" "$tree" || return $?
  printf '[PASS] %s: dependency boundary holds in %s.\n' "$guard" "$repo"
}
