# Dongkrek: Legenda Eyang Palang

Game RPG turn-based bergaya pixel art yang terinspirasi dari kesenian **Dongkrek** dari Mejayan, Madiun. Kamu bermain sebagai Eyang Palang, sesepuh desa yang mengusir para Buto pembawa pagebluk. Senjatanya tongkat dan bunyi bedug serta korek.

Pertarungannya memakai mekanik **Tactical Cycle Synthesis**: 15 kartu jurus, ketukan yang terbatas, jurus yang bisa digabung, dan Gebrakan Dongkrek yang bisa diisi sampai 200%.

## Cara menjalankan

1. Unduh **Godot 4.7** versi standar (bukan .NET) dari <https://godotengine.org/download/>. Versi dari Steam juga bisa. Project ini diuji dengan Godot 4.7.2.
2. Buka Godot, pilih **Import**, lalu arahkan ke file `project.godot` di folder ini.
3. Tekan **F5** (atau tombol ▶ di kanan atas) untuk mulai bermain.

Pertama kali dibuka, Godot butuh beberapa detik untuk mengimpor gambar dan suara. Itu normal.

**Game terlihat kecil atau Layar Penuh tidak berfungsi saat dijalankan dari editor?** Sejak Godot 4.4, game berjalan *di dalam* editor (tab **Game**), sehingga pilihan Layar Penuh tidak berpengaruh. Supaya game terbuka di jendelanya sendiri: di tab Game, klik ikon **⋮** paling kanan di toolbar, hilangkan centang **Embed Game on Next Play**, lalu jalankan lagi. Di Mac, tombol jalankan adalah **⌘B** (F5 di Mac perlu ditekan bersama tombol fn).

## Cara bermain

Seluruh game bisa dimainkan dengan mouse.

| Aksi | Mouse | Keyboard |
|---|---|---|
| Mainkan kartu | Klik kartu, atau seret ke tubuh Buto | Angka 1–9 |
| Geser kartu (1 ketukan) | Seret kartu ke posisi lain | – |
| Gabung kartu (gratis) | Klik tombol rantai di antara dua kartu | – |
| Pilih target | Klik Buto | – |
| Gebrakan Dongkrek | Tombol gong | Q |
| Akhiri giliran | Tombol Akhiri Giliran | E atau Spasi |
| Jeda | Tombol II | Esc |

Aturan singkatnya:

- **Ketukan**: 4 ketukan setiap giliran, seperti satu *gatra* gamelan. Memainkan kartu 1 ketukan, menggeser kartu 1 ketukan. Kartu di tangan tidak dibuang di akhir giliran, dan tangan diisi ulang sampai 7 kartu.
- **Tiga jenis jurus**: Sabet (merah) memberi damage, Semedi (biru) mengisi Greget, Tangkis (hijau) memberi Tameng.
- **Menggabung jurus**: dua kartu bersebelahan yang beda warna tapi bintangnya sama bisa digabung.
  - Sabet + Semedi = **Tenaga Dalam** (damage besar + Greget)
  - Sabet + Tangkis = **Tangkis Balik** (damage + Tameng)
  - Semedi + Tangkis = **Manunggal** (Tameng + Greget + 1 ketukan)
- **Greget**: pada 100% **Gebrakan Dongkrek** siap dan menghantam semua Buto. Kalau ditahan sampai 200% (Greget Memuncak), damagenya dua kali lipat.
- **Wirama**: memainkan 3 kartu bintang 3 berturut-turut dalam satu giliran memperkuat Gebrakan Dongkrek sampai battle selesai.
- **Niat Buto**: ikon di atas kepala Buto menunjukkan rencananya di giliran berikutnya.

### Para Buto

| Buto | Ilmu |
|---|---|
| Kuning | **Hisap Greget**: serangannya menghisap Greget di atas 100% |
| Hijau | **Sembur Lara**: Lara menggerogoti nyawa tiap akhir giliran Buto |
| Merah | Pola tetap: serang, **Ancang-ancang**, lalu **Gebug Raksasa** |
| Putih | **Sirep**: kartu terkuatmu tidak bisa dipakai selama satu giliran |
| Hitam (bos) | Di sisa nyawa separuh ia murka: serangan naik dan kartu di tanganmu diacak |

Petualangan terdiri dari 5 babak di peta Mejayan. Setelah menang, Roro Ayu memberi satu **berkah** pilihan: menaikkan bintang dua kartu atau menambah nyawa maksimal. Babak yang sudah selesai boleh diulang untuk berkah tambahan.

Bahasa bisa diganti antara **Indonesia** dan **English** di menu Pengaturan. Progres tersimpan otomatis.

## Membuat versi siap main (export)

**Lewat editor Godot:**

1. Menu **Editor → Manage Export Templates → Download and Install** (sekali saja).
2. Menu **Project → Export**. Preset **Windows Desktop**, **Linux**, dan **Web** sudah disiapkan.
3. Pilih preset lalu **Export Project**. Hasilnya masuk ke folder `build/`.

**Lewat GitHub Actions:** workflow `.github/workflows/export.yml` otomatis membuat ketiga versi itu setiap ada push ke `main`/`master`, atau bisa dijalankan manual dari tab **Actions → Export game → Run workflow**. File jadinya bisa diunduh dari bagian *Artifacts* di halaman run.

Versi Web bisa langsung diunggah ke itch.io (pilih "This file will be played in the browser").

## Struktur folder

```
autoload/      GameState (progres & simpanan), CardDB, SceneRouter, AudioManager
core/          Logika battle: BattleManager, DeckController, HandManager, PlayerState, aksi
data/          Data kartu, resep merge, dan stage (dibuat oleh tools/generate_data.gd)
scenes/        Menu utama, peta, battle, Pustaka, ending, dan unit
ui/            Kartu, tangan, HUD, dialog, pengaturan, tooltip, titik peta
assets/        Sprite, latar, kartu, ikon, font, shader, musik, dan efek suara
localization/  Teks dua bahasa (dibuat oleh tools/strings_source.py)
tests/         Tes otomatis
tools/         Skrip pembuat aset, data, audio, dan simulasi keseimbangan
docs/          Dokumen arsitektur dan desain asli
```

## Untuk pengembang

Semua aset tambahan dibuat ulang dengan skrip, jadi kalau mau mengubah sesuatu cukup ubah skripnya lalu jalankan lagi:

```bash
python3 tools/build_assets.py      # sprite, kartu, ikon dari desain asli (butuh Pillow, numpy)
python3 tools/build_map.py         # gambar peta perjalanan
python3 tools/build_audio.py       # musik & efek suara (butuh numpy, scipy, ffmpeg)
python3 tools/strings_source.py    # teks dua bahasa -> localization/strings.csv
godot --headless -s tools/generate_data.gd      # data kartu & stage
godot --headless -s tools/simulate_balance.gd   # simulasi keseimbangan
```

Tes otomatis:

```bash
for t in tests/test_*.gd; do godot --headless -s "$t"; done
```

`test_campaign_flow.gd` menamatkan seluruh kampanye dengan klik mouse sungguhan, dari menu utama sampai ending (sekitar 25 detik).

Baris `ERROR` yang muncul di tes `test_battle_manager` dan `test_deck_hand` memang disengaja: tes itu sengaja memberi input salah untuk memastikan input tersebut ditolak.

### Keseimbangan

Hasil `simulate_balance.gd` (200 battle per stage). Bot "cerdas" menggabung kartu, menggeser kartu supaya bisa digabung, dan menyimpan Moxie. Bot "santai" memainkan kartu dari kiri saja.

| Stage | Lawan | Menang (cerdas) | Menang (santai) | Lama rata-rata |
|---|---|---|---|---|
| 1 | Kuning | 100% | 100% | 3–4 turn |
| 2 | Hijau + Kuning | 100% | 100% | 5–6 turn |
| 3 | Merah + Hijau | 100% | 99% | 5–6 turn |
| 4 | Putih + Merah | 98% | 93% | 7–8 turn |
| 5 | Hitam | 89% | 68% | 9–11 turn |

Angka HP dan serangan Buto ada di `tools/generate_data.gd`.

## Kredit

- Desain karakter, kartu, dan latar: pemilik proyek (lihat `docs/desain_asli/`)
- Font: Tiny5 dan Silkscreen, lisensi SIL Open Font License (`assets/fonts/OFL.txt`)
- Mesin: Godot Engine 4.7
- Terinspirasi dari kesenian Dongkrek, Mejayan, Kabupaten Madiun, Jawa Timur
