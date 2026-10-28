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
