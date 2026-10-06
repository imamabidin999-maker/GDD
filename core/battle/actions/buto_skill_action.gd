class_name ButoSkillAction
extends BattleAction
## Aksi Buto yang memakai skill khusus warnanya.
##
## Logika skill-nya sendiri ada di EnemyButo.perform_skill(). Aksi ini hanya
## menjadwalkannya di RESOLVE_ACTIONS, supaya skill tetap diantre, punya jeda
## animasi, dan diikuti cek HP seperti aksi lainnya.

var buto: EnemyButo
var skill: EnemyButo.Skill
## Hasil skill, diisi EnemyButo.perform_skill() untuk ditampilkan view.
## false kalau skill gagal berefek, misalnya tidak ada kartu yang bisa dikunci.
var succeeded: bool = false
## Damage ke hero (serangan Kuning, hantaman Hitam, atau serangan cadangan Putih).
var damage_dealt: int = 0
## Kartu yang dikunci LockCard. null kalau tidak ada, atau kuncinya ditunda ke
## tangan berikutnya karena tangan sedang kosong.
var locked_card: CardInstance


func _init(user: EnemyButo, used_skill: EnemyButo.Skill) -> void:
	buto = user
	skill = used_skill


## Dilewati kalau Buto-nya sudah mati sebelum gilirannya tiba.
func is_valid() -> bool:
	return EnemyUnit.is_valid_alive(buto)


func _apply(battle: BattleManager) -> void:
	buto.perform_skill(self, battle)
