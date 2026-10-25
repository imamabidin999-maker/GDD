class_name Challenges
extends RefCounted
## Tantangan babak untuk Bintang Dongkrek.
##
## Setiap babak punya tiga bintang: bintang pertama untuk menang, dua lainnya
## dari tantangan yang ditulis di StageData.challenges sebagai teks pendek:
##
##   turns:N      menang paling lama N giliran
##   hp:P         sisa Nyawa minimal P persen
##   merges:N     gabung kartu minimal N kali
##   no_ult       menang tanpa Gebrakan Dongkrek
##   max_lara:N   Lara tidak pernah lebih dari N
##   first:WARNA  Buto berwarna itu tumbang lebih dulu
##   calm_ready   membuyarkan amukan Buto yang siap Ngamuk
##   blocked:N    Tameng menahan total minimal N damage
##   max_sirep:N  paling banyak N kartu tersirep
##   no_ngamuk    tidak ada Buto yang sempat Ngamuk
##   ajian:N      membuyarkan Ajian minimal N kali
##   bala_first   semua Bala dikalahkan sebelum Buto Hitam

const STARS_PER_STAGE := 3

## Hadiah Bintang Dongkrek: jumlah bintang yang dibutuhkan.
const KENONG_STARS := 8
const REROLL_STARS := 16
const RUWATAN_BLESSING_STARS := 24
const MASTER_STARS := 30


## Hasil tiga bintang: [menang, tantangan 1, tantangan 2].
static func evaluate(challenges: PackedStringArray, stats: BattleStats) -> Array[bool]:
	var results: Array[bool] = [stats.won]
	for id: String in challenges:
		results.append(stats.won and is_met(id, stats))
	while results.size() < STARS_PER_STAGE:
		results.append(false)
	return results


static func is_met(id: String, stats: BattleStats) -> bool:
	var key := id.get_slice(":", 0)
	var arg := id.get_slice(":", 1)
	match key:
		"turns":
			return stats.turns <= int(arg)
		"hp":
			return stats.hp_ratio() * 100.0 >= float(arg) - 0.001
		"merges":
			return stats.merges >= int(arg)
		"no_ult":
			return stats.ultimates_used == 0
		"max_lara":
			return stats.max_poison <= int(arg)
		"first":
			return stats.first_killed == arg
		"calm_ready":
			return stats.calmed_ready >= 1
		"blocked":
			return stats.block_absorbed >= int(arg)
		"max_sirep":
			return stats.sirep_received <= int(arg)
		"no_ngamuk":
			return stats.ngamuk_count == 0
		"ajian":
			return stats.ajian_breaks >= int(arg)
		"bala_first":
			return stats.bala_summoned > 0 and stats.bala_killed_before_boss >= stats.bala_summoned
	push_error("Challenges: tantangan '%s' tidak dikenal." % id)
	return false


## Kalimat tantangan untuk ditampilkan.
static func describe(id: String) -> String:
	var key := id.get_slice(":", 0)
	var arg := id.get_slice(":", 1)
	match key:
		"win":
			return TranslationServer.translate("CH_WIN")
		"no_ult", "calm_ready", "no_ngamuk", "bala_first":
			return TranslationServer.translate("CH_" + key.to_upper())
		"first":
			return TranslationServer.translate("CH_FIRST") % TranslationServer.translate("BUTO_" + arg.to_upper())
	return TranslationServer.translate("CH_" + key.to_upper()) % int(arg)


## Tiga kalimat bintang sebuah babak, dimulai dengan "Menangkan babak".
static func describe_stage(challenges: PackedStringArray) -> Array[String]:
	var lines: Array[String] = [describe("win")]
	for id: String in challenges:
		lines.append(describe(id))
	return lines


static func mask_of(results: Array[bool]) -> int:
	var mask := 0
	for i: int in results.size():
		if results[i]:
			mask |= 1 << i
	return mask


static func count_bits(mask: int) -> int:
	var total := 0
	for i: int in STARS_PER_STAGE:
		if mask & (1 << i):
			total += 1
	return total


## Hadiah yang terbuka di jumlah bintang ini (urut naik), sebagai kunci teks.
static func rewards() -> Array:
	return [
		[KENONG_STARS, "STAR_REWARD_KENONG"],
		[REROLL_STARS, "STAR_REWARD_REROLL"],
		[RUWATAN_BLESSING_STARS, "STAR_REWARD_RUWATAN"],
		[MASTER_STARS, "STAR_REWARD_MASTER"],
	]
