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

## Titik Amuk berubah (0..AMUK_MAX, boleh negatif di awal battle).
signal amuk_changed(value: int)

## Jumlah aksi yang mengisi Amuk sampai penuh.
const AMUK_MAX := 3

@export var display_name: String = "Buto"
## HealthComponent milik Buto ini, biasanya child bernama "Health".
@export var health: HealthComponent
@export var attack_power: int = 10

@export_group("Ngamuk")
## Kalau aktif, setiap aksi mengisi satu titik Amuk. Setelah AMUK_MAX titik
## terisi, giliran berikutnya Buto ini Ngamuk: beraksi dua kali.
@export var can_ngamuk: bool = false
## Titik Amuk di awal battle. Boleh negatif supaya Ngamuk pertamanya datang
## lebih lambat (dipakai babak 9 supaya Buto tidak ngamuk bersamaan).
@export var start_amuk: int = 0

var amuk: int = 0:
	set(value):
		if value == amuk:
			return
		amuk = value
		amuk_changed.emit(amuk)


## true kalau enemy masih ada (belum di-free) dan HP-nya di atas 0.
## Parameternya sengaja Variant: di Godot 4, mengoper node yang sudah di-free
## ke parameter bertipe EnemyUnit langsung memicu error.
static func is_valid_alive(enemy: Variant) -> bool:
	return is_instance_valid(enemy) and enemy is EnemyUnit and (enemy as EnemyUnit).is_alive()


func is_alive() -> bool:
	return health != null and not health.is_dead()


func is_ngamuk_ready() -> bool:
	return can_ngamuk and amuk >= AMUK_MAX


## Berapa aksi Buto ini di giliran musuh berikutnya. Turunan boleh menunda
## Ngamuk (misalnya Buto Hitam saat melepas Ajian).
func get_action_count() -> int:
	return 2 if is_ngamuk_ready() else 1


## Dipanggil BattleManager setelah Buto ini selesai memilih aksinya di giliran
## musuh. Ngamuk mengosongkan Amuk; aksi biasa mengisi satu titik.
func finish_enemy_turn(actions_taken: int) -> void:
	if not can_ngamuk:
		return
	if actions_taken >= 2:
		amuk = 0
	else:
		amuk = mini(amuk + 1, AMUK_MAX)


## Gebrakan Dongkrek juga membuyarkan kekuatan yang sedang disiapkan Buto
## (Ajian Lebur Saketi milik Buto Hitam). Mengembalikan true kalau ada yang buyar.
func break_power() -> bool:
	return false


## Aksi tambahan di akhir giliran musuh, setelah semua Buto beraksi dan
## sebelum Lara bekerja. Contohnya Pagebluk Merata milik Buto Hitam.
func get_end_turn_action(_battle: BattleManager) -> BattleAction:
	return null


## Gebrakan Dongkrek membuyarkan amukan. Titik negatif (jeda awal) dibiarkan.
## Mengembalikan true kalau ada titik Amuk yang hilang.
func calm_amuk() -> bool:
	if amuk <= 0:
		return false
	amuk = 0
	return true


## Semua niat untuk giliran musuh berikutnya, dua kalau Buto ini akan Ngamuk.
func get_intents(battle: BattleManager) -> Array[EnemyIntent]:
	var list: Array[EnemyIntent] = [get_intent(battle)]
	if get_action_count() >= 2:
		list.append(get_intent(battle))
	return list


## Dipanggil BattleManager.start_battle() untuk setiap musuh, sebelum turn
## pertama. Turunan boleh meng-override untuk mereset state per battle atau
## menyambungkan signal ke sistem battle.
func on_battle_started(_battle: BattleManager) -> void:
	pass


## Dipanggil BattleManager di awal setiap turn baru pemain, setelah kartu
## ditarik, untuk setiap musuh yang masih hidup. Cocok untuk efek yang menunggu
## tangan baru, atau nanti untuk memilih intent yang ditampilkan ke pemain.
func on_player_turn_started(_battle: BattleManager) -> void:
	pass


## Niat untuk giliran musuh berikutnya, untuk ikon di atas kepala.
## Hanya mengintip: tidak mengubah state apa pun.
func get_intent(_battle: BattleManager) -> EnemyIntent:
	return EnemyIntent.new(EnemyIntent.Kind.ATTACK, attack_power)


## Dipanggil BattleManager di awal ENEMY_TURN. Boleh mengembalikan null kalau
## Buto ini tidak beraksi di turn ini, misalnya sedang terkena stun. Override
## boleh memakai await; BattleManager menunggunya sebelum lanjut.
func decide_action(battle: BattleManager) -> BattleAction:
	return EnemyAttackAction.new(self, battle.hero_health, attack_power)
