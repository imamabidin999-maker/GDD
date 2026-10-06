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
## - Input hanya diterima saat PLAYER_TURN sedang diam menunggu. Request di state
##   lain ditolak, jadi klik ganda saat animasi berjalan tidak bisa memotong AP
##   dua kali.
## - Request yang dipanggil dari dalam listener signal (misalnya dari ap_changed
##   atau state_changed) juga ditolak, supaya battle tidak loncat state di tengah
##   request lain. Aturan otomatis seperti "End Turn kalau AP habis" sebaiknya
##   didengarkan dari signal player_input_ready.
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

signal battle_started
## Dipancarkan setiap kali state berpindah. Kalau state barunya PLAYER_TURN di
## awal turn baru, AP dan tangan sudah siap saat signal ini terpancar.
signal state_changed(previous: State, current: State)
## Turn baru pemain dimulai. AP sudah terisi dan tangan sudah ditarik penuh.
signal turn_started(turn_number: int)
## Pemain menekan End Turn. Dipancarkan sebelum masuk ENEMY_TURN.
signal turn_ended(turn_number: int)
## PLAYER_TURN sudah stabil dan request baru boleh dikirim. Cocok untuk
## menyalakan tombol UI atau aturan otomatis seperti auto End Turn.
signal player_input_ready
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
## Kalau false, merge hanya terjadi lewat request_merge().
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
# Naik setiap start_battle(). Coroutine yang selesai menunggu animasi memakai
# nomor ini untuk memastikan battle-nya masih battle yang sama.
var _battle_id: int = 0
var _is_handling_request: bool = false

# Dipakai _change_state() supaya perpindahan state tidak saling bersarang.
var _is_changing_state: bool = false
var _has_pending_state: bool = false
var _pending_state: State = State.IDLE


#region Setup

## Memulai battle baru dengan 15 kartu deck dan daftar Buto yang sudah di-spawn.
## Mengembalikan false (dan tidak mengubah apa pun) kalau referensi belum diisi,
## data tidak valid, hero sudah mati, atau battle lain masih berjalan.
## HP hero tidak diisi ulang otomatis. Panggil hero_health.reset() kalau perlu.
func start_battle(card_list: Array[CardData], enemy_list: Array[EnemyUnit]) -> bool:
	if is_battle_running():
		push_error("BattleManager: battle masih berjalan.")
		return false
	if not _has_required_references() or not _is_valid_enemy_list(enemy_list):
		return false
	if hero_health.is_dead():
		push_error("BattleManager: HP hero 0. Panggil hero_health.reset() sebelum memulai battle.")
		return false
	if not deck.build_deck(card_list):
		return false

	# build_deck() sudah membuat 15 kartu baru, jadi sisa kartu di tangan dari
	# battle sebelumnya cukup dibuang.
	hand.take_all_cards()
	_enemies = enemy_list.duplicate()
	_action_queue.clear()
	_target = null
	turn_number = 0
	_battle_id += 1
	player.begin_battle() # nanti: oper Moxie awal & multiplier dari GameState
	_refresh_target()
	battle_started.emit()

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
	var any_alive := false
	for enemy: EnemyUnit in enemy_list:
		if not is_instance_valid(enemy) or enemy.health == null:
			push_error("BattleManager: ada musuh yang null atau belum punya HealthComponent.")
			return false
		if enemy.is_alive():
			any_alive = true
	if not any_alive:
		push_error("BattleManager: semua musuh sudah mati sebelum battle dimulai.")
		return false
	return true

#endregion


#region Query

func get_state() -> State:
	return _state


func is_battle_running() -> bool:
	return _state != State.IDLE and _state != State.VICTORY and _state != State.DEFEAT


## true hanya saat PLAYER_TURN sedang diam menunggu input. UI bisa memakai ini
## (atau signal player_input_ready) untuk mengaktifkan tombol.
func is_accepting_input() -> bool:
	return _state == State.PLAYER_TURN and not _is_changing_state and not _is_handling_request


func get_living_enemies() -> Array[EnemyUnit]:
	var living: Array[EnemyUnit] = []
	for enemy: EnemyUnit in _enemies:
		if EnemyUnit.is_valid_alive(enemy):
			living.append(enemy)
	return living


func get_target() -> EnemyUnit:
	return _target

#endregion


#region Input pemain
# Semua request mengembalikan false tanpa efek apa pun kalau ditolak.
# Sambungkan tombol UI ke fungsi-fungsi ini, misalnya:
#   end_turn_button.pressed.connect(battle_manager.request_end_turn)

func request_play_card(hand_index: int) -> bool:
	if not _begin_request():
		return false
	var card := hand.get_card(hand_index)
	if card == null or not player.consume_ap(PlayerState.AP_COST_PLAY_CARD):
		return _end_request(false)

	hand.remove_card_at(hand_index)
	_refresh_target()
	_queue_action(PlayCardAction.new(card, _target))
	return _end_request(true, State.RESOLVE_ACTIONS)


## Geser kartu cukup diselesaikan langsung di PLAYER_TURN, tanpa RESOLVE_ACTIONS,
## karena tidak ada damage dan tidak bisa mengubah hasil menang/kalah.
func request_move_card(from_index: int, to_index: int) -> bool:
	if not _begin_request():
		return false
	if not hand.is_valid_index(from_index) or not hand.is_valid_index(to_index) or from_index == to_index:
		return _end_request(false)
	if not player.consume_ap(PlayerState.AP_COST_MOVE_CARD):
		return _end_request(false)

	hand.move_card(from_index, to_index)
	if auto_merge_on_move:
		hand.merge_with_neighbor(to_index)
	return _end_request(true)


## Menggabungkan dua kartu bersebelahan secara manual. Dipakai kalau
## auto_merge_on_move = false, atau untuk kartu yang kebetulan sudah
## bersebelahan setelah draw. Untuk sekarang gratis AP.
func request_merge(index_a: int, index_b: int) -> bool:
	if not _begin_request():
		return false
	var merged := hand.merge_at(index_a, index_b)
	return _end_request(merged != null)


func request_ultimate() -> bool:
	if not _begin_request():
		return false
	if not player.is_ultimate_ready() or not player.consume_ap(ultimate_ap_cost):
		return _end_request(false)

	var spent := player.spend_moxie_for_ultimate()
	_refresh_target()
	_queue_action(UltimateAction.new(_target, spent, ultimate_base_damage))
	return _end_request(true, State.RESOLVE_ACTIONS)


func request_end_turn() -> bool:
	if not _begin_request():
		return false
	if discard_hand_on_turn_end:
		deck.discard_cards(hand.take_all_cards())
	turn_ended.emit(turn_number)
	return _end_request(true, State.ENEMY_TURN)


## Mengunci target serangan (gaya Reverse: 1999). Gagal di luar PLAYER_TURN,
## atau kalau Buto itu bukan bagian dari battle ini atau sudah mati.
func select_target(enemy: EnemyUnit) -> bool:
	if not is_accepting_input() or not _enemies.has(enemy) or not EnemyUnit.is_valid_alive(enemy):
		return false
	_set_target(enemy)
	return true


# Mengunci input selama satu request diproses. Signal yang terpancar di tengah
# request (ap_changed, hand_changed, action_queued, ...) jadi tidak bisa memicu
# request lain.
func _begin_request() -> bool:
	if not is_accepting_input():
		return false
	_is_handling_request = true
	return true


# Membuka kunci, lalu pindah ke next_state kalau request diterima. Kalau
# state-nya tetap PLAYER_TURN (geser/merge), player_input_ready dipancarkan lagi
# supaya UI tahu input sudah terbuka.
func _end_request(accepted: bool, next_state: State = State.PLAYER_TURN) -> bool:
	_is_handling_request = false
	if accepted:
		if next_state == State.PLAYER_TURN:
			player_input_ready.emit()
		else:
			_change_state(next_state)
	return accepted

#endregion


#region Presentasi

## Dipanggil setiap BattleAction setelah efeknya diterapkan. Untuk sekarang
## hanya menunggu presentation_delay. Nanti diganti dengan menunggu animasi
## asli dari view, misalnya sampai view memancarkan signal "animasi selesai".
func present_action(action: BattleAction) -> void:
	action_presentation_started.emit(action)
	if presentation_delay > 0.0 and is_inside_tree():
		# process_always = false: timer ikut berhenti saat game di-pause.
		await get_tree().create_timer(presentation_delay, false).timeout

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

		# Turn baru disiapkan SEBELUM diumumkan, supaya pendengar state_changed
		# sudah melihat AP penuh dan tangan yang sudah ditarik.
		var is_new_turn := _state == State.PLAYER_TURN and _needs_turn_setup
		if is_new_turn:
			_setup_new_player_turn()
		state_changed.emit(previous, _state)
		if is_new_turn:
			turn_started.emit(turn_number)

		_enter_state(_state)
	_is_changing_state = false

	if _state == State.PLAYER_TURN:
		player_input_ready.emit()


func _enter_state(state: State) -> void:
	match state:
		State.PLAYER_TURN:
			pass # AP & kartu sudah disiapkan di _change_state(); tinggal menunggu input
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


## PLAYER_TURN (turn baru): isi ulang AP dan tarik kartu sampai tangan penuh.
func _setup_new_player_turn() -> void:
	_needs_turn_setup = false
	turn_number += 1
	player.start_turn()
	deck.fill_hand(hand)


## ENEMY_TURN: setiap Buto yang masih hidup memilih aksi, lalu semuanya diantre.
## decide_action() boleh memakai await (misalnya AI yang "berpikir" dulu).
func _enter_enemy_turn() -> void:
	var battle_id := _battle_id
	enemy_turn_started.emit()
	for enemy: EnemyUnit in get_living_enemies():
		@warning_ignore("redundant_await")
		var action: BattleAction = await enemy.decide_action(self)
		if _is_stale(battle_id, State.ENEMY_TURN):
			return
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

	var battle_id := _battle_id
	var action: BattleAction = _action_queue.pop_front()
	if action.is_valid():
		await action.execute(self)
		if _is_stale(battle_id, State.RESOLVE_ACTIONS):
			return
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


# true kalau, setelah sebuah await, battle-nya sudah berganti atau state sudah
# dipindah pihak lain. Coroutine yang basi tidak boleh menggerakkan state lagi.
func _is_stale(battle_id: int, expected_state: State) -> bool:
	return battle_id != _battle_id or _state != expected_state

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
