class_name EnemyButo
extends EnemyUnit
## Buto Dongkrek dengan mekanik pengganggu sesuai warnanya.
##
##   Kuning : setiap serangannya menguras Moxie Overcharge pemain, lewat signal
##            overcharge_drain_requested yang tersambung ke PlayerState.
##   Putih  : skill LockCard, mengunci 1 kartu acak di tangan sehingga tidak bisa
##            digeser atau digabung.
##   Hitam  : boss. Saat HP-nya turun ke fase 2, skill ForceShuffle mengacak sisa
##            deck dan urutan kartu di tangan.
##   Hijau, Merah : untuk sekarang menyerang biasa.
##
## Skill tidak langsung dijalankan di decide_action(). Buto hanya memilih skill,
## lalu ButoSkillAction menjalankannya di RESOLVE_ACTIONS. Jadi skill tetap
## mengikuti alur BattleManager: diantre, ada jeda animasi, lalu cek HP.

enum ButoType { KUNING, HIJAU, MERAH, PUTIH, HITAM }
enum Skill {
	DRAINING_STRIKE, ## Kuning: serangan + kuras Moxie Overcharge
	LOCK_CARD, ## Putih: kunci 1 kartu acak di tangan
	FORCE_SHUFFLE, ## Hitam fase 2: acak sisa deck & urutan tangan
}

## Minta PlayerState menguras Moxie Overcharge. Disambungkan otomatis ke
## PlayerState.drain_overcharge() di on_battle_started().
signal overcharge_drain_requested(amount: float)
## Untuk VFX/SFX. succeeded false kalau skill tidak berefek.
signal skill_used(skill: Skill, succeeded: bool)
## Buto Hitam masuk fase baru. Cocok untuk ganti BGM atau animasi marah.
signal phase_changed(phase: int)

@export var buto_type: ButoType = ButoType.KUNING

@export_group("Kuning")
## Moxie Overcharge yang dikuras setiap serangan Buto Kuning (dalam persen).
@export var overcharge_drain: float = 25.0

@export_group("Putih")
## Berapa turn pemain kartu yang dikunci LockCard tetap terkunci.
@export_range(1, 5) var lock_duration_turns: int = 1

@export_group("Hitam (Boss)")
## Fase 2 dimulai saat HP <= rasio ini dari max HP.
@export_range(0.05, 0.95, 0.05) var phase_two_hp_ratio: float = 0.5

@export_group("Skill")
## Skill (LockCard, ForceShuffle) dipakai setiap N turn musuh. 1 = setiap turn.
## Serangan Buto Kuning tidak memakai cooldown karena efeknya menempel di serangan.
@export_range(1, 5) var skill_cooldown_turns: int = 2
## Seed acakan skill. 0 = acak setiap battle. Isi angka tetap untuk debugging.
@export var rng_seed: int = 0

## Fase boss. Hanya Buto Hitam yang bisa naik ke fase 2; Buto lain selalu 1.
var phase: int = 1

var _turns_until_skill: int = 0
var _rng := RandomNumberGenerator.new()
var _drain_receiver: Callable


func get_type_name() -> String:
	return "Buto %s" % String(ButoType.keys()[buto_type]).capitalize()


#region Siklus battle

## Mereset state per battle dan menyambungkan signal ke sistem battle.
func on_battle_started(battle: BattleManager) -> void:
	phase = 1
	_turns_until_skill = 0 # skill pertama boleh langsung dipakai
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	_connect_drain_to(battle.player.drain_overcharge)
	if health != null and not health.hp_changed.is_connected(_on_hp_changed):
		health.hp_changed.connect(_on_hp_changed)
	_update_phase()


## Memilih aksi di awal ENEMY_TURN berdasarkan warna Buto.
func decide_action(battle: BattleManager) -> BattleAction:
	_update_phase()
	var skill_ready := _tick_skill_cooldown()

	match buto_type:
		ButoType.KUNING:
			return ButoSkillAction.new(self, Skill.DRAINING_STRIKE)
		ButoType.PUTIH:
			if skill_ready and battle.hand.has_lockable_card():
				_start_skill_cooldown()
				return ButoSkillAction.new(self, Skill.LOCK_CARD)
		ButoType.HITAM:
			if phase >= 2 and skill_ready:
				_start_skill_cooldown()
				return ButoSkillAction.new(self, Skill.FORCE_SHUFFLE)

	return super.decide_action(battle) # serangan biasa


## Menjalankan skill. Dipanggil ButoSkillAction di state RESOLVE_ACTIONS.
## Mengembalikan false kalau skill tidak berefek.
func perform_skill(skill: Skill, battle: BattleManager) -> bool:
	var success := false
	match skill:
		Skill.DRAINING_STRIKE:
			draining_strike(battle.hero_health)
			success = true
		Skill.LOCK_CARD:
			success = lock_card(battle.hand) >= 0
		Skill.FORCE_SHUFFLE:
			force_shuffle(battle.deck, battle.hand)
			success = true
	skill_used.emit(skill, success)
	return success

#endregion


#region Skill

## Buto Kuning: damage biasa ke hero, lalu memancarkan overcharge_drain_requested
## supaya PlayerState menguras Moxie di atas 100%. Moxie di bawah 100% aman.
## Mengembalikan damage yang masuk.
func draining_strike(hero_health: HealthComponent) -> int:
	var dealt := hero_health.take_damage(attack_power)
	overcharge_drain_requested.emit(overcharge_drain)
	return dealt


## LockCard (Buto Putih): mengunci 1 kartu acak yang belum terkunci selama
## lock_duration_turns turn pemain. Kartu terkunci tidak bisa digeser atau
## digabung, tapi tetap bisa dimainkan. Mengembalikan index kartu yang dikunci,
## atau -1 kalau tidak ada kartu yang bisa dikunci.
func lock_card(hand: HandManager) -> int:
	return hand.lock_random_card(_rng, lock_duration_turns)


## ForceShuffle (Buto Hitam fase 2): mengacak sisa draw pile dan urutan kartu
## di tangan. Kartu yang sedang terkunci tetap di posisinya.
func force_shuffle(deck: DeckController, hand: HandManager) -> void:
	deck.shuffle_draw_pile()
	hand.shuffle_cards(_rng)

#endregion


#region Helper

# true kalau skill siap dipakai turn ini. Kalau belum, cooldown dihitung mundur.
func _tick_skill_cooldown() -> bool:
	if _turns_until_skill > 0:
		_turns_until_skill -= 1
		return false
	return true


func _start_skill_cooldown() -> void:
	_turns_until_skill = skill_cooldown_turns - 1


func _on_hp_changed(_current: int, _maximum: int) -> void:
	_update_phase()


# Fase dicek setiap HP berubah, jadi phase_changed langsung terpancar saat Buto
# Hitam terkena pukulan yang membawanya ke fase 2.
func _update_phase() -> void:
	if buto_type != ButoType.HITAM or phase >= 2 or not is_alive():
		return
	if health.current_hp <= health.max_hp * phase_two_hp_ratio:
		phase = 2
		_turns_until_skill = 0 # ForceShuffle langsung dipakai di turn musuh berikutnya
		phase_changed.emit(phase)


# Satu Buto hanya tersambung ke satu PlayerState. Kalau battle baru memakai
# PlayerState lain, sambungan lama dilepas dulu.
func _connect_drain_to(receiver: Callable) -> void:
	if _drain_receiver == receiver and overcharge_drain_requested.is_connected(receiver):
		return
	if _drain_receiver.is_valid() and overcharge_drain_requested.is_connected(_drain_receiver):
		overcharge_drain_requested.disconnect(_drain_receiver)
	_drain_receiver = receiver
	overcharge_drain_requested.connect(receiver)

#endregion
