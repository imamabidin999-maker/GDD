class_name BattleStats
extends RefCounted
## Catatan satu battle untuk menilai tantangan babak (Bintang Dongkrek) dan
## untuk catatan permainan sepanjang masa (PlayRecords).
##
## Pasang dengan attach() sebelum BattleManager.start_battle(). Semua angka
## diisi dari signal, jadi BattleManager tidak perlu tahu soal tantangan.

var won: bool = false
var turns: int = 0
var hp_left: int = 0
var max_hp: int = 1
var ultimates_used: int = 0
var merges: int = 0
var max_poison: int = 0
## Berapa kali kartu kena Sirep (kartu yang sama bisa terhitung lagi).
var sirep_received: int = 0
## Total damage yang ditahan Tameng Eyang Palang.
var block_absorbed: int = 0
## Berapa kali ada Buto yang Ngamuk (beraksi dua kali).
var ngamuk_count: int = 0
## Amukan Buto yang siap Ngamuk yang dibuyarkan (Gebrakan atau Korek).
var calmed_ready: int = 0
var ajian_breaks: int = 0
var tabuh_played: int = 0
## Kunci warna Buto yang pertama tumbang, misalnya "putih".
var first_killed: String = ""
var bala_summoned: int = 0
## Bala yang dikalahkan sebelum Buto Hitam tumbang.
var bala_killed_before_boss: int = 0
## Buto yang dikalahkan: kunci warna, "murka", atau "bala" -> jumlah.
var killed: Dictionary = {}
## Keluarga kartu -> berapa kali dimainkan.
var cards_played: Dictionary = {}
## Damage terbesar dari satu kartu atau satu Sapu Jagad (semua sasaran).
var biggest_hit: int = 0

var _battle: BattleManager
var _bosses: Array[EnemyButo] = []


func attach(battle: BattleManager, enemies: Array[EnemyUnit]) -> void:
	_battle = battle
	max_hp = battle.hero_health.max_hp
	battle.hand.cards_merged.connect(func(_r: CardInstance, _i: int) -> void: merges += 1)
	battle.hand.card_lock_changed.connect(func(_c: CardInstance, locked: bool) -> void:
		if locked:
			sirep_received += 1)
	battle.player.poison_changed.connect(func(stacks: int) -> void: max_poison = maxi(max_poison, stacks))
	battle.hero_health.damage_blocked.connect(func(amount: int) -> void: block_absorbed += amount)
	battle.enemy_ngamuk.connect(func(_e: EnemyUnit) -> void: ngamuk_count += 1)
	battle.action_resolved.connect(_on_action_resolved)
	battle.enemy_spawned.connect(func(e: EnemyUnit, _s: EnemyUnit) -> void: _watch_enemy(e))
	battle.battle_ended.connect(_on_battle_ended)
	for enemy: EnemyUnit in enemies:
		_watch_enemy(enemy)


func hp_ratio() -> float:
	return float(hp_left) / float(maxi(max_hp, 1))


func _watch_enemy(enemy: EnemyUnit) -> void:
	var buto := enemy as EnemyButo
	if buto == null:
		return
	if buto.is_bala:
		bala_summoned += 1
	if buto.buto_type == EnemyButo.ButoType.HITAM:
		_bosses.append(buto)
	buto.ajian_broken.connect(func() -> void: ajian_breaks += 1)
	buto.health.died.connect(func() -> void:
		if first_killed == "":
			first_killed = buto.get_type_key()
		# Bala yang lenyap karena Buto Hitam tumbang tidak dihitung.
		if buto.is_bala and _boss_down():
			return
		if buto.is_bala:
			bala_killed_before_boss += 1
		var key := "bala" if buto.is_bala else ("murka" if buto.murka else buto.get_type_key())
		killed[key] = int(killed.get(key, 0)) + 1)


func _boss_down() -> bool:
	for boss: EnemyButo in _bosses:
		if boss.health.is_dead():
			return true
	return false


func _on_action_resolved(action: BattleAction) -> void:
	if action is UltimateAction:
		ultimates_used += 1
		calmed_ready += (action as UltimateAction).calmed_ready
		biggest_hit = maxi(biggest_hit, (action as UltimateAction).damage_dealt)
	elif action is PlayCardAction:
		var play := action as PlayCardAction
		if play.calmed_ready:
			calmed_ready += 1
		if play.card.data.is_tabuh():
			tabuh_played += 1
		var family := play.card.data.get_family()
		cards_played[family] = int(cards_played.get(family, 0)) + 1
		biggest_hit = maxi(biggest_hit, play.damage_dealt)


func _on_battle_ended(player_won: bool) -> void:
	won = player_won
	turns = _battle.turn_number
	hp_left = _battle.hero_health.current_hp
	max_hp = _battle.hero_health.max_hp
