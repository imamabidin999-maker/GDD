class_name RuwatanRun
extends RefCounted
## Satu perjalanan Ruwatan, mode yang terbuka setelah tamat: delapan langkah
## berisi battle, kejadian, dan Buto Hitam di akhir. Deck, berkah, dan Nyawa
## milik Ruwatan sendiri, terpisah dari petualangan cerita. Nyawa terbawa dari
## battle ke battle dan hanya pulih sebagian setelah menang.
##
## Tingkat Pagebluk (1-10) menambah kesulitan secara bertumpuk. Aturannya ada
## di fungsi-fungsi bagian "Tingkat Pagebluk" di bawah.
##
## Antarmuka profilnya sama dengan GameState (get_deck, get_blessings,
## get_max_hp, change_max_hp, apply_blessing, upgrade_card, downgrade_card,
## place_tabuh, roll_blessings), jadi panel berkah, kejadian, dan pemilih
## kartu dipakai apa adanya. Kelas ini tidak menyebut autoload supaya bisa
## dipakai tes dan simulasi keseimbangan.

## Ada perubahan yang perlu disimpan.
signal changed

enum Step { BATTLE, MURKA, TWIN_MURKA, EVENT, BOSS }
enum State { ACTIVE, WON, LOST }

const STEPS: Array[Step] = [
	Step.BATTLE, Step.BATTLE, Step.EVENT, Step.MURKA,
	Step.MURKA, Step.EVENT, Step.TWIN_MURKA, Step.BOSS,
]
const MAX_LEVEL := 10
const START_HP := 70
const MIN_MAX_HP := 30
const HEAL_RATIO := 0.45
const HEAL_RATIO_HARD := 0.35
const START_POISON := 1
const COLORS: Array[EnemyButo.ButoType] = [
	EnemyButo.ButoType.KUNING, EnemyButo.ButoType.HIJAU,
	EnemyButo.ButoType.MERAH, EnemyButo.ButoType.PUTIH,
]
## [Nyawa, serangan] tiap warna menurut perannya, sebelum Tingkat Pagebluk.
## Lebih ringan daripada babak cerita karena Nyawa terbawa dan berkah datang
## sambil jalan.
const LEAD := {
	EnemyButo.ButoType.KUNING: [80, 9], EnemyButo.ButoType.HIJAU: [88, 9],
	EnemyButo.ButoType.MERAH: [104, 9], EnemyButo.ButoType.PUTIH: [116, 11],
}
const COMPANION := {
	EnemyButo.ButoType.KUNING: [56, 8], EnemyButo.ButoType.HIJAU: [60, 8],
	EnemyButo.ButoType.MERAH: [68, 8], EnemyButo.ButoType.PUTIH: [68, 8],
}
const MURKA_LEAD := {
	EnemyButo.ButoType.KUNING: [120, 10], EnemyButo.ButoType.HIJAU: [114, 9],
	EnemyButo.ButoType.MERAH: [140, 9], EnemyButo.ButoType.PUTIH: [172, 12],
}
const TWIN := {
	EnemyButo.ButoType.KUNING: [92, 9], EnemyButo.ButoType.HIJAU: [88, 8],
	EnemyButo.ButoType.MERAH: [104, 8], EnemyButo.ButoType.PUTIH: [120, 10],
}
const BOSS := [370, 15]
## Battle kedua dari jenis yang sama (langkah 2 dan 5) sedikit lebih alot.
const SECOND_HP_MULT := 1.05
## Keluarga kartu yang boleh ada di deck simpanan.
const DECK_FAMILIES: Array[String] = ["serang", "fokus", "taktik", "bedug", "kentongan", "korek", "gong", "beri", "kenong"]
## Latar battle yang boleh dipakai tiap langkah (nomor babak cerita).
const BACKGROUND_POOLS: Array = [[1, 2, 3, 4], [1, 2, 3, 4], [], [5, 6, 7, 8], [5, 6, 7, 8], [], [9], [10]]

var level: int = 1
var seed_value: int = 0
## Langkah yang sedang dijalani (0..7). STEPS.size() setelah Ruwatan berhasil.
var step: int = 0
var state: State = State.ACTIVE
var deck: Array[String] = []
var blessings: Array[String] = []
var max_hp: int = START_HP
var hp: int = START_HP
## Battle baru dimenangkan dan berkahnya belum dipilih.
var pending_blessing: bool = false
## Berkah awal hadiah Bintang Dongkrek ("" kalau tidak ada).
var start_blessing: String = ""
## Berkah yang belum terbuka (Kenong sebelum 8 bintang). Diisi GameState.
var excluded_blessings: Array = []
## Lawan tiap langkah: daftar {"type", "role", "amuk"}. Kosong untuk kejadian.
## Ditentukan dari seed, jadi battle yang ditinggal di tengah jalan tetap sama.
var foes: Array = []
## Kejadian tiap langkah ("" kalau bukan langkah kejadian).
var events: Array[String] = []
## Latar tiap langkah (nomor babak cerita, 0 untuk kejadian).
var backgrounds: Array[int] = []


## Ruwatan baru di tingkat `level` dengan deck awal `starter`.
static func create(start_level: int, new_seed: int, starter: Array[String], excluded: Array = []) -> RuwatanRun:
	var run := RuwatanRun.new()
	run.level = clampi(start_level, 1, MAX_LEVEL)
	run.seed_value = new_seed
	run.deck = starter.duplicate()
	run.excluded_blessings = excluded.duplicate()
	run._generate()
	return run


## Hadiah 24 Bintang Dongkrek: satu berkah acak di awal. Berkah kartu Tabuh
## tidak ikut diundi karena butuh pemain memilih kartu. -1 kalau tidak ada.
func grant_start_blessing(rng: RandomNumberGenerator) -> int:
	var excluded := excluded_blessings.duplicate()
	excluded.append_array(Blessings.TABUH_FAMILY.keys())
	var options := Blessings.available(deck, blessings, excluded)
	options.erase(Blessings.Kind.LARAS_GAMELAN)
	for kind: Blessings.Kind in Blessings.TABUH_FAMILY:
		options.erase(kind)
	if options.is_empty():
		return -1
	var kind: Blessings.Kind = options[rng.randi_range(0, options.size() - 1)]
	apply_blessing(kind)
	start_blessing = Blessings.kind_name(kind)
	changed.emit()
	return kind


#region Langkah

func current_step() -> Step:
	return STEPS[clampi(step, 0, STEPS.size() - 1)]


func is_over() -> bool:
	return state != State.ACTIVE


func is_battle_step(index: int = step) -> bool:
	return index >= 0 and index < STEPS.size() and STEPS[index] != Step.EVENT


func current_event() -> String:
	if is_over() or step >= STEPS.size():
		return ""
	return events[step]


## Langkah yang sudah dilewati (8 kalau Ruwatan berhasil).
func steps_cleared() -> int:
	return STEPS.size() if state == State.WON else step


## Battle langkah ini dimenangkan dengan sisa Nyawa `hp_left`. Nyawa pulih
## sebagian dan berkah menunggu dipilih. Mengembalikan Nyawa yang dipulihkan.
func win_battle(hp_left: int) -> int:
	if is_over() or not is_battle_step():
		return 0
	hp = clampi(hp_left, 1, max_hp)
	if current_step() == Step.BOSS:
		state = State.WON
		step = STEPS.size()
		changed.emit()
		return 0
	var before := hp
	hp = mini(max_hp, hp + roundi(max_hp * heal_ratio()))
	pending_blessing = true
	step += 1
	changed.emit()
	return hp - before


func lose_battle() -> void:
	if is_over():
		return
	state = State.LOST
	hp = 0
	changed.emit()


func finish_event() -> void:
	if is_over() or current_step() != Step.EVENT:
		return
	step += 1
	changed.emit()


func finish_blessing() -> void:
	pending_blessing = false
	changed.emit()

#endregion


#region Lawan

## Data babak untuk battle di langkah `index`: lawan, musik, dan warna latar.
func build_stage(index: int = step) -> StageData:
	var stage := StageData.new()
	stage.stage_number = 0
	stage.enemies = enemy_specs(index)
	stage.is_boss = index >= 0 and index < STEPS.size() and STEPS[index] == Step.BOSS
	stage.music = "boss" if stage.is_boss else "battle"
	if index >= 0 and index < backgrounds.size() and backgrounds[index] > 0:
		stage.background = "res://assets/backgrounds/stage_%d.png" % backgrounds[index]
	return stage


## EnemySpec langkah `index` dengan angka dasar (Tingkat Pagebluk dipasang
## lewat modify_buto() setelah Buto dibuat).
func enemy_specs(index: int = step) -> Array[EnemySpec]:
	var out: Array[EnemySpec] = []
	if index < 0 or index >= foes.size():
		return out
	for foe: Dictionary in foes[index]:
		out.append(_spec_for(foe, index))
	return out


func _spec_for(foe: Dictionary, index: int) -> EnemySpec:
	var type: EnemyButo.ButoType = foe["type"]
	var spec := EnemySpec.new()
	spec.buto_type = type
	spec.start_amuk = int(foe.get("amuk", 0))
	var stats: Array = BOSS
	match str(foe["role"]):
		"lead":
			stats = LEAD[type]
		"companion":
			stats = COMPANION[type]
			spec.sprite_scale = 0.9
		"murka":
			stats = MURKA_LEAD[type]
			spec.murka = true
			spec.can_ngamuk = true
		"twin":
			stats = TWIN[type]
			spec.murka = true
			spec.can_ngamuk = true
		_:
			spec.sprite_scale = 1.15
	var hp_mult := SECOND_HP_MULT if index == 1 or index == 4 else 1.0
	spec.max_hp = roundi(int(stats[0]) * hp_mult)
	spec.attack_power = int(stats[1])
	return spec


## Menerapkan Tingkat Pagebluk ke Buto yang baru dibuat dari EnemySpec.
func modify_buto(buto: EnemyButo) -> void:
	var hp_mult := enemy_hp_mult()
	var atk_mult := enemy_attack_mult()
	buto.health.max_hp = maxi(1, roundi(buto.health.max_hp * hp_mult))
	buto.health.reset()
	buto.attack_power = maxi(1, roundi(buto.attack_power * atk_mult))
	buto.bala_hp = maxi(1, roundi(buto.bala_hp * hp_mult))
	buto.bala_attack = maxi(1, roundi(buto.bala_attack * atk_mult))
	if normal_ngamuk():
		buto.can_ngamuk = true
	if level >= 9:
		buto.bala_count = 3
	if level >= 10:
		buto.ajian_break_threshold += 10
		buto.pagebluk_poison += 1


# Lawan seluruh langkah dan dua kejadian, ditentukan dari seed.
func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	foes.clear()
	events.clear()
	backgrounds.clear()
	var picked_events: Array[String] = []
	var last_lead := -1
	for i: int in STEPS.size():
		var group: Array = []
		var event_id := ""
		match STEPS[i]:
			Step.BATTLE, Step.MURKA:
				var lead := _pick_color(rng, [last_lead])
				var companion := _pick_color(rng, [lead])
				last_lead = lead
				# Pendamping Ngamuk belakangan kalau Tingkat Pagebluk 5 membuatnya bisa Ngamuk.
				group = [
					{"type": lead, "role": "lead" if STEPS[i] == Step.BATTLE else "murka", "amuk": 0},
					{"type": companion, "role": "companion", "amuk": -1},
				]
			Step.TWIN_MURKA:
				var first := _pick_color(rng, [])
				var second := _pick_color(rng, [first])
				group = [
					{"type": first, "role": "twin", "amuk": 0},
					{"type": second, "role": "twin", "amuk": 2},
				]
			Step.BOSS:
				group = [{"type": EnemyButo.ButoType.HITAM, "role": "boss", "amuk": 0}]
			Step.EVENT:
				event_id = JourneyEvents.pick(rng, picked_events)
				picked_events.append(event_id)
		foes.append(group)
		events.append(event_id)
		var pool: Array = BACKGROUND_POOLS[i].duplicate()
		if i > 0 and backgrounds[i - 1] > 0 and pool.size() > 1:
			pool.erase(backgrounds[i - 1])
		backgrounds.append(int(pool[rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else 0)


func _pick_color(rng: RandomNumberGenerator, avoid: Array) -> EnemyButo.ButoType:
	var pool: Array[EnemyButo.ButoType] = []
	for c: EnemyButo.ButoType in COLORS:
		if not avoid.has(c):
			pool.append(c)
	return pool[rng.randi_range(0, pool.size() - 1)]

## Nyawa Buto yang ditampilkan di layar Ruwatan (sudah termasuk Tingkat Pagebluk).
func display_hp(spec: EnemySpec) -> int:
	return maxi(1, roundi(spec.max_hp * enemy_hp_mult()))


static func step_title_key(kind: Step) -> String:
	match kind:
		Step.MURKA:
			return "RUWATAN_STEP_MURKA"
		Step.TWIN_MURKA:
			return "RUWATAN_STEP_TWIN"
		Step.EVENT:
			return "RUWATAN_STEP_EVENT"
		Step.BOSS:
			return "RUWATAN_STEP_BOSS"
	return "RUWATAN_STEP_BATTLE"

#endregion


#region Tingkat Pagebluk

func enemy_hp_mult() -> float:
	if level >= 8:
		return 1.2
	return 1.1 if level >= 2 else 1.0


func enemy_attack_mult() -> float:
	return 1.1 if level >= 3 else 1.0


func heal_ratio() -> float:
	return HEAL_RATIO_HARD if level >= 4 else HEAL_RATIO


## Buto biasa (bukan Murka) juga bisa Ngamuk.
func normal_ngamuk() -> bool:
	return level >= 5


func blessing_choices() -> int:
	return 2 if level >= 6 else 3


## Lara di awal setiap battle.
func start_poison() -> int:
	return START_POISON if level >= 7 else 0


## Kunci teks aturan tambahan tingkat 2 sampai `up_to` (untuk layar pilih tingkat).
static func rule_keys(up_to: int) -> Array[String]:
	var keys: Array[String] = []
	for n: int in range(2, clampi(up_to, 1, MAX_LEVEL) + 1):
		keys.append("PAGEBLUK_RULE_%d" % n)
	return keys

#endregion


#region Profil pemain

func get_deck() -> Array[String]:
	return deck


func get_blessings() -> Array[String]:
	return blessings


func get_max_hp() -> int:
	return max_hp


## Nyawa maksimal bertambah atau berkurang. Tambahan ikut mengisi Nyawa.
func change_max_hp(delta: int) -> int:
	max_hp = maxi(MIN_MAX_HP, max_hp + delta)
	hp = clampi(hp + maxi(delta, 0), 1, max_hp)
	changed.emit()
	return max_hp


func roll_blessings(rng: RandomNumberGenerator) -> Array[Blessings.Kind]:
	return Blessings.roll(rng, deck, blessings, blessing_choices(), excluded_blessings)


func apply_blessing(kind: Blessings.Kind, _for_stage: int = 0) -> Array[String]:
	var upgraded := Blessings.apply_to_deck(kind, deck)
	if kind == Blessings.Kind.JAMU_KUNYIT_ASAM:
		max_hp += Blessings.JAMU_HP
		hp += Blessings.JAMU_HP
	blessings.append(Blessings.kind_name(kind))
	changed.emit()
	return upgraded


func place_tabuh(index: int, family: String) -> Array[String]:
	if index < 0 or index >= deck.size() or not Blessings.TABUH_FAMILIES.has(family):
		return []
	var old := deck[index]
	deck[index] = Blessings.tabuh_spec_for(family, old)
	changed.emit()
	return [old, deck[index]]


func upgrade_card(index: int) -> String:
	var result := Blessings.upgrade_at(deck, index)
	if result != "":
		changed.emit()
	return result


func downgrade_card(index: int) -> String:
	var result := Blessings.downgrade_at(deck, index)
	if result != "":
		changed.emit()
	return result

#endregion


#region Simpan & muat

func to_dict() -> Dictionary:
	return {
		"level": level,
		"seed": seed_value,
		"step": step,
		"state": state,
		"deck": deck.duplicate(),
		"blessings": blessings.duplicate(),
		"max_hp": max_hp,
		"hp": hp,
		"pending_blessing": pending_blessing,
		"start_blessing": start_blessing,
	}


## null kalau datanya rusak atau dari versi yang tidak dikenal.
static func from_dict(data: Dictionary, excluded: Array = []) -> RuwatanRun:
	var saved_deck: Variant = data.get("deck", [])
	if not (saved_deck is Array) or not _is_valid_deck(saved_deck):
		return null
	var run := RuwatanRun.new()
	run.level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	run.seed_value = int(data.get("seed", 0))
	run.step = clampi(int(data.get("step", 0)), 0, STEPS.size())
	match int(data.get("state", State.ACTIVE)):
		State.WON:
			run.state = State.WON
		State.LOST:
			run.state = State.LOST
	run.deck.assign(saved_deck)
	for entry: Variant in data.get("blessings", []):
		if entry is String and Blessings.from_name(entry) >= 0:
			run.blessings.append(entry)
	run.max_hp = maxi(MIN_MAX_HP, int(data.get("max_hp", START_HP)))
	run.hp = clampi(int(data.get("hp", run.max_hp)), 0, run.max_hp)
	if run.state == State.ACTIVE:
		run.hp = maxi(run.hp, 1)
		if run.step >= STEPS.size():
			run.step = STEPS.size() - 1
	run.pending_blessing = bool(data.get("pending_blessing", false))
	run.start_blessing = str(data.get("start_blessing", ""))
	run.excluded_blessings = excluded.duplicate()
	run._generate()
	return run


static func _is_valid_deck(saved: Array) -> bool:
	if saved.is_empty():
		return false
	for entry: Variant in saved:
		if not (entry is String):
			return false
		var parts := (entry as String).split(":")
		if parts.size() != 2 or not DECK_FAMILIES.has(parts[0]) or int(parts[1]) < 1 or int(parts[1]) > Blessings.MAX_RANK:
			return false
	return true

#endregion
