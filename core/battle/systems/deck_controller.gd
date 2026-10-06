class_name DeckController
extends Node
## Mengelola tumpukan kartu selama SATU battle: draw pile dan discard pile.
##
## Daftar 15 kartu milik pemain (deck sebagai koleksi) disimpan di GameState.
## Node ini hanya mengurus deck sebagai tumpukan, dan ikut hilang saat
## BattleScene ditutup.
##
## Konvensi: kartu teratas draw pile adalah elemen TERAKHIR array, supaya
## menarik kartu cukup dengan pop_back() yang O(1).

signal deck_built(card_count: int)
signal card_drawn(card: CardInstance)
signal deck_reshuffled(card_count: int)
signal piles_changed(draw_count: int, discard_count: int)

const DECK_SIZE: int = 15

## Seed pengocokan. 0 berarti acak setiap battle. Isi angka tetap saat debugging
## atau replay supaya urutan kartu selalu sama.
@export var shuffle_seed: int = 0

var _draw_pile: Array[CardInstance] = []
var _discard_pile: Array[CardInstance] = []
var _rng := RandomNumberGenerator.new()


#region Setup

## Menyiapkan deck untuk battle baru dari daftar 15 CardData.
## Mengembalikan false (dan deck tidak berubah) kalau daftarnya tidak valid.
func build_deck(card_list: Array[CardData]) -> bool:
	if not _is_valid_card_list(card_list):
		return false

	# Seed dipasang di sini, bukan di _ready(), supaya tiap battle dengan seed
	# yang sama menghasilkan urutan yang sama, kapan pun build_deck() dipanggil.
	if shuffle_seed != 0:
		_rng.seed = shuffle_seed
	else:
		_rng.randomize()

	_draw_pile.clear()
	_discard_pile.clear()
	for card_data: CardData in card_list:
		_draw_pile.append(CardInstance.new(card_data))
	_shuffle(_draw_pile)

	deck_built.emit(_draw_pile.size())
	_emit_piles_changed()
	return true


func _is_valid_card_list(card_list: Array[CardData]) -> bool:
	if card_list.size() != DECK_SIZE:
		push_error("DeckController: deck harus berisi %d kartu, diterima %d." % [DECK_SIZE, card_list.size()])
		return false
	for card_data: CardData in card_list:
		if card_data == null:
			push_error("DeckController: ada slot kosong (null) di daftar deck.")
			return false
		if not card_data.is_base_type():
			push_error("DeckController: deck awal hanya boleh berisi kartu dasar, '%s' adalah hybrid." % card_data.id)
			return false
	return true

#endregion


#region Draw

## Menarik satu kartu dari atas draw pile.
## Kalau draw pile kosong, discard pile dikocok ulang lebih dulu.
## Mengembalikan null kalau kedua tumpukan kosong (semua kartu sedang di tangan).
func draw_card() -> CardInstance:
	if _draw_pile.is_empty():
		reshuffle_discard_into_draw()
	if _draw_pile.is_empty():
		return null

	var card: CardInstance = _draw_pile.pop_back()
	card_drawn.emit(card)
	_emit_piles_changed()
	return card


## Menarik beberapa kartu langsung ke tangan pemain.
## Berhenti lebih awal kalau tangan penuh atau kartu habis. Kartu tidak pernah
## ditarik kalau tangan sudah penuh, jadi tidak ada kartu yang hilang.
## Mengembalikan daftar kartu yang benar-benar masuk ke tangan.
func draw_cards_into(hand: HandManager, amount: int) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i: int in amount:
		if hand.is_full():
			break
		var card := draw_card()
		if card == null:
			break
		hand.add_card(card)
		drawn.append(card)
	return drawn


## Menarik kartu sampai tangan penuh.
func fill_hand(hand: HandManager) -> Array[CardInstance]:
	return draw_cards_into(hand, hand.get_free_slots())

#endregion


#region Discard & Reshuffle

## Membuang kartu ke discard pile. Kartu hybrid dipecah menjadi kartu-kartu
## dasarnya supaya total kartu dasar di deck tetap 15.
func discard_card(card: CardInstance) -> void:
	if card == null:
		return
	for base_card: CardInstance in card.get_base_cards():
		if _discard_pile.has(base_card):
			push_warning("DeckController: %s sudah ada di discard pile, diabaikan." % base_card)
			continue
		_discard_pile.append(base_card)
	_emit_piles_changed()


func discard_cards(cards: Array[CardInstance]) -> void:
	for card: CardInstance in cards:
		discard_card(card)


## Memindahkan seluruh discard pile ke draw pile lalu mengocoknya.
## Biasanya dipanggil otomatis oleh draw_card(), tapi dibuat public untuk
## efek kartu yang memaksa reshuffle.
func reshuffle_discard_into_draw() -> void:
	if _discard_pile.is_empty():
		return
	_draw_pile.append_array(_discard_pile)
	_discard_pile.clear()
	_shuffle(_draw_pile)
	deck_reshuffled.emit(_draw_pile.size())
	_emit_piles_changed()


## Fisher-Yates shuffle memakai RNG milik node ini (bukan RNG global),
## supaya hasilnya bisa diulang kalau shuffle_seed diisi.
func _shuffle(pile: Array[CardInstance]) -> void:
	for i: int in range(pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := pile[i]
		pile[i] = pile[j]
		pile[j] = temp

#endregion


#region Query

func get_draw_count() -> int:
	return _draw_pile.size()


func get_discard_count() -> int:
	return _discard_pile.size()


## Mengecek invariant: draw + discard + kartu dasar di tangan harus tepat 15.
## Panggil hanya di titik yang stabil (misalnya awal dan akhir turn), bukan saat
## sebuah kartu sedang di-resolve dan belum masuk discard pile.
func verify_integrity(cards_in_hand: Array[CardInstance]) -> bool:
	var total := _draw_pile.size() + _discard_pile.size()
	for card: CardInstance in cards_in_hand:
		total += card.get_base_cards().size()
	if total != DECK_SIZE:
		push_warning("DeckController: total kartu %d, seharusnya %d." % [total, DECK_SIZE])
		return false
	return true


func _emit_piles_changed() -> void:
	piles_changed.emit(_draw_pile.size(), _discard_pile.size())

#endregion
