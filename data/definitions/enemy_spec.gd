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
