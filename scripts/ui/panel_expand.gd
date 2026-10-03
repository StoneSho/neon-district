extends Control
## 扩张页（阶段 D · 城市扩张系统）：花钱征地，让"能盖楼的格子"变多。
## 新征到的格子全是废墟，清完才能建造 —— 这里同时提供批量清废墟。
## 只读 Game 状态；变更走 Game.expand_land() / Game.clear_all_ruins()。

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
	var st: Dictionary = Game.land_stats()
	var sig := "%d|%d|%d|%d|%d|%d" % [
		int(st["unlocked"]), int(st["free"]), int(st["ruins"]), int(st["cap"]),
		Game.expansions, Game.money / 100]
	if sig == _sig:
		return
	_sig = sig
	_rebuild()

func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var st: Dictionary = Game.land_stats()
	var head := UIStyle.label(13, UIStyle.MUTED)
	head.text = "扩张街区：花声望与钱征地，可盖楼的格子变多"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(head)
	_body.add_child(_stats_card(st))
	_body.add_child(_expand_card(st, "x", "东扩 +%d 列", "向地图右侧买地（横向加宽）"))
	_body.add_child(_expand_card(st, "y", "南扩 +%d 行", "向地图下方买地（纵向加高）"))
	_body.add_child(_ruin_card(st))

## 土地账本。
func _stats_card(st: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(Color(0.55, 0.8, 1.0), false))
	var col := UIStyle.vbox(4)
	card.add_child(col)
	var title := UIStyle.label(13, Color(0.7, 0.9, 1.0))
	title.text = "土地账本"
	col.add_child(title)
	var pend: Vector2i = st["pending"]
	var rows := [
		["已解锁地块", "%d 格（%d × %d）" % [int(st["unlocked"]), Game.unlocked_w, Game.unlocked_h]],
		["可自由建造", "%d 格" % int(st["free"])],
		["被占用/待清", "%d 格（其中废墟 %d）" % [int(st["blockers"]), int(st["ruins"])]],
		["星级土地上限", "%d 格（%d × %d）" % [int(st["cap"]), int(st["cap_w"]), int(st["cap_h"])]],
		["还能征", "%d 列 / %d 行（列=东扩，行=南扩）" % [pend.x, pend.y]],
		["累计征地", "%d 次" % int(st["expansions"])],
	]
	for r in rows:
		var line := UIStyle.hbox(8)
		var k := UIStyle.label(11, UIStyle.MUTED)
		k.text = String(r[0])
		k.custom_minimum_size = Vector2(96, 0)
		line.add_child(k)
		var v := UIStyle.label(12, UIStyle.INK)
		v.text = String(r[1])
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(v)
		col.add_child(line)
	return card

## 征地按钮卡：显示能拿几格、花多少钱、为什么不能征。
func _expand_card(st: Dictionary, axis: String, title_fmt: String, subtitle: String) -> PanelContainer:
	var step := Game.expand_step_size(axis)
	var cost := Game.expand_cost()
	var can := Game.can_expand(axis)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(UIStyle.GOLD if can else Color(0.5, 0.55, 0.68), false))
	var col := UIStyle.vbox(4)
	card.add_child(col)
	var title := UIStyle.label(14, UIStyle.INK)
	title.text = (title_fmt % step) if step > 0 else "%s（已达上限）" % title_fmt.split(" ")[0]
	col.add_child(title)
	var sub := UIStyle.label(11, UIStyle.MUTED)
	sub.text = subtitle
	col.add_child(sub)
	# 达上限时只留一条原因，避免两句同义提示堆在一起。
	if step > 0:
		var gain := UIStyle.label(11, Color(0.75, 0.95, 0.8))
		gain.text = "征地后：可建造格 +%d（需清废墟 €%d/格）" % [step * Game.unlocked_h, Game.RUIN_CLEAR_COST]
		gain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(gain)
	# 已达上限时不再显示价格（置灰按钮上的价格只会误导），只留一条原因。
	var btn := UIStyle.make_button("征地 €%s" % UIStyle.group(cost) if step > 0 else "已达当前上限", UIStyle.GOLD, Vector2(0, 30))
	btn.disabled = not can
	btn.pressed.connect(func() -> void:
		if Game.expand_land(axis):
			invalidate()
	)
	col.add_child(btn)
	if step <= 0:
		var capped := UIStyle.label(11, UIStyle.DIM)
		capped.text = "· 已拿满当前星级的土地上限，升星即可解锁更多"
		capped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(capped)
	elif not can:
		var why := UIStyle.label(11, UIStyle.DANGER)
		why.text = "· 资金不足（还差 €%s）" % UIStyle.group(cost - Game.money)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(why)
	return card

## 废墟批量清理：没有废墟时只留一行提示，不再重复整块信息。
func _ruin_card(st: Dictionary) -> PanelContainer:
	var n := int(st["ruins"])
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(Color(0.85, 0.6, 0.5) if n > 0 else Color(0.45, 0.5, 0.62), false))
	var col := UIStyle.vbox(4)
	card.add_child(col)
	var title := UIStyle.label(14, UIStyle.INK if n > 0 else Color(0.72, 0.76, 0.86))
	title.text = "清理废墟"
	col.add_child(title)
	if n <= 0:
		var none := UIStyle.label(11, UIStyle.DIM)
		none.text = "当前没有废墟 · 征地或让 Boss 拆楼后才会出现"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(none)
		return card
	var info := UIStyle.label(11, UIStyle.MUTED)
	info.text = "还有 %d 格废墟 · 单价 €%d · 全部清完需要 €%s" % [
		n, Game.RUIN_CLEAR_COST, UIStyle.group(n * Game.RUIN_CLEAR_COST)]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	var all_cost := n * Game.RUIN_CLEAR_COST
	var btn := UIStyle.make_button("一键清完（最多清 %d 格）" % mini(n, Game.money / Game.RUIN_CLEAR_COST), Color(0.9, 0.7, 0.55), Vector2(0, 30))
	btn.disabled = n <= 0 or Game.money < Game.RUIN_CLEAR_COST
	btn.pressed.connect(func() -> void:
		var cleared := Game.clear_all_ruins()
		if cleared > 0:
			EventBus.notice.emit("清理了 %d 格废墟" % cleared)
		invalidate()
	)
	col.add_child(btn)
	var hint := UIStyle.label(11, UIStyle.DIM)
	hint.text = "也可以直接点街上的废墟格单清（清废墟模式）"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	return card
