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

## 6. Penutup Arak-arakan

Menurut kisah asal-usulnya, Dongkrek lahir dari tabuhan dan arak-arakan keliling desa untuk mengusir pagebluk. Penutup game sekarang benar-benar memainkannya.

- **Alurnya**: Buto Hitam kalah, fajar di Mejayan, lalu dialog penutup (Roro Ayu meminta tabuhan itu diberi nama, Eyang menamainya Dongkrek, lalu mengajak warga mengarak keliling desa). Setelah itu **arak-arakan**, lalu epilog: Roro Perot ingin memegang korek tahun depan, janji menabuhnya setiap tahun, lahirnya Dongkrek, dan ajakan mendengarkan dung... krek... kalau suatu hari berkunjung ke Madiun. Terakhir judul dan kredit.
- **Permainannya** mirip irama Sapu Jagad: dung (bulat) dan krek (kotak) datang ke lingkaran, lalu ditabuh dengan klik, Spasi, Enter, atau tombol Sapu Jagad. Temponya 100 ketukan per menit: empat hitungan kentongan, lalu empat putaran delapan ketukan (26 ketukan untuk pemain), dan penutup gong serta gulungan bedug. Totalnya sekitar 26 detik.
- **Rombongan ikut satu per satu**, dua ketukan sebelum putarannya:
  1. pembawa bedug;
  2. penabuh korek, bersama Roro Ayu dan Roro Perot;
  3. pembawa gong, kentongan, dan obor;
  4. warga bertopeng Buto yang menari, berganti pose di setiap ketukan.
- Iringannya ikut bertambah ramai di setiap putaran: kentongan, bedug, korek dan saron, gong-kenong-kempul (dengan desing gong beri), lalu bonang dan slompret.
- **Tidak ada kalah.** Ketukan yang meleset hanya mengurangi *semarak*. Di akhir tampil persennya dan satu kalimat, dari "Meriah sekali! Seluruh desa bersorak" sampai "Tabuhannya kacau, tapi warga tetap tertawa dan bersorak".
- Ada tombol **Lewati**. Kalau irama dimatikan di Pengaturan, arak-arakan berjalan sendiri tanpa lintasan ketukan.
- Setelah selesai, seluruh barisan tetap di layar sebagai gambar penutup di belakang epilog dan kredit.
- **Gambar**: Eyang Palang, Roro Ayu, Roro Perot, dan lima Buto memakai sprite yang sudah ada. Warga di barisan belakang digambar baru sebagai **siluet yang disinari fajar dari belakang** (`sprites/arak/warga_*.png`), karena belum ada desain warga.
- Halaman Roro Perot di Pustaka juga terbuka setelah tamat, karena ia ikut arak-arakan.

## 7. Catatan Permainan dan Riwayat Ruwatan

- Pustaka punya halaman baru, **Catatan**, yang berisi catatan sepanjang masa:
  - battle yang dimenangkan dan yang kalah;
  - berapa kali Sapu Jagad dilepas, dan irama Sapu Jagad terbaik;
  - berapa kali kartu digabung, dan pukulan terbesar (satu kartu atau satu Sapu Jagad, dijumlah untuk semua sasaran);
  - arak-arakan paling semarak, dan berapa kali tamat;
  - Buto yang dikalahkan per warna (dengan topengnya), ditambah Buto Murka dan Bala;
  - **jurus favorit**, kartu yang paling sering dimainkan, lengkap dengan kartunya;
  - **riwayat Ruwatan**: sepuluh Ruwatan terakhir dengan tanggal, Tingkat Pagebluk, jumlah langkah, dan hasilnya (berhasil atau gugur).
- Seperti Bintang Dongkrek, catatan ini tidak ikut terhapus saat memulai petualangan baru. Catatan tersimpan di bagian `records` simpanan, dan simpanan lama tanpa bagian ini mulai dari nol.
- Catatan per battle dikumpulkan oleh `BattleStats` (yang juga dipakai untuk tantangan babak), lalu dijumlahkan di `core/progress/play_records.gd`. Battle cerita dan Ruwatan sama-sama dihitung.
- Tamat hanya dihitung sekali per petualangan, jadi mengulang babak 10 tidak menambah angkanya.
- Hasil satu Ruwatan bisa dilaporkan lebih dari sekali (saat selesai dan saat ditutup). Riwayat mengenali Ruwatan yang sama dari seed dan tingkatnya, jadi tetap tercatat satu kali.
- Tesnya ada di `tests/test_records.gd`, dan tes kampanye memeriksa catatan setelah tamat dan setelah Ruwatan.

## 8. Teks Besar dan Gamepad

**Teks besar**

- Pengaturan punya pilihan baru, **Teks besar**. Kalau dinyalakan, teks yang biasanya 8 piksel memakai huruf 16 piksel di tempat-tempat yang banyak dibaca:
  - keterangan saat kursor diarahkan ke kartu, Buto, ikon, tombol HUD, dan istilah Jawa (kotaknya melebar dari 190 ke 300 piksel), juga keterangan di Pengaturan;
  - petunjuk battle (kotaknya melebar dari 330 ke 440 piksel);
  - petunjuk jalan di persimpangan, dan ringkasan hasil kejadian di perjalanan;
  - catatan kecil di Pustaka: pengantar halaman, keterangan kartu, angka Nyawa dan Serangan Buto, dan tanda asal-usul.
- Teks cerita, dialog, dan isi Pustaka sudah 16 piksel dari awal, jadi tidak berubah.
- Angka di HUD, wajah kartu, dan panel tombol keyboard dan gamepad tetap kecil. Layar game hanya 640×360, dan bagian-bagian itu akan saling tumpuk kalau hurufnya dua kali lebih besar. Semua angka di sana juga bisa dibaca lebih besar lewat keterangan saat kursor diarahkan.
- Pilihan ini tersimpan bersama pengaturan lain. Kodenya ada di `UIKit.large_text()` dan `UIKit.small_text_variation()`, jadi layar baru cukup memakai fungsi itu untuk teks kecilnya.

**Gamepad**

- Autoload baru `GamepadCursor` mengubah gamepad menjadi mouse. Karena semua bagian game bisa dimainkan dengan mouse, cara ini langsung berlaku di semua layar: menu, peta, battle, Pustaka, kejadian, sampai arak-arakan.
  - **Stik kiri** menggerakkan kursor 240 piksel per detik. Setelah didorong setengah detik, kursor makin cepat sampai dua kali lipat, supaya menyeberang layar tidak lama. Stik yang hanya sedikit miring (di bawah 20%) diabaikan.
  - **D-pad** menggerakkan kursor lebih pelan (120 piksel per detik) untuk membidik dengan tepat.
  - **A** adalah klik kiri. Tahan A sambil menggerakkan kursor untuk menggeser kartu.
  - **Stik kanan** menggulir seperti roda mouse, misalnya di Pustaka dan daftar jurus.
- Tombol lain langsung terpasang ke aksi battle: **X** akhiri giliran, **Y** Sapu Jagad (juga untuk menabuh irama), **RB** ganti sasaran, **LB** kecepatan 1x/2x, **Start** atau **B** untuk jeda dan kembali. Tombol-tombol ini bisa diganti di panel Tombol Gamepad (lihat bagian 10).
- Mengganti tombol keyboard tidak melepas tombol gamepad, begitu juga sebaliknya.
- Aksi bawaan Godot (`ui_accept`, `ui_left`, dan seterusnya) tidak lagi membaca gamepad. Tanpa ini, satu tekanan A terhitung dua kali di irama Sapu Jagad, dan D-pad ikut menggeser slider volume yang sedang aktif.
- Hanya gamepad pertama yang tersambung yang dibaca, dan hanya saat jendela game sedang aktif, supaya kursor tidak ikut tertarik ketika pemain membuka jendela lain.
- Tesnya ada di `tests/test_keys.gd`: pemetaan tombol, aksi bawaan yang sudah bersih dari gamepad, dan hitungan kecepatan kursor. Fitur ini belum dicoba dengan gamepad sungguhan, jadi rasa kecepatan kursornya masih perlu dicoba langsung.

## 9. Keseimbangan dan Pemeriksaan Akhir

Setelah bagian 1–8 selesai, semua simulasi dijalankan ulang. Angka lengkapnya ada di bagian Keseimbangan di README.

- **Mode cerita, kesulitan Normal (500 battle per babak).** Bot cerdas hampir tidak berubah. Perbandingan versi sebelum Gong Beri dengan versi sekarang di babak 4–8: 93/99/97/99/96% menjadi 95/99/98/99/96%.
- Bot santai turun di babak 5 (82% → 76%) dan babak 6 (68% → 62%), sedangkan babak 4, 7, dan 8 tetap. Penyebab yang paling mungkin: bot memilih berkah dan kejadian secara acak, jadi Gong Beri (dari berkah atau dari cangkriman Roro Perot) kadang menggantikan kartu serang, lalu dimainkan dari kiri tanpa melihat niat Buto. Bot cerdas, yang membaca niat Buto, tidak dirugikan, jadi angka Buto tidak diubah.
- Angka 73% untuk bot santai di babak 6 pada tabel lama ternyata kebetulan dari 200 battle. Dengan 500 battle, versi lama pun hanya 68%.
- Babak 9: bot cerdas 75%, bot santai 38% (sebelumnya 80% dan 45%). Babak 10: 90% dan 30% (sebelumnya 91% dan 35%). Kedua babak ini memang dirancang paling menuntut siasat.
- **Kesulitan Santai**: bot santai menang 66–100% di setiap babak, bot cerdas 99–100%. **Sulit**: bot cerdas 40–100%, bot santai 9–100%.
- **Ruwatan (200 perjalanan per tingkat)**: bot cerdas berhasil 77% di tingkat 1, turun bertahap sampai 3% di tingkat 10. Selisihnya dengan angka lama paling banyak 5 poin, kecuali tingkat 6 (40% → 31%). Setelah diulang dengan 600 perjalanan, tingkat 6 versi lama ternyata 33% dan versi sekarang 31%, jadi angka 40% dulu hanya kebetulan.
- **Tes**: 16 berkas tes dengan 767 cek, semuanya lolos. Termasuk di dalamnya tes kampanye yang menamatkan 10 babak lalu satu Ruwatan dengan klik mouse sungguhan (53 cek).

**Yang masih menunggu pemilik proyek**

- Rupa Roro Perot dan warga di arak-arakan masih rancangan sementara: Roro Perot dibuat dari kisi Roro Ayu, warga berupa siluet. Kalau desain aslinya sudah ada, cukup ganti prosesnya di `tools/roro_sprites.py` dan `tools/build_assets.py`.
- Gambar beresolusi lebih tinggi harus mengikuti gaya gambar pemilik proyek, jadi tidak dibuat dari skrip.
- Gamepad baru dicoba lewat tes otomatis, belum dengan gamepad sungguhan.
- Uji main oleh orang lain, terutama babak 6, 9, dan 10 untuk pemain yang bermain santai.
- Bunyi gamelan masih disintesis. Kalau ada rekaman tabuhan Dongkrek dari sanggar, rekaman itu bisa menggantikan berkas di `assets/audio/`.

## 10. Bintang per Petualangan dan Panel Tombol Gamepad

Dua perubahan dari hasil mencoba game.

**Bintang Dongkrek dihitung ulang setiap petualangan baru**

- Dulu Bintang Dongkrek tidak ikut direset saat memulai petualangan baru, karena bintang membuka hadiah permanen. Akibatnya peta petualangan baru sudah menunjukkan 25/30 bintang, dan babak yang masih terkunci sudah berbintang. Itu terasa seperti petualangannya belum benar-benar baru.
- Sekarang bintang di peta, di panel babak, dan di panel Hasil Tantangan milik petualangan yang sedang berjalan, dan mulai dari 0 lagi saat Petualangan Baru.
- Hadiah bintang (Kenong di undian berkah, tombol Pilihan lain, berkah awal Ruwatan, gelar Juru Dongkrek) mengikuti **rekor bintang**, yaitu gabungan bintang dari semua petualangan. Hadiah yang sudah terbuka tidak hilang. Bintang yang diraih lagi di petualangan baru dihitung baru di petualangan itu, tapi rekornya tidak bertambah dua kali.
- Rekornya tampil di keterangan bintang di peta dan di halaman Catatan.
- Konfirmasi Petualangan Baru sekarang menyebutkan apa yang hilang (babak, deck, berkah, bintang petualangan ini) dan apa yang tetap (hadiah bintang, Ruwatan, Catatan).
- Simpanan lama: semua bintang lama menjadi rekor, dan petualangan yang sedang berjalan hanya menyimpan bintang babak yang sudah ia selesaikan.

**Panel tombol gamepad sendiri**

- Baris **Tombol keyboard** di Pengaturan menjadi **Pengaturan tombol** dengan dua tombol: **Keyboard** dan **Gamepad**. Keterangan gamepad di panel keyboard dipindah ke panel gamepad.
- Panel Tombol Gamepad berisi:
  - gamepad yang sedang tersambung, atau keterangan kalau belum ada;
  - tombol kursor (tetap): stik kiri atau D-pad, A untuk klik, tahan A untuk menggeser kartu, stik kanan untuk menggulir;
  - tombol aksi battle yang bisa diganti seperti di panel keyboard. A, D-pad, dan Start ditolak, dan Start selalu untuk jeda di samping tombol pilihan;
  - **kecepatan kursor** 50–200%, karena kenyamanannya berbeda di setiap gamepad dan belum dicoba dengan gamepad sungguhan;
  - nama tombol mengikuti gamepad Xbox, dengan padanannya untuk gamepad PlayStation.
- Pilihan gamepad disimpan di `settings/pad` dan `settings/pad_cursor_speed`. Aturannya ada di `core/input/pad_bindings.gd`, dan panelnya di `ui/common/gamepad_panel.gd`.
