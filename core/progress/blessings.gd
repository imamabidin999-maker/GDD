class_name Blessings
extends RefCounted
## Berkah Roro Ayu: daftar berkah, aturan undiannya, dan efeknya di battle.
##
## Berkah diberikan sekali untuk setiap kemenangan pertama di sebuah babak.
## Pemain memilih satu dari tiga pilihan acak. Berkah "sekali" hilang dari
## undian setelah dimiliki, berkah naik bintang hilang kalau kartu tipenya
## sudah bintang 3 semua, dan Jamu Kunyit Asam paling banyak diambil 3 kali.
##
## Semua fungsi di sini statis dan tidak menyentuh GameState, jadi bisa dipakai
## tes dan simulasi keseimbangan. Berkah yang dimiliki disimpan sebagai nama
## enum (misalnya "KENDANG_PEMBUKA") supaya simpanan tidak bergantung urutan enum.

enum Kind {
	TEMPA_SABET, ## 2 kartu Sabet naik satu bintang
	OLAH_SEMEDI, ## 2 kartu Semedi naik satu bintang
	LAKU_TANGKIS, ## 2 kartu Tangkis naik satu bintang
	JAMU_KUNYIT_ASAM, ## Nyawa maksimal +10, paling banyak 3 kali
	KENDANG_PEMBUKA, ## +1 Ketukan di giliran pertama
	GREGET_LELUHUR, ## battle dimulai dengan Greget 30%
	TAMENG_PUSAKA, ## Tameng 10 di giliran pertama
	JIMAT_PENOLAK_SIREP, ## Sirep pertama di tiap battle ditangkal
	JAMU_BERAS_KENCUR, ## Lara yang diterima berkurang 1
	TABUH_BEDUG, ## kartu Tabuh Bedug menggantikan satu kartu
	TABUH_KENTONGAN, ## kartu Kentongan Titir menggantikan satu kartu
	TABUH_KOREK, ## kartu Korek menggantikan satu kartu
	TABUH_GONG, ## kartu Gong menggantikan satu kartu
	TABUH_KENONG, ## kartu Kenong menggantikan satu kartu (perlu 8 Bintang Dongkrek)
	LARAS_GAMELAN, ## 2 kartu Tabuh naik satu bintang
}

const MAX_RANK := 3
const UPGRADE_COUNT := 2
const JAMU_LIMIT := 3
const JAMU_HP := 10
const KENDANG_AP := 1
const LELUHUR_MOXIE := 30.0
const PUSAKA_BLOCK := 10
const JIMAT_WARDS := 1
const KENCUR_REDUCTION := 1

## Berkah yang hanya bisa dimiliki sekali.
const ONCE: Array[Kind] = [
	Kind.KENDANG_PEMBUKA, Kind.GREGET_LELUHUR, Kind.TAMENG_PUSAKA,
	Kind.JIMAT_PENOLAK_SIREP, Kind.JAMU_BERAS_KENCUR,
	Kind.TABUH_BEDUG, Kind.TABUH_KENTONGAN, Kind.TABUH_KOREK, Kind.TABUH_GONG, Kind.TABUH_KENONG,
]
## Berkah kartu Tabuh dan keluarga kartunya. Kartu baru masuk dengan bintang 1
## dan menggantikan satu kartu pilihan pemain (deck tetap 15 kartu).
const TABUH_FAMILY := {
	Kind.TABUH_BEDUG: "bedug",
	Kind.TABUH_KENTONGAN: "kentongan",
	Kind.TABUH_KOREK: "korek",
	Kind.TABUH_GONG: "gong",
	Kind.TABUH_KENONG: "kenong",
}
const TABUH_FAMILIES: Array[String] = ["bedug", "kentongan", "korek", "gong", "kenong"]
## Kartu Tabuh yang baru didapat mendapat bintang kartu yang digantinya
## ditambah ini (paling tinggi bintang 3), seperti jurus lama yang ditempa ulang.
const TABUH_RANK_BONUS := 1
## Berkah naik bintang dan tipe kartunya.
const UPGRADE_FAMILY := {
	Kind.TEMPA_SABET: "serang",
	Kind.OLAH_SEMEDI: "fokus",
	Kind.LAKU_TANGKIS: "taktik",
}
## Kunci teks nama berkah; keterangannya memakai kunci + "_DESC".
const TEXT_KEYS := {
	Kind.TEMPA_SABET: "BLESS_TEMPA",
	Kind.OLAH_SEMEDI: "BLESS_FOKUS",
	Kind.LAKU_TANGKIS: "BLESS_TAKTIK",
	Kind.JAMU_KUNYIT_ASAM: "BLESS_JAMU",
	Kind.KENDANG_PEMBUKA: "BLESS_KENDANG",
	Kind.GREGET_LELUHUR: "BLESS_LELUHUR",
	Kind.TAMENG_PUSAKA: "BLESS_PUSAKA",
	Kind.JIMAT_PENOLAK_SIREP: "BLESS_JIMAT",
	Kind.JAMU_BERAS_KENCUR: "BLESS_KENCUR",
	Kind.TABUH_BEDUG: "BLESS_TABUH_BEDUG",
	Kind.TABUH_KENTONGAN: "BLESS_TABUH_KENTONGAN",
	Kind.TABUH_KOREK: "BLESS_TABUH_KOREK",
	Kind.TABUH_GONG: "BLESS_TABUH_GONG",
	Kind.TABUH_KENONG: "BLESS_TABUH_KENONG",
	Kind.LARAS_GAMELAN: "BLESS_LARAS",
}


static func kind_name(kind: Kind) -> String:
	return Kind.keys()[kind]


## -1 kalau nama tidak dikenal (misalnya simpanan dari versi yang lebih baru).
static func from_name(name: String) -> int:
	return Kind.keys().find(name)


static func text_key(kind: Kind) -> String:
	return TEXT_KEYS[kind]


static func has(owned: Array[String], kind: Kind) -> bool:
	return owned.has(kind_name(kind))


static func count(owned: Array[String], kind: Kind) -> int:
	return owned.count(kind_name(kind))


## Berkah yang masih boleh ditawarkan, urut sesuai enum. `excluded` berisi
## berkah yang belum terbuka (misalnya Kenong sebelum 8 Bintang Dongkrek).
static func available(deck: Array[String], owned: Array[String], excluded: Array = []) -> Array[Kind]:
	var pool: Array[Kind] = []
	for kind: Kind in UPGRADE_FAMILY:
		if count_upgradable(deck, UPGRADE_FAMILY[kind]) > 0:
			pool.append(kind)
	if count(owned, Kind.JAMU_KUNYIT_ASAM) < JAMU_LIMIT:
		pool.append(Kind.JAMU_KUNYIT_ASAM)
	for kind: Kind in ONCE:
		if not has(owned, kind) and not excluded.has(kind):
			pool.append(kind)
	if count_upgradable_tabuh(deck) > 0:
		pool.append(Kind.LARAS_GAMELAN)
	return pool


## Pilihan acak yang berbeda-beda, paling banyak `amount`.
static func roll(rng: RandomNumberGenerator, deck: Array[String], owned: Array[String], amount: int = 3,
		excluded: Array = []) -> Array[Kind]:
	var pool := available(deck, owned, excluded)
	for i: int in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, amount)


static func count_upgradable(deck: Array[String], family: String) -> int:
	var total := 0
	for spec: String in deck:
		var parts := spec.split(":")
		if parts[0] == family and int(parts[1]) < MAX_RANK:
			total += 1
	return total


## Spec kartu Tabuh `family` yang menggantikan kartu `replaced`.
static func tabuh_spec_for(family: String, replaced: String) -> String:
	var rank := clampi(int(replaced.get_slice(":", 1)) + TABUH_RANK_BONUS, 1, MAX_RANK)
	return "%s:%d" % [family, rank]


static func is_tabuh_spec(spec: String) -> bool:
	return TABUH_FAMILIES.has(spec.get_slice(":", 0))


static func count_upgradable_tabuh(deck: Array[String]) -> int:
	var total := 0
	for spec: String in deck:
		if is_tabuh_spec(spec) and int(spec.get_slice(":", 1)) < MAX_RANK:
			total += 1
	return total


## Laras Gamelan: menaikkan bintang kartu Tabuh terendah sebanyak `amount`.
static func upgrade_tabuh(deck: Array[String], amount: int = UPGRADE_COUNT) -> Array[String]:
	var upgraded: Array[String] = []
	for step: int in amount:
		var best := -1
		var best_rank := MAX_RANK
		for i: int in deck.size():
			if not is_tabuh_spec(deck[i]):
				continue
			var rank := int(deck[i].get_slice(":", 1))
			if rank < best_rank:
				best = i
				best_rank = rank
		if best < 0:
			break
		deck[best] = "%s:%d" % [deck[best].get_slice(":", 0), best_rank + 1]
		upgraded.append(deck[best])
	return upgraded


## Efek berkah pada deck: berkah naik bintang dan Laras Gamelan. Mengubah
## `deck` langsung dan mengembalikan kartu yang naik. Berkah lain tidak
## menyentuh deck (Jamu Kunyit Asam diurus pemilik Nyawa, kartu Tabuh dipasang
## setelah pemain memilih kartu yang diganti).
static func apply_to_deck(kind: Kind, deck: Array[String]) -> Array[String]:
	if UPGRADE_FAMILY.has(kind):
		return upgrade_family(deck, UPGRADE_FAMILY[kind])
	if kind == Kind.LARAS_GAMELAN:
		return upgrade_tabuh(deck)
	return []


## Menurunkan satu kartu tertentu (paling rendah bintang 1). Mengembalikan
## spec barunya, atau "" kalau index salah.
static func downgrade_at(deck: Array[String], index: int) -> String:
	if index < 0 or index >= deck.size():
		return ""
	var rank := int(deck[index].get_slice(":", 1))
	if rank > 1:
		deck[index] = "%s:%d" % [deck[index].get_slice(":", 0), rank - 1]
	return deck[index]


## Menaikkan satu kartu tertentu (pilihan pemain). Mengembalikan spec barunya,
## atau "" kalau sudah bintang 3.
static func upgrade_at(deck: Array[String], index: int) -> String:
	if index < 0 or index >= deck.size():
		return ""
	var rank := int(deck[index].get_slice(":", 1))
	if rank >= MAX_RANK:
		return ""
	deck[index] = "%s:%d" % [deck[index].get_slice(":", 0), rank + 1]
	return deck[index]


## Menaikkan bintang kartu terendah dari satu tipe sebanyak `amount` kartu.
## Mengubah `deck` langsung dan mengembalikan kartu yang naik (untuk UI).
static func upgrade_family(deck: Array[String], family: String, amount: int = UPGRADE_COUNT) -> Array[String]:
	var upgraded: Array[String] = []
	for step: int in amount:
		var best := -1
		var best_rank := MAX_RANK
		for i: int in deck.size():
			var parts := deck[i].split(":")
			if parts[0] == family and int(parts[1]) < best_rank:
				best = i
				best_rank = int(parts[1])
		if best < 0:
			break
		deck[best] = "%s:%d" % [family, best_rank + 1]
		upgraded.append(deck[best])
	return upgraded


## Memasang efek berkah battle ke PlayerState. Dipanggil sebelum
## BattleManager.start_battle(); nilainya dipakai begin_battle() dan giliran
## pertama.
static func prepare_player(player: PlayerState, owned: Array[String]) -> void:
	player.start_moxie = LELUHUR_MOXIE if has(owned, Kind.GREGET_LELUHUR) else 0.0
	player.first_turn_bonus_ap = KENDANG_AP if has(owned, Kind.KENDANG_PEMBUKA) else 0
	player.first_turn_block = PUSAKA_BLOCK if has(owned, Kind.TAMENG_PUSAKA) else 0
	player.sirep_wards_per_battle = JIMAT_WARDS if has(owned, Kind.JIMAT_PENOLAK_SIREP) else 0
	player.poison_reduction = KENCUR_REDUCTION if has(owned, Kind.JAMU_BERAS_KENCUR) else 0
