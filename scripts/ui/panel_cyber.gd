extends Control
## 义体页（阶段 5）：按星级与店铺解锁的义体目录 + 仓库 + 垃圾/强化剂库存。
## 安装与维护在居民详情里做。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

const SLOT_TEXT := {
	"neural": "神经", "ocular": "眼部", "os": "OS", "skeletal": "骨骼",
	"leg": "腿", "dermal": "皮肤", "arm": "手臂",
}
const STAT_TEXT := {
	"body": "体质", "reflex": "反应", "tech": "技术", "intelligence": "智力", "cool": "酷",
}

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
	var sig := "%d|%d|%d|" % [Game.star, Game.money, Game.junk]
	for cw: Dictionary in ConfigDB.cyberware_list:
		sig += "%s:%d;" % [String(cw["id"]), int(Game.warehouse.get(String(cw["id"]), 0))]
	if sig == _sig:
		return
	_sig = sig
	_rebuild()

func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var head := UIStyle.hbox(6)
	_body.add_child(head)
	head.add_child(UIStyle.chip("赛博垃圾 ×%d" % Game.junk, Color(0.8, 0.7, 0.95)))
	var tip := UIStyle.label(11, UIStyle.MUTED)
	tip.text = "二手摊只卖 ★★ 及以下 · 改装店在居民详情里安装"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(tip)
	for cw: Dictionary in ConfigDB.cyberware_list:
		_body.add_child(_row(cw))

func _row(cw: Dictionary) -> PanelContainer:
	var wid := String(cw["id"])
	var unlocked: bool = Game.star >= int(cw["star"])
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 52)
	card.add_theme_stylebox_override("panel", UIStyle.card_box(UIStyle.INK, false))
	var row := UIStyle.hbox(10)
	card.add_child(row)
	var col := UIStyle.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := UIStyle.label(13, UIStyle.INK if unlocked else UIStyle.DIM)
	name.text = "%s  %s · %s槽" % [String(cw["name"]), "★".repeat(int(cw["rarity"])), SLOT_TEXT.get(String(cw["slot"]), String(cw["slot"]))]
	col.add_child(name)
	var bonus: Dictionary = cw.get("bonus", {})
	var bits := PackedStringArray()
	for k in bonus.keys():
		bits.append("%s +%d" % [STAT_TEXT.get(String(k), String(k)), int(bonus[k])])
	bits.append("耐久 %d天" % int(cw["dura"]))
	var sub := UIStyle.label(11, UIStyle.MUTED)
	sub.text = "，".join(bits)
	col.add_child(sub)
	if not unlocked:
		row.add_child(UIStyle.chip("需 %d★" % int(cw["star"]), UIStyle.DIM))
	# 禁用原因：只有二手摊时买不了 ★★★ 及以上，明确提示缺哪栋建筑。
	var has_shop: bool = Game._has_fid("cyberware_shop")
	var has_stall: bool = Game._has_fid("used_cyber_stall")
	if unlocked and not has_shop and not has_stall:
		row.add_child(UIStyle.chip("缺义体店", UIStyle.DANGER))
	elif unlocked and not has_shop and int(cw["rarity"]) > 2:
		row.add_child(UIStyle.chip("需改装店", UIStyle.DANGER))
	elif unlocked and not Game.can_buy_implant(wid) and Game.money < int(cw["price"]):
		row.add_child(UIStyle.chip("钱不够", UIStyle.DANGER))
	var held := int(Game.warehouse.get(wid, 0))
	if held > 0:
		row.add_child(UIStyle.chip("仓库 ×%d" % held, Color(0.62, 0.95, 0.72)))
	var buy := UIStyle.make_button("€%s" % UIStyle.group(int(cw["price"])), UIStyle.MONEY, Vector2(76, 30))
	buy.disabled = not Game.can_buy_implant(wid)
	buy.pressed.connect(func() -> void:
		if not Game.buy_implant(wid):
			EventBus.notice.emit("需要义体改装店（或二手摊买低稀有度），且星级和钱要够")
	)
	row.add_child(buy)
	return card
