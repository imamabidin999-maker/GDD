extends SceneTree

var _failures: int = 0
var _checks: int = 0


class Fixture:
	var bm: BattleManager
	var deck: DeckController
	var hand: HandManager
	var player: PlayerState
	var hero: HealthComponent
	var enemies: Array[EnemyUnit] = []
	var deck_list: Array[CardData] = []


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func make_card(id: String, type: CardData.CardType, rank: int, power: int) -> CardData:
	var c := CardData.new()
	c.id = StringName(id)
	c.display_name = id
	c.card_type = type
	c.rank = rank
	c.base_power = power
	return c


func make_recipes() -> Array[MergeRecipe]:
	var S := CardData.CardType.SERANG
	var F := CardData.CardType.FOKUS
	var T := CardData.CardType.TAKTIK
	var out: Array[MergeRecipe] = []
	for pair: Array in [[S, F, "Crimson Focus"], [S, T, "Piercing Strike"], [F, T, "Flow State"]]:
		var r := MergeRecipe.new()
		r.type_a = pair[0]
		r.type_b = pair[1]
		for rank: int in [1, 2, 3]:
			r.results.append(make_card(str(pair[2]), CardData.CardType.HYBRID, rank, 20))
		out.append(r)
	return out


func default_deck() -> Array[CardData]:
	var list: Array[CardData] = []
	for i: int in 5:
		list.append(make_card("Serang", CardData.CardType.SERANG, 1, 10))
		list.append(make_card("Fokus", CardData.CardType.FOKUS, 1, 0))
		list.append(make_card("Taktik", CardData.CardType.TAKTIK, 1, 5))
	return list


func make_buto(type: EnemyButo.ButoType, hp: int, seed: int) -> EnemyButo:
	var b := EnemyButo.new()
	b.buto_type = type
	b.rng_seed = seed
	b.attack_power = 10
	b.phase_two_attack_bonus = 0 # angka serangan di tes ini mengasumsikan tanpa bonus murka
	var h := HealthComponent.new()
	h.max_hp = hp
	b.add_child(h)
	b.health = h
	return b


func make_fixture(butos: Array[EnemyUnit], hero_hp: int) -> Fixture:
	var f := Fixture.new()
	var holder := Node.new()
	f.deck = DeckController.new()
	f.deck.shuffle_seed = 11
	f.hand = HandManager.new()
	f.hand.merge_recipes = make_recipes()
	f.player = PlayerState.new()
	f.hero = HealthComponent.new()
	f.hero.max_hp = hero_hp
	f.bm = BattleManager.new()
	f.bm.deck = f.deck
	f.bm.hand = f.hand
	f.bm.player = f.player
	f.bm.hero_health = f.hero
	f.bm.presentation_delay = 0.0
	for n: Node in [f.deck, f.hand, f.player, f.hero, f.bm]:
		holder.add_child(n)
	for b: EnemyUnit in butos:
		holder.add_child(b)
		f.enemies.append(b)
	root.add_child(holder)
	f.deck_list = default_deck()
	return f


func locked_indices(hand: HandManager) -> Array[int]:
	var out: Array[int] = []
	for i: int in hand.get_card_count():
		if hand.is_locked_at(i):
			out.append(i)
	return out


func uids(cards: Array[CardInstance]) -> Array[int]:
	var out: Array[int] = []
	for c: CardInstance in cards:
		out.append(c.uid)
	return out


func sorted_copy(values: Array[int]) -> Array[int]:
	var out: Array[int] = values.duplicate()
	out.sort()
	return out


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("[PlayerState.drain_overcharge]")
	var ps := PlayerState.new()
	root.add_child(ps)
	ps.begin_battle()
	var drained_log: Array[float] = []
	ps.overcharge_drained.connect(func(a: float) -> void: drained_log.append(a))
	ps.gain_moxie(180.0)
	check(is_equal_approx(ps.drain_overcharge(25.0), 25.0) and is_equal_approx(ps.moxie, 155.0), "180 -> 155")
	ps.moxie = 110.0
	check(is_equal_approx(ps.drain_overcharge(25.0), 10.0) and is_equal_approx(ps.moxie, 100.0), "110 -> 100 (tidak turun di bawah 100)")
	ps.moxie = 80.0
	check(ps.drain_overcharge(25.0) == 0.0 and is_equal_approx(ps.moxie, 80.0), "80 tidak berubah (bukan overcharge)")
	check(ps.drain_overcharge(-5.0) == 0.0, "nilai negatif diabaikan")
	check(drained_log.size() == 2 and is_equal_approx(drained_log[0], 25.0) and is_equal_approx(drained_log[1], 10.0), "signal overcharge_drained hanya saat ada yang terkuras")

	print("[HandManager: kunci kartu]")
	var hm := HandManager.new()
	hm.merge_recipes = make_recipes()
	root.add_child(hm)
	var S := CardData.CardType.SERANG
	var F := CardData.CardType.FOKUS
	var T := CardData.CardType.TAKTIK
	var c0 := CardInstance.new(make_card("Serang", S, 1, 10))
	var c1 := CardInstance.new(make_card("Fokus", F, 1, 0))
	var c2 := CardInstance.new(make_card("Serang", S, 1, 10))
	var c3 := CardInstance.new(make_card("Taktik", T, 1, 5))
	var c4 := CardInstance.new(make_card("Fokus", F, 1, 0))
	for c: CardInstance in [c0, c1, c2, c3, c4]:
		hm.add_card(c)
	var lock_log: Array[String] = []
	hm.card_lock_changed.connect(func(c: CardInstance, locked: bool) -> void: lock_log.append("%d:%s" % [c.uid, locked]))
	check(hm.lock_card_at(1, 1) and hm.is_locked_at(1) and c1.is_locked(), "lock_card_at(1)")
	check(not hm.can_move_card(1, 3) and not hm.move_card(1, 3), "kartu terkunci tidak bisa digeser")
	check(not hm.can_merge_at(0, 1) and not hm.can_merge_at(1, 2), "kartu terkunci tidak bisa digabung")
	check(hm.merge_with_neighbor(0) == null and hm.get_card_count() == 5, "auto-merge dengan kartu terkunci gagal")
	check(hm.move_card(0, 3) and hm.index_of(c1) == 0 and c1.is_locked(), "kartu lain boleh digeser, kunci ikut kartunya")
	check(hm.lock_card_at(0, 3) and c1.lock_turns == 3, "kunci ulang memperpanjang durasi")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in 3:
		hm.lock_random_card(rng, 1)
	var free_idx := -1
	for i: int in hm.get_card_count():
		if not hm.is_locked_at(i):
			free_idx = i
	check(locked_indices(hm).size() == 4 and hm.lock_random_card(rng, 1) == free_idx, "lock_random_card hanya memilih kartu yang belum terkunci")
	check(hm.lock_random_card(rng, 1) == -1 and not hm.has_lockable_card(), "semua terkunci -> -1")
	hm.tick_card_locks()
	check(locked_indices(hm) == [hm.index_of(c1)] and c1.lock_turns == 2, "tick: kunci 1 turn terbuka, kunci 3 turn sisa 2")
	var removed := hm.remove_card_at(hm.index_of(c1))
	check(removed == c1 and not c1.is_locked(), "kartu yang diangkat dari tangan otomatis terbuka")
	check(lock_log.has("%d:true" % c1.uid) and lock_log.has("%d:false" % c0.uid), "signal card_lock_changed terpancar")

	print("[HandManager: shuffle_cards]")
	var hs := HandManager.new()
	root.add_child(hs)
	var hs_cards: Array[CardInstance] = []
	for i: int in 7:
		var c := CardInstance.new(make_card("K%d" % i, S, 1, 10))
		hs_cards.append(c)
		hs.add_card(c)
	hs.lock_card_at(2, 1)
	hs.lock_card_at(5, 1)
	var before_shuffle := uids(hs.get_cards())
	var srng := RandomNumberGenerator.new()
	srng.seed = 99
	hs.shuffle_cards(srng)
	var after_shuffle := uids(hs.get_cards())
	check(after_shuffle[2] == before_shuffle[2] and after_shuffle[5] == before_shuffle[5], "kartu terkunci tetap di slotnya")
	check(sorted_copy(after_shuffle) == sorted_copy(before_shuffle), "isi tangan tetap sama")
	check(after_shuffle != before_shuffle, "urutan kartu bebas berubah")

	print("[DeckController.shuffle_draw_pile]")
	var dk := DeckController.new()
	dk.shuffle_seed = 4
	root.add_child(dk)
	dk.build_deck(default_deck())
	var dk_hand: Array[CardInstance] = []
	for i: int in 7:
		dk_hand.append(dk.draw_card())
	dk.discard_card(dk_hand[0])
	var shuffled_count: Array[int] = []
	dk.draw_pile_shuffled.connect(func(n: int) -> void: shuffled_count.append(n))
	var draw_before := uids(dk._draw_pile)
	dk.shuffle_draw_pile()
	var draw_after := uids(dk._draw_pile)
	check(sorted_copy(draw_before) == sorted_copy(draw_after) and draw_before != draw_after, "isi draw pile sama, urutan berubah")
	check(dk.get_discard_count() == 1 and shuffled_count == [8], "discard tidak disentuh, signal (8)")

	print("[Buto Kuning: serangan menguras Overcharge]")
	var kuning := make_buto(EnemyButo.ButoType.KUNING, 200, 1)
	var fk := make_fixture([kuning], 100)
	var k_skills: Array[String] = []
	kuning.skill_used.connect(func(s: EnemyButo.Skill, ok: bool) -> void: k_skills.append("%s:%s" % [EnemyButo.Skill.find_key(s), ok]))
	check(kuning.get_type_name() == "Buto Kuning", "nama tipe: %s" % kuning.get_type_name())
	var k_actions: Array[ButoSkillAction] = []
	fk.bm.action_presentation_started.connect(func(a: BattleAction) -> void:
		if a is ButoSkillAction:
			k_actions.append(a as ButoSkillAction))
	fk.bm.start_battle(fk.deck_list, fk.enemies)
	fk.player.gain_moxie(180.0)
	fk.bm.request_end_turn()
	check(k_actions.size() == 1 and k_actions[0].damage_dealt == 10, "ButoSkillAction menyimpan damage serangan Kuning")
	check(fk.hero.current_hp == 90 and is_equal_approx(fk.player.moxie, 155.0), "hero -10 dan Moxie 180 -> 155")
	check(k_skills == ["DRAINING_STRIKE:true"], "skill_used(DRAINING_STRIKE)")
	fk.player.moxie = 90.0
	fk.bm.request_end_turn()
	check(fk.hero.current_hp == 80 and is_equal_approx(fk.player.moxie, 90.0), "Moxie di bawah 100 aman, serangan tetap masuk")
	kuning.on_battle_started(fk.bm)
	kuning.on_battle_started(fk.bm)
	check(kuning.overcharge_drain_requested.get_connections().size() == 1, "on_battle_started berulang tidak menyambung dobel")
	var other_ps := PlayerState.new()
	root.add_child(other_ps)
	fk.bm.player = other_ps
	kuning.on_battle_started(fk.bm)
	other_ps.begin_battle()
	other_ps.gain_moxie(150.0)
	fk.player.moxie = 150.0
	kuning.draining_strike(fk.hero)
	check(is_equal_approx(other_ps.moxie, 125.0) and is_equal_approx(fk.player.moxie, 150.0), "pindah ke PlayerState baru, sambungan lama dilepas")
	fk.bm.player = fk.player

	print("[Buto Putih: Sirep + cooldown 2]")
	var putih := make_buto(EnemyButo.ButoType.PUTIH, 300, 5)
	putih.skill_cooldown_turns = 2
	var fp := make_fixture([putih], 100)
	var p_actions: Array[ButoSkillAction] = []
	fp.bm.action_presentation_started.connect(func(a: BattleAction) -> void:
		if a is ButoSkillAction:
			p_actions.append(a as ButoSkillAction))
	fp.bm.start_battle(fp.deck_list, fp.enemies)
	fp.bm.request_end_turn() # musuh turn 1: LockCard
	check(p_actions.size() == 1 and p_actions[0].locked_card != null and p_actions[0].locked_card.is_locked(), "ButoSkillAction menyimpan kartu yang dikunci")
	var locks := locked_indices(fp.hand)
	check(locks.size() == 1 and fp.hero.current_hp == 100, "turn 2: 1 kartu terkunci, hero tidak diserang")
	var li := locks[0]
	var other := 0 if li != 0 else 1
	check(not fp.bm.request_move_card(li, other) and fp.player.current_ap == 4, "geser kartu terkunci ditolak tanpa memotong AP")
	var neighbor := li - 1 if li > 0 else li + 1
	check(not fp.bm.request_merge(li, neighbor), "merge kartu terkunci ditolak")
	var locked_card := fp.hand.get_card(li)
	check(fp.bm.request_move_card(other, fp.hand.get_card_count() - 1) and locked_card.is_locked(), "kartu lain tetap bisa digeser (1 AP)")
	fp.bm.request_end_turn() # tick -> terbuka; musuh turn 2: cooldown -> serang
	check(locked_indices(fp.hand).is_empty() and fp.hero.current_hp == 90, "turn 3: kunci terbuka, Buto Putih menyerang biasa")
	fp.bm.request_end_turn() # musuh turn 3: LockCard lagi
	check(locked_indices(fp.hand).size() == 1 and fp.hero.current_hp == 90, "turn 4: LockCard lagi")
	var li2 := locked_indices(fp.hand)[0]
	var lc2 := fp.hand.get_card(li2)
	var ap_before := fp.player.current_ap
	check(not fp.bm.request_play_card(li2) and lc2.is_locked() and fp.player.current_ap == ap_before, "kartu tersirep tidak bisa dimainkan, AP utuh")
	var best_rank := 0
	for c: CardInstance in fp.hand.get_cards():
		best_rank = maxi(best_rank, c.get_rank())
	check(lc2.get_rank() == best_rank, "Sirep menyasar kartu berbintang tertinggi")
	check(fp.deck.verify_integrity(fp.hand.get_cards()), "integritas 15 kartu")

	print("[Sirep: kartu terkuat, Putih Murka 2 kartu]")
	var hk := HandManager.new()
	root.add_child(hk)
	var ranks: Array[int] = [1, 3, 2, 3, 1, 2]
	var hk_cards: Array[CardInstance] = []
	for r: int in ranks:
		var card_data := make_card("S%d" % r, S, r, 5 * r)
		var ci := CardInstance.new(card_data)
		hk_cards.append(ci)
		hk.add_card(ci)
	var krng := RandomNumberGenerator.new()
	krng.seed = 4
	var first := hk.lock_strongest_cards(krng, 1, 1)
	check(first.size() == 1 and hk.get_card(first[0]).get_rank() == 3, "satu sirep -> kartu bintang 3")
	var second := hk.lock_strongest_cards(krng, 2, 1)
	var second_ranks: Array[int] = []
	for idx: int in second:
		second_ranks.append(hk.get_card(idx).get_rank())
	second_ranks.sort()
	check(second_ranks == [2, 3], "dua sirep berikutnya -> bintang 3 sisa lalu bintang 2")
	check(not hk.can_play_at(first[0]) and hk.can_play_at(0), "can_play_at menolak kartu tersirep")
	var putih_murka := make_buto(EnemyButo.ButoType.PUTIH, 300, 5)
	putih_murka.sirep_count = 2
	var fpm := make_fixture([putih_murka], 100)
	fpm.bm.start_battle(fpm.deck_list, fpm.enemies)
	check(putih_murka.get_intent(fpm.bm).kind == EnemyIntent.Kind.LOCK and putih_murka.get_intent(fpm.bm).extra == 2, "niat Putih Murka: sirep 2 kartu")
	fpm.bm.request_end_turn()
	check(locked_indices(fpm.hand).size() == 2, "Putih Murka menyirep 2 kartu")

	print("[Buto Hitam: fase 2 + ForceShuffle]")
	var hitam := make_buto(EnemyButo.ButoType.HITAM, 100, 8)
	var fh := make_fixture([hitam], 200)
	var phases: Array[int] = []
	hitam.phase_changed.connect(func(p: int) -> void: phases.append(p))
	var h_skills: Array[String] = []
	var snapshot_hand: Array[int] = []
	var snapshot_draw: Array[int] = []
	hitam.skill_used.connect(func(s: EnemyButo.Skill, ok: bool) -> void:
		h_skills.append("%s:%s" % [EnemyButo.Skill.find_key(s), ok])
		snapshot_hand.assign(uids(fh.hand.get_cards()))
		snapshot_draw.assign(uids(fh.deck._draw_pile)))
	fh.bm.start_battle(fh.deck_list, fh.enemies)
	fh.bm.request_end_turn()
	check(hitam.phase == 1 and fh.hero.current_hp == 190 and h_skills.is_empty(), "fase 1: serangan biasa")
	hitam.health.take_damage(49)
	check(hitam.phase == 1 and phases.is_empty(), "HP 51% -> masih fase 1")
	hitam.health.take_damage(1)
	check(hitam.phase == 2 and phases == [2], "HP 50% -> phase_changed(2) langsung saat terkena pukulan")
	var hand_before := uids(fh.hand.get_cards())
	var draw_before_h := uids(fh.deck._draw_pile)
	fh.bm.request_end_turn()
	check(h_skills == ["FORCE_SHUFFLE:true"] and fh.hero.current_hp == 180, "ForceShuffle: menghantam (-10) lalu mengacak")
	check(sorted_copy(snapshot_hand) == sorted_copy(hand_before) and snapshot_hand != hand_before, "urutan tangan teracak, isinya sama")
	check(sorted_copy(snapshot_draw) == sorted_copy(draw_before_h) and snapshot_draw != draw_before_h, "sisa draw pile teracak, isinya sama")
	fh.bm.request_end_turn()
	check(h_skills.size() == 1 and fh.hero.current_hp == 170, "cooldown: turn berikutnya serangan biasa")
	fh.bm.request_end_turn()
	check(h_skills.size() == 2, "lalu ForceShuffle lagi")
	hitam.health.take_damage(10)
	check(phases == [2], "fase 2 tidak terpicu ulang")
	check(fh.deck.verify_integrity(fh.hand.get_cards()), "integritas 15 kartu")

	print("[Putih + Hitam: kartu terkunci tidak ikut teracak]")
	var p2 := make_buto(EnemyButo.ButoType.PUTIH, 300, 21)
	p2.skill_cooldown_turns = 1
	var h2 := make_buto(EnemyButo.ButoType.HITAM, 100, 22)
	var fc := make_fixture([p2, h2], 300)
	var lock_snapshot: Array[int] = [-1, -1]
	var lock_held: Array[bool] = []
	p2.skill_used.connect(func(_s: EnemyButo.Skill, _ok: bool) -> void:
		var idx := locked_indices(fc.hand)
		lock_snapshot[0] = idx[0] if not idx.is_empty() else -1
		lock_snapshot[1] = fc.hand.get_card(lock_snapshot[0]).uid if lock_snapshot[0] >= 0 else -1)
	h2.skill_used.connect(func(_s: EnemyButo.Skill, _ok: bool) -> void:
		lock_held.append(lock_snapshot[0] >= 0 and fc.hand.get_card(lock_snapshot[0]).uid == lock_snapshot[1]))
	fc.bm.start_battle(fc.deck_list, fc.enemies)
	h2.health.take_damage(50)
	fc.bm.request_end_turn()
	check(lock_snapshot[0] >= 0 and lock_held == [true], "ForceShuffle tidak memindahkan kartu yang dikunci LockCard")

	print("[Signal kunci untuk UI]")
	var hu := HandManager.new()
	root.add_child(hu)
	var u0 := CardInstance.new(make_card("A", S, 1, 10))
	var u1 := CardInstance.new(make_card("B", F, 1, 0))
	hu.add_card(u0)
	hu.add_card(u1)
	hu.lock_card_at(0, 2)
	var hu_changes: Array[int] = [0]
	var hu_locks: Array[String] = []
	hu.hand_changed.connect(func() -> void: hu_changes[0] += 1)
	hu.card_lock_changed.connect(func(c: CardInstance, locked: bool) -> void: hu_locks.append("%d:%s" % [c.uid, locked]))
	hu.tick_card_locks()
	check(u0.lock_turns == 1 and hu_changes[0] == 1 and hu_locks.is_empty(), "tick 2 -> 1 memancarkan hand_changed")
	hu.remove_card_at(0)
	check(hu_locks == ["%d:false" % u0.uid], "kartu terkunci yang diangkat memancarkan card_lock_changed(false)")

	print("[Dua Buto Putih, kartu bebas tinggal 1]")
	var pa := make_buto(EnemyButo.ButoType.PUTIH, 300, 31)
	var pb := make_buto(EnemyButo.ButoType.PUTIH, 300, 32)
	var fm := make_fixture([pa, pb], 100)
	var pb_log: Array[String] = []
	pb.skill_used.connect(func(sk: EnemyButo.Skill, ok: bool) -> void: pb_log.append("%s:%s" % [EnemyButo.Skill.find_key(sk), ok]))
	fm.bm.start_battle(fm.deck_list, fm.enemies)
	for i: int in range(1, fm.hand.get_card_count()):
		fm.hand.lock_card_at(i, 2)
	fm.bm.request_end_turn()
	check(pb_log == ["LOCK_CARD:false"] and fm.hero.current_hp == 90, "Putih kedua tidak membuang giliran: menyerang (-10)")
	check(fm.hand.count_unlocked() == 0, "Putih pertama mengunci kartu bebas terakhir")
	fm.bm.request_end_turn()
	check(pb_log.size() == 2 and pb_log[1] == "LOCK_CARD:true", "cooldown Putih kedua tidak terpakai: turn berikutnya LockCard lagi")

	print("[Mode buang tangan (gaya FGO)]")
	var pf := make_buto(EnemyButo.ButoType.PUTIH, 300, 41)
	var ff := make_fixture([pf], 100)
	ff.bm.discard_hand_on_turn_end = true
	var pf_actions: Array[ButoSkillAction] = []
	ff.bm.action_presentation_started.connect(func(a: BattleAction) -> void:
		if a is ButoSkillAction:
			pf_actions.append(a as ButoSkillAction))
	ff.bm.start_battle(ff.deck_list, ff.enemies)
	ff.bm.request_end_turn()
	check(pf_actions.size() == 1 and pf_actions[0].succeeded and pf_actions[0].locked_card == null, "Putih: tangan kosong -> kunci ditunda")
	check(locked_indices(ff.hand).size() == 1 and ff.hand.get_card_count() == 7 and ff.hero.current_hp == 100, "kunci terpasang ke tangan baru di awal turn 2")
	ff.bm.request_end_turn()
	check(ff.hero.current_hp == 90 and locked_indices(ff.hand).is_empty(), "turn berikutnya: cooldown -> serang, tangan baru tanpa kunci")
	check(ff.deck.verify_integrity(ff.hand.get_cards()), "integritas 15 kartu (mode FGO)")
	var hf := make_buto(EnemyButo.ButoType.HITAM, 100, 42)
	var fhf := make_fixture([hf], 100)
	fhf.bm.discard_hand_on_turn_end = true
	var hf_log: Array[int] = [0]
	hf.skill_used.connect(func(_sk: EnemyButo.Skill, _ok: bool) -> void: hf_log[0] += 1)
	fhf.bm.start_battle(fhf.deck_list, fhf.enemies)
	hf.health.take_damage(60)
	fhf.bm.request_end_turn()
	fhf.bm.request_end_turn()
	check(hf.phase == 2 and hf_log[0] == 0 and fhf.hero.current_hp == 80, "Hitam: tangan kosong -> tidak ForceShuffle, tetap menyerang")

	print("[Hitam: ForceShuffle butuh minimal 2 kartu bebas]")
	var hp2 := make_buto(EnemyButo.ButoType.HITAM, 100, 51)
	var fp2 := make_fixture([hp2], 100)
	var hp2_log: Array[int] = [0]
	hp2.skill_used.connect(func(_sk: EnemyButo.Skill, _ok: bool) -> void: hp2_log[0] += 1)
	fp2.bm.start_battle(fp2.deck_list, fp2.enemies)
	hp2.health.take_damage(60)
	for i: int in range(1, fp2.hand.get_card_count()):
		fp2.hand.lock_card_at(i, 2)
	fp2.bm.request_end_turn()
	check(hp2_log[0] == 0 and fp2.hero.current_hp == 90, "1 kartu bebas -> serang biasa")
	fp2.bm.request_end_turn()
	check(hp2_log[0] == 1 and fp2.hero.current_hp == 80, "cooldown tidak terbuang: turn berikutnya ForceShuffle (+hantaman)")

	print("[Fase Hitam saat battle diulang]")
	var hr := make_buto(EnemyButo.ButoType.HITAM, 100, 61)
	var fr := make_fixture([hr], 100)
	var hr_phases: Array[int] = []
	hr.phase_changed.connect(func(ph: int) -> void: hr_phases.append(ph))
	fr.bm.start_battle(fr.deck_list, fr.enemies)
	hr.health.take_damage(70)
	check(hr.phase == 2 and hr_phases == [2], "fase 2")
	hr.on_battle_started(fr.bm)
	check(hr.phase == 1 and hr_phases == [2, 1], "on_battle_started: kembali ke fase 1 dan memberi tahu listener")
	hr.health.reset()
	check(hr.phase == 1, "HP diisi setelahnya -> tetap fase 1")
	hr.health.take_damage(60)
	check(hr.phase == 2 and hr_phases == [2, 1, 2], "fase 2 bisa terpicu lagi di battle baru")

	print("[Merah: langkah pertama serangan biasa]")
	var merah0 := make_buto(EnemyButo.ButoType.MERAH, 50, 1)
	var fg := make_fixture([merah0], 100)
	fg.bm.start_battle(fg.deck_list, fg.enemies)
	check(merah0.decide_action(fg.bm) is EnemyAttackAction, "decide_action -> EnemyAttackAction")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
