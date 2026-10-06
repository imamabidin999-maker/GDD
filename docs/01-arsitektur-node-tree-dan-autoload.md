# Arsitektur Teknis: Node Tree & Autoload

Game Turn-Based RPG Pixel Art bertema Dongkrek Madiun
Engine: Godot 4.x (GDScript)
Mekanik inti: **Tactical Cycle Synthesis**

Dokumen ini baru sebatas rancangan struktur. Belum ada kode fungsi.

---

## 0. Tiga Aturan yang Dipegang di Seluruh Rancangan

1. **Data, logika, dan tampilan dipisah.**
   Definisi kartu dan musuh disimpan sebagai Resource (`.tres`). Logika battle (deck, hand, merge, AP, Moxie) ada di Node yang tidak tahu apa-apa soal UI. UI tugasnya cuma mendengarkan signal lalu menggambar ulang.
2. **Autoload hanya untuk hal yang hidup sepanjang game.**
   Apa pun yang harus di-reset setiap battle (draw pile, isi tangan, AP, Moxie) tinggal di dalam `BattleScene` dan ikut hilang saat scene ditutup.
3. **Signal naik, pemanggilan fungsi turun.**
   Child tidak pernah memanggil parent-nya. Child cukup emit signal, lalu parent (atau composition root) yang menyambungkan.

---

## 1. Peta Scene Global

```
Boot.tscn ──► MainMenu.tscn ──► StageMap.tscn ──► BattleScene.tscn ──► (Overlay hasil) ──► StageMap.tscn
                                     │
                                     └──► Pustaka.tscn   (ensiklopedia kartu & 5 Buto Dongkrek)
```

| Scene | Isi singkat |
|---|---|
| `Boot` | Splash, load data awal lewat `CardDB`, cek save |
| `MainMenu` | Mulai, Lanjutkan, Pengaturan, Pustaka |
| `StageMap` | Peta perjalanan; tiap node berisi satu `EncounterData` |
| `BattleScene` | Inti game. Strukturnya dijabarkan di bagian 2 |
| `Pustaka` | Info budaya Dongkrek + kartu + Buto yang sudah ditemui |

Perpindahan scene selalu lewat `SceneRouter` (autoload) supaya transisi fade dan loading konsisten.

---

## 2. BattleScene: Node Tree Lengkap

```
BattleScene (Node)                          ← battle_scene.gd · composition root, menyambungkan semua sistem
│
├── Systems (Node)                          ← logika murni, tidak ada visual sama sekali
│   ├── BattleStateMachine (Node)
│   │   ├── BattleStart (Node)
│   │   ├── TurnStart (Node)
│   │   ├── PlayerAction (Node)
│   │   ├── Resolving (Node)
│   │   ├── TurnEnd (Node)
│   │   ├── EnemyTurn (Node)
│   │   ├── Victory (Node)
│   │   └── Defeat (Node)
│   ├── ActionQueue (Node)                  ← antrean Command, eksekusi berurutan + tunggu animasi
│   ├── DeckController (Node)               ← draw pile & discard pile
│   ├── HandManager (Node)                  ← urutan kartu di tangan, geser, ganti hasil merge
│   ├── PlayerState (Node)                  ← AP, Moxie 0–200%, Evolutionary Chain
│   ├── TargetSelector (Node)               ← musuh yang sedang dikunci sebagai target
│   └── EnemyDirector (Node)                ← atur intent & giliran semua Buto
│
├── World (Node2D)                          ← semua yang ada "di dunia" game
│   ├── Background (Parallax2D)             ← Parallax2D tersedia sejak 4.3
│   ├── PlayerSide (Node2D)
│   │   └── Hero (HeroUnit.tscn)
│   ├── EnemySide (Node2D)
│   │   ├── Slot1 (Marker2D)                ← posisi spawn Buto, diisi dari EncounterData
│   │   ├── Slot2 (Marker2D)
│   │   ├── Slot3 (Marker2D)
│   │   └── Slot4 (Marker2D)
│   ├── VFXLayer (Node2D)                   ← efek serangan, angka damage
│   └── Camera2D                            ← shake saat crit / Ultimate
│
├── HUD (CanvasLayer, layer = 10)
│   └── BattleHUD (Control, Full Rect)
│       ├── TopBar (HBoxContainer)
│       │   ├── TurnLabel (Label)
│       │   ├── PileCounter (HBoxContainer) ← sisa draw pile / discard pile
│       │   └── PauseButton (TextureButton)
│       ├── HeroStatus (VBoxContainer)
│       │   ├── HPBar (TextureProgressBar)
│       │   └── StatusIcons (HBoxContainer)
│       ├── MoxieGauge (MoxieGauge.tscn)
│       ├── APDisplay (HBoxContainer)       ← pip AP, nyala/mati
│       ├── HandView (HBoxContainer)        ← diisi CardView.tscn secara dinamis
│       ├── UltimateButton (TextureButton)
│       ├── EndTurnButton (TextureButton)
│       └── Tooltip (PanelContainer)
│
└── Overlay (CanvasLayer, layer = 20)
    ├── ResultPanel (Control)               ← layar menang / kalah
    └── PauseMenu (Control)
```

Catatan:

- Root sengaja pakai `Node`, bukan `Node2D`, karena isinya campuran dunia 2D dan CanvasLayer.
- Node yang sering diakses (`HandView`, `MoxieGauge`, `APDisplay`) ditandai **Access as Unique Name** (`%HandView`) supaya path tidak patah saat hierarki UI diubah.
- Semua node di bawah `Systems` tidak punya sprite atau Control. Kalau suatu saat mau bikin mode auto-battle atau unit test, cabang ini bisa jalan tanpa UI.

---

## 3. Sub-Scene yang Dipakai Ulang

### 3.1 Unit (base) dan turunannya

```
Unit.tscn (Node2D)                          ← unit.gd
├── Visual (Node2D)
│   ├── Shadow (Sprite2D)
│   └── Body (AnimatedSprite2D)             ← idle, attack, hit, death
├── AnimationPlayer                         ← maju-mundur saat menyerang, flash saat kena hit
├── Health (Node)                           ← HealthComponent
├── Status (Node)                           ← StatusComponent: buff/debuff + durasi per turn
├── ClickArea (Area2D)                      ← untuk memilih target
│   └── CollisionShape2D
├── InfoAnchor (Marker2D)                   ← titik tempel HP bar kecil & ikon intent
└── PopupAnchor (Marker2D)                  ← titik muncul angka damage
```

Turunan (pakai **Inherited Scene**):

```
HeroUnit.tscn      ← extends Unit, tanpa tambahan node (misalnya tokoh Eyang Palang)

ButoUnit.tscn      ← extends Unit
├── + Brain (Node)                          ← menyimpan AIBrain resource & intent yang sedang aktif
├── + InfoAnchor/IntentIcon (Sprite2D)      ← ikon niat musuh di turn berikutnya
└── + InfoAnchor/MiniHPBar (TextureProgressBar)

ButoHitam.tscn     ← extends ButoUnit (khusus boss)
├── + PhaseController (Node)                ← ganti fase saat HP melewati ambang tertentu
└── + AuraVFX (CPUParticles2D)
```

Pemetaan 5 Buto:

| Buto | Scene | Data | Contoh peran (bisa diganti) |
|---|---|---|---|
| Buto Kuning | `ButoUnit.tscn` | `buto_kuning.tres` | Cepat, serangan ringan beruntun |
| Buto Hijau | `ButoUnit.tscn` | `buto_hijau.tres` | Debuff / racun |
| Buto Merah | `ButoUnit.tscn` | `buto_merah.tres` | Serangan berat, butuh ancang-ancang |
| Buto Putih | `ButoUnit.tscn` | `buto_putih.tres` | Support: heal / shield untuk Buto lain |
| Buto Hitam | `ButoHitam.tscn` | `buto_hitam.tres` | Boss multi-fase |

Empat minion cukup satu scene, bedanya hanya di file data. Jadi kalau nanti mau tambah Buto baru, cukup bikin `.tres` baru tanpa menyentuh scene.

### 3.2 CardView

```
CardView.tscn (Control)                     ← card_view.gd · tampilan saja, memegang referensi CardInstance
├── Frame (NinePatchRect)                   ← warna ikut tipe: merah / biru / hijau / hybrid
├── Art (TextureRect)
├── TypeIcon (TextureRect)
├── NameLabel (Label)
├── RankPips (HBoxContainer)
├── MergeGlow (TextureRect)                 ← menyala kalau kartu ini bisa di-merge dengan tetangganya
└── AnimationPlayer                         ← draw, hover, play, merge
```

Fitur geser kartu bisa memanfaatkan drag & drop bawaan Control di Godot (`_get_drag_data`, `_can_drop_data`, `_drop_data`). Tapi `CardView` dan `HandView` **tidak** memindahkan data sendiri. Keduanya hanya melaporkan "pemain minta geser dari slot X ke slot Y", lalu sistem yang memutuskan.

### 3.3 MoxieGauge

```
MoxieGauge.tscn (Control)
├── BarBase (TextureProgressBar)            ← 0–100%
├── BarOvercharge (TextureProgressBar)      ← 100–200%, warna berbeda, ditumpuk di atas BarBase
├── PercentLabel (Label)
└── AnimationPlayer                         ← denyut saat 100% (Ultimate siap) dan 200% (Overcharge penuh)
```

---

## 4. Daftar Autoload (Singleton)

Didaftarkan di **Project Settings → Autoload** (di Godot 4.3+ letaknya di tab *Globals*). Urutan di bawah ini adalah urutan load, dan urutannya penting.

| # | Nama Autoload | Tugas | Menyimpan state? |
|---|---|---|---|
| 1 | `EventBus` | Kumpulan signal global. Tidak ada logika, tidak ada data. | Tidak |
| 2 | `CardDB` | Registry baca-saja: semua `CardData`, `MergeRecipe`, `EnemyData`, `EncounterData`. Dimuat sekali saat boot. Menyediakan pencarian berdasarkan id dan pencarian resep merge berdasarkan pasangan tipe. | Read-only |
| 3 | `GameState` | Data progres pemain yang bertahan antar-scene: komposisi 15 kartu, stat hero, stage yang terbuka, Buto yang sudah dikalahkan, encounter yang akan dimainkan, dan status alur game (MENU / MAP / BATTLE / PUSTAKA). | **Ya** |
| 4 | `SaveManager` | Baca/tulis `GameState` ke `user://`. Pengaturan (volume, bahasa) disimpan terpisah pakai `ConfigFile`. | Tidak (hanya I/O) |
| 5 | `SceneRouter` | Ganti scene dengan transisi fade + threaded loading (`ResourceLoader.load_threaded_request`) untuk scene berat seperti BattleScene. Berupa `.tscn` karena butuh CanvasLayer untuk layar transisi. | Minimal |
| 6 | `AudioManager` | BGM dengan crossfade, pool SFX. Bus audio: Master → BGM, SFX, UI, Ambience. Berupa `.tscn`. | Minimal |

Alasan urutan:

- `EventBus` paling atas karena autoload lain mungkin connect ke signal-nya di `_ready`.
- `CardDB` sebelum `GameState`, karena saat load save, `GameState` perlu mengubah id kartu menjadi `CardData`.
- `SaveManager` setelah `GameState`, karena yang disimpan adalah isi `GameState`.

Peringatan khas Godot 4: jangan beri `class_name` pada script autoload dengan nama yang sama seperti nama autoload-nya. Godot akan protes karena class tersebut "menyembunyikan" singleton.

### 4.1 Isi EventBus (nama signal saja)

Aturannya: **EventBus dipakai untuk memberi tahu, bukan untuk menyuruh.** Sistem yang perlu menyuruh sistem lain memakai Command (bagian 6), bukan signal global.

| Kelompok | Signal |
|---|---|
| Alur battle | `battle_started`, `turn_started(turn)`, `turn_ended`, `battle_ended(result)` |
| Kartu | `card_drawn`, `card_played`, `card_moved`, `cards_merged`, `deck_reshuffled`, `pile_count_changed` |
| Sumber daya | `ap_changed(current, max)`, `moxie_changed(value)`, `ultimate_ready`, `overcharge_full` |
| Combat | `unit_damaged`, `unit_healed`, `unit_died`, `status_applied`, `enemy_intent_updated`, `target_changed` |
| UI | `tooltip_requested`, `tooltip_hidden` |

Pendengar utamanya: HUD, AudioManager, sistem tutorial, dan pencatat Pustaka. Mereka bisa bereaksi tanpa harus tahu letak node `HandManager` di tree.

### 4.2 Kenapa DeckController & HandManager tidak dijadikan Autoload

Ini sengaja. Ada empat alasan:

1. **Umur data berbeda.** Autoload hidup sejak game dibuka sampai ditutup, sedangkan draw pile, isi tangan, AP, dan Moxie cuma relevan selama satu battle. Kalau ditaruh di autoload, kamu wajib reset manual setiap battle baru. Satu variabel lupa di-reset, muncul bug "kartu dari battle sebelumnya masih nyangkut".
2. **Lebih gampang dites.** Node di dalam `BattleScene` bisa dijalankan di scene uji tersendiri dengan deck palsu.
3. **Mencegah kopling liar.** Kalau `HandManager` global, script mana pun bisa mengubah isi tangan dan nanti susah dilacak siapa pelakunya.
4. **Akses tetap mudah.** `BattleScene` sebagai composition root menyerahkan referensi ke state dan UI yang membutuhkan (dependency injection lewat fungsi setup). Pihak yang cuma perlu *tahu* perubahan cukup mendengarkan `EventBus`.

Jadi "deck" dipecah dua:

| Konsep | Tempat | Umur |
|---|---|---|
| **Deck sebagai koleksi**: 15 kartu milik pemain | `GameState` (autoload) | Sepanjang game, ikut di-save |
| **Deck sebagai tumpukan**: draw pile, discard pile, hand | `DeckController` + `HandManager` (di BattleScene) | Satu battle |

---

## 5. State Management: Dua Lapis

### 5.1 Lapis global (di GameState + SceneRouter)

```
BOOT ──► MENU ──► MAP ──► BATTLE ──► MAP ...
           │        │
           └────────┴──► PUSTAKA
```

Lapis ini sederhana. Cukup enum di `GameState` yang diubah oleh `SceneRouter` setiap kali pindah scene.

### 5.2 Lapis battle (BattleStateMachine)

Node-based state machine: setiap state adalah child Node dengan script turunan satu base `BattleState`. Hanya satu state yang aktif dalam satu waktu.

```
BattleStart ──► TurnStart ──► PlayerAction ◄──► Resolving
                   ▲                │                │
                   │            (End Turn)     (HP semua Buto habis) ──► Victory
                   │                ▼
                   │            TurnEnd
                   │                │
                   │                ▼
                   └──────────── EnemyTurn ──(HP hero habis)──► Defeat
```

| State | Kapan masuk | Yang dikerjakan |
|---|---|---|
| `BattleStart` | Scene siap | Spawn Buto dari `EncounterData`, buat 15 `CardInstance`, kocok deck, putar BGM |
| `TurnStart` | Awal setiap turn | Isi ulang AP, tarik kartu sampai batas hand, Buto memilih intent lalu ditampilkan, proses durasi status |
| `PlayerAction` | Menunggu input | **Satu-satunya state yang menerima input.** Pilih target, mainkan kartu, geser kartu, Ultimate, End Turn |
| `Resolving` | Ada Command di antrean | Input dikunci, tunggu `ActionQueue` kosong (termasuk animasi), lalu cek menang/kalah |
| `TurnEnd` | Pemain tekan End Turn | Urus sisa kartu di tangan (dibuang/disimpan sesuai aturan), efek akhir turn |
| `EnemyTurn` | Setelah TurnEnd | Setiap Buto menjalankan intent-nya lewat `ActionQueue`, satu per satu |
| `Victory` / `Defeat` | Kondisi terpenuhi | Tampilkan `ResultPanel`, update `GameState`, minta `SaveManager` menyimpan |

Mengunci input di luar `PlayerAction` adalah cara paling murah untuk mencegah bug klasik, misalnya pemain klik kartu dua kali dengan cepat lalu AP terpotong dua kali.

---

## 6. Tanggung Jawab Tiap Sistem di `Systems`

### DeckController
- Menyimpan `draw_pile` dan `discard_pile` (isinya `CardInstance`).
- Saat battle mulai: membuat 15 `CardInstance` dari `GameState`, lalu mengocoknya.
- Saat draw pile habis: discard pile dikocok ulang jadi draw pile. Inilah "cycle" pada Tactical Cycle.
- **Invariant penting:** jumlah kartu dasar di draw + tangan + discard + yang "tertelan" di dalam kartu hybrid selalu 15. Saat kartu hybrid dibuang, ia dipecah lagi menjadi dua kartu asalnya ke discard pile. Dengan begitu deck tidak pernah menyusut.

### HandManager
- Menyimpan isi tangan sebagai **array berurutan**. Urutan itu penting karena merge didasarkan pada kartu yang bersebelahan.
- Operasi: tambah, ambil, geser dari posisi A ke B, ganti dua kartu bersebelahan dengan satu kartu hasil merge.
- **Tidak** mengecek AP. Pengecekan AP dilakukan di Command, supaya aturan biaya ada di satu tempat.

### MergeResolver (RefCounted, bukan Node)
- Logika murni: menerima dua `CardInstance`, mengembalikan kartu hasil merge atau "tidak bisa".
- Syarat: tipe berbeda dan rank sama, lalu cari `MergeRecipe` di `CardDB`:
  - Serang + Fokus → **Crimson Focus**
  - Serang + Taktik → **Piercing Strike**
  - Fokus + Taktik → **Flow State**
- Dipanggil oleh `MoveCardCommand` setelah kartu digeser, dan dipakai `HandView` untuk menyalakan `MergeGlow`.

### PlayerState
Menggabungkan APController dan MoxieController dari rancangan awal, karena game ini memakai satu karakter. HP tetap diurus `HealthComponent` milik `HeroUnit`.
- **AP:** menyimpan AP sekarang dan AP maksimal, lalu mengisi ulang di `TurnStart`. `consume_ap()` menolak aksi kalau AP tidak cukup. Main kartu = 1 AP, geser kartu = 1 AP.
- **Moxie:** nilai 0–200. Ambang 100 = Ultimate bisa dipakai, di atas 100 = overcharge, 200 = penuh. Untuk sementara, Moxie dari kartu yang mengandung Fokus diatur lewat tabel per rank. Nantinya dipindah ke `MoxieGainEffect`.
- **Evolutionary Chain:** kalau dalam satu turn pemain memainkan 3 kartu ★3, `ultimate_damage_multiplier` naik permanen sampai battle selesai. Maksimal sekali per turn dan ada batas atasnya.

### TargetSelector
- Gaya Reverse: 1999: pemain mengetuk Buto untuk mengunci target, lalu semua kartu serang diarahkan ke situ. Jadi tidak perlu pilih target setiap kali main kartu.
- Kalau target mati, otomatis pindah ke Buto lain yang masih hidup.

### EnemyDirector
- Saat `TurnStart`: meminta `Brain` setiap Buto memilih intent berikutnya, lalu `IntentIcon` ditampilkan agar pemain bisa membaca niat musuh.
- Saat `EnemyTurn`: mengubah intent menjadi Command dan memasukkannya ke `ActionQueue`.

### ActionQueue + Command
Semua aksi, dari pemain maupun musuh, dibungkus menjadi Command:
`PlayCardCommand`, `MoveCardCommand`, `UltimateCommand`, `EnemyActionCommand`, `EndTurnCommand`.

Setiap Command melewati tiga tahap:
1. **Validate**: AP cukup? target valid? kartu masih ada di tangan?
2. **Execute**: mengubah data (AP, hand, HP, Moxie).
3. **Present**: menunggu animasi selesai sebelum Command berikutnya jalan.

Manfaatnya: animasi tidak tumpang tindih, cek AP hanya di satu tempat, ada log aksi untuk debugging, dan fitur undo geser kartu jadi mudah kalau nanti diinginkan.

### Helper logika murni (RefCounted)
- `DamageCalculator`: base power × rank × buff/debuff × crit.
- `MergeResolver`: sudah dijelaskan di atas.

Keduanya cocok dites dengan GUT atau gdUnit4 karena tidak butuh scene.

---

## 7. Lapisan Data (Custom Resource)

| Resource | Isi | Contoh file |
|---|---|---|
| `CardData` | id, nama, tipe (`SERANG`, `FOKUS`, `TAKTIK`, `HYBRID`), rank, ikon, art, deskripsi, daftar `CardEffect` | `serang_r1.tres` |
| `CardEffect` (base) | Dipecah jadi turunan: `DamageEffect`, `MoxieGainEffect`, `ApplyStatusEffect`, `DrawEffect`, dst. Satu kartu bisa punya beberapa efek. | dipasang di dalam `CardData` |
| `MergeRecipe` | tipe A, tipe B, kartu hasil untuk tiap rank | `recipe_serang_fokus.tres` |
| `DeckList` | Array 15 `CardData` | `starter_deck.tres` |
| `EnemyData` | nama, HP, SpriteFrames, `AIBrain`, resistensi, teks Pustaka | `buto_merah.tres` |
| `AIBrain` (base) | Turunan: `PatternBrain` (urutan tetap), `WeightedBrain` (acak berbobot), `BossPhaseBrain` | dipasang di `EnemyData` |
| `StatusEffectData` | nama, ikon, durasi, stack, efek per turn | `status_terbakar.tres` |
| `EncounterData` | daftar Buto + slot, background, BGM | `stage_03.tres` |
| `BattleConfig` | AP per turn, batas kartu di tangan, Moxie maksimal, ambang Ultimate | `default_battle.tres` |

### CardInstance (RefCounted, bukan Resource)

Pembungkus runtime untuk satu kartu di dalam battle. Isinya: id unik, referensi ke `CardData`, modifier sementara, dan (khusus kartu hybrid) **dua kartu asal yang ditelannya**.

Kenapa tidak langsung pakai `CardData`? Karena Resource di Godot itu **dibagi pakai** (shared). Kalau satu kartu Serang diberi buff dengan cara mengubah `CardData`-nya, semua kartu Serang di deck ikut berubah. `CardInstance` mencegah hal itu.

---

## 8. Struktur Folder Proyek

```
res://
├── autoload/
│   ├── event_bus.gd
│   ├── card_db.gd
│   ├── game_state.gd
│   ├── save_manager.gd
│   ├── scene_router.tscn (+ .gd)
│   └── audio_manager.tscn (+ .gd)
├── core/                        ← logika, tidak menyentuh UI
│   ├── battle/
│   │   ├── states/              ← battle_state.gd (base) + 8 state
│   │   ├── commands/            ← command.gd (base) + turunannya
│   │   └── systems/             ← deck_controller, hand_manager, player_state, target, enemy_director, action_queue
│   ├── cards/                   ← card_instance.gd, merge_resolver.gd, damage_calculator.gd
│   └── components/              ← health_component.gd, status_component.gd
├── data/
│   ├── definitions/             ← script class_name: card_data.gd, enemy_data.gd, dst.
│   ├── cards/
│   │   ├── base/                ← serang, fokus, taktik per rank
│   │   └── hybrid/              ← crimson_focus, piercing_strike, flow_state per rank
│   ├── merge_recipes/
│   ├── decks/
│   ├── enemies/                 ← 5 file Buto
│   ├── encounters/
│   └── config/
├── scenes/
│   ├── boot/
│   ├── main_menu/
│   ├── stage_map/
│   ├── battle/                  ← battle_scene.tscn
│   ├── units/                   ← unit, hero_unit, buto_unit, buto_hitam
│   └── pustaka/
├── ui/
│   ├── battle_hud/
│   ├── card/                    ← card_view.tscn
│   ├── moxie_gauge/
│   └── common/                  ← tombol, panel, theme.tres
└── assets/
    ├── sprites/  (hero/, buto/, cards/, vfx/, backgrounds/)
    ├── audio/    (bgm/, sfx/: bedug, kentongan, korek, gong)
    └── fonts/    (font pixel)
```

---

## 9. Contoh Alur: Geser Kartu Lalu Terjadi Merge

1. Pemain men-drag sebuah `CardView` ke posisi lain. `HandView` hanya mengirim permintaan "geser dari slot 1 ke slot 3".
2. State `PlayerAction` menerima permintaan itu, membuat `MoveCardCommand`, memasukkannya ke `ActionQueue`, lalu pindah ke `Resolving` (input terkunci).
3. **Validate**: `PlayerState` masih punya minimal 1 AP? Posisi tujuan valid?
4. **Execute**: AP dipotong 1, lalu `HandManager` memindahkan kartu. `MergeResolver` mengecek kartu di kiri dan kanan posisi baru.
5. Ternyata tetangganya Fokus rank 1, kartu yang digeser Serang rank 1. Resep ditemukan di `CardDB`, maka `HandManager` mengganti dua kartu itu menjadi satu **Crimson Focus** (yang menyimpan kedua kartu asalnya).
6. `EventBus` mengirim `card_moved` lalu `cards_merged`. `HandView` memainkan animasi merge, `AudioManager` membunyikan "dung" bedug disusul "krek" korek (asal-usul nama Dongkrek, cocok dijadikan SFX merge).
7. **Present** selesai, `Resolving` mengecek menang/kalah, lalu kembali ke `PlayerAction`.

Alur main kartu kurang lebih sama: `PlayCardCommand` → potong 1 AP → jalankan setiap `CardEffect` ke target dari `TargetSelector` → `PlayerState` menambah Moxie jika ada efeknya dan mengecek Evolutionary Chain → `DeckController` membuang kartu (hybrid dipecah jadi dua) → cek menang/kalah.

---

## 10. Pengaturan Proyek untuk Pixel Art (Godot 4.x)

| Setting | Nilai |
|---|---|
| Rendering → Textures → Default Texture Filter | **Nearest** |
| Display → Window → Viewport Width / Height | 640 × 360 (atau 480 × 270) |
| Display → Window → Stretch → Mode | `viewport` |
| Display → Window → Stretch → Scale Mode | `integer` (tersedia sejak 4.2) |
| Rendering → 2D → Snap 2D Transforms to Pixel | Aktif |
| Font pixel (Import) | Antialiasing: None, Hinting: None |

---

## 11. Keputusan Desain yang Perlu Dikunci Sebelum Menulis Kode

Pertanyaan berikut berpengaruh langsung ke struktur di atas, jadi sebaiknya dijawab dulu:

1. **Pemicu merge:** otomatis saat dua kartu cocok bersebelahan, atau pemain harus menekan sesuatu?
2. **Rank hasil hybrid:** tetap sama dengan rank asal atau naik satu?
3. **Merge lanjutan:** apakah kartu hybrid bisa digabung lagi? Apakah sesama tipe dengan rank sama juga bisa naik rank seperti di Reverse: 1999?
4. **Sisa kartu di akhir turn:** dibuang semua (gaya FGO) atau disimpan ke turn berikutnya (gaya Reverse: 1999)?
5. **AP & hand:** berapa AP per turn dan berapa batas kartu di tangan?
6. **Ultimate:** memakan AP atau tidak? Apa beda efek di 100%, 150%, dan 200%?
7. **Jumlah karakter:** satu hero saja, atau party? Kalau party, kartu perlu tahu siapa pemiliknya dan `PlayerSide` berisi beberapa Unit.

Setelah ketujuh poin ini jelas, langkah paling masuk akal berikutnya adalah membuat script definisi Resource (`CardData`, `CardEffect`, `MergeRecipe`, `EnemyData`), karena semua sistem lain bergantung pada bentuk datanya.
