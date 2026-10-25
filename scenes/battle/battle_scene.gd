extends Node2D
## Composition root battle: membaca stage dari GameState, memunculkan Eyang
## Palang dan para Buto, menyambungkan BattleManager dengan tampilan (HUD,
## tangan, animasi), lalu mengurus alur menang/kalah.

const HERO_IDLE := preload("res://assets/sprites/hero/eyang_palang_idle.png")
const HERO_ATTACKS: Array[Texture2D] = [
	preload("res://assets/sprites/hero/eyang_palang_attack_1.png"),
	preload("res://assets/sprites/hero/eyang_palang_attack_2.png"),
]
const ENEMY_SLOTS := {
	1: [Vector2(472, 228)],
	2: [Vector2(410, 228), Vector2(540, 228)],
	3: [Vector2(372, 228), Vector2(470, 228), Vector2(568, 228)],
	4: [Vector2(322, 228), Vector2(406, 228), Vector2(490, 228), Vector2(574, 228)],
}
## Empat Buto sekaligus (babak 9) sedikit diperkecil supaya muat.
const FOUR_SLOT_SCALE := 0.82
## Bala muncul di depan Buto Hitam, yang mundur ke HITAM_BACK_X.
const BALA_SLOTS: Array[Vector2] = [Vector2(318, 236), Vector2(404, 236), Vector2(362, 250)]
const BALA_SCALE := 0.8
const HITAM_BACK_X := 528.0
const HIT_DELAY := 0.17

@onready var _battle: BattleManager = $Systems/BattleManager
@onready var _deck: DeckController = $Systems/DeckController
@onready var _hand: HandManager = $Systems/HandManager
@onready var _player: PlayerState = $Systems/PlayerState
@onready var _world: Node2D = $World
@onready var _background: Sprite2D = $World/Background
@onready var _hero_node: Node2D = $World/Hero
@onready var _hero_health: HealthComponent = $World/Hero/Health
@onready var _enemy_layer: Node2D = $World/Enemies
@onready var _effects: Node2D = $World/Effects
@onready var _hud: BattleHUD = $HUD/BattleHUD
@onready var _hand_view: HandView = $HUD/HandView
@onready var _tooltip: GameTooltip = $HUD/Tooltip
@onready var _overlay: CanvasLayer = $Overlay

var _stage: StageData
var _hero_view: UnitView
var _enemy_views: Dictionary = {} # EnemyUnit -> UnitView
var _enemies: Array[EnemyUnit] = []
var _enemy_phase: bool = false
var _battle_over: bool = false
var _last_block: int = 0
# Aksi yang sedang di-resolve, supaya angka damage tahu sumbernya (misalnya racun).
var _current_action: BattleAction
var _bala_spawned: int = 0
# Dialog singkat saat Buto Hitam masuk fase 2, diputar begitu pemain bisa beraksi lagi.
var _phase_dialog_pending: bool = false
var _hints: HintToast
# Skala waktu sebelum battle (tes otomatis mempercepatnya). Kecepatan battle
# dikalikan ke sini dan dikembalikan saat scene ditutup.
var _base_time_scale: float = 1.0


func _ready() -> void:
	var catalog := StageCatalog.load_default()
	_stage = catalog.get_stage(GameState.current_stage)
	if _stage == null:
		_stage = catalog.stages[0]

	_background.modulate = _stage.background_tint
	_add_fireflies()
	_setup_hero()
	_setup_enemies()

	_hand.merge_recipes = CardDB.get_recipes()
	_hud.setup(_battle, _stage_title())
	GameState.settings_changed.connect(_on_settings_changed)
	_hand_view.setup(_battle)
	_hand_view.deck_point = Vector2(40, 330)
	_hints = HintToast.new()
	$HUD.add_child(_hints)
	_connect_signals()
	_base_time_scale = Engine.time_scale
	_apply_speed()
	tree_exiting.connect(func() -> void: Engine.time_scale = _base_time_scale)
	AudioManager.play_music(_stage.music)
	_begin.call_deferred()


func _apply_speed() -> void:
	Engine.time_scale = _base_time_scale * GameState.battle_speed


func _toggle_speed() -> void:
	AudioManager.play_sfx("click")
	GameState.set_battle_speed(1.0 if GameState.battle_speed > 1.0 else 2.0)


func _begin() -> void:
	await _play_dialog(_stage.intro_dialog)
	if not _stage.tutorial_dialog.is_empty() and not GameState.tutorial_done:
		await _play_dialog(_stage.tutorial_dialog)
		GameState.tutorial_done = true
		GameState.save_game()
	var deck_list := CardDB.build_deck_list(GameState.deck)
	GameState.prepare_player(_player)
	_battle.start_battle(deck_list, _enemies)
	for enemy: EnemyUnit in _enemies:
		var view: UnitView = _enemy_views[enemy]
		view.show_amuk(enemy.can_ngamuk)
		view.set_amuk(enemy.amuk)
		var buto := enemy as EnemyButo
		if buto != null and buto.murka:
			_hints.offer("murka")
		if enemy.can_ngamuk:
			_hints.offer("ngamuk")


#region Persiapan

func _setup_hero() -> void:
	_hero_health.max_hp = GameState.max_hp
	_hero_health.reset()
	_hero_view = UnitView.new()
	_hero_node.add_child(_hero_view)
	_hero_view.setup(HERO_IDLE, HERO_ATTACKS, _hero_health, false)
	_hero_view.hover_changed.connect(_on_hero_hover)


func _setup_enemies() -> void:
	var specs := _stage.enemies
	var slots: Array = ENEMY_SLOTS.get(specs.size(), ENEMY_SLOTS[4])
	var layout_scale := FOUR_SLOT_SCALE if specs.size() >= 4 else 1.0
	for i: int in specs.size():
		_create_buto(specs[i], slots[i], layout_scale)


## Membuat satu Buto lengkap dengan HealthComponent dan UnitView-nya, sesuai
## EnemySpec. Dipakai di awal battle dan saat Buto Hitam memanggil Bala.
func _create_buto(spec: EnemySpec, at: Vector2, layout_scale: float = 1.0) -> EnemyButo:
	var buto := spec.create_buto()
	_apply_difficulty(buto)
	buto.position = at
	_enemy_layer.add_child(buto)
	_register_buto(buto, spec.sprite_scale * layout_scale)
	return buto


# Tingkat kesulitan cerita mengubah Nyawa dan serangan Buto (termasuk Bala
# yang nanti dipanggil Buto Hitam).
func _apply_difficulty(buto: EnemyButo) -> void:
	var hp_mult := GameState.difficulty_hp_multiplier()
	var atk_mult := GameState.difficulty_attack_multiplier()
	if is_equal_approx(hp_mult, 1.0) and is_equal_approx(atk_mult, 1.0):
		return
	buto.health.max_hp = maxi(1, roundi(buto.health.max_hp * hp_mult))
	buto.health.reset()
	buto.attack_power = maxi(1, roundi(buto.attack_power * atk_mult))
	buto.bala_hp = maxi(1, roundi(buto.bala_hp * hp_mult))
	buto.bala_attack = maxi(1, roundi(buto.bala_attack * atk_mult))


# Membuat UnitView untuk Buto yang sudah ada di _enemy_layer, lalu mencatatnya.
func _register_buto(buto: EnemyButo, view_scale: float) -> UnitView:
	buto.name = "Buto%s%d" % [String(EnemyButo.ButoType.keys()[buto.buto_type]).capitalize(), _enemies.size()]
	buto.display_name = _buto_name(buto)
	var key := buto.get_type_key()
	var idle: Texture2D = load("res://assets/sprites/buto/buto_%s_idle.png" % key)
	var attacks: Array[Texture2D] = [load("res://assets/sprites/buto/buto_%s_attack.png" % key)]
	var view := UnitView.new()
	buto.add_child(view)
	view.setup(idle, attacks, buto.health, true, view_scale)
	view.set_murka(buto.murka)
	view.set_shadow(buto.is_bala)
	view.clicked.connect(_on_enemy_clicked)
	view.hover_changed.connect(_on_enemy_hover)
	_enemy_views[buto] = view
	_enemies.append(buto)
	buto.phase_changed.connect(_on_phase_changed.bind(buto))
	buto.ajian_progress_changed.connect(view.set_ajian_progress)
	buto.ajian_broken.connect(_on_ajian_broken.bind(buto))
	buto.bala_shield_changed.connect(view.set_bala_shield)
	GameState.mark_buto_seen("bala" if buto.is_bala else key)
	if buto.murka:
		GameState.mark_buto_seen("murka")
	return view


# Sambungan signal per Buto: titik Amuk dan angka damage.
func _hook_enemy_signals(enemy: EnemyUnit) -> void:
	var view: UnitView = _enemy_views[enemy]
	enemy.amuk_changed.connect(view.set_amuk)
	enemy.health.damaged.connect(_on_unit_damaged.bind(enemy.health))
	enemy.health.damage_blocked.connect(_on_unit_blocked.bind(enemy.health))


func _buto_name(buto: EnemyButo) -> String:
	var base := tr("BUTO_" + buto.get_type_key().to_upper())
	if buto.is_bala:
		return tr("BALA_FMT") % base.trim_prefix("Buto ")
	return tr("BUTO_MURKA_FMT") % base if buto.murka else base


func _stage_title() -> String:
	return "%s  -  %s" % [tr("MAP_STAGE") % _stage.stage_number, tr(_stage.title_key)]


## Bahasa bisa diganti dari menu jeda: tulis ulang teks yang tidak ikut
## berganti sendiri.
func _on_settings_changed() -> void:
	_hud.refresh_texts(_stage_title())
	_hud.refresh_speed()
	_apply_speed()
	for enemy: EnemyUnit in _enemies:
		var buto := enemy as EnemyButo
		if buto != null:
			buto.display_name = _buto_name(buto)


func _add_fireflies() -> void:
	var p := Ambient.fireflies(Vector2(320, 120), Vector2(320, 90))
	_world.add_child(p)
	_world.move_child(p, 1)


func _connect_signals() -> void:
	_battle.action_started.connect(func(action: BattleAction) -> void: _current_action = action)
	_battle.action_presentation_started.connect(_on_action_presented)
	_battle.target_changed.connect(_on_target_changed)
	_battle.turn_started.connect(_on_turn_started)
	_battle.enemy_turn_started.connect(_on_enemy_turn_started)
	_battle.enemy_ngamuk.connect(_on_enemy_ngamuk)
	_battle.enemy_spawned.connect(_on_enemy_spawned)
	_player.prayitna_changed.connect(func(on: bool) -> void:
		_hero_view.set_prayitna(on)
		if on:
			_hints.offer("prayitna"))
	for enemy: EnemyUnit in _enemies:
		_hook_enemy_signals(enemy)
	_battle.player_input_ready.connect(_refresh_intents)
	_battle.player_input_ready.connect(_play_phase_dialog)
	_battle.battle_ended.connect(_on_battle_ended)
	_hand.hand_changed.connect(_refresh_intents)
	_player.ap_rejected.connect(_on_ap_rejected)
	_player.poison_changed.connect(func(stacks: int) -> void:
		_hero_view.set_poison(stacks)
		if stacks > 0:
			_hints.offer("lara"))
	_player.evolutionary_chain_triggered.connect(_on_chain)
	_player.overcharge_drained.connect(func(amount: float) -> void:
		_float_text(tr("BATTLE_MOXIE_DRAINED") % roundi(amount), _hud.get_moxie_point() + Vector2(0, -6), UIKit.COLOR_PURPLE))
	_player.ultimate_ready.connect(func() -> void: AudioManager.play_sfx("moxie"))

	_hero_health.damaged.connect(_on_unit_damaged.bind(_hero_health))
	_hero_health.damage_blocked.connect(_on_unit_blocked.bind(_hero_health))
	_hero_health.block_changed.connect(_on_hero_block_changed)

	_hud.end_turn_pressed.connect(_on_end_turn)
	_hud.ultimate_pressed.connect(_on_ultimate)
	_hud.pause_pressed.connect(_open_pause)
	_hud.speed_pressed.connect(_toggle_speed)
	_hud.tooltip_requested.connect(func(text: String, at: Vector2) -> void: _tooltip.show_text(text, at))
	_hud.tooltip_hidden.connect(_tooltip.hide_tip)
	_hand_view.card_hovered.connect(func(view: CardView) -> void:
		_tooltip.show_text(view.get_tooltip_bbcode(), view.global_position + Vector2(0, 0)))
	_hand_view.card_unhovered.connect(func(_v: CardView) -> void: _tooltip.hide_tip())
	_hand_view.play_on_enemy_requested.connect(_on_play_on_enemy)
	_hand_view.sirep_card_touched.connect(func(view: CardView) -> void:
		AudioManager.play_sfx("error")
		_float_text(tr("BATTLE_CARD_LOCKED"), view.global_position + Vector2(38, -4), UIKit.COLOR_GOLD))


func _view_of(health: HealthComponent) -> UnitView:
	if health == _hero_health:
		return _hero_view
	for enemy: EnemyUnit in _enemies:
		if enemy.health == health:
			return _enemy_views[enemy]
	return null

#endregion


#region Input pemain

func _on_end_turn() -> void:
	if _battle.request_end_turn():
		AudioManager.play_sfx("kentongan")


func _on_ultimate() -> void:
	_battle.request_ultimate()


func _on_enemy_clicked(view: UnitView) -> void:
	for enemy: EnemyUnit in _enemies:
		if _enemy_views[enemy] == view and _battle.select_target(enemy):
			AudioManager.play_sfx("click")


func _on_play_on_enemy(hand_index: int, point: Vector2) -> void:
	for enemy: EnemyUnit in _enemies:
		var view: UnitView = _enemy_views[enemy]
		if view.contains_point(point):
			_battle.select_target(enemy)
			break
	_battle.request_play_card(hand_index)


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.get_child_count() > 0 or _battle_over:
		return
	if event.is_action_pressed("pause"):
		_open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("end_turn"):
		_on_end_turn()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ultimate"):
		_on_ultimate()
		get_viewport().set_input_as_handled()
	else:
		var key := event as InputEventKey
		if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_9:
			var index := key.keycode - KEY_1
			if _battle.hand.is_locked_at(index):
				_hand_view.reject_sirep_at(index)
			else:
				_battle.request_play_card(index)
			get_viewport().set_input_as_handled()

#endregion


#region Reaksi tampilan

func _on_action_presented(action: BattleAction) -> void:
	if action is PlayCardAction:
		_present_card(action as PlayCardAction)
	elif action is UltimateAction:
		_present_ultimate(action as UltimateAction)
	elif action is ButoSkillAction:
		_present_skill(action as ButoSkillAction)
	elif action is EnemyAttackAction:
		var attack := action as EnemyAttackAction
		_enemy_views[attack.attacker].play_attack()
		AudioManager.play_sfx("bedug", 0.08)
	elif action is PoisonTickAction:
		AudioManager.play_sfx("poison")


func _present_card(action: PlayCardAction) -> void:
	var data := action.card.data
	if data.base_power > 0:
		_hero_view.play_attack(data.base_power >= 14)
		AudioManager.play_sfx("hit_heavy" if data.base_power >= 14 else "hit", 0.08)
	else:
		_hero_view.play_glow(Color(0.5, 0.95, 0.6))
		AudioManager.play_sfx("card", 0.05)
	if action.moxie_gained > 0.0:
		_float_text("+%d%%" % roundi(action.moxie_gained), _hud.get_moxie_point() + Vector2(0, -6), UIKit.COLOR_BLUE)
	if action.ap_gained > 0:
		_float_text(tr("EFFECT_AP") % action.ap_gained, _hud.get_ap_point() + Vector2(0, -6), UIKit.COLOR_GOLD)


func _present_ultimate(action: UltimateAction) -> void:
	_hero_view.play_attack(true)
	AudioManager.play_sfx("gong", 0.0)
	_hud.show_banner(tr("BATTLE_ULTIMATE"), UIKit.COLOR_GOLD)
	_screen_flash(Color(1.0, 0.92, 0.7, 0.55))
	_shake_world(5.0)
	if action.calmed > 0:
		_float_text(tr("BATTLE_AMUK_CALMED"), Vector2(470, 70), UIKit.COLOR_GOLD, true)


func _present_skill(action: ButoSkillAction) -> void:
	var view: UnitView = _enemy_views.get(action.buto)
	if view == null:
		return
	match action.skill:
		EnemyButo.Skill.DRAINING_STRIKE:
			view.play_attack()
			AudioManager.play_sfx("bedug", 0.08)
		EnemyButo.Skill.LOCK_CARD:
			view.play_glow(Color(0.9, 0.95, 1.0))
			AudioManager.play_sfx("lock")
			if action.warded:
				_hero_view.play_glow(Color(0.95, 0.8, 0.4))
				_float_text(tr("BATTLE_SIREP_WARDED"), _hero_view.get_top_point(), UIKit.COLOR_GOLD, true)
			elif action.succeeded:
				_float_text(tr("BATTLE_CARD_LOCKED_BY"), view.get_top_point(), UIKit.COLOR_GOLD)
		EnemyButo.Skill.POISON_SPIT:
			view.play_attack()
			AudioManager.play_sfx("poison")
		EnemyButo.Skill.CHARGE:
			view.play_charge()
			AudioManager.play_sfx("korek")
			_float_text(tr("BATTLE_CHARGING"), view.get_top_point(), UIKit.COLOR_RED)
		EnemyButo.Skill.HEAVY_STRIKE:
			view.play_attack(true)
			AudioManager.play_sfx("hit_heavy")
			_shake_world(4.0)
		EnemyButo.Skill.PLAGUE_STRIKE:
			view.play_attack()
			AudioManager.play_sfx("bedug", 0.08)
			AudioManager.play_sfx("poison", 0.05, -4.0)
		EnemyButo.Skill.AJIAN_CHARGE:
			view.play_charge()
			AudioManager.play_sfx("gong", 0.0, -4.0)
			_float_text(tr("BATTLE_AJIAN_CHARGING"), view.get_top_point(), Color(1.0, 0.45, 0.6), true)
		EnemyButo.Skill.AJIAN:
			view.play_attack(true)
			AudioManager.play_sfx("hit_heavy")
			_screen_flash(Color(0.85, 0.15, 0.4, 0.45))
			_shake_world(7.0)
			_hud.show_banner(tr("BATTLE_AJIAN"), UIKit.COLOR_RED)
		EnemyButo.Skill.SUMMON_BALA:
			view.play_glow(Color(0.6, 0.4, 0.9))
			AudioManager.play_sfx("gong", 0.0, -2.0)
			_hud.show_banner(tr("BATTLE_SUMMON_BALA"), UIKit.COLOR_PURPLE)
		EnemyButo.Skill.STAGGER:
			view.play_hit(Color(1.0, 0.95, 0.6))
			AudioManager.play_sfx("korek")
			_float_text(tr("BATTLE_STAGGERED"), view.get_top_point(), UIKit.COLOR_GOLD, true)
		EnemyButo.Skill.PAGEBLUK:
			AudioManager.play_sfx("poison", 0.05, -4.0)
			_hero_view.play_glow(Color(0.6, 0.35, 0.85))
			_float_text(tr("BATTLE_PAGEBLUK") % action.buto.pagebluk_poison, _hero_view.get_top_point() + Vector2(0, 10), UIKit.COLOR_PURPLE)


func _on_unit_damaged(amount: int, health: HealthComponent) -> void:
	var view := _view_of(health)
	if view == null:
		return
	var poison_hit := _current_action is PoisonTickAction
	await get_tree().create_timer(HIT_DELAY).timeout
	view.play_hit(Color(0.5, 1.0, 0.4) if poison_hit else Color.WHITE)
	var color := UIKit.COLOR_GREEN if poison_hit else (UIKit.COLOR_RED if health == _hero_health else Color(1, 0.95, 0.85))
	_float_text("-%d" % amount, view.get_hit_point() + Vector2(randf_range(-8, 8), -10), color, amount >= 15)


func _on_unit_blocked(amount: int, health: HealthComponent) -> void:
	var view := _view_of(health)
	if view == null:
		return
	await get_tree().create_timer(HIT_DELAY).timeout
	AudioManager.play_sfx("block", 0.05)
	_float_text("%s -%d" % [tr("BATTLE_BLOCK"), amount], view.get_hit_point() + Vector2(0, -24), UIKit.COLOR_GREEN)


func _on_hero_block_changed(block: int) -> void:
	if block > _last_block:
		_float_text("+%d %s" % [block - _last_block, tr("BATTLE_BLOCK")], _hero_view.get_hit_point() + Vector2(0, -20), UIKit.COLOR_GREEN)
	_last_block = block


func _on_target_changed(target: EnemyUnit) -> void:
	for enemy: EnemyUnit in _enemies:
		_enemy_views[enemy].set_targeted(enemy == target)


func _on_turn_started(turn: int) -> void:
	_enemy_phase = false
	_hud.show_banner(tr("BATTLE_PLAYER_TURN"))
	AudioManager.play_sfx("korek", 0.05, -4.0)
	_refresh_intents()
	if turn == 1 and _player.first_turn_bonus_ap > 0:
		_float_text(tr("BATTLE_KENDANG") % _player.first_turn_bonus_ap, _hud.get_ap_point() + Vector2(0, -6), UIKit.COLOR_GOLD)
	if _player.prayitna:
		_hero_view.play_glow(Color(0.6, 1.0, 0.6))
		_float_text(tr("BATTLE_PRAYITNA"), _hero_view.get_top_point() + Vector2(0, 6), UIKit.COLOR_GREEN, true)


func _on_enemy_ngamuk(enemy: EnemyUnit) -> void:
	var view: UnitView = _enemy_views.get(enemy)
	if view == null:
		return
	view.play_glow(Color(1.0, 0.35, 0.25))
	AudioManager.play_sfx("hit_heavy", 0.05, -6.0)
	_float_text(tr("BATTLE_NGAMUK"), view.get_top_point() + Vector2(0, -2), UIKit.COLOR_RED, true)


func _on_enemy_spawned(enemy: EnemyUnit, summoner: EnemyUnit) -> void:
	var buto := enemy as EnemyButo
	if buto == null:
		return
	buto.position = BALA_SLOTS[_bala_spawned % BALA_SLOTS.size()]
	_bala_spawned += 1
	var view := _register_buto(buto, BALA_SCALE)
	_hook_enemy_signals(buto)
	view.show_amuk(false)
	view.set_targeted(buto == _battle.get_target())
	view.play_spawn()
	_hints.offer("bala")
	if summoner != null and summoner.position.x < HITAM_BACK_X:
		var t := summoner.create_tween()
		t.tween_property(summoner, "position:x", HITAM_BACK_X, 0.5).set_trans(Tween.TRANS_SINE)


func _on_ajian_broken(buto: EnemyButo) -> void:
	var view: UnitView = _enemy_views.get(buto)
	if view == null:
		return
	view.play_hit(Color(1.0, 0.9, 0.5))
	AudioManager.play_sfx("gong", 0.0, 3.0)
	_shake_world(3.0)
	_float_text(tr("BATTLE_AJIAN_BROKEN"), view.get_top_point() + Vector2(0, 10), UIKit.COLOR_GOLD, true)
	_refresh_intents()


func _play_phase_dialog() -> void:
	if not _phase_dialog_pending or _battle_over or _overlay.get_child_count() > 0:
		return
	_phase_dialog_pending = false
	_tooltip.hide_tip()
	await _play_dialog(PackedStringArray(["buto_hitam|S10_PHASE2_1", "eyang|S10_PHASE2_2"]))


func _on_enemy_turn_started() -> void:
	_enemy_phase = true
	_tooltip.hide_tip()
	for enemy: EnemyUnit in _enemies:
		_enemy_views[enemy].hide_intent()
	_hud.show_banner(tr("BATTLE_ENEMY_TURN"), UIKit.COLOR_RED)


func _refresh_intents() -> void:
	if _enemy_phase or _battle_over or not _battle.is_battle_running():
		return
	for enemy: EnemyUnit in _enemies:
		var view: UnitView = _enemy_views[enemy]
		if enemy.is_alive():
			var intents := enemy.get_intents(_battle)
			view.set_intents(intents)
			view.set_ngamuk_badge(enemy.get_action_count() >= 2)
			for intent: EnemyIntent in intents:
				match intent.kind:
					EnemyIntent.Kind.LOCK:
						_hints.offer("sirep")
					EnemyIntent.Kind.POISON, EnemyIntent.Kind.PLAGUE_STRIKE:
						_hints.offer("lara")
					EnemyIntent.Kind.AJIAN_CHARGE, EnemyIntent.Kind.AJIAN:
						_hints.offer("ajian")
		else:
			view.hide_intent()


func _on_ap_rejected(_requested: int, _available: int) -> void:
	AudioManager.play_sfx("error")
	_hud.shake_ap()
	_float_text(tr("BATTLE_NO_AP"), _hud.get_ap_point() + Vector2(10, -8), UIKit.COLOR_RED)


func _on_chain(_stacks: int, _multiplier: float) -> void:
	AudioManager.play_sfx("gong")
	_hud.show_banner(tr("BATTLE_CHAIN"), Color(1.0, 0.75, 0.35))


func _on_phase_changed(phase: int, buto: EnemyButo) -> void:
	if phase < 2 or not _battle.is_battle_running():
		return
	var view: UnitView = _enemy_views.get(buto)
	if view != null:
		view.play_glow(Color(1.0, 0.25, 0.2))
		view.show_amuk(buto.can_ngamuk)
		view.set_amuk(buto.amuk)
	AudioManager.play_sfx("gong", 0.0, 2.0)
	_shake_world(5.0)
	_hud.show_banner(tr("BATTLE_PHASE2"), UIKit.COLOR_RED)
	if buto.buto_type == EnemyButo.ButoType.HITAM:
		_phase_dialog_pending = true
		_hints.offer("pagebluk")


func _on_enemy_hover(view: UnitView, hovering: bool) -> void:
	if not hovering:
		_tooltip.hide_tip()
		return
	for enemy: EnemyUnit in _enemies:
		if _enemy_views[enemy] != view or not enemy.is_alive():
			continue
		var buto := enemy as EnemyButo
		var lines: Array[String] = []
		lines.append("[b][color=#ffdc80]%s[/color][/b]" % enemy.display_name)
		lines.append(tr("UNIT_HP") % [enemy.health.current_hp, enemy.health.max_hp])
		if not _enemy_phase and buto != null:
			var intents := buto.get_intents(_battle)
			if intents.size() >= 2:
				lines.append("[color=#ff6a5a]%s[/color]" % tr("INTENT_NGAMUK"))
				for intent: EnemyIntent in intents:
					lines.append("- " + _intent_text(intent))
			else:
				lines.append(_intent_text(intents[0]))
		if enemy.can_ngamuk:
			lines.append("[color=#ffb070]%s[/color]" % (tr("AMUK_TIP") % [clampi(enemy.amuk, 0, EnemyUnit.AMUK_MAX), EnemyUnit.AMUK_MAX]))
		if buto != null and buto.is_ajian_charged():
			lines.append("[color=#ffd36e]%s[/color]" % (tr("AJIAN_BREAK_TIP") % [buto.ajian_break_threshold, buto.get_ajian_progress(), buto.ajian_break_threshold]))
		if buto != null and not buto.get_living_bala().is_empty():
			lines.append("[color=#c8a8ff]%s[/color]" % tr("BALA_SHIELD_TIP"))
		if buto != null and buto.is_bala:
			lines.append("[color=#9aa0b8]%s[/color]" % tr("BALA_TIP"))
		_tooltip.show_text("\n".join(lines), view.get_top_point() + Vector2(10, 20))


func _on_hero_hover(_view: UnitView, hovering: bool) -> void:
	if not hovering:
		_tooltip.hide_tip()
		return
	var lines: Array[String] = ["[b][color=#ffdc80]%s[/color][/b]" % tr("SPEAKER_EYANG")]
	lines.append(tr("UNIT_HP") % [_hero_health.current_hp, _hero_health.max_hp])
	if _player.prayitna:
		lines.append("[color=#b8ff8c]%s[/color]" % tr("PRAYITNA_TIP"))
	if _hero_health.block > 0:
		lines.append(tr("BATTLE_BLOCK_TIP") % _hero_health.block)
	if _player.poison > 0:
		lines.append(tr("BATTLE_POISON_TIP") % [_player.poison, _player.poison])
	if _player.sirep_wards > 0:
		lines.append("[color=#ffd36e]%s[/color]" % tr("HERO_JIMAT_TIP"))
	if _player.poison_reduction > 0:
		lines.append("[color=#ffd36e]%s[/color]" % (tr("HERO_KENCUR_TIP") % _player.poison_reduction))
	_tooltip.show_text("\n".join(lines), _hero_view.get_top_point() + Vector2(10, 20))


func _intent_text(intent: EnemyIntent) -> String:
	match intent.kind:
		EnemyIntent.Kind.DRAIN:
			return tr("INTENT_DRAIN_MURKA" if intent.murka else "INTENT_DRAIN") % [intent.damage, intent.extra]
		EnemyIntent.Kind.LOCK:
			return tr("INTENT_LOCK") % intent.extra
		EnemyIntent.Kind.PLAGUE_STRIKE:
			return tr("INTENT_PLAGUE") % [intent.damage, intent.extra]
		EnemyIntent.Kind.AJIAN_CHARGE:
			return tr("INTENT_AJIAN_CHARGE") % intent.extra
		EnemyIntent.Kind.AJIAN:
			return tr("INTENT_AJIAN") % [intent.damage, intent.extra]
		EnemyIntent.Kind.SUMMON:
			return tr("INTENT_SUMMON") % intent.extra
		EnemyIntent.Kind.STAGGER:
			return tr("INTENT_STAGGER")
		EnemyIntent.Kind.POISON:
			return tr("INTENT_POISON") % [intent.damage, intent.extra]
		EnemyIntent.Kind.CHARGE:
			return tr("INTENT_CHARGE") % intent.extra
		EnemyIntent.Kind.HEAVY:
			return tr("INTENT_HEAVY") % intent.damage
	return tr("INTENT_ATTACK") % intent.damage

#endregion


#region Efek layar

func _float_text(text: String, at: Vector2, color: Color, big: bool = false) -> void:
	FloatingText.spawn(_effects, text, at, color, big)


func _screen_flash(color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(rect)
	var t := rect.create_tween()
	t.tween_property(rect, "modulate:a", 0.0, 0.45)
	t.tween_callback(rect.queue_free)


func _shake_world(strength: float) -> void:
	var t := create_tween()
	for i: int in 6:
		var off := Vector2(randf_range(-strength, strength), randf_range(-strength * 0.5, strength * 0.5))
		t.tween_property(_world, "position", off, 0.04)
		strength *= 0.75
	t.tween_property(_world, "position", Vector2.ZERO, 0.05)

#endregion


#region Dialog, jeda, dan akhir battle

func _play_dialog(lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	var box := DialogBox.new()
	_overlay.add_child(box)
	await box.play(lines)


func _open_pause() -> void:
	if _overlay.get_child_count() > 0 or _battle_over:
		return
	AudioManager.play_sfx("click")
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(UIKit.dimmer(0.65))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	root.add_child(UIKit.center(panel))
	var col := UIKit.vbox(6)
	panel.add_child(col)
	var title := UIKit.label(tr("BATTLE_PAUSED"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var help := UIKit.label(tr("BATTLE_HELP"), &"", UIKit.COLOR_DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(260, 0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(help)
	var resume := UIKit.button(tr("BTN_RESUME"), 160, true)
	var settings := UIKit.button(tr("MENU_SETTINGS"), 160, true)
	var to_map := UIKit.button(tr("BTN_TO_MAP"), 160, true)
	var to_menu := UIKit.button(tr("BTN_MAIN_MENU"), 160, true)
	for b: Button in [resume, settings, to_map, to_menu]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(b)
	_overlay.add_child(root)
	resume.pressed.connect(func() -> void:
		get_tree().paused = false
		root.queue_free())
	settings.pressed.connect(func() -> void:
		var s := SettingsPanel.new()
		root.add_child(s)
		# Buka ulang menu jeda supaya teksnya memakai bahasa yang baru.
		s.closed.connect(func() -> void:
			root.queue_free()
			_reopen_pause.call_deferred()))
	to_map.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.STAGE_MAP))
	to_menu.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU))


func _reopen_pause() -> void:
	get_tree().paused = false
	await get_tree().process_frame
	_open_pause()


func _on_battle_ended(player_won: bool) -> void:
	_battle_over = true
	_tooltip.hide_tip()
	if player_won:
		await _victory()
	else:
		await _defeat()


func _victory() -> void:
	AudioManager.play_music("victory")
	_hud.show_banner(tr("BATTLE_VICTORY"), UIKit.COLOR_GOLD)
	await get_tree().create_timer(1.6).timeout
	await _play_dialog(_stage.victory_dialog)
	var first_win := not GameState.is_stage_blessed(_stage.stage_number)
	GameState.complete_stage(_stage.stage_number)
	if _stage.stage_number >= GameState.STAGE_COUNT:
		SceneRouter.go_to(SceneRouter.ENDING)
		return
	var reward := RewardPanel.new()
	reward.stage_number = _stage.stage_number
	reward.already_received = not first_win
	_overlay.add_child(reward)
	await reward.done
	SceneRouter.go_to(SceneRouter.STAGE_MAP)


func _defeat() -> void:
	AudioManager.stop_music()
	AudioManager.play_sfx("defeat")
	await get_tree().create_timer(0.8).timeout
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(UIKit.dimmer(0.7))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	root.add_child(UIKit.center(panel))
	var col := UIKit.vbox(8)
	panel.add_child(col)
	var title := UIKit.label(tr("BATTLE_DEFEAT"), &"TitleLabel", UIKit.COLOR_RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var hint := UIKit.label(tr("BATTLE_DEFEAT_HINT"), &"BigLabel", UIKit.COLOR_TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(300, 0)
	col.add_child(hint)
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var retry := UIKit.button(tr("BTN_RETRY"), 110, true)
	var to_map := UIKit.button(tr("BTN_TO_MAP"), 110, true)
	row.add_child(retry)
	row.add_child(to_map)
	col.add_child(row)
	_overlay.add_child(root)
	retry.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.BATTLE))
	to_map.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.STAGE_MAP))

#endregion
