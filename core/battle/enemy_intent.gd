class_name EnemyIntent
extends RefCounted
## Niat musuh untuk turn musuh berikutnya. Ditampilkan sebagai ikon + angka di
## atas kepala Buto supaya pemain bisa menyusun strategi.

enum Kind {
	ATTACK, ## serangan biasa
	DRAIN, ## Kuning: serangan + kuras Moxie Overcharge
	LOCK, ## Putih: kunci 1 kartu
	POISON, ## Hijau: semburan racun
	CHARGE, ## Merah: ancang-ancang (turn depan pukulan berat)
	HEAVY, ## Merah: pukulan berat
	PLAGUE_STRIKE, ## Hitam: Gebug Pagebluk, serangan + Lara
	AJIAN_CHARGE, ## Hitam: ancang-ancang Ajian Lebur Saketi
	AJIAN, ## Hitam: Ajian Lebur Saketi (bisa dibuyarkan)
	SUMMON, ## Hitam fase 2: Memanggil Bala
	STAGGER, ## Hitam: terhuyung setelah ajiannya buyar, tidak beraksi
}

var kind: Kind
## Damage ke hero (0 kalau tidak menyerang).
var damage: int
## Nilai tambahan: persen Moxie yang dikuras, tumpukan racun, damage pukulan
## berat/Ajian yang sedang disiapkan, atau jumlah Bala yang dipanggil.
var extra: int
## Niat Buto Murka (teks niatnya sedikit berbeda, misalnya Kuning Murka
## menghisap Greget dari level berapa pun).
var murka: bool = false


func _init(intent_kind: Kind, intent_damage: int = 0, intent_extra: int = 0) -> void:
	kind = intent_kind
	damage = intent_damage
	extra = intent_extra
