class_name MergeResolver
extends RefCounted
## Aturan Hybrid Merging di tingkat kartu, tanpa peduli posisi di tangan.
##
## Dua kartu bisa digabung kalau:
##   1. Rank (bintang) keduanya sama.
##   2. Keduanya kartu dasar dan tipenya berbeda.
##   3. Ada [MergeRecipe] untuk pasangan tipe itu yang punya hasil di rank tersebut.
##
## Syarat "harus bersebelahan" diurus oleh [HandManager], bukan di sini.
## Kartu sesama tipe dan kartu hybrid sengaja belum bisa digabung. Itu masih
## menunggu keputusan desain nomor 3 di dokumen arsitektur.

var _recipes: Array[MergeRecipe] = []


func _init(recipes: Array[MergeRecipe]) -> void:
	_recipes = recipes


func is_same_rank(first: CardInstance, second: CardInstance) -> bool:
	return first.get_rank() == second.get_rank()


## true kalau keduanya kartu dasar (bukan hybrid) dan tipenya tidak sama.
func is_different_base_type(first: CardInstance, second: CardInstance) -> bool:
	if first.is_hybrid() or second.is_hybrid():
		return false
	return first.get_type() != second.get_type()


## Mencari CardData hasil merge. Mengembalikan null kalau syarat tidak terpenuhi.
func find_result(first: CardInstance, second: CardInstance) -> CardData:
	if first == null or second == null or first == second:
		return null
	if not is_same_rank(first, second):
		return null
	if not is_different_base_type(first, second):
		return null
	for recipe: MergeRecipe in _recipes:
		if recipe != null and recipe.matches(first.get_type(), second.get_type()):
			return recipe.get_result_for_rank(first.get_rank())
	return null


func can_merge(first: CardInstance, second: CardInstance) -> bool:
	return find_result(first, second) != null


## Membuat kartu hybrid baru. Fungsi ini tidak mengubah isi tangan; itu tugas HandManager.
func merge(first: CardInstance, second: CardInstance) -> CardInstance:
	var result_data := find_result(first, second)
	if result_data == null:
		return null
	return CardInstance.create_hybrid(result_data, first, second)
