class_name BattleAction
extends RefCounted
## Satu aksi yang diselesaikan di state RESOLVE_ACTIONS (pola Command).
##
## Turunannya cukup meng-override _apply() untuk menghitung dan menerapkan
## efeknya (damage, Moxie, discard). execute() lalu menunggu animasinya lewat
## BattleManager.present_action() sebelum state machine lanjut ke state berikutnya.


## Dipanggil BattleManager. Yang di-override di turunan adalah _apply(), bukan fungsi ini.
func execute(battle: BattleManager) -> void:
	@warning_ignore("redundant_await")
	await _apply(battle)
	await battle.present_action(self)


## false kalau aksi sudah tidak relevan, misalnya pelakunya sudah mati sebelum
## gilirannya tiba. Aksi yang tidak valid dilewati tanpa efek.
func is_valid() -> bool:
	return true


## Hitung dan terapkan efek aksi. Override di turunan.
## Boleh memakai await, misalnya untuk serangan beruntun Buto Kuning. Selama
## itu state tetap RESOLVE_ACTIONS sehingga input pemain tetap terkunci.
func _apply(_battle: BattleManager) -> void:
	pass
