class_name HealthComponent
extends Node
## HP satu unit, entah hero atau Buto. Dipasang sebagai child node bernama "Health".
##
## HP langsung penuh sejak node dibuat, tanpa menunggu _ready(). Untuk hero
## yang HP-nya terbawa antar battle, panggil reset(hp_dari_game_state).

signal hp_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

## Mengubah max_hp saat HP sedang penuh akan ikut mengisi penuh HP.
## Jadi Buto yang max_hp-nya diatur di Inspector tetap mulai dengan HP penuh.
@export_range(1, 9999) var max_hp: int = 100:
	set(value):
		var was_full := current_hp == max_hp
		max_hp = maxi(value, 1)
		if was_full or current_hp > max_hp:
			current_hp = max_hp

var current_hp: int = 100


## Mengisi ulang HP. Tanpa argumen berarti penuh.
func reset(starting_hp: int = -1) -> void:
	current_hp = max_hp if starting_hp < 0 else clampi(starting_hp, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)


func is_dead() -> bool:
	return current_hp <= 0


## Mengurangi HP dan mengembalikan damage yang benar-benar masuk.
## Unit yang sudah mati tidak bisa terkena damage lagi.
func take_damage(amount: int) -> int:
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
