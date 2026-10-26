class_name UltimateAction
extends BattleAction
## Ultimate Eyang Palang: "Sapu Jagad", menghantam SEMUA Buto.
## Bunyinya juga membuyarkan amukan: titik Amuk semua Buto dikosongkan.
## Moxie sudah dihabiskan BattleManager saat request, jadi aksi ini tinggal
## menghitung damage.
##
## Rumus:
##   base_damage × ultimate_damage_multiplier × (moxie_spent / 100)
## Moxie 100% memberi pengali 1×, overcharge penuh 200% memberi 2×.
## ultimate_damage_multiplier naik lewat Evolutionary Chain.
## Hasilnya dikali rhythm_bonus dari permainan irama (sampai 1,3×).

var moxie_spent: float
var base_damage: int
var rhythm_bonus: float = 1.0
## Damage per Buto (sama untuk semua) dan totalnya, untuk ditampilkan view.
var damage_per_target: int = 0
var damage_dealt: int = 0
var targets: Array[EnemyUnit] = []
## Berapa Buto yang amukannya buyar.
var calmed: int = 0
## Berapa Buto yang kekuatannya (Ajian) buyar.
var broken: int = 0
## Berapa Buto yang sudah siap Ngamuk lalu amukannya buyar.
var calmed_ready: int = 0


func _init(spent_moxie: float, ultimate_base_damage: int, bonus: float = 1.0) -> void:
	moxie_spent = spent_moxie
	base_damage = ultimate_base_damage
	rhythm_bonus = maxf(bonus, 1.0)


func _apply(battle: BattleManager) -> void:
	var overcharge_factor := moxie_spent / PlayerState.MOXIE_NORMAL_CAP
	damage_per_target = roundi(base_damage * battle.player.ultimate_damage_multiplier * overcharge_factor * rhythm_bonus)
	targets = battle.get_living_enemies()
	for enemy: EnemyUnit in targets:
		if enemy.is_ngamuk_ready():
			calmed_ready += 1
		damage_dealt += enemy.health.take_damage(damage_per_target)
	calmed = battle.calm_enemies()
	broken = battle.break_enemy_powers()
