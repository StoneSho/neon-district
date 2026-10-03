extends Control
## 研究页（阶段 6）：黑客工作台回收/兑换 + 四条研究线。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

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
	var sig := "%d|%d|%d|%d|%d|" % [Game.star, Game.money, Game.junk, Game.knowledge, Game.research.size()]
	for dn in Game.research_done:
		sig += String(dn) + ";"
	for rk in Game.research.keys():
		sig += "%s:%d;" % [String(rk), int(Game.research[rk]["left"])]
	if sig == _sig:
		return
	_sig = sig
	_rebuild()

func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	_workbench()
	_exchange()
	_research_lines()

func _workbench() -> void:
	var head := UIStyle.hbox(6)
	_body.add_child(head)
	head.add_child(UIStyle.chip("赛博垃圾 ×%d" % Game.junk, Color(0.8, 0.7, 0.95)))
	head.add_child(UIStyle.chip("知识点 %d" % Game.knowledge, Color(0.5, 0.9, 1.0)))
	var re := UIStyle.make_button("回收 +%d 知识" % Game.JUNK_KNOWLEDGE, Color(0.6, 0.85, 1.0), Vector2(0, 28))
	re.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	re.disabled = not Game.can_recycle_junk()
	re.pressed.connect(func() -> void: Game.recycle_junk())
	head.add_child(re)
	if not Game._has_fid("hack_bench"):
		var tip := UIStyle.label(11, UIStyle.DIM)
		tip.text = "需要「黑客工作台」建筑才能回收与兑换"
		_body.add_child(tip)

func _exchange() -> void:
	if not Game._has_fid("hack_bench"):
		return
	_sect("兑换（武器 · 义体 · 强化剂）")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	for w: Dictionary in ConfigDB.weapon_list:
		var wid := String(w["id"])
		var cost := Game.knowledge_cost(int(w["price"]))
		grid.add_child(_ex_btn("%s · %d" % [String(w["name"]), cost], UIStyle.INK, func() -> void:
			if Game.exchange_weapon(wid):
				invalidate()
		, not Game.can_exchange_weapon(wid)))
	for cw: Dictionary in ConfigDB.cyberware_list:
		var wid := String(cw["id"])
		var cost := Game.knowledge_cost(int(cw["price"]))
		grid.add_child(_ex_btn("义体·%s · %d" % [String(cw["name"]), cost], Color(0.5, 0.9, 0.72), func() -> void:
			if Game.exchange_implant(wid):
				invalidate()
		, not Game.can_exchange_implant(wid)))
	for st in ["body", "reflex", "tech", "intelligence", "cool"]:
		var sid := String(st)
		grid.add_child(_ex_btn("强化剂·%s · %d" % [STAT_TEXT[st], Game.KNOWLEDGE_STIM_COST], Color(0.95, 0.75, 0.9), func() -> void:
			if Game.exchange_stim(sid):
				invalidate()
		, not Game.can_exchange_stim(sid)))

func _research_lines() -> void:
	_sect("研究（槽 %d/%d · 秘密服务器加速 ×%.0f%%）" % [
		Game.active_research_count(), Game.research_slots(), Game.research_speed_mult() * 100.0])
	for rl: Dictionary in ConfigDB.research_list:
		_body.add_child(_line(rl))

func _line(rl: Dictionary) -> PanelContainer:
	var rid := String(rl["id"])
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 64)
	var done: bool = Game.research_done.has(rid)
	var active: bool = Game.research.has(rid)
	var accent := UIStyle.GOLD if done else (UIStyle.INK if not active else Color(0.5, 0.9, 1.0))
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent, active))
	var row := UIStyle.hbox(10)
	card.add_child(row)
	var col := UIStyle.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := UIStyle.label(13, UIStyle.INK)
	name.text = String(rl["name"]) + ("（已完成）" if done else "")
	col.add_child(name)
	var preq := String(rl["prereq"])
	var preq_ok: bool = Game._has_fid(preq)
	var preq_name := String(ConfigDB.get_facility(preq).get("name", preq))
	var uname := String(ConfigDB.get_facility(String(rl["unlocks"])).get("name", rl["unlocks"]))
	var meta := UIStyle.label(11, UIStyle.MUTED)
	meta.clip_text = true
	meta.text = "€%d · %d 小时 · 提前 1 星解锁" % [int(rl["cost"]), int(rl["hours"])]
	col.add_child(meta)
	# 前提与解锁目标拆成独立短行：中文没有词边界，长句开了自动换行会被硬拆（如「豪/华公寓」）。
	var unl := UIStyle.label(11, UIStyle.DIM)
	unl.clip_text = true
	unl.text = "前提 %s%s · 解锁 %s" % [preq_name, "" if preq_ok else "（缺）", uname]
	col.add_child(unl)
	var desc := UIStyle.label(11, UIStyle.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.text = String(rl.get("desc", ""))
	col.add_child(desc)
	if active:
		var rec: Dictionary = Game.research[rid]
		var bar := UIStyle.meter(100.0, Color(0.5, 0.9, 1.0))
		bar.value = float(int(rec["left"])) / float(maxi(1, int(rec["total"]))) * 100.0
		bar.custom_minimum_size = Vector2(90, 8)
		row.add_child(bar)
		var left_h := Game.hours_left(int(rec["left"]))
		row.add_child(UIStyle.chip("%d 小时" % left_h, Color(0.5, 0.9, 1.0)))
	else:
		# 禁用原因提示：槽位/前提/资金，避免按钮变灰但看不出为什么。
		# 放在左侧文本列而不是按钮旁边：芯片在窄行里会被逐字换行成竖排。
		var reason := ""
		if done:
			reason = ""
		elif Game.active_research_count() >= Game.research_slots():
			reason = "槽位已满"
		elif not preq_ok:
			reason = "缺前提建筑"
		elif Game.money < int(rl["cost"]):
			reason = "钱不够"
		elif Game._free_tech_residents(1).is_empty():
			reason = "缺技术系居民"
		if reason != "":
			var why := UIStyle.label(11, UIStyle.DANGER)
			why.text = "· " + reason
			col.add_child(why)
		var go := UIStyle.make_button("研究" if not done else "✓", UIStyle.MONEY, Vector2(64, 28))
		go.disabled = done or not Game.can_start_research(rid)
		go.pressed.connect(func() -> void:
			if Game.start_research(rid):
				invalidate()
		)
		row.add_child(go)
	return card

func _ex_btn(text: String, accent: Color, on_press: Callable, disabled: bool) -> Button:
	var b := UIStyle.make_button(text, accent, Vector2(0, 26))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.disabled = disabled
	b.pressed.connect(on_press)
	return b

func _sect(text: String) -> void:
	var l := UIStyle.label(11, UIStyle.DIM)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(l)
