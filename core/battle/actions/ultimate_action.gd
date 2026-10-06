class_name UltimateAction
extends BattleAction
## Ultimate pemain. Moxie sudah dihabiskan BattleManager saat request, jadi
## aksi ini tinggal menghitung damage.
##
## Rumus sementara:
##   base_damage × ultimate_damage_multiplier × (moxie_spent / 100)
## Moxie 100% memberi pengali 1×, overcharge penuh 200% memberi 2×.

var target: EnemyUnit
var moxie_spent: float
var base_damage: int
var damage_dealt: int = 0


func _init(target_enemy: EnemyUnit, spent_moxie: float, ultimate_base_damage: int) -> void:
	target = target_enemy
	moxie_spent = spent_moxie
	base_damage = ultimate_base_damage


func _apply(battle: BattleManager) -> void:
	if not EnemyUnit.is_valid_alive(target):
		return
	var overcharge_factor := moxie_spent / PlayerState.MOXIE_NORMAL_CAP
	var damage := roundi(base_damage * battle.player.ultimate_damage_multiplier * overcharge_factor)
	damage_dealt = target.health.take_damage(damage)
