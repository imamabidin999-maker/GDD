class_name CardLibrary
extends Resource
## Kumpulan semua kartu dan resep merge. Satu file (data/card_library.tres)
## supaya CardDB tidak perlu membaca isi folder, yang tidak bisa diandalkan di
## game hasil export.

@export var cards: Array[CardData] = []
@export var recipes: Array[MergeRecipe] = []
