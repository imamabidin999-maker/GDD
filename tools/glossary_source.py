"""Satu sumber untuk halaman Istilah Jawa dan Asli atau Rekaan di Pustaka.

Jalankan dari root repo setelah mengubah isi file ini:
    python3 tools/glossary_source.py
    python3 tools/strings_source.py

Script ini menulis:
- core/content/glossary_data.gd: urutan istilah dan kelompoknya untuk Pustaka;
- docs/05-istilah-jawa-dan-asli-rekaan.md: versi bacaan untuk pemilik proyek.
Teks dua bahasanya diambil tools/strings_source.py lewat fungsi strings().
"""
from __future__ import annotations

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (kunci, nama Indonesia, nama Inggris)
CATEGORIES = [
    ("tokoh", "Tokoh dan kesenian", "People and the art"),
    ("jurus", "Jurus dan pertarungan", "Moves and battle"),
    ("berkah", "Berkah", "Blessings"),
    ("tabuh", "Tabuh dan gamelan", "Tabuh and gamelan"),
    ("desa", "Kehidupan desa", "Village life"),
    ("tempat", "Tempat", "Places"),
    ("busana", "Busana dan benda", "Clothing and objects"),
]

# (kelompok, istilah, penjelasan Indonesia, penjelasan Inggris)
GLOSSARY = [
    ("tokoh", "Dongkrek",
     "Kesenian rakyat dari Mejayan, Kabupaten Madiun. Namanya tiruan bunyi bedug atau kendang (dung) dan korek (krek). Awalnya diarak keliling desa untuk mengusir pagebluk.",
     "A folk art from Mejayan in Madiun Regency, named after the sound of the bedug or kendang (dung) and the korek (krek). It was first paraded around the village to drive away a plague."),
    ("tokoh", "Eyang",
     "Sebutan hormat untuk kakek atau nenek, juga untuk orang tua yang disegani.",
     "A respectful word for a grandparent, also used for a revered elder."),
    ("tokoh", "Palang",
     "Jabatan pemimpin wilayah di Mejayan pada masa itu. Raden Ngabehi Lo Prawirodipuro memegang jabatan ini, karena itu ia dikenal sebagai Eyang Palang.",
     "The title of the local leader of Mejayan at the time. Raden Ngabehi Lo Prawirodipuro held this post, which is why he is remembered as Eyang Palang."),
    ("tokoh", "Raden Ngabehi",
     "Gelar priyayi Jawa. Raden menandakan keturunan bangsawan, Ngabehi adalah gelar kepangkatan untuk abdi dalem atau pejabat.",
     "Javanese gentry titles. Raden marks noble birth, and Ngabehi is a rank given to court servants and officials."),
    ("tokoh", "Sesepuh",
     "Orang yang dituakan di desa dan dimintai nasihat.",
     "An elder whom the village looks to for counsel."),
    ("tokoh", "Wangsit",
     "Petunjuk gaib yang diterima lewat mimpi atau semedi. Menurut cerita, Eyang Palang mendapat wangsit untuk mengusir pagebluk dengan tabuhan dan arak-arakan.",
     "A spiritual message received in a dream or in meditation. The story says Eyang Palang received one telling him to drive the plague away with music and a procession."),
    ("tokoh", "Roro Ayu",
     "Roro (dari rara) berarti gadis, ayu berarti cantik. Dalam Dongkrek, Roro Ayu adalah topeng perempuan berwajah cantik. Di game: gadis desa yang menemani Eyang Palang dan memberi berkah.",
     "Roro (from rara) means maiden and ayu means beautiful. In Dongkrek, Roro Ayu is the mask of a beautiful woman. In the game: the village girl who travels with Eyang Palang and gives blessings."),
    ("tokoh", "Roro Perot",
     "Perot berarti mencong. Topeng perempuan berwajah jenaka dengan mulut miring dalam Dongkrek. Di game: kawan Roro Ayu yang suka bercanda, wajahnya selalu berbedak dingin.",
     "Perot means lopsided. The comic female mask in Dongkrek, with a crooked mouth. In the game: Roro Ayu's joking friend, her face always covered in bedak dingin."),
    ("tokoh", "Buto",
     "Raksasa dalam wayang dan dongeng Jawa (dari kata buta). Dalam Dongkrek, para Buto bertopeng seram menjadi lambang pagebluk.",
     "An ogre from wayang and Javanese tales (from the word buta). In Dongkrek, the fierce masked Buto stand for the plague."),
    ("tokoh", "Genderuwo",
     "Makhluk halus bertubuh besar dan berbulu dalam kepercayaan Jawa. Topeng Buto di Dongkrek sering disebut topeng genderuwo.",
     "A large, hairy spirit in Javanese belief. The Buto masks of Dongkrek are often called genderuwo masks."),
    ("tokoh", "Pagebluk",
     "Wabah penyakit yang menyerang banyak orang dalam waktu singkat. Di game: bencana yang dibawa Buto Hitam, juga nama tingkat kesulitan Ruwatan.",
     "An epidemic that strikes many people at once. In the game: the plague brought by Buto Hitam, and the name of the Ruwatan difficulty levels."),
    ("tokoh", "Tolak bala",
     "Doa atau upacara untuk menolak bencana. Dongkrek pada awalnya adalah ritual tolak bala.",
     "A prayer or ritual to ward off disaster. Dongkrek began as one."),
    ("tokoh", "Arak-arakan",
     "Iring-iringan orang yang berjalan bersama sambil menabuh, menari, atau membawa sesuatu. Dongkrek pada mulanya diarak keliling desa untuk mengusir pagebluk.",
     "A procession of people walking together while playing music, dancing, or carrying something. Dongkrek was first paraded around the village to drive the plague away."),
    ("tokoh", "Ruwatan",
     "Upacara ruwat untuk membebaskan seseorang atau desa dari nasib buruk. Di game: mode perjalanan acak yang terbuka setelah tamat.",
     "A cleansing ceremony that frees a person or a village from misfortune. In the game: the random journey mode unlocked after the story."),

    ("jurus", "Jurus",
     "Gerakan atau teknik dalam pencak silat. Di game: kartu-kartu Eyang Palang.",
     "A move or technique in pencak silat. In the game: Eyang Palang's cards."),
    ("jurus", "Sabet",
     "Dari nyabet: memukul dengan mengayunkan tongkat atau cambuk. Di game: kartu serang.",
     "From nyabet: to strike with a swinging stick or whip. In the game: the attack card."),
    ("jurus", "Semedi",
     "Bertapa atau bermeditasi untuk menenangkan batin. Di game: kartu yang mengisi Greget.",
     "Meditation to still the mind. In the game: the card that fills Greget."),
    ("jurus", "Tangkis",
     "Menahan atau menepis serangan. Di game: kartu pemberi Tameng.",
     "To parry or fend off a blow. In the game: the card that gives Block."),
    ("jurus", "Tenaga dalam",
     "Kekuatan batin dalam pencak silat. Di game: gabungan Sabet dan Semedi.",
     "Inner power in pencak silat. In the game: Sabet merged with Semedi."),
    ("jurus", "Tangkis Balik",
     "Menangkis lalu langsung membalas. Di game: gabungan Sabet dan Tangkis.",
     "To parry and strike back at once. In the game: Sabet merged with Tangkis."),
    ("jurus", "Manunggal",
     "Menyatu, seperti dalam ungkapan manunggaling kawula Gusti. Di game: gabungan Semedi dan Tangkis.",
     "Becoming one, as in the phrase manunggaling kawula Gusti. In the game: Semedi merged with Tangkis."),
    ("jurus", "Greget",
     "Semangat dan gairah. Dalam tari Jawa, greget adalah daya hidup yang membuat gerak terasa bertenaga. Di game: pengisi Sapu Jagad; di atas 100% disebut Greget Memuncak.",
     "Spirit and drive. In Javanese dance, greget is the inner fire that gives a movement its force. In the game: the meter that powers Sapu Jagad; above 100% it is called Greget Memuncak."),
    ("jurus", "Wirama",
     "Irama atau tempo. Bersama wiraga (gerak) dan wirasa (rasa), wirama adalah tiga dasar tari Jawa. Di game: bonus saat memainkan tiga kartu bintang 3 berturut-turut.",
     "Rhythm or tempo. With wiraga (movement) and wirasa (feeling), it is one of the three foundations of Javanese dance. In the game: the bonus for playing three rank-3 cards in a row."),
    ("jurus", "Gatra",
     "Satuan empat ketukan dalam gending gamelan. Di game: empat Ketukan di setiap giliran.",
     "A unit of four beats in a gamelan piece. In the game: your four Ketukan each turn."),
    ("jurus", "Sapu Jagad",
     "Berarti menyapu jagad, menyapu seisi dunia. Dalam kepercayaan kejawen, Sapu Jagad adalah nama sebuah ajian. Di game: jurus pamungkas Eyang Palang.",
     "Means sweeping the whole world. In kejawen belief it is the name of an ajian. In the game: Eyang Palang's finishing move."),
    ("jurus", "Ajian",
     "Ilmu kesaktian yang konon didapat lewat laku seperti puasa dan mantra. Disebut juga aji.",
     "A supernatural power said to be gained through ascetic practice such as fasting and mantras. Also called aji."),
    ("jurus", "Lebur Saketi",
     "Lebur berarti hancur luluh, saketi berarti seratus ribu. Dalam cerita kesaktian Jawa, Ajian Lebur Saketi dikenal sebagai pukulan jarak jauh. Di game: pukulan pamungkas Buto Hitam.",
     "Lebur means crushed to dust and saketi means a hundred thousand. In Javanese tales of supernatural powers, Ajian Lebur Saketi is a long-range blow. In the game: Buto Hitam's ultimate."),
    ("jurus", "Sirep",
     "Ajian yang membuat orang tertidur lelap; dalam cerita rakyat sering dipakai maling. Di game: kartu terkuatmu tidak bisa dipakai selama satu giliran.",
     "A spell that puts people into a deep sleep, often used by thieves in folk tales. In the game: your strongest card can't be used for a turn."),
    ("jurus", "Lara",
     "Sakit. Di game: racun yang mengurangi Nyawa di akhir setiap giliran Buto dan menembus Tameng.",
     "Sickness. In the game: poison that drains HP at the end of every Buto turn and ignores Block."),
    ("jurus", "Prayitna",
     "Waspada dan siaga. Di game: saat ada Buto yang siap Ngamuk, Tameng dari kartu bertambah 50%.",
     "Alert and on guard. In the game: when a Buto is about to go Ngamuk, Block from cards is increased by 50%."),
    ("jurus", "Ngamuk",
     "Mengamuk, menyerang membabi buta. Di game: Buto yang ketiga titik Amuk-nya penuh beraksi dua kali.",
     "To run amok and lash out blindly. In the game: a Buto whose three Amuk points are full acts twice."),
    ("jurus", "Giris",
     "Ngeri, sampai ciut nyali. Di game: Buto yang giris karena bunyi Gong Beri serangannya melemah di giliran berikutnya.",
     "Terrified, losing one's nerve. In the game: a Buto shaken by the Gong Beri hits weaker on its next turn."),
    ("jurus", "Murka",
     "Sangat marah. Di game: Buto yang sudah kalah lalu dibangkitkan lagi oleh Buto Hitam dengan ilmu yang lebih kuat.",
     "Wrathful. In the game: a defeated Buto raised again by Buto Hitam with a stronger skill."),
    ("jurus", "Bala",
     "Pasukan atau bala tentara. Bala dalam tolak bala lain artinya, yaitu bencana. Di game: Buto bayangan yang dipanggil Buto Hitam.",
     "Troops, an army. The bala in tolak bala is a different word that means misfortune. In the game: the shadow Buto summoned by Buto Hitam."),
    ("jurus", "Gebug",
     "Memukul keras dengan benda tumpul. Di game: Gebug Raksasa milik Buto Merah dan Gebug Pagebluk milik Buto Hitam.",
     "To club hard with a blunt object. In the game: Buto Merah's Gebug Raksasa and Buto Hitam's Gebug Pagebluk."),
    ("jurus", "Sembur",
     "Menyemburkan dari mulut. Di game: Sembur Lara milik Buto Hijau.",
     "To spit or spray from the mouth. In the game: Buto Hijau's Sembur Lara."),
    ("jurus", "Tameng",
     "Perisai. Di game: penahan damage yang habis di awal giliran berikutnya.",
     "A shield. In the game: Block, which runs out at the start of your next turn."),
    ("jurus", "Ancang-ancang",
     "Bersiap sebelum melompat atau memukul. Di game: tanda Buto akan melepas serangan besar di giliran depan.",
     "Winding up before a leap or a blow. In the game: a sign that a Buto will unleash a big attack next turn."),

    ("berkah", "Tempa",
     "Menempa logam supaya kuat dan tajam, pekerjaan seorang pande. Di game: berkah Tempa Sabet.",
     "To forge metal so it is strong and sharp, the work of a smith. In the game: the Tempa Sabet blessing."),
    ("berkah", "Olah",
     "Mengolah atau melatih. Olah semedi berarti melatih batin. Di game: berkah Olah Semedi.",
     "To train or cultivate. Olah semedi means training the mind. In the game: the Olah Semedi blessing."),
    ("berkah", "Laku",
     "Latihan atau tirakat yang dijalani dengan tekun. Di game: berkah Laku Tangkis.",
     "A practice or discipline followed with devotion. In the game: the Laku Tangkis blessing."),
    ("berkah", "Pusaka",
     "Benda warisan yang dikeramatkan, misalnya keris atau tombak. Di game: berkah Tameng Pusaka.",
     "A revered heirloom, such as a keris or a spear. In the game: the Tameng Pusaka blessing."),
    ("berkah", "Jimat",
     "Benda yang dipercaya bisa menolak bahaya. Di game: berkah Jimat Penolak Sirep.",
     "An object believed to ward off harm. In the game: the Jimat Penolak Sirep blessing."),
    ("berkah", "Leluhur",
     "Nenek moyang. Di game: berkah Greget Leluhur.",
     "Ancestors. In the game: the Greget Leluhur blessing."),
    ("berkah", "Jamu",
     "Minuman tradisional dari rempah. Kunyit asam dan beras kencur adalah dua jamu yang paling dikenal. Di game: berkah penambah Nyawa dan penangkal Lara.",
     "A traditional herbal drink. Kunyit asam (turmeric and tamarind) and beras kencur (rice and aromatic ginger) are two of the best known. In the game: blessings that add HP or ease Lara."),

    ("tabuh", "Tabuh",
     "Memukul alat musik (menabuh), juga sebutan untuk pemukulnya. Di game: kartu-kartu alat musik.",
     "To strike an instrument (menabuh), also the beater itself. In the game: the instrument cards."),
    ("tabuh", "Bedug",
     "Gendang besar dari kayu berlapis kulit, biasa ada di masjid atau langgar. Bunyinya dung.",
     "A large wooden drum with a hide head, usually found at a mosque. It sounds dung."),
    ("tabuh", "Korek",
     "Alat musik khas Dongkrek: kayu berbentuk bujur sangkar dengan tangkai bergerigi yang digesek sehingga berbunyi krek.",
     "Dongkrek's signature instrument: a square wooden box with a serrated stick that rasps out a krek."),
    ("tabuh", "Kentongan",
     "Alat bunyi dari bambu atau kayu berlubang yang dipukul sebagai tanda di desa.",
     "A hollow bamboo or wooden slit drum struck to send signals around a village."),
    ("tabuh", "Titir",
     "Pukulan kentongan yang cepat dan beruntun, tanda ada bahaya.",
     "A rapid, unbroken beating of the kentongan that warns of danger."),
    ("tabuh", "Kendang",
     "Gendang yang memimpin cepat-lambatnya irama gamelan. Di game: berkah Kendang Pembuka.",
     "The drum that leads the tempo of a gamelan. In the game: the Kendang Pembuka blessing."),
    ("tabuh", "Gong",
     "Gong besar yang menandai akhir satu putaran gending.",
     "The large gong that closes each cycle of a gamelan piece."),
    ("tabuh", "Gong beri",
     "Gong datar tanpa pencu (tonjolan di tengah) yang sisinya tipis, sehingga bunyinya nyaring dan berdesing. Gong beri masuk ke perangkat Dongkrek belakangan, sebagai perpaduan budaya Jawa, Islam, dan Cina. Di game: kartu Tabuh yang membuat Buto giris.",
     "A flat gong with a thin rim and no central boss, so it rings with a bright, shimmering crash. It joined the Dongkrek ensemble later, as a blend of Javanese, Islamic, and Chinese culture. In the game: the Tabuh card that leaves the Buto shaken (Giris)."),
    ("tabuh", "Kenong",
     "Gong pencon besar yang diletakkan di atas tali dalam kotak kayu. Bunyinya menandai bagian-bagian gending.",
     "A large knobbed gong resting on cords in a wooden frame. It marks the sections of a piece."),
    ("tabuh", "Gamelan",
     "Ansambel musik tradisional Jawa yang sebagian besar alatnya dipukul.",
     "The traditional Javanese ensemble, made mostly of struck instruments."),
    ("tabuh", "Gending",
     "Lagu atau komposisi gamelan.",
     "A gamelan composition."),
    ("tabuh", "Laras",
     "Tangga nada gamelan; ada dua, slendro dan pelog. Di game: berkah Laras Gamelan.",
     "The tuning system of a gamelan, either slendro or pelog. In the game: the Laras Gamelan blessing."),
    ("tabuh", "Pande",
     "Tukang atau perajin logam, misalnya pande besi atau pande gamelan.",
     "A metal craftsman, such as a blacksmith or a gamelan maker."),

    ("desa", "Mbok",
     "Sebutan untuk ibu atau perempuan yang lebih tua.",
     "A word for a mother or an older woman."),
    ("desa", "Jamu gendong",
     "Penjual jamu keliling yang menggendong bakul di punggung.",
     "A herbal-drink seller who walks the village with a basket on her back."),
    ("desa", "Ronda",
     "Jaga malam bergiliran untuk menjaga keamanan desa. Orangnya disebut peronda.",
     "The night watch that villagers take turns keeping. The watchmen are called peronda."),
    ("desa", "Sesajen",
     "Persembahan berupa bunga, makanan, dan kemenyan untuk menghormati yang gaib.",
     "An offering of flowers, food, and incense to honor the unseen."),
    ("desa", "Kemenyan",
     "Getah harum yang dibakar dalam doa dan upacara.",
     "A fragrant resin burned during prayers and ceremonies."),
    ("desa", "Cangkriman",
     "Teka-teki Jawa. Yang terkenal misalnya pitik walik saba kebon, \"ayam terbalik berkeliaran di kebun\", dan jawabannya nanas.",
     "A Javanese riddle. A well-known one is pitik walik saba kebon, \"an upside-down chicken roaming the garden\". The answer is a pineapple."),
    ("desa", "Beringin",
     "Pohon besar berakar gantung yang sering dianggap keramat.",
     "A great banyan tree with hanging roots, often held to be sacred."),

    ("tempat", "Mejayan",
     "Kecamatan di Kabupaten Madiun, Jawa Timur, tempat Dongkrek lahir. Tempat ini nyata.",
     "A district in Madiun Regency, East Java, where Dongkrek was born. It is a real place."),
    ("tempat", "Wingit",
     "Angker dan keramat, membuat bulu kuduk berdiri. Di game: Rumpun Bambu Wingit.",
     "Eerie and sacred, the kind of place that makes your hair stand on end. In the game: the haunted bamboo grove."),
    ("tempat", "Sendang",
     "Mata air atau kolam alami yang sering dianggap keramat. Sendang Larangan berarti sendang yang terlarang.",
     "A natural spring or pool, often held sacred. Sendang Larangan means the forbidden spring."),
    ("tempat", "Gapura",
     "Gerbang atau pintu masuk.",
     "A gateway."),
    ("tempat", "Candi",
     "Bangunan suci peninggalan masa Hindu-Buddha.",
     "A temple from the Hindu-Buddhist era."),
    ("tempat", "Tegal",
     "Ladang atau tanah lapang. Ilalang adalah rumput liar yang tinggi.",
     "A field or open ground. Ilalang is tall wild grass."),
    ("tempat", "Alas",
     "Hutan. Alas Jati Peteng berarti hutan jati yang gelap.",
     "Forest. Alas Jati Peteng means the dark teak forest."),
    ("tempat", "Kali",
     "Sungai. Kali Watu berarti sungai berbatu.",
     "River. Kali Watu means the rocky river."),
    ("tempat", "Pring",
     "Bambu. Jembatan Pring berarti jembatan bambu.",
     "Bamboo. Jembatan Pring means the bamboo bridge."),
    ("tempat", "Pecinan",
     "Kampung tempat tinggal warga keturunan Cina. Di game: asal gong beri milik bapak Roro Perot.",
     "The neighborhood where people of Chinese descent live. In the game: where Roro Perot's father got his gong beri."),
    ("tempat", "Pelataran",
     "Halaman luas di depan sebuah bangunan.",
     "A wide courtyard in front of a building."),

    ("busana", "Kebaya",
     "Baju perempuan Jawa. Kebaya kutubaru punya kain penghubung (bef) di bagian dada.",
     "The traditional Javanese women's blouse. The kutubaru style has a connecting panel (bef) across the chest."),
    ("busana", "Selendang",
     "Kain panjang yang disampirkan di bahu. Dalam tari disebut sampur.",
     "A long cloth draped over the shoulder. In dance it is called a sampur."),
    ("busana", "Sanggul",
     "Rambut yang digelung di belakang kepala, disebut juga konde.",
     "Hair coiled into a bun at the back of the head, also called a konde."),
    ("busana", "Cunduk mentul",
     "Hiasan sanggul berbentuk bunga di atas tangkai pegas, sehingga bergoyang saat dipakai.",
     "A flower-shaped hair ornament on a spring, so it trembles as the wearer moves."),
    ("busana", "Subang",
     "Anting yang dipasang di cuping telinga.",
     "An earring worn in the earlobe."),
    ("busana", "Bedak dingin",
     "Bedak tradisional dari beras yang direndam berhari-hari lalu dijemur menjadi butiran. Dipakai dengan sedikit air, rasanya sejuk di wajah. Di game: ciri khas Roro Perot.",
     "A traditional powder made from rice soaked for days and dried into small beads. Mixed with a little water, it feels cool on the face. In the game: Roro Perot's trademark."),
    ("busana", "Keris",
     "Senjata tikam khas Jawa; banyak yang bilahnya berkelok (luk). Gambar kartu Sabet.",
     "The Javanese dagger, often with a wavy (luk) blade. Shown on the Sabet card."),
    ("busana", "Padupan",
     "Tempat membakar dupa atau kemenyan. Gambar kartu Semedi.",
     "A burner for incense. Shown on the Semedi card."),
    ("busana", "Tombak",
     "Senjata berupa mata tajam di ujung tangkai panjang. Gambar kartu Tangkis Balik.",
     "A spear. Shown on the Tangkis Balik card."),
    ("busana", "Kawung",
     "Motif batik berupa empat bulatan seperti irisan buah aren. Menghiasi tameng di kartu Tangkis.",
     "A batik pattern of four ovals like slices of palm fruit. It decorates the shield on the Tangkis card."),
]

# Bentuk kata lain yang ikut ditandai di teks cerita (huruf kecil), misalnya
# kata berimbuhan seperti bersemedi atau tersirep.
EXTRA_FORMS = {
    "Semedi": ["bersemedi"],
    "Tabuh": ["tabuhan", "tabuhanmu", "tabuhannya", "ditabuh", "menabuh", "penabuh"],
    "Sirep": ["tersirep", "kusirep", "menyirep", "disirep"],
    "Ngamuk": ["mengamuk"],
    "Ronda": ["peronda"],
    "Ruwatan": ["ruwat"],
    "Sembur": ["semburan", "semburannya"],
    "Sabet": ["sabetan"],
    "Tangkis": ["tangkisan", "menangkis"],
    "Tempa": ["menempa", "tempaan"],
    "Arak-arakan": ["diarak", "mengarak"],
    "Bedak dingin": ["berbedak dingin"],
    "Cangkriman": ["cangkrimanku"],
}

# Istilah yang juga kata sehari-hari hanya ditandai di dalam nama tempatnya:
# kali berarti sungai, tetapi "dua kali" bukan sungai.
ONLY_FORMS = {
    "Kali": ["kali watu"],
    "Alas": ["alas jati peteng"],
    "Tegal": ["tegal ilalang"],
    "Pring": ["jembatan pring"],
}

# Frasa yang menunjuk beberapa istilah sekaligus; artinya ditampilkan berurutan.
JOINT_FORMS = {
    "eyang palang": ["Eyang", "Palang"],
}

# (kunci, nama Indonesia, nama Inggris)
ORIGIN_KINDS = [
    ("asli", "Dari kisah Dongkrek", "From the Dongkrek story"),
    ("budaya", "Dari budaya Jawa", "From Javanese culture"),
    ("rekaan", "Rekaan untuk game", "Made up for the game"),
]

# (jenis, judul Indonesia, judul Inggris, penjelasan Indonesia, penjelasan Inggris)
ORIGINS = [
    ("asli", "Mejayan dan tahun 1867", "Mejayan and the year 1867",
     "Dongkrek berasal dari Mejayan, Kabupaten Madiun. Menurut cerita yang dipegang masyarakat setempat, kesenian ini lahir sekitar tahun 1867. Ada juga penelitian yang menyebut tahun 1910.",
     "Dongkrek comes from Mejayan in Madiun Regency. According to the local account it was born around 1867, although one study dates it to 1910."),
    ("asli", "Eyang Palang", "Eyang Palang",
     "Tokoh dalam cerita asal-usul Dongkrek: Raden Ngabehi Lo Prawirodipuro, yang saat itu menjabat palang di Mejayan. Dalam pertunjukan, dialah orang tua sakti yang menaklukkan para Buto.",
     "The figure at the heart of Dongkrek's origin story: Raden Ngabehi Lo Prawirodipuro, who was then the palang of Mejayan. On stage he is the wise elder who subdues the Buto."),
    ("asli", "Pagebluk dan wangsit", "The plague and the vision",
     "Dongkrek lahir sebagai ritual tolak bala ketika wabah melanda desa. Menurut cerita, Eyang Palang bersemedi lalu mendapat wangsit untuk mengusir pagebluk dengan tabuhan dan arak-arakan keliling desa.",
     "Dongkrek was born as a ritual against a plague that struck the village. The story says Eyang Palang meditated and received a vision telling him to drive it away with music and a procession around the village."),
    ("asli", "Bunyi dung dan krek", "The sounds dung and krek",
     "Nama Dongkrek berasal dari bunyi bedug atau kendang (dung) dan korek (krek), alat kayu bergerigi yang digesek. Korek adalah alat musik khas Dongkrek.",
     "The name comes from the sound of the bedug or kendang (dung) and the korek (krek), a serrated wooden instrument that is rasped. The korek is unique to Dongkrek."),
    ("asli", "Gong, kenong, dan kentongan", "Gong, kenong, and kentongan",
     "Selain bedug dan korek, pertunjukan Dongkrek kemudian memakai gong, kenong, kentongan, kendang, dan gong beri (gong datar tanpa pencu). Di game, semuanya menjadi kartu Tabuh atau berkah.",
     "Besides the bedug and korek, Dongkrek later took up the gong, kenong, kentongan, kendang, and gong beri (a flat gong with no boss). In the game, all of them appear as Tabuh cards or blessings."),
    ("asli", "Para Buto bertopeng", "The masked Buto",
     "Pertunjukan Dongkrek menampilkan Buto atau genderuwo bertopeng seram sebagai lambang pagebluk, lalu ditaklukkan Eyang Palang.",
     "A Dongkrek performance features fierce masked Buto, or genderuwo, who stand for the plague and are subdued by Eyang Palang."),
    ("asli", "Roro Ayu dan Roro Perot", "Roro Ayu and Roro Perot",
     "Dua topeng perempuan dalam Dongkrek. Roro Ayu berwajah cantik, Roro Perot bermulut miring. Keduanya menggambarkan warga desa yang diincar makhluk jahat.",
     "The two female masks of Dongkrek: Roro Ayu is beautiful, Roro Perot has a crooked mouth. Both stand for villagers stalked by evil beings."),

    ("budaya", "Ajian dan kesaktian", "Ajian and supernatural powers",
     "Sapu Jagad, Lebur Saketi, dan Sirep adalah nama ajian dalam kepercayaan kejawen dan cerita rakyat Jawa. Dongkrek sendiri tidak berisi pertarungan ajian seperti ini.",
     "Sapu Jagad, Lebur Saketi, and Sirep are names of ajian from kejawen belief and Javanese folk tales. Dongkrek itself has no duels of this kind."),
    ("budaya", "Jurus silat", "Silat moves",
     "Sabet, Tangkis, Semedi, dan tenaga dalam berasal dari dunia pencak silat dan laku kebatinan Jawa.",
     "Sabet, Tangkis, Semedi, and tenaga dalam come from pencak silat and Javanese spiritual practice."),
    ("budaya", "Greget, wirama, dan gatra", "Greget, wirama, and gatra",
     "Istilah dari tari dan karawitan Jawa. Di game, greget menjadi semangat, wirama menjadi irama kartu, dan gatra menjadi empat ketukan tiap giliran.",
     "Terms from Javanese dance and gamelan music. In the game, greget becomes fighting spirit, wirama the rhythm of your cards, and gatra the four beats of each turn."),
    ("budaya", "Kehidupan desa", "Village life",
     "Jamu gendong, sesajen, ronda, dan pande gamelan adalah bagian kehidupan desa Jawa yang dijadikan kejadian di perjalanan.",
     "Jamu sellers, offerings, the night watch, and gamelan smiths are parts of Javanese village life that became the events of the journey."),
    ("budaya", "Busana dan benda", "Clothing and objects",
     "Kebaya, sanggul, cunduk mentul, keris, tombak, padupan, dan motif kawung adalah busana dan benda khas Jawa yang dipakai untuk menggambar tokoh dan kartu.",
     "The kebaya, sanggul, cunduk mentul, keris, spear, incense burner, and kawung pattern are Javanese clothing and objects used to draw the characters and cards."),
    ("budaya", "Ruwatan", "Ruwatan",
     "Upacara ruwat memang ada dalam budaya Jawa. Mode Ruwatan di game hanya meminjam namanya.",
     "The ruwat ceremony is a real Javanese tradition. The game's Ruwatan mode only borrows the name."),

    ("rekaan", "Lima warna Buto", "The five Buto colors",
     "Buto Kuning, Hijau, Merah, Putih, dan Hitam beserta ilmu masing-masing dibuat khusus untuk game.",
     "Buto Kuning, Hijau, Merah, Putih, and Hitam and their skills were made up for the game."),
    ("rekaan", "Buto Hitam, Buto Murka, dan Bala", "Buto Hitam, Buto Murka, and Bala",
     "Raja para Buto, Buto yang dibangkitkan lagi, dan Buto bayangan adalah rekaan untuk memberi tantangan di babak akhir.",
     "The Buto king, the risen Buto, and the shadow Buto are inventions that give the final acts their challenge."),
    ("rekaan", "Tempat-tempat di peta", "The places on the map",
     "Kecuali Desa Mejayan, tempat-tempat seperti Rumpun Bambu Wingit, Sendang Larangan, Alas Jati Peteng, dan Candi Pagebluk adalah tempat rekaan.",
     "Apart from Mejayan itself, places such as the haunted bamboo grove, the forbidden spring, the dark teak forest, and the Temple of the Plague are made up."),
    ("rekaan", "Perjalanan sepuluh babak", "The ten-act journey",
     "Kisah malam demi malam sebelum kesenian itu punya nama dikarang untuk game. Cerita aslinya berupa ritual dan arak-arakan keliling desa, bukan perjalanan melawan Buto satu per satu.",
     "The night-by-night story set before the art had a name was written for the game. The original account is a ritual procession around the village, not a journey fighting Buto one by one."),
    ("rekaan", "Peran Roro Ayu", "Roro Ayu's role",
     "Di Dongkrek, Roro Ayu adalah topeng dalam pertunjukan. Perannya sebagai gadis desa yang menemani Eyang Palang dan memberi berkah adalah rekaan.",
     "In Dongkrek, Roro Ayu is a mask in the performance. Her role as the village girl who travels with Eyang Palang and gives blessings is made up."),
    ("rekaan", "Aturan permainan", "The rules of play",
     "Kartu yang bisa digabung, Greget, Wirama, irama Sapu Jagad, Tantangan, dan Bintang Dongkrek adalah aturan permainan rekaan. Nama-namanya dipinjam dari bahasa dan budaya Jawa.",
     "Mergeable cards, Greget, Wirama, the Sapu Jagad rhythm, challenges, and Dongkrek Stars are game rules. Their names are borrowed from Javanese language and culture."),
    ("rekaan", "Kejadian di perjalanan", "Events on the road",
     "Pertemuan dengan mbok jamu, pande gamelan, peronda, dan Buto kecil yang tersesat adalah rekaan, meski tokoh-tokohnya akrab dalam kehidupan desa Jawa.",
     "Meeting the jamu seller, the gamelan smith, the night watch, and the lost little Buto are made up, even though such people are familiar in Javanese village life."),
    ("rekaan", "Peran Roro Perot", "Roro Perot's role",
     "Di Dongkrek, Roro Perot adalah topeng jenaka. Di game ia menjadi kawan Roro Ayu yang berbedak dingin dan gemar cangkriman. Peran itu rekaan, begitu juga gong beri dari Pecinan milik bapaknya.",
     "In Dongkrek, Roro Perot is a comic mask. In the game she is Roro Ayu's friend who wears bedak dingin and loves riddles. That role is made up, and so is her father's gong beri from the Pecinan."),
]

# Rujukan yang dipakai saat menyusun isi di atas (untuk dokumen).
SOURCES = [
    ("Perilaku komunikasi dalam ritual tolak bala kesenian Dongkrek (Telkom University)",
     "https://repository.telkomuniversity.ac.id/pustaka/files/180574/bab1/perilaku-komunikasi-dalam-ritual-tolak-bala-kesenian-dongkrek-di-desa-mejayan-kabupaten-madiun.pdf"),
    ("Dongkrek: An Islamic Literature and Artform in Madiun, East Java (Litera, UNY)",
     "https://journal.uny.ac.id/index.php/litera/article/view/26260"),
    ("Karakteristik Topeng Dongkrek Sanggar Krido Sakti (Unesa)",
     "https://ejournal.unesa.ac.id/index.php/va/article/view/11561"),
    ("Kesenian Dongkrek, Warisan Budaya Tak Benda Indonesia (GNFI)",
     "https://www.goodnewsfromindonesia.id/2023/11/06/kesenian-dongkrek-warisan-budaya-tak-benda-indonesia"),
    ("Analisis musik kesenian Dongkrek di Balerejo, Madiun (UNY)",
     "https://journal.student.uny.ac.id/musik/article/download/9819/9473"),
    ("Jurnal Dinamika tentang Dongkrek",
     "https://jurnal.dinamika.ac.id/index.php/ArtNouveau/article/download/2031/638"),
    ("Gatra (music), Wikipedia", "https://en.wikipedia.org/wiki/Gatra_(music)"),
    ("Mengenal Ajian Inti Lebur Saketi (Kumparan)",
     "https://kumparan.com/dukun-millennial/mengenal-ajian-inti-lebur-saketi-1tJmg4vMdPG"),
    ("Makna Analogi Sapu Jagad (Buddhazine)", "https://buddhazine.com/makna-analogi-sapu-jagad/"),
    ("Mengenal ragam paes pengantin pada pernikahan adat Jawa (GNFI)",
     "https://www.goodnewsfromindonesia.id/2021/01/12/mengenal-ragam-paes-pengantin-pada-pernikahan-adat-jawa"),
    ("Perbedaan kebaya tangkepan dan kutubaru (Zalora)",
     "https://www.zalora.co.id/blog/fashion/review/perbedaan-kebaya-tangkepan-dan-kutubaru/"),
]


def slug(text: str) -> str:
    return re.sub(r"[^A-Z0-9]+", "_", text.upper()).strip("_")


def gloss_key(term: str) -> str:
    return "GLOSS_" + slug(term)


def origin_key(title_id: str) -> str:
    return "ORIGIN_" + slug(title_id)


def forms() -> dict[str, list[str]]:
    """Bentuk kata di teks (huruf kecil) -> kunci istilah yang dijelaskan."""
    terms = {term: gloss_key(term) for _cat, term, _i, _e in GLOSSARY}
    out: dict[str, list[str]] = {}

    def add(form: str, names: list[str]) -> None:
        assert re.fullmatch(r"[a-z]+(?:[ -][a-z]+)*", form), form
        assert form not in out, "bentuk ganda: " + form
        out[form] = [terms[n] for n in names]

    for _cat, term, _i, _e in GLOSSARY:
        for form in ONLY_FORMS.get(term, [term.lower()]):
            add(form, [term])
        for form in EXTRA_FORMS.get(term, []):
            add(form, [term])
    for form, names in JOINT_FORMS.items():
        add(form, names)
    unknown = (set(EXTRA_FORMS) | set(ONLY_FORMS)) - set(terms)
    assert not unknown, unknown
    return out


def strings() -> list[tuple[str, str, str]]:
    """Teks dua bahasa untuk tools/strings_source.py."""
    out = []
    for key, name_id, name_en in CATEGORIES:
        out.append(("GLOSS_CAT_" + key.upper(), name_id, name_en))
    for _cat, term, text_id, text_en in GLOSSARY:
        out.append((gloss_key(term), text_id, text_en))
    for key, name_id, name_en in ORIGIN_KINDS:
        out.append(("ORIGIN_KIND_" + key.upper(), name_id, name_en))
    for _kind, title_id, title_en, text_id, text_en in ORIGINS:
        base = origin_key(title_id)
        out.append((base + "_TITLE", title_id, title_en))
        out.append((base + "_TEXT", text_id, text_en))
    return out


def write_gdscript() -> str:
    lines = [
        "class_name GlossaryData",
        "extends RefCounted",
        "## Dibuat oleh tools/glossary_source.py; ubah di sana, bukan di sini.",
        "## Urutan istilah untuk halaman Istilah Jawa dan daftar Asli atau Rekaan di",
        "## Pustaka. Teksnya ada di localization (kunci GLOSS_* dan ORIGIN_*).",
        "",
        "const CATEGORIES: Array[String] = [%s]" % ", ".join('"%s"' % k for k, _a, _b in CATEGORIES),
        "const TERMS: Array[Dictionary] = [",
    ]
    for cat, term, _i, _e in GLOSSARY:
        lines.append('\t{"cat": "%s", "term": "%s", "key": "%s"},' % (cat, term, gloss_key(term)))
    lines.append("]")
    lines.append("## Bentuk kata di teks (huruf kecil) -> istilah yang dijelaskan (lihat GlossaryText).")
    lines.append("const FORMS: Dictionary = {")
    for form, keys in forms().items():
        lines.append('\t"%s": [%s],' % (form, ", ".join('"%s"' % k for k in keys)))
    lines.append("}")
    lines.append("const ORIGIN_KINDS: Array[String] = [%s]" % ", ".join('"%s"' % k for k, _a, _b in ORIGIN_KINDS))
    lines.append("const ORIGINS: Array[Dictionary] = [")
    for kind, title_id, _te, _ti, _tn in ORIGINS:
        lines.append('\t{"kind": "%s", "key": "%s"},' % (kind, origin_key(title_id)))
    lines.append("]")
    path = os.path.join(ROOT, "core", "content", "glossary_data.gd")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return path


def write_doc() -> str:
    out = [
        "# Istilah Jawa dan Asli atau Rekaan",
        "",
        "Dokumen ini berisi isi dua halaman baru di Pustaka: **Istilah Jawa** dan **Asli atau Rekaan**. "
        "Isinya dibuat dari `tools/glossary_source.py`, jadi kalau ada yang mau diubah, ubah di file itu lalu "
        "jalankan `python3 tools/glossary_source.py` dan `python3 tools/strings_source.py`. Dokumen ini, teks di "
        "game (Indonesia dan Inggris), dan urutan di Pustaka akan ikut berubah.",
        "",
        "## Istilah Jawa",
        "",
        "Setiap istilah diberi arti aslinya, lalu (kalau ada) perannya di game.",
        "",
    ]
    for key, name_id, _en in CATEGORIES:
        out.append("### " + name_id)
        out.append("")
        out.append("| Istilah | Arti dan pemakaiannya di game |")
        out.append("|---|---|")
        for cat, term, text_id, _te in GLOSSARY:
            if cat == key:
                out.append("| **%s** | %s |" % (term, text_id))
        out.append("")
    out += [
        "## Asli atau Rekaan",
        "",
        "Game ini terinspirasi dari kisah Dongkrek, tetapi banyak bagiannya dikarang untuk kebutuhan permainan. "
        "Setiap unsur di bawah diberi salah satu dari tiga tanda:",
        "",
        "- **Dari kisah Dongkrek**: ada dalam cerita asal-usul atau pertunjukan Dongkrek.",
        "- **Dari budaya Jawa**: nyata dalam budaya Jawa, tetapi bukan bagian khusus dari Dongkrek.",
        "- **Rekaan untuk game**: dibuat untuk game ini.",
        "",
    ]
    for key, name_id, _en in ORIGIN_KINDS:
        out.append("### " + name_id)
        out.append("")
        for kind, title_id, _te, text_id, _tn in ORIGINS:
            if kind == key:
                out.append("- **%s.** %s" % (title_id, text_id))
        out.append("")
    out += [
        "## Catatan tentang sumber",
        "",
        "- Tahun kelahiran Dongkrek ditulis berbeda-beda: kebanyakan menyebut 1867, satu penelitian menyebut 1910. "
        "Game mengikuti 1867, yang dipegang masyarakat Mejayan.",
        "- Ada sumber yang menyebut jabatan Eyang Palang sebagai wedana. Game memakai sebutan palang, sesuai namanya.",
        "- Dongkrek sering disebut sebagai warisan budaya takbenda Indonesia, tetapi tahun penetapan resminya belum "
        "saya temukan, jadi tidak dicantumkan di game.",
        "- Sapu Jagad dan Lebur Saketi dikenal sebagai nama ajian dalam kepercayaan kejawen. Sumbernya kebanyakan "
        "tulisan populer dan cerita turun-temurun, bukan catatan sejarah.",
        "- Arti istilah Jawa yang umum (misalnya prayitna, greget, wirama) ditulis dari pengetahuan bahasa Jawa sehari-hari. "
        "Kalau mau lebih pasti, bisa dicocokkan dengan kamus Baoesastra Djawa.",
        "",
        "## Rujukan",
        "",
    ]
    for title, url in SOURCES:
        out.append("- [%s](%s)" % (title, url))
    path = os.path.join(ROOT, "docs", "05-istilah-jawa-dan-asli-rekaan.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    return path


if __name__ == "__main__":
    print("ditulis:", write_gdscript())
    print("ditulis:", write_doc())
    print(len(GLOSSARY), "istilah,", len(ORIGINS), "unsur asli/rekaan")
