extends Node
## Data yang bertahan sepanjang game: progres 5 stage, isi deck pemain,
## dan pengaturan. Disimpan ke user://save.cfg.
##
## Deck disimpan sebagai daftar "tipe:rank", misalnya "serang:2". CardDB yang
## mengubahnya menjadi CardData saat battle dimulai.

signal settings_changed
signal progress_changed

const SAVE_PATH := "user://save.cfg"
const STAGE_COUNT := 5
const BASE_MAX_HP := 70
const MAX_RANK := 3
const STARTER_DECK: Array[String] = [
	"serang:1", "serang:1", "serang:2", "serang:2", "serang:3",
	"fokus:1", "fokus:1", "fokus:2", "fokus:2", "fokus:3",
	"taktik:1", "taktik:1", "taktik:2", "taktik:2", "taktik:3",
]

## Tes otomatis mengganti ini supaya simpanan pemain tidak tertimpa.
var save_path: String = SAVE_PATH

## Jenis berkah (hadiah setelah menang) yang bisa dipilih pemain.
enum Blessing { TEMPA_SERANG, ILMU_FOKUS, SIASAT_TAKTIK, JAMU }

#region Progres
## Stage tertinggi yang sudah terbuka (1..STAGE_COUNT).
var unlocked_stage: int = 1
var cleared_stages: Array[int] = []
## Stage yang sedang dipilih pemain di peta.
var current_stage: int = 1
var max_hp: int = BASE_MAX_HP
var deck: Array[String] = []
var game_completed: bool = false
var tutorial_done: bool = false
var prologue_seen: bool = false
## Buto yang sudah pernah dilawan, untuk membuka entri Pustaka.
var seen_buto: Array[String] = []
#endregion

#region Pengaturan
var locale: String = "id"
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var fullscreen: bool = false
#endregion


func _ready() -> void:
	deck = STARTER_DECK.duplicate()
	load_game()
	apply_settings()


#region Progres

func has_progress() -> bool:
	return not cleared_stages.is_empty() or unlocked_stage > 1


## Ada petualangan yang bisa dilanjutkan dari menu utama.
func has_save() -> bool:
	return prologue_seen or has_progress()


## Mulai petualangan baru. Pengaturan tidak ikut direset.
func new_game() -> void:
	unlocked_stage = 1
	cleared_stages.clear()
	current_stage = 1
	max_hp = BASE_MAX_HP
	deck = STARTER_DECK.duplicate()
	game_completed = false
	tutorial_done = false
	prologue_seen = false
	seen_buto.clear()
	save_game()
	progress_changed.emit()


func is_stage_unlocked(stage: int) -> bool:
	return stage >= 1 and stage <= unlocked_stage


func is_stage_cleared(stage: int) -> bool:
	return cleared_stages.has(stage)


## Dipanggil setelah pemain menang di stage ini.
func complete_stage(stage: int) -> void:
	if not cleared_stages.has(stage):
		cleared_stages.append(stage)
	unlocked_stage = clampi(maxi(unlocked_stage, stage + 1), 1, STAGE_COUNT)
	if stage >= STAGE_COUNT:
		game_completed = true
	save_game()
	progress_changed.emit()


func mark_buto_seen(type_key: String) -> void:
	if not seen_buto.has(type_key):
		seen_buto.append(type_key)
		save_game()

#endregion


#region Berkah (hadiah kemenangan)

## Tiga pilihan berkah acak. Pilihan yang tidak lagi berguna (misalnya semua
## kartu Serang sudah bintang 3) tidak ditawarkan.
func roll_blessings(rng: RandomNumberGenerator) -> Array[Blessing]:
	var pool: Array[Blessing] = [Blessing.JAMU]
	if _count_upgradable("serang") > 0:
		pool.append(Blessing.TEMPA_SERANG)
	if _count_upgradable("fokus") > 0:
		pool.append(Blessing.ILMU_FOKUS)
	if _count_upgradable("taktik") > 0:
		pool.append(Blessing.SIASAT_TAKTIK)
	# acak urutan lalu ambil maksimal 3
	for i: int in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, 3)


## Menerapkan berkah. Mengembalikan daftar kartu yang naik rank (untuk UI).
func apply_blessing(blessing: Blessing) -> Array[String]:
	var upgraded: Array[String] = []
	match blessing:
		Blessing.TEMPA_SERANG:
			upgraded = _upgrade_type("serang", 2)
		Blessing.ILMU_FOKUS:
			upgraded = _upgrade_type("fokus", 2)
		Blessing.SIASAT_TAKTIK:
			upgraded = _upgrade_type("taktik", 2)
		Blessing.JAMU:
			max_hp += 10
	save_game()
	return upgraded


func _count_upgradable(type_key: String) -> int:
	var count := 0
	for spec: String in deck:
		var parts := spec.split(":")
		if parts[0] == type_key and int(parts[1]) < MAX_RANK:
			count += 1
	return count


# Naikkan rank kartu terendah dari tipe ini, sebanyak `amount` kartu.
func _upgrade_type(type_key: String, amount: int) -> Array[String]:
	var upgraded: Array[String] = []
	for step: int in amount:
		var best := -1
		var best_rank := MAX_RANK
		for i: int in deck.size():
			var parts := deck[i].split(":")
			if parts[0] == type_key and int(parts[1]) < best_rank:
				best = i
				best_rank = int(parts[1])
		if best < 0:
			break
		deck[best] = "%s:%d" % [type_key, best_rank + 1]
		upgraded.append(deck[best])
	return upgraded

#endregion


#region Pengaturan

func set_locale(new_locale: String) -> void:
	locale = new_locale
	apply_settings()
	save_game()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply_settings()
	save_game()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_settings()
	save_game()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_settings()
	save_game()


func apply_settings() -> void:
	TranslationServer.set_locale(locale)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	settings_changed.emit()


func _set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))

#endregion


#region Simpan & muat

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_stage", unlocked_stage)
	cfg.set_value("progress", "cleared_stages", cleared_stages)
	cfg.set_value("progress", "max_hp", max_hp)
	cfg.set_value("progress", "deck", deck)
	cfg.set_value("progress", "game_completed", game_completed)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "prologue_seen", prologue_seen)
	cfg.set_value("progress", "seen_buto", seen_buto)
	cfg.set_value("settings", "locale", locale)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.save(save_path)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	unlocked_stage = clampi(int(cfg.get_value("progress", "unlocked_stage", 1)), 1, STAGE_COUNT)
	cleared_stages.assign(cfg.get_value("progress", "cleared_stages", []))
	max_hp = int(cfg.get_value("progress", "max_hp", BASE_MAX_HP))
	var saved_deck: Array = cfg.get_value("progress", "deck", [])
	if _is_valid_deck(saved_deck):
		deck.assign(saved_deck)
	game_completed = bool(cfg.get_value("progress", "game_completed", false))
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	prologue_seen = bool(cfg.get_value("progress", "prologue_seen", false))
	seen_buto.assign(cfg.get_value("progress", "seen_buto", []))
	locale = str(cfg.get_value("settings", "locale", "id"))
	music_volume = float(cfg.get_value("settings", "music_volume", 0.8))
	sfx_volume = float(cfg.get_value("settings", "sfx_volume", 0.9))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))


func _is_valid_deck(saved: Array) -> bool:
	if saved.size() != STARTER_DECK.size():
		return false
	for entry: Variant in saved:
		if not (entry is String) or (entry as String).split(":").size() != 2:
			return false
	return true

#endregion
