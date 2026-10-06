class_name BattleManager
extends Node
## Pengatur jalannya pertarungan memakai state machine sederhana berbasis enum.
##
## Alur state:
##   PLAYER_TURN ──main kartu / Ultimate──► RESOLVE_ACTIONS ──► CHECK_WIN_LOSE
##   PLAYER_TURN ──End Turn──► ENEMY_TURN ──► RESOLVE_ACTIONS ──► CHECK_WIN_LOSE
##   CHECK_WIN_LOSE ──► VICTORY / DEFEAT, atau
##                  ──► RESOLVE_ACTIONS kalau antrean aksi belum habis, atau
##                  ──► PLAYER_TURN (lanjut menunggu input, atau turn baru setelah musuh)
##
## Aturan yang dipegang:
## - Hanya PLAYER_TURN yang menerima input. Request di state lain ditolak, jadi
##   klik ganda saat animasi berjalan tidak bisa memotong AP dua kali.
## - State hanya berpindah lewat _change_state(). Signal dipakai untuk
##   MENGUMUMKAN perpindahan itu ke UI, audio, dan sistem lain.
## - RESOLVE_ACTIONS menyelesaikan SATU aksi per kunjungan, lalu selalu lewat
##   CHECK_WIN_LOSE. Kalau hero tumbang oleh Buto pertama, Buto berikutnya
##   tidak sempat menyerang.

enum State {
	IDLE, ## Belum ada battle
	PLAYER_TURN, ## Menunggu input pemain
	RESOLVE_ACTIONS, ## Menghitung damage satu aksi dan menunggu animasinya
	CHECK_WIN_LOSE, ## Mengecek HP hero & Buto, lalu memilih state berikutnya
	ENEMY_TURN, ## Setiap Buto yang masih hidup memilih aksinya
	VICTORY,
	DEFEAT,
}

## Dipancarkan setiap kali state berpindah. Sumber utama UI untuk tahu fase battle.
signal state_changed(previous: State, current: State)
## Turn baru pemain dimulai. AP sudah terisi dan tangan sudah ditarik penuh.
signal turn_started(turn_number: int)
signal enemy_turn_started
signal action_queued(action: BattleAction)
## View memutar animasi aksi ini. Lihat present_action().
signal action_presentation_started(action: BattleAction)
signal action_resolved(action: BattleAction)
signal target_changed(enemy: EnemyUnit)
signal battle_ended(player_won: bool)

@export_group("Referensi")
@export var deck: DeckController
@export var hand: HandManager
@export var player: PlayerState
@export var hero_health: HealthComponent

@export_group("Aturan")
## Gabungkan otomatis kartu yang baru digeser dengan tetangga yang cocok.
@export var auto_merge_on_move: bool = true
## true: sisa kartu di tangan dibuang saat End Turn (gaya FGO).
## false: kartu disimpan ke turn berikutnya (gaya Reverse: 1999).
@export var discard_hand_on_turn_end: bool = false
@export_range(0, 10) var ultimate_ap_cost: int = 0
@export var ultimate_base_damage: int = 100

@export_group("Presentasi")
## Jeda sementara per aksi (detik) sebagai pengganti animasi. 0 = tanpa jeda.
@export_range(0.0, 3.0, 0.05) var presentation_delay: float = 0.4

var turn_number: int = 0

var _state: State = State.IDLE
var _enemies: Array[EnemyUnit] = []
var _action_queue: Array[BattleAction] = []
var _target: EnemyUnit
# true kalau PLAYER_TURN berikutnya adalah turn baru (AP diisi, kartu ditarik).
# false kalau hanya kembali ke PLAYER_TURN setelah aksi pemain selesai di-resolve.
var _needs_turn_setup: bool = false

# Dipakai _change_state() supaya perpindahan state tidak saling bersarang.
var _is_changing_state: bool = false
var _has_pending_state: bool = false
var _pending_state: State = State.IDLE


#region Setup

## Memulai battle baru dengan 15 kartu deck dan daftar Buto yang sudah di-spawn.
## Mengembalikan false kalau referensi belum diisi, data tidak valid, atau
## battle lain masih berjalan.
func start_battle(card_list: Array[CardData], enemy_list: Array[EnemyUnit]) -> bool:
	if is_battle_running():
		push_error("BattleManager: battle masih berjalan.")
		return false
	if not _has_required_references() or not _is_valid_enemy_list(enemy_list):
		return false

	hand.take_all_cards()
	if not deck.build_deck(card_list):
		return false

	_enemies = enemy_list.duplicate()
	_action_queue.clear()
	_target = null
	turn_number = 0
	player.begin_battle() # nanti: oper Moxie awal & multiplier dari GameState
	_refresh_target()

	_needs_turn_setup = true
	_change_state(State.PLAYER_TURN)
	return true


func _has_required_references() -> bool:
	var missing: PackedStringArray = []
	if deck == null:
		missing.append("deck")
	if hand == null:
		missing.append("hand")
	if player == null:
		missing.append("player")
	if hero_health == null:
		missing.append("hero_health")
	if not missing.is_empty():
		push_error("BattleManager: referensi belum diisi di Inspector: %s." % ", ".join(missing))
		return false
	return true


func _is_valid_enemy_list(enemy_list: Array[EnemyUnit]) -> bool:
	if enemy_list.is_empty():
		push_error("BattleManager: daftar musuh kosong.")
		return false
	for enemy: EnemyUnit in enemy_list:
		if not is_instance_valid(enemy) or enemy.health == null:
			push_error("BattleManager: ada musuh yang null atau belum punya HealthComponent.")
			return false
	return true

#endregion


#region Query

func get_state() -> State:
	return _state


func is_battle_running() -> bool:
	return _state != State.IDLE and _state != State.VICTORY and _state != State.DEFEAT


## true hanya di PLAYER_TURN. UI bisa memakai ini untuk mengaktifkan tombol.
func is_accepting_input() -> bool:
	return _state == State.PLAYER_TURN


func get_living_enemies() -> Array[EnemyUnit]:
	var living: Array[EnemyUnit] = []
	for enemy: EnemyUnit in _enemies:
		if EnemyUnit.is_valid_alive(enemy):
			living.append(enemy)
	return living


func get_target() -> EnemyUnit:
	return _target


## Mengunci target serangan (gaya Reverse: 1999). Gagal kalau Buto itu bukan
## bagian dari battle ini atau sudah mati.
func select_target(enemy: EnemyUnit) -> bool:
	if not is_battle_running() or not _enemies.has(enemy) or not EnemyUnit.is_valid_alive(enemy):
		return false
	_set_target(enemy)
	return true

#endregion


#region Input pemain
# Semua request mengembalikan false tanpa efek apa pun kalau ditolak.
# Sambungkan tombol UI ke fungsi-fungsi ini, misalnya:
#   end_turn_button.pressed.connect(battle_manager.request_end_turn)

func request_play_card(hand_index: int) -> bool:
	if not is_accepting_input():
		return false
	var card := hand.get_card(hand_index)
	if card == null:
		return false
	if not player.consume_ap(PlayerState.AP_COST_PLAY_CARD):
		return false

	hand.remove_card_at(hand_index)
	_refresh_target()
	_queue_action(PlayCardAction.new(card, _target))
	_change_state(State.RESOLVE_ACTIONS)
	return true


## Geser kartu cukup diselesaikan langsung di PLAYER_TURN, tanpa RESOLVE_ACTIONS,
## karena tidak ada damage dan tidak bisa mengubah hasil menang/kalah.
func request_move_card(from_index: int, to_index: int) -> bool:
	if not is_accepting_input():
		return false
	if not hand.is_valid_index(from_index) or not hand.is_valid_index(to_index) or from_index == to_index:
		return false
	if not player.consume_ap(PlayerState.AP_COST_MOVE_CARD):
		return false

	hand.move_card(from_index, to_index)
	if auto_merge_on_move:
		hand.merge_with_neighbor(to_index)
	return true


func request_ultimate() -> bool:
	if not is_accepting_input() or not player.is_ultimate_ready():
		return false
	if not player.consume_ap(ultimate_ap_cost):
		return false

	var spent := player.spend_moxie_for_ultimate()
	_refresh_target()
	_queue_action(UltimateAction.new(_target, spent, ultimate_base_damage))
	_change_state(State.RESOLVE_ACTIONS)
	return true


func request_end_turn() -> bool:
	if not is_accepting_input():
		return false
	if discard_hand_on_turn_end:
		deck.discard_cards(hand.take_all_cards())
	_change_state(State.ENEMY_TURN)
	return true

#endregion


#region Presentasi

## Dipanggil setiap BattleAction setelah efeknya diterapkan. Untuk sekarang
## hanya menunggu presentation_delay. Nanti diganti dengan menunggu animasi
## asli, misalnya: await animation_player.animation_finished
func present_action(action: BattleAction) -> void:
	action_presentation_started.emit(action)
	if presentation_delay > 0.0 and is_inside_tree():
		await get_tree().create_timer(presentation_delay).timeout

#endregion


#region State machine

## Satu-satunya pintu untuk berpindah state.
##
## Kalau dipanggil dari dalam handler state lain (misalnya CHECK_WIN_LOSE yang
## langsung memilih state berikutnya), perpindahannya diantre dulu dan baru
## dijalankan setelah handler itu selesai. Dengan begitu handler tidak saling
## bersarang dan urutan signal state_changed selalu rapi.
func _change_state(next: State) -> void:
	if _is_changing_state:
		if _has_pending_state:
			push_warning("BattleManager: perpindahan ke %s menimpa %s yang belum jalan." \
				% [State.keys()[next], State.keys()[_pending_state]])
		_pending_state = next
		_has_pending_state = true
		return

	_is_changing_state = true
	_pending_state = next
	_has_pending_state = true
	while _has_pending_state:
		_has_pending_state = false
		var previous := _state
		_state = _pending_state
		state_changed.emit(previous, _state)
		_enter_state(_state)
	_is_changing_state = false


func _enter_state(state: State) -> void:
	match state:
		State.PLAYER_TURN:
			_enter_player_turn()
		State.RESOLVE_ACTIONS:
			_enter_resolve_actions()
		State.CHECK_WIN_LOSE:
			_enter_check_win_lose()
		State.ENEMY_TURN:
			_enter_enemy_turn()
		State.VICTORY:
			_enter_battle_end(true)
		State.DEFEAT:
			_enter_battle_end(false)


## PLAYER_TURN: isi ulang AP, tarik kartu sampai tangan penuh, lalu tunggu input.
func _enter_player_turn() -> void:
	if not _needs_turn_setup:
		return # baru selesai me-resolve aksi pemain, lanjut menunggu input

	_needs_turn_setup = false
	turn_number += 1
	player.start_turn()
	deck.fill_hand(hand)
	turn_started.emit(turn_number)


## ENEMY_TURN: setiap Buto yang masih hidup memilih aksi, lalu semuanya diantre.
func _enter_enemy_turn() -> void:
	enemy_turn_started.emit()
	for enemy: EnemyUnit in get_living_enemies():
		var action := enemy.decide_action(self)
		if action != null:
			_queue_action(action)

	# Setelah semua aksi Buto selesai, PLAYER_TURN berikutnya adalah turn baru.
	_needs_turn_setup = true
	_change_state(State.RESOLVE_ACTIONS)


## RESOLVE_ACTIONS: jalankan satu aksi dari antrean dan tunggu animasinya.
## Fungsi ini coroutine. Selama animasi berjalan, state tetap RESOLVE_ACTIONS
## sehingga semua input pemain ditolak.
func _enter_resolve_actions() -> void:
	if _action_queue.is_empty():
		_change_state(State.CHECK_WIN_LOSE)
		return

	var action: BattleAction = _action_queue.pop_front()
	if action.is_valid():
		await action.execute(self)
		action_resolved.emit(action)
	_change_state(State.CHECK_WIN_LOSE)


## CHECK_WIN_LOSE: cek HP lalu pilih state berikutnya.
func _enter_check_win_lose() -> void:
	_refresh_target()

	# Hero dicek lebih dulu: kalau hero dan Buto terakhir tumbang bersamaan,
	# pemain dianggap kalah. Tukar urutannya kalau ingin sebaliknya.
	if hero_health.is_dead():
		_change_state(State.DEFEAT)
	elif get_living_enemies().is_empty():
		_change_state(State.VICTORY)
	elif not _action_queue.is_empty():
		_change_state(State.RESOLVE_ACTIONS)
	else:
		_change_state(State.PLAYER_TURN)


func _enter_battle_end(player_won: bool) -> void:
	_action_queue.clear()
	battle_ended.emit(player_won)

#endregion


#region Helper

func _queue_action(action: BattleAction) -> void:
	_action_queue.append(action)
	action_queued.emit(action)


## Kalau target sekarang sudah mati (atau belum ada), pindah ke Buto pertama
## yang masih hidup.
func _refresh_target() -> void:
	if EnemyUnit.is_valid_alive(_target):
		return
	var living := get_living_enemies()
	_set_target(living[0] if not living.is_empty() else null)


func _set_target(enemy: EnemyUnit) -> void:
	if enemy == _target:
		return
	_target = enemy
	target_changed.emit(enemy)

#endregion
