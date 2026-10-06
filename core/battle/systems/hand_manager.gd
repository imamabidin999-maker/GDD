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
	hand_changed.emit()
	return taken


## Menggeser kartu dari from_index sehingga berakhir di to_index.
## Kartu lain otomatis bergeser mengisi tempat kosong.
## Fungsi ini tidak otomatis melakukan merge. BattleManager.request_move_card()
## yang memutuskan apakah merge_with_neighbor() dipanggil setelahnya.
func move_card(from_index: int, to_index: int) -> bool:
	if not is_valid_index(from_index) or not is_valid_index(to_index):
		return false
	if from_index == to_index:
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


## Pengecekan lengkap: bersebelahan, rank sama, tipe dasar berbeda, dan resepnya ada.
## Bisa dipakai UI untuk menyalakan MergeGlow tanpa mengubah apa pun.
func can_merge_at(index_a: int, index_b: int) -> bool:
	if not are_adjacent(index_a, index_b):
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
