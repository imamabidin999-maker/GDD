class_name PlayerState
extends Node
## Variabel karakter pemain selama SATU battle: Action Points, Moxie, dan
## Evolutionary Chain.
##
## Node ini menggabungkan APController dan MoxieController dari rancangan awal,
## karena game ini memakai satu karakter. HP diurus HealthComponent milik hero.
##
## Siapa memanggil apa (semuanya dari BattleManager):
##   begin_battle()          sekali, di start_battle()
##   start_turn()            di awal setiap turn baru PLAYER_TURN: AP diisi ulang, riwayat turn direset
##   consume_ap()            di request_play_card() / request_move_card() / request_ultimate()
##   register_card_played()  di PlayCardAction._apply() setelah kartu dimainkan

signal ap_changed(current: int, maximum: int)
## Aksi ditolak karena AP kurang. Bisa dipakai UI untuk membuat pip AP berkedip.
signal ap_rejected(requested: int, available: int)
signal moxie_changed(value: float)
## Moxie baru saja menyentuh 100%.
signal ultimate_ready
## Moxie baru saja menyentuh 200%.
signal overcharge_full
signal evolutionary_chain_triggered(stacks: int, multiplier: float)
## Moxie Overcharge berkurang karena efek musuh (misalnya serangan Buto Kuning).
signal overcharge_drained(amount: float)

const AP_COST_PLAY_CARD: int = 1
const AP_COST_MOVE_CARD: int = 1

const MOXIE_NORMAL_CAP: float = 100.0
const MOXIE_MAX: float = 200.0

## Jumlah kartu bintang maksimal yang dibutuhkan untuk memicu Evolutionary Chain.
const CHAIN_LENGTH: int = 3

@export_group("Action Points")
## AP per turn. Ini nilai sementara sampai keputusan desain nomor 5 dikunci.
@export_range(1, 10) var max_ap: int = 4

@export_group("Moxie")
## Moxie dari kartu yang mengandung Fokus, berdasarkan rank kartunya:
## index 0 = ★1, index 1 = ★2, index 2 = ★3.
## Nantinya pindah ke MoxieGainEffect di CardData.
@export var fokus_moxie_by_rank: Array[float] = [10.0, 15.0, 25.0]

@export_group("Evolutionary Chain")
## true: 3 kartu bintang maksimal harus dimainkan berturut-turut.
## false: cukup 3 kartu bintang maksimal di mana saja dalam turn yang sama.
@export var chain_requires_consecutive: bool = true
## Tambahan ultimate_damage_multiplier setiap kali chain terpicu.
@export var evolution_bonus: float = 0.25
## Batas atas multiplier supaya tidak menumpuk tanpa batas di battle yang panjang.
@export var max_ultimate_damage_multiplier: float = 3.0

var current_ap: int = 0:
	set(value):
		current_ap = maxi(value, 0)
		ap_changed.emit(current_ap, max_ap)

## Moxie dalam persen, 0–200. Nilai di atas 100 berarti overcharge.
## Setiap perubahan otomatis di-clamp dan memancarkan signal.
var moxie: float = 0.0:
	set(value):
		var previous := moxie
		moxie = clampf(value, 0.0, MOXIE_MAX)
		if is_equal_approx(previous, moxie):
			return
		moxie_changed.emit(moxie)
		if previous < MOXIE_NORMAL_CAP and moxie >= MOXIE_NORMAL_CAP:
			ultimate_ready.emit()
		if previous < MOXIE_MAX and moxie >= MOXIE_MAX:
			overcharge_full.emit()

## Pengali damage Ultimate. Naik permanen lewat Evolutionary Chain dan tidak
## direset setiap turn. Kalau ingin terbawa ke battle berikutnya, simpan
## nilainya di GameState lalu oper lewat begin_battle().
var ultimate_damage_multiplier: float = 1.0
## Berapa kali Evolutionary Chain sudah terpicu di battle ini.
var evolution_stacks: int = 0

var _played_this_turn: Array[CardInstance] = []
var _chain_triggered_this_turn: bool = false


#region Siklus battle & turn

## Menyiapkan state untuk battle baru.
func begin_battle(starting_moxie: float = 0.0, starting_multiplier: float = 1.0) -> void:
	ultimate_damage_multiplier = starting_multiplier
	evolution_stacks = 0
	moxie = starting_moxie
	start_turn()


## Dipanggil di awal setiap turn pemain.
func start_turn() -> void:
	_played_this_turn.clear()
	_chain_triggered_this_turn = false
	refill_ap()

#endregion


#region Action Points

func refill_ap() -> void:
	current_ap = max_ap


func can_afford(amount: int) -> bool:
	return amount >= 0 and current_ap >= amount


## Memotong AP sebanyak amount. Kalau AP tidak cukup, aksi ditolak: fungsi
## mengembalikan false, AP tidak berubah, dan signal ap_rejected dipancarkan.
##
## Validasi aksinya (index kartu, target) sebaiknya dilakukan SEBELUM memanggil
## fungsi ini, supaya AP tidak terpotong untuk aksi yang ternyata gagal.
func consume_ap(amount: int) -> bool:
	if amount < 0:
		push_error("PlayerState: consume_ap() menerima nilai negatif (%d)." % amount)
		return false
	if not can_afford(amount):
		ap_rejected.emit(amount, current_ap)
		return false
	if amount > 0:
		current_ap -= amount
	return true

#endregion


#region Moxie

## Menambah Moxie dan mengembalikan jumlah yang benar-benar masuk.
## allow_overcharge = false dipakai untuk sumber Moxie yang hanya boleh
## mengisi sampai 100%. Moxie yang sudah di atas 100% tidak dikurangi.
func gain_moxie(amount: float, allow_overcharge: bool = true) -> float:
	if amount <= 0.0:
		return 0.0
	var cap: float = MOXIE_MAX if allow_overcharge else maxf(MOXIE_NORMAL_CAP, moxie)
	var before := moxie
	moxie = minf(moxie + amount, cap)
	return moxie - before


func is_ultimate_ready() -> bool:
	return moxie >= MOXIE_NORMAL_CAP


func is_overcharged() -> bool:
	return moxie > MOXIE_NORMAL_CAP


## Mengurangi bagian Overcharge saja, yaitu Moxie di atas 100%. Lewat fungsi
## ini Moxie tidak pernah turun di bawah 100%, jadi Ultimate yang sudah siap
## tetap siap. Mengembalikan jumlah yang benar-benar terkuras.
## Disambungkan ke signal overcharge_drain_requested milik Buto Kuning.
func drain_overcharge(amount: float) -> float:
	if amount <= 0.0 or moxie <= MOXIE_NORMAL_CAP:
		return 0.0
	var before := moxie
	moxie = maxf(moxie - amount, MOXIE_NORMAL_CAP)
	var drained := before - moxie
	overcharge_drained.emit(drained)
	return drained


## Menghabiskan seluruh Moxie untuk Ultimate. Mengembalikan jumlah yang dipakai
## (100–200), atau 0 kalau Moxie belum 100%.
## Contoh rumus di DamageCalculator nanti:
##   base_damage × ultimate_damage_multiplier × (spent / 100)
func spend_moxie_for_ultimate() -> float:
	if not is_ultimate_ready():
		return 0.0
	var spent := moxie
	moxie = 0.0
	return spent


## Berapa Moxie yang didapat dari memainkan kartu ini.
## Kartu Fokus memberi Moxie. Kartu hybrid yang mengandung Fokus (Crimson Focus,
## Flow State) juga memberi Moxie, jadi pemain tidak rugi Moxie karena merge.
func get_moxie_gain_from_card(card: CardInstance) -> float:
	if card == null or fokus_moxie_by_rank.is_empty():
		return 0.0
	if not _contains_type(card, CardData.CardType.FOKUS):
		return 0.0
	var rank_index := clampi(card.get_rank() - 1, 0, fokus_moxie_by_rank.size() - 1)
	return fokus_moxie_by_rank[rank_index]


func _contains_type(card: CardInstance, card_type: CardData.CardType) -> bool:
	for base_card: CardInstance in card.get_base_cards():
		if base_card.get_type() == card_type:
			return true
	return false

#endregion


#region Evolutionary Chain

## Mencatat kartu yang baru dimainkan, menambah Moxie kalau kartunya Fokus,
## lalu mengecek Evolutionary Chain.
func register_card_played(card: CardInstance) -> void:
	if card == null:
		return
	_played_this_turn.append(card)
	gain_moxie(get_moxie_gain_from_card(card))
	check_evolutionary_chain()


## Evolutionary Chain: kalau di turn ini pemain sudah memainkan 3 kartu dengan
## rank maksimal (★3), ultimate_damage_multiplier naik secara permanen.
## Hanya bisa terpicu sekali per turn. Mengembalikan true kalau buff diberikan.
func check_evolutionary_chain() -> bool:
	if _chain_triggered_this_turn:
		return false
	if _count_chain_cards() < CHAIN_LENGTH:
		return false

	_chain_triggered_this_turn = true
	evolution_stacks += 1
	ultimate_damage_multiplier = minf(
		ultimate_damage_multiplier + evolution_bonus,
		max_ultimate_damage_multiplier
	)
	evolutionary_chain_triggered.emit(evolution_stacks, ultimate_damage_multiplier)
	return true


## Progres chain untuk UI, misalnya "Evolutionary Chain 2/3".
func get_chain_progress() -> int:
	if _chain_triggered_this_turn:
		return CHAIN_LENGTH
	return mini(_count_chain_cards(), CHAIN_LENGTH)


func get_cards_played_this_turn() -> int:
	return _played_this_turn.size()


# Mode berturut-turut: hitung kartu ★3 dari kartu terakhir ke belakang sampai
# ketemu kartu yang bukan ★3. Mode bebas: hitung semua kartu ★3 di turn ini.
func _count_chain_cards() -> int:
	var count := 0
	if chain_requires_consecutive:
		for i: int in range(_played_this_turn.size() - 1, -1, -1):
			if not _is_max_rank(_played_this_turn[i]):
				break
			count += 1
	else:
		for card: CardInstance in _played_this_turn:
			if _is_max_rank(card):
				count += 1
	return count


func _is_max_rank(card: CardInstance) -> bool:
	return card.get_rank() >= CardData.MAX_RANK

#endregion
