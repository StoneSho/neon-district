extends Control
## 开局主界面。街区在后面照常画着，点选之后才开始模拟。

const UIStyle := preload("res://scripts/ui/ui_style.gd")
const SETTINGS_PATH := "user://settings.cfg"

var hud
var _home: VBoxContainer
var _settings: VBoxContainer
var _ask: VBoxContainer
var _continue: Button
var _load: Button
var _full: Button
var _vsync: Button
var _volume: HSlider
var _volume_label: Label
var _fullscreen := false
var _vsync_on := true
var _volume_pct := 80


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var card := PanelContainer.new()
	card.offset_left = 72.0
	card.offset_top = 78.0
	card.offset_right = 460.0
	card.offset_bottom = 620.0
	card.add_theme_stylebox_override("panel", UIStyle.panel_box(Color(0.35, 0.9, 1.0)))
	add_child(card)
	var root := UIStyle.vbox(14)
	card.add_child(root)
	var title := UIStyle.label(40, UIStyle.GOLD)
	title.text = "霓虹街区"
	root.add_child(title)
	var sub := UIStyle.label(14, UIStyle.MUTED)
	sub.text = "赛博朋克街区经营"
	root.add_child(sub)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color(0.35, 0.9, 1.0, 0.7)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(line)
	_home = UIStyle.vbox(10)
	root.add_child(_home)
	_continue = _btn("继续游戏", UIStyle.MONEY, _on_continue)
	_home.add_child(_continue)
	_home.add_child(_btn("新游戏", Color(0.45, 0.9, 1.0), _on_new))
	_load = _btn("读档", UIStyle.GOLD, _on_load)
	_home.add_child(_load)
	_home.add_child(_btn("设置", Color(0.78, 0.7, 1.0), _show_settings))
	_home.add_child(_btn("退出", UIStyle.DANGER, _on_quit))
	_settings = UIStyle.vbox(12)
	_settings.visible = false
	root.add_child(_settings)
	var st := UIStyle.label(18, UIStyle.INK)
	st.text = "设置"
	_settings.add_child(st)
	_full = _btn("显示：窗口", Color(0.7, 0.9, 1.0), _toggle_full)
	_settings.add_child(_full)
	_vsync = _btn("垂直同步：开", Color(0.7, 0.9, 1.0), _toggle_vsync)
	_settings.add_child(_vsync)
	_volume_label = UIStyle.label(13, UIStyle.MUTED)
	_settings.add_child(_volume_label)
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 1
	_volume.custom_minimum_size = Vector2(280, 22)
	_volume.value_changed.connect(_on_volume)
	_settings.add_child(_volume)
	_settings.add_child(_btn("返回", UIStyle.INK, _show_home))
	_ask = UIStyle.vbox(10)
	_ask.visible = false
	root.add_child(_ask)
	var ask_title := UIStyle.label(16, UIStyle.GOLD)
	ask_title.text = "覆盖存档？"
	_ask.add_child(ask_title)
	var ask_body := UIStyle.label(13, UIStyle.INK)
	ask_body.text = "新游戏会覆盖当前存档。上一份会留在 slot1.json.bak。"
	ask_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask_body.custom_minimum_size = Vector2(300, 0)
	_ask.add_child(ask_body)
	_ask.add_child(_btn("确认新游戏", UIStyle.DANGER, _do_new))
	_ask.add_child(_btn("取消", UIStyle.INK, _show_home))
	_load_settings()
	_apply_settings()
	_refresh()
	EventBus.return_to_menu.connect(_on_return)


func _btn(text: String, accent: Color, cb: Callable) -> Button:
	var b := UIStyle.make_button(text, accent, Vector2(300, 40))
	b.pressed.connect(cb)
	return b


func _refresh() -> void:
	var playing: bool = Game.session_started
	_continue.visible = playing
	_continue.disabled = not playing
	var has: bool = Game.has_save()
	_load.disabled = not has
	_load.text = "读档" if has else "读档（没有存档）"
	_full.text = "显示：全屏" if _fullscreen else "显示：窗口"
	_vsync.text = "垂直同步：开" if _vsync_on else "垂直同步：关"
	_volume_label.text = "主音量  %d" % _volume_pct
	_volume.set_value_no_signal(_volume_pct)


func _show_home() -> void:
	_home.visible = true
	_settings.visible = false
	_ask.visible = false
	_refresh()


func _show_settings() -> void:
	_home.visible = false
	_settings.visible = true
	_refresh()


func _on_continue() -> void:
	_enter_play(false)


func _on_new() -> void:
	if Game.has_save() or Game.session_started:
		_home.visible = false
		_settings.visible = false
		_ask.visible = true
		return
	_do_new()


func _do_new() -> void:
	if hud != null and hud.view != null:
		hud.view.build_mode = ""
		hud.view.demolish = false
		hud.view.selected_bid = -1
		hud.view.selected_rid = -1
	Game.new_game()
	_enter_play(true)


func _on_load() -> void:
	if not Game.load_slot(true):
		EventBus.notice.emit("没有可读的存档")
		_refresh()
		return
	if hud != null and hud.view != null:
		hud.view.selected_bid = -1
		hud.view.selected_rid = -1
		hud.view.build_mode = ""
	_enter_play(false)
	EventBus.notice.emit("读档 · 第%d天" % Game.day())


func _on_quit() -> void:
	get_tree().quit()


func _enter_play(show_tip: bool) -> void:
	Game.at_menu = false
	visible = false
	if hud != null:
		hud.visible = true
	if Game.speed <= 0:
		Game.set_speed(1)
	else:
		Game.set_speed(Game.speed)
	if show_tip:
		EventBus.notice.emit("把「霓虹面馆」和「霓虹酒吧」贴在一起，再派人去做委托")


func _on_return() -> void:
	Game.at_menu = true
	Game.set_speed(0)
	if hud != null:
		hud.visible = false
	visible = true
	_show_home()


func _toggle_full() -> void:
	_fullscreen = not _fullscreen
	_apply_settings()
	_save_settings()
	_refresh()


func _toggle_vsync() -> void:
	_vsync_on = not _vsync_on
	_apply_settings()
	_save_settings()
	_refresh()


func _on_volume(v: float) -> void:
	_volume_pct = int(v)
	_apply_settings()
	_save_settings()
	_volume_label.text = "主音量  %d" % _volume_pct


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	_fullscreen = bool(cf.get_value("video", "fullscreen", false))
	_vsync_on = bool(cf.get_value("video", "vsync", true))
	_volume_pct = clampi(int(cf.get_value("audio", "volume", 80)), 0, 100)


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("video", "fullscreen", _fullscreen)
	cf.set_value("video", "vsync", _vsync_on)
	cf.set_value("audio", "volume", _volume_pct)
	cf.save(SETTINGS_PATH)


func _apply_settings() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	var vs := DisplayServer.VSYNC_ENABLED if _vsync_on else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vs)
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if _volume_pct <= 0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(float(_volume_pct) / 100.0))
