class_name CardData
extends Resource
## Definisi satu jenis kartu. Disimpan sebagai file .tres di data/cards/.
##
## Resource ini DIPAKAI BERSAMA oleh semua salinan kartu yang sama, jadi
## jangan diubah nilainya saat battle berjalan. Perubahan sementara seperti
## kunci LockCard disimpan di [CardInstance].
##
## Efek kartu saat dimainkan (lihat PlayCardAction):
##   base_power -> damage ke Buto yang sedang dikunci sebagai target
##   shield     -> Tameng (block) untuk Eyang Palang sampai awal turn berikutnya
##   ap_gain    -> tambahan AP langsung
##   Moxie      -> otomatis dari PlayerState untuk kartu yang mengandung Fokus

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
## Kunci terjemahan nama kartu, misalnya "CARD_SERANG". Ditampilkan lewat tr().
@export var display_name: String = ""
@export var card_type: CardType = CardType.SERANG
@export_range(MIN_RANK, MAX_RANK) var rank: int = MIN_RANK

@export_group("Efek")
@export var base_power: int = 0
@export var shield: int = 0
@export var ap_gain: int = 0

@export_group("Tampilan")
@export var icon: Texture2D
@export var frame: Texture2D
@export_multiline var description: String = ""


## true untuk Serang, Fokus, dan Taktik. false untuk kartu hasil merge.
func is_base_type() -> bool:
	return card_type != CardType.HYBRID


## Bagian depan id, misalnya "serang" untuk "serang_2" atau "crimson" untuk "crimson_1".
func get_family() -> String:
	return String(id).get_slice("_", 0)
