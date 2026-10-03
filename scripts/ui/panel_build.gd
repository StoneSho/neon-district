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
var _road: Button
var _clear: Button
var _cards: Dictionary = {}

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := UIStyle.vbox(8)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)
	root.add_child(_make_filters())
	var sc := UIStyle.fill_scroll()
	root.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_grid)
	var foot := UIStyle.vbox(6)
	root.add_child(foot)
	var actions := UIStyle.hbox(6)
	foot.add_child(actions)
	_road = UIStyle.make_button("铺路", Color(0.6, 0.75, 1.0), Vector2(0, 32))
	_road.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_road.pressed.connect(func() -> void: host.on_road_mode())
	actions.add_child(_road)
	_clear = UIStyle.make_button("清废墟", Color(0.85, 0.65, 0.5), Vector2(0, 32))
	_clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear.pressed.connect(func() -> void: host.on_clear_mode())
	actions.add_child(_clear)
	_rotate = UIStyle.make_button("旋转", Color(0.7, 0.9, 1.0), Vector2(0, 32))
	_rotate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rotate.pressed.connect(func() -> void: host.on_rotate())
	actions.add_child(_rotate)
	_demolish = UIStyle.make_button("拆除", UIStyle.DANGER, Vector2(0, 32))
	_demolish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 危险操作：常态就给红色填充底，和铺路/清废墟/旋转拉开差距，降低误触。
	_demolish.add_theme_stylebox_override("normal", UIStyle.button_box(UIStyle.DANGER, true))
	_demolish.add_theme_stylebox_override("hover", UIStyle.button_box(UIStyle.DANGER, true))
	_demolish.pressed.connect(func() -> void: host.on_demolish_mode())
	actions.add_child(_demolish)
	_desc = UIStyle.label(12, UIStyle.MUTED)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

## 一行功能标识：这栋楼解决什么问题（数据驱动，从 satisfy/tag 推）。
func _function_tag(f: Dictionary) -> String:
	var bits := PackedStringArray()
	var sat: Dictionary = f.get("satisfy", {})
	var sat_text := {"hunger": "解决饥饿", "fun": "解决娱乐", "health": "看病", "cyberware": "修义体"}
	for k in ["hunger", "fun", "health", "cyberware"]:
		if float(sat.get(k, 0.0)) > 0.0:
			bits.append(String(sat_text[k]))
	match String(f.get("tag", "")):
		"tech":
			bits.append("科技据点")
		"business":
			bits.append("固定收入")
		"deco":
			bits.append("点缀/增益")
		"transit":
			bits.append("加速通行")
		"legendary":
			bits.append("传奇·全图限1")
		"rest":
			bits.append("住所")
	if String(f["id"]) == "hack_bench":
		bits.append("垃圾换知识")
	if bits.is_empty():
		return "客流收入 €%d/次" % int(f.get("income", 0))
	return " · ".join(bits)

func _make_card(f: Dictionary) -> PanelContainer:
	var fid := String(f["id"])
	var accent: Color = ConfigDB.theme_color(String(f["theme"]))
	var need := Game.building_star_req(String(f["id"]))
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
	var name := UIStyle.label(13, UIStyle.INK if not locked else Color(0.74, 0.78, 0.88))
	name.text = String(f["name"])
	name.clip_text = true
	col.add_child(name)
	var price := UIStyle.label(12, UIStyle.MONEY if not locked else Color(1.0, 0.84, 0.45))
	price.text = ("🔒 升到 %d★" % need) if locked else "€%s" % UIStyle.group(Game.facility_cost(f))
	col.add_child(price)
	# 功能标识：一行为什么要建它（豆包评审：卡片看不出用途，新手难判优先级）。
	var fn := UIStyle.label(10, Color(0.66, 0.78, 0.9))
	fn.text = _function_tag(f)
	fn.clip_text = true
	col.add_child(fn)
	if locked:
		# 轻微压暗 + 灰蓝描边：既区分"不可建"，又不牺牲「升到 N★」的可读性。
		card.modulate = Color(0.82, 0.82, 0.9, 1.0)
	_cards[fid] = {
		"panel": card,
		"price": price,
		"cost": Game.facility_cost(f),
		"locked": locked,
		"accent": accent,
	}
	return card

func _paint() -> void:
	var mode := ""
	var demo := false
	var road_on := false
	var clear_on := false
	if host.view != null:
		mode = String(host.view.build_mode)
		demo = bool(host.view.demolish)
		road_on = bool(host.view.road_mode)
		clear_on = bool(host.view.clear_mode)
	for fid in _cards.keys():
		var rec: Dictionary = _cards[fid]
		var card: PanelContainer = rec["panel"]
		if not is_instance_valid(card):
			continue
		var accent: Color = rec["accent"]
		var locked: bool = bool(rec["locked"])
		var active: bool = mode == String(fid) and not demo and not locked
		# 锁定卡用灰蓝描边区分，但仍保留主题色可见度。
		card.add_theme_stylebox_override("panel", UIStyle.card_box(Color(0.52, 0.56, 0.7) if locked else accent, active))
		if not locked:
			var price: Label = rec["price"]
			var poor: bool = Game.money < int(rec["cost"])
			price.add_theme_color_override("font_color", UIStyle.DANGER if poor else UIStyle.MONEY)
	_demolish.modulate = Color(1.35, 1.2, 1.2) if demo else Color.WHITE
	_road.modulate = Color(1.2, 1.35, 1.3) if road_on else Color.WHITE
	_clear.modulate = Color(1.35, 1.2, 1.0) if clear_on else Color.WHITE
	_rotate.disabled = mode == ""
	if road_on:
		_desc.text = "铺路 €%d/格：人在道路上走得快（酸雨时失效）" % Game.ROAD_COST
		return
	if clear_on:
		_desc.text = "清理废墟 €%d/格：清理后才能走和盖楼" % Game.RUIN_CLEAR_COST
		return
	if mode == "":
		_desc.text = "选一栋，再到街上点格子放下"
		return
	var f: Dictionary = ConfigDB.get_facility(mode)
	if f.is_empty():
		_desc.text = ""
		return
	_desc.text = "%s · %d×%d · €%d/访客\n%s" % [
		f["name"], int(f["size"]), int(f["size"]), int(f["income"]), f.get("desc", "")]
