class_name EnemyIntent
extends RefCounted
## Niat musuh untuk turn musuh berikutnya. Ditampilkan sebagai ikon + angka di
## atas kepala Buto supaya pemain bisa menyusun strategi.

enum Kind {
	ATTACK, ## serangan biasa
	DRAIN, ## Kuning: serangan + kuras Moxie Overcharge
	LOCK, ## Putih: kunci 1 kartu
	SHUFFLE, ## Hitam fase 2: hantaman + acak deck & tangan
	POISON, ## Hijau: semburan racun
	CHARGE, ## Merah: ancang-ancang (turn depan pukulan berat)
	HEAVY, ## Merah: pukulan berat
}

var kind: Kind
## Damage ke hero (0 kalau tidak menyerang).
var damage: int
## Nilai tambahan: persen Moxie yang dikuras, tumpukan racun, atau damage
## pukulan berat yang sedang disiapkan.
var extra: int


func _init(intent_kind: Kind, intent_damage: int = 0, intent_extra: int = 0) -> void:
	kind = intent_kind
	damage = intent_damage
	extra = intent_extra
