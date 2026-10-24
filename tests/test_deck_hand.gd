extends SceneTree

var _failures: int = 0
var _checks: int = 0
var _reshuffle_signals: int = 0


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func make_card(id: String, type: CardData.CardType, rank: int) -> CardData:
	var c := CardData.new()
	c.id = StringName(id)
	c.display_name = id
	c.card_type = type
	c.rank = rank
	return c


func make_recipe(a: CardData.CardType, b: CardData.CardType, name: String) -> MergeRecipe:
	var r := MergeRecipe.new()
	r.type_a = a
	r.type_b = b
	for rank: int in [1, 2, 3]:
		r.results.append(make_card("%s" % name, CardData.CardType.HYBRID, rank))
	return r


func _initialize() -> void:
	var S := CardData.CardType.SERANG
	var F := CardData.CardType.FOKUS
	var T := CardData.CardType.TAKTIK

	var serang1 := make_card("Serang", S, 1)
	var serang2 := make_card("Serang", S, 2)
	var fokus1 := make_card("Fokus", F, 1)
	var fokus2 := make_card("Fokus", F, 2)
	var taktik1 := make_card("Taktik", T, 1)
	var taktik2 := make_card("Taktik", T, 2)

	var deck_list: Array[CardData] = []
	for i: int in 3:
		deck_list.append(serang1)
		deck_list.append(fokus1)
		deck_list.append(taktik1)
	for i: int in 2:
		deck_list.append(serang2)
		deck_list.append(fokus2)
		deck_list.append(taktik2)

	var recipes: Array[MergeRecipe] = [
		make_recipe(S, F, "Crimson Focus"),
		make_recipe(S, T, "Piercing Strike"),
		make_recipe(F, T, "Flow State"),
	]

	var deck := DeckController.new()
	deck.shuffle_seed = 1999
	var hand := HandManager.new()
	hand.merge_recipes = recipes
	root.add_child(deck)
	root.add_child(hand)
	deck.deck_reshuffled.connect(func(_n: int) -> void: _reshuffle_signals += 1)

	print("[Build]")
	var short_list: Array[CardData] = deck_list.slice(0, 14)
	check(not deck.build_deck(short_list), "deck 14 kartu ditolak")
	var with_hybrid: Array[CardData] = deck_list.duplicate()
	with_hybrid[0] = recipes[0].results[0]
	check(not deck.build_deck(with_hybrid), "deck berisi kartu hybrid ditolak")
	check(deck.build_deck(deck_list), "deck 15 kartu diterima")
	check(deck.get_draw_count() == 15 and deck.get_discard_count() == 0, "draw 15, discard 0")

	print("[Shuffle deterministik]")
	var d2 := DeckController.new()
	d2.shuffle_seed = 1999
	root.add_child(d2)
	d2.build_deck(deck_list)
	var order_a: Array[String] = []
	var order_b: Array[String] = []
	for i: int in 15:
		order_a.append(str(deck._draw_pile[i].data.id) + str(deck._draw_pile[i].get_rank()))
		order_b.append(str(d2._draw_pile[i].data.id) + str(d2._draw_pile[i].get_rank()))
	check(order_a == order_b, "seed sama -> urutan sama")
	print("    urutan: ", order_a)

	print("[Draw ke tangan]")
	var drawn := deck.fill_hand(hand)
	check(drawn.size() == 7 and hand.get_card_count() == 7, "fill_hand mengisi 7 kartu")
	check(deck.get_draw_count() == 8, "draw pile tersisa 8")
	check(hand.is_full() and deck.draw_cards_into(hand, 3).is_empty(), "tangan penuh -> tidak menarik")
	check(deck.get_draw_count() == 8, "kartu tidak hilang saat tangan penuh")
	check(deck.verify_integrity(hand.get_cards()), "integritas 15 kartu")

	print("[Deteksi merge]")
	# Susun tangan secara manual: [Serang1, Fokus1, Serang1, Serang2, Taktik1, Taktik2]
	deck.discard_cards(hand.take_all_cards())
	var s1a := CardInstance.new(serang1)
	var f1 := CardInstance.new(fokus1)
	var s1b := CardInstance.new(serang1)
	var s2 := CardInstance.new(serang2)
	var t1 := CardInstance.new(taktik1)
	var t2 := CardInstance.new(taktik2)
	for c: CardInstance in [s1a, f1, s1b, s2, t1, t2]:
		hand.add_card(c)
	check(hand.are_adjacent(0, 1), "0 dan 1 bersebelahan")
	check(not hand.are_adjacent(0, 2), "0 dan 2 tidak bersebelahan")
	check(not hand.are_adjacent(5, 6), "index di luar tangan -> false")
	check(hand.has_same_rank(0, 1), "Serang1 & Fokus1 rank sama")
	check(not hand.has_same_rank(2, 3), "Serang1 & Serang2 rank beda")
	check(hand.can_merge_at(0, 1), "Serang1 + Fokus1 bisa merge")
	check(not hand.can_merge_at(0, 2), "tidak bersebelahan -> tidak bisa")
	check(not hand.can_merge_at(3, 4), "rank beda -> tidak bisa")
	check(not hand.can_merge_at(2, 3), "Serang1+Serang2 tidak bisa")

	print("[Eksekusi merge]")
	var merged_signal_index: Array[int] = []
	hand.cards_merged.connect(func(_r: CardInstance, idx: int) -> void: merged_signal_index.append(idx))
	var hybrid := hand.merge_at(1, 0)
	check(hybrid != null and hybrid.data.display_name == "Crimson Focus", "hasil = Crimson Focus")
	check(hybrid.is_hybrid() and hybrid.get_rank() == 1, "hybrid rank 1")
	check(hand.get_card_count() == 5 and hand.get_card(0) == hybrid, "tangan jadi 5, hybrid di index 0")
	check(merged_signal_index == [0], "signal cards_merged index 0")
	check(hand.get_card(1) == s1b, "kartu lain bergeser dengan benar")
	check(not hand.can_merge_at(0, 1), "hybrid tidak bisa merge lagi")
	check(hand.merge_at(0, 1) == null, "merge_at gagal mengembalikan null")

	print("[Geser + auto merge]")
	# Tangan: [Crimson, Serang1, Serang2, Taktik1, Taktik2] -> geser Taktik1 ke index 2
	check(hand.move_card(3, 2), "move 3 -> 2")
	check(hand.get_card(2) == t1 and hand.get_card(3) == s2, "urutan setelah geser benar")
	check(hand.find_merge_partner(2) == 1, "partner Taktik1 = Serang1 di kiri")
	var piercing := hand.merge_with_neighbor(2)
	check(piercing != null and piercing.data.display_name == "Piercing Strike", "auto merge -> Piercing Strike")
	check(hand.get_card_count() == 4, "tangan jadi 4")
	check(not hand.move_card(0, 0) and not hand.move_card(0, 9), "move tidak valid ditolak")

	print("[Discard hybrid & reshuffle]")
	var before := deck.get_discard_count()
	deck.discard_card(hand.remove_card_at(0))
	check(deck.get_discard_count() == before + 2, "hybrid dipecah jadi 2 kartu di discard")
	deck.discard_card(f1)
	check(deck.get_discard_count() == before + 2, "discard ganda diabaikan")
	deck.discard_cards(hand.take_all_cards())
	check(hand.get_card_count() == 0, "tangan kosong")

	# Kartu manual (s1a dkk) di luar 15 kartu asli, jadi buat ulang battle bersih.
	deck.build_deck(deck_list)
	_reshuffle_signals = 0
	var held: Array[CardInstance] = []
	for i: int in 15:
		held.append(deck.draw_card())
	check(deck.get_draw_count() == 0, "draw pile habis setelah 15 draw")
	check(deck.draw_card() == null, "draw saat semua kartu dipegang -> null")
	deck.discard_cards(held.slice(0, 5))
	var again := deck.draw_card()
	check(again != null and _reshuffle_signals == 1, "draw pile kosong -> reshuffle dari discard")
	check(deck.get_draw_count() == 4 and deck.get_discard_count() == 0, "draw 4, discard 0 setelah reshuffle")
	var in_play: Array[CardInstance] = held.slice(5, 15)
	in_play.append(again)
	check(deck.verify_integrity(in_play), "integritas tetap 15")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
