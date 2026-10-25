class_name EnemySpec
extends Resource
## Satu Buto di sebuah stage: warnanya dan angka-angka untuk stage itu.

@export var buto_type: EnemyButo.ButoType = EnemyButo.ButoType.KUNING
@export_range(1, 999) var max_hp: int = 50
@export_range(1, 99) var attack_power: int = 7
## Skill (racun, LockCard, ForceShuffle) dipakai setiap N turn musuh.
@export_range(1, 5) var skill_cooldown_turns: int = 2
## Skala sprite di layar. Boss lebih besar.
@export var sprite_scale: float = 1.0
## Buto Murka: versi yang dikuatkan Buto Hitam (aura, ilmu lebih kuat, Ngamuk).
@export var murka: bool = false
## Bisa Ngamuk (beraksi dua kali setelah 3 aksi). Buto Murka selalu bisa.
@export var can_ngamuk: bool = false
## Titik Amuk awal; negatif menunda Ngamuk pertama.
@export_range(-3, 3) var start_amuk: int = 0
## Bala: Buto bayangan panggilan Buto Hitam (tidak dipakai di data babak).
@export var bala: bool = false


## Membuat EnemyButo (beserta HealthComponent bernama "Health") sesuai angka
## di spec ini. Dipakai battle scene dan simulasi keseimbangan supaya keduanya
## selalu memakai aturan yang sama.
func create_buto() -> EnemyButo:
	var buto := EnemyButo.new()
	buto.buto_type = buto_type
	buto.attack_power = attack_power
	buto.skill_cooldown_turns = skill_cooldown_turns
	buto.is_bala = bala
	if murka:
		buto.apply_murka()
	buto.can_ngamuk = buto.can_ngamuk or can_ngamuk
	buto.start_amuk = start_amuk
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_hp = max_hp
	buto.add_child(health)
	buto.health = health
	return buto
