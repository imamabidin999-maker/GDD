# Pembaruan v4

Catatan untuk rangkaian pembaruan setelah halaman Istilah Jawa dan Asli atau Rekaan masuk ke Pustaka. Setiap bagian ditulis setelah tahapnya selesai dan lolos tes.

## 1. Istilah Jawa Muncul Saat Dibaca

- Istilah Jawa di teks cerita sekarang berwarna jingga dan bergaris bawah. Kalau kursor diarahkan ke istilah itu, artinya muncul di kotak keterangan, sama persis dengan isi halaman Istilah Jawa di Pustaka.
- Tempat yang ditandai: kotak dialog (prolog, babak, penutup, tutorial), panel kejadian di perjalanan (cerita awal dan hasilnya), petunjuk yang muncul di battle, dan halaman-halaman Pustaka. Halaman Istilah Jawa sendiri tidak ditandai karena memang kamusnya.
- Supaya teks tidak penuh warna, satu istilah hanya ditandai pada kemunculan pertamanya di satu percakapan, satu panel, atau satu halaman.
- Kata berimbuhan ikut dikenali: *bersemedi* menunjuk Semedi, *menabuh* dan *tabuhan* menunjuk Tabuh, *tersirep* menunjuk Sirep, *peronda* menunjuk Ronda, dan seterusnya.
- Istilah yang juga kata sehari-hari hanya ditandai di dalam nama tempatnya. *Kali* berarti sungai, tetapi "dua kali" bukan sungai, jadi yang ditandai hanya *Kali Watu*. Begitu juga *Alas Jati Peteng*, *Tegal Ilalang*, dan *Jembatan Pring*.
- *Eyang Palang* ditandai sebagai satu kesatuan dan keterangannya berisi dua arti sekaligus: Eyang lalu Palang.
- Istilah baru di kamus: **Arak-arakan**, karena kata ini dipakai di cerita dan akan jadi penutup game.
- Pengaturan sekarang dua kolom supaya muat, dan ada pilihan baru **Tandai istilah Jawa** (bawaan: menyala) untuk pemain yang ingin teks polos.
- Daftar bentuk kata ada di `tools/glossary_source.py` (`EXTRA_FORMS`, `ONLY_FORMS`, `JOINT_FORMS`) dan ditulis ke `GlossaryData.FORMS`. Penandanya ada di `ui/common/glossary_text.gd`.
- Tes memastikan tanda tidak mengubah isi teks yang terbaca di seluruh teks cerita, kejadian, dan petunjuk dalam dua bahasa (sekitar 500 istilah ditandai).

## 2. Kartu Tabuh Gong Beri

- Gong beri adalah alat musik Dongkrek yang belum ada di game. Bentuknya gong datar tanpa pencu (tonjolan di tengah) dengan sisi tipis, jadi bunyinya nyaring dan berdesing. Menurut penelitian tentang musik Dongkrek di Balerejo, Madiun, gong beri dipakai bersama bedug, korek, kenong, kentongan, kendang, dan gong. Alat ini masuk belakangan, sebagai perpaduan budaya Jawa, Islam, dan Cina.
- Kartunya: **Gong Beri**, 1 Ketukan, tanpa damage. Semua Buto menjadi **giris** (bahasa Jawa: ngeri, ciut nyali), sehingga serangan mereka di giliran Buto berikutnya berkurang 25 / 35 / 50% sesuai bintang. Tameng yang sedang dipakai Buto juga pecah.
- Giris tidak bertumpuk (yang berlaku yang terbesar) dan paling banyak 75%. Kenong menguatkannya juga: Kenong +40% lalu Gong Beri bintang 3 berarti serangan Buto berkurang 70%.
- Semua damage Buto dihitung dari serangannya, jadi niat di atas kepala Buto langsung menunjukkan angka yang sudah melemah. Pengecualian: pratinjau ancang-ancang (Gebug Raksasa dan Ajian Lebur Saketi giliran depan) tetap memakai serangan penuh, karena pukulan itu datang setelah giris hilang.
- Pasangan yang pas: Tameng 10 dari ancang-ancang Buto Merah Murka dan Tameng 15 dari Ajian Buto Hitam bisa dipecah Gong Beri, sehingga semua pukulan sesudahnya ikut menghitung untuk membuyarkan Ajian.
- Di Buto yang giris muncul ikon bilah dengan panah ungu dan angka persennya. Keterangannya muncul saat ikon atau Buto-nya disorot.
- Gambar kartu dan bunyinya dibuat baru: gong datar berukir melingkar dengan pemukul berlapis kain merah, dan bunyi gong yang nadanya "mekar" sesaat setelah dipukul. Bunyinya dibuat dengan deret acak sendiri (`build_audio.py --tambahan`), jadi bunyi lain tidak ikut berubah.
- Didapat dari berkah Roro Ayu (sekali, seperti kartu Tabuh lain). Istilah **Gong beri** dan **Giris** masuk ke halaman Istilah Jawa, dan catatan Asli atau Rekaan tentang alat musik Dongkrek diperbarui.
- Simulasi 200 kali per babak, sebelum dan sesudah Gong Beri masuk undian berkah: bot cerdas 80% → 78% di babak 9 dan 91% → 92% di babak 10. Bot santai (yang memainkan kartu dari kiri tanpa melihat niat Buto) 45% → 38% dan 35% → 31%. Selisihnya masih dalam batas acak undian berkah, dan wajar kalau bot santai sedikit dirugikan, karena kartu tanpa damage hanya berguna kalau dimainkan pada saat yang tepat.
- Ruwatan (150 kali per tingkat, bot cerdas): tingkat 1 tetap 78%, tingkat 3 48% → 39%, tingkat 5 36% → 33%, tingkat 7 tetap 25%, tingkat 10 3% → 1%. Sedikit turun karena bot memilih berkah secara acak, jadi kadang menukar kartu serang dengan Gong Beri. Pemain yang memilih sendiri tidak terkena masalah ini, jadi angkanya tidak diubah.

## 3. Musik Battle Tambahan

Sebelumnya semua babak memakai satu lagu battle, kecuali Buto Hitam. Sekarang setiap bagian cerita punya lagunya sendiri, dan semuanya tetap disintesis dari bunyi gamelan Dongkrek yang sama (bedug, korek, kentongan, kendang, saron, bonang, kenong, kempul, gong, slompret, suling):

| Lagu | Dipakai di | Ciri |
|---|---|---|
| `battle` | Babak 1–4 | Slendro, 132 ketukan per menit (lagu lama) |
| `battle_murka` | Babak 5–8 (Buto Murka) | Pelog yang lebih gelap, 126 ketukan, dua bonang bergantian (imbal), dengung rendah tipis, kentongan titir tiap delapan ketukan |
| `battle_candi` | Babak 9 (empat Buto Murka di Candi Pagebluk) | Slendro cepat, 148 ketukan, gong tiap delapan ketukan, desir yang naik menjelang gong |
| `boss` | Buto Hitam fase pertama | Pelog, 140 ketukan (lagu lama) |
| `boss2` | Buto Hitam fase kedua | Pola **sampak**: kenong di setiap ketukan, kempul berselang, gong tiap delapan ketukan, 156 ketukan, dengung yang perlahan naik, slompret meraung |

- Sampak dipilih untuk fase kedua karena di pertunjukan wayang, pola inilah yang dipakai untuk adegan perang yang memuncak.
- Lagu berganti dengan *crossfade* tepat saat Buto Hitam masuk fase kedua.
- Ruwatan ikut memakai lagu sesuai jenis langkahnya: battle biasa, Buto Murka, dua Buto Murka (lagu Candi Pagebluk), lalu bos.
- Ketiga lagu dibuat dengan deret acak masing-masing (`build_audio.py --tambahan`), jadi lagu dan bunyi lama tidak berubah. Kekerasan suaranya disamakan dengan lagu lama (RMS sekitar 0,13–0,145), dan ujung loop-nya disambung ke awal supaya tidak terdengar patah.

## 4. Roro Ayu dan Roro Perot di Dunia Game

- **Sprite badan penuh.** Desain sprite diam Roro Ayu (`docs/desain_asli/roro_ayu_standby.png`) ternyata pixel art yang diperbesar sekitar 5,125 kali. Kisi aslinya dibaca ulang (satu warna per sel), jadi satu piksel desain menjadi satu piksel game dan tinggi Roro Ayu hampir sama dengan Eyang Palang. Latar dan bayangan di kakinya dibuang lewat isian dari tepi gambar, supaya rambut yang warnanya mirip latar tidak ikut terhapus. Kebayanya diputihkan dengan cara yang sama seperti potretnya.
- **Di mana Roro Ayu muncul:**
  - di kiri panel **Berkah Roro Ayu**, bernapas pelan;
  - di peta, berjalan di belakang Eyang setelah babak 3 (di cerita ia memperkenalkan diri setelah babak 3);
  - di Pustaka, halaman **Roro Ayu** dengan tanda asal-usul: topengnya dari kisah Dongkrek, perannya di game rekaan.
- **Roro Perot** belum punya desain dari pemilik proyek, jadi rupanya dibuat sebagai **rancangan sementara** dari kisi Roro Ayu:
  - wajah berlapis **bedak dingin** putih (bedak beras tradisional), dengan pipi merah dan tahi lalat;
  - mulut miring (*perot*), satu alis terangkat;
  - kebaya lurik nila, hiasan sanggul diganti bunga merah.
  - Kalau nanti ada desain asli, cukup ganti prosesnya di `tools/roro_sprites.py`.
- **Dua kejadian baru bersama Roro Perot:**
  - *Cangkriman Roro Perot*: ia menghadang dengan teka-teki Jawa "pitik walik saba kebon" (jawabannya nanas). Jawab dengan benar untuk mendapat kartu **Gong Beri** titipan bapaknya, oleh-oleh dari saudagar Pecinan, atau pura-pura bingung untuk Nyawa maksimal +5.
  - *Bedak Dingin*: biarkan wajah Eyang dibedaki (berkah Jamu Beras Kencur, penangkal Lara; kalau sudah punya, Nyawa maksimal +5), atau berlatih ditonton Roro Perot (kartu acak +1 bintang).
- Halaman Roro Perot di Pustaka berupa siluet sampai ia ditemui di salah satu kejadiannya. Ia juga punya potret dan warna nama sendiri di kotak dialog untuk dipakai di penutup.
- Istilah baru: **Cangkriman**, **Bedak dingin**, dan **Pecinan**. Catatan Roro Perot di halaman Istilah Jawa diperbarui (sebelumnya tertulis ia tidak muncul di game), dan ada unsur rekaan baru: *Peran Roro Perot*.
- Di halaman Pustaka tentang seorang tokoh, nama tokoh itu sendiri tidak ditandai sebagai istilah lagi.

## 5. Persimpangan Jalan

- Sebelumnya, setelah kemenangan pertama di babak 2, 4, 6, dan 8 hanya ada satu kejadian acak. Sekarang Eyang tiba di **persimpangan jalan** dengan dua cabang, masing-masing menuju kejadian yang berbeda.
- Setiap cabang diberi nama tempat dan petunjuk dari kejadian di ujungnya, tanpa membuka isinya: dentang palu dari jalan ke pandean, wangi kunyit dan kencur dari jalan desa, asap kemenyan dari jalan setapak ke beringin, isak tangis dari pinggir hutan, tawa cekikikan dari pematang sawah, dan seterusnya. Gambar kecil kejadiannya ikut tampil sebagai petunjuk tambahan.
- Kejadian yang dipilih tercatat sudah dialami. Kejadian di cabang lain belum, jadi bisa muncul lagi di persimpangan berikutnya.
- Kalau hanya tersisa satu kejadian yang belum dialami, kejadian itu langsung menunggu tanpa persimpangan.
- Persimpangan yang belum dipilih ikut tersimpan (`pending_paths` di simpanan). Simpanan lama yang masih menyimpan satu kejadian tetap berjalan seperti biasa.
- **Ruwatan**: kedua langkah kejadian juga berupa persimpangan. Cabang keduanya diundi dengan deret acak terpisah dari seed yang sama, jadi lawan, latar, dan kejadian utama dari Ruwatan yang sedang berjalan tidak berubah setelah pembaruan ini.
- Penunjuk jalan digambar baru: tiang kayu dengan dua papan arah (`ui/crossroads.png`).
