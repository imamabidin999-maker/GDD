# Dongkrek: Legenda Eyang Palang

Game RPG turn-based bergaya pixel art yang terinspirasi dari kesenian **Dongkrek** dari Mejayan, Madiun. Kisahnya berlatar sebelum kesenian itu punya nama: Mejayan sekitar tahun 1867, saat pagebluk melanda dan Eyang Palang mendapat wangsit bahwa para Buto takut pada bunyi bedug (dung) dan korek (krek). Kamu bermain sebagai Eyang Palang yang mengusir para Buto dengan tongkat dan tabuhan warga, sampai akhirnya tabuhan itu diberi nama Dongkrek.

Pertarungannya memakai mekanik **Tactical Cycle Synthesis**: 15 kartu jurus, ketukan yang terbatas, jurus yang bisa digabung, dan Sapu Jagad yang bisa diisi sampai 200%.

Petualangannya berisi 10 babak cerita. Di sepanjang jalan ada kartu Tabuh dari alat musik Dongkrek, tantangan untuk mengumpulkan Bintang Dongkrek, dan kejadian kecil di perjalanan. Setelah tamat, mode **Ruwatan** terbuka: perjalanan acak delapan langkah dengan sepuluh Tingkat Pagebluk.

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
| Sapu Jagad | Tombol gong | Q |
| Menabuh irama Sapu Jagad | Klik kiri | Spasi, Enter, atau Q |
| Akhiri giliran | Tombol Akhiri Giliran | E atau Spasi |
| Kecepatan battle 1x / 2x | Tombol 1x di atas | – |
| Jeda | Tombol II | Esc |

Aturan singkatnya:

- **Ketukan**: 4 ketukan setiap giliran, seperti satu *gatra* gamelan. Memainkan kartu 1 ketukan, menggeser kartu 1 ketukan. Kartu di tangan tidak dibuang di akhir giliran, dan tangan diisi ulang sampai 7 kartu.
- **Tiga jenis jurus**: Sabet (merah) memberi damage, Semedi (biru) mengisi Greget, Tangkis (hijau) memberi Tameng.
- **Menggabung jurus**: dua kartu bersebelahan yang beda warna tapi bintangnya sama bisa digabung.
  - Sabet + Semedi = **Tenaga Dalam** (damage besar + Greget)
  - Sabet + Tangkis = **Tangkis Balik** (damage + Tameng)
  - Semedi + Tangkis = **Manunggal** (Tameng + Greget + 1 ketukan)
- **Greget**: pada 100% **Sapu Jagad** (bahasa Jawa: menyapu seisi jagad) siap: bedug dan korek ditabuh serentak dan gelegarnya menghantam semua Buto. Kalau ditahan sampai 200% (Greget Memuncak), damagenya dua kali lipat.
- **Wirama**: memainkan 3 kartu bintang 3 berturut-turut dalam satu giliran memperkuat Sapu Jagad sampai battle selesai.
- **Niat Buto**: ikon di atas kepala Buto menunjukkan rencananya di giliran berikutnya. Arahkan kursor ke ikon itu (juga api Amuk, Tameng, Lara, perisai Bala, dan bar Buyarkan) untuk melihat artinya.
- **Kartu Tabuh** (bingkai emas): jurus dari alat musik Dongkrek. Didapat dari berkah atau kejadian di perjalanan, dan tidak bisa digabung. Lihat bagian Jurus Tabuh di bawah.
- **Petunjuk**: saat sebuah mekanik muncul pertama kali (Buto Murka, Ngamuk, Lara, Sirep, Ajian, Bala, kartu Tabuh, dan lainnya), keterangan singkat tampil di pojok layar. Petunjuk bisa dimatikan di Pengaturan.

### Para Buto

| Buto | Ilmu |
|---|---|
| Kuning | **Hisap Greget**: serangannya menghisap Greget di atas 100% |
| Hijau | **Sembur Lara**: Lara menggerogoti nyawa tiap akhir giliran Buto |
| Merah | Pola tetap: serang, **Ancang-ancang**, lalu **Gebug Raksasa** |
| Putih | **Sirep**: kartu terkuatmu tidak bisa dipakai selama satu giliran |
| Hitam (bos) | Pola **Gebug Pagebluk** (serangan + Lara), Gebug, lalu **Ajian Lebur Saketi** yang bisa dibuyarkan. Di sisa nyawa separuh ia memanggil **Bala** dan menebar **Pagebluk Merata** |

### Buto Hitam

Saat ancang-ancang, Buto Hitam bertameng 15, lalu melepas **Ajian Lebur Saketi** di giliran berikutnya (40 damage + 3 Lara). Ajian itu **buyar** kalau di giliranmu kamu memberi 30 damage yang menembus Tamengnya (ada bar *Buyarkan* di atas bar nyawanya) atau memakai Sapu Jagad. Damage yang tertahan Tameng tidak ikut dihitung. Kalau buyar, Buto Hitam terhuyung dan kehilangan satu aksi.

Di sisa nyawa separuh ia murka:

- **Memanggil Bala** (sekali): dua Buto bayangan berwarna acak (35 nyawa, serangan 6) dengan ilmu warnanya masing-masing. Selama ada Bala yang hidup, Buto Hitam hanya menerima **separuh damage**. Bala lenyap kalau Buto Hitam tumbang.
- **Pagebluk Merata**: setiap akhir giliran Buto kamu mendapat 1 Lara, dan Lara tidak berkurang lagi.
- Ia mulai bisa **Ngamuk**, tapi tidak pernah di giliran ancang-ancang atau melepas Ajian.

### Buto Murka dan Ngamuk

Setelah babak 4, Buto Hitam membangkitkan keempat Buto yang sudah kalah menjadi **Buto Murka**: tubuhnya beraura merah keunguan dan ilmunya lebih kuat.

| Buto Murka | Bedanya |
|---|---|
| Kuning | Hisap Greget bekerja di level Greget berapa pun |
| Hijau | Sembur Lara dengan tenaga penuh dan 5 Lara |
| Merah | Langsung Ancang-ancang (sambil bertameng) lalu Gebug Raksasa yang lebih keras |
| Putih | Menyirep dua kartu terkuat sekaligus |

Semua Buto Murka bisa **Ngamuk**: setiap aksi mengisi satu titik Amuk (api di atas kepala). Setelah tiga titik penuh muncul tanda **x2**, dan giliran berikutnya Buto itu beraksi dua kali. Selama ada Buto yang siap Ngamuk, Eyang Palang mendapat **Prayitna**: Tameng dari semua kartu +50%. Sapu Jagad juga membuyarkan semua titik Amuk.

### Sepuluh babak

| Bagian | Babak |
|---|---|
| I. Kedatangan Buto | 1 Desa Mejayan, 2 Rumpun Bambu, 3 Sendang, 4 Gapura |
| II. Buto Murka | 5 Tegal Ilalang, 6 Alas Jati Peteng, 7 Kali Watu, 8 Jembatan Pring (masing-masing satu Buto Murka dan satu pendamping) |
| III. Candi Pagebluk | 9 Pelataran Candi (keempat Buto Murka sekaligus), 10 Candi Pagebluk (Buto Hitam) |

### Berkah Roro Ayu

Kemenangan **pertama** di setiap babak memberi satu berkah: pilih satu dari tiga pilihan acak. Babak yang diulang tidak memberi berkah lagi, jadi sepanjang petualangan ada 9 berkah.

| Berkah | Efek | Batas |
|---|---|---|
| Tempa Sabet / Olah Semedi / Laku Tangkis | 2 kartu tipe itu naik satu bintang | Selama masih ada yang bisa naik |
| Jamu Kunyit Asam | Nyawa maksimal +10 | 3 kali |
| Kendang Pembuka | +1 Ketukan di giliran pertama tiap battle | Sekali |
| Greget Leluhur | Tiap battle dimulai dengan Greget 30% | Sekali |
| Tameng Pusaka | Tameng 10 di giliran pertama tiap battle | Sekali |
| Jimat Penolak Sirep | Sirep pertama di tiap battle ditangkal | Sekali |
| Jamu Beras Kencur | Setiap kali menerima Lara, jumlahnya berkurang 1 | Sekali |

| Tabuh Bedug / Kentongan Titir / Korek / Gong / Kenong | Kartu Tabuh itu menggantikan satu kartu pilihanmu | Sekali per jenis |
| Laras Gamelan | 2 kartu Tabuh naik satu bintang | Selama masih ada yang bisa naik |

Kenong baru masuk undian setelah 8 Bintang Dongkrek. Berkah yang dimiliki terlihat di panel **Jurus** pada peta.

### Jurus Tabuh

Saat berkah kartu Tabuh dipilih, kamu memilih kartu mana yang diganti. Bintang kartu Tabuh yang masuk sama dengan bintang kartu yang diganti **ditambah satu** (paling tinggi bintang 3), jadi mengganti kartu yang sudah ditempa tidak sia-sia. Deck tetap 15 kartu.

| Kartu | Bintang 1 / 2 / 3 | Ketukan |
|---|---|---|
| Tabuh Bedug | 5 / 8 / 12 damage ke **semua** Buto | 1 |
| Kentongan Titir | +1 Ketukan, tarik 2 / 2 / 3 kartu, Tameng 0 / 3 / 5 | 1 |
| Korek | 4 / 6 / 9 damage, membuyarkan titik Amuk target, Greget +10 / 15 / 20% | 1 |
| Gong | 18 / 26 / 36 damage | 2 |
| Kenong | Kartu berikutnya giliran ini +40 / 60 / 80%: damage dan Tameng untuk Sabet dan Tangkis, Greget untuk Semedi | 0 |

### Kejadian di perjalanan

Setelah kemenangan pertama di babak 2, 4, 6, dan 8, sebuah kejadian menunggu di peta: Mbok Jamu Gendong, Pande Gamelan, Peronda Desa, Buto Kecil Tersesat, dan lainnya (ada delapan). Setiap kejadian punya dua pilihan, misalnya menukar sedikit Nyawa maksimal dengan kartu Tabuh, menempa satu kartu pilihanmu, atau menerima berkah. Kejadian yang sudah dialami tidak muncul lagi di petualangan yang sama.

### Tantangan dan Bintang Dongkrek

Setiap babak punya tiga **Bintang Dongkrek**: satu untuk menang, dua untuk tantangan babak itu (misalnya "menang paling lama 6 giliran", "Lara tidak pernah lebih dari 3", "kalahkan kedua Bala sebelum Buto Hitam"). Tantangan dan bintangnya terlihat di panel babak pada peta, dan hasilnya muncul setelah menang. Bintang tetap tercatat walau memulai petualangan baru.

| Bintang | Hadiah |
|---|---|
| 8 | Kenong masuk ke pilihan berkah |
| 16 | Tombol **Pilihan lain** (undi ulang sekali) di panel berkah |
| 24 | Ruwatan dimulai dengan satu berkah acak |
| 30 | Gelar **Juru Dongkrek** di menu utama dan aura emas Eyang Palang |

### Sapu Jagad berirama

Saat Sapu Jagad dipakai, iringan gamelannya sendiri mulai: empat hitungan kentongan (angka di lingkaran ikut menghitung mundur), lalu enam ketukan "dung" (bedug, bulat) dan "krek" (korek, kotak) datang ke lingkaran satu ketukan demi satu ketukan, sekitar 86 ketukan per menit. Klik, tekan Spasi, atau Q tepat saat ketukan masuk lingkaran. Selisih sampai 90 ms bernilai penuh, sampai 180 ms bernilai setengah, dan hasilnya menambah damage Sapu Jagad **sampai +30%**. Tekanan yang terlalu cepat diberi tanda tanpa menghabiskan ketukan, dan meleset semua tidak mengurangi damage. Musik battle dipelankan selama irama, lalu pukulannya ditutup bunyi dung-dung, krek, dan gong.

Saat Greget pertama kali penuh, Eyang Palang menjelaskan cara memakai Sapu Jagad, dan saat irama pertama kali muncul ada layar cara bermain. Irama bisa dicoba kapan saja lewat tombol **Coba** di Pengaturan, dan bisa dimatikan. Iramanya tidak ikut dipercepat oleh kecepatan battle 2x.

## Ruwatan

Mode ini terbuka setelah tamat sekali, dari tombol **Ruwatan** di menu utama, dan tetap terbuka walau kamu memulai petualangan baru. Ruwatan adalah perjalanan acak delapan langkah dengan deck, berkah, dan Nyawa sendiri:

1. Dua Buto biasa
2. Dua Buto biasa
3. Kejadian di perjalanan
4. Buto Murka dan pendampingnya
5. Buto Murka dan pendampingnya
6. Kejadian di perjalanan
7. Sepasang Buto Murka
8. Buto Hitam

- Mulai dengan jurus awal dan 70 Nyawa, tanpa berkah. Setiap menang dapat satu berkah.
- **Nyawa terbawa** dari battle ke battle dan hanya pulih 45% Nyawa maksimal setelah menang.
- Kalah berarti Ruwatan selesai. Langkah terjauh di setiap tingkat dicatat.
- Seluruh jalur (warna Buto dan letak kejadian) terlihat sejak awal. Ruwatan yang sedang berjalan tersimpan otomatis.

**Tingkat Pagebluk** berlaku bertumpuk, dan berhasil di satu tingkat membuka tingkat berikutnya. Tingkat kesulitan cerita tidak berlaku di Ruwatan.

| Tingkat | Tambahan |
|---|---|
| 1 | Ruwatan biasa |
| 2 | Nyawa Buto +10% |
| 3 | Serangan Buto +10% |
| 4 | Pemulihan setelah menang hanya 35% |
| 5 | Buto biasa juga bisa Ngamuk |
| 6 | Pilihan berkah tinggal dua |
| 7 | Setiap battle dimulai dengan 1 Lara |
| 8 | Nyawa Buto +20% (menggantikan +10%) |
| 9 | Buto Hitam memanggil 3 Bala |
| 10 | Ajian makin sulit dibuyarkan (+10) dan Pagebluk Merata menambah 1 Lara lagi |

## Pengaturan

- **Bahasa**: Indonesia atau English.
- **Musik, Efek Suara, Layar Penuh**.
- **Kesulitan** mode cerita: Santai (Nyawa Buto −20%, serangan −15%), Normal, atau Sulit (Nyawa dan serangan +15%). Bisa diganti kapan saja.
- **Kecepatan battle** 1x atau 2x (juga lewat tombol di atas layar battle).
- **Petunjuk** dan **Irama Sapu Jagad** bisa dinyalakan atau dimatikan. Tombol **Coba** di samping Irama Sapu Jagad membuka latihan irama.

Progres tersimpan otomatis.

Simpanan lama tetap bisa dipakai. Dari versi 5 babak, babak 1–4 tetap tercatat selesai, sedangkan babak 5 ke atas dibuka ulang karena isinya sudah berubah. Babak yang sudah selesai dianggap sudah memberi berkah, dan Jamu yang sudah diminum dihitung dari nyawa maksimal.

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
core/          Logika battle (BattleManager, DeckController, HandManager, PlayerState, aksi)
               dan progres (berkah, tantangan, kejadian di perjalanan, Ruwatan)
data/          Data kartu, resep merge, dan 10 babak (dibuat oleh tools/generate_data.gd)
scenes/        Menu utama, peta, battle, Ruwatan, Pustaka, ending, dan unit
ui/            Kartu, tangan, HUD, dialog, pengaturan, tooltip, titik peta, panel berkah,
               kejadian, tantangan, irama Sapu Jagad, dan pemilih kartu
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
python3 tools/build_backgrounds.py # latar battle tiap babak, menu, dan ending
python3 tools/build_audio.py       # musik & efek suara (butuh numpy, scipy, ffmpeg)
                                   # --gebrakan: hanya iringan dan bunyi Sapu Jagad
                                   # --kartu: hanya bunyi kartu (gabung, main, tarik, geser)
python3 tools/strings_source.py    # teks dua bahasa -> localization/strings.csv
godot --headless -s tools/generate_data.gd      # data kartu & stage
godot --headless -s tools/simulate_balance.gd   # simulasi keseimbangan
# opsi simulasi: -- runs=80 stages=9,10 hpx=0.9 atkx=1.1 set=bala_hp:40,ajian_break_threshold:35
#                -- noevents=1 notabuh=1   (tanpa kejadian / tanpa kartu Tabuh)
#                -- mode=ruwatan levels=1,5,10   (Ruwatan utuh per Tingkat Pagebluk)
```

Tes otomatis:

```bash
for t in tests/test_*.gd; do godot --headless -s "$t"; done
```

`test_campaign_flow.gd` menamatkan seluruh kampanye 10 babak dengan klik mouse sungguhan, dari menu utama sampai ending, termasuk berkah, kartu Tabuh, tantangan, dan kejadian di perjalanan, lalu menempuh satu Ruwatan sampai panel hasil (sekitar satu setengah menit).

Baris `ERROR` yang muncul di tes `test_battle_manager` dan `test_deck_hand` memang disengaja: tes itu sengaja memberi input salah untuk memastikan input tersebut ditolak.

### Keseimbangan

Hasil `simulate_balance.gd` di kesulitan Normal (200 battle per babak). Deck, nyawa, dan berkah bot diambil dari berkah acak di babak-babak sebelumnya, ditambah kejadian di perjalanan setelah babak 2, 4, 6, dan 8 (pilihannya juga acak). Bot "cerdas" menggabung kartu, menggeser kartu supaya bisa digabung, memilih kartu Tabuh sesuai keadaan, menyimpan Greget, membuyarkan Ajian, dan menghabisi Bala lebih dulu. Bot "santai" memainkan kartu dari kiri saja dan langsung memakai Sapu Jagad begitu siap. Bonus irama Sapu Jagad tidak ikut dihitung.

| Babak | Lawan | Menang (cerdas) | Menang (santai) | Lama rata-rata |
|---|---|---|---|---|
| 1 | Kuning | 100% | 100% | 3–4 giliran |
| 2 | Hijau + Kuning | 100% | 100% | 5–6 giliran |
| 3 | Merah + Hijau | 100% | 97% | 5–6 giliran |
| 4 | Putih + Merah | 93% | 82% | 7–8 giliran |
| 5 | Kuning Murka + Hijau | 99% | 82% | 6–7 giliran |
| 6 | Hijau Murka + Merah | 99% | 73% | 5 giliran |
| 7 | Merah Murka + Putih | 98% | 81% | 6–7 giliran |
| 8 | Putih Murka + Kuning | 96% | 84% | 8 giliran |
| 9 | Keempat Buto Murka | 80% | 45% | 6 giliran |
| 10 | Buto Hitam | 91% | 35% | 10–11 giliran |

Babak 9 dan 10 sengaja paling menuntut siasat. Di babak 9 keempat Buto Murka memakai Nyawa 80–95 dan serangan 7–8 (versi Murka penuh tidak bisa dimenangkan bot sama sekali, jadi dipilih titik tengah). Di babak 10 Buto Hitam bertameng saat menyiapkan Ajian, dan bot santai tidak pernah sengaja membuyarkan Ajian atau mengincar Bala. Di kesulitan Santai bot santai menang 64–100% di setiap babak; di kesulitan Sulit bot cerdas menang 48–100% dan bot santai 11–100%. Angka nyawa dan serangan Buto ada di `tools/generate_data.gd`, angka ilmu Buto Hitam dan Bala di `scenes/units/enemy_buto.gd`.

Ruwatan (`mode=ruwatan`, 200 perjalanan per tingkat; berkah dan kejadian dipilih acak, jadi pemain yang memilih dengan cermat akan lebih sering berhasil):

| Tingkat Pagebluk | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Berhasil (cerdas) | 80% | 67% | 46% | 29% | 34% | 40% | 25% | 11% | 9% | 3% |
| Berhasil (santai) | 17% | 7% | 4% | 1% | 1% | 1% | 0% | 0% | 0% | 0% |

Angka Buto Ruwatan dan aturan tiap tingkat ada di `core/progress/ruwatan_run.gd`. Catatan perancangan lengkap untuk pembaruan ini ada di `docs/04-rancangan-pembaruan-v3.md`.

## Kredit

- Desain karakter dan kartu: pemilik proyek (lihat `docs/desain_asli/`)
- Latar, peta, aset tambahan, musik, dan efek suara: digambar dan disintesis lewat skrip di `tools/`
- Font: Tiny5 dan Silkscreen, lisensi SIL Open Font License (`assets/fonts/OFL.txt`)
- Mesin: Godot Engine 4.7
- Terinspirasi dari kesenian Dongkrek, Mejayan, Kabupaten Madiun, Jawa Timur
