extends Control
## 相性辞典页（阶段 8）：未发现为剪影，发现后显示成员与效果。

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
	var sig := "%d" % Game.combos_found.size()
	for c: Dictionary in ConfigDB.combos:
		if Game._combo_flags.has(String(c["id"])):
			sig += ":" + String(c["id"])
	if sig == _sig:
		return
	_sig = sig
	_rebuild()

func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var total := ConfigDB.combos.size()
	var head := UIStyle.label(13, UIStyle.MUTED)
	head.text = "把特定建筑贴邻连通即可激活相性"
	_body.add_child(head)
	var prog := UIStyle.meter(float(total), UIStyle.GOLD)
	prog.value = float(Game.combos_found.size())
	prog.custom_minimum_size = Vector2(0, 10)
	_body.add_child(prog)
	var pl := UIStyle.label(12, UIStyle.GOLD)
	pl.text = "已发现 %d / %d" % [Game.combos_found.size(), total]
	_body.add_child(pl)
	for c: Dictionary in ConfigDB.combos:
		_body.add_child(_card(c))
	var foot := UIStyle.label(11, UIStyle.DIM)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.text = "已收录的相性摆好位置后会显示「生效中」，效果立刻生效。"
	_body.add_child(foot)

## 奖励预告：从数据表读效果，未发现的相性也能看到"值得凑"的理由。
func _reward_text(c: Dictionary) -> String:
	var bits := PackedStringArray()
	var im := float(c.get("income_mult", 1.0))
	if im > 1.0:
		bits.append("组合内收入 ×%.1f" % im)
	if c.has("fun_decay"):
		bits.append("周边娱乐衰减 ×%.1f" % float(c["fun_decay"]))
	if c.has("weapon_discount"):
		bits.append("武器 -%d%%" % int(round(float(c["weapon_discount"]) * 100.0)))
	if c.has("boss_power_mult"):
		bits.append("Boss 战力 +%d%%" % int(round((float(c["boss_power_mult"]) - 1.0) * 100.0)))
	if c.has("tech_gig_faster"):
		bits.append("科技委托耗时 -%d%%" % int(round(float(c["tech_gig_faster"]) * 100.0)))
	if bits.is_empty():
		return "奖励：特殊效果"
	return "奖励：" + "，".join(bits)

## 未发现相性的剪影块：只给数量线索，不剧透是哪几栋。
func _silhouette(accent: Color) -> Control:
	var box := ColorRect.new()
	box.color = Color(accent.r, accent.g, accent.b, 0.18)
	box.custom_minimum_size = Vector2(30, 30)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var q := UIStyle.label(14, Color(accent.r, accent.g, accent.b, 0.95))
	q.text = "?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(q)
	return box

## 大类线索：只提示涉及哪几个主题，不点名具体建筑（豆包评审建议）。
func _theme_clue(fids: Array) -> String:
	var names := PackedStringArray()
	for fid in fids:
		var f: Dictionary = ConfigDB.get_facility(String(fid))
		if f.is_empty():
			continue
		var tname := ConfigDB.theme_name(String(f.get("theme", "")))
		if tname != "" and not names.has(tname):
			names.append(tname)
	if names.is_empty():
		return ""
	return "线索：涉及 %s 类建筑" % "/".join(names)

func _card(c: Dictionary) -> PanelContainer:
	var cid := String(c["id"])
	var found: bool = Game.combos_found.has(cid)
	var active: bool = Game._combo_flags.has(cid)
	var accent := UIStyle.GOLD if found else Color(0.5, 0.55, 0.7)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 68)
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent, active))
	var row := UIStyle.hbox(10)
	card.add_child(row)
	var col := UIStyle.vbox(3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := UIStyle.label(14, UIStyle.INK if found else Color(0.78, 0.82, 0.92))
	name.text = String(c["name"]) if found else "？？？（尚未发现）"
	col.add_child(name)
	var fids: Array = c.get("fids", [])
	if found:
		var bits := PackedStringArray()
		for fid in fids:
			bits.append(String(ConfigDB.get_facility(String(fid)).get("name", fid)))
		var sub := UIStyle.label(12, UIStyle.INK)
		sub.text = "成员：%s" % " + ".join(bits)
		col.add_child(sub)
		var desc := UIStyle.label(11, UIStyle.MUTED)
		desc.text = String(c.get("desc", ""))
		col.add_child(desc)
	else:
		var sil := UIStyle.hbox(4)
		for i in range(fids.size()):
			sil.add_child(_silhouette(accent))
		var need := UIStyle.label(11, Color(0.8, 0.85, 0.95))
		need.text = "需要 %d 栋建筑贴邻连通" % fids.size()
		var wrap := UIStyle.hbox(8)
		wrap.add_child(sil)
		wrap.add_child(need)
		col.add_child(wrap)
		var clue := _theme_clue(fids)
		if clue != "":
			var cl := UIStyle.label(11, Color(0.85, 0.8, 0.62))
			cl.text = clue
			cl.clip_text = true
			col.add_child(cl)
	var reward := UIStyle.label(11, Color(0.72, 0.9, 0.8))
	reward.clip_text = true
	reward.text = _reward_text(c)
	col.add_child(reward)
	if active:
		row.add_child(UIStyle.chip("生效中", Color(0.62, 0.95, 0.72)))
	elif found:
		row.add_child(UIStyle.chip("已收录", UIStyle.DIM))
	else:
		row.add_child(UIStyle.chip("未发现", Color(0.62, 0.7, 0.88)))
	return card
