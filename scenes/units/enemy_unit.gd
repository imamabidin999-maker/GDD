class_name EnemyUnit
extends Node2D
## Satu Buto di medan tempur.
##
## AI dasarnya paling sederhana: selalu menyerang hero. Mekanik khusus tiap
## warna Buto ada di turunannya, EnemyButo.
##
## Buto yang mati jangan di-queue_free() selama battle masih berjalan. Cukup
## sembunyikan setelah animasi matinya selesai, lalu bersihkan setelah
## BattleManager memancarkan battle_ended.

@export var display_name: String = "Buto"
## HealthComponent milik Buto ini, biasanya child bernama "Health".
@export var health: HealthComponent
@export var attack_power: int = 10


## true kalau enemy masih ada (belum di-free) dan HP-nya di atas 0.
## Parameternya sengaja Variant: di Godot 4, mengoper node yang sudah di-free
## ke parameter bertipe EnemyUnit langsung memicu error.
static func is_valid_alive(enemy: Variant) -> bool:
	return is_instance_valid(enemy) and enemy is EnemyUnit and (enemy as EnemyUnit).is_alive()


func is_alive() -> bool:
	return health != null and not health.is_dead()


## Dipanggil BattleManager.start_battle() untuk setiap musuh, sebelum turn
## pertama. Turunan boleh meng-override untuk mereset state per battle atau
## menyambungkan signal ke sistem battle.
func on_battle_started(_battle: BattleManager) -> void:
	pass


## Dipanggil BattleManager di awal ENEMY_TURN. Boleh mengembalikan null kalau
## Buto ini tidak beraksi di turn ini, misalnya sedang terkena stun. Override
## boleh memakai await; BattleManager menunggunya sebelum lanjut.
func decide_action(battle: BattleManager) -> BattleAction:
	return EnemyAttackAction.new(self, battle.hero_health, attack_power)
