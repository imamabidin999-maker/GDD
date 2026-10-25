class_name StageData
extends Resource
## Satu stage di peta perjalanan Eyang Palang.
##
## Baris dialog ditulis "pembicara|KUNCI_TEKS". Pembicara yang dikenal:
## narator, eyang, warga, roro_ayu, buto_kuning, buto_hijau, buto_merah,
## buto_putih, buto_hitam. Teksnya ada di localization/strings.csv.

@export var stage_number: int = 1
## Bagian cerita: 1 Kedatangan Buto, 2 Buto Murka, 3 Candi Pagebluk.
@export_range(1, 3) var chapter: int = 1
@export var title_key: String = ""
@export var enemies: Array[EnemySpec] = []
## Musik battle: "battle" atau "boss".
@export var music: String = "battle"
@export var is_boss: bool = false
## Posisi titik stage di peta (koordinat layar 640x360).
@export var map_position: Vector2 = Vector2.ZERO
## Warna yang dikalikan ke latar battle, supaya tiap stage terasa berbeda.
@export var background_tint: Color = Color.WHITE
@export var intro_dialog: PackedStringArray = []
@export var victory_dialog: PackedStringArray = []
## Tips yang muncul di awal battle (dipakai di stage pertama sebagai tutorial).
@export var tutorial_dialog: PackedStringArray = []
