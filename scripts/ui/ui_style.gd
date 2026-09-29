extends RefCounted
## 界面用的颜色和控件。面板底 #10131c，卡片底 #171b28。

const PANEL := Color(0.063, 0.075, 0.110, 0.92)
const CARD := Color(0.090, 0.106, 0.157, 0.98)
const INK := Color(0.90, 0.93, 1.0)
const MUTED := Color(0.62, 0.68, 0.82)
const DIM := Color(0.45, 0.50, 0.62)
const MONEY := Color(0.55, 1.0, 0.75)
const GOLD := Color(1.0, 0.86, 0.45)
const DANGER := Color(1.0, 0.45, 0.48)

static func label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func group(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if v < 0 else "") + out

static func panel_box(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func card_box(accent: Color, active: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.95 if active else 0.35)
	sb.set_border_width_all(2 if active else 1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

static func chip_box(accent: Color, fill: float = 0.16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, fill)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

static func button_box(accent: Color, active: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if active:
		sb.bg_color = Color(accent.r, accent.g, accent.b, 0.28)
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.95)
	else:
		sb.bg_color = Color(0.12, 0.14, 0.22, 0.9)
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	return sb

static func toast_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.92)
	sb.border_color = Color(0.35, 0.85, 1.0, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

static func news_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.05, 0.97)
	sb.border_color = Color(1.0, 0.82, 0.4, 0.95)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb

static func make_button(text: String, accent: Color, size: Vector2 = Vector2(0, 32)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.add_theme_stylebox_override("normal", button_box(accent, false))
	b.add_theme_stylebox_override("hover", button_box(accent, true))
	b.add_theme_stylebox_override("pressed", button_box(accent, true))
	b.add_theme_stylebox_override("disabled", button_box(DIM, false))
	return b

static func chip(text: String, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", chip_box(accent))
	var l := label(11, accent)
	l.text = text
	p.add_child(l)
	return p

static func meter(max_value: float, col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maxf(1.0, max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.16, 0.26, 0.95)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

static func paint_meter(bar: ProgressBar, col: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)

static func need_color(v: float) -> Color:
	if v >= 58.0:
		return Color(0.65, 0.95, 0.8)
	if v >= 35.0:
		return GOLD
	return DANGER

static func stat_color(v: int) -> Color:
	if v >= 60:
		return MONEY
	if v >= 35:
		return Color(0.68, 0.9, 1.0)
	return Color(1.0, 0.72, 0.45)

static func grade_color(ratio: float) -> Color:
	if ratio >= 1.5:
		return Color(0.6, 1.0, 0.85)
	if ratio >= 1.0:
		return MONEY
	if ratio >= 0.5:
		return GOLD
	return DANGER

static func gig_color(type_name: String) -> Color:
	match type_name:
		"劫持":
			return Color(0.24, 0.88, 1.0)
		"清剿", "护卫":
			return Color(1.0, 0.30, 0.37)
		"提取":
			return Color(0.77, 0.42, 1.0)
		"快递", "传奇", "社交":
			return GOLD
		"破坏":
			return Color(0.49, 1.0, 0.61)
		_:
			return Color(0.7, 0.8, 1.0)

static func building_thumb(tex: Texture2D, accent: Color) -> Control:
	var clip := ColorRect.new()
	clip.color = Color(accent.r, accent.g, accent.b, 0.12)
	clip.custom_minimum_size = Vector2(48, 48)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_top = -16.0
		clip.add_child(tr)
	return clip

static func portrait(tex: Texture2D, tint: Color, side: float = 40.0) -> Control:
	var box := ColorRect.new()
	box.custom_minimum_size = Vector2(side, side)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex != null:
		box.color = Color(0.08, 0.09, 0.14, 1.0)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.add_child(tr)
	else:
		box.color = tint
	return box

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v
