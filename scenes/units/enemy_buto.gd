class_name EnemyButo
extends EnemyUnit
## Buto Dongkrek dengan mekanik pengganggu sesuai warnanya.
##
##   Kuning : setiap serangannya menguras Moxie Overcharge pemain, lewat signal
##            overcharge_drain_requested yang tersambung ke PlayerState.
##   Hijau  : setiap beberapa turn menyemburkan racun. Racun mengurangi HP hero
##            di akhir giliran musuh, menembus Tameng.
##   Merah  : pola tiga langkah: serang biasa, ancang-ancang, pukulan berat.
##   Putih  : ilmu Sirep (skill LOCK_CARD), menyirep kartu berbintang tertinggi
##            di tangan sehingga tidak bisa dimainkan, digeser, atau digabung.
##   Hitam  : bos. Pola empat langkah: Gebug Pagebluk (serangan + Lara),
##            Gebug, ancang-ancang Ajian, lalu Ajian Lebur Saketi. Ajian buyar
##            kalau pemain memberi cukup damage di giliran setelah ancang-ancang
##            atau memakai Gebrakan Dongkrek; Buto Hitam lalu terhuyung dan
##            kehilangan satu aksi. Di fase 2 ia Memanggil Bala (Buto bayangan
##            yang membuatnya hanya menerima separuh damage), menebar Pagebluk
##            Merata (+Lara tiap giliran, Lara tidak berkurang), dan bisa Ngamuk.
##
## Skill tidak langsung dijalankan di decide_action(). Buto hanya memilih skill,
## lalu ButoSkillAction menjalankannya di RESOLVE_ACTIONS. Jadi skill tetap
## mengikuti alur BattleManager: diantre, ada jeda animasi, lalu cek HP.
## Skill hanya dipilih kalau memang bisa berefek. Kalau tidak, Buto menyerang biasa.

enum ButoType { KUNING, HIJAU, MERAH, PUTIH, HITAM }
enum Skill {
	NONE = -1, ## serangan biasa
	DRAINING_STRIKE, ## Kuning: serangan + kuras Moxie Overcharge
	LOCK_CARD, ## Putih: kunci 1 kartu acak di tangan
	POISON_SPIT, ## Hijau: serangan ringan + racun
	CHARGE, ## Merah: ancang-ancang, tidak menyerang
	HEAVY_STRIKE, ## Merah: pukulan berat
	PLAGUE_STRIKE, ## Hitam: Gebug Pagebluk, serangan + Lara
	AJIAN_CHARGE, ## Hitam: ancang-ancang Ajian Lebur Saketi
	AJIAN, ## Hitam: Ajian Lebur Saketi
	SUMMON_BALA, ## Hitam fase 2: memanggil Buto bayangan
	STAGGER, ## Hitam: terhuyung, tidak beraksi
	PAGEBLUK, ## Hitam fase 2: Pagebluk Merata di akhir giliran musuh
}

## Minta PlayerState menguras Moxie Overcharge. Disambungkan otomatis ke
## PlayerState.drain_overcharge() di on_battle_started().
signal overcharge_drain_requested(amount: float)
## Untuk VFX/SFX. succeeded false kalau skill tidak berefek. Detail hasilnya
## (damage, kartu yang dikunci) ada di ButoSkillAction yang sedang di-resolve.
signal skill_used(skill: Skill, succeeded: bool)
## Fase Buto Hitam berubah. Cocok untuk ganti BGM atau animasi marah.
signal phase_changed(phase: int)
## Bar "Buyarkan" Ajian. progress -1 berarti bar disembunyikan.
signal ajian_progress_changed(progress: int, threshold: int)
## Ajian Lebur Saketi buyar; Buto Hitam terhuyung di giliran berikutnya.
signal ajian_broken
## Bala masih hidup (Buto Hitam hanya menerima sebagian damage) atau sudah habis.
signal bala_shield_changed(active: bool)

@export var buto_type: ButoType = ButoType.KUNING
## Buto Murka (dikuatkan Buto Hitam). Panggil apply_murka() setelah mengisi
## buto_type supaya angka-angka ilmunya ikut naik.
@export var murka: bool = false
## Bala: Buto bayangan panggilan Buto Hitam. Tidak bisa Ngamuk.
@export var is_bala: bool = false

@export_group("Kuning")
## Moxie Overcharge yang dikuras setiap serangan Buto Kuning (dalam persen).
@export var overcharge_drain: float = 25.0
## Kuning Murka: Greget yang dihisap dari level berapa pun.
@export var murka_drain: float = 20.0

@export_group("Hijau")
## Tumpukan racun dari satu semburan.
@export_range(1, 10) var poison_stacks: int = 3

@export_group("Merah")
## Pukulan berat = attack_power × pengali ini.
@export var heavy_multiplier: float = 2.5
## Merah Murka: Tameng yang didapat saat ancang-ancang.
@export var murka_charge_block: int = 10

@export_group("Putih")
## Berapa giliran pemain kartu yang disirep tetap tersirep.
@export_range(1, 5) var lock_duration_turns: int = 1
## Berapa kartu yang disirep sekaligus (Buto Putih Murka: 2).
@export_range(1, 3) var sirep_count: int = 1

@export_group("Hitam (Boss)")
## Fase 2 dimulai saat HP <= rasio ini dikali max HP.
@export_range(0.05, 0.95, 0.05) var phase_two_hp_ratio: float = 0.5
## Ajian Lebur Saketi = attack_power × pengali ini.
@export var ajian_multiplier: float = 2.5
## Lara dari Ajian Lebur Saketi.
@export_range(0, 10) var ajian_poison: int = 3
## Lara dari Gebug Pagebluk.
@export_range(0, 10) var plague_poison: int = 2
## Total damage dalam satu giliran pemain yang membuyarkan Ajian.
@export var ajian_break_threshold: int = 40
## Jumlah Bala yang dipanggil di fase 2 (warnanya acak dan berbeda).
@export_range(1, 4) var bala_count: int = 2
@export var bala_hp: int = 35
@export var bala_attack: int = 6
## Pengali damage ke Buto Hitam selama masih ada Bala yang hidup.
@export_range(0.1, 1.0, 0.05) var bala_damage_multiplier: float = 0.5
## Pagebluk Merata: Lara tambahan di akhir setiap giliran musuh selama fase 2.
@export_range(0, 5) var pagebluk_poison: int = 1

@export_group("Skill")
## Skill (racun, LockCard, ForceShuffle) dipakai setiap N turn musuh. 1 = setiap turn.
## Serangan Buto Kuning dan pola Buto Merah tidak memakai cooldown ini.
@export_range(1, 5) var skill_cooldown_turns: int = 2
## Seed acakan skill. 0 = acak setiap battle. Isi angka tetap untuk debugging.
@export var rng_seed: int = 0

## Fase boss. Hanya Buto Hitam yang bisa naik ke fase 2; Buto lain selalu 1.
var phase: int = 1

var _turns_until_skill: int = 0
# Langkah pola Buto Merah: 0 serang biasa, 1 ancang-ancang, 2 pukulan berat.
var _merah_step: int = 0
# true kalau LockCard dipakai saat tangan kosong. Kuncinya dipasang ke tangan
# baru di awal turn pemain berikutnya.
var _pending_hand_lock: bool = false
var _rng := RandomNumberGenerator.new()
var _drain_receiver: Callable
var _player: PlayerState

# Pola Buto Hitam: 0 Gebug Pagebluk, 1 Gebug, 2 ancang-ancang Ajian. Ajian
# sendiri dilepas di giliran berikutnya selama _ajian_charged masih true.
var _hitam_step: int = 0
var _ajian_charged: bool = false
var _ajian_progress: int = 0
var _staggered: bool = false
# Giliran musuh ini dipakai terhuyung, jadi Amuk tidak bertambah.
var _stagger_turn: bool = false
var _bala_summoned: bool = false
var _bala: Array[EnemyUnit] = []


## Kunci untuk teks dan gambar, misalnya "kuning".
func get_type_key() -> String:
	return String(ButoType.keys()[buto_type]).to_lower()


func get_type_name() -> String:
	return "Buto %s" % String(ButoType.keys()[buto_type]).capitalize()


## Damage serangan biasa saat ini.
func get_attack_damage() -> int:
	return attack_power


func get_ajian_damage() -> int:
	return roundi(attack_power * ajian_multiplier)


## true kalau Ajian sedang disiapkan dan bisa dibuyarkan giliran ini.
func is_ajian_charged() -> bool:
	return _ajian_charged


func get_ajian_progress() -> int:
	return _ajian_progress


## Bala yang masih hidup.
func get_living_bala() -> Array[EnemyUnit]:
	var living: Array[EnemyUnit] = []
	for b: EnemyUnit in _bala:
		if EnemyUnit.is_valid_alive(b):
			living.append(b)
	return living


func get_heavy_damage() -> int:
	return roundi(attack_power * heavy_multiplier)


func get_spit_damage() -> int:
	# Hijau Murka menyembur dengan tenaga penuh.
	return attack_power if murka else ceili(attack_power * 0.5)


## Menjadikan Buto ini Buto Murka: aura, Ngamuk, dan ilmu yang lebih kuat.
func apply_murka() -> void:
	murka = true
	can_ngamuk = true
	match buto_type:
		ButoType.HIJAU:
			poison_stacks = 5
		ButoType.MERAH:
			heavy_multiplier = 3.0
		ButoType.PUTIH:
			sirep_count = 2


# Panjang pola Merah: biasa 3 langkah (serang, ancang-ancang, gebug),
# Murka 2 langkah (ancang-ancang, gebug).
func _merah_cycle() -> int:
	return 2 if murka else 3


#region Siklus battle

## Mereset state per battle dan menyambungkan signal ke sistem battle.
## Fase tidak dihitung di sini dari sisa HP battle sebelumnya. Fase dicek lagi
## setiap HP berubah dan setiap kali Buto memilih aksi.
func on_battle_started(battle: BattleManager) -> void:
	var previous_phase := phase
	phase = 1
	_turns_until_skill = 0 # skill pertama boleh langsung dipakai
	_merah_step = 0
	_pending_hand_lock = false
	_hitam_step = 0
	_ajian_charged = false
	_ajian_progress = 0
	_staggered = false
	_stagger_turn = false
	_bala_summoned = false
	_bala.clear()
	if buto_type == ButoType.HITAM:
		can_ngamuk = false # Buto Hitam baru bisa Ngamuk di fase 2
		amuk = 0
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	_connect_drain_to(battle.player.drain_overcharge)
	_player = battle.player
	if health != null and not health.hp_changed.is_connected(_on_hp_changed):
		health.hp_changed.connect(_on_hp_changed)
	if health != null and not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	if health != null:
		health.damage_taken_multiplier = 1.0
	if previous_phase != phase:
		phase_changed.emit(phase) # BGM/animasi fase 2 dari battle lalu ikut kembali


## Memasang kunci LockCard yang tertunda ke tangan yang baru ditarik.
func on_player_turn_started(battle: BattleManager) -> void:
	if _pending_hand_lock:
		_pending_hand_lock = false
		lock_card(battle.hand)


## Niat turn musuh berikutnya. Hanya mengintip, tidak mengubah cooldown.
## Dihitung ulang setiap tangan berubah, jadi ikon niat selalu jujur
## (misalnya Buto Hitam batal mengacak kalau kartu bebas tinggal satu).
func get_intent(battle: BattleManager) -> EnemyIntent:
	var intent := _build_intent(battle)
	intent.murka = murka
	return intent


func _build_intent(battle: BattleManager) -> EnemyIntent:
	var skill := _pick_skill(battle, _turns_until_skill <= 0)
	match skill:
		Skill.DRAINING_STRIKE:
			return EnemyIntent.new(EnemyIntent.Kind.DRAIN, attack_power, roundi(murka_drain if murka else overcharge_drain))
		Skill.LOCK_CARD:
			return EnemyIntent.new(EnemyIntent.Kind.LOCK, 0, sirep_count)
		Skill.PLAGUE_STRIKE:
			return EnemyIntent.new(EnemyIntent.Kind.PLAGUE_STRIKE, get_attack_damage(), plague_poison)
		Skill.AJIAN_CHARGE:
			return EnemyIntent.new(EnemyIntent.Kind.AJIAN_CHARGE, 0, get_ajian_damage())
		Skill.AJIAN:
			return EnemyIntent.new(EnemyIntent.Kind.AJIAN, get_ajian_damage(), ajian_poison)
		Skill.SUMMON_BALA:
			return EnemyIntent.new(EnemyIntent.Kind.SUMMON, 0, bala_count)
		Skill.STAGGER:
			return EnemyIntent.new(EnemyIntent.Kind.STAGGER)
		Skill.POISON_SPIT:
			return EnemyIntent.new(EnemyIntent.Kind.POISON, get_spit_damage(), poison_stacks)
		Skill.CHARGE:
			return EnemyIntent.new(EnemyIntent.Kind.CHARGE, 0, get_heavy_damage())
		Skill.HEAVY_STRIKE:
			return EnemyIntent.new(EnemyIntent.Kind.HEAVY, get_heavy_damage())
	return EnemyIntent.new(EnemyIntent.Kind.ATTACK, get_attack_damage())


## Dua niat kalau Buto ini akan Ngamuk. Niat kedua dihitung dari keadaan
## setelah aksi pertama (cooldown dan langkah pola), lalu keadaannya dikembalikan.
func get_intents(battle: BattleManager) -> Array[EnemyIntent]:
	var list: Array[EnemyIntent] = [get_intent(battle)]
	if get_action_count() < 2:
		return list
	var saved := _save_pattern()
	_after_pick(_pick_skill(battle, _tick_skill_cooldown()))
	list.append(get_intent(battle))
	_restore_pattern(saved)
	return list


## Buto Hitam menunda Ngamuk kalau giliran depannya terhuyung, ancang-ancang
## Ajian, atau melepas Ajian. Ajian selalu punya satu giliran pemain untuk
## dibuyarkan, dan tidak pernah jatuh bersama amukan.
func get_action_count() -> int:
	var count := super()
	if count >= 2 and buto_type == ButoType.HITAM:
		var next := _hitam_next_skill()
		if next == Skill.STAGGER or next == Skill.AJIAN_CHARGE or next == Skill.AJIAN:
			return 1
	return count


func finish_enemy_turn(actions_taken: int) -> void:
	if _stagger_turn:
		_stagger_turn = false
		return # terhuyung tidak dihitung sebagai aksi
	super(actions_taken)


## Gebrakan Dongkrek membuyarkan Ajian yang sedang disiapkan.
func break_power() -> bool:
	if not _ajian_charged:
		return false
	_break_ajian()
	return true


## Pagebluk Merata di akhir setiap giliran musuh selama fase 2.
func get_end_turn_action(_battle: BattleManager) -> BattleAction:
	if buto_type == ButoType.HITAM and phase >= 2 and pagebluk_poison > 0:
		return ButoSkillAction.new(self, Skill.PAGEBLUK)
	return null


## Memilih aksi di awal ENEMY_TURN berdasarkan warna Buto.
func decide_action(battle: BattleManager) -> BattleAction:
	_update_phase()
	var skill_ready := _tick_skill_cooldown()
	var skill := _pick_skill(battle, skill_ready)
	_after_pick(skill)

	if skill == Skill.NONE:
		return EnemyAttackAction.new(self, battle.hero_health, get_attack_damage())
	return ButoSkillAction.new(self, skill)


## Menjalankan skill dan mengisi hasilnya ke action (damage, kartu yang
## dikunci, berhasil atau tidak). Dipanggil ButoSkillAction di RESOLVE_ACTIONS.
func perform_skill(action: ButoSkillAction, battle: BattleManager) -> void:
	match action.skill:
		Skill.DRAINING_STRIKE:
			action.damage_dealt = draining_strike(battle.hero_health)
			action.succeeded = true
		Skill.LOCK_CARD:
			_perform_lock_card(action, battle)
		Skill.PLAGUE_STRIKE:
			action.damage_dealt = battle.hero_health.take_damage(get_attack_damage())
			battle.player.add_poison(plague_poison)
			action.succeeded = true
		Skill.AJIAN_CHARGE:
			action.succeeded = true
			ajian_progress_changed.emit(_ajian_progress, ajian_break_threshold)
		Skill.AJIAN:
			action.damage_dealt = battle.hero_health.take_damage(get_ajian_damage())
			battle.player.add_poison(ajian_poison)
			action.succeeded = true
			ajian_progress_changed.emit(-1, ajian_break_threshold)
		Skill.SUMMON_BALA:
			action.summoned = _summon_bala(battle)
			action.succeeded = not action.summoned.is_empty()
		Skill.STAGGER:
			action.succeeded = true
		Skill.PAGEBLUK:
			battle.player.add_poison(pagebluk_poison)
			action.succeeded = true
		Skill.POISON_SPIT:
			action.damage_dealt = battle.hero_health.take_damage(get_spit_damage())
			battle.player.add_poison(poison_stacks)
			action.succeeded = true
		Skill.CHARGE:
			action.succeeded = true # ancang-ancang: tidak menyerang turn ini
			if murka and murka_charge_block > 0:
				health.gain_block(murka_charge_block)
		Skill.HEAVY_STRIKE:
			action.damage_dealt = battle.hero_health.take_damage(get_heavy_damage())
			action.succeeded = true
	skill_used.emit(action.skill, action.succeeded)

#endregion


#region Skill

## Buto Kuning: damage biasa ke hero, lalu memancarkan overcharge_drain_requested
## supaya PlayerState menguras Moxie di atas 100%. Moxie di bawah 100% aman.
## Mengembalikan damage yang masuk.
func draining_strike(hero_health: HealthComponent) -> int:
	var dealt := hero_health.take_damage(attack_power)
	if murka and _player != null:
		_player.drain_moxie(murka_drain)
	else:
		overcharge_drain_requested.emit(overcharge_drain)
	return dealt


## Sirep (Buto Putih): menyirep `sirep_count` kartu berbintang tertinggi yang
## belum tersirep selama lock_duration_turns giliran pemain. Kartu tersirep
## tidak bisa dimainkan, digeser, maupun digabung. Mengembalikan index kartu
## pertama yang disirep, atau -1 kalau tidak ada kartu yang bisa disirep.
func lock_card(hand: HandManager) -> int:
	var locked := lock_cards(hand)
	return locked[0] if not locked.is_empty() else -1


## Seperti lock_card(), tapi mengembalikan semua index yang disirep.
func lock_cards(hand: HandManager) -> Array[int]:
	return hand.lock_strongest_cards(_rng, sirep_count, lock_duration_turns)


#endregion


#region Helper

# Skill apa yang dipakai kalau Buto beraksi sekarang. Murni membaca state.
func _pick_skill(battle: BattleManager, skill_ready: bool) -> Skill:
	match buto_type:
		ButoType.KUNING:
			return Skill.DRAINING_STRIKE
		ButoType.HIJAU:
			if skill_ready:
				return Skill.POISON_SPIT
		ButoType.MERAH:
			var charge_step := 0 if murka else 1
			if _merah_step == charge_step:
				return Skill.CHARGE
			if _merah_step == charge_step + 1:
				return Skill.HEAVY_STRIKE
		ButoType.PUTIH:
			# Tangan kosong (misalnya mode buang-tangan gaya FGO) tetap boleh:
			# kuncinya dipasang ke tangan baru di awal turn pemain berikutnya.
			var hand_empty := battle.hand.get_card_count() == 0
			if skill_ready and (hand_empty or battle.hand.has_lockable_card()):
				return Skill.LOCK_CARD
		ButoType.HITAM:
			return _hitam_next_skill()
	return Skill.NONE


# Langkah Buto Hitam berikutnya. Murni membaca state.
func _hitam_next_skill() -> Skill:
	if _staggered:
		return Skill.STAGGER
	if _ajian_charged:
		return Skill.AJIAN
	if phase >= 2 and not _bala_summoned:
		return Skill.SUMMON_BALA
	match _hitam_step:
		0:
			return Skill.PLAGUE_STRIKE
		2:
			return Skill.AJIAN_CHARGE
	return Skill.NONE


func _perform_lock_card(action: ButoSkillAction, battle: BattleManager) -> void:
	if battle.hand.get_card_count() == 0:
		_pending_hand_lock = true
		action.succeeded = true
		return

	var locked := lock_cards(battle.hand)
	if not locked.is_empty():
		for index: int in locked:
			action.locked_cards.append(battle.hand.get_card(index))
		action.locked_card = action.locked_cards[0]
		action.succeeded = true
		return

	# Semua kartu sudah terkunci, misalnya oleh Buto Putih lain di turn yang
	# sama. Daripada membuang giliran, serang biasa dan skill siap lagi di turn
	# berikutnya.
	action.damage_dealt = battle.hero_health.take_damage(attack_power)
	action.succeeded = false
	_turns_until_skill = 0


# Efek samping memilih skill: memulai cooldown dan memajukan pola Buto Merah.
func _after_pick(skill: Skill) -> void:
	if skill == Skill.POISON_SPIT or skill == Skill.LOCK_CARD:
		_start_skill_cooldown()
	if buto_type == ButoType.MERAH:
		_merah_step = (_merah_step + 1) % _merah_cycle()
	if buto_type == ButoType.HITAM:
		match skill:
			Skill.PLAGUE_STRIKE:
				_hitam_step = 1
			Skill.NONE:
				_hitam_step = 2
			Skill.AJIAN_CHARGE:
				# Bar Buyarkan mulai dihitung dari sini; damage di giliran musuh
				# ini tidak ada karena hanya pemain yang melukai Buto Hitam.
				_hitam_step = 0
				_ajian_charged = true
				_ajian_progress = 0
			Skill.AJIAN:
				_ajian_charged = false
			Skill.STAGGER:
				_staggered = false
				_stagger_turn = true
			Skill.SUMMON_BALA:
				_bala_summoned = true


# Semua state pola yang diubah _after_pick(), untuk mengintip niat kedua.
func _save_pattern() -> Array:
	return [_turns_until_skill, _merah_step, _hitam_step, _ajian_charged, _ajian_progress,
		_staggered, _stagger_turn, _bala_summoned]


func _restore_pattern(saved: Array) -> void:
	_turns_until_skill = saved[0]
	_merah_step = saved[1]
	_hitam_step = saved[2]
	_ajian_charged = saved[3]
	_ajian_progress = saved[4]
	_staggered = saved[5]
	_stagger_turn = saved[6]
	_bala_summoned = saved[7]


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


# Damage selama Ajian disiapkan mengisi bar Buyarkan.
func _on_damaged(amount: int) -> void:
	if not _ajian_charged or not is_alive():
		return
	_ajian_progress += amount
	if _ajian_progress >= ajian_break_threshold:
		_break_ajian()
	else:
		ajian_progress_changed.emit(_ajian_progress, ajian_break_threshold)


func _break_ajian() -> void:
	_ajian_charged = false
	_ajian_progress = 0
	_staggered = true
	ajian_progress_changed.emit(-1, ajian_break_threshold)
	ajian_broken.emit()


# Bala lenyap kalau pemanggilnya tumbang.
func _on_died() -> void:
	if _ajian_charged:
		_ajian_charged = false
		ajian_progress_changed.emit(-1, ajian_break_threshold)
	for b: EnemyUnit in get_living_bala():
		b.health.kill()


func _summon_bala(battle: BattleManager) -> Array[EnemyUnit]:
	var colors: Array[ButoType] = [ButoType.KUNING, ButoType.HIJAU, ButoType.MERAH, ButoType.PUTIH]
	for i: int in range(colors.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := colors[i]
		colors[i] = colors[j]
		colors[j] = tmp
	var summoned: Array[EnemyUnit] = []
	for i: int in mini(bala_count, colors.size()):
		var spec := EnemySpec.new()
		spec.buto_type = colors[i]
		spec.max_hp = bala_hp
		spec.attack_power = bala_attack
		spec.bala = true
		spec.sprite_scale = 0.8
		var unit := spec.create_buto()
		unit.rng_seed = _rng.randi_range(1, 1 << 30)
		battle.add_enemy(unit, self)
		unit.health.died.connect(_refresh_bala_shield)
		_bala.append(unit)
		summoned.append(unit)
	_refresh_bala_shield()
	return summoned


func _refresh_bala_shield() -> void:
	var active := not get_living_bala().is_empty() and is_alive()
	health.damage_taken_multiplier = bala_damage_multiplier if active else 1.0
	bala_shield_changed.emit(active)


# Fase dicek setiap HP berubah, jadi phase_changed langsung terpancar saat Buto
# Hitam terkena pukulan yang membawanya ke fase 2.
func _update_phase() -> void:
	if buto_type != ButoType.HITAM or phase >= 2 or not is_alive():
		return
	if health.current_hp <= health.max_hp * phase_two_hp_ratio:
		phase = 2
		can_ngamuk = true
		amuk = 0
		if _player != null:
			_player.poison_decay_paused = true # Pagebluk Merata
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
