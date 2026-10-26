# Implementasi Akhir: Dari Rancangan ke Game Jadi

Dokumen `01-arsitektur-node-tree-dan-autoload.md` ditulis sebelum game selesai dan menggambarkan arsitektur yang dituju. Dokumen ini mencatat bentuk akhirnya: apa yang dibuat persis seperti rancangan, apa yang disederhanakan, dan di mana letak tiap bagian.

---

## 1. Alur Scene

```
MainMenu ──► StageMap ──► BattleScene ──► (Berkah Roro Ayu) ──► StageMap
   │            │  │                                   │
   │            │  └──► Pustaka ◄──────────────────────┘ (kembali ke scene asal)
   │            └──────► Ending (setelah stage 5, bisa diputar ulang dari peta)
   └──► Pustaka
```

| Scene | File | Isi |
|---|---|---|
| Menu utama | `scenes/main_menu/` | Lanjutkan, Petualangan Baru (dengan konfirmasi), Pustaka, Pengaturan, Keluar |
| Peta | `scenes/stage_map/` | 5 titik stage, panel info lawan, penampil deck, prolog saat pertama dibuka |
| Battle | `scenes/battle/` | Pertarungan, dialog pembuka/penutup, tutorial di stage 1, panel kalah/jeda |
| Pustaka | `scenes/pustaka/` | Dongkrek, Eyang Palang, 5 Buto (terbuka setelah dilawan), cara main, kartu & resep |
| Ending | `scenes/ending/` | Dialog penutup, fajar di Mejayan, kredit |

Scene `Boot` dari rancangan tidak dibuat: autoload sudah memuat data dan save sebelum menu tampil, jadi layar boot terpisah tidak diperlukan.

## 2. Autoload

| Rancangan | Implementasi | Catatan |
|---|---|---|
| `EventBus` | tidak dibuat | Semua signal cukup lewat `BattleManager`, `PlayerState`, `HandManager`, dan `HealthComponent`. Battle scene yang menyambungkan semuanya |
| `CardDB` | `autoload/card_db.gd` | Kartu dan resep dari `data/card_library.tres`. Data stage ada di `StageCatalog` |
| `GameState` | `autoload/game_state.gd` | Progres, deck (`"tipe:rank"`), HP maksimal, Buto yang pernah dilawan, berkah, pengaturan |
| `SaveManager` | digabung ke `GameState` | Satu file `user://save.cfg` (ConfigFile) untuk progres dan pengaturan |
| `SceneRouter` | `autoload/scene_router.gd` | Fade hitam, `go_back()` untuk tombol Kembali di Pustaka |
| `AudioManager` | `autoload/audio_manager.gd` | Crossfade musik, 8 suara SFX. Bus: Master → Music, SFX |

## 3. BattleScene

```
BattleScene (Node2D)                 battle_scene.gd: memuat stage, membuat Buto, menyambungkan sistem ke tampilan
├── Systems
│   ├── DeckController
│   ├── HandManager
│   ├── PlayerState
│   └── BattleManager                state machine + antrean BattleAction
├── World
│   ├── Background                   latar candi, diberi warna per stage
│   ├── Hero (Health + UnitView)
│   ├── Enemies                      EnemyButo + Health + UnitView per musuh
│   └── Effects                      angka damage melayang
├── HUD (CanvasLayer 10)
│   ├── BattleHUD                    AP, Moxie, rantai evolusi, tombol Ultimate & Akhiri Turn
│   ├── HandView                     kartu, seret-geser, tombol merge
│   └── Tooltip
└── Overlay (CanvasLayer 20)         dialog, jeda, berkah, panel kalah
```

Tampilan tidak pernah mengubah logika secara langsung. `HandView` dan `BattleHUD` hanya memanggil `request_*` di `BattleManager`, lalu menggambar ulang dari signal. Saat aksi berjalan, `BattleManager.action_started` memberi tahu scene aksi apa yang sedang dipresentasikan (serangan, Ultimate, racun, ilmu Buto) supaya animasi dan suaranya cocok.

## 4. Aturan yang Dipakai

Jawaban final untuk tabel "Keputusan Desain yang Masih Terbuka" di dokumen 01:

| Pertanyaan | Keputusan |
|---|---|
| Pemicu merge | Otomatis saat kartu digeser ke sebelah pasangannya (1 AP), atau gratis lewat tombol rantai kalau sudah bersebelahan |
| Rank hybrid | Sama dengan rank bahan |
| Merge lanjutan | Tidak ada |
| Sisa kartu di akhir turn | Disimpan, tangan diisi ulang sampai 7 |
| AP & tangan | 4 AP, maksimal 7 kartu, batas atas AP 9 (dari Flow State) |
| Ultimate | 0 AP, damage dasar 30 ke semua Buto × (Moxie terpakai / 100) × pengali evolusi |
| Jumlah karakter | Satu hero, Eyang Palang |

Tambahan selama pengembangan:

- **Tameng (Block)** dari kartu Taktik, hilang di awal turn pemain.
- **Racun** dari Buto Hijau, bekerja di akhir giliran musuh dan menembus Tameng.
- **Niat Buto** (`EnemyIntent`) ditampilkan di atas kepala tiap Buto.
- **Berkah Roro Ayu** setelah menang: dua kartu satu tipe naik bintang, atau HP maksimal +10.

## 5. Data dan Aset

| Bagian | Sumber | Dibuat oleh |
|---|---|---|
| Sprite Eyang Palang & Buto | `docs/desain_asli/` | `tools/build_assets.py` (potong latar, rapikan) |
| Bingkai kartu | desain kartu asli, diwarnai ulang untuk 6 jenis | `tools/build_assets.py` |
| Ikon kartu | digambar baru bernuansa Jawa (keris, padupan, tameng, tombak, alat musik Tabuh); mata merah Tenaga Dalam dari desain asli | `tools/build_assets.py` |
| Latar battle & menu | desain latar candi | `tools/build_assets.py` |
| Peta perjalanan | digambar baru dengan palet latar battle | `tools/build_map.py` |
| Ikon kecil, topeng, potret Eyang & Buto | digambar baru / dipotong dari sprite | `tools/build_assets.py` |
| Potret Roro Ayu | dilukis baru dari desain sprite diam Roro Ayu (setengah badan, menghadap ke depan) | `tools/portrait_roro_ayu.py` |
| Musik & efek suara | disintesis (bedug, korek, kentongan, gamelan, slompret, suling) | `tools/build_audio.py` |
| Kartu, resep, stage | angka di dalam skrip | `tools/generate_data.gd` |
| Teks dua bahasa | daftar `(kunci, id, en)` | `tools/strings_source.py` |

## 6. Pengujian

- `tests/`: 284 cek untuk deck, tangan, PlayerState, BattleManager, semua Buto, dan konten game.
- `tests/test_campaign_flow.gd`: menamatkan kampanye lewat scene asli dengan klik mouse sungguhan (menu, prolog, 5 battle, berkah, ending, kembali ke menu). Simpanan pemain tidak tersentuh karena tes memakai `user://test_save.cfg`.
- `tools/simulate_balance.gd`: bot memainkan tiap stage 200 kali. Hasilnya ada di README.
