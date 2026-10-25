extends SceneTree
## Simulasi keseimbangan: bot memainkan kesepuluh babak berkali-kali dengan
## aturan battle yang asli (BattleManager tanpa jeda animasi), lalu mencetak
## persentase menang, lama battle, dan sisa HP.
##
## Dua gaya bot:
##   cerdas : menggabung kartu, menggeser kartu supaya bisa digabung, memilih
##            kartu sesuai niat Buto, menyimpan Moxie sampai 200%.
##   santai : memainkan kartu dari kiri, hanya menggabung yang kebetulan
##            bersebelahan, langsung memakai Ultimate begitu siap.
##
## Pemakaian: godot --headless -s tools/simulate_balance.gd [-- runs=200]
## Untuk mencoba-coba: hpx=1.5 atkx=1.2 mengalikan HP/serangan semua Buto,
## stages=6,7,9 hanya mensimulasikan babak itu, set=ajian_multiplier:2,bala_count:1
## mengubah properti EnemyButo (yang punya properti itu) sebelum battle.

const MAX_TURNS := 40

var _card_db: Node
var _game_state: Node


func _initialize() -> void:
	_run()


func _arg(name: String, default: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return default


func _run() -> void:
	await process_frame
	_card_db = root.get_node("CardDB")
	_game_state = root.get_node("GameState")
	var runs := int(_arg("runs", "200"))
	var catalog := StageCatalog.load_default()
	for style: String in ["cerdas", "santai"]:
		print("\n=== Bot %s (%d kali per stage) ===" % [style, runs])
		print("stage | menang | turn rata2 | sisa HP rata2 (saat menang)")
		for n: int in range(1, int(_game_state.get("STAGE_COUNT")) + 1):
			if _arg("stages", "") != "" and not _arg("stages", "").split(",").has(str(n)):
				continue
			var stage := catalog.get_stage(n)
			var wins := 0
			var turns := 0
			var hp_left := 0
			for r: int in runs:
				var rng := RandomNumberGenerator.new()
				rng.seed = 1000 * n + r
				# Deck dan HP mengikuti berkah acak dari stage-stage sebelumnya.
				var deck: Array[String] = []
				deck.assign(_game_state.get("STARTER_DECK"))
				var max_hp: int = _game_state.get("BASE_MAX_HP")
				for b: int in n - 1:
					max_hp = _apply_random_blessing(deck, max_hp, rng)
				var result := _battle(stage, deck, max_hp, rng.randi(), style)
				if result.x > 0:
					wins += 1
					hp_left += result.z
				turns += result.y
			print("  %2d  |  %3d%%  |   %5.1f    |   %5.1f" % [n, roundi(100.0 * wins / runs),
				float(turns) / runs, float(hp_left) / maxi(wins, 1)])
	quit(0)


func _apply_random_blessing(deck: Array[String], max_hp: int, rng: RandomNumberGenerator) -> int:
	var choice := rng.randi_range(0, 3)
	if choice == 3:
		return max_hp + 10
	var family: String = ["serang", "fokus", "taktik"][choice]
	for step: int in 2:
		var best := -1
		var best_rank := 3
		for i: int in deck.size():
			var parts := deck[i].split(":")
			if parts[0] == family and int(parts[1]) < best_rank:
				best = i
				best_rank = int(parts[1])
		if best >= 0:
			deck[best] = "%s:%d" % [family, best_rank + 1]
	return max_hp


## Mengembalikan Vector3i(menang 1/0, jumlah turn, sisa HP).
func _battle(stage: StageData, deck_specs: Array[String], max_hp: int, seed_value: int, style: String) -> Vector3i:
	var holder := Node.new()
	var deck := DeckController.new()
	deck.shuffle_seed = seed_value
	var hand := HandManager.new()
	hand.merge_recipes = _card_db.call("get_recipes")
	var player := PlayerState.new()
	var hero := HealthComponent.new()
	hero.max_hp = max_hp
	var bm := BattleManager.new()
	bm.deck = deck
	bm.hand = hand
	bm.player = player
	bm.hero_health = hero
	bm.presentation_delay = 0.0
	for node: Node in [deck, hand, player, hero, bm]:
		holder.add_child(node)
	var enemies: Array[EnemyUnit] = []
	for spec: EnemySpec in stage.enemies:
		var buto := spec.create_buto()
		buto.attack_power = roundi(spec.attack_power * float(_arg("atkx", "1")))
		buto.health.max_hp = roundi(spec.max_hp * float(_arg("hpx", "1")))
		buto.rng_seed = seed_value + enemies.size()
		for pair: String in _arg("set", "").split(",", false):
			var kv := pair.split(":")
			if kv.size() == 2 and kv[0] in buto:
				buto.set(kv[0], str_to_var(kv[1]))
		holder.add_child(buto)
		enemies.append(buto)
	root.add_child(holder)
	bm.start_battle(_card_db.call("build_deck_list", deck_specs), enemies)

	while bm.is_battle_running() and bm.turn_number <= MAX_TURNS:
		if style == "cerdas":
			_smart_turn(bm)
		else:
			_casual_turn(bm)
		if bm.is_battle_running():
			bm.request_end_turn()

	var won := bm.get_state() == BattleManager.State.VICTORY
	var result := Vector3i(1 if won else 0, bm.turn_number, hero.current_hp)
	holder.free()
	return result


#region Bot cerdas

func _smart_turn(bm: BattleManager) -> void:
	var guard := 0
	while bm.is_accepting_input() and guard < 30:
		guard += 1
		_choose_target(bm)
		_merge_all(bm)
		if _try_ultimate(bm, false):
			continue
		if bm.player.current_ap <= 0:
			return
		if bm.player.current_ap >= 2 and _move_for_merge(bm):
			continue
		var best := _best_card(bm)
		if best < 0 or not bm.request_play_card(best):
			return


# Ajian yang sedang disiapkan dibuyarkan lebih dulu, lalu Bala dihabisi
# (selama Bala hidup Buto Hitam hanya menerima separuh damage).
func _choose_target(bm: BattleManager) -> void:
	var living := bm.get_living_enemies()
	for e: EnemyUnit in living:
		var buto := e as EnemyButo
		if buto != null and buto.is_ajian_charged():
			bm.select_target(e)
			return
	var weakest: EnemyUnit = null
	for e: EnemyUnit in living:
		var buto := e as EnemyButo
		if buto != null and buto.is_bala and (weakest == null or e.health.current_hp < weakest.health.current_hp):
			weakest = e
	if weakest != null:
		bm.select_target(weakest)


func _merge_all(bm: BattleManager) -> void:
	var merged := true
	while merged:
		merged = false
		for i: int in bm.hand.get_card_count() - 1:
			if bm.hand.can_merge_at(i, i + 1) and bm.request_merge(i, i + 1):
				merged = true
				break


func _move_for_merge(bm: BattleManager) -> bool:
	var hand := bm.hand
	var count := hand.get_card_count()
	for i: int in count:
		for j: int in count:
			if absi(i - j) < 2 or hand.is_locked_at(i) or hand.is_locked_at(j):
				continue
			var a := hand.get_card(i)
			var b := hand.get_card(j)
			if not a.data.is_base_type() or not b.data.is_base_type():
				continue
			if a.get_rank() != b.get_rank() or a.get_type() == b.get_type():
				continue
			var to := j - 1 if i < j else j + 1
			if hand.can_move_card(i, to) and bm.request_move_card(i, to):
				return true
	return false


func _incoming_damage(bm: BattleManager) -> int:
	var total := 0
	for e: EnemyUnit in bm.get_living_enemies():
		for intent: EnemyIntent in e.get_intents(bm):
			if intent != null and intent.kind != EnemyIntent.Kind.CHARGE and intent.kind != EnemyIntent.Kind.LOCK:
				total += intent.damage
	return total + bm.player.poison


func _try_ultimate(bm: BattleManager, eager: bool) -> bool:
	var player := bm.player
	if not player.is_ultimate_ready():
		return false
	var dmg := roundi(bm.ultimate_base_damage * player.ultimate_damage_multiplier * player.moxie / 100.0)
	var total_hp := 0
	for e: EnemyUnit in bm.get_living_enemies():
		total_hp += e.health.current_hp
	var lethal := true
	for e: EnemyUnit in bm.get_living_enemies():
		if e.health.current_hp > dmg:
			lethal = false
	var danger := bm.hero_health.current_hp <= _incoming_damage(bm) + 5
	# Gebrakan membuyarkan amukan: layak dipakai kalau Ngamuk akan sakit.
	var calm := false
	for e: EnemyUnit in bm.get_living_enemies():
		if e.get_action_count() >= 2 and _incoming_damage(bm) >= bm.hero_health.current_hp * 0.3:
			calm = true
	# Ajian yang tidak bisa dibuyarkan dengan kartu: buyarkan dengan Gebrakan.
	var ajian := false
	for e: EnemyUnit in bm.get_living_enemies():
		var buto := e as EnemyButo
		if buto != null and buto.is_ajian_charged() and bm.player.current_ap <= 1:
			ajian = true
	if eager or player.moxie >= PlayerState.MOXIE_MAX or lethal or danger or calm or ajian:
		return bm.request_ultimate()
	return false


func _best_card(bm: BattleManager) -> int:
	var hand := bm.hand
	var target := bm.get_target()
	var need := maxi(0, _incoming_damage(bm) - bm.hero_health.block)
	var enemy_count := bm.get_living_enemies().size()
	var best := -1
	var best_score := -INF
	for i: int in hand.get_card_count():
		var card := hand.get_card(i)
		if card.is_locked():
			continue # tersirep, tidak bisa dimainkan
		var data := card.data
		var score := float(data.base_power)
		if target != null and data.base_power >= target.health.current_hp:
			score += 8.0
		score += 1.1 * mini(bm.player.get_card_shield(card), need)
		score += 0.3 * enemy_count * bm.player.get_moxie_gain_from_card(card) * (1.0 if bm.player.moxie < PlayerState.MOXIE_MAX else 0.0)
		score += 6.0 * data.ap_gain
		if score > best_score:
			best_score = score
			best = i
	return best

#endregion


#region Bot santai

func _casual_turn(bm: BattleManager) -> void:
	var guard := 0
	while bm.is_accepting_input() and guard < 30:
		guard += 1
		for i: int in bm.hand.get_card_count() - 1:
			if bm.hand.can_merge_at(i, i + 1):
				bm.request_merge(i, i + 1)
				break
		if _try_ultimate(bm, true):
			continue
		if bm.player.current_ap <= 0 or bm.hand.get_card_count() == 0:
			return
		var first_free := -1
		for i: int in bm.hand.get_card_count():
			if bm.hand.can_play_at(i):
				first_free = i
				break
		if first_free < 0 or not bm.request_play_card(first_free):
			return

#endregion
