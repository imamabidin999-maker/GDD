class_name PoisonTickAction
extends BattleAction
## Racun Buto Hijau bekerja di akhir giliran musuh: hero kehilangan HP sebanyak
## jumlah tumpukan (menembus Tameng), lalu tumpukannya berkurang satu.
## Dijalankan lewat RESOLVE_ACTIONS supaya kekalahan karena racun ikut dicek.
##
## Selalu diantre di akhir giliran musuh, karena semburan racun di giliran yang
## sama baru berlaku setelah aksi Buto selesai. Kalau saat gilirannya tiba
## racunnya 0, aksi ini dilewati.

var player: PlayerState
var damage_dealt: int = 0


func _init(target_player: PlayerState) -> void:
	player = target_player


func is_valid() -> bool:
	return player != null and player.poison > 0


func _apply(battle: BattleManager) -> void:
	damage_dealt = battle.hero_health.lose_hp(player.tick_poison())
