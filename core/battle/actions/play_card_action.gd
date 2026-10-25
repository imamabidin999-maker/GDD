class_name PlayCardAction
extends BattleAction
## Pemain memainkan satu kartu dari tangan.
##
## AP sudah dipotong dan kartu sudah diangkat dari tangan oleh BattleManager
## sebelum aksi ini masuk antrean.

var card: CardInstance
var target: EnemyUnit
## Hasil untuk ditampilkan view (angka damage, tameng, AP, Moxie).
var damage_dealt: int = 0
var shield_gained: int = 0
var ap_gained: int = 0
var moxie_gained: float = 0.0


func _init(played_card: CardInstance, target_enemy: EnemyUnit) -> void:
	card = played_card
	target = target_enemy


func _apply(battle: BattleManager) -> void:
	var data := card.data
	if data.base_power > 0 and EnemyUnit.is_valid_alive(target):
		damage_dealt = target.health.take_damage(data.base_power)
	var shield := battle.player.get_card_shield(card) # termasuk tambahan Prayitna
	if shield > 0:
		battle.hero_health.gain_block(shield)
		shield_gained = shield
	if data.ap_gain > 0:
		ap_gained = battle.player.gain_ap(data.ap_gain)

	var moxie_before := battle.player.moxie
	battle.player.register_card_played(card) # Moxie + Evolutionary Chain
	moxie_gained = battle.player.moxie - moxie_before
	battle.deck.discard_card(card) # kartu hybrid dipecah lagi jadi 2 kartu dasar
