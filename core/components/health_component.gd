class_name HealthComponent
extends Node
## HP satu unit, entah hero atau Buto. Dipasang sebagai child node bernama "Health".
##
## HP langsung penuh sejak node dibuat, tanpa menunggu _ready(). Untuk hero
## yang HP-nya terbawa antar battle, panggil reset(hp_dari_game_state).
##
## Tameng (block) menyerap damage lebih dulu sebelum HP berkurang. Eyang
## Palang mendapat Tameng dari kartu Taktik; BattleManager mengosongkannya di
## awal setiap turn pemain.

signal hp_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died
signal block_changed(block: int)
## Sebagian damage tertahan Tameng. Cocok untuk angka "diblok" di UI.
signal damage_blocked(amount: int)

## Mengubah max_hp saat HP sedang penuh akan ikut mengisi penuh HP.
## Jadi Buto yang max_hp-nya diatur di Inspector tetap mulai dengan HP penuh.
## hp_changed hanya dipancarkan setelah node siap (_ready sudah jalan). Sebelum
## itu, view (HP bar) cukup membaca current_hp dan max_hp di _ready miliknya.
@export_range(1, 9999) var max_hp: int = 100:
	set(value):
		var old_max := max_hp
		var old_hp := current_hp
		max_hp = maxi(value, 1)
		if old_hp == old_max or current_hp > max_hp:
			current_hp = max_hp
		if is_node_ready() and (max_hp != old_max or current_hp != old_hp):
			hp_changed.emit(current_hp, max_hp)

var current_hp: int = 100
var block: int = 0


## Mengisi ulang HP. Tanpa argumen berarti penuh. Tameng ikut dikosongkan.
func reset(starting_hp: int = -1) -> void:
	current_hp = max_hp if starting_hp < 0 else clampi(starting_hp, 0, max_hp)
	block = 0
	hp_changed.emit(current_hp, max_hp)
	block_changed.emit(block)


func is_dead() -> bool:
	return current_hp <= 0


## Mengurangi HP dan mengembalikan damage yang benar-benar mengenai HP.
## Tameng menyerap damage lebih dulu. Unit yang sudah mati tidak bisa terkena
## damage lagi.
func take_damage(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	if block > 0:
		var absorbed := mini(block, amount)
		block -= absorbed
		amount -= absorbed
		block_changed.emit(block)
		damage_blocked.emit(absorbed)
	return lose_hp(amount)


## Mengurangi HP tanpa melewati Tameng, misalnya karena racun.
func lose_hp(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var dealt := mini(amount, current_hp)
	current_hp -= dealt
	damaged.emit(dealt)
	hp_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		died.emit()
	return dealt


## Menambah HP dan mengembalikan jumlah yang benar-benar pulih.
## Unit yang sudah mati tidak bisa dipulihkan lewat fungsi ini.
func heal(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var restored := mini(amount, max_hp - current_hp)
	if restored == 0:
		return 0
	current_hp += restored
	healed.emit(restored)
	hp_changed.emit(current_hp, max_hp)
	return restored


func gain_block(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	block += amount
	block_changed.emit(block)


func clear_block() -> void:
	if block == 0:
		return
	block = 0
	block_changed.emit(block)
