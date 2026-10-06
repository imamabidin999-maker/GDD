class_name CardInstance
extends RefCounted
## Satu kartu "fisik" di dalam battle.
##
## [CardData] adalah cetakannya, sedangkan CardInstance adalah kartu yang
## benar-benar dipegang pemain. Dua kartu Serang ★1 di deck memakai CardData
## yang sama, tapi masing-masing punya CardInstance dan uid sendiri.
##
## Kartu hybrid menyimpan dua kartu bahannya di [member components]. Saat
## kartu hybrid dibuang, DeckController memecahnya lagi supaya jumlah kartu
## dasar di deck tetap 15.

# Penghitung uid yang dipakai bersama oleh semua instance (static var butuh Godot 4.1+).
static var _next_uid: int = 1

## Nomor unik per kartu. Berguna untuk mencocokkan kartu dengan CardView-nya.
var uid: int
var data: CardData
## Kosong untuk kartu dasar. Berisi dua kartu bahan untuk kartu hybrid.
var components: Array[CardInstance] = []


func _init(card_data: CardData) -> void:
	data = card_data
	uid = _next_uid
	_next_uid += 1


## Membuat kartu hybrid baru dari dua kartu bahan.
static func create_hybrid(result_data: CardData, first: CardInstance, second: CardInstance) -> CardInstance:
	var hybrid := CardInstance.new(result_data)
	hybrid.components.append(first)
	hybrid.components.append(second)
	return hybrid


func get_rank() -> int:
	return data.rank


func get_type() -> CardData.CardType:
	return data.card_type


func is_hybrid() -> bool:
	return not data.is_base_type()


## Mengembalikan kartu-kartu dasar penyusun kartu ini.
## Kartu dasar mengembalikan dirinya sendiri. Kartu hybrid mengembalikan bahan
## penyusunnya secara rekursif, berjaga-jaga kalau nanti hybrid boleh di-merge lagi.
func get_base_cards() -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if components.is_empty():
		result.append(self)
		return result
	for part: CardInstance in components:
		result.append_array(part.get_base_cards())
	return result


func _to_string() -> String:
	return "%s★%d#%d" % [data.display_name, data.rank, uid]
