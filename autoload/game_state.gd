extends Node
## Data yang bertahan sepanjang game: progres 10 babak, isi deck pemain,
## Ruwatan, dan pengaturan. Disimpan ke user://save.cfg.
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
## Kejadian di perjalanan yang menunggu di peta ("" kalau tidak ada).
var pending_event: String = ""
## Dua kejadian di persimpangan jalan; pemain memilih satu (lihat choose_path).
var pending_paths: Array[String] = []
## Kejadian yang sudah dialami di petualangan ini (tidak diulang).
var seen_events: Array[String] = []
## Catatan permainan sepanjang masa (halaman Catatan di Pustaka). Tidak ikut
## direset saat petualangan baru.
var records := PlayRecords.new()
## Bintang Dongkrek petualangan ini: babak -> bitmask 3 bintang (lihat
## Challenges). Mulai dari nol lagi saat petualangan baru.
var stage_stars: Dictionary = {}
## Rekor bintang sepanjang masa, gabungan bintang dari semua petualangan.
## Hadiah bintang dihitung dari rekor ini, jadi hadiah yang sudah terbuka tetap
## terbuka walau petualangan baru dimulai.
var star_record: Dictionary = {}
#endregion

## Battle berikutnya milik mode cerita atau Ruwatan. Tidak disimpan.
enum PlayMode { STORY, RUWATAN }
var play_mode: int = PlayMode.STORY

#region Ruwatan
## Terbuka setelah tamat sekali. Tidak ikut direset saat petualangan baru.
var ruwatan_unlocked: bool = false
## Hasil terbaik per Tingkat Pagebluk: tingkat -> langkah yang dilewati (8 = berhasil).
var ruwatan_best: Dictionary = {}
## Ruwatan yang sedang berjalan (null kalau tidak ada).
var ruwatan: RuwatanRun = null
#endregion

## Tingkat kesulitan mode cerita. Mengubah Nyawa dan serangan Buto.
enum Difficulty { SANTAI, NORMAL, SULIT }
const DIFFICULTY_HP := [0.8, 1.0, 1.15]
const DIFFICULTY_ATTACK := [0.85, 1.0, 1.15]

#region Pengaturan
var locale: String = "id"
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var fullscreen: bool = false
## Kecepatan animasi battle: 1.0 atau 2.0.
var battle_speed: float = 1.0
## Petunjuk singkat saat mekanik baru pertama kali muncul.
var hints_enabled: bool = true
## Petunjuk yang sudah pernah tampil. Tidak ikut direset saat petualangan baru.
var seen_hints: Array[String] = []
## Tingkat kesulitan mode cerita (lihat Difficulty).
var difficulty: int = Difficulty.NORMAL
## Permainan irama saat Sapu Jagad dipakai.
var rhythm_enabled: bool = true
## Istilah Jawa di teks cerita diberi warna dan bisa disorot (GlossaryText).
var glossary_marks: bool = true
## Keterangan, petunjuk, dan catatan kecil memakai huruf 16 piksel (UIKit.large_text).
var large_text: bool = false
## Tombol keyboard pilihan pemain: {aksi: [kode, kode]} (lihat KeyBindings).
## Aksi yang tidak ada di sini memakai tombol bawaan.
var key_bindings: Dictionary = {}
## Tombol gamepad pilihan pemain: {aksi: tombol} (lihat PadBindings).
var pad_bindings: Dictionary = {}
## Pengali kecepatan kursor gamepad (lihat GamepadCursor), 0,5 sampai 2.
var pad_cursor_speed: float = 1.0
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
	pending_event = ""
	pending_paths.clear()
	seen_events.clear()
	stage_stars.clear()
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
		if not game_completed:
			records.stories_completed += 1
		game_completed = true
		ruwatan_unlocked = true
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
	return Blessings.roll(rng, deck, blessings, 3, locked_blessings())


## Berkah yang belum terbuka.
func locked_blessings() -> Array:
	return [] if kenong_unlocked() else [Blessings.Kind.TABUH_KENONG]


## Kenong masuk undian berkah setelah rekor bintang cukup.
func kenong_unlocked() -> bool:
	return best_total_stars() >= Challenges.KENONG_STARS


func reroll_unlocked() -> bool:
	return best_total_stars() >= Challenges.REROLL_STARS


func ruwatan_blessing_unlocked() -> bool:
	return best_total_stars() >= Challenges.RUWATAN_BLESSING_STARS


func master_unlocked() -> bool:
	return best_total_stars() >= Challenges.MASTER_STARS


## Bintang babak ini di petualangan yang sedang berjalan (bitmask).
func stars_of(stage: int) -> int:
	return int(stage_stars.get(stage, 0))


## Jumlah bintang di petualangan yang sedang berjalan.
func total_stars() -> int:
	return _count_stars(stage_stars)


## Jumlah rekor bintang sepanjang masa (dasar hadiah bintang).
func best_total_stars() -> int:
	return _count_stars(star_record)


static func _count_stars(masks: Dictionary) -> int:
	var total := 0
	for stage: Variant in masks:
		total += Challenges.count_bits(int(masks[stage]))
	return total


## Mencatat hasil tantangan di petualangan ini dan di rekor. Mengembalikan
## bintang yang baru didapat di petualangan ini (true di posisi bintang yang
## sebelumnya belum dimiliki).
func record_stars(stage: int, results: Array[bool]) -> Array[bool]:
	var before := stars_of(stage)
	var after := before | Challenges.mask_of(results)
	stage_stars[stage] = after
	star_record[stage] = int(star_record.get(stage, 0)) | after
	var fresh: Array[bool] = []
	for i: int in Challenges.STARS_PER_STAGE:
		fresh.append(bool(after & (1 << i)) and not bool(before & (1 << i)))
	save_game()
	return fresh


## Menerapkan berkah dan mencatat babak asalnya. Mengembalikan daftar kartu
## yang naik bintang (untuk UI).
func apply_blessing(kind: Blessings.Kind, for_stage: int = 0) -> Array[String]:
	var upgraded := Blessings.apply_to_deck(kind, deck)
	if kind == Blessings.Kind.JAMU_KUNYIT_ASAM:
		max_hp += Blessings.JAMU_HP
	# Berkah kartu Tabuh: kartunya dipasang lewat replace_card() setelah pemain
	# memilih kartu yang diganti.
	blessings.append(Blessings.kind_name(kind))
	if for_stage > 0 and not blessed_stages.has(for_stage):
		blessed_stages.append(for_stage)
	save_game()
	return upgraded


## Mengganti kartu ke-`index` di deck dengan `spec` (misalnya "bedug:1").
## Mengembalikan spec kartu yang dikeluarkan, atau "" kalau index salah.
func replace_card(index: int, spec: String) -> String:
	if index < 0 or index >= deck.size() or CardDB.card_from_spec(spec) == null:
		return ""
	var old := deck[index]
	deck[index] = spec
	save_game()
	return old


## Memasang kartu Tabuh `family` menggantikan kartu ke-`index`. Bintangnya
## mengikuti Blessings.tabuh_spec_for(). Mengembalikan [lama, baru] atau [].
func place_tabuh(index: int, family: String) -> Array[String]:
	if index < 0 or index >= deck.size():
		return []
	var spec := Blessings.tabuh_spec_for(family, deck[index])
	var old := replace_card(index, spec)
	if old == "":
		return []
	return [old, spec]


## Menaikkan satu kartu pilihan. Mengembalikan spec barunya, atau "".
func upgrade_card(index: int) -> String:
	var result := Blessings.upgrade_at(deck, index)
	if result != "":
		save_game()
	return result


## Menurunkan satu kartu (paling rendah bintang 1). Mengembalikan spec barunya.
func downgrade_card(index: int) -> String:
	var result := Blessings.downgrade_at(deck, index)
	if result != "":
		save_game()
	return result


#region Profil pemain
# Antarmuka yang sama dengan RuwatanRun, supaya panel berkah, kejadian, dan
# pemilih kartu bisa dipakai di mode cerita maupun Ruwatan.

func get_deck() -> Array[String]:
	return deck


func get_blessings() -> Array[String]:
	return blessings


func get_max_hp() -> int:
	return max_hp


## Menambah (atau mengurangi) Nyawa maksimal. Paling rendah 30.
func change_max_hp(delta: int) -> int:
	max_hp = maxi(30, max_hp + delta)
	save_game()
	return max_hp

#endregion


#region Kejadian di perjalanan

## Babak yang kemenangan pertamanya disusul kejadian di perjalanan.
const EVENT_STAGES: Array[int] = [2, 4, 6, 8]


## Dipanggil setelah berkah kemenangan pertama. Di peta, Eyang tiba di
## persimpangan jalan: dua kejadian acak yang belum pernah dialami, masing-masing
## di ujung satu jalan. Kalau hanya tersisa satu, kejadian itu langsung menunggu.
## Mengembalikan kejadian pertama ("" kalau tidak ada).
func queue_event_after(stage: int, rng: RandomNumberGenerator) -> String:
	if not EVENT_STAGES.has(stage) or pending_event != "" or not pending_paths.is_empty():
		return ""
	var first := JourneyEvents.pick(rng, seen_events)
	if first == "":
		return ""
	var second := JourneyEvents.pick(rng, seen_events + [first])
	if second == "":
		pending_event = first
		seen_events.append(first)
	else:
		pending_paths.assign([first, second])
	save_game()
	return first


## Jalan yang dipilih di persimpangan. Kejadian di jalan lain belum dialami,
## jadi bisa muncul lagi di persimpangan berikutnya.
func choose_path(id: String) -> void:
	if not pending_paths.has(id):
		return
	pending_paths.clear()
	pending_event = id
	seen_events.append(id)
	save_game()


func finish_event() -> void:
	pending_event = ""
	save_game()

#endregion


## Efek berkah untuk battle yang akan dimulai.
func prepare_player(player: PlayerState) -> void:
	Blessings.prepare_player(player, blessings)


#region Catatan permainan

## Dipanggil setelah battle selesai (cerita maupun Ruwatan).
func record_battle(stats: BattleStats) -> void:
	records.add_battle(stats)
	save_game()


func record_rhythm(score: float) -> void:
	records.add_rhythm(score)
	save_game()


## Semarak arak-arakan penutup (score < 0 kalau dilewati).
func record_parade(score: float) -> void:
	records.add_parade(score)
	save_game()

#endregion

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


func set_battle_speed(value: float) -> void:
	battle_speed = 2.0 if value >= 1.5 else 1.0
	save_game()
	settings_changed.emit()


func set_rhythm_enabled(value: bool) -> void:
	rhythm_enabled = value
	save_game()


func set_hints_enabled(value: bool) -> void:
	hints_enabled = value
	save_game()


func set_glossary_marks(value: bool) -> void:
	glossary_marks = value
	save_game()


func set_large_text(value: bool) -> void:
	large_text = value
	_apply_text_size()
	save_game()
	settings_changed.emit()


## Keterangan bawaan Godot (tooltip_text, misalnya di Pengaturan) memakai tipe
## TooltipLabel di tema, jadi ukurannya diubah langsung di tema proyek.
func _apply_text_size() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		theme.set_font_size("font_size", "TooltipLabel", 16 if large_text else 8)


## true kalau petunjuk ini perlu ditampilkan sekarang (belum pernah dan
## petunjuk aktif). Langsung dicatat sebagai sudah tampil.
func take_hint(id: String) -> bool:
	if not hints_enabled or seen_hints.has(id):
		return false
	seen_hints.append(id)
	save_game()
	return true


func set_difficulty(value: int) -> void:
	difficulty = clampi(value, Difficulty.SANTAI, Difficulty.SULIT)
	save_game()
	settings_changed.emit()


func difficulty_hp_multiplier() -> float:
	return DIFFICULTY_HP[difficulty]


func difficulty_attack_multiplier() -> float:
	return DIFFICULTY_ATTACK[difficulty]


#region Tombol keyboard

## Memasang tombol ke satu slot aksi. Mengembalikan aksi lain yang kehilangan
## tombol itu ("" kalau tidak ada, "!" kalau ditolak).
func set_key(action: String, slot: int, code: int) -> String:
	var displaced := KeyBindings.assign(key_bindings, action, slot, code)
	if displaced != "!":
		_apply_bindings()
	return displaced


func clear_key(action: String, slot: int) -> void:
	KeyBindings.clear(key_bindings, action, slot)
	_apply_bindings()


func reset_keys() -> void:
	key_bindings.clear()
	_apply_bindings()


## Memasang tombol gamepad ke aksi. Hasilnya seperti set_key: aksi yang
## kehilangan tombolnya, "" kalau tidak ada, atau "!" kalau ditolak.
func set_pad_button(action: String, button: int) -> String:
	var displaced := PadBindings.assign(pad_bindings, action, button)
	if displaced != "!":
		_apply_bindings()
	return displaced


func clear_pad_button(action: String) -> void:
	PadBindings.clear(pad_bindings, action)
	_apply_bindings()


## Tombol gamepad dan kecepatan kursor kembali seperti semula.
func reset_pad() -> void:
	pad_bindings.clear()
	pad_cursor_speed = 1.0
	_apply_bindings()


func pad_button(action: String) -> int:
	return PadBindings.button(pad_bindings, action)


func set_pad_cursor_speed(value: float) -> void:
	pad_cursor_speed = clampf(value, 0.5, 2.0)
	save_game()


func _apply_bindings() -> void:
	KeyBindings.apply(key_bindings, pad_bindings)
	save_game()
	settings_changed.emit()


func key_codes(action: String) -> Array[int]:
	return KeyBindings.codes(key_bindings, action)


## Nama tombol aksi ini, misalnya "E / Spasi".
func key_names(action: String) -> String:
	return KeyBindings.names(key_bindings, action)


## Mengganti {aksi} di teks dengan nama tombolnya.
func fill_keys(text: String) -> String:
	return KeyBindings.fill(text, key_bindings)

#endregion


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_settings()
	save_game()


func apply_settings() -> void:
	TranslationServer.set_locale(locale)
	KeyBindings.apply(key_bindings, pad_bindings)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	_apply_text_size()
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


#region Ruwatan

## Tingkat Pagebluk tertinggi yang boleh dipilih: satu di atas tingkat
## tertinggi yang pernah berhasil.
func ruwatan_max_level() -> int:
	var top := 0
	for lvl: Variant in ruwatan_best:
		if int(ruwatan_best[lvl]) >= RuwatanRun.STEPS.size():
			top = maxi(top, int(lvl))
	return clampi(top + 1, 1, RuwatanRun.MAX_LEVEL)


func ruwatan_best_of(level: int) -> int:
	return int(ruwatan_best.get(level, -1))


## Memulai Ruwatan baru (yang lama, kalau ada, ditinggalkan).
func start_ruwatan(level: int, rng: RandomNumberGenerator) -> RuwatanRun:
	if ruwatan != null:
		abandon_ruwatan()
	_attach_ruwatan(RuwatanRun.create(mini(level, ruwatan_max_level()), rng.randi(), STARTER_DECK, locked_blessings()))
	if ruwatan_blessing_unlocked():
		ruwatan.grant_start_blessing(rng)
	save_game()
	return ruwatan


## Mengakhiri Ruwatan yang sedang berjalan atau yang hasilnya sudah dilihat.
func abandon_ruwatan() -> void:
	if ruwatan == null:
		return
	_record_ruwatan(ruwatan)
	ruwatan.changed.disconnect(_on_ruwatan_changed)
	ruwatan = null
	save_game()


func _attach_ruwatan(run: RuwatanRun) -> void:
	ruwatan = run
	if run != null:
		run.changed.connect(_on_ruwatan_changed)


func _on_ruwatan_changed() -> void:
	if ruwatan.is_over():
		_record_ruwatan(ruwatan)
	save_game()


func _record_ruwatan(run: RuwatanRun) -> void:
	ruwatan_best[run.level] = maxi(ruwatan_best_of(run.level), run.steps_cleared())
	records.add_ruwatan(run.seed_value, run.level, run.steps_cleared(), run.state == RuwatanRun.State.WON,
		Time.get_date_string_from_system())

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
	cfg.set_value("progress", "pending_event", pending_event)
	cfg.set_value("progress", "pending_paths", pending_paths)
	cfg.set_value("progress", "seen_events", seen_events)
	cfg.set_value("progress", "stage_stars", _stars_out(stage_stars))
	cfg.set_value("progress", "star_record", _stars_out(star_record))
	cfg.set_value("ruwatan", "unlocked", ruwatan_unlocked)
	var best_out := {}
	for lvl: Variant in ruwatan_best:
		best_out[str(lvl)] = int(ruwatan_best[lvl])
	cfg.set_value("ruwatan", "best", best_out)
	cfg.set_value("ruwatan", "run", ruwatan.to_dict() if ruwatan != null else {})
	cfg.set_value("records", "data", records.to_dict())
	cfg.set_value("settings", "locale", locale)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "battle_speed", battle_speed)
	cfg.set_value("settings", "hints_enabled", hints_enabled)
	cfg.set_value("settings", "seen_hints", seen_hints)
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "rhythm_enabled", rhythm_enabled)
	cfg.set_value("settings", "glossary_marks", glossary_marks)
	cfg.set_value("settings", "large_text", large_text)
	cfg.set_value("settings", "keys", key_bindings)
	cfg.set_value("settings", "pad", pad_bindings)
	cfg.set_value("settings", "pad_cursor_speed", pad_cursor_speed)
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
	pending_event = str(cfg.get_value("progress", "pending_event", ""))
	if not JourneyEvents.exists(pending_event):
		pending_event = ""
	seen_events.assign(cfg.get_value("progress", "seen_events", []))
	pending_paths.clear()
	var paths_in: Variant = cfg.get_value("progress", "pending_paths", [])
	if paths_in is Array and (paths_in as Array).size() == 2 and pending_event == "":
		for id: Variant in paths_in:
			if id is String and JourneyEvents.exists(id) and not seen_events.has(id) and not pending_paths.has(id):
				pending_paths.append(id)
		if pending_paths.size() != 2:
			pending_paths.clear()
	stage_stars = _stars_in(cfg.get_value("progress", "stage_stars", {}))
	if cfg.has_section_key("progress", "star_record"):
		star_record = _stars_in(cfg.get_value("progress", "star_record", {}))
	else:
		# Simpanan lama hanya punya satu daftar bintang yang tidak pernah
		# direset. Semuanya menjadi rekor, dan petualangan yang sedang berjalan
		# hanya menyimpan bintang babak yang sudah ia selesaikan.
		star_record = stage_stars.duplicate()
		for stage: Variant in stage_stars.keys():
			if not cleared_stages.has(stage):
				stage_stars.erase(stage)
	for stage: Variant in stage_stars:
		star_record[stage] = int(star_record.get(stage, 0)) | int(stage_stars[stage])
	ruwatan_unlocked = bool(cfg.get_value("ruwatan", "unlocked", false)) or game_completed
	ruwatan_best.clear()
	var best_in: Variant = cfg.get_value("ruwatan", "best", {})
	if best_in is Dictionary:
		for key: Variant in best_in:
			var lvl := int(str(key))
			if lvl >= 1 and lvl <= RuwatanRun.MAX_LEVEL:
				ruwatan_best[lvl] = clampi(int(best_in[key]), 0, RuwatanRun.STEPS.size())
	records = PlayRecords.from_dict(cfg.get_value("records", "data", {}))
	if ruwatan != null:
		ruwatan.changed.disconnect(_on_ruwatan_changed)
		ruwatan = null
	var run_in: Variant = cfg.get_value("ruwatan", "run", {})
	if run_in is Dictionary and not (run_in as Dictionary).is_empty():
		_attach_ruwatan(RuwatanRun.from_dict(run_in, locked_blessings()))
	locale = str(cfg.get_value("settings", "locale", "id"))
	music_volume = float(cfg.get_value("settings", "music_volume", 0.8))
	sfx_volume = float(cfg.get_value("settings", "sfx_volume", 0.9))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))
	battle_speed = 2.0 if float(cfg.get_value("settings", "battle_speed", 1.0)) >= 1.5 else 1.0
	hints_enabled = bool(cfg.get_value("settings", "hints_enabled", true))
	seen_hints.assign(cfg.get_value("settings", "seen_hints", []))
	difficulty = clampi(int(cfg.get_value("settings", "difficulty", Difficulty.NORMAL)), Difficulty.SANTAI, Difficulty.SULIT)
	rhythm_enabled = bool(cfg.get_value("settings", "rhythm_enabled", true))
	glossary_marks = bool(cfg.get_value("settings", "glossary_marks", true))
	large_text = bool(cfg.get_value("settings", "large_text", false))
	key_bindings = KeyBindings.sanitize(cfg.get_value("settings", "keys", {}))
	pad_bindings = PadBindings.sanitize(cfg.get_value("settings", "pad", {}))
	pad_cursor_speed = clampf(float(cfg.get_value("settings", "pad_cursor_speed", 1.0)), 0.5, 2.0)
	var version := int(cfg.get_value("meta", "save_version", 1))
	if version < 2:
		_migrate_from_v1()
	if version < 3:
		_migrate_from_v2()
	if version < SAVE_VERSION:
		save_game()


func _stars_out(masks: Dictionary) -> Dictionary:
	var out := {}
	for stage: Variant in masks:
		out[str(stage)] = int(masks[stage])
	return out


func _stars_in(data: Variant) -> Dictionary:
	var out := {}
	if data is Dictionary:
		for key: Variant in data:
			var stage := int(str(key))
			if stage >= 1 and stage <= STAGE_COUNT:
				out[stage] = clampi(int(data[key]), 0, (1 << Challenges.STARS_PER_STAGE) - 1)
	return out


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
