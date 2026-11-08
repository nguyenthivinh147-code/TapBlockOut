extends Node
## Autoload Sfx: hiệu ứng, nhạc, bus riêng, rung nhẹ. Thiếu file hoặc không giải mã được thì im lặng.
## Tên: assets/sfx/<name>.wav (thêm tiền tố "sfx_" nếu thiếu), nhạc assets/music/<name>.ogg.
## Cài đặt truyền qua apply_settings(Game.s.settings): sfx, music, haptics.
## Music (docs/AUDIO_MUSIC.md): MUSIC_LEVEL in the level, MUSIC_HOME on the other screens but loading. A track starts
## from MUSIC_FADE_DB and fades in; a track change fades the old one out first (Config.CONTENT.music_fade_*).

const Config := preload("res://src/config.gd")
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const MUSIC_HOME := "bgm_home"
const MUSIC_LEVEL := "bgm_level"
const POOL_SIZE := 8
const SFX_DB := 0.0
const MUSIC_DB := -8.0
const MUSIC_FADE_DB := -30.0
## Rung nhẹ (ms) theo tên hiệu ứng; không có trong bảng thì không rung.
const HAPTIC_MS := {"tap": 10, "blocked": 25, "bump": 25, "shatter": 15, "box_tear": 15, "smash": 30, "life_lost": 30}

var sfx_on: bool = true
var music_on: bool = true
var haptics_on: bool = true
## Quan sát được từ test.
var last_played: String = ""
var music_name: String = ""

var _pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer = null
var _music_fade: Tween = null
var _cache: Dictionary = {}
var _ad_paused: bool = false
var _ready_done: bool = false


func _ready() -> void:
	setup()


## Tạo bus và player; gọi nhiều lần vẫn an toàn.
func setup() -> void:
	if _ready_done:
		return
	_ready_done = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BUS_SFX, SFX_DB)
	_ensure_bus(BUS_MUSIC, MUSIC_DB)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
	_apply_mutes()


## Dừng mọi player, bỏ stream và xoá cache để không giữ tài nguyên tới lúc thoát.
func release_all() -> void:
	for p in _pool:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_stop_music_fade()
	if _music_player != null and is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	_cache.clear()


func _exit_tree() -> void:
	release_all()


func _ensure_bus(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_volume_db(idx, db)


func _apply_mutes() -> void:
	var i := AudioServer.get_bus_index(BUS_SFX)
	if i != -1:
		AudioServer.set_bus_mute(i, not sfx_on)
	i = AudioServer.get_bus_index(BUS_MUSIC)
	if i != -1:
		AudioServer.set_bus_mute(i, not music_on)


## settings: {"sfx": bool, "music": bool, "haptics": bool}; khoá thiếu giữ nguyên.
func apply_settings(settings: Dictionary) -> void:
	sfx_on = bool(settings.get("sfx", sfx_on))
	music_on = bool(settings.get("music", music_on))
	haptics_on = bool(settings.get("haptics", haptics_on))
	_apply_mutes()
	if not sfx_on:
		for p in _pool:
			p.stop()
	_sync_music()


func play(sfx_name: String) -> void:
	if sfx_name == "":
		return
	setup()
	if haptics_on and HAPTIC_MS.has(sfx_name.trim_prefix("sfx_")):
		Platform.haptic(HAPTIC_MS[sfx_name.trim_prefix("sfx_")])
	if not sfx_on or _ad_paused:
		return
	var stream := _load_sfx(sfx_name)
	if stream == null:
		return
	last_played = sfx_name
	var p := _free_player()
	p.stream = stream
	p.play()


## Phát `sfx_name`; chưa có file thì phát `fallback`. Rung theo tên chính.
func play_or(sfx_name: String, fallback: String) -> void:
	setup()
	if _load_sfx(sfx_name) != null:
		play(sfx_name)
		return
	if haptics_on and HAPTIC_MS.has(sfx_name):
		Platform.haptic(HAPTIC_MS[sfx_name])
	var was_haptics := haptics_on
	haptics_on = false
	play(fallback)
	haptics_on = was_haptics


func music(music_track: String) -> void:
	setup()
	if music_track == music_name and _music_player.playing:
		return
	music_name = music_track
	_sync_music()


func stop_music() -> void:
	music_name = ""
	_stop_music_fade()
	if _music_player != null:
		_music_player.stop()


func pause_for_ad() -> void:
	_ad_paused = true
	_stop_music_fade()
	if _music_player != null:
		_music_player.stop()
	for p in _pool:
		p.stop()


func resume_after_ad() -> void:
	_ad_paused = false
	_sync_music()


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


func _sync_music() -> void:
	if _music_player == null:
		return
	_stop_music_fade()
	var stream: AudioStream = null
	if music_name != "" and music_on and not _ad_paused:
		stream = _load_music(music_name)
	if stream == null:
		_music_player.stop()
		return
	if not is_inside_tree():
		_play_music(stream)
		_music_player.volume_db = 0.0
		return
	var c: Dictionary = Config.CONTENT
	_music_fade = create_tween()
	if _music_player.playing and _music_player.stream != stream:
		_music_fade.tween_property(_music_player, "volume_db", MUSIC_FADE_DB, float(c.music_fade_out_sec))
		_music_fade.tween_callback(_play_music.bind(stream))
	else:
		_play_music(stream)
	# Also brings a track back up when it is asked for again during its fade-out.
	_music_fade.tween_property(_music_player, "volume_db", 0.0, float(c.music_fade_in_sec))


## Starts stream from MUSIC_FADE_DB, unless it is the one already playing.
func _play_music(stream: AudioStream) -> void:
	if _music_player.playing and _music_player.stream == stream:
		return
	_music_player.stream = stream
	_music_player.volume_db = MUSIC_FADE_DB
	_music_player.play()


func _stop_music_fade() -> void:
	if _music_fade != null:
		_music_fade.kill()
		_music_fade = null


func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]


func _load_sfx(sfx_name: String) -> AudioStream:
	var key := "s:" + sfx_name
	if _cache.has(key):
		return _cache[key]
	var names: Array[String] = [sfx_name]
	if not sfx_name.begins_with("sfx_"):
		names.append("sfx_" + sfx_name)
	var stream: AudioStream = null
	for n in names:
		stream = _try_load("%s%s.wav" % [SFX_DIR, n])
		if stream != null:
			break
	_cache[key] = stream
	return stream


func _load_music(track: String) -> AudioStream:
	var key := "m:" + track
	if _cache.has(key):
		return _cache[key]
	var stream := _try_load("%s%s.ogg" % [MUSIC_DIR, track])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_cache[key] = stream
	return stream


func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
