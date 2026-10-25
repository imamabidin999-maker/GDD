class_name HandView
extends Control
## Tampilan tangan pemain: menata CardView, menangani klik (main kartu),
## seret (geser kartu atau main ke Buto tertentu), dan tombol gabung gratis.
##
## Semua aksi diteruskan ke BattleManager lewat request_*. Kalau ditolak
## (AP kurang, kartu terkunci, bukan giliran pemain), kartu kembali ke tempatnya.

## Dipancarkan saat kartu dimainkan dengan diseret ke Buto tertentu.
signal play_on_enemy_requested(hand_index: int, global_point: Vector2)
signal card_hovered(view: CardView)
signal card_unhovered(view: CardView)
## Kartu terkunci dicoba digeser.
## Pemain mencoba memakai atau menggeser kartu yang tersirep.
signal sirep_card_touched(view: CardView)

const CARD_STEP_MAX := 70.0
const HOVER_RAISE := 14.0
const DRAG_THRESHOLD := 5.0
const MERGE_ICON := preload("res://assets/ui/mini_chain.png")

var battle: BattleManager
var hand: HandManager
var player: PlayerState
## Titik asal kartu baru (tumpukan dek di layar).
var deck_point := Vector2(40, 300)

var _views: Dictionary = {} # uid -> CardView
var _merge_buttons: Array[Button] = []
var _rebuild_queued: bool = false
var _pressed_view: CardView
var _press_point := Vector2.ZERO
## Posisi mouse terakhir dari event (dalam koordinat viewport).
var _mouse := Vector2.ZERO
var _dragging: bool = false
var _drag_offset := Vector2.ZERO
var _insert_marker: ColorRect


func setup(battle_manager: BattleManager) -> void:
	battle = battle_manager
	hand = battle.hand
	player = battle.player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insert_marker = ColorRect.new()
	_insert_marker.color = Color(1.0, 0.86, 0.4, 0.9)
	_insert_marker.size = Vector2(2, 96)
	_insert_marker.visible = false
	_insert_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insert_marker.z_index = 20
	add_child(_insert_marker)
	hand.hand_changed.connect(_queue_rebuild)
	hand.card_lock_changed.connect(func(_c: CardInstance, _l: bool) -> void: _queue_rebuild())
	player.moxie_changed.connect(func(_v: float) -> void: _queue_rebuild())
	player.prayitna_changed.connect(func(_on: bool) -> void: _queue_rebuild())
	_queue_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


#region Tata letak

func _rebuild() -> void:
	_rebuild_queued = false
	var cards := hand.get_cards()
	var alive: Dictionary = {}
	for card: CardInstance in cards:
		alive[card.uid] = card

	# Kartu yang keluar dari tangan: bergabung jadi hybrid, atau dimainkan/dibuang.
	for uid: int in _views.keys():
		if alive.has(uid):
			continue
		var view: CardView = _views[uid]
		_views.erase(uid)
		_animate_leave(view, cards)

	# Kartu baru masuk dari tumpukan dek (atau muncul di tempat kalau hasil merge).
	for card: CardInstance in cards:
		var view: CardView = _views.get(card.uid)
		if view == null:
			view = _create_view(card)
			_views[card.uid] = view
			if card.is_hybrid():
				view.scale = Vector2(1.25, 1.25)
				view.modulate = Color(2, 2, 2)
				var pop := view.create_tween().set_parallel(true)
				pop.tween_property(view, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
				pop.tween_property(view, "modulate", Color.WHITE, 0.35)
			else:
				view.position = deck_point - global_position
				view.modulate.a = 0.0
		view.moxie_gain = player.get_moxie_gain_from_card(card)
		view.shield_value = player.get_card_shield(card)
		view.refresh()

	_layout(true)
	_rebuild_merge_buttons()


func _create_view(card: CardInstance) -> CardView:
	var view := CardView.new()
	add_child(view)
	view.setup(card, player.get_moxie_gain_from_card(card))
	view.pressed.connect(_on_card_pressed)
	view.hover_changed.connect(_on_card_hover)
	return view


func _slot_positions(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count == 0:
		return result
	var card_w := CardView.CARD_SIZE.x
	var step := CARD_STEP_MAX
	if count > 1:
		step = minf(CARD_STEP_MAX, (size.x - card_w) / float(count - 1))
	var total := step * (count - 1) + card_w
	var start_x := (size.x - total) * 0.5
	for i: int in count:
		result.append(Vector2(start_x + step * i, 0))
	return result


func _layout(animate: bool) -> void:
	var cards := hand.get_cards()
	var slots := _slot_positions(cards.size())
	for i: int in cards.size():
		var view: CardView = _views.get(cards[i].uid)
		if view == null or (view == _pressed_view and _dragging):
			continue
		var target := slots[i]
		if view.hovering and not _dragging:
			target.y -= HOVER_RAISE
		view.slot_position = target
		view.z_index = 10 if view.hovering else i
		if animate:
			var t := view.create_tween().set_parallel(true)
			t.tween_property(view, "position", target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(view, "modulate:a", 1.0, 0.16)
		else:
			view.position = target


func _rebuild_merge_buttons() -> void:
	for b: Button in _merge_buttons:
		b.queue_free()
	_merge_buttons.clear()
	var cards := hand.get_cards()
	for view: Variant in _views.values():
		(view as CardView).mergeable = false
	var slots := _slot_positions(cards.size())
	for i: int in range(cards.size() - 1):
		if not hand.can_merge_at(i, i + 1):
			continue
		(_views[cards[i].uid] as CardView).mergeable = true
		(_views[cards[i + 1].uid] as CardView).mergeable = true
		var b := Button.new()
		b.icon = MERGE_ICON
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = tr("BATTLE_MERGE_TIP")
		b.custom_minimum_size = Vector2(18, 16)
		b.size = Vector2(18, 16)
		var left := slots[i]
		var right := slots[i + 1]
		var mid_x := (left.x + CardView.CARD_SIZE.x + right.x) * 0.5
		b.position = Vector2(mid_x - 9, -12)
		b.z_index = 30
		var a := i
		b.pressed.connect(func() -> void:
			if battle.request_merge(a, a + 1):
				AudioManager.play_sfx("dongkrek", 0.02))
		add_child(b)
		_merge_buttons.append(b)


func _animate_leave(view: CardView, cards_now: Array[CardInstance]) -> void:
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.z_index = 40
	# Kalau kartu ini bahan hybrid yang baru jadi, terbang ke kartu hybrid itu.
	for card: CardInstance in cards_now:
		if card.components.has(view.card):
			var slots := _slot_positions(cards_now.size())
			var idx := cards_now.find(card)
			var t := view.create_tween().set_parallel(true)
			t.tween_property(view, "position", slots[idx], 0.18)
			t.tween_property(view, "modulate:a", 0.0, 0.2)
			t.chain().tween_callback(view.queue_free)
			return
	var up := view.create_tween().set_parallel(true)
	up.tween_property(view, "position", view.position + Vector2(0, -70), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(view, "modulate:a", 0.0, 0.25)
	up.chain().tween_callback(view.queue_free)

#endregion


#region Input

func _on_card_hover(view: CardView, hovering: bool) -> void:
	if _dragging:
		return
	if hovering:
		card_hovered.emit(view)
	else:
		card_unhovered.emit(view)
	_layout(true)


func _on_card_pressed(view: CardView) -> void:
	_pressed_view = view
	_press_point = _mouse
	_dragging = false
	_drag_offset = _press_point - view.global_position


func _input(event: InputEvent) -> void:
	# _input menerima event sebelum kartu (_gui_input), jadi posisi ini sudah
	# terisi saat _on_card_pressed dipanggil. Koordinatnya koordinat viewport,
	# sama dengan koordinat global HUD (CanvasLayer tanpa offset).
	var mouse_event := event as InputEventMouse
	if mouse_event != null:
		_mouse = mouse_event.position
	if _pressed_view == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var point := _mouse
		if not _dragging and point.distance_to(_press_point) > DRAG_THRESHOLD:
			if _pressed_view.card.is_locked():
				_reject_sirep(_pressed_view)
				_pressed_view = null
				return
			_dragging = true
			_pressed_view.z_index = 50
			card_unhovered.emit(_pressed_view)
		if _dragging:
			_pressed_view.global_position = point - _drag_offset
			_update_insert_marker(point)
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		_release(_mouse)


func _release(point: Vector2) -> void:
	var view := _pressed_view
	_pressed_view = null
	_insert_marker.visible = false
	var index := hand.index_of(view.card)
	if index < 0:
		_dragging = false
		return
	if not _dragging:
		if view.card.is_locked():
			_reject_sirep(view)
		else:
			battle.request_play_card(index)
		return
	_dragging = false
	var hand_rect := get_global_rect().grow_individual(0, 30, 0, 0)
	if not hand_rect.has_point(point):
		# Dilepas di medan tempur: main kartu ke Buto di titik itu (kalau ada).
		play_on_enemy_requested.emit(index, point)
	else:
		var to := _insert_index(point.x, view)
		if to != index:
			battle.request_move_card(index, to)
	_layout(true)


func _insert_index(global_x: float, dragged: CardView) -> int:
	var count := 0
	for card: CardInstance in hand.get_cards():
		var v: CardView = _views.get(card.uid)
		if v == null or v == dragged:
			continue
		if v.global_position.x + CardView.CARD_SIZE.x * 0.5 < global_x:
			count += 1
	return count


func _update_insert_marker(point: Vector2) -> void:
	var hand_rect := get_global_rect().grow_individual(0, 30, 0, 0)
	if not hand_rect.has_point(point):
		_insert_marker.visible = false
		return
	var to := _insert_index(point.x, _pressed_view)
	var others: Array[CardView] = []
	for card: CardInstance in hand.get_cards():
		var v: CardView = _views.get(card.uid)
		if v != null and v != _pressed_view:
			others.append(v)
	var x := 0.0
	if others.is_empty():
		x = size.x * 0.5
	elif to >= others.size():
		x = others[-1].position.x + CardView.CARD_SIZE.x + 1
	else:
		x = others[to].position.x - 2
	_insert_marker.position = Vector2(x, 4)
	_insert_marker.visible = true


func _shake(view: CardView) -> void:
	var base := view.position
	var t := view.create_tween()
	for i: int in 4:
		t.tween_property(view, "position:x", base.x + (3.0 if i % 2 == 0 else -3.0), 0.035)
	t.tween_property(view, "position:x", base.x, 0.035)


func _reject_sirep(view: CardView) -> void:
	sirep_card_touched.emit(view)
	_shake(view)


## Kartu tersirep yang dipilih lewat keyboard: bergetar dan memberi tahu pemain.
func reject_sirep_at(index: int) -> void:
	var cards := hand.get_cards()
	if index >= 0 and index < cards.size():
		var v: CardView = _views.get(cards[index].uid)
		if v != null:
			_reject_sirep(v)


## Dipakai kalau aksi ditolak, supaya kartu yang sedang disorot ikut bergetar.
func shake_card_at(index: int) -> void:
	var cards := hand.get_cards()
	if index >= 0 and index < cards.size():
		var v: CardView = _views.get(cards[index].uid)
		if v != null:
			_shake(v)

#endregion
