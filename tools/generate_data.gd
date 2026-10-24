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
			card.icon = load("res://assets/cards/icon_%s.png" % family)
			card.frame = load("res://assets/cards/frame_%s.png" % family)
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

	var s1 := _stage(1, [_enemy(K.KUNING, 40, 6)] as Array[EnemySpec],
		Vector2(92, 268), Color(1, 1, 1), 4, 2)
	s1.intro_dialog = _with_speakers(s1.intro_dialog, ["narator", "eyang", "buto_kuning", "eyang"])
	s1.victory_dialog = _with_speakers(s1.victory_dialog, ["warga", "eyang"])
	s1.tutorial_dialog = _with_speakers(PackedStringArray(["TUT_1", "TUT_2", "TUT_3", "TUT_4", "TUT_5", "TUT_6"]),
		["eyang", "eyang", "eyang", "eyang", "eyang", "eyang"])

	var s2 := _stage(2, [_enemy(K.HIJAU, 46, 6), _enemy(K.KUNING, 30, 5, 0.9)] as Array[EnemySpec],
		Vector2(206, 196), Color(0.82, 1.0, 0.88), 3, 2)
	s2.intro_dialog = _with_speakers(s2.intro_dialog, ["narator", "buto_hijau", "eyang"])
	s2.victory_dialog = _with_speakers(s2.victory_dialog, ["eyang", "narator"])

	var s3 := _stage(3, [_enemy(K.MERAH, 64, 7), _enemy(K.HIJAU, 36, 5, 0.9)] as Array[EnemySpec],
		Vector2(318, 262), Color(0.82, 0.88, 1.06), 3, 2)
	s3.intro_dialog = _with_speakers(s3.intro_dialog, ["narator", "buto_merah", "eyang"])
	s3.victory_dialog = _with_speakers(s3.victory_dialog, ["eyang", "roro_ayu"])

	var s4 := _stage(4, [_enemy(K.PUTIH, 58, 7), _enemy(K.MERAH, 52, 6, 0.9)] as Array[EnemySpec],
		Vector2(438, 188), Color(1.0, 0.9, 0.82), 3, 2)
	s4.intro_dialog = _with_speakers(s4.intro_dialog, ["narator", "buto_putih", "eyang"])
	s4.victory_dialog = _with_speakers(s4.victory_dialog, ["eyang", "narator"])

	var s5 := _stage(5, [_enemy(K.HITAM, 170, 9, 1.15)] as Array[EnemySpec],
		Vector2(554, 112), Color(0.92, 0.72, 0.78), 4, 2)
	s5.music = "boss"
	s5.is_boss = true
	s5.intro_dialog = _with_speakers(s5.intro_dialog, ["narator", "buto_hitam", "eyang", "buto_hitam"])
	s5.victory_dialog = _with_speakers(s5.victory_dialog, ["buto_hitam", "eyang"])

	for stage: StageData in [s1, s2, s3, s4, s5]:
		var path := "%sstage_%d.tres" % [STAGE_DIR, stage.stage_number]
		_save(stage, path)
		catalog.stages.append(load(path) as StageData)

	catalog.prologue_dialog = _with_speakers(
		PackedStringArray(["PROLOGUE_1", "PROLOGUE_2", "PROLOGUE_3", "PROLOGUE_4", "PROLOGUE_5"]),
		["narator", "narator", "warga", "narator", "eyang"])
	catalog.ending_dialog = _with_speakers(
		PackedStringArray(["ENDING_1", "ENDING_2", "ENDING_3", "ENDING_4", "ENDING_5"]),
		["narator", "roro_ayu", "eyang", "narator", "narator"])
	_save(catalog, StageCatalog.PATH)


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Gagal menyimpan %s (%d)" % [path, err])
	else:
		print("  ", path)
