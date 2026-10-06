class_name PlayCardAction
extends BattleAction
## Pemain memainkan satu kartu dari tangan.
##
## AP sudah dipotong dan kartu sudah diangkat dari tangan oleh BattleManager
## sebelum aksi ini masuk antrean.

var card: CardInstance
var target: EnemyUnit
## Damage yang benar-benar masuk, untuk angka damage di UI.
var damage_dealt: int = 0


func _init(played_card: CardInstance, target_enemy: EnemyUnit) -> void:
	card = played_card
	target = target_enemy


func _apply(battle: BattleManager) -> void:
	# Untuk sementara damage = base_power kartu.
	# Nanti diganti CardEffect + DamageCalculator.
	if card.data.base_power > 0 and EnemyUnit.is_valid_alive(target):
		damage_dealt = target.health.take_damage(card.data.base_power)

	battle.player.register_card_played(card) # Moxie + Evolutionary Chain
	battle.deck.discard_card(card) # kartu hybrid dipecah lagi jadi 2 kartu dasar
