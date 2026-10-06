class_name MergeRecipe
extends Resource
## Resep Hybrid Merging: pasangan dua tipe dasar menghasilkan kartu hybrid.
##
## Contoh: SERANG + FOKUS menjadi Crimson Focus.
## Urutan tipe tidak berpengaruh, SERANG + FOKUS sama dengan FOKUS + SERANG.

@export var type_a: CardData.CardType = CardData.CardType.SERANG
@export var type_b: CardData.CardType = CardData.CardType.FOKUS
## Kartu hasil untuk tiap rank, misalnya Crimson Focus ★1, ★2, dan ★3.
## Rank kartu hasil harus sama dengan rank kedua kartu bahannya.
@export var results: Array[CardData] = []


## true kalau resep ini berlaku untuk pasangan tipe tersebut (urutan bebas).
func matches(first: CardData.CardType, second: CardData.CardType) -> bool:
	return (first == type_a and second == type_b) \
		or (first == type_b and second == type_a)


## Mengembalikan kartu hasil untuk rank tertentu, atau null kalau belum diisi.
func get_result_for_rank(rank: int) -> CardData:
	for result: CardData in results:
		if result != null and result.rank == rank:
			return result
	return null
