extends Control
## 建造面板：主题筛选、带楼图的卡片、底部旋转和拆除。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

var host

var _filter := "all"
var _sig := ""
var _filter_row: HBoxContainer
var _grid: GridContainer
var _desc: Label
var _rotate: Button
var _demolish: Button
var _cards: Dictionary = {}

func _ready() -> void:
	var root := UIStyle.vbox(8)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_make_filters())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_grid)
	var foot := UIStyle.hbox(8)
	root.add_child(foot)
	_rotate = UIStyle.make_button("旋转", Color(0.7, 0.9, 1.0), Vector2(64, 36))
	_rotate.pressed.connect(func() -> void: host.on_rotate())
	foot.add_child(_rotate)
	_demolish = UIStyle.make_button("拆除", UIStyle.DANGER, Vector2(64, 36))
	_demolish.pressed.connect(func() -> void: host.on_demolish_mode())
	foot.add_child(_demolish)
	_desc = UIStyle.label(12, UIStyle.MUTED)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc.custom_minimum_size = Vector2(160, 36)
	foot.add_child(_desc)

func invalidate() -> void:
	_sig = ""

func refresh() -> void:
	var sig := "%s|%d|%d" % [_filter, Game.star, ConfigDB.catalog_entries().size()]
	if sig != _sig:
		_sig = sig
		_rebuild()
	_paint()

func _make_filters() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 32)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_filter_row = UIStyle.hbox(6)
	sc.add_child(_filter_row)
	_filter_row.add_child(_filter_button("all", "全部", Color(0.75, 0.85, 1.0)))
	for th in ConfigDB.THEME_ORDER:
		var name := "植物" if th == "deco" else ConfigDB.theme_name(th)
		_filter_row.add_child(_filter_button(th, name, ConfigDB.theme_color(th)))
	return sc

func _filter_button(id: String, title: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = title
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("fid", id)
	b.set_meta("accent", accent)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func() -> void:
		_filter = id
		_sig = ""
	)
	return b

func _style_filter(b: Button) -> void:
	var id := String(b.get_meta("fid"))
	var accent: Color = b.get_meta("accent")
	var on: bool = id == _filter
	b.add_theme_color_override("font_color", Color.WHITE if on else UIStyle.MUTED)
	var sb := UIStyle.chip_box(accent, 0.30 if on else 0.08)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", UIStyle.chip_box(accent, 0.22))
	b.add_theme_stylebox_override("pressed", UIStyle.chip_box(accent, 0.30))

func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	var filters := _find_filters()
	for b in filters:
		_style_filter(b)
	for f in ConfigDB.catalog_entries():
		var th := String(f["theme"])
		if _filter != "all" and th != _filter:
			continue
		_grid.add_child(_make_card(f))

func _find_filters() -> Array:
	var out: Array = []
	if _filter_row == null:
		return out
	for c in _filter_row.get_children():
		if c is Button:
			out.append(c)
	return out

func _make_card(f: Dictionary) -> PanelContainer:
	var fid := String(f["id"])
	var accent: Color = ConfigDB.theme_color(String(f["theme"]))
	var need := int(f["need_star"])
	var locked: bool = Game.star < need
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(156, 72)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if locked:
			return
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			host.on_build(fid)
	)
	var row := UIStyle.hbox(8)
	card.add_child(row)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)
	pad.add_child(UIStyle.building_thumb(host.building_texture(fid), accent))
	var col := UIStyle.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := UIStyle.label(13, UIStyle.INK if not locked else UIStyle.DIM)
	name.text = String(f["name"])
	name.clip_text = true
	col.add_child(name)
	var price := UIStyle.label(12, UIStyle.MONEY)
	price.text = "需 %d★" % need if locked else "€%s" % UIStyle.group(int(f["cost"]))
	col.add_child(price)
	if locked:
		card.modulate = Color(0.55, 0.55, 0.62, 1.0)
	_cards[fid] = {
		"panel": card,
		"price": price,
		"cost": int(f["cost"]),
		"locked": locked,
		"accent": accent,
	}
	return card

func _paint() -> void:
	var mode := ""
	var demo := false
	if host.view != null:
		mode = String(host.view.build_mode)
		demo = bool(host.view.demolish)
	for fid in _cards.keys():
		var rec: Dictionary = _cards[fid]
		var card: PanelContainer = rec["panel"]
		if not is_instance_valid(card):
			continue
		var accent: Color = rec["accent"]
		var active: bool = mode == String(fid) and not demo and not bool(rec["locked"])
		card.add_theme_stylebox_override("panel", UIStyle.card_box(accent, active))
		if not bool(rec["locked"]):
			var price: Label = rec["price"]
			var poor: bool = Game.money < int(rec["cost"])
			price.add_theme_color_override("font_color", UIStyle.DANGER if poor else UIStyle.MONEY)
	_demolish.modulate = Color(1.35, 1.2, 1.2) if demo else Color.WHITE
	_rotate.disabled = mode == ""
	if mode == "":
		_desc.text = "选一栋，再到街上点格子放下"
		return
	var f: Dictionary = ConfigDB.get_facility(mode)
	if f.is_empty():
		_desc.text = ""
		return
	_desc.text = "%s · %d×%d · €%d/访客\n%s" % [
		f["name"], int(f["size"]), int(f["size"]), int(f["income"]), f.get("desc", "")]
