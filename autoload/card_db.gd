extends Node
## Registry baca-saja untuk semua kartu dan resep merge.
##
## Kartu dicari dengan kunci "keluarga:rank", misalnya "serang:2" atau
## "crimson:1". Format yang sama dipakai GameState untuk menyimpan deck.

const LIBRARY_PATH := "res://data/card_library.tres"

var library: CardLibrary
var _by_key: Dictionary = {}


func _ready() -> void:
	library = load(LIBRARY_PATH) as CardLibrary
	if library == null:
		push_error("CardDB: gagal memuat %s" % LIBRARY_PATH)
		return
	for card: CardData in library.cards:
		_by_key[_key_of(card)] = card


func get_card(family: String, rank: int) -> CardData:
	return _by_key.get("%s:%d" % [family, rank]) as CardData


## Mengubah "serang:2" menjadi CardData-nya. null kalau tidak dikenal.
func card_from_spec(spec: String) -> CardData:
	return _by_key.get(spec) as CardData


func build_deck_list(specs: Array[String]) -> Array[CardData]:
	var list: Array[CardData] = []
	for spec: String in specs:
		var card := card_from_spec(spec)
		if card == null:
			push_error("CardDB: kartu '%s' tidak dikenal." % spec)
			continue
		list.append(card)
	return list


func get_recipes() -> Array[MergeRecipe]:
	return library.recipes if library != null else ([] as Array[MergeRecipe])


func get_all_cards() -> Array[CardData]:
	return library.cards if library != null else ([] as Array[CardData])


func _key_of(card: CardData) -> String:
	return "%s:%d" % [card.get_family(), card.rank]
