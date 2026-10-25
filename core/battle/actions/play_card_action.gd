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
## Efek kartu Tabuh.
var hit_targets: Array[EnemyUnit] = []
var cards_drawn: int = 0
var calmed: bool = false
## Korek membuyarkan Buto yang sudah siap Ngamuk.
var calmed_ready: bool = false
## Penguat Kenong yang dipakai kartu ini (0 = tidak ada).
var boost_used: float = 0.0


func _init(played_card: CardInstance, target_enemy: EnemyUnit) -> void:
	card = played_card
	target = target_enemy


func _apply(battle: BattleManager) -> void:
	var data := card.data
	var player := battle.player
	if data.next_boost <= 0.0:
		boost_used = player.next_card_boost
	var damage := player.get_card_damage(card) # termasuk penguat Kenong
	if damage > 0:
		if data.hits_all:
			for enemy: EnemyUnit in battle.get_living_enemies():
				hit_targets.append(enemy)
				damage_dealt += enemy.health.take_damage(damage)
		elif EnemyUnit.is_valid_alive(target):
			hit_targets.append(target)
			damage_dealt = target.health.take_damage(damage)
	var shield := player.get_card_shield(card) # termasuk Prayitna dan Kenong
	if shield > 0:
		battle.hero_health.gain_block(shield)
		shield_gained = shield
	if data.ap_gain > 0:
		ap_gained = player.gain_ap(data.ap_gain)
	if data.calm_target and EnemyUnit.is_valid_alive(target):
		calmed_ready = target.is_ngamuk_ready()
		calmed = target.calm_amuk()
	# Penguat Kenong habis dipakai kartu ini; Kenong memasang penguat baru.
	if data.next_boost > 0.0:
		player.next_card_boost = data.next_boost
	elif boost_used > 0.0:
		player.next_card_boost = 0.0

	var moxie_before := player.moxie
	player.register_card_played(card) # Moxie + Evolutionary Chain
	moxie_gained = player.moxie - moxie_before
	battle.deck.discard_card(card) # kartu hybrid dipecah lagi jadi 2 kartu dasar
	# Tarikan Kentongan setelah kartunya dibuang, jadi slotnya sudah kosong.
	if data.draw > 0:
		cards_drawn = battle.deck.draw_cards_into(battle.hand, data.draw).size()
