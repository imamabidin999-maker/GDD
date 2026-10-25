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

Terbuka setelah tamat, dari menu utama. Ruwatan adalah perjalanan acak 8 langkah:

1. Battle (dua Buto biasa)
2. Battle (dua Buto biasa)
3. Kejadian
4. Battle (Buto Murka + pendamping)
5. Battle (Buto Murka + pendamping)
6. Kejadian
7. Battle (dua Buto Murka)
8. Bos: Buto Hitam

- Mulai dari deck awal dan 70 Nyawa, tanpa berkah. Setiap menang dapat berkah (3 pilihan, tanpa aturan kemenangan pertama).
- **Nyawa terbawa** antar battle dan pulih 40% Nyawa maksimal setelah menang.
- Kalah berarti Ruwatan selesai. Hasil terbaik dicatat.
- Ruwatan yang sedang berjalan tersimpan dan bisa dilanjutkan.

**Tingkat Pagebluk** (berlaku menumpuk). Menang di tingkat N membuka tingkat N+1.

| Tingkat | Tambahan |
|---|---|
| 1 | Ruwatan biasa |
| 2 | Nyawa Buto +10% |
| 3 | Serangan Buto +10% |
| 4 | Pemulihan setelah menang hanya 25% |
| 5 | Buto biasa juga bisa Ngamuk |
| 6 | Pilihan berkah hanya 2 |
| 7 | Setiap battle dimulai dengan 2 Lara |
| 8 | Nyawa Buto +20% (menggantikan +10%) |
| 9 | Buto Hitam memanggil 3 Bala |
| 10 | Ambang Buyarkan Ajian +10, Pagebluk Merata +1 Lara lagi |

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
