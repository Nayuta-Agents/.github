# Nayuta Organization Infrastructure (`.github`)

Repositori `.github` menyimpan:
1. **`profile/README.md`**: Profil publik GitHub Organization Nayuta.
2. **`.github/workflows/rust-ci.yml`**: *Reusable GitHub Actions workflow* untuk seluruh repositori Rust (`core`, `shaders`, `vrm`, `router`, `agent`, `sdk`, `spatial`, `nayuta`).
3. **`scripts/check-all.ps1`**: Skrip verifikasi lokal lintas-repositori (`cargo fmt`, `cargo clippy`, `cargo test`, 5 *Architectural Fitness Guards*, dan *smoke test* `nayuta-headless`).
4. **`scripts/set-remotes.ps1`**: Skrip otomasi untuk mengisi nama organisasi `Nayuta-Agents` dan memasang `git remote origin` pada kesebelas repositori.
