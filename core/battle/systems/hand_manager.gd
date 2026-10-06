class_name HandManager
extends Node
## Mengelola kartu di tangan pemain selama battle.
##
## Isi tangan disimpan sebagai array BERURUTAN: index 0 adalah kartu paling kiri.
## Urutan ini penting karena Hybrid Merging hanya bisa terjadi pada dua kartu
## yang bersebelahan.
##
## Node ini sengaja tidak mengecek AP. Biaya AP dicek BattleManager
## (request_play_card, request_move_card) sebelum fungsi di sini dipanggil.

signal card_added(card: CardInstance, index: int)
signal card_removed(card: CardInstance, index: int)
signal card_moved(card: CardInstance, from_index: int, to_index: int)
## result menempati posisi index. Dua kartu bahannya ada di result.components.
signal cards_merged(result: CardInstance, index: int)
## Kartu terkunci atau terbuka lagi (skill LockCard Buto Putih).
signal card_lock_changed(card: CardInstance, locked: bool)
## Urutan tangan diacak paksa (skill ForceShuffle Buto Hitam).
signal hand_shuffled
## Dipancarkan setelah setiap perubahan. Cocok untuk UI yang cukup menggambar
## ulang seluruh tangan.
signal hand_changed

const NO_PARTNER: int = -1

@export_range(1, 10) var max_hand_size: int = 7
## Daftar resep merge. Nantinya diisi BattleScene dari autoload CardDB.
## Untuk sekarang bisa diisi lewat Inspector supaya HandManager bisa dites sendiri.
@export var merge_recipes: Array[MergeRecipe] = []:
	set(value):
		merge_recipes = value
		_resolver = null # dibuat ulang dengan resep baru saat dibutuhkan

var _cards: Array[CardInstance] = []
var _resolver: MergeResolver


# Resolver dibuat saat pertama kali dipakai, bukan di _ready(), supaya
# HandManager tetap aman dipakai sebelum masuk scene tree.
func _get_resolver() -> MergeResolver:
	if _resolver == null:
		_resolver = MergeResolver.new(merge_recipes)
	return _resolver


#region Query

func get_card_count() -> int:
	return _cards.size()


func is_full() -> bool:
	return _cards.size() >= max_hand_size


func get_free_slots() -> int:
	return maxi(max_hand_size - _cards.size(), 0)


func is_valid_index(index: int) -> bool:
	return index >= 0 and index < _cards.size()


## Mengembalikan kartu di posisi tertentu, atau null kalau index tidak valid.
func get_card(index: int) -> CardInstance:
	if not is_valid_index(index):
		return null
	return _cards[index]


## Salinan isi tangan. Mengubah array hasilnya tidak memengaruhi tangan.
func get_cards() -> Array[CardInstance]:
	return _cards.duplicate()


## Posisi kartu di tangan, atau -1 kalau kartu tidak ada di tangan.
func index_of(card: CardInstance) -> int:
	return _cards.find(card)

#endregion


#region Tambah, ambil, geser

## Menambah kartu di ujung kanan tangan. Gagal kalau tangan penuh atau kartu
## sudah ada di tangan.
func add_card(card: CardInstance) -> bool:
	if card == null or is_full() or _cards.has(card):
		return false
	_cards.append(card)
	card_added.emit(card, _cards.size() - 1)
	hand_changed.emit()
	return true


## Mengangkat kartu dari tangan (misalnya saat dimainkan).
## Mengembalikan null kalau index tidak valid.
func remove_card_at(index: int) -> CardInstance:
	if not is_valid_index(index):
		return null
	var card: CardInstance = _cards.pop_at(index)
	_clear_lock(card) # kunci hanya berlaku selama kartu ada di tangan
	card_removed.emit(card, index)
	hand_changed.emit()
	return card


func remove_card(card: CardInstance) -> bool:
	return remove_card_at(index_of(card)) != null


## Mengosongkan tangan dan mengembalikan semua kartunya, misalnya untuk
## dibuang di akhir turn.
func take_all_cards() -> Array[CardInstance]:
	var taken: Array[CardInstance] = _cards.duplicate()
	_cards.clear()
	for card: CardInstance in taken:
		_clear_lock(card)
	hand_changed.emit()
	return taken


## true kalau kartu di from_index boleh digeser ke to_index: kedua index valid,
## berbeda, dan kartu yang digeser tidak sedang terkunci.
func can_move_card(from_index: int, to_index: int) -> bool:
	if not is_valid_index(from_index) or not is_valid_index(to_index):
		return false
	return from_index != to_index and not _cards[from_index].is_locked()


## Menggeser kartu dari from_index sehingga berakhir di to_index.
## Kartu lain otomatis bergeser mengisi tempat kosong, termasuk kartu yang
## terkunci: kunci melarang kartu itu DIGESER pemain, bukan menahan slotnya.
## Fungsi ini tidak otomatis melakukan merge. BattleManager.request_move_card()
## yang memutuskan apakah merge_with_neighbor() dipanggil setelahnya.
func move_card(from_index: int, to_index: int) -> bool:
	if not can_move_card(from_index, to_index):
		return false
	var card: CardInstance = _cards.pop_at(from_index)
	_cards.insert(to_index, card)
	card_moved.emit(card, from_index, to_index)
	hand_changed.emit()
	return true

#endregion


#region Hybrid Merging

## true kalau kedua index valid dan posisinya bersebelahan (selisih tepat 1).
func are_adjacent(index_a: int, index_b: int) -> bool:
	if not is_valid_index(index_a) or not is_valid_index(index_b):
		return false
	return absi(index_a - index_b) == 1


## true kalau kartu di kedua posisi punya rank (bintang) yang sama.
func has_same_rank(index_a: int, index_b: int) -> bool:
	if not is_valid_index(index_a) or not is_valid_index(index_b):
		return false
	return _get_resolver().is_same_rank(_cards[index_a], _cards[index_b])


## Pengecekan lengkap: bersebelahan, tidak terkunci, rank sama, tipe dasar
## berbeda, dan resepnya ada. Bisa dipakai UI untuk menyalakan MergeGlow tanpa
## mengubah apa pun.
func can_merge_at(index_a: int, index_b: int) -> bool:
	if not are_adjacent(index_a, index_b):
		return false
	if _cards[index_a].is_locked() or _cards[index_b].is_locked():
		return false
	return _get_resolver().can_merge(_cards[index_a], _cards[index_b])


## Menjalankan Hybrid Merging pada dua kartu bersebelahan.
## Kartu hybrid menempati posisi kiri, posisi kanan hilang, sehingga isi tangan
## berkurang satu. Mengembalikan kartu hybrid, atau null kalau tidak bisa digabung.
func merge_at(index_a: int, index_b: int) -> CardInstance:
	if not can_merge_at(index_a, index_b):
		return null

	var left_index := mini(index_a, index_b)
	var right_index := maxi(index_a, index_b)
	var hybrid := _get_resolver().merge(_cards[left_index], _cards[right_index])

	_cards[left_index] = hybrid
	_cards.remove_at(right_index)

	cards_merged.emit(hybrid, left_index)
	hand_changed.emit()
	return hybrid


## Mencari tetangga (kiri lebih dulu, lalu kanan) yang bisa di-merge dengan
## kartu di index ini. Mengembalikan NO_PARTNER kalau tidak ada.
func find_merge_partner(index: int) -> int:
	for neighbor: int in [index - 1, index + 1]:
		if can_merge_at(index, neighbor):
			return neighbor
	return NO_PARTNER


## Menggabungkan kartu di index ini dengan tetangga yang cocok, kalau ada.
## Dipakai untuk auto-merge setelah kartu digeser.
func merge_with_neighbor(index: int) -> CardInstance:
	var partner := find_merge_partner(index)
	if partner == NO_PARTNER:
		return null
	return merge_at(index, partner)

#endregion


#region Kunci kartu & acak paksa (skill Buto)

func is_locked_at(index: int) -> bool:
	return is_valid_index(index) and _cards[index].is_locked()


func has_lockable_card() -> bool:
	return count_unlocked() > 0


func count_unlocked() -> int:
	var count := 0
	for card: CardInstance in _cards:
		if not card.is_locked():
			count += 1
	return count


## Mengunci kartu di index ini selama `turns` turn pemain. Kunci menempel di
## kartunya, bukan di nomor slot, karena index bergeser setiap kali ada kartu
## yang dimainkan. Kalau kartunya sudah terkunci, durasi yang lebih panjang dipakai.
func lock_card_at(index: int, turns: int) -> bool:
	if not is_valid_index(index) or turns <= 0:
		return false
	var card := _cards[index]
	var was_locked := card.is_locked()
	card.lock_turns = maxi(card.lock_turns, turns)
	if not was_locked:
		card_lock_changed.emit(card, true)
	hand_changed.emit()
	return true


## Mengunci satu kartu acak yang belum terkunci. Mengembalikan index-nya,
## atau -1 kalau tidak ada kartu yang bisa dikunci.
func lock_random_card(rng: RandomNumberGenerator, turns: int) -> int:
	if turns <= 0:
		return -1
	var candidates: Array[int] = []
	for i: int in _cards.size():
		if not _cards[i].is_locked():
			candidates.append(i)
	if candidates.is_empty():
		return -1
	var index := candidates[rng.randi_range(0, candidates.size() - 1)]
	lock_card_at(index, turns)
	return index


## Mengurangi sisa durasi kunci semua kartu sebanyak satu turn.
## Dipanggil BattleManager setiap kali pemain menekan End Turn.
## hand_changed terpancar setiap ada durasi yang berkurang, supaya angka sisa
## turn di ikon gembok ikut ter-update.
func tick_card_locks() -> void:
	var changed := false
	for card: CardInstance in _cards:
		if card.lock_turns > 0:
			card.lock_turns -= 1
			changed = true
			if card.lock_turns == 0:
				card_lock_changed.emit(card, false)
	if changed:
		hand_changed.emit()


## Mengacak urutan kartu di tangan. Kartu yang terkunci tetap di posisinya,
## hanya kartu yang bebas yang saling bertukar tempat. Mengembalikan true kalau
## urutannya benar-benar berubah.
func shuffle_cards(rng: RandomNumberGenerator) -> bool:
	var free_slots: Array[int] = []
	var free_cards: Array[CardInstance] = []
	for i: int in _cards.size():
		if not _cards[i].is_locked():
			free_slots.append(i)
			free_cards.append(_cards[i])
	var original := free_cards.duplicate()

	# Fisher-Yates pada kartu yang bebas saja.
	for i: int in range(free_cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := free_cards[i]
		free_cards[i] = free_cards[j]
		free_cards[j] = temp

	for k: int in free_slots.size():
		_cards[free_slots[k]] = free_cards[k]
	hand_shuffled.emit()
	hand_changed.emit()
	return free_cards != original


# Membuka kunci kartu yang keluar dari tangan, dan memberi tahu view-nya.
func _clear_lock(card: CardInstance) -> void:
	if card.is_locked():
		card.lock_turns = 0
		card_lock_changed.emit(card, false)

#endregion
