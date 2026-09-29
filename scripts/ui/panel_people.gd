extends Control
## 居民列表：立绘、职业、四条需求的颜色点。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

var host
var _sig := ""
var _grid: GridContainer

func _ready() -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_grid)

func invalidate() -> void:
	_sig = ""

func refresh() -> void:
	var sig := ""
	for r in Game.residents:
		sig += "%d:%s:%d|" % [int(r.id), r.status_text(Game.tick), int(r.level)]
		for k in ["hunger", "fun", "health", "cyberware"]:
			sig += "%d" % int(float(r.needs[k]) / 20.0)
	if sig == _sig:
		return
	_sig = sig
	_rebuild()

func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for r in Game.residents:
		_grid.add_child(_card(r))

func _card(r) -> PanelContainer:
	var rid := int(r.id)
	var on: bool = host.view != null and int(host.view.selected_rid) == rid
	var accent: Color = r.color
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(156, 64)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent, on))
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			host.on_resident(rid)
	)
	var row := UIStyle.hbox(8)
	card.add_child(row)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 6)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)
	pad.add_child(UIStyle.portrait(host.portrait(String(r.job_id)), accent, 40.0))
	var col := UIStyle.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := UIStyle.label(13, UIStyle.INK)
	name.text = String(r.rname)
	name.clip_text = true
	col.add_child(name)
	var sub := UIStyle.label(11, UIStyle.MUTED)
	sub.text = "%s Lv%d" % [r.job_name, int(r.level)]
	col.add_child(sub)
	var dots := UIStyle.hbox(4)
	col.add_child(dots)
	var status: String = r.status_text(Game.tick)
	if status != "闲逛":
		var pill_col := UIStyle.DANGER if status == "受伤" else Color(0.7, 0.85, 1.0)
		dots.add_child(UIStyle.chip(status, pill_col))
	for k in ["hunger", "fun", "health", "cyberware"]:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = UIStyle.need_color(float(r.needs[k]))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	return card
