class_name JourneyEvents
extends RefCounted
## Kejadian di perjalanan: cerita pendek dengan dua pilihan di antara babak
## (mode cerita) atau di langkah kejadian (Ruwatan).
##
## Efek pilihan ditulis sebagai teks pendek, dipisah koma:
##   hp:+5 / hp:-5            Nyawa maksimal bertambah/berkurang
##   tabuh:KELUARGA           kartu Tabuh menggantikan kartu pilihan pemain
##   upgrade_pick             satu kartu pilihan pemain naik bintang
##   upgrade_random           satu kartu acak naik bintang
##   upgrade_random_tabuh     satu kartu Tabuh acak naik bintang (atau kartu acak)
##   downgrade_random         satu kartu acak turun bintang
##   blessing:NAMA|CADANGAN   berkah sekali; kalau sudah punya, jalankan CADANGAN
##   nothing                  tidak terjadi apa-apa
##
## "profile" adalah GameState (cerita) atau RuwatanRun: keduanya punya
## get_deck(), get_blessings(), change_max_hp(), apply_blessing(),
## upgrade_card(), downgrade_card(), dan place_tabuh().

const EVENTS := [
	{"id": "warga_sakit", "icon": "res://assets/cards/icon_kentongan.png", "a": "hp:-5,tabuh:kentongan", "b": "nothing"},
	{"id": "pande", "icon": "res://assets/cards/icon_gong.png", "a": "upgrade_pick", "b": "tabuh:gong"},
	{"id": "mbok_jamu", "icon": "res://assets/ui/bless_kencur.png", "a": "hp:+5", "b": "blessing:JAMU_BERAS_KENCUR|hp:+5"},
	{"id": "latihan", "icon": "res://assets/cards/icon_korek.png", "a": "upgrade_random", "b": "tabuh:korek"},
	{"id": "sesajen", "icon": "res://assets/ui/bless_leluhur.png", "a": "upgrade_random", "b": "blessing:GREGET_LELUHUR|hp:+5"},
	{"id": "peronda", "icon": "res://assets/cards/icon_bedug.png", "a": "tabuh:bedug", "b": "hp:+8,downgrade_random"},
	{"id": "buto_kecil", "icon": "res://assets/ui/portrait_buto_kuning.png", "a": "upgrade_random_tabuh", "b": "hp:+8"},
	{"id": "pengamen", "icon": "res://assets/cards/icon_kenong.png", "a": "hp:-5,tabuh:kenong", "b": "hp:+3"},
]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in EVENTS:
		out.append(e["id"])
	return out


static func exists(id: String) -> bool:
	return ids().has(id)


static func get_event(id: String) -> Dictionary:
	for e: Dictionary in EVENTS:
		if e["id"] == id:
			return e
	return {}


## Kejadian acak yang belum ada di `seen`. "" kalau semua sudah dialami.
static func pick(rng: RandomNumberGenerator, seen: Array) -> String:
	var pool: Array[String] = []
	for id: String in ids():
		if not seen.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


## Efek pilihan "a" atau "b".
static func effects_of(id: String, choice: String) -> PackedStringArray:
	var e := get_event(id)
	if e.is_empty():
		return PackedStringArray()
	return str(e[choice]).split(",", false)


## true kalau efek ini butuh pemain memilih kartu (pemilih kartu).
static func needs_picker(effect: String) -> bool:
	return effect.begins_with("tabuh:") or effect == "upgrade_pick"


## Menjalankan efek yang tidak butuh pilihan pemain. Mengembalikan kalimat
## hasilnya ("" kalau tidak ada yang berubah).
static func apply(effect: String, profile: Object, rng: RandomNumberGenerator) -> String:
	var key := effect.get_slice(":", 0)
	var arg := effect.substr(key.length() + 1) if effect.contains(":") else ""
	match key:
		"hp":
			var before: int = profile.call("get_max_hp")
			var after: int = profile.call("change_max_hp", int(arg))
			return _t("EV_RESULT_HP") % [before, after]
		"upgrade_random":
			return _upgrade_random(profile, rng, false)
		"upgrade_random_tabuh":
			return _upgrade_random(profile, rng, true)
		"downgrade_random":
			var deck: Array[String] = profile.call("get_deck")
			var options: Array[int] = []
			for i: int in deck.size():
				if int(deck[i].get_slice(":", 1)) > 1:
					options.append(i)
			if options.is_empty():
				return ""
			var at: int = options[rng.randi_range(0, options.size() - 1)]
			var old := deck[at]
			var result: String = profile.call("downgrade_card", at)
			return _t("EV_RESULT_DOWNGRADE") % [card_label(old), card_label(result)]
		"blessing":
			var name := arg.get_slice("|", 0)
			var fallback := arg.substr(name.length() + 1) if arg.contains("|") else ""
			var kind := Blessings.from_name(name)
			var owned: Array[String] = profile.call("get_blessings")
			if kind < 0 or owned.has(name):
				return apply(fallback, profile, rng) if fallback != "" else ""
			profile.call("apply_blessing", kind, 0)
			return _t("EV_RESULT_BLESSING") % _t(Blessings.text_key(kind))
	return ""


static func _upgrade_random(profile: Object, rng: RandomNumberGenerator, tabuh_only: bool) -> String:
	var deck: Array[String] = profile.call("get_deck")
	var options: Array[int] = []
	for i: int in deck.size():
		if int(deck[i].get_slice(":", 1)) < Blessings.MAX_RANK and (not tabuh_only or Blessings.is_tabuh_spec(deck[i])):
			options.append(i)
	if options.is_empty():
		return _upgrade_random(profile, rng, false) if tabuh_only else ""
	var at: int = options[rng.randi_range(0, options.size() - 1)]
	var old := deck[at]
	var result: String = profile.call("upgrade_card", at)
	return _t("EV_RESULT_UPGRADE") % [card_label(old), card_label(result)]


## "Sabet (Bintang 2)" dari "serang:2", tanpa perlu CardDB.
static func card_label(spec: String) -> String:
	var family := spec.get_slice(":", 0)
	return "%s (%s)" % [_t("CARD_" + family.to_upper()), _t("CARD_RANK") % int(spec.get_slice(":", 1))]


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
