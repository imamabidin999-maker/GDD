class_name CardData
extends Resource
## Definisi satu jenis kartu. Disimpan sebagai file .tres.
##
## Resource ini DIPAKAI BERSAMA oleh semua salinan kartu yang sama, jadi
## jangan diubah nilainya saat battle berjalan. Perubahan sementara seperti
## buff atau debuff disimpan di [CardInstance].

enum CardType {
	SERANG, ## Merah
	FOKUS, ## Biru
	TAKTIK, ## Hijau
	HYBRID, ## Hasil Hybrid Merging: Crimson Focus, Piercing Strike, Flow State
}

## Batas rank (bintang). Ubah MAX_RANK kalau nanti ada kartu bintang 4 ke atas.
const MIN_RANK: int = 1
const MAX_RANK: int = 3

@export var id: StringName = &""
@export var display_name: String = ""
@export var card_type: CardType = CardType.SERANG
@export_range(MIN_RANK, MAX_RANK) var rank: int = MIN_RANK
@export var base_power: int = 0
@export var icon: Texture2D
@export_multiline var description: String = ""
# Daftar CardEffect (damage, gain Moxie, status, dst.) ditambahkan di tahap berikutnya.


## true untuk Serang, Fokus, dan Taktik. false untuk kartu hasil merge.
func is_base_type() -> bool:
	return card_type != CardType.HYBRID
