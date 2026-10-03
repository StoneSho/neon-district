extends Control
## 军火页（阶段 4）：按星级解锁的武器目录 + 仓库。装备在居民详情里做。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

var host
var _sig := ""
var _body: VBoxContainer

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sc := UIStyle.fill_scroll()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sc)
	_body = UIStyle.vbox(8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

func invalidate() -> void:
	_sig = ""

func refresh() -> void:
	var sig := "%d|%d|" % [Game.star, Game.money]
	for w: Dictionary in ConfigDB.weapon_list:
		sig += "%s:%d;" % [String(w["id"]), int(Game.warehouse.get(String(w["id"]), 0))]
	if sig == _sig:
		return
	_sig = sig
	_rebuild()

func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var head := UIStyle.label(13, UIStyle.MUTED)
	head.text = "武器给委托与讨伐提供战力加成 · 装备在居民详情里做"
	_body.add_child(head)
	for w: Dictionary in ConfigDB.weapon_list:
		_body.add_child(_row(w))

func _row(w: Dictionary) -> PanelContainer:
	var wid := String(w["id"])
	var unlocked: bool = Game.star >= int(w["star"])
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 52)
	card.add_theme_stylebox_override("panel", UIStyle.card_box(UIStyle.INK, false))
	var row := UIStyle.hbox(10)
	card.add_child(row)
	var col := UIStyle.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := UIStyle.label(13, UIStyle.INK if unlocked else UIStyle.DIM)
	name.text = "%s  %s" % [String(w["name"]), "★".repeat(int(w["rarity"]))]
	col.add_child(name)
	var bonus: Dictionary = w.get("bonus", {})
	var bits := PackedStringArray()
	for k in ["combat", "hack", "social"]:
		if int(bonus.get(k, 0)) > 0:
			bits.append("%s +%d" % [{"combat": "战斗", "hack": "黑客", "social": "社交"}[k], int(bonus[k])])
	var sub := UIStyle.label(11, UIStyle.MUTED)
	sub.text = "，".join(bits)
	col.add_child(sub)
	if not unlocked:
		var lock := UIStyle.chip("需 %d★" % int(w["star"]), UIStyle.DIM)
		row.add_child(lock)
	var held := int(Game.warehouse.get(wid, 0))
	if held > 0:
		row.add_child(UIStyle.chip("仓库 ×%d" % held, Color(0.62, 0.95, 0.72)))
	var buy := UIStyle.make_button("€%s" % UIStyle.group(Game.weapon_price(wid)), UIStyle.MONEY, Vector2(76, 30))
	buy.disabled = not Game.can_buy_weapon(wid)
	buy.pressed.connect(func() -> void:
		if not Game.buy_weapon(wid):
			EventBus.notice.emit("买不起或星级不够")
	)
	row.add_child(buy)
	return card
