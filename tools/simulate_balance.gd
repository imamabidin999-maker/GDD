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
##
## noevents=1 mematikan kejadian di perjalanan, notabuh=1 mengeluarkan kartu
## Tabuh dari undian berkah.
##
## mode=ruwatan levels=1,4,7,10 mensimulasikan Ruwatan utuh (8 langkah, Nyawa
## terbawa, berkah dan kejadian dipilih acak) di Tingkat Pagebluk itu.

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
	if _arg("mode", "") == "ruwatan":
		_run_ruwatan(runs)
		quit(0)
		return
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
				# Deck, Nyawa, dan berkah mengikuti berkah acak dari babak-babak
				# sebelumnya (satu berkah untuk setiap kemenangan pertama) dan
				# kejadian di perjalanan setelah babak 2, 4, 6, dan 8.
				var profile := _story_profile(n, rng)
				var deck := profile.deck
				var max_hp := profile.max_hp
				var owned := profile.blessings
				var result := _battle(stage, deck, max_hp, owned, rng.randi(), style)
				if result.x > 0:
					wins += 1
					hp_left += result.z
				turns += result.y
			print("  %2d  |  %3d%%  |   %5.1f    |   %5.1f" % [n, roundi(100.0 * wins / runs),
				float(turns) / runs, float(hp_left) / maxi(wins, 1)])
	quit(0)


# Profil pemain sebelum babak `n`. RuwatanRun dipakai sekadar wadah deck,
# berkah, dan Nyawa karena antarmukanya sama dengan GameState. Berkah dan
# kejadian dipilih acak (pemain tidak selalu memilih yang terbaik).
func _story_profile(n: int, rng: RandomNumberGenerator) -> RuwatanRun:
	var starter: Array[String] = []
	starter.assign(_game_state.get("STARTER_DECK"))
	var excluded: Array = [Blessings.Kind.TABUH_KENONG]
	if _arg("notabuh", "0") == "1":
		excluded.append_array(Blessings.TABUH_FAMILY.keys())
	var profile := RuwatanRun.create(1, 0, starter, excluded)
	var seen: Array[String] = []
	for stage: int in range(1, n):
		_sim_blessing(profile, rng)
		if _arg("noevents", "0") != "1" and (_game_state.get("EVENT_STAGES") as Array).has(stage):
			var id := JourneyEvents.pick(rng, seen)
			seen.append(id)
			_sim_event(profile, id, rng)
	return profile


# Kartu yang diganti kartu Tabuh: bintang terendah dari tipe dasar yang
# paling banyak di deck (seperti pilihan pemain yang wajar).
func _replace_index(deck: Array[String]) -> int:
	var counts := {}
	for spec: String in deck:
		var fam := spec.get_slice(":", 0)
		counts[fam] = int(counts.get(fam, 0)) + 1
	var best := 0
	var best_key := Vector2i(99, 0)
	for i: int in deck.size():
		var fam := deck[i].get_slice(":", 0)
		if Blessings.is_tabuh_spec(deck[i]):
			continue
		var key := Vector2i(int(deck[i].get_slice(":", 1)), -int(counts[fam]))
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best_key = key
			best = i
	return best


## Mengembalikan Vector3i(menang 1/0, jumlah turn, sisa HP). Untuk Ruwatan,
## `run` memasang Tingkat Pagebluk dan `start_hp` adalah Nyawa yang terbawa.
func _battle(stage: StageData, deck_specs: Array[String], max_hp: int, owned: Array[String], seed_value: int, style: String,
		start_hp: int = -1, run: RuwatanRun = null) -> Vector3i:
	var holder := Node.new()
	var deck := DeckController.new()
	deck.shuffle_seed = seed_value
	var hand := HandManager.new()
	hand.merge_recipes = _card_db.call("get_recipes")
	var player := PlayerState.new()
	var hero := HealthComponent.new()
	hero.max_hp = max_hp
	if start_hp > 0:
		hero.reset(start_hp)
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
		if run != null:
			run.modify_buto(buto)
		for pair: String in _arg("set", "").split(",", false):
			var kv := pair.split(":")
			if kv.size() == 2 and kv[0] in buto:
				buto.set(kv[0], str_to_var(kv[1]))
		holder.add_child(buto)
		enemies.append(buto)
	root.add_child(holder)
	Blessings.prepare_player(player, owned)
	if run != null:
		player.start_poison = run.start_poison()
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


#region Ruwatan

func _run_ruwatan(runs: int) -> void:
	var starter: Array[String] = []
	starter.assign(_game_state.get("STARTER_DECK"))
	for style: String in ["cerdas", "santai"]:
		print("\n=== Ruwatan, bot %s (%d kali per tingkat) ===" % [style, runs])
		print("tingkat | berhasil | langkah rata2 | gugur di langkah 1..8")
		for level_text: String in _arg("levels", "1,3,5,7,10").split(","):
			var level := int(level_text)
			var wins := 0
			var steps := 0
			var died: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
			for r: int in runs:
				var rng := RandomNumberGenerator.new()
				rng.seed = 7000 * level + r
				var run := RuwatanRun.create(level, rng.randi(), starter, [Blessings.Kind.TABUH_KENONG])
				while not run.is_over():
					if run.current_step() == RuwatanRun.Step.EVENT:
						_sim_event(run, run.current_event(), rng)
						run.finish_event()
						continue
					var result := _battle(run.build_stage(), run.deck, run.max_hp, run.blessings, rng.randi(), style, run.hp, run)
					if result.x == 0:
						died[run.step] += 1
						run.lose_battle()
					else:
						run.win_battle(result.z)
						if not run.is_over():
							_sim_blessing(run, rng)
							run.finish_blessing()
				steps += run.steps_cleared()
				if run.state == RuwatanRun.State.WON:
					wins += 1
			print("   %2d   |  %3d%%    |     %4.1f      | %s" % [level, roundi(100.0 * wins / runs), float(steps) / runs, str(died)])


# Berkah acak dari pilihan yang ditawarkan, seperti di mode cerita.
func _sim_blessing(run: RuwatanRun, rng: RandomNumberGenerator) -> void:
	var options := run.roll_blessings(rng)
	if options.is_empty():
		return
	var kind: Blessings.Kind = options[rng.randi_range(0, options.size() - 1)]
	run.apply_blessing(kind)
	if Blessings.TABUH_FAMILY.has(kind):
		run.place_tabuh(_replace_index(run.deck), Blessings.TABUH_FAMILY[kind])


# Pilihan kejadian acak. Pemilih kartu: Tabuh menggantikan kartu terlemah,
# tempa menaikkan kartu terendah.
func _sim_event(run: RuwatanRun, event_id: String, rng: RandomNumberGenerator) -> void:
	var choice := "a" if rng.randf() < 0.5 else "b"
	for effect: String in JourneyEvents.effects_of(event_id, choice):
		if effect.begins_with("tabuh:"):
			run.place_tabuh(_replace_index(run.deck), effect.get_slice(":", 1))
		elif effect == "upgrade_pick":
			var best := -1
			for i: int in run.deck.size():
				var rank := int(run.deck[i].get_slice(":", 1))
				if rank < Blessings.MAX_RANK and (best < 0 or rank < int(run.deck[best].get_slice(":", 1))):
					best = i
			run.upgrade_card(best)
		else:
			JourneyEvents.apply(effect, run, rng)

#endregion


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
			if not a.data.is_base_type() or not b.data.is_base_type() or a.data.is_tabuh() or b.data.is_tabuh():
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
		if card.is_locked() or card.data.ap_cost > bm.player.current_ap:
			continue # tersirep atau Ketukan tidak cukup
		var data := card.data
		var damage := bm.player.get_card_damage(card)
		var score := float(damage * (enemy_count if data.hits_all else 1))
		if target != null and damage >= target.health.current_hp:
			score += 8.0
		score += 1.1 * mini(bm.player.get_card_shield(card), need)
		score += 0.3 * enemy_count * bm.player.get_moxie_gain_from_card(card) * (1.0 if bm.player.moxie < PlayerState.MOXIE_MAX else 0.0)
		score += 6.0 * data.ap_gain
		score += 4.0 * mini(data.draw, hand.get_free_slots() + 1)
		if data.calm_target and target != null:
			score += 12.0 if target.is_ngamuk_ready() else 3.0 * maxi(target.amuk, 0)
		if data.next_boost > 0.0 and bm.player.current_ap >= 2:
			score += data.next_boost * _best_other_damage(bm, i)
		# Gong Beri: serangan yang dicegah (yang belum tertahan Tameng) dan Tameng Buto yang pecah.
		var giris := bm.player.get_card_giris(card)
		if giris > 0.0:
			score += 1.1 * minf(giris * float(_incoming_damage(bm) - bm.player.poison), float(need))
		if data.shatter_block:
			for e: EnemyUnit in bm.get_living_enemies():
				score += 0.4 * e.health.block
		score /= maxf(1.0, float(data.ap_cost))
		if score > best_score:
			best_score = score
			best = i
	return best


func _best_other_damage(bm: BattleManager, skip: int) -> float:
	var best := 0.0
	for i: int in bm.hand.get_card_count():
		var card := bm.hand.get_card(i)
		if i != skip and not card.is_locked() and card.data.next_boost <= 0.0:
			best = maxf(best, float(card.data.base_power + card.data.shield))
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
			if bm.hand.can_play_at(i) and bm.hand.get_card(i).data.ap_cost <= bm.player.current_ap:
				first_free = i
				break
		if first_free < 0 or not bm.request_play_card(first_free):
			return

#endregion
