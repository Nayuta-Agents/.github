# Nayuta Organization Infrastructure (`.github`)

Repositori `.github` mengelola identitas organisasi GitHub **Nayuta-Agents**, *workflow* Continuous Integration lintas-repositori, pipeline staging rilis, dan rangkaian skrip verifikasi arsitektur untuk kesebelas repositori saudara (*sibling layout*).

---

## Struktur Repositori

| Jalur | Peran |
| :--- | :--- |
| [`profile/README.md`](./profile/README.md) | Halaman profil publik organisasi GitHub Nayuta |
| [`.github/workflows/rust-ci.yml`](./.github/workflows/rust-ci.yml) | *Reusable GitHub Actions workflow* untuk pemeriksaan Rust per repositori (`fmt`, `clippy -D warnings`, `test`, *fitness guards*, dan matrix LFS/dev) |
| [`.github/workflows/ci-and-release.yml`](./.github/workflows/ci-and-release.yml) | Workflow CI multi-OS (`ubuntu-latest`, `windows-latest`), validasi `nayuta-headless --features web-companion`, pengujian Docker headless non-root, serta staging artefak rilis manual/tag `v*` |
| [`scripts/check-all.sh`](./scripts/check-all.sh) | Runner verifikasi lengkap lintas-8-repositori Rust untuk Linux/macOS |
| [`scripts/check-all.ps1`](./scripts/check-all.ps1) | Runner verifikasi lengkap lintas-8-repositori Rust untuk Windows PowerShell |
| [`scripts/verification.sh`](./scripts/verification.sh) | Pustaka helper Bash untuk deteksi *Cargo manifest warning* dan validasi `GUARD-01` – `GUARD-05` |
| [`scripts/verification.ps1`](./scripts/verification.ps1) | Pustaka helper PowerShell untuk deteksi *Cargo manifest warning* dan validasi `GUARD-01` – `GUARD-05` |
| [`scripts/test-verification.sh`](./scripts/test-verification.sh) | 21 *negative & positive fixture tests* untuk menguji kelayakan *guard parser* di Linux |
| [`scripts/test-verification.ps1`](./scripts/test-verification.ps1) | Fixture tests setara untuk PowerShell di Windows |
| [`scripts/set-remotes.ps1`](./scripts/set-remotes.ps1) | Helper penyiapan `git remote origin` ke `Nayuta-Agents` untuk seluruh sibling repositori |
| [`scripts/push-all.ps1`](./scripts/push-all.ps1) | Skrip dorong (*push*) seluruh sibling repositori ke `origin/dev` |

---

## Lima Architectural Fitness Guards

Skrip verifikasi (`verification.sh` / `verification.ps1`) menegakkan aturan dependensi DAG secara *fail-closed* pada setiap repositori:

1. **`GUARD-01` (`core`)**: Seluruh crate `nayuta-core-*` dilarang menarik `axum`, `reqwest`, `wgpu`, `winit`, `egui`, atau fitur `tokio` selain `sync`.
2. **`GUARD-02` (`vrm`)**: Seluruh crate `nayuta-vrm-*` wajib murni CPU; bebas dari `wgpu`, `winit`, `egui`, dan `nayuta-shader-*`.
3. **`GUARD-03` (`agent`)**: Crate `nayuta-agent-*` dilarang bergantung pada `nayuta-router-*`; abstraksi backend wajib melalui `nayuta-core-types`.
4. **`GUARD-04` (`nayuta-headless`)**: Biner server dilarang menarik `wgpu`, `winit`, `egui`, `nayuta-spatial-*`, atau `nayuta-shader-*` (diperiksa baik pada fitur *default* maupun `--features web-companion`).
5. **`GUARD-05` (`spatial` & `nayuta`)**: Hanya diizinkan tepat **satu versi** `wgpu` dan **satu versi** `winit` di pohon dependensi `cargo tree`.

Selain guard di atas, fungsi `checked_cargo` memastikan *build* gagal otomatis apabila Cargo mengeluarkan peringatan manifest (`unused_crate_dependencies`, kunci `Cargo.toml` tidak valid, dsb.).

---

## Menjalankan Verifikasi Lokal

Jalankan perintah berikut dari direktori induk ekosistem (`RustNagisa/`) dengan `HOME` dan `TMPDIR` terisolasi agar konfigurasi pengguna lokal tidak memengaruhi pengujian:

### Linux / macOS (Bash)

```bash
(
  export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
  export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
  mkdir -p target
  test_root="$(mktemp -d "$PWD/target/nayuta-verify.XXXXXX")"
  trap 'rm -rf "$test_root"' EXIT
  mkdir -p "$test_root/home" "$test_root/tmp"
  export HOME="$test_root/home" TMPDIR="$test_root/tmp"
  CARGO_BUILD_JOBS=2 bash .github/scripts/check-all.sh
)
```

Opsi tambahan:
- `--skip-fmt` untuk melewati pemeriksaan `cargo fmt --check`.
- `--skip-smoke` untuk melewati *smoke test* CLI `nayuta-headless chat "Halo Nayuta" --provider mock`.

### Windows (PowerShell)

```powershell
.\.github\scripts\check-all.ps1
```

---

## Lisensi

Seluruh konfigurasi dan skrip di dalam repositori ini dilisensikan secara ganda di bawah **MIT OR Apache-2.0**.
