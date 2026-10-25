extends Node
## Data yang bertahan sepanjang game: progres 10 babak, isi deck pemain,
## dan pengaturan. Disimpan ke user://save.cfg.
##
## Deck disimpan sebagai daftar "tipe:rank", misalnya "serang:2". CardDB yang
## mengubahnya menjadi CardData saat battle dimulai.

signal settings_changed
signal progress_changed

const SAVE_PATH := "user://save.cfg"
## Versi format simpanan. Versi 1 dari masa 5 babak, versi 2 untuk 10 babak,
## versi 3 mencatat berkah yang dimiliki dan babak yang sudah memberi berkah.
const SAVE_VERSION := 3
const STAGE_COUNT := 10
## Babak lama (versi 1) yang isinya masih sama di versi 10 babak.
const V1_KEPT_STAGES := 4
const BASE_MAX_HP := 70
const STARTER_DECK: Array[String] = [
	"serang:1", "serang:1", "serang:2", "serang:2", "serang:3",
	"fokus:1", "fokus:1", "fokus:2", "fokus:2", "fokus:3",
	"taktik:1", "taktik:1", "taktik:2", "taktik:2", "taktik:3",
]

## Tes otomatis mengganti ini supaya simpanan pemain tidak tertimpa.
var save_path: String = SAVE_PATH

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
## Berkah yang dimiliki, sebagai nama Blessings.Kind. Jamu Kunyit Asam bisa
## muncul lebih dari sekali.
var blessings: Array[String] = []
## Babak yang berkah kemenangan pertamanya sudah diterima.
var blessed_stages: Array[int] = []
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
	blessings.clear()
	blessed_stages.clear()
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

## Berkah hanya diberikan sekali untuk setiap babak, saat pertama kali menang.
func is_stage_blessed(stage: int) -> bool:
	return blessed_stages.has(stage)


## Tiga pilihan berkah acak (lihat aturan di Blessings).
func roll_blessings(rng: RandomNumberGenerator) -> Array[Blessings.Kind]:
	return Blessings.roll(rng, deck, blessings)


## Menerapkan berkah dan mencatat babak asalnya. Mengembalikan daftar kartu
## yang naik bintang (untuk UI).
func apply_blessing(kind: Blessings.Kind, for_stage: int = 0) -> Array[String]:
	var upgraded: Array[String] = []
	if Blessings.UPGRADE_FAMILY.has(kind):
		upgraded = Blessings.upgrade_family(deck, Blessings.UPGRADE_FAMILY[kind])
	elif kind == Blessings.Kind.JAMU_KUNYIT_ASAM:
		max_hp += Blessings.JAMU_HP
	blessings.append(Blessings.kind_name(kind))
	if for_stage > 0 and not blessed_stages.has(for_stage):
		blessed_stages.append(for_stage)
	save_game()
	return upgraded


## Efek berkah untuk battle yang akan dimulai.
func prepare_player(player: PlayerState) -> void:
	Blessings.prepare_player(player, blessings)

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
	cfg.set_value("meta", "save_version", SAVE_VERSION)
	cfg.set_value("progress", "unlocked_stage", unlocked_stage)
	cfg.set_value("progress", "cleared_stages", cleared_stages)
	cfg.set_value("progress", "max_hp", max_hp)
	cfg.set_value("progress", "deck", deck)
	cfg.set_value("progress", "game_completed", game_completed)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "prologue_seen", prologue_seen)
	cfg.set_value("progress", "seen_buto", seen_buto)
	cfg.set_value("progress", "blessings", blessings)
	cfg.set_value("progress", "blessed_stages", blessed_stages)
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
	blessings.clear()
	for entry: Variant in cfg.get_value("progress", "blessings", []):
		if entry is String and Blessings.from_name(entry) >= 0:
			blessings.append(entry)
	blessed_stages.assign(cfg.get_value("progress", "blessed_stages", []))
	locale = str(cfg.get_value("settings", "locale", "id"))
	music_volume = float(cfg.get_value("settings", "music_volume", 0.8))
	sfx_volume = float(cfg.get_value("settings", "sfx_volume", 0.9))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))
	var version := int(cfg.get_value("meta", "save_version", 1))
	if version < 2:
		_migrate_from_v1()
	if version < 3:
		_migrate_from_v2()
	if version < SAVE_VERSION:
		save_game()


# Simpanan dari masa 5 babak. Babak 1-4 isinya sama, jadi tetap dianggap
# selesai. Babak 5 dulu melawan Buto Hitam, sekarang Buto Kuning Murka, jadi
# babak 5 ke atas dibuka ulang dan tamat harus diraih lagi.
func _migrate_from_v1() -> void:
	var kept: Array[int] = []
	for stage: int in cleared_stages:
		if stage >= 1 and stage <= V1_KEPT_STAGES and not kept.has(stage):
			kept.append(stage)
	cleared_stages = kept
	unlocked_stage = mini(unlocked_stage, V1_KEPT_STAGES + 1)
	game_completed = false


# Sebelum versi 3 berkah diberikan setiap menang tanpa dicatat. Babak yang
# sudah selesai dianggap sudah memberi berkah, dan Jamu yang sudah diminum
# dihitung dari Nyawa maksimal supaya batas 3 kali tetap berlaku.
func _migrate_from_v2() -> void:
	blessed_stages = cleared_stages.duplicate()
	blessings.clear()
	@warning_ignore("integer_division")
	var jamu := clampi((max_hp - BASE_MAX_HP) / Blessings.JAMU_HP, 0, Blessings.JAMU_LIMIT)
	for i: int in jamu:
		blessings.append(Blessings.kind_name(Blessings.Kind.JAMU_KUNYIT_ASAM))


func _is_valid_deck(saved: Array) -> bool:
	if saved.size() != STARTER_DECK.size():
		return false
	for entry: Variant in saved:
		if not (entry is String) or (entry as String).split(":").size() != 2:
			return false
	return true

#endregion
