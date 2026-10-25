"""Sumber teks dua bahasa (Indonesia / English) untuk game.

Jalankan dari root repo untuk menulis ulang localization/strings.csv:
    python3 tools/strings_source.py

Godot membaca strings.csv dan membuat file .translation saat project dibuka.
Tambah atau ubah teks di daftar STRINGS di bawah, lalu jalankan lagi script ini.
Kunci yang diakhiri angka/%d dipakai dengan format % di GDScript.
"""
import csv
import os

STRINGS = [
    # ------------------------------------------------------------------ umum
    ("GAME_TITLE", "DONGKREK", "DONGKREK"),
    ("GAME_SUBTITLE", "Legenda Eyang Palang", "The Legend of Eyang Palang"),
    ("BTN_YES", "Ya", "Yes"),
    ("BTN_NO", "Tidak", "No"),
    ("BTN_BACK", "Kembali", "Back"),
    ("BTN_CLOSE", "Tutup", "Close"),
    ("BTN_CONTINUE", "Lanjut", "Continue"),
    ("BTN_RETRY", "Coba Lagi", "Try Again"),
    ("BTN_TO_MAP", "Ke Peta", "To Map"),
    ("BTN_RESUME", "Lanjut Main", "Resume"),
    ("BTN_MAIN_MENU", "Menu Utama", "Main Menu"),
    ("BTN_SKIP", "Lewati", "Skip"),
    ("BTN_FIGHT", "Bertarung", "Fight"),
    ("BTN_NEXT", "Berikutnya", "Next"),
    ("HINT_CLICK_CONTINUE", "Klik untuk lanjut", "Click to continue"),

    # ------------------------------------------------------------- menu utama
    ("MENU_NEW", "Petualangan Baru", "New Journey"),
    ("MENU_CONTINUE", "Lanjutkan", "Continue"),
    ("MENU_PUSTAKA", "Pustaka", "Codex"),
    ("MENU_SETTINGS", "Pengaturan", "Settings"),
    ("MENU_QUIT", "Keluar", "Quit"),
    ("MENU_CONFIRM_NEW", "Mulai dari awal? Progres yang tersimpan akan hilang.", "Start over? Your saved progress will be lost."),
    ("MENU_CREDIT_LINE", "Terinspirasi dari kesenian Dongkrek, Mejayan, Madiun", "Inspired by the Dongkrek folk art of Mejayan, Madiun"),

    # -------------------------------------------------------------- pengaturan
    ("SETTINGS_TITLE", "Pengaturan", "Settings"),
    ("SETTINGS_LANGUAGE", "Bahasa", "Language"),
    ("SETTINGS_MUSIC", "Musik", "Music"),
    ("SETTINGS_SFX", "Efek Suara", "Sound Effects"),
    ("SETTINGS_FULLSCREEN", "Layar Penuh", "Fullscreen"),
    ("LANG_ID", "Bahasa Indonesia", "Bahasa Indonesia"),
    ("LANG_EN", "English", "English"),

    # -------------------------------------------------------------------- peta
    ("MAP_TITLE", "Perjalanan Eyang Palang", "Eyang Palang's Journey"),
    ("MAP_HINT", "Pilih tujuan berikutnya.", "Choose your next destination."),
    ("MAP_STAGE", "Stage %d", "Stage %d"),
    ("MAP_LOCKED", "Terkunci", "Locked"),
    ("MAP_CLEARED", "Selesai", "Cleared"),
    ("MAP_ENEMIES", "Lawan:", "Enemies:"),
    ("MAP_DECK", "Deck", "Deck"),
    ("MAP_HP", "HP Eyang Palang: %d", "Eyang Palang HP: %d"),
    ("MAP_ALL_CLEAR", "Semua Buto telah diusir. Tonton lagi akhir ceritanya?", "Every Buto has been driven away. Watch the ending again?"),
    ("MAP_ENDING", "Akhir Cerita", "Ending"),
    ("STAGE_1_TITLE", "Pinggir Desa Mejayan", "Outskirts of Mejayan"),
    ("STAGE_2_TITLE", "Rumpun Bambu Wingit", "The Haunted Bamboo Grove"),
    ("STAGE_3_TITLE", "Sendang Larangan", "The Forbidden Spring"),
    ("STAGE_4_TITLE", "Gapura Candi Tua", "Gate of the Old Temple"),
    ("STAGE_5_TITLE", "Candi Pagebluk", "Temple of the Plague"),

    # ------------------------------------------------------------------ battle
    ("BATTLE_TURN", "Turn %d", "Turn %d"),
    ("BATTLE_END_TURN", "Akhiri Turn", "End Turn"),
    ("BATTLE_ULTIMATE", "Gebrakan Palang", "Palang Strike"),
    ("BATTLE_ULTIMATE_SHORT", "GEBRAKAN", "ULTIMATE"),
    ("BATTLE_ULTIMATE_TIP", "Ultimate: menghantam SEMUA Buto %d. Butuh Moxie 100%%. Di 200%% damage-nya dua kali lipat.", "Ultimate: hits EVERY Buto for %d. Needs 100%% Moxie. At 200%% it deals double damage."),
    ("BATTLE_PLAYER_TURN", "Giliranmu", "Your Turn"),
    ("BATTLE_ENEMY_TURN", "Giliran Buto", "Buto's Turn"),
    ("BATTLE_VICTORY", "MENANG!", "VICTORY!"),
    ("BATTLE_DEFEAT", "KALAH...", "DEFEATED..."),
    ("BATTLE_DEFEAT_HINT", "Para Buto masih berkeliaran. Atur siasat, lalu coba lagi.", "The Buto still roam free. Rethink your tactics and try again."),
    ("BATTLE_NO_AP", "AP tidak cukup", "Not enough AP"),
    ("BATTLE_CARD_LOCKED", "Kartu tersirep", "Card under Sirep"),
    ("BATTLE_CHAIN", "Evolutionary Chain!", "Evolutionary Chain!"),
    ("BATTLE_PHASE2", "Buto Hitam murka!", "Buto Hitam is enraged!"),
    ("BATTLE_MERGE", "Gabung", "Merge"),
    ("BATTLE_MERGE_TIP", "Gabungkan dua kartu ini (gratis)", "Merge these two cards (free)"),
    ("BATTLE_DECK_TIP", "Dek: %d kartu", "Deck: %d cards"),
    ("BATTLE_DISCARD_TIP", "Buangan: %d kartu", "Discard: %d cards"),
    ("BATTLE_PAUSED", "Jeda", "Paused"),
    ("BATTLE_BLOCK", "Tameng", "Block"),
    ("BATTLE_POISON_TIP", "Racun %d: kehilangan %d HP di akhir giliran Buto (menembus Tameng).", "Poison %d: lose %d HP at the end of the Buto's turn (ignores Block)."),
    ("BATTLE_BLOCK_TIP", "Tameng %d: menahan damage sampai awal turn berikutnya.", "Block %d: absorbs damage until your next turn."),
    ("BATTLE_AP_TIP", "AP: main kartu 1 AP, geser kartu 1 AP.", "AP: playing a card costs 1 AP, moving a card costs 1 AP."),
    ("BATTLE_MOXIE_TIP", "Moxie %d%%. Kartu Fokus mengisinya. 100%% = Ultimate siap, sampai 200%% = Overcharge.", "Moxie %d%%. Focus cards charge it. 100%% = Ultimate ready, up to 200%% = Overcharge."),
    ("BATTLE_CHAIN_TIP", "Evolutionary Chain %d/3: mainkan 3 kartu bintang 3 berturut-turut untuk memperkuat Ultimate (sekarang x%.2f).", "Evolutionary Chain %d/3: play 3 rank-3 cards in a row to power up your Ultimate (now x%.2f)."),
    ("BATTLE_HELP", "Klik kartu: mainkan  |  Seret kartu: geser  |  Klik Buto: pilih target  |  Spasi: akhiri turn", "Click card: play  |  Drag card: move  |  Click Buto: target  |  Space: end turn"),
    ("BATTLE_HAND_SHUFFLED", "Tangan diacak!", "Hand shuffled!"),
    ("BATTLE_CARD_LOCKED_BY", "Sirep!", "Sirep!"),
    ("BATTLE_MOXIE_DRAINED", "Moxie -%d%%", "Moxie -%d%%"),
    ("BATTLE_CHARGING", "Ancang-ancang!", "Winding up!"),

    # ------------------------------------------------------------------- kartu
    ("CARD_SERANG", "Serang", "Attack"),
    ("CARD_FOKUS", "Fokus", "Focus"),
    ("CARD_TAKTIK", "Taktik", "Tactic"),
    ("CARD_CRIMSON", "Crimson Focus", "Crimson Focus"),
    ("CARD_PIERCING", "Piercing Strike", "Piercing Strike"),
    ("CARD_FLOW", "Flow State", "Flow State"),
    ("CARD_SERANG_SHORT", "SERANG", "ATTACK"),
    ("CARD_FOKUS_SHORT", "FOKUS", "FOCUS"),
    ("CARD_TAKTIK_SHORT", "TAKTIK", "TACTIC"),
    ("CARD_CRIMSON_SHORT", "CRIMSON", "CRIMSON"),
    ("CARD_PIERCING_SHORT", "PIERCING", "PIERCING"),
    ("CARD_FLOW_SHORT", "FLOW", "FLOW"),
    ("CARD_SERANG_DESC", "Hantaman tongkat Eyang Palang.", "A blow from Eyang Palang's staff."),
    ("CARD_FOKUS_DESC", "Menenangkan batin, mengisi Moxie.", "Calms the mind and charges Moxie."),
    ("CARD_TAKTIK_DESC", "Kuda-kuda bertahan ala pendekar.", "A defensive martial stance."),
    ("CARD_CRIMSON_DESC", "Serang + Fokus. Pukulan berat sambil mengisi Moxie.", "Attack + Focus. A heavy blow that also charges Moxie."),
    ("CARD_PIERCING_DESC", "Serang + Taktik. Tusukan tongkat sambil bertahan.", "Attack + Tactic. A staff thrust that also guards."),
    ("CARD_FLOW_DESC", "Fokus + Taktik. Gerak mengalir: Tameng, Moxie, dan AP kembali.", "Focus + Tactic. Flowing motion: Block, Moxie, and AP back."),
    ("EFFECT_DAMAGE", "Damage %d", "Damage %d"),
    ("EFFECT_BLOCK", "Tameng %d", "Block %d"),
    ("EFFECT_AP", "+%d AP", "+%d AP"),
    ("EFFECT_MOXIE", "Moxie +%d%%", "Moxie +%d%%"),
    ("CARD_RANK", "Bintang %d", "Rank %d"),
    ("CARD_LOCKED_TIP", "Tersirep %d giliran: tidak bisa dimainkan, digeser, atau digabung.", "Under Sirep for %d turn(s): can't be played, moved, or merged."),
    ("CARD_MERGE_HINT", "Gabung: kartu beda warna dengan bintang sama yang bersebelahan.", "Merge: adjacent cards of different colors with the same rank."),

    # ---------------------------------------------------------------- niat Buto
    ("INTENT_ATTACK", "Akan menyerang %d", "Will attack for %d"),
    ("INTENT_DRAIN", "Menyerang %d dan menguras %d%% Moxie Overcharge", "Attacks for %d and drains %d%% Overcharge Moxie"),
    ("INTENT_LOCK", "Akan menyirep %d kartu terkuatmu selama 1 giliran", "Will cast Sirep on your %d strongest card(s) for 1 turn"),
    ("INTENT_SHUFFLE", "Menghantam %d lalu mengacak tangan dan deck", "Hits for %d, then shuffles your hand and deck"),
    ("INTENT_POISON", "Menyembur %d dan memberi %d Racun", "Spits for %d and applies %d Poison"),
    ("INTENT_CHARGE", "Ancang-ancang: turn depan pukulan berat %d", "Winding up: next turn a heavy blow for %d"),
    ("INTENT_HEAVY", "Pukulan berat %d!", "Heavy blow for %d!"),

    # ------------------------------------------------------------------- Buto
    ("BUTO_KUNING", "Buto Kuning", "Buto Kuning"),
    ("BUTO_HIJAU", "Buto Hijau", "Buto Hijau"),
    ("BUTO_MERAH", "Buto Merah", "Buto Merah"),
    ("BUTO_PUTIH", "Buto Putih", "Buto Putih"),
    ("BUTO_HITAM", "Buto Hitam", "Buto Hitam"),

    # ------------------------------------------------------------------- berkah
    ("REWARD_TITLE", "Berkah Roro Ayu", "Roro Ayu's Blessing"),
    ("REWARD_HINT", "Pilih satu berkah untuk perjalanan berikutnya.", "Choose one blessing for the road ahead."),
    ("BLESS_TEMPA", "Tempa Tongkat", "Temper the Staff"),
    ("BLESS_TEMPA_DESC", "2 kartu Serang naik satu bintang.", "Upgrade 2 Attack cards by one rank."),
    ("BLESS_FOKUS", "Olah Batin", "Inner Focus"),
    ("BLESS_FOKUS_DESC", "2 kartu Fokus naik satu bintang.", "Upgrade 2 Focus cards by one rank."),
    ("BLESS_TAKTIK", "Siasat Leluhur", "Ancestral Tactics"),
    ("BLESS_TAKTIK_DESC", "2 kartu Taktik naik satu bintang.", "Upgrade 2 Tactic cards by one rank."),
    ("BLESS_JAMU", "Jamu Kunyit Asam", "Turmeric Tonic"),
    ("BLESS_JAMU_DESC", "HP maksimal Eyang Palang +10.", "Eyang Palang's max HP +10."),
    ("REWARD_DONE", "Berkah diterima!", "Blessing received!"),

    # --------------------------------------------------------------- pembicara
    ("SPEAKER_NARATOR", "Narator", "Narrator"),
    ("SPEAKER_EYANG", "Eyang Palang", "Eyang Palang"),
    ("SPEAKER_WARGA", "Warga Desa", "Villager"),
    ("SPEAKER_RORO_AYU", "Roro Ayu", "Roro Ayu"),
    ("SPEAKER_BUTO_KUNING", "Buto Kuning", "Buto Kuning"),
    ("SPEAKER_BUTO_HIJAU", "Buto Hijau", "Buto Hijau"),
    ("SPEAKER_BUTO_MERAH", "Buto Merah", "Buto Merah"),
    ("SPEAKER_BUTO_PUTIH", "Buto Putih", "Buto Putih"),
    ("SPEAKER_BUTO_HITAM", "Buto Hitam", "Buto Hitam"),

    # ------------------------------------------------------------------ cerita
    ("PROLOGUE_1", "Madiun, masa silam. Pagebluk melanda Desa Mejayan. Pagi sakit, sore meninggal. Sore sakit, pagi meninggal.",
     "Madiun, long ago. A plague swept through the village of Mejayan. Sick in the morning, gone by evening. Sick by evening, gone by morning."),
    ("PROLOGUE_2", "Para sesepuh percaya pagebluk itu dibawa para Buto, raksasa jahat dari candi tua di tengah hutan.",
     "The elders believed the plague was brought by the Buto, wicked giants from an old temple deep in the forest."),
    ("PROLOGUE_3", "Eyang... kalau terus begini, desa kita bisa habis.",
     "Eyang... if this goes on, there won't be a village left."),
    ("PROLOGUE_4", "Dalam semedinya, Eyang Palang mendapat petunjuk: Buto takut pada bunyi bedug yang bertalu dan korek yang berderak. Dung... krek. Dung... krek.",
     "In meditation, Eyang Palang received a sign: the Buto fear the pounding bedug drum and the rattling korek. Dung... krek. Dung... krek."),
    ("PROLOGUE_5", "Ambilkan tongkatku. Malam ini juga kita usir mereka dari Mejayan.",
     "Fetch my staff. Tonight we drive them out of Mejayan."),

    ("S1_INTRO_1", "Di pinggir desa, sesosok raksasa bertopeng kuning mengendus-endus pagar bambu.",
     "At the edge of the village, a giant in a yellow mask sniffs along the bamboo fence."),
    ("S1_INTRO_2", "Buto Kuning. Yang paling rakus di antara mereka.", "Buto Kuning. The greediest of them all."),
    ("S1_INTRO_3", "Hrrgh... semangatmu harum sekali, Pak Tua. Biar kuhisap sampai habis!",
     "Hrrgh... your spirit smells delicious, old man. I'll drain every last drop!"),
    ("S1_INTRO_4", "Coba saja kalau berani.", "Try it, if you dare."),
    ("S1_WIN_1", "Buto itu lari! Eyang berhasil!", "The Buto ran off! Eyang did it!"),
    ("S1_WIN_2", "Itu baru satu. Jejaknya mengarah ke rumpun bambu di utara.", "That was only one. Its tracks lead to the bamboo grove up north."),

    ("TUT_1", "Setiap turn kamu punya 4 AP. Klik sebuah kartu untuk memainkannya ke Buto yang sedang jadi target. Biayanya 1 AP.",
     "Each turn you have 4 AP. Click a card to play it on the targeted Buto. It costs 1 AP."),
    ("TUT_2", "Kartu merah (Serang) memberi damage, kartu biru (Fokus) mengisi Moxie, kartu hijau (Taktik) memberi Tameng.",
     "Red cards (Attack) deal damage, blue cards (Focus) charge Moxie, green cards (Tactic) give Block."),
    ("TUT_3", "Seret kartu ke posisi lain untuk menggesernya (1 AP). Kalau ia bersebelahan dengan kartu beda warna yang bintangnya sama, keduanya bergabung jadi kartu hybrid yang lebih kuat.",
     "Drag a card to another position to move it (1 AP). If it lands next to a different-colored card of the same rank, they merge into a stronger hybrid card."),
    ("TUT_4", "Kartu yang sudah bersebelahan bisa langsung digabung gratis lewat tombol kecil di antara keduanya.",
     "Cards that are already side by side can be merged for free with the small button between them."),
    ("TUT_5", "Saat Moxie mencapai 100%, Gebrakan Palang siap dan menghantam semua Buto. Tahan sampai 200% untuk damage dua kali lipat.",
     "When Moxie reaches 100%, Palang Strike is ready and hits every Buto. Hold it until 200% for double damage."),
    ("TUT_6", "Perhatikan ikon di atas kepala Buto: itu rencana mereka di giliran berikutnya. Kalau sudah selesai, tekan Akhiri Turn.",
     "Watch the icon above each Buto's head: it shows what they plan to do next. When you're done, press End Turn."),

    ("S2_INTRO_1", "Rumpun bambu berderit tertiup angin. Bau anyir menusuk hidung.", "The bamboo creaks in the wind. A foul stench fills the air."),
    ("S2_INTRO_2", "Hehehe... napasku membawa penyakit. Hirup dalam-dalam, Pak Tua!", "Hehehe... my breath carries sickness. Breathe deep, old man!"),
    ("S2_INTRO_3", "Racunmu takkan bertahan lama. Bedug, tabuh!", "Your poison won't last. Drums, sound!"),
    ("S2_WIN_1", "Racunnya mulai pudar dari udara.", "The poison is fading from the air."),
    ("S2_WIN_2", "Warga yang sakit perlahan bisa bernapas lega. Tapi di arah sendang, airnya berubah merah.",
     "The sick villagers can finally breathe easier. But toward the spring, the water has turned red."),

    ("S3_INTRO_1", "Sendang Larangan, mata air yang tak boleh dijamah. Sesosok Buto merah berendam di dalamnya.",
     "Sendang Larangan, the spring no one may touch. A red Buto is soaking in its waters."),
    ("S3_INTRO_2", "GRAAAH! Siapa berani mengganggu tidurku?! Kuremukkan tulangmu!", "GRAAAH! Who dares disturb my sleep?! I'll crush your bones!"),
    ("S3_INTRO_3", "Tenagamu besar, tapi ancang-ancangmu terlalu lama. Di situ celahmu.", "You're strong, but your wind-up is far too slow. That's your weakness."),
    ("S3_WIN_1", "Airnya kembali jernih.", "The water runs clear again."),
    ("S3_WIN_2", "Eyang, aku Roro Ayu. Kami para perempuan desa ikut menabuh dari jauh. Bawalah doa kami.",
     "Eyang, I'm Roro Ayu. We women of the village are drumming from afar. Take our prayers with you."),

    ("S4_INTRO_1", "Gapura candi tua menjulang. Buto bertopeng putih berjaga di depannya.", "The old temple gate towers overhead. A Buto in a white mask stands guard."),
    ("S4_INTRO_2", "Ilmu orang tua... akan kubelenggu. Tanganmu takkan bisa bergerak bebas.", "An old man's tricks... I'll bind them. Your hands won't move freely."),
    ("S4_INTRO_3", "Kartuku boleh terkunci, tekadku tidak.", "You can lock my cards, but not my resolve."),
    ("S4_WIN_1", "Gapura sudah terbuka. Di dalam sana ada sumber semua pagebluk ini.", "The gate is open. Inside lies the source of this whole plague."),
    ("S4_WIN_2", "Dari dalam candi terdengar geraman yang membuat tanah bergetar.", "From inside the temple comes a growl that shakes the ground."),

    ("S5_INTRO_1", "Di jantung candi, Buto Hitam menunggu. Dialah raja para Buto, biang pagebluk.",
     "At the heart of the temple waits Buto Hitam, king of the Buto and the root of the plague."),
    ("S5_INTRO_2", "Jadi kau yang mengusir anak buahku. Bunyi bedugmu tak ada artinya di sini!", "So you're the one who chased off my servants. Your drums mean nothing here!"),
    ("S5_INTRO_3", "Selama warga Mejayan masih menabuh, aku takkan mundur.", "As long as Mejayan keeps drumming, I will not step back."),
    ("S5_INTRO_4", "Kalau begitu, akan kuporak-porandakan semua rencanamu!", "Then I'll tear every one of your plans apart!"),
    ("S5_WIN_1", "Dung... krek... bunyi itu... AAARGH!", "Dung... krek... that sound... AAARGH!"),
    ("S5_WIN_2", "Pulanglah ke tempatmu. Jangan ganggu Mejayan lagi.", "Go back where you belong. Leave Mejayan in peace."),

    ("ENDING_TITLE", "Pagebluk Sirna", "The Plague Is Lifted"),
    ("ENDING_1", "Pagebluk pun sirna. Satu per satu warga Mejayan pulih dari sakitnya.", "And so the plague was lifted. One by one, the people of Mejayan recovered."),
    ("ENDING_2", "Mulai hari ini kita tabuh bedug dan korek setiap tahun, supaya para Buto tak lupa.",
     "From now on we'll play the bedug and korek every year, so the Buto never forget."),
    ("ENDING_3", "Dan supaya anak cucu kita ingat: warga yang bersatu lebih kuat dari raksasa mana pun.",
     "And so our grandchildren remember: a village that stands together is stronger than any giant."),
    ("ENDING_4", "Dari peristiwa itu lahirlah Dongkrek, kesenian tolak bala khas Madiun yang masih dimainkan sampai sekarang.",
     "From that night came Dongkrek, Madiun's art of warding off evil, still performed to this day."),
    ("ENDING_5", "Terima kasih sudah menemani perjalanan Eyang Palang.", "Thank you for joining Eyang Palang on his journey."),
    ("CREDITS_TITLE", "Kredit", "Credits"),
    ("CREDITS_TEXT",
     "Desain karakter, kartu, dan latar: pemilik proyek\nPemrograman, aset tambahan, musik, dan efek suara: dibuat bersama Claude\nFont: Tiny5 & Silkscreen (SIL Open Font License)\nMesin: Godot Engine\n\nTerinspirasi dari kesenian Dongkrek, Mejayan, Kabupaten Madiun, Jawa Timur.",
     "Character, card, and background design: project owner\nProgramming, extra assets, music, and sound: made together with Claude\nFonts: Tiny5 & Silkscreen (SIL Open Font License)\nEngine: Godot Engine\n\nInspired by the Dongkrek folk art of Mejayan, Madiun Regency, East Java."),

    # ----------------------------------------------------------------- pustaka
    ("PUSTAKA_TITLE", "Pustaka Dongkrek", "Dongkrek Codex"),
    ("PUSTAKA_LOCKED", "Belum pernah ditemui. Lanjutkan perjalanan untuk membuka entri ini.", "Not encountered yet. Keep travelling to unlock this entry."),
    ("PUSTAKA_DONGKREK", "Kesenian Dongkrek", "The Dongkrek Art"),
    ("PUSTAKA_DONGKREK_TEXT",
     "Dongkrek adalah kesenian dari Mejayan, Kabupaten Madiun, Jawa Timur. Namanya berasal dari bunyi bedug (dung) dan korek (krek), alat musik dari kayu bergerigi yang digesek.\n\nMenurut cerita turun-temurun, kesenian ini lahir sekitar tahun 1867 untuk mengusir pagebluk yang melanda desa. Pertunjukannya menampilkan para Buto bertopeng, Roro Ayu dan Roro Perot, serta Eyang Palang yang akhirnya menaklukkan para Buto.\n\nKisah di game ini terinspirasi dari cerita tersebut, tetapi beberapa bagiannya dikarang untuk kebutuhan permainan. Desa Mejayan memang ada, sedangkan rumpun bambu, sendang, gapura, dan candi di peta adalah tempat rekaan. Warna dan ilmu tiap Buto juga dibuat khusus untuk game ini.",
     "Dongkrek is a folk art from Mejayan in Madiun Regency, East Java. Its name comes from the sound of the bedug drum (dung) and the korek (krek), a notched wooden instrument that is scraped.\n\nAccording to local tradition, it was created around 1867 to drive away a plague that struck the village. Performances feature masked Buto giants, Roro Ayu and Roro Perot, and Eyang Palang, who finally subdues the Buto.\n\nThe story in this game is inspired by that tale, but some parts were invented for the game. Mejayan is a real village, while the bamboo grove, spring, gate, and temple on the map are fictional places. Each Buto's color and skill were also created for this game."),
    ("PUSTAKA_EYANG", "Eyang Palang", "Eyang Palang"),
    ("PUSTAKA_EYANG_TEXT",
     "Sesepuh desa yang berwibawa, selalu membawa tongkat. Dalam cerita asal-usul Dongkrek, tokoh ini dikenal sebagai Raden Ngabehi Lo Prawirodipuro dari Mejayan. Lewat semedi ia mendapat petunjuk untuk membuat tarian yang mengiringi keluarnya makhluk jahat dari desa. Dalam pertunjukan Dongkrek, dialah yang menaklukkan para Buto dan mengembalikan ketenteraman desa.\n\nDi game ini Eyang Palang bertarung dengan tiga jenis jurus: Serang (merah), Fokus (biru), dan Taktik (hijau).",
     "A dignified village elder who always carries a staff. In the origin story of Dongkrek, he is known as Raden Ngabehi Lo Prawirodipuro of Mejayan. Through meditation he received guidance to create a dance that would lead the evil beings out of the village. In Dongkrek performances, he is the one who subdues the Buto and restores peace to the village.\n\nIn this game Eyang Palang fights with three kinds of techniques: Attack (red), Focus (blue), and Tactic (green)."),
    ("PUSTAKA_BUTO_KUNING_TEXT",
     "Buto paling rakus. Setiap serangannya menghisap semangat lawan: Moxie di atas 100% berkurang. Moxie di bawah 100% aman.\n\nSiasat: pakai Gebrakan Palang sebelum ia sempat menguras Overcharge-mu.",
     "The greediest Buto. Every attack sucks away its foe's spirit: Moxie above 100% is drained. Moxie below 100% is safe.\n\nTip: use Palang Strike before it can drain your Overcharge."),
    ("PUSTAKA_BUTO_HIJAU_TEXT",
     "Napasnya membawa penyakit. Semburannya meninggalkan Racun yang menggerogoti HP di akhir giliran Buto, menembus Tameng. Racun berkurang satu setiap kali bekerja.\n\nSiasat: kalahkan ia lebih dulu supaya racunnya berhenti bertambah.",
     "Its breath carries disease. Its spit leaves Poison that eats away HP at the end of the Buto's turn, ignoring Block. Poison drops by one each time it ticks.\n\nTip: take it down first so the poison stops piling up."),
    ("PUSTAKA_BUTO_MERAH_TEXT",
     "Tenaganya paling besar. Polanya selalu sama: serang biasa, ancang-ancang, lalu pukulan berat.\n\nSiasat: saat ia ancang-ancang, siapkan Tameng dari kartu Taktik.",
     "The strongest of them all. Its pattern never changes: a normal attack, a wind-up, then a heavy blow.\n\nTip: when it winds up, raise your Block with Tactic cards."),
    ("PUSTAKA_BUTO_PUTIH_TEXT",
     "Penjaga gapura candi. Ilmu Sirep-nya membuat kartu terkuat di tanganmu tak berdaya selama satu giliran: tidak bisa dimainkan, digeser, atau digabung.\n\nSiasat: mainkan kartu berbintang tinggi sebelum gilirannya tiba.",
     "Guardian of the temple gate. Its Sirep spell leaves the strongest card in your hand powerless for one turn: it can't be played, moved, or merged.\n\nTip: play your high-rank cards before its turn comes."),
    ("PUSTAKA_BUTO_HITAM_TEXT",
     "Raja para Buto dan biang pagebluk. Saat HP-nya tinggal separuh ia murka: serangannya makin kuat dan ia mengacak urutan kartu di tanganmu.\n\nSiasat: simpan Moxie penuh untuk fase kedua.",
     "King of the Buto and root of the plague. At half HP it becomes enraged: its attacks grow stronger and it shuffles the cards in your hand.\n\nTip: save a full Moxie gauge for the second phase."),
    ("PUSTAKA_HOWTO", "Cara Bermain", "How to Play"),
    ("PUSTAKA_HOWTO_TEXT",
     "AP: kamu punya 4 AP setiap turn. Main kartu 1 AP, geser kartu 1 AP.\n\nKartu: Serang memberi damage, Fokus mengisi Moxie, Taktik memberi Tameng. Bintang menunjukkan kekuatan kartu.\n\nHybrid Merging: dua kartu beda warna dengan bintang sama yang bersebelahan bisa digabung. Serang+Fokus = Crimson Focus, Serang+Taktik = Piercing Strike, Fokus+Taktik = Flow State. Seret kartu untuk menggesernya, atau klik tombol gabung di antara dua kartu.\n\nMoxie & Ultimate: pada 100% Gebrakan Palang siap dan menghantam semua Buto. Simpan sampai 200% untuk damage dua kali lipat.\n\nEvolutionary Chain: mainkan 3 kartu bintang 3 berturut-turut dalam satu turn untuk memperkuat Ultimate selama battle.\n\nNiat Buto: ikon di atas kepala Buto menunjukkan apa yang akan ia lakukan di giliran berikutnya.",
     "AP: you have 4 AP each turn. Playing a card costs 1 AP, moving a card costs 1 AP.\n\nCards: Attack deals damage, Focus charges Moxie, Tactic gives Block. Stars show a card's strength.\n\nHybrid Merging: two adjacent cards of different colors with the same rank can be merged. Attack+Focus = Crimson Focus, Attack+Tactic = Piercing Strike, Focus+Tactic = Flow State. Drag a card to move it, or click the merge button between two cards.\n\nMoxie & Ultimate: at 100% Palang Strike is ready and hits every Buto. Save it up to 200% for double damage.\n\nEvolutionary Chain: play 3 rank-3 cards in a row in one turn to power up your Ultimate for the rest of the battle.\n\nButo intent: the icon above each Buto shows what it will do on its next turn."),
    ("PUSTAKA_CARDS", "Kartu", "Cards"),
    ("PUSTAKA_STATS", "HP %d  |  Serangan %d", "HP %d  |  Attack %d"),
    ("PUSTAKA_RECIPES", "Resep Hybrid", "Hybrid Recipes"),
    ("PUSTAKA_CARDS_HINT", "Arahkan kursor ke kartu untuk melihat detailnya.", "Hover over a card to see its details."),
    ("PUSTAKA_SKILL", "Ilmu: %s", "Skill: %s"),
    ("SKILL_KUNING", "Hisap Moxie", "Drain Moxie"),
    ("SKILL_HIJAU", "Sembur Racun", "Poison Spit"),
    ("SKILL_MERAH", "Pukulan Berat", "Heavy Blow"),
    ("SKILL_PUTIH", "Kunci Kartu", "Lock Card"),
    ("SKILL_HITAM", "Acak Tangan", "Shuffle Hand"),
    ("MAP_BOSS", "Pertarungan Bos", "Boss Fight"),
    ("MAP_MENU", "Menu", "Menu"),
    ("MAP_REPLAY", "Bisa diulang untuk berkah tambahan.", "Replay it for another blessing."),
    ("MAP_LOCKED_HINT", "Kalahkan stage sebelumnya dulu.", "Clear the previous stage first."),
    ("DECK_TITLE", "Deck Eyang Palang", "Eyang Palang's Deck"),
    ("DECK_HINT", "15 kartu. Berkah Roro Ayu menaikkan bintang kartu.", "15 cards. Roro Ayu's blessings raise card ranks."),
    ("ENDING_THANKS", "Tamat", "The End"),
]


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, "localization", "strings.csv")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    keys = set()
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
        writer.writerow(["keys", "id", "en"])
        for key, text_id, text_en in STRINGS:
            if key in keys:
                raise SystemExit(f"Kunci ganda: {key}")
            keys.add(key)
            writer.writerow([key, text_id, text_en])
    print(f"{len(STRINGS)} teks ditulis ke {path}")


if __name__ == "__main__":
    main()
