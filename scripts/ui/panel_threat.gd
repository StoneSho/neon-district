extends Control
## 威胁面板。没人闹事时只留一句，有 Boss 时用战力和倒计时条。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

var host
var _sig := ""
var _root: VBoxContainer
var _timer: ProgressBar

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sc := UIStyle.fill_scroll()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sc)
	_root = UIStyle.vbox(10)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_root)

func invalidate() -> void:
	_sig = ""

func refresh() -> void:
	var sig := "none"
	if not Game.boss.is_empty():
		sig = "%s|%d|%d" % [Game.boss.get("id", ""), int(Game.boss_busy()), int(Game.boss.get("left", 0)) / 30]
	for rid in host.boss_picked:
		sig += "|p%d" % int(rid)
	for r in Game.residents:
		if r.state == Resident.State.AWAY or r.injured(Game.tick):
			sig += "|x%d" % int(r.id)
	if sig != _sig:
		_sig = sig
		_rebuild()
	elif _timer != null and is_instance_valid(_timer) and not Game.boss.is_empty():
		_timer.value = float(Game.boss.get("left", 0))

func _rebuild() -> void:
	_timer = null
	for c in _root.get_children():
		c.queue_free()
	if Game.boss.is_empty():
		var box := UIStyle.vbox(8)
		_root.add_child(box)
		var t := UIStyle.label(16, UIStyle.INK)
		t.text = "街区平静"
		box.add_child(t)
		var s := UIStyle.label(12, UIStyle.MUTED)
		s.text = "赛博精神病会在傍晚或夜里出现，提前把人练起来"
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(s)
		# 战绩统计（原来这一页只有两行字，大片留白）。
		var injured := 0
		for r in Game.residents:
			if r.injured(Game.tick):
				injured += 1
		var hurt := 0
		for b in Game.buildings:
			if bool(b.get("damaged", false)):
				hurt += 1
		var chips := UIStyle.hbox(6)
		chips.add_child(UIStyle.chip("已讨伐 %d" % int(Game.bosses_killed), UIStyle.GOLD))
		chips.add_child(UIStyle.chip("伤员 %d" % injured, UIStyle.DANGER if injured > 0 else UIStyle.DIM))
		chips.add_child(UIStyle.chip("受损建筑 %d" % hurt, UIStyle.DANGER if hurt > 0 else UIStyle.DIM))
		box.add_child(chips)
		if not Game.boss_kinds_killed.is_empty():
			var met := UIStyle.hbox(6)
			for k in Game.boss_kinds_killed.keys():
				met.add_child(UIStyle.chip("遇过 · " + _kind_label(String(k)), Color(0.75, 0.8, 0.95)))
			box.add_child(met)
		# 待战名单：按战斗战力排名，谁该上阵一眼看出。
		var key := "combat"
		var list: Array = Game.residents.duplicate()
		list.sort_custom(func(a, b) -> bool: return Game.battle_power(a, key) > Game.battle_power(b, key))
		var rank_title := UIStyle.label(12, UIStyle.MUTED)
		var total := 0
		for r in list:
			total += Game.battle_power(r, key)
		var top := 0
		for i in mini(Game.MAX_SQUAD, list.size()):
			top += Game.battle_power(list[i], key)
		rank_title.text = "待战名单 · 全队合计 %d · 最强 %d 人 %d" % [total, mini(Game.MAX_SQUAD, list.size()), top]
		box.add_child(rank_title)
		var rank := 1
		for r in list:
			if rank > 5:
				break
			box.add_child(_rank_row(r, key, rank))
			rank += 1
		var foot := UIStyle.label(11, UIStyle.DIM)
		foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		foot.text = "威胁出现时，这里会显示倒计时、出战人选与胜算。"
		box.add_child(foot)
		return
	var accent := UIStyle.DANGER
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent, true))
	_root.add_child(card)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	card.add_child(pad)
	var col := UIStyle.vbox(8)
	pad.add_child(col)
	var head := UIStyle.hbox(8)
	col.add_child(head)
	var name := UIStyle.label(18, Color.WHITE)
	name.text = String(Game.boss["name"])
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UIStyle.chip(_kind_name(), accent))
	var power := UIStyle.label(20, UIStyle.GOLD)
	power.text = "战力 %s" % Game.boss_power_text()
	col.add_child(power)
	if Game.boss_timer_hidden():
		col.add_child(UIStyle.chip("时间不明", UIStyle.MUTED))
	else:
		var stay := float(Game.boss.get("stay", 10 * Game.TICKS_PER_HOUR))
		_timer = UIStyle.meter(stay, accent)
		_timer.value = float(Game.boss.get("left", 0))
		col.add_child(_timer)
		var left := UIStyle.label(12, UIStyle.MUTED)
		left.text = "还剩 %d 小时" % Game.hours_left(int(Game.boss["left"]))
		col.add_child(left)
	col.add_child(UIStyle.chip(_counter(), Color(0.75, 0.88, 1.0)))
	if Game.boss_busy():
		var busy := UIStyle.label(13, Color(0.8, 0.9, 1.0))
		busy.text = "已经有人赶过去了。"
		col.add_child(busy)
		return
	var key := Game.boss_power_key()
	var need := maxi(1, int(Game.boss["power"]))
	var pw: int = Game.team_power(host.boss_picked, key)
	var ratio := float(pw) / float(need)
	var verdict := "还打不过"
	var vcol := UIStyle.DANGER
	if ratio >= 1.0:
		verdict = "占上风"
		vcol = UIStyle.MONEY
	elif ratio >= 0.82:
		verdict = "能险胜"
		vcol = UIStyle.GOLD
	var meter := UIStyle.meter(float(need), vcol)
	meter.value = float(pw)
	col.add_child(meter)
	var sum := UIStyle.label(12, vcol)
	sum.text = "%s %d / %d · %s" % [_power_name(key), pw, need, verdict]
	col.add_child(sum)
	var faces := GridContainer.new()
	faces.columns = 8
	faces.add_theme_constant_override("h_separation", 4)
	faces.add_theme_constant_override("v_separation", 4)
	col.add_child(faces)
	for r in Game.residents:
		faces.add_child(_face(r, key, need))
	var send := UIStyle.make_button("出发（%d人）" % host.boss_picked.size(), accent, Vector2(140, 32))
	send.disabled = host.boss_picked.is_empty()
	send.pressed.connect(func() -> void: host.send_boss())
	col.add_child(send)

func _face(r, key: String, need: int) -> Button:
	var rid := int(r.id)
	var chosen: bool = host.boss_picked.has(rid)
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
	b.disabled = not Game.can_send(rid) or (not chosen and host.boss_picked.size() >= Game.MAX_SQUAD)
	b.pressed.connect(func() -> void: host.toggle_boss_pick(rid))
	return b

## 待战名单一行：名次 · 姓名 · 职业 · 战力 · 状态。
func _rank_row(r, key: String, rank: int) -> Control:
	var row := UIStyle.hbox(8)
	var n := UIStyle.label(12, UIStyle.GOLD if rank == 1 else UIStyle.MUTED)
	n.text = "%d" % rank
	n.custom_minimum_size = Vector2(16, 0)
	row.add_child(n)
	var nm := UIStyle.label(12, UIStyle.INK)
	nm.text = "%s · %s" % [String(r.rname), String(r.job_name)]
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	row.add_child(nm)
	var pw := UIStyle.label(12, Color(0.8, 0.9, 1.0))
	pw.text = "%d" % Game.battle_power(r, key)
	row.add_child(pw)
	if r.state == Resident.State.AWAY:
		row.add_child(UIStyle.chip("外出", UIStyle.DIM))
	elif r.injured(Game.tick):
		row.add_child(UIStyle.chip("受伤", UIStyle.DANGER))
	else:
		row.add_child(UIStyle.chip("在岗", Color(0.62, 0.9, 0.72)))
	return row

func _kind_label(kind: String) -> String:
	match kind:
		"hack":
			return "黑客"
		"stealth":
			return "潜行"
		"swarm":
			return "虫群"
		"glitch":
			return "故障"
		_:
			return "砸店"

func _kind_name() -> String:
	return _kind_label(String(Game.boss.get("kind", "")))

func _counter() -> String:
	match String(Game.boss.get("kind", "")):
		"hack":
			return "派黑客"
		"stealth":
			return "派社交"
		"swarm":
			return "组队围剿"
		"glitch":
			return "派最强"
		_:
			return "派武士"

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
