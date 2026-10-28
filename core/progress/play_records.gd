class_name PlayRecords
extends RefCounted
## Catatan permainan sepanjang masa untuk halaman Catatan di Pustaka: battle,
## Buto yang dikalahkan, Sapu Jagad, jurus favorit, arak-arakan, dan riwayat
## Ruwatan. Seperti Bintang Dongkrek, catatan ini tidak ikut direset saat
## petualangan baru.
##
## Semua fungsi di sini tidak menyentuh GameState, jadi bisa dipakai tes.

## Riwayat Ruwatan yang disimpan (terbaru dulu).
const HISTORY_LIMIT := 10
## Urutan tampil Buto yang dikalahkan. Murka dan Bala dihitung tersendiri.
const BUTO_KEYS: Array[String] = ["kuning", "hijau", "merah", "putih", "hitam", "murka", "bala"]

var battles_won: int = 0
var battles_lost: int = 0
var buto_defeated: Dictionary = {}
## Keluarga kartu -> berapa kali dimainkan (kartu gabungan dihitung sendiri).
var cards_played: Dictionary = {}
var merges: int = 0
var sapu_jagad: int = 0
## Damage terbesar dari satu kartu atau satu Sapu Jagad (jumlah semua sasaran).
var biggest_hit: int = 0
## Nilai irama Sapu Jagad dan arak-arakan terbaik (0..1), -1 kalau belum pernah.
var rhythm_best: float = -1.0
var parade_best: float = -1.0
var stories_completed: int = 0
## {"seed", "level", "steps", "won", "date"}; terbaru di depan.
var ruwatan_history: Array[Dictionary] = []


func add_battle(stats: BattleStats) -> void:
	if stats.won:
		battles_won += 1
	else:
		battles_lost += 1
	for key: String in stats.killed:
		buto_defeated[key] = int(buto_defeated.get(key, 0)) + int(stats.killed[key])
	for family: String in stats.cards_played:
		cards_played[family] = int(cards_played.get(family, 0)) + int(stats.cards_played[family])
	merges += stats.merges
	sapu_jagad += stats.ultimates_used
	biggest_hit = maxi(biggest_hit, stats.biggest_hit)


func add_rhythm(score: float) -> void:
	rhythm_best = maxf(rhythm_best, clampf(score, 0.0, 1.0))


func add_parade(score: float) -> void:
	if score >= 0.0:
		parade_best = maxf(parade_best, clampf(score, 0.0, 1.0))


## Mencatat hasil satu Ruwatan. Ruwatan yang sama (seed dan tingkatnya sama)
## hanya diperbarui, karena hasilnya bisa dilaporkan lebih dari sekali.
func add_ruwatan(seed_value: int, level: int, steps: int, won: bool, date: String) -> void:
	var entry := {"seed": seed_value, "level": level, "steps": steps, "won": won, "date": date}
	for i: int in ruwatan_history.size():
		var old := ruwatan_history[i]
		if int(old.get("seed", -1)) == seed_value and int(old.get("level", -1)) == level:
			ruwatan_history[i] = entry
			return
	ruwatan_history.push_front(entry)
	while ruwatan_history.size() > HISTORY_LIMIT:
		ruwatan_history.pop_back()


func total_defeated() -> int:
	var total := 0
	for key: String in buto_defeated:
		total += int(buto_defeated[key])
	return total


## Keluarga kartu yang paling sering dimainkan ("" kalau belum ada).
func favorite_card() -> String:
	var best := ""
	var best_count := 0
	for family: String in cards_played:
		var count := int(cards_played[family])
		if count > best_count or (count == best_count and best != "" and family < best):
			best = family
			best_count = count
	return best


func to_dict() -> Dictionary:
	return {
		"battles_won": battles_won,
		"battles_lost": battles_lost,
		"buto_defeated": buto_defeated.duplicate(),
		"cards_played": cards_played.duplicate(),
		"merges": merges,
		"sapu_jagad": sapu_jagad,
		"biggest_hit": biggest_hit,
		"rhythm_best": rhythm_best,
		"parade_best": parade_best,
		"stories_completed": stories_completed,
		"ruwatan_history": ruwatan_history.duplicate(true),
	}


## Dari simpanan. Nilai yang rusak diganti nilai awal.
static func from_dict(data: Variant) -> PlayRecords:
	var r := PlayRecords.new()
	if not (data is Dictionary):
		return r
	var d: Dictionary = data
	r.battles_won = maxi(0, int(d.get("battles_won", 0)))
	r.battles_lost = maxi(0, int(d.get("battles_lost", 0)))
	r.buto_defeated = _counts(d.get("buto_defeated", {}))
	r.cards_played = _counts(d.get("cards_played", {}))
	r.merges = maxi(0, int(d.get("merges", 0)))
	r.sapu_jagad = maxi(0, int(d.get("sapu_jagad", 0)))
	r.biggest_hit = maxi(0, int(d.get("biggest_hit", 0)))
	r.rhythm_best = clampf(float(d.get("rhythm_best", -1.0)), -1.0, 1.0)
	r.parade_best = clampf(float(d.get("parade_best", -1.0)), -1.0, 1.0)
	r.stories_completed = maxi(0, int(d.get("stories_completed", 0)))
	var history: Variant = d.get("ruwatan_history", [])
	if history is Array:
		for entry: Variant in history:
			if entry is Dictionary and r.ruwatan_history.size() < HISTORY_LIMIT:
				var e: Dictionary = entry
				r.ruwatan_history.append({
					"seed": int(e.get("seed", 0)),
					"level": clampi(int(e.get("level", 1)), 1, RuwatanRun.MAX_LEVEL),
					"steps": clampi(int(e.get("steps", 0)), 0, RuwatanRun.STEPS.size()),
					"won": bool(e.get("won", false)),
					"date": str(e.get("date", "")),
				})
	return r


static func _counts(data: Variant) -> Dictionary:
	var out := {}
	if data is Dictionary:
		for key: Variant in data:
			var value := int((data as Dictionary)[key])
			if key is String and value > 0:
				out[key] = value
	return out
