# Nayuta

**100% Native Rust AI Router, Autonomous Agent Runtime & VRM 3D Spatial Telemetry Engine.**

Nayuta adalah ekosistem modular yang menggabungkan gateway multi-provider LLM berkinerja tinggi (`router`), orkestrator agen otonom (`agent`), dan *porting* Rust untuk spesifikasi karakter 3D `@pixiv/three-vrm` (`vrm`, `shaders`, `spatial`) di atas `wgpu` + `winit` + `egui`.

---

## Peta Repositori Organisasi

| Level | Repositori | Peran Utama |
| :-: | :--- | :--- |
| **L0** | [`core`](https://github.com/Nayuta-Agents/core) | Tipe data chat kanonik, trait `ChatBackend`, *lossy broadcast* `TelemetryBus`, konfigurasi berlapis, dan amplop IPC |
| **L0** | [`shaders`](https://github.com/Nayuta-Agents/shaders) | Modul shader WGSL murni (`MToon`, kurva *spline* 3D, *post-FX bloom*) tervalidasi `naga` |
| **L0** | [`vrm`](https://github.com/Nayuta-Agents/vrm) | Porting *CPU-only* `@pixiv/three-vrm`: parser VRM 0.x/1.0, fisika rambut Verlet `SpringBone`, `LookAt`, dan `.vrma` |
| **L1** | [`router`](https://github.com/Nayuta-Agents/router) | Gateway AI multi-provider, *circuit breaker*, *auto-failover*, estimasi token, dan server HTTP/SSE OpenAI-compatible |
| **L1** | [`agent`](https://github.com/Nayuta-Agents/agent) | Siklus penalaran *ReAct*, eksekusi *tool* paralel, integrasi *Model Context Protocol* (MCP), dan penyimpanan memori |
| **L1** | [`sdk`](https://github.com/Nayuta-Agents/sdk) | Pustaka klien Rust, spesifikasi OpenAPI 3.1, dan kontrak plugin WebAssembly Component Model (WIT) |
| **L2** | [`spatial`](https://github.com/Nayuta-Agents/spatial) | Renderer 3D `wgpu` + `winit` + `egui`, jembatan VRM-ke-GPU, kurva *Catmull-Rom* simpul API, dan panel HUD |
| **L3** | [`nayuta`](https://github.com/Nayuta-Agents/nayuta) | Biner aplikasi utama: `nayuta-desktop` (3D GUI) dan `nayuta-headless` (murni CLI/Server untuk VPS tanpa GPU) |
| **Aset** | [`assets`](https://github.com/Nayuta-Agents/assets) | Penyimpanan berbasis Git LFS untuk model avatar `.vrm`, animasi `.vrma`, tekstur, dan font |
| **Dok** | [`docs`](https://github.com/Nayuta-Agents/docs) | Dokumentasi arsitektur lengkap (PRD, Use Case, ERD, Dependency Graph, Flows, Kontrak Crate, ADR, dan Playbook AI Agent) |

---

## Lisensi

Seluruh kode sumber dilisensikan di bawah **MIT OR Apache-2.0**.
