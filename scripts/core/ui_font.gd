class_name UIFont
extends RefCounted
## 提供支持中文的系统字体（Godot 默认字体没有 CJK 字形）

static var _font: SystemFont = null

static func get_font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray([
			"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC",
			"Source Han Sans SC", "SimHei", "sans-serif",
		])
		_font.allow_system_fallback = true
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return _font

static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = get_font()
	t.default_font_size = 15
	return t
