extends Control
## 委托面板：每条一张卡，头像组队，别的委托留在列表里。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

var host
var _sig := ""
var _missions: VBoxContainer
var _list: VBoxContainer

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := UIStyle.vbox(8)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)
	_missions = UIStyle.vbox(2)
	root.add_child(_missions)
	var sc := UIStyle.fill_scroll()
	root.add_child(sc)
	_list = UIStyle.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)

func invalidate() -> void:
	_sig = ""

func refresh() -> void:
	var sig := "%d|" % host.picking_uid
	for rid in host.picked:
		sig += "%d," % int(rid)
	sig += "|i%d" % int(round(Game.intel_power_mult() * 100.0))
	for g in Game.gig_board:
		sig += str(g["uid"]) + ","
	for m in Game.missions:
		sig += "m%s%d" % [m["kind"], int(m["left"])]
	if sig == _sig:
		return
	_sig = sig
	_rebuild_missions()
	_rebuild_list()

func _rebuild_missions() -> void:
	for c in _missions.get_children():
		c.queue_free()
	if Game.missions.is_empty():
		return
	var title := UIStyle.label(11, UIStyle.DIM)
	title.text = "在外面"
	_missions.add_child(title)
	for m in Game.missions:
		var what := "讨伐" if String(m["kind"]) == "boss" else String(m["gig"]["name"])
		var line := UIStyle.label(12, Color(0.75, 0.92, 1.0))
		line.text = "%s · %s · 剩 %d 小时" % [Game.team_names(m["rids"]), what, Game.hours_left(int(m["left"]))]
		_missions.add_child(line)

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	if Game.gig_board.is_empty():
		var empty := UIStyle.label(13, UIStyle.MUTED)
		empty.text = "板上没活了。每天早晨会补一批。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
		return
	for g in Game.gig_board:
		_list.add_child(_make_card(g))

func _make_card(g: Dictionary) -> PanelContainer:
	var uid := int(g["uid"])
	var accent := UIStyle.gig_color(String(g["type"]))
	var open: bool = host.picking_uid == uid
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent, open))
	var row := UIStyle.hbox(0)
	card.add_child(row)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(4, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	row.add_child(pad)
	var col := UIStyle.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(col)
	var head := UIStyle.hbox(6)
	col.add_child(head)
	var title := UIStyle.label(14, UIStyle.INK)
	title.text = String(g["name"])
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	head.add_child(UIStyle.chip(String(g["type"]), accent))
	var intel := Game.intel_power_mult()
	if intel > 1.001:
		head.add_child(UIStyle.chip("情报+%d%%" % int(round((intel - 1.0) * 100.0)), Color(0.45, 0.9, 1.0)))
	var chips := UIStyle.hbox(4)
	col.add_child(chips)
	chips.add_child(UIStyle.chip("需要%s %d" % [_power_name(String(g["power"])), int(g["need"])], accent))
	chips.add_child(UIStyle.chip("€%s" % UIStyle.group(int(g["pay"])), UIStyle.MONEY))
	var chips2 := UIStyle.hbox(4)
	col.add_child(chips2)
	chips2.add_child(UIStyle.chip("声望 +%d" % int(g["rep"]), UIStyle.GOLD))
	chips2.add_child(UIStyle.chip("%d 小时" % int(g["hours"]), UIStyle.MUTED))
	if not open:
		var go := UIStyle.make_button("组队", accent, Vector2(72, 28))
		go.pressed.connect(func() -> void: host.start_pick(uid))
		var line := UIStyle.hbox(8)
		line.alignment = BoxContainer.ALIGNMENT_END
		col.add_child(line)
		line.add_child(go)
		return card
	var key := String(g["power"])
	var need := maxi(1, int(g["need"]))
	var pw: int = Game.gig_team_power(host.picked, key)
	var ratio := float(pw) / float(need)
	var meter := UIStyle.meter(float(need), UIStyle.grade_color(ratio))
	meter.value = float(pw)
	col.add_child(meter)
	var sum := UIStyle.label(12, UIStyle.grade_color(ratio))
	var note := ""
	if intel > 1.001:
		note = " · 情报已计入"
	sum.text = "战力 %d / %d · %s%s" % [pw, need, Game.grade_text(ratio), note]
	col.add_child(sum)
	var faces := GridContainer.new()
	faces.columns = 8
	faces.add_theme_constant_override("h_separation", 4)
	faces.add_theme_constant_override("v_separation", 4)
	col.add_child(faces)
	for r in Game.residents:
		faces.add_child(_face(r, key, need, uid))
	var actions := UIStyle.hbox(8)
	col.add_child(actions)
	var cancel := UIStyle.make_button("收起", UIStyle.MUTED, Vector2(64, 30))
	cancel.pressed.connect(func() -> void: host.cancel_pick())
	actions.add_child(cancel)
	var send := UIStyle.make_button("出发（%d人）" % host.picked.size(), accent, Vector2(120, 30))
	send.disabled = host.picked.is_empty()
	send.pressed.connect(func() -> void: host.send_gig(uid))
	actions.add_child(send)
	return card

func _face(r, key: String, need: int, uid: int) -> Button:
	var rid := int(r.id)
	var chosen: bool = host.picked.has(rid)
	var pwr: int = Game.battle_power(r, key)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(36, 36)
	b.tooltip_text = "%s %s %d" % [r.rname, _power_name(key), pwr]
	var tex: Texture2D = host.portrait(String(r.job_id))
	if tex != null:
		b.icon = tex
		b.expand_icon = true
	else:
		b.text = String(r.rname).substr(0, 1)
	var accent := UIStyle.GOLD if chosen else (UIStyle.MONEY if pwr >= need else Color(1.0, 0.65, 0.45))
	b.add_theme_stylebox_override("normal", UIStyle.button_box(accent, chosen))
	b.add_theme_stylebox_override("hover", UIStyle.button_box(accent, true))
	b.add_theme_stylebox_override("pressed", UIStyle.button_box(accent, true))
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_stylebox_override("disabled", UIStyle.button_box(UIStyle.DIM, false))
	b.disabled = not Game.can_send(rid) or (not chosen and host.picked.size() >= Game.MAX_SQUAD)
	b.pressed.connect(func() -> void: host.toggle_pick(rid))
	return b

func _power_name(key: String) -> String:
	match key:
		"combat":
			return "战斗"
		"hack":
			return "黑客"
		"social":
			return "社交"
		_:
			return "任意"
