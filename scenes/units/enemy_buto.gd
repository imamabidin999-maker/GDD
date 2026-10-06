class_name EnemyButo
extends EnemyUnit
## Buto Dongkrek dengan mekanik pengganggu sesuai warnanya.
##
##   Kuning : setiap serangannya menguras Moxie Overcharge pemain, lewat signal
##            overcharge_drain_requested yang tersambung ke PlayerState.
##   Putih  : skill LockCard, mengunci 1 kartu acak di tangan sehingga tidak bisa
##            digeser atau digabung.
##   Hitam  : boss. Saat HP-nya turun ke fase 2, skill ForceShuffle menghantam
##            hero lalu mengacak sisa deck dan urutan kartu di tangan.
##   Hijau, Merah : untuk sekarang menyerang biasa.
##
## Skill tidak langsung dijalankan di decide_action(). Buto hanya memilih skill,
## lalu ButoSkillAction menjalankannya di RESOLVE_ACTIONS. Jadi skill tetap
## mengikuti alur BattleManager: diantre, ada jeda animasi, lalu cek HP.
## Skill hanya dipilih kalau memang bisa berefek. Kalau tidak, Buto menyerang biasa.

enum ButoType { KUNING, HIJAU, MERAH, PUTIH, HITAM }
enum Skill {
	DRAINING_STRIKE, ## Kuning: serangan + kuras Moxie Overcharge
	LOCK_CARD, ## Putih: kunci 1 kartu acak di tangan
	FORCE_SHUFFLE, ## Hitam fase 2: serangan + acak sisa deck & urutan tangan
}

## Minta PlayerState menguras Moxie Overcharge. Disambungkan otomatis ke
## PlayerState.drain_overcharge() di on_battle_started().
signal overcharge_drain_requested(amount: float)
## Untuk VFX/SFX. succeeded false kalau skill tidak berefek. Detail hasilnya
## (damage, kartu yang dikunci) ada di ButoSkillAction yang sedang di-resolve.
signal skill_used(skill: Skill, succeeded: bool)
## Fase Buto Hitam berubah. Cocok untuk ganti BGM atau animasi marah.
signal phase_changed(phase: int)

@export var buto_type: ButoType = ButoType.KUNING

@export_group("Kuning")
## Moxie Overcharge yang dikuras setiap serangan Buto Kuning (dalam persen).
@export var overcharge_drain: float = 25.0

@export_group("Putih")
## Berapa turn pemain kartu yang dikunci LockCard tetap terkunci.
@export_range(1, 5) var lock_duration_turns: int = 1

@export_group("Hitam (Boss)")
## Fase 2 dimulai saat HP <= rasio ini dikali max HP.
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
# true kalau LockCard dipakai saat tangan kosong. Kuncinya dipasang ke tangan
# baru di awal turn pemain berikutnya.
var _pending_hand_lock: bool = false
var _rng := RandomNumberGenerator.new()
var _drain_receiver: Callable


func get_type_name() -> String:
	return "Buto %s" % String(ButoType.keys()[buto_type]).capitalize()


#region Siklus battle

## Mereset state per battle dan menyambungkan signal ke sistem battle.
## Fase tidak dihitung di sini dari sisa HP battle sebelumnya. Fase dicek lagi
## setiap HP berubah dan setiap kali Buto memilih aksi.
func on_battle_started(battle: BattleManager) -> void:
	var previous_phase := phase
	phase = 1
	_turns_until_skill = 0 # skill pertama boleh langsung dipakai
	_pending_hand_lock = false
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	_connect_drain_to(battle.player.drain_overcharge)
	if health != null and not health.hp_changed.is_connected(_on_hp_changed):
		health.hp_changed.connect(_on_hp_changed)
	if previous_phase != phase:
		phase_changed.emit(phase) # BGM/animasi fase 2 dari battle lalu ikut kembali


## Memasang kunci LockCard yang tertunda ke tangan yang baru ditarik.
func on_player_turn_started(battle: BattleManager) -> void:
	if _pending_hand_lock:
		_pending_hand_lock = false
		lock_card(battle.hand)


## Memilih aksi di awal ENEMY_TURN berdasarkan warna Buto.
func decide_action(battle: BattleManager) -> BattleAction:
	_update_phase()
	var skill_ready := _tick_skill_cooldown()

	match buto_type:
		ButoType.KUNING:
			return ButoSkillAction.new(self, Skill.DRAINING_STRIKE)
		ButoType.PUTIH:
			# Tangan kosong (misalnya mode buang-tangan gaya FGO) tetap boleh:
			# kuncinya dipasang ke tangan baru di awal turn pemain berikutnya.
			var hand_empty := battle.hand.get_card_count() == 0
			if skill_ready and (hand_empty or battle.hand.has_lockable_card()):
				_start_skill_cooldown()
				return ButoSkillAction.new(self, Skill.LOCK_CARD)
		ButoType.HITAM:
			# Mengacak tangan baru berarti kalau ada minimal 2 kartu yang bebas.
			if phase >= 2 and skill_ready and battle.hand.count_unlocked() >= 2:
				_start_skill_cooldown()
				return ButoSkillAction.new(self, Skill.FORCE_SHUFFLE)

	return super.decide_action(battle) # serangan biasa


## Menjalankan skill dan mengisi hasilnya ke action (damage, kartu yang
## dikunci, berhasil atau tidak). Dipanggil ButoSkillAction di RESOLVE_ACTIONS.
func perform_skill(action: ButoSkillAction, battle: BattleManager) -> void:
	match action.skill:
		Skill.DRAINING_STRIKE:
			action.damage_dealt = draining_strike(battle.hero_health)
			action.succeeded = true
		Skill.LOCK_CARD:
			_perform_lock_card(action, battle)
		Skill.FORCE_SHUFFLE:
			action.damage_dealt = battle.hero_health.take_damage(attack_power)
			action.succeeded = force_shuffle(battle.deck, battle.hand)
	skill_used.emit(action.skill, action.succeeded)

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
## di tangan. Kartu yang sedang terkunci tetap di posisinya. Mengembalikan true
## kalau urutan tangan benar-benar berubah.
##
## Catatan: draw pile memang sudah acak dan tidak terlihat pemain, jadi bagian
## deck ini baru terasa kalau nanti ada efek mengintip/menata kartu teratas.
## Untuk sekarang yang langsung terasa adalah acakan urutan tangan.
func force_shuffle(deck: DeckController, hand: HandManager) -> bool:
	deck.shuffle_draw_pile()
	return hand.shuffle_cards(_rng)

#endregion


#region Helper

func _perform_lock_card(action: ButoSkillAction, battle: BattleManager) -> void:
	if battle.hand.get_card_count() == 0:
		_pending_hand_lock = true
		action.succeeded = true
		return

	var index := lock_card(battle.hand)
	if index >= 0:
		action.locked_card = battle.hand.get_card(index)
		action.succeeded = true
		return

	# Semua kartu sudah terkunci, misalnya oleh Buto Putih lain di turn yang
	# sama. Daripada membuang giliran, serang biasa dan skill siap lagi di turn
	# berikutnya.
	action.damage_dealt = battle.hero_health.take_damage(attack_power)
	action.succeeded = false
	_turns_until_skill = 0


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
