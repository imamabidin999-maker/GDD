# Rancangan Pembaruan v3: Supaya Pemain Tidak Bosan

Dokumen ini melanjutkan `03-rancangan-pembaruan-v2.md`. Isinya lima tambahan besar dan tiga tambahan kecil yang disetujui untuk dikerjakan semua. Angka di sini adalah angka awal; angka akhirnya ditentukan simulasi dan dicatat di bagian akhir.

Masalah utama yang mau diatasi: dari babak 1 sampai 10 pemain memegang 15 kartu yang jenisnya sama (Sabet, Semedi, Tangkis), jadi cara bermainnya cepat terasa berulang. Setelah tamat juga tidak ada alasan untuk bermain lagi.

---

## 1. Jurus Tabuh

Lima kartu baru yang diambil dari alat musik Dongkrek. Warnanya emas kecoklatan, dan kartu Tabuh **tidak bisa digabung**.

| Kartu | Ketukan | ★1 | ★2 | ★3 |
|---|---|---|---|---|
| **Tabuh Bedug** | 1 | 5 damage ke **semua** Buto | 8 | 12 |
| **Kentongan Titir** | 1, lalu **kembali 1** | Tarik 2 kartu | Tarik 2, Tameng 3 | Tarik 3, Tameng 5 |
| **Korek** | 1 | 4 damage, **mengosongkan Amuk** sasaran, Greget +10% | 6, +15% | 9, +20% |
| **Gong** | **2** | 18 damage | 26 | 36 |
| **Kenong** | **0** | Kartu berikutnya giliran ini +40% (damage dan Tameng) | +60% | +80% |

Cara mendapatkannya:

- **Berkah Jurus Tabuh**: setiap jenis Tabuh punya berkahnya sendiri ("Terima Tabuh Bedug"). Setelah dipilih, pemain memilih satu kartu di Jurus yang diganti. Kartu Tabuh yang masuk mendapat **bintang kartu yang diganti ditambah satu** (paling tinggi 3), seperti jurus lama yang ditempa ulang. Deck tetap 15 kartu. Masing-masing hanya sekali.
- **Laras Gamelan** (berkah): 2 kartu Tabuh terendah naik satu bintang. Muncul kalau ada Tabuh yang masih bisa naik.
- **Kejadian di perjalanan** (bagian 4) juga bisa memberi Tabuh, dengan aturan bintang yang sama.
- Kenong baru masuk undian setelah pemain punya 8 Bintang Dongkrek (bagian 2).

Kartu Tabuh bisa disirep dan ikut dihitung untuk Wirama kalau bintang 3.

## 2. Tantangan Babak dan Bintang Dongkrek

Setiap babak punya 3 bintang. Bintang pertama didapat dengan menang. Dua lainnya dari tantangan:

| Babak | ★2 | ★3 |
|---|---|---|
| 1 Desa Mejayan | Menang paling lama 4 giliran | Sisa Nyawa minimal 80% |
| 2 Rumpun Bambu | Gabung kartu minimal 3 kali | Menang tanpa Gebrakan |
| 3 Sendang | Lara tidak pernah lebih dari 3 | Menang paling lama 6 giliran |
| 4 Gapura | Kalahkan Buto Putih lebih dulu | Sisa Nyawa minimal 50% |
| 5 Tegal Ilalang | Buyarkan amukan Buto yang siap Ngamuk | Menang paling lama 7 giliran |
| 6 Alas Jati Peteng | Lara tidak pernah lebih dari 5 | Menang tanpa Gebrakan |
| 7 Kali Watu | Tameng menahan total 60 damage | Sisa Nyawa minimal 50% |
| 8 Jembatan Pring | Paling banyak 2 kartu tersirep | Menang paling lama 8 giliran |
| 9 Pelataran Candi | Tidak ada Buto yang sempat Ngamuk | Sisa Nyawa minimal 40% |
| 10 Candi Pagebluk | Buyarkan Ajian 2 kali | Kalahkan kedua Bala sebelum Buto Hitam |

Bintang tidak harus didapat sekaligus; tiap tantangan dicatat sendiri. Bintang Dongkrek seperti rekor: tidak hilang saat memulai Petualangan Baru. Bintang tampil di bawah titik peta, daftar tantangan ada di panel info, dan jumlah totalnya di bar atas peta. Setelah menang muncul panel "Hasil Tantangan".

Hadiah Bintang Dongkrek (total 30):

| Bintang | Hadiah |
|---|---|
| 8 | Kenong masuk ke undian berkah |
| 16 | Tombol "Pilihan lain": sekali di setiap panel berkah, tiga pilihan bisa diundi ulang |
| 24 | Ruwatan dimulai dengan satu berkah acak |
| 30 | Gelar "Juru Dongkrek" di menu utama dan aura emas Eyang Palang |

## 3. Gebrakan Dongkrek Berirama

Saat Gebrakan dipakai, muncul lintasan irama singkat: 6 ketukan "dung" dan "krek" berjalan ke lingkaran sasaran. Tekan klik kiri, Spasi, atau Enter tepat saat ketukan masuk lingkaran.

- Tepat (±70 ms) bernilai 1, cukup (±140 ms) bernilai ½, meleset 0.
- Bonus damage Gebrakan = nilai rata-rata × 30%. Paling besar +30%.
- Meleset semua tidak mengurangi damage. Ritme bisa dimatikan di Pengaturan (tanpa bonus).
- Saat ritme berjalan, kecepatan battle dikembalikan ke 1x.

## 4. Kejadian di Perjalanan

Setelah kemenangan **pertama** di babak 2, 4, 6, dan 8 muncul satu kejadian acak (tidak berulang) di peta. Setiap kejadian punya 2 pilihan.

| Kejadian | Pilihan A | Pilihan B |
|---|---|---|
| Warga Kena Pagebluk | Rawat dia: Nyawa maks −5, warga memberi Kentongan Titir | Doakan dan lanjut: tidak terjadi apa-apa |
| Pande Gamelan | Tempa satu jurus pilihan (+1 bintang) | Minta dibuatkan Gong |
| Mbok Jamu Gendong | Minum jamu: Nyawa maks +5 | Bawa bekal Beras Kencur (berkahnya, atau Nyawa maks +5 kalau sudah punya) |
| Latihan bersama Roro Ayu | Latih jurus: satu kartu acak naik bintang | Belajar Korek |
| Sesajen di Bawah Beringin | Berdoa: satu kartu acak naik bintang | Bakar kemenyan: Greget Leluhur (atau Nyawa maks +5) |
| Peronda Desa | Pinjam bedugnya: Tabuh Bedug | Ikut ronda: Nyawa maks +8, satu kartu acak turun bintang |
| Buto Kecil Tersesat | Usir dengan bunyi Dongkrek: satu kartu Tabuh naik bintang (atau kartu acak) | Tunjukkan jalan pulang: Nyawa maks +8 |
| Pengamen Kenong | Beli kenongnya: Kenong (Nyawa maks −5) | Dengarkan saja: Nyawa maks +3 |

Kejadian yang belum selesai tersimpan, jadi tidak hilang kalau game ditutup.

## 5. Mode Ruwatan

Terbuka setelah tamat sekali (tetap terbuka walau memulai petualangan baru), dari menu utama. Ruwatan adalah perjalanan acak 8 langkah:

1. Battle (dua Buto biasa)
2. Battle (dua Buto biasa)
3. Kejadian
4. Battle (Buto Murka + pendamping)
5. Battle (Buto Murka + pendamping)
6. Kejadian
7. Battle (sepasang Buto Murka)
8. Bos: Buto Hitam

- Mulai dari deck awal dan 70 Nyawa, tanpa berkah. Setiap menang dapat berkah (3 pilihan, tanpa aturan kemenangan pertama).
- **Nyawa terbawa** antar battle dan pulih 45% Nyawa maksimal setelah menang.
- Kalah berarti Ruwatan selesai. Hasil terbaik (langkah terjauh) dicatat per tingkat.
- Ruwatan yang sedang berjalan tersimpan dan bisa dilanjutkan. Keluar di tengah battle tidak mengubah Nyawa; battle yang sama diulang saat kembali.
- Warna Buto, kejadian, dan urutannya ditentukan dari seed saat Ruwatan dimulai, jadi seluruh jalur bisa dilihat dari awal.
- Tingkat kesulitan cerita (Santai/Normal/Sulit) tidak berlaku di Ruwatan; Tingkat Pagebluk yang menggantikannya.

Angka Buto di Ruwatan lebih ringan daripada babak cerita karena Nyawa terbawa dan berkah datang sambil jalan:

| Peran | Kuning | Hijau | Merah | Putih |
|---|---|---|---|---|
| Pemimpin (langkah 1-2) | 80 / 9 | 88 / 9 | 104 / 9 | 116 / 11 |
| Pendamping | 56 / 8 | 60 / 8 | 68 / 8 | 68 / 8 |
| Buto Murka (langkah 4-5) | 120 / 10 | 114 / 9 | 140 / 9 | 172 / 12 |
| Sepasang Murka (langkah 7) | 92 / 9 | 88 / 8 | 104 / 8 | 120 / 10 |

Angka ditulis Nyawa / serangan. Battle kedua dari jenis yang sama (langkah 2 dan 5) mendapat Nyawa +5%. Buto Hitam di Ruwatan: 370 Nyawa, serangan 15.

**Tingkat Pagebluk** (berlaku menumpuk). Menang di tingkat N membuka tingkat N+1.

| Tingkat | Tambahan |
|---|---|
| 1 | Ruwatan biasa |
| 2 | Nyawa Buto +10% |
| 3 | Serangan Buto +10% |
| 4 | Pemulihan setelah menang hanya 35% |
| 5 | Buto biasa juga bisa Ngamuk |
| 6 | Pilihan berkah hanya 2 |
| 7 | Setiap battle dimulai dengan 1 Lara |
| 8 | Nyawa Buto +20% (menggantikan +10%) |
| 9 | Buto Hitam memanggil 3 Bala |
| 10 | Ambang Buyarkan Ajian +10, Pagebluk Merata +1 Lara lagi |

Catatan penyetelan: rancangan awal memakai pemulihan 40%/25% dan 2 Lara di tingkat 7. Simulasi (bot memilih berkah dan kejadian secara acak) menunjukkan tebing yang terlalu curam di tingkat 4 dan 7, dan angka Buto setara babak cerita membuat tingkat 1 hanya 18% berhasil untuk bot cerdas. Setelah disetel, bot cerdas berhasil sekitar 86% di tingkat 1 dan turun bertahap sampai sekitar 7% di tingkat 10.

## 6. Tambahan Kecil

- **Kecepatan battle 1x/2x**: tombol di samping tombol jeda, tersimpan di Pengaturan.
- **Petunjuk mekanik**: saat Lara, Sirep, Ngamuk, Prayitna, Ajian, Bala, Buto Murka, atau kartu Tabuh pertama kali muncul, tampil petunjuk singkat di atas layar. Hanya sekali; bisa dimatikan di Pengaturan.
- **Tingkat kesulitan cerita**: Santai (Nyawa Buto −20%, serangan −15%), Normal, Sulit (Nyawa dan serangan +15%). Bisa diganti kapan saja di Pengaturan. Tidak berlaku di Ruwatan.

## 7. Urutan Pengerjaan

| Tahap | Isi |
|---|---|
| 8 | Dokumen ini, kecepatan, petunjuk, kesulitan |
| 9 | Jurus Tabuh |
| 10 | Tantangan dan Bintang Dongkrek |
| 11 | Gebrakan berirama |
| 12 | Kejadian di perjalanan |
| 13 | Mode Ruwatan |
| 14 | Keseimbangan, tes, dokumentasi |

## 8. Hasil Akhir dan Catatan Keseimbangan

Semua tahap 8 sampai 14 sudah dikerjakan. Beberapa hal yang berubah dari rancangan awal setelah dicoba dan disimulasikan:

- **Kartu Tabuh dan aturan bintang +1.** Waktu Tabuh pertama kali masuk, angka menang bot turun tajam (bot cerdas 23–63% di babak akhir). Sebagian karena kartu Tabuh bintang 1 menggantikan kartu yang sudah ditempa, jadi dibuat aturan "bintang kartu yang diganti ditambah satu". Penyebab terbesarnya ternyata ada di bot simulasi: bot cerdas menggeser kartu Tabuh untuk digabung padahal Tabuh tidak bisa digabung, sehingga Ketukannya terbuang. Setelah bot diperbaiki, angkanya kembali normal.
- **Kejadian di perjalanan ikut disimulasikan.** Simulasi cerita sekarang memberi kejadian acak setelah babak 2, 4, 6, dan 8, sama seperti di game. Dengan kejadian, keseimbangan mode cerita kembali ke profil v2 tanpa perlu mengubah angka Buto.
- **Ruwatan.** Angka Buto dibuat lebih ringan daripada babak cerita, pemulihan dinaikkan ke 45%/35%, dan tingkat 7 memakai 1 Lara. Rinciannya ada di bagian 5.

Hasil simulasi akhir, kesulitan Normal, 200 battle per babak (berkah dan kejadian dipilih acak):

| Babak | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Bot cerdas | 100% | 100% | 100% | 93% | 99% | 99% | 98% | 96% | 99% | 97% |
| Bot santai | 100% | 100% | 97% | 83% | 81% | 73% | 81% | 85% | 86% | 57% |

Kesulitan Santai: bot santai menang 87–100% di setiap babak. Kesulitan Sulit: bot cerdas 57–100%, bot santai 25–100%.

Ruwatan, 200 perjalanan per tingkat:

| Tingkat | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Bot cerdas | 88% | 71% | 58% | 42% | 46% | 38% | 32% | 15% | 12% | 7% |
| Bot santai | 28% | 14% | 6% | 3% | 4% | 2% | 2% | 1% | 0% | 0% |

Bot memilih berkah dan pilihan kejadian secara acak, jadi angka ini lebih rendah daripada pemain yang memilih dengan cermat. Bonus irama Gebrakan juga tidak dihitung. Selisih tingkat 4 dan 5 masih dalam batas acak simulasi.

Tes baru untuk pembaruan ini: `test_tabuh`, `test_challenges`, `test_rhythm`, `test_events`, dan `test_ruwatan`. `test_campaign_flow` sekarang ikut melewati pemilih kartu Tabuh, panel Hasil Tantangan, empat kejadian di perjalanan, dan satu Ruwatan sampai panel hasil.

## 9. Perubahan Setelah Uji Main

Masukan dari uji main dan cara menanganinya:

1. **Tutorial dan bunyi Gebrakan.** Saat Greget pertama kali penuh, Eyang Palang menjelaskan Gebrakan dalam tiga baris dialog. Saat irama pertama kali muncul ada layar cara bermain dengan tombol Mulai, dan Pengaturan punya tombol "Coba" untuk latihan. Gebrakan punya iringan sendiri (`gebrakan_iringan.ogg`) dan bunyi pukulan sendiri (`gebrakan.ogg`); musik battle dipelankan selama irama.
2. **Latar.** Latar lama hanya desain 160x160 yang diperbesar dan diburamkan. Sekarang setiap babak, menu, dan ending punya latar sendiri yang digambar piksel demi piksel di ukuran layar oleh `tools/build_backgrounds.py`.
3. **Dialog asal-usul.** Tidak ada tokoh yang menyebut Dongkrek sebelum ending. Mereka hanya mengenal bunyi dung dan krek dari wangsit Eyang Palang, dan di ending tabuhan itu diberi nama. Gebrakan Dongkrek menjadi Gebrakan Dung-Krek.
4. **Kenong pada Semedi.** Kenong menaikkan Greget kartu Semedi, bukan damage-nya. Sabet dan Tangkis tetap naik damage dan Tamengnya.
5. **Irama Gebrakan.** Diuji dengan klik dan Spasi sungguhan, input-nya tidak hilang; masalahnya irama terlalu rapat dan jendela penilaian sempit. Tempo sekarang 700 ms per ketukan tanpa setengah ketukan, ada empat hitungan kentongan, jendela tepat 90 ms dan cukup 180 ms, dan tekanan yang terlalu cepat diberi tanda.
6. **Tameng Ajian.** Buto Hitam bertameng 15 saat ancang-ancang Ajian. Hanya damage yang menembus Tameng yang mengisi bar Buyarkan.
7. **Keterangan ikon.** Ikon niat, api Amuk, x2, perisai Bala, Tameng, Lara, Prayitna, dan bar Buyarkan menampilkan penjelasan saat disorot.
8. **Babak 9.** Keempat Buto Murka diperkuat ke Nyawa 80/85/95/95 dan serangan 7-8. Versi Murka penuh (seperti babak 5-8) membuat bot cerdas pun kalah di semua percobaan, jadi dipakai titik tengah.

Hasil simulasi setelah perubahan ini (kesulitan Normal): bot cerdas 80% di babak 9 dan 91% di babak 10, bot santai 45% dan 35%. Ruwatan: bot cerdas 80% di tingkat 1 sampai 3% di tingkat 10.

## 10. Nama Ultimate dan Bunyi Kartu

- Nama "Gebrakan Dung-Krek" terasa janggal, jadi ultimate Eyang Palang sekarang bernama **Sapu Jagad**: "menyapu seisi jagad", nama yang juga dikenal sebagai ajian dalam cerita rakyat Jawa. Di game, bedug dan korek ditabuh serentak dan gelegarnya menyapu semua Buto sekaligus. (Sempat dinamai Gelap Ngampar sebelum dipilih Sapu Jagad.) Nama kode di dalam skrip (`RhythmGebrakan`, bunyi `gebrakan`) tidak berubah.
- Kartu sekarang punya bunyi sendiri: gabung (hembusan, dua nada saron naik, kenong), main (kibasan kartu), tarik dari dek (jentikan kertas, berurutan saat beberapa kartu masuk), angkat (tik kayu), taruh setelah digeser (tok kayu), dan sorot (tik halus). Bunyi gabung terdengar baik lewat tombol rantai maupun saat kartu digeser bersebelahan. Saat tumpukan buangan dikocok kembali ke dek, bunyi kocok terdengar.

## 11. Tombol Keyboard yang Bisa Diubah

- Pengaturan punya baris **Tombol keyboard** dengan tombol **Atur**. Panelnya mendaftar semua aksi dalam dua kelompok: Pertarungan (Sapu Jagad, Akhiri giliran, Ganti sasaran, Kecepatan 1x/2x, Jeda) dan Kartu di tangan (kartu ke-1 sampai ke-9). Setiap aksi punya dua tombol.
- Cara mengganti: klik kotak tombol, lalu tekan tombol barunya. Klik kanan atau Backspace mengosongkan, Esc membatalkan. Satu tombol hanya punya satu arti: kalau tombol baru sudah dipakai aksi lain, tombol itu dipindah dan pemain diberi tahu ("Q dipindah dari Sapu Jagad ke Akhiri giliran").
- Esc dikunci untuk jeda, kembali, dan membatalkan, supaya pemain tidak pernah terkunci di satu layar. Slot kedua Jeda tetap bisa diisi.
- Dua aksi baru: **Ganti sasaran** (Tab) untuk berpindah Buto tanpa mouse, dan **Kecepatan 1x/2x** (F).
- Yang disimpan adalah letak tombol di keyboard (physical keycode), bukan hurufnya, jadi tetap pas di keyboard AZERTY atau QWERTZ. Nama yang ditampilkan mengikuti tata letak keyboard pemain.
- Teks yang menyebut tombol (menu jeda, tutorial Sapu Jagad, layar cara bermain irama) memakai penanda `{ultimate}`, `{end_turn}`, dan seterusnya, yang diisi nama tombol pilihan pemain. Nama tombol juga tampil di pojok gong Sapu Jagad dan di keterangan tombol HUD.
- Logikanya ada di `core/input/key_bindings.gd`, panelnya di `ui/common/controls_panel.gd`, dan tesnya di `tests/test_keys.gd`.

## 12. Gambar Kartu Bernuansa Jawa dan Potret Roro Ayu

- Gambar tiga kartu dasar diganti supaya senada dengan kartu Tabuh (palet kayu dan perunggu, garis tepi gelap):
  - **Sabet**: pedang diganti **keris** luk lima, lengkap dengan pamor di bilah, ganja, mendak emas, dan deder kayu yang menunduk.
  - **Semedi**: mata diganti **padupan** perunggu dengan bara kemenyan dan tiga alur asap yang naik.
  - **Tangkis**: perisai bergaya Eropa diganti **tameng** prajurit Jawa yang lonjong runcing, berbingkai emas, dengan motif tumpal di ujung dan kawung di tengah.
- **Tangkis Balik**: mata tombak sebelumnya bergeser dari garis tangkainya. Tombak digambar ulang sehingga mata tombak, methuk emas, dan tangkai berada di satu garis lurus, dan garis anginnya tidak lagi menimpa tangkai.
- **Tenaga Dalam** tetap memakai mata merah, tetapi pedang kecil di belakangnya ikut diganti keris.
- **Roro Ayu** sekarang punya potret di kotak dialog, setengah badan dan menoleh tiga perempat ke kanan (ke arah teks). Potret ini sudah digambar ulang berdasarkan rujukan berikut:
  - Topeng Roro Ayu dalam Dongkrek digambarkan berwajah krem, cantik, dengan tatapan sendu dan senyum tipis. Itu yang dipakai untuk wajahnya: kulit kuning langsat, mata besar yang lembut dengan kelopak sedikit turun, dan senyum tipis.
  - Gambaran perempuan cantik dalam Serat Centhini: rambut hitam berkilau, kulit kuning langsat, leher jenjang, halus dan tenang.
  - Sanggul ukel konde gaya Solo letaknya rendah di tengkuk dan lonjong, jadi sanggulnya diturunkan ke tengkuk, dihias untaian melati dan tusuk konde emas.
  - Kebaya kutubaru (khas Jawa, ada bef di dada) dengan peniti renteng tiga bros, subang bermata merah, dan kalung tipis. Selendang di bahu dibuang karena lebih khas Bali.
  - Teknik potret piksel ala GBA: wajah tiga perempat yang sisi dekat dan jauhnya berbeda, shading menggerombol dengan 4-6 warna per bahan, bayangan bergeser ke merah-ungu dan kilau ke kuning, tanpa garis di bawah mata (membuat wajah tampak tua).
  - Potretnya dilukis oleh `tools/portrait_roro_ayu.py`: bentuk tiap bagian dibuat 8x lebih besar, diperkecil, lalu diwarnai bertingkat menurut arah cahaya; mata, alis, hidung, bibir, perhiasan, melati, dan sulaman ditempel per piksel.
