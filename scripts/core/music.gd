extends Node
## 循环配乐。主菜单、街区、Boss 三段，交叉淡入淡出。走 Master 总线，跟设置里的主音量。

const FADE := 1.1
const TRACKS := {
	"menu": "res://assets/audio/menu.wav",
	"district": "res://assets/audio/district.wav",
	"boss": "res://assets/audio/boss.wav",
}

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _front: AudioStreamPlayer
var _back: AudioStreamPlayer
var _current := ""
var _fade_left := 0.0
var _cache: Dictionary = {}


func _exit_tree() -> void:
	if _a != null:
		_a.stop()
	if _b != null:
		_b.stop()


func _ready() -> void:
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.bus = "Master"
		add_child(p)
	_front = _a
	_back = _b
	_apply_saved_volume()
	play("menu")


func _process(delta: float) -> void:
	var paused: bool = (not Game.at_menu) and Game.speed <= 0
	var want := "menu"
	if not Game.at_menu:
		want = "boss" if not Game.boss.is_empty() else "district"
	play(want)
	_a.stream_paused = paused
	_b.stream_paused = paused
	if not paused:
		_tick_fade(delta)


func play(id: String) -> void:
	if id == _current:
		return
	if not TRACKS.has(id):
		return
	var stream := _stream(String(TRACKS[id]))
	if stream == null:
		return
	_current = id
	if not _front.playing:
		_front.stream = stream
		_front.volume_db = 0.0
		_front.play()
		_back.stop()
		_fade_left = 0.0
		return
	_back.stop()
	_back.stream = stream
	_back.volume_db = -48.0
	_back.play()
	var tmp := _front
	_front = _back
	_back = tmp
	_fade_left = FADE


func _tick_fade(delta: float) -> void:
	if _fade_left <= 0.0:
		return
	_fade_left = maxf(0.0, _fade_left - delta)
	var k := 1.0 - _fade_left / FADE
	_front.volume_db = lerpf(-48.0, 0.0, k)
	_back.volume_db = lerpf(0.0, -48.0, k)
	if _fade_left <= 0.0:
		_back.stop()
		_front.volume_db = 0.0


func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var loaded = load(path)
	if loaded is AudioStreamWAV:
		var wav: AudioStreamWAV = loaded
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var frame_bytes := 2
		if wav.stereo:
			frame_bytes *= 2
		if wav.format == AudioStreamWAV.FORMAT_8_BITS:
			frame_bytes = 1 if not wav.stereo else 2
		wav.loop_begin = 0
		wav.loop_end = int(wav.data.size() / frame_bytes)
	_cache[path] = loaded
	return loaded


func _apply_saved_volume() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") != OK:
		return
	var pct := clampi(int(cf.get_value("audio", "volume", 80)), 0, 100)
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if pct <= 0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(float(pct) / 100.0))
