class_name EnemyAttackAction
extends BattleAction
## Serangan dasar Buto ke hero.

var attacker: EnemyUnit
var target: HealthComponent
var damage: int
var damage_dealt: int = 0


func _init(enemy: EnemyUnit, target_health: HealthComponent, amount: int) -> void:
	attacker = enemy
	target = target_health
	damage = amount


## Dilewati kalau Buto-nya sudah mati sebelum gilirannya tiba, atau hero
## sudah tumbang.
func is_valid() -> bool:
	return EnemyUnit.is_valid_alive(attacker) and target != null and not target.is_dead()


func _apply(_battle: BattleManager) -> void:
	damage_dealt = target.take_damage(damage)
