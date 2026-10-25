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
## Efek khusus kartu Tabuh:
##   hits_all    -> base_power mengenai semua Buto (Tabuh Bedug)
##   draw        -> tarik kartu tambahan (Kentongan Titir)
##   calm_target -> mengosongkan Amuk sasaran (Korek)
##   ap_cost     -> Ketukan yang dibutuhkan (Gong: 2)
##   next_boost  -> kartu berikutnya giliran ini lebih kuat (Kenong)
##   moxie_gain  -> Greget tetap (Korek)

enum CardType {
	SERANG, ## Merah
	FOKUS, ## Biru
	TAKTIK, ## Hijau
	HYBRID, ## Hasil Hybrid Merging: Crimson Focus, Piercing Strike, Flow State
	TABUH, ## Jurus Tabuh (alat musik Dongkrek): tidak bisa digabung
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
## Ketukan untuk memainkan kartu ini.
@export_range(0, 4) var ap_cost: int = 1
@export var hits_all: bool = false
@export_range(0, 5) var draw: int = 0
@export var calm_target: bool = false
## Tambahan untuk kartu berikutnya giliran ini, misalnya 0.4 = +40%.
@export_range(0.0, 2.0, 0.05) var next_boost: float = 0.0
## Greget tetap dari kartu ini (Korek), di luar Greget dari kartu Semedi.
@export_range(0.0, 100.0) var moxie_gain: float = 0.0

@export_group("Tampilan")
@export var icon: Texture2D
@export var frame: Texture2D
@export_multiline var description: String = ""


## true untuk Serang, Fokus, Taktik, dan Tabuh. false untuk kartu hasil merge.
## Hanya kartu dasar yang boleh ada di deck.
func is_base_type() -> bool:
	return card_type != CardType.HYBRID


func is_tabuh() -> bool:
	return card_type == CardType.TABUH


## Bagian depan id, misalnya "serang" untuk "serang_2" atau "crimson" untuk "crimson_1".
func get_family() -> String:
	return String(id).get_slice("_", 0)
