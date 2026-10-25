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
]
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


## Berkah yang masih boleh ditawarkan, urut sesuai enum.
static func available(deck: Array[String], owned: Array[String]) -> Array[Kind]:
	var pool: Array[Kind] = []
	for kind: Kind in UPGRADE_FAMILY:
		if count_upgradable(deck, UPGRADE_FAMILY[kind]) > 0:
			pool.append(kind)
	if count(owned, Kind.JAMU_KUNYIT_ASAM) < JAMU_LIMIT:
		pool.append(Kind.JAMU_KUNYIT_ASAM)
	for kind: Kind in ONCE:
		if not has(owned, kind):
			pool.append(kind)
	return pool


## Pilihan acak yang berbeda-beda, paling banyak `amount`.
static func roll(rng: RandomNumberGenerator, deck: Array[String], owned: Array[String], amount: int = 3) -> Array[Kind]:
	var pool := available(deck, owned)
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
