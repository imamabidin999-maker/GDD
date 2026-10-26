extends Node
## Musik latar (dengan crossfade) dan efek suara.
##
## Musik: AudioManager.play_music("battle")
## Efek : AudioManager.play_sfx("bedug")
## Volume diatur lewat bus "Music" dan "SFX" oleh GameState.

const MUSIC := {
	"menu": "res://assets/audio/bgm/menu.ogg",
	"map": "res://assets/audio/bgm/map.ogg",
	"battle": "res://assets/audio/bgm/battle.ogg",
	"boss": "res://assets/audio/bgm/boss.ogg",
	"victory": "res://assets/audio/bgm/victory.ogg",
}

const SFX := {
	"bedug": "res://assets/audio/sfx/bedug.ogg",
	"korek": "res://assets/audio/sfx/korek.ogg",
	"kentongan": "res://assets/audio/sfx/kentongan.ogg",
	"gong": "res://assets/audio/sfx/gong.ogg",
	"dongkrek": "res://assets/audio/sfx/dongkrek.ogg",
	"gebrakan": "res://assets/audio/sfx/gebrakan.ogg",
	"hit": "res://assets/audio/sfx/hit.ogg",
	"hit_heavy": "res://assets/audio/sfx/hit_heavy.ogg",
	"block": "res://assets/audio/sfx/block.ogg",
	"card": "res://assets/audio/sfx/card.ogg",
	"card_merge": "res://assets/audio/sfx/card_merge.ogg",
	"card_play": "res://assets/audio/sfx/card_play.ogg",
	"card_draw": "res://assets/audio/sfx/card_draw.ogg",
	"card_pick": "res://assets/audio/sfx/card_pick.ogg",
	"card_place": "res://assets/audio/sfx/card_place.ogg",
	"card_hover": "res://assets/audio/sfx/card_hover.ogg",
	"click": "res://assets/audio/sfx/click.ogg",
	"lock": "res://assets/audio/sfx/lock.ogg",
	"shuffle": "res://assets/audio/sfx/shuffle.ogg",
	"moxie": "res://assets/audio/sfx/moxie.ogg",
	"poison": "res://assets/audio/sfx/poison.ogg",
	"defeat": "res://assets/audio/sfx/defeat.ogg",
	"error": "res://assets/audio/sfx/error.ogg",
}

const SFX_VOICES := 8
const CROSSFADE := 0.8
## Volume musik saat dipelankan (misalnya selama irama Gebrakan).
const DUCK_DB := -16.0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music: String = ""
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _cache: Dictionary = {}
var _fades: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	for i: int in SFX_VOICES:
		_sfx_players.append(_make_player("SFX"))


func play_music(key: String) -> void:
	if key == _current_music:
		return
	_current_music = key
	var stream := _load(MUSIC.get(key, "")) as AudioStream
	# Pemain yang sedang terdengar paling keras dianggap musik lama.
	var old := _music_a if _music_a.volume_db >= _music_b.volume_db and _music_a.playing else _music_b
	var new := _music_b if old == _music_a else _music_a
	if stream != null:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = key != "victory"
		new.stream = stream
		new.volume_db = -40.0
		new.play()
		_fade(new, 0.0, false)
	else:
		_fade(new, -40.0, true)
	if old.playing:
		_fade(old, -40.0, true)


## Memelankan musik yang sedang terdengar, atau mengembalikannya.
func duck_music(on: bool) -> void:
	var current := _music_a if _music_a.volume_db >= _music_b.volume_db else _music_b
	if current.playing:
		_fade(current, DUCK_DB if on else 0.0, false)


func stop_music() -> void:
	_current_music = ""
	for player: AudioStreamPlayer in [_music_a, _music_b]:
		if player.playing:
			_fade(player, -40.0, true)


func _fade(player: AudioStreamPlayer, to_db: float, stop_after: bool) -> void:
	var running := _fades.get(player) as Tween
	if running != null and running.is_valid():
		running.kill()
	var t := create_tween()
	t.tween_property(player, "volume_db", to_db, CROSSFADE)
	if stop_after:
		t.tween_callback(player.stop)
	_fades[player] = t


## Memutar efek suara. pitch_jitter memberi sedikit variasi supaya pukulan
## beruntun tidak terdengar sama persis.
func play_sfx(key: String, pitch_jitter: float = 0.05, volume_db: float = 0.0) -> void:
	var stream := _load(SFX.get(key, "")) as AudioStream
	if stream == null:
		return
	var player := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _load(path: String) -> Resource:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path] as Resource
	var res: Resource = null
	if ResourceLoader.exists(path):
		res = load(path)
	_cache[path] = res
	return res
