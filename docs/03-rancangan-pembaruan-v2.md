# Rancangan Pembaruan v2

Dokumen ini merangkum semua yang sudah kita sepakati dalam diskusi, ditambah detail yang perlu ada sebelum mulai coding. Angka nyawa dan serangan di sini adalah perkiraan awal. Angka finalnya akan diatur lewat simulasi seperti sebelumnya.

Bagian yang ditandai **(usulan saya)** belum pernah kita bahas. Silakan dicoret atau diubah kalau tidak cocok.

---

## 1. Perbaikan cepat

### 1.1 Pose serang Buto

Di desain asli, pose diam menghadap kanan sedangkan pose serang menghadap kiri. Kemarin keduanya dibalik, jadi pose serang sekarang malah menghadap kanan. Perbaikannya: **hanya pose diam yang dibalik**. Potret dialog, topeng di peta, dan gambar di Pustaka ikut pose diam, jadi semuanya tetap menghadap kiri.

### 1.2 Sirep (pengganti "kunci kartu")

| Aturan | Isi |
|---|---|
| Target | Kartu dengan **bintang tertinggi** yang belum tersirep. Kalau ada beberapa yang sama tinggi, dipilih acak di antara itu |
| Efek | Kartu **tidak bisa dimainkan, digeser, maupun digabung** |
| Lama | 1 giliran pemain. Sirep dipasang di giliran Buto, berlaku sepanjang giliranmu berikutnya, lalu lepas |
| Buto Putih biasa | Menyirep 1 kartu |
| Buto Putih Murka | Menyirep 2 kartu (dua bintang tertinggi) |
| Tampilan | Kartu menggelap, ada gembok dan sisa giliran. Kalau diklik, kartu bergetar dan muncul tulisan "Tersirep" |

Kartu yang tersirep tetap memakan tempat di tangan. Itulah yang membuat Sirep terasa sebagai gangguan sungguhan.

---

## 2. Istilah

Istilah Jawa dipakai di **kedua bahasa**. Di mode English istilahnya tetap sama, dan tooltip memberi arti singkat, misalnya *Greget (fighting spirit)*.

| Lama | Baru | Arti / alasan |
|---|---|---|
| AP | **Ketukan** | Satu *gatra* gamelan berisi 4 ketukan, dan Eyang punya 4 aksi per giliran |
| Turn | **Giliran** | |
| Moxie | **Greget** | Istilah tari Jawa untuk semangat dan daya hidup penari |
| Overcharge (100–200%) | **Greget Memuncak** | |
| Ultimate | **Gebrakan Dongkrek** | Bedug dan korek berbunyi serentak, bunyi yang mengusir Buto dalam legenda |
| Evolutionary Chain | **Wirama** | Satu dari tiga prinsip tari Jawa (wiraga, wirama, wirasa) |
| Kartu Serang / Fokus / Taktik | **Sabet / Semedi / Tangkis** | Sabetan tongkat; semedi seperti Eyang dalam legenda; tangkisan |
| Crimson Focus | **Tenaga Dalam** | Sabet + Semedi |
| Piercing Strike | **Tangkis Balik** | Sabet + Tangkis |
| Flow State | **Manunggal** | Semedi + Tangkis |
| Racun | **Lara** | "Sakit", dekat dengan pagebluk |
| HP | **Nyawa** | |
| Stage | **Babak** | Istilah pertunjukan |
| Deck / tumpukan / buangan | **Jurus / Jurus tersisa / Jurus terpakai** | |
| Kunci kartu | **Sirep** | Ilmu yang membuat tak berdaya |
| Serangan ganda | **Ngamuk**, pengisinya **Amuk** | |
| Buff penangkal Ngamuk | **Prayitna** | Bahasa Jawa: waspada, siaga |
| Tameng, Bintang, Niat, Berkah | tetap | Sudah dekat dengan nuansanya |

Catatan: Giliran, Nyawa, Babak, Jurus, Tameng, dan Bintang sebenarnya bahasa Indonesia. Saya pertahankan karena padanan Jawanya kurang dikenal pemain. Kalau mau semuanya Jawa, bilang saja.

Nama ilmu Buto:

| Buto | Ilmu |
|---|---|
| Kuning | **Hisap Greget** |
| Hijau | **Sembur Lara** |
| Merah | **Ancang-ancang** lalu **Gebug Raksasa** |
| Putih | **Sirep** |
| Hitam | **Ajian Lebur Saketi**, **Memanggil Bala**, **Pagebluk Merata** |

---

## 3. Sistem Ngamuk dan Prayitna

### 3.1 Ngamuk

- Buto yang punya sifat ini memiliki **3 titik Amuk** di bawah bar nyawanya.
- **Setiap aksi** Buto mengisi 1 titik: serangan, ilmu, Sirep, Ancang-ancang, dan lainnya.
- Begitu titik ketiga terisi, niat di atas kepalanya berubah menjadi **"Ngamuk ×2"**, dan tooltip-nya menampilkan dua aksi yang akan dilakukan. Pemain melihat peringatan ini satu giliran lebih awal.
- Di giliran berikutnya Buto beraksi **dua kali** berturut-turut, lalu titiknya kosong lagi. Kedua aksi itu tidak mengisi Amuk.

Yang punya sifat Ngamuk:

| Babak | Ngamuk? |
|---|---|
| 1–4 (Buto biasa) | Tidak |
| 5–9 (Buto Murka) | Ya. Buto pendamping biasa tidak |
| 10 (Buto Hitam) | Hanya di fase kedua |
| Bala (bayangan panggilan Buto Hitam) | Tidak |

**Babak 9 (empat Buto Murka):** titik awal tiap Buto dibedakan supaya **tidak pernah ada dua Buto yang ngamuk di giliran yang sama**. Usulan titik awal: Merah 2, Hijau 1, Kuning 0, Putih −1 (butuh satu aksi ekstra). Hasilnya, mulai giliran ke-2 tiap giliran ada tepat satu Buto yang ngamuk, bergiliran.

**Buto Hitam:** Ngamuk tidak pernah jatuh bersamaan dengan giliran Ajian. Kalau Amuk penuh tepat saat Ajian akan dilepas, ngamuknya ditunda ke giliran berikutnya.

### 3.2 Prayitna (buff Eyang Palang)

- Didapat **otomatis** di awal giliranmu kalau ada Buto yang sedang bersiap ngamuk (Amuk-nya penuh).
- Selama giliran itu, **Tameng dari semua kartu bertambah 50%**, dibulatkan ke atas. Ini berlaku untuk Tangkis, Tangkis Balik, dan Manunggal. Contoh: Tangkis bintang 2 memberi 8 → 12. **(usulan saya: berlaku untuk semua kartu bertameng, bukan hanya Tangkis)**
- Tampilan: ikon Prayitna di samping bar nyawa Eyang, tulisan "Prayitna!" di awal giliran, dan angka Tameng di kartu berubah hijau sesuai nilai yang sudah ditambah.

### 3.3 Gebrakan Dongkrek membuyarkan amukan

Memakai Gebrakan Dongkrek **mengosongkan titik Amuk semua Buto**, termasuk yang sudah siap ngamuk. Gebrakan juga **membuyarkan Ajian Lebur Saketi** milik Buto Hitam (lihat bagian 5). Aturannya satu dan mudah diingat: bunyi Dongkrek membuyarkan kekuatan Buto.

---

## 4. Buto Murka

Buto Hitam membangkitkan kembali keempat Buto yang sudah dikalahkan dan memberi mereka kekuatan pagebluk.

**Tampilan:** aura merah keunguan yang berdenyut di sekitar tubuh, nama menjadi "Buto Kuning Murka", dan titik Amuk di bawah bar nyawa. Tidak perlu gambar baru.

| Buto Murka | Bedanya dari versi biasa |
|---|---|
| Kuning Murka | Hisap Greget menyedot **20 Greget dari berapa pun**, bukan hanya kelebihan di atas 100% |
| Hijau Murka | Sembur Lara memberi **5 Lara** (biasa 3), dan damage semburannya **penuh** (biasa separuh serangan). Tetap dipakai setiap 2 giliran |
| Merah Murka | Pola lebih pendek, Ancang-ancang lalu Gebug, tanpa serangan biasa di antaranya. Gebug **×3** (biasa ×2,5). Saat Ancang-ancang ia mendapat Tameng 10 |
| Putih Murka | Menyirep **2 kartu** sekaligus |

Semua Buto Murka juga punya sifat **Ngamuk**.

---

## 5. Buto Hitam (bos babak 10)

### Fase 1 (nyawa di atas 50%)

Pola berulang:

1. **Gebug Pagebluk:** serangan biasa + 2 Lara
2. **Gebug:** serangan biasa
3. **Ancang-ancang Ajian:** tidak menyerang. Niatnya menampilkan "Ajian Lebur Saketi: 45"
4. **Ajian Lebur Saketi:** pukulan sangat keras (±45) + 3 Lara, **kecuali dibuyarkan**

**Membuyarkan Ajian.** Di giliranmu setelah ia Ancang-ancang, ajiannya buyar kalau salah satu terjadi:
- Kamu memberi total **±40 damage** ke Buto Hitam di giliran itu. Ada bar kecil "Buyarkan 12/40" di bawah bar nyawanya.
- Kamu memakai **Gebrakan Dongkrek**.

Kalau buyar, Buto Hitam **terhuyung** dan kehilangan aksi berikutnya.

### Fase 2 (nyawa 50% ke bawah)

Saat masuk fase ini muncul dialog singkat dan tulisan "Buto Hitam Murka!". Lalu:

- **Memanggil Bala (sekali):** muncul 2 Buto bayangan, dipilih acak dari Kuning, Hijau, Merah, dan Putih. Wujudnya gelap tembus pandang, nyawa ±50, dan memakai ilmu warnanya masing-masing. Selama masih ada Bala yang hidup, Buto Hitam hanya menerima **separuh damage**, ditandai ikon perisai di atas kepalanya. **(usulan saya: Bala hanya dipanggil sekali)**
- **Pagebluk Merata:** di akhir setiap giliran Buto, Eyang mendapat **+1 Lara**, dan **Lara tidak berkurang** selama fase ini. Tekanannya terus naik, jadi pemain didorong untuk segera menuntaskan pertarungan.
- **Ngamuk** aktif.
- Ajian Lebur Saketi tetap ada, dengan pola yang sama.

Ilmu lama (mengacak tangan) **dihapus**.

---

## 6. Sepuluh Babak

| # | Tempat (rekaan, kecuali Mejayan) | Lawan | Perkiraan nyawa / serangan |
|---|---|---|---|
| **Bagian I – Kedatangan Buto** | | | |
| 1 | Pinggir Desa Mejayan | Kuning (tutorial) | 95 / 10 |
| 2 | Rumpun Bambu Wingit | Hijau + Kuning | 110 / 11, 70 / 9 |
| 3 | Sendang Larangan | Merah + Hijau | 140 / 11, 80 / 9 |
| 4 | Gapura Candi Tua | Putih + Merah | 160 / 15, 135 / 12 |
| **Bagian II – Buto Murka** | | | |
| 5 | Tegal Ilalang | **Kuning Murka** + Hijau | 170 / 13, 90 / 10 |
| 6 | Alas Jati Peteng | **Hijau Murka** + Merah | 190 / 13, 110 / 11 |
| 7 | Kali Watu | **Merah Murka** + Putih | 220 / 14, 120 / 12 |
| 8 | Jembatan Pring | **Putih Murka** + Kuning | 230 / 15, 110 / 11 |
| **Bagian III – Candi Pagebluk** | | | |
| 9 | Pelataran Candi | **Keempat Buto Murka** | ±120–150 / 12–13 masing-masing |
| 10 | Candi Pagebluk | **Buto Hitam** | ±520 / 18 (+2 Bala ±50 / 9) |

**(usulan saya)** Babak 5–8 diberi satu Buto biasa sebagai pendamping supaya ada variasi dan pemain harus memilih target. Kalau mau Buto Murka sendirian saja, bisa.

**Target tingkat kesulitan** (diukur dengan bot simulasi):
- Babak 1–4: bot cerdas hampir selalu menang.
- Babak 5–9: bot cerdas menang ±90–95%, bot santai ±70–85%.
- Babak 10: bot cerdas ±85%, bot santai ±55–65%.

**Babak 9:** layar battle diberi tata letak untuk 4 Buto, masing-masing sedikit diperkecil.

**Peta:** digambar ulang dengan 10 titik. Bagian I di sekitar desa, sama seperti sekarang. Bagian II berupa jalan memutar lewat tegal, hutan jati, sungai berbatu, dan jembatan bambu. Bagian III ada di pelataran dan candi. Semua tempat selain Mejayan adalah rekaan, dan Pustaka sudah menyebutkannya.

### Alur cerita singkat

- **Setelah babak 4:** saat Eyang menembus gapura, Buto Hitam muncul dalam bayangan dan membangkitkan keempat Buto dengan kekuatan pagebluk. Mereka kabur ke empat penjuru.
- **Babak 5–8:** Eyang mengejar tiap Buto Murka. Roro Ayu memberi petunjuk tentang Ngamuk dan Prayitna lewat dialog singkat di babak 5.
- **Babak 9:** keempat Buto menghadang di pelataran candi.
- **Babak 10:** pertarungan terakhir, lalu ending seperti sekarang.

Dialog lengkapnya saya tulis saat coding dan bisa kamu revisi setelahnya.

---

## 7. Berkah

### Aturan

- Berkah hanya diberikan saat **pertama kali** memenangkan suatu babak. Kalau babaknya diulang, muncul keterangan "Berkah babak ini sudah diterima".
- Setiap kali ada berkah, muncul **3 pilihan acak** dari daftar di bawah.
- Berkah bertanda *sekali* hilang dari daftar setelah dipilih. Berkah naik bintang hilang kalau kartu tipe itu sudah bintang 3 semua.
- **(usulan saya)** Jamu Kunyit Asam bisa diambil paling banyak 3 kali.

### Daftar

| Berkah | Efek | Batas |
|---|---|---|
| Tempa Sabet | 2 kartu Sabet naik satu bintang | Selama masih bisa naik |
| Olah Semedi | 2 kartu Semedi naik satu bintang | Selama masih bisa naik |
| Laku Tangkis | 2 kartu Tangkis naik satu bintang | Selama masih bisa naik |
| Jamu Kunyit Asam | Nyawa maksimal +10 | 3 kali |
| Kendang Pembuka | +1 Ketukan di giliran pertama tiap battle | Sekali |
| Greget Leluhur | Tiap battle dimulai dengan Greget 30% | Sekali |
| Tameng Pusaka | Tameng 10 di giliran pertama tiap battle | Sekali |
| Jimat Penolak Sirep | Sirep pertama di tiap battle ditangkal | Sekali |
| Jamu Beras Kencur | Setiap kali menerima Lara, jumlahnya berkurang 1 | Sekali |

Dengan 9 kemenangan pertama, pemain mendapat 9 berkah. Daftarnya cukup untuk membuat pilihan tetap menarik tanpa membuat deck terlalu cepat menjadi bintang 3 semua.

---

## 8. Perubahan tampilan

- **Titik Amuk** di bawah bar nyawa Buto, menyala merah saat penuh, dan lencana **×2** di niatnya.
- **Ikon Prayitna** di samping bar nyawa Eyang, serta angka Tameng yang berubah di kartu.
- **Bar Buyarkan** dan ikon Ajian di bawah Buto Hitam saat ia Ancang-ancang.
- **Ikon perisai Bala** di atas Buto Hitam selama Bala masih hidup.
- **Aura Murka** dan nama "… Murka".
- **Kartu tersirep:** gelap, ada gembok, dan bergetar kalau diklik.
- Semua istilah diganti di HUD, tooltip, tutorial, Pustaka, dan README.
- **Pustaka:** entri Cara Bermain ditambah penjelasan Sirep, Ngamuk, Prayitna, Ajian, dan Bala. Entri Buto Murka dan Bala ditambahkan.
- Ikon baru (titik Amuk, Prayitna, Ajian, perisai Bala, ×2) digambar dengan gaya piksel yang sama.

---

## 9. Simpanan lama

Simpanan dari versi sekarang (5 stage) diubah begini: babak 1–4 yang sudah selesai tetap tercatat selesai, deck dan nyawa maksimal tetap. Babak 5 dan seterusnya dibuka ulang dari awal, karena isinya sudah berbeda.

---

## 10. Rencana pengerjaan

Setiap tahap di-commit terpisah, dan tes harus lolos dulu sebelum lanjut.

| Tahap | Isi | File utama |
|---|---|---|
| 1 | Pose serang dan Sirep | `tools/build_assets.py`, `enemy_buto.gd`, `battle_manager.gd`, `hand_manager.gd`, `card_view.gd` |
| 2 | Ganti istilah | `tools/strings_source.py`, HUD, Pustaka, README |
| 3 | Ngamuk, Prayitna, Gebrakan membuyarkan | `enemy_unit.gd`, `enemy_buto.gd`, `battle_manager.gd`, `player_state.gd`, `unit_view.gd`, `battle_hud.gd` |
| 4 | Buto Murka, 10 babak, peta baru, tata letak 4 Buto | `enemy_spec.gd`, `tools/generate_data.gd`, `tools/build_map.py`, `stage_map.gd`, `battle_scene.gd` |
| 5 | Buto Hitam baru (Ajian, Bala, Pagebluk Merata) | `enemy_buto.gd`, `battle_manager.gd` (memunculkan musuh di tengah battle), `unit_view.gd` |
| 6 | Berkah v2 dan perubahan simpanan lama | `game_state.gd`, `reward_panel.gd` |
| 7 | Keseimbangan dan pemeriksaan akhir | `tools/simulate_balance.gd`, semua tes, screenshot semua layar |

**Tes baru:**
- Sirep menyasar kartu terkuat dan kartu tersirep tidak bisa dimainkan.
- Ngamuk terisi dari setiap aksi, dan aksi ganda berjalan benar.
- Babak 9 tidak pernah punya dua Buto ngamuk bersamaan.
- Prayitna menambah Tameng.
- Gebrakan mengosongkan Amuk dan membuyarkan Ajian.
- Ajian buyar di ±40 damage.
- Bala mengurangi damage ke Buto Hitam.
- Pagebluk Merata menahan Lara.
- Berkah hanya untuk kemenangan pertama, dengan batas masing-masing.
- Simpanan lama terbaca dengan benar.
- Tes kampanye diperpanjang menjadi 10 babak.

---

## 11. Ringkasan usulan saya yang perlu dicek

1. Prayitna berlaku untuk semua kartu bertameng (Tangkis, Tangkis Balik, Manunggal), bukan hanya Tangkis.
2. Babak 5–8: Buto Murka ditemani satu Buto biasa.
3. Bala hanya dipanggil sekali, dan selama Bala hidup Buto Hitam menerima separuh damage.
4. Ambang membuyarkan Ajian ±40 damage dalam satu giliran (angka final dari simulasi).
5. Jamu Kunyit Asam maksimal 3 kali.
6. Nama tempat baru: Tegal Ilalang, Alas Jati Peteng, Kali Watu, Jembatan Pring, Pelataran Candi.
7. Simpanan lama: babak 1–4 tetap selesai, sisanya dibuka ulang.
