extends SceneTree
## Membuat ulang semua file data (.tres) kartu, resep merge, dan stage.
##
## Jalankan dari root repo:
##   godot --headless -s tools/generate_data.gd
##
## Setelah dibuat, file .tres bisa langsung diedit di Inspector Godot. Hati-hati:
## menjalankan script ini lagi akan MENIMPA perubahan manual di file .tres.

const CARD_DIR := "res://data/cards/"
const STAGE_DIR := "res://data/stages/"

# Statistik kartu per rank: [damage, tameng, AP tambahan]
const CARDS := {
	"serang": {"type": CardData.CardType.SERANG, "name": "CARD_SERANG", "stats": [[6, 0, 0], [9, 0, 0], [13, 0, 0]]},
	"fokus": {"type": CardData.CardType.FOKUS, "name": "CARD_FOKUS", "stats": [[3, 0, 0], [4, 0, 0], [6, 0, 0]]},
	"taktik": {"type": CardData.CardType.TAKTIK, "name": "CARD_TAKTIK", "stats": [[0, 5, 0], [0, 8, 0], [0, 12, 0]]},
	"crimson": {"type": CardData.CardType.HYBRID, "name": "CARD_CRIMSON", "stats": [[12, 0, 0], [17, 0, 0], [25, 0, 0]]},
	"piercing": {"type": CardData.CardType.HYBRID, "name": "CARD_PIERCING", "stats": [[10, 4, 0], [14, 6, 0], [20, 9, 0]]},
	"flow": {"type": CardData.CardType.HYBRID, "name": "CARD_FLOW", "stats": [[3, 5, 1], [5, 7, 1], [7, 10, 1]]},
	# Jurus Tabuh: kartu dasar berbingkai emas yang tidak bisa digabung.
	"bedug": {"type": CardData.CardType.TABUH, "name": "CARD_BEDUG", "stats": [[5, 0, 0], [8, 0, 0], [12, 0, 0]],
		"hits_all": true},
	"kentongan": {"type": CardData.CardType.TABUH, "name": "CARD_KENTONGAN", "stats": [[0, 0, 1], [0, 3, 1], [0, 5, 1]],
		"draw": [2, 2, 3]},
	"korek": {"type": CardData.CardType.TABUH, "name": "CARD_KOREK", "stats": [[4, 0, 0], [6, 0, 0], [9, 0, 0]],
		"calm": true, "moxie": [10.0, 15.0, 20.0]},
	"gong": {"type": CardData.CardType.TABUH, "name": "CARD_GONG", "stats": [[18, 0, 0], [26, 0, 0], [36, 0, 0]],
		"ap_cost": 2},
	"kenong": {"type": CardData.CardType.TABUH, "name": "CARD_KENONG", "stats": [[0, 0, 0], [0, 0, 0], [0, 0, 0]],
		"boost": [0.4, 0.6, 0.8], "ap_cost": 0},
	# Gong beri: gong datar tanpa pencu. Bunyinya membuat semua Buto giris.
	"beri": {"type": CardData.CardType.TABUH, "name": "CARD_GONG_BERI", "stats": [[0, 0, 0], [0, 0, 0], [0, 0, 0]],
		"giris": [0.25, 0.35, 0.5], "shatter": true},
}

# Tantangan bintang ke-2 dan ke-3 setiap babak (lihat core/progress/challenges.gd).
const STAGE_CHALLENGES := {
	1: ["turns:4", "hp:80"],
	2: ["merges:3", "no_ult"],
	3: ["max_lara:3", "turns:6"],
	4: ["first:putih", "hp:50"],
	5: ["calm_ready", "turns:7"],
	6: ["max_lara:5", "no_ult"],
	7: ["blocked:60", "hp:50"],
	8: ["max_sirep:2", "turns:8"],
	9: ["no_ngamuk", "hp:40"],
	10: ["ajian:2", "bala_first"],
}

const RECIPES := [
	[CardData.CardType.SERANG, CardData.CardType.FOKUS, "crimson"],
	[CardData.CardType.SERANG, CardData.CardType.TAKTIK, "piercing"],
	[CardData.CardType.FOKUS, CardData.CardType.TAKTIK, "flow"],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARD_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STAGE_DIR))
	var by_family := _build_cards()
	_build_library(by_family)
	_build_stages()
	print("Selesai membuat data.")
	quit(0)


func _build_cards() -> Dictionary:
	var by_family := {}
	for family: String in CARDS:
		var info: Dictionary = CARDS[family]
		var list: Array[CardData] = []
		for i: int in 3:
			var stats: Array = info["stats"][i]
			var card := CardData.new()
			card.id = StringName("%s_%d" % [family, i + 1])
			card.display_name = info["name"]
			card.card_type = info["type"]
			card.rank = i + 1
			card.base_power = stats[0]
			card.shield = stats[1]
			card.ap_gain = stats[2]
			card.ap_cost = info.get("ap_cost", 1)
			card.hits_all = info.get("hits_all", false)
			card.calm_target = info.get("calm", false)
			card.draw = info["draw"][i] if info.has("draw") else 0
			card.next_boost = info["boost"][i] if info.has("boost") else 0.0
			card.moxie_gain = info["moxie"][i] if info.has("moxie") else 0.0
			card.giris = info["giris"][i] if info.has("giris") else 0.0
			card.shatter_block = info.get("shatter", false)
			card.icon = load("res://assets/cards/icon_%s.png" % family)
			var frame_name := "tabuh" if card.card_type == CardData.CardType.TABUH else family
			card.frame = load("res://assets/cards/frame_%s.png" % frame_name)
			var path := "%s%s_%d.tres" % [CARD_DIR, family, i + 1]
			_save(card, path)
			list.append(load(path) as CardData)
		by_family[family] = list
	return by_family


func _build_library(by_family: Dictionary) -> void:
	var library := CardLibrary.new()
	for family: String in CARDS:
		for card: CardData in by_family[family]:
			library.cards.append(card)
	for entry: Array in RECIPES:
		var recipe := MergeRecipe.new()
		recipe.type_a = entry[0]
		recipe.type_b = entry[1]
		for card: CardData in by_family[entry[2]]:
			recipe.results.append(card)
		var path := "res://data/recipes/recipe_%s.tres" % entry[2]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/recipes/"))
		_save(recipe, path)
		library.recipes.append(load(path) as MergeRecipe)
	_save(library, "res://data/card_library.tres")


func _enemy(type: EnemyButo.ButoType, hp: int, attack: int, scale: float = 1.0, cooldown: int = 2) -> EnemySpec:
	var spec := EnemySpec.new()
	spec.buto_type = type
	spec.max_hp = hp
	spec.attack_power = attack
	spec.sprite_scale = scale
	spec.skill_cooldown_turns = cooldown
	return spec


## Buto Murka: dikuatkan Buto Hitam dan bisa Ngamuk. start_amuk menggeser
## kapan Ngamuk pertamanya datang.
func _murka(type: EnemyButo.ButoType, hp: int, attack: int, scale: float = 1.0, start_amuk: int = 0) -> EnemySpec:
	var spec := _enemy(type, hp, attack, scale)
	spec.murka = true
	spec.can_ngamuk = true
	spec.start_amuk = start_amuk
	return spec


func _stage(number: int, enemies: Array[EnemySpec], map_pos: Vector2, tint: Color, intro: int, win: int) -> StageData:
	var stage := StageData.new()
	stage.stage_number = number
	stage.title_key = "STAGE_%d_TITLE" % number
	stage.enemies = enemies
	stage.map_position = map_pos
	stage.background_tint = tint
	var intro_lines := PackedStringArray()
	for i: int in intro:
		intro_lines.append("S%d_INTRO_%d" % [number, i + 1])
	stage.intro_dialog = intro_lines
	var win_lines := PackedStringArray()
	for i: int in win:
		win_lines.append("S%d_WIN_%d" % [number, i + 1])
	stage.victory_dialog = win_lines
	return stage


# Baris dialog: "pembicara|KUNCI". Pembicara ditulis terpisah supaya teksnya
# bisa diterjemahkan tanpa menyentuh data stage.
func _with_speakers(keys: PackedStringArray, speakers: Array[String]) -> PackedStringArray:
	var out := PackedStringArray()
	for i: int in keys.size():
		out.append("%s|%s" % [speakers[i], keys[i]])
	return out


func _build_stages() -> void:
	var K := EnemyButo.ButoType
	var catalog := StageCatalog.new()
	var stages: Array[StageData] = []

	# Bagian I: Kedatangan Buto
	var s1 := _stage(1, [_enemy(K.KUNING, 95, 10)] as Array[EnemySpec],
		Vector2(56, 304), Color(1, 1, 1), 4, 2)
	s1.intro_dialog = _with_speakers(s1.intro_dialog, ["narator", "eyang", "buto_kuning", "eyang"])
	s1.victory_dialog = _with_speakers(s1.victory_dialog, ["warga", "eyang"])
	s1.tutorial_dialog = _with_speakers(PackedStringArray(["TUT_1", "TUT_2", "TUT_3", "TUT_4", "TUT_5", "TUT_6"]),
		["eyang", "eyang", "eyang", "eyang", "eyang", "eyang"])
	stages.append(s1)

	var s2 := _stage(2, [_enemy(K.HIJAU, 110, 11), _enemy(K.KUNING, 70, 9, 0.9)] as Array[EnemySpec],
		Vector2(148, 260), Color(0.82, 1.0, 0.88), 3, 2)
	s2.intro_dialog = _with_speakers(s2.intro_dialog, ["narator", "buto_hijau", "eyang"])
	s2.victory_dialog = _with_speakers(s2.victory_dialog, ["eyang", "narator"])
	stages.append(s2)

	var s3 := _stage(3, [_enemy(K.MERAH, 140, 11), _enemy(K.HIJAU, 80, 9, 0.9)] as Array[EnemySpec],
		Vector2(256, 304), Color(0.82, 0.88, 1.06), 3, 2)
	s3.intro_dialog = _with_speakers(s3.intro_dialog, ["narator", "buto_merah", "eyang"])
	s3.victory_dialog = _with_speakers(s3.victory_dialog, ["eyang", "roro_ayu"])
	stages.append(s3)

	var s4 := _stage(4, [_enemy(K.PUTIH, 160, 15), _enemy(K.MERAH, 135, 12, 0.9)] as Array[EnemySpec],
		Vector2(356, 252), Color(1.0, 0.9, 0.82), 3, 4)
	s4.intro_dialog = _with_speakers(s4.intro_dialog, ["narator", "buto_putih", "eyang"])
	s4.victory_dialog = _with_speakers(s4.victory_dialog, ["eyang", "narator", "buto_hitam", "narator"])
	stages.append(s4)

	# Bagian II: Buto Murka
	var s5 := _stage(5, [_murka(K.KUNING, 165, 12), _enemy(K.HIJAU, 85, 10, 0.9)] as Array[EnemySpec],
		Vector2(280, 192), Color(1.0, 0.95, 0.8), 4, 2)
	s5.intro_dialog = _with_speakers(s5.intro_dialog, ["narator", "buto_kuning", "roro_ayu", "eyang"])
	s5.victory_dialog = _with_speakers(s5.victory_dialog, ["eyang", "roro_ayu"])
	stages.append(s5)

	var s6 := _stage(6, [_murka(K.HIJAU, 150, 11), _enemy(K.MERAH, 90, 10, 0.9)] as Array[EnemySpec],
		Vector2(176, 184), Color(0.74, 0.92, 0.8), 3, 2)
	s6.intro_dialog = _with_speakers(s6.intro_dialog, ["narator", "buto_hijau", "eyang"])
	s6.victory_dialog = _with_speakers(s6.victory_dialog, ["narator", "eyang"])
	stages.append(s6)

	var s7 := _stage(7, [_murka(K.MERAH, 195, 10), _enemy(K.PUTIH, 90, 9, 0.9)] as Array[EnemySpec],
		Vector2(104, 128), Color(0.8, 0.9, 1.06), 3, 2)
	s7.intro_dialog = _with_speakers(s7.intro_dialog, ["narator", "buto_merah", "eyang"])
	s7.victory_dialog = _with_speakers(s7.victory_dialog, ["eyang", "narator"])
	stages.append(s7)

	var s8 := _stage(8, [_murka(K.PUTIH, 270, 18), _enemy(K.KUNING, 120, 12, 0.9)] as Array[EnemySpec],
		Vector2(196, 112), Color(0.9, 0.95, 1.04), 3, 2)
	s8.intro_dialog = _with_speakers(s8.intro_dialog, ["narator", "buto_putih", "eyang"])
	s8.victory_dialog = _with_speakers(s8.victory_dialog, ["roro_ayu", "eyang"])
	stages.append(s8)

	# Bagian III: Candi Pagebluk
	# Titik Amuk awal dibedakan supaya tidak ada dua Buto yang Ngamuk di giliran yang sama.
	var s9 := _stage(9, [
		_murka(K.KUNING, 80, 8, 1.0, 0),
		_murka(K.HIJAU, 85, 7, 1.0, 1),
		_murka(K.MERAH, 95, 7, 1.0, 2),
		_murka(K.PUTIH, 95, 8, 1.0, -1),
	] as Array[EnemySpec], Vector2(392, 140), Color(1.0, 0.84, 0.84), 4, 2)
	s9.intro_dialog = _with_speakers(s9.intro_dialog, ["narator", "buto_merah", "buto_kuning", "eyang"])
	s9.victory_dialog = _with_speakers(s9.victory_dialog, ["narator", "buto_hitam"])
	stages.append(s9)

	var s10 := _stage(10, [_enemy(K.HITAM, 500, 18, 1.15)] as Array[EnemySpec],
		Vector2(554, 112), Color(0.92, 0.72, 0.78), 4, 2)
	s10.music = "boss"
	s10.is_boss = true
	s10.intro_dialog = _with_speakers(s10.intro_dialog, ["narator", "buto_hitam", "eyang", "buto_hitam"])
	s10.victory_dialog = _with_speakers(s10.victory_dialog, ["buto_hitam", "eyang"])
	stages.append(s10)

	# Musik: Bagian I lagu battle biasa, Bagian II lagu Buto Murka, babak 9 lagu
	# Candi Pagebluk, dan babak 10 lagu bos (fase kedua berganti ke "boss2").
	s9.music = "battle_candi"
	for stage: StageData in stages:
		stage.chapter = 1 if stage.stage_number <= 4 else (2 if stage.stage_number <= 8 else 3)
		if stage.chapter == 2:
			stage.music = "battle_murka"
		# Latar digambar khusus untuk tiap tempat (tools/build_backgrounds.py),
		# jadi warnanya tidak perlu diwarnai lagi.
		stage.background = "res://assets/backgrounds/stage_%d.png" % stage.stage_number
		stage.background_tint = Color.WHITE
		stage.challenges = PackedStringArray(STAGE_CHALLENGES[stage.stage_number])

	for stage: StageData in stages:
		var path := "%sstage_%d.tres" % [STAGE_DIR, stage.stage_number]
		_save(stage, path)
		catalog.stages.append(load(path) as StageData)

	catalog.prologue_dialog = _with_speakers(
		PackedStringArray(["PROLOGUE_1", "PROLOGUE_2", "PROLOGUE_3", "PROLOGUE_4", "PROLOGUE_5", "PROLOGUE_6"]),
		["narator", "narator", "warga", "narator", "eyang", "eyang"])
	catalog.ending_dialog = _with_speakers(
		PackedStringArray(["ENDING_1", "ENDING_2", "ENDING_3", "ENDING_4", "ENDING_5", "ENDING_6"]),
		["narator", "roro_ayu", "eyang", "eyang", "narator", "narator"])
	_save(catalog, StageCatalog.PATH)


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Gagal menyimpan %s (%d)" % [path, err])
	else:
		print("  ", path)
