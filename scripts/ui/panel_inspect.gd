extends PanelContainer
## 点选建筑或居民后出现在右侧。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

var host
var _sig := ""
var _title: Label
var _sub: Label
var _thumb: CenterContainer
var _body: VBoxContainer
var _need_bars: Dictionary = {}
var _btn_up: Button
var _btn_fix: Button
var _btn_del: Button
var _btn_hunt: Button

func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_box(UIStyle.GOLD))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := UIStyle.vbox(8)
	add_child(root)
	var head := UIStyle.hbox(8)
	root.add_child(head)
	_thumb = CenterContainer.new()
	_thumb.custom_minimum_size = Vector2(56, 56)
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_thumb)
	var titles := UIStyle.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_title = UIStyle.label(16, UIStyle.GOLD)
	titles.add_child(_title)
	_sub = UIStyle.label(12, UIStyle.MUTED)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_sub)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	_body = UIStyle.vbox(6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)
	var row := UIStyle.hbox(6)
	root.add_child(row)
	_btn_up = UIStyle.make_button("升级", UIStyle.MONEY, Vector2(0, 32))
	_btn_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_up.pressed.connect(func() -> void: host.on_upgrade())
	row.add_child(_btn_up)
	_btn_fix = UIStyle.make_button("修复", UIStyle.GOLD, Vector2(0, 32))
	_btn_fix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_fix.pressed.connect(func() -> void: host.on_repair())
	row.add_child(_btn_fix)
	_btn_del = UIStyle.make_button("拆除", UIStyle.DANGER, Vector2(0, 32))
	_btn_del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_del.pressed.connect(func() -> void: host.on_inspect_demolish())
	row.add_child(_btn_del)
	_btn_hunt = UIStyle.make_button("派去讨伐", UIStyle.DANGER, Vector2(0, 32))
	_btn_hunt.pressed.connect(func() -> void: host.on_hunt())
	root.add_child(_btn_hunt)

func refresh() -> void:
	if host.view == null:
		visible = false
		return
	var bid := int(host.view.selected_bid)
	var rid := int(host.view.selected_rid)
	if bid >= 0 and Game.index_of_bid(bid) >= 0:
		visible = true
		_show_building(bid)
		return
	if rid >= 0 and Game.resident_by_id(rid) != null:
		visible = true
		_show_resident(rid)
		return
	visible = false
	_sig = ""

func _clear_thumb() -> void:
	for c in _thumb.get_children():
		c.queue_free()

func _clear_body() -> void:
	for c in _body.get_children():
		c.queue_free()
	_need_bars.clear()

func _show_building(bid: int) -> void:
	var idx := Game.index_of_bid(bid)
	var b: Dictionary = Game.buildings[idx]
	var tier: Dictionary = Game.region_tier_for(idx)
	var combo := Game.combo_mult_for(idx)
	var sig := "b|%d|%d|%d|%d|%d|%d|%d|%d" % [
		bid, int(b["level"]), int(tier["count"]), int(combo * 100.0),
		Game.estimate_income(idx), int(b["visits"]),
		1 if bool(b.get("damaged", false)) else 0,
		Game.hours_left(int(b.get("disabled_until", 0)) - Game.tick),
	]
	if sig != _sig:
		_sig = sig
		var neon: Color = ConfigDB.theme_color(String(b["theme"]))
		add_theme_stylebox_override("panel", UIStyle.panel_box(neon))
		_clear_thumb()
		_thumb.add_child(UIStyle.building_thumb(host.building_texture(String(b["fid"])), neon))
		_title.text = String(b["name"])
		_sub.text = "Lv%d · %s" % [int(b["level"]), ConfigDB.theme_name(String(b["theme"]))]
		_clear_body()
		var chips := UIStyle.hbox(6)
		_body.add_child(chips)
		var damaged: bool = bool(b.get("damaged", false))
		var hacked: bool = Game.is_hacked(b)
		if damaged:
			chips.add_child(UIStyle.chip("受损", UIStyle.DANGER))
		elif hacked:
			chips.add_child(UIStyle.chip("停业 %d小时" % Game.hours_left(int(b["disabled_until"]) - Game.tick), Color(0.5, 0.9, 1.0)))
		else:
			chips.add_child(UIStyle.chip("€%d" % Game.estimate_income(idx), UIStyle.MONEY))
		chips.add_child(UIStyle.chip("%d 访客" % int(b["visits"]), UIStyle.INK))
		chips.add_child(UIStyle.chip("%s ×%.1f" % [tier["name"], float(tier["mult"])], Color(0.7, 0.88, 1.0)))
		if combo > 1.05:
			_body.add_child(UIStyle.chip("相性 ×%.1f" % combo, UIStyle.GOLD))
		var near := _near_text(b)
		if near != "":
			var n := UIStyle.label(12, Color(0.7, 1.0, 0.88))
			n.text = near
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(n)
		var desc := UIStyle.label(12, UIStyle.MUTED)
		desc.text = String(ConfigDB.get_facility(String(b["fid"])).get("desc", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(desc)
	var cost := Game.upgrade_cost(bid)
	_btn_up.visible = true
	_btn_fix.visible = bool(b.get("damaged", false))
	_btn_del.visible = true
	_btn_hunt.visible = false
	if cost < 0:
		_btn_up.text = "已满级"
		_btn_up.disabled = true
	else:
		_btn_up.text = "升级 €%s" % UIStyle.group(cost)
		_btn_up.disabled = Game.money < cost
	_btn_fix.text = "修复 €%d" % Game.REPAIR_COST
	_btn_fix.disabled = not bool(b.get("damaged", false)) or Game.money < Game.REPAIR_COST

func _show_resident(rid: int) -> void:
	var r = Game.resident_by_id(rid)
	var stat_sum := int(r.stats["body"]) + int(r.stats["reflex"]) + int(r.stats["tech"]) \
		+ int(r.stats["intelligence"]) + int(r.stats["cool"])
	var sig := "r|%d|%d|%s|%d" % [rid, int(r.level), r.status_text(Game.tick), stat_sum]
	if sig != _sig:
		_sig = sig
		var accent: Color = r.color
		add_theme_stylebox_override("panel", UIStyle.panel_box(accent))
		_clear_thumb()
		_thumb.add_child(UIStyle.portrait(host.portrait(String(r.job_id)), accent, 56.0))
		_title.text = String(r.rname)
		_sub.text = "%s · Lv%d · %s" % [r.job_name, int(r.level), r.status_text(Game.tick)]
		_clear_body()
		_section("五维")
		for pair in [["body", "体质"], ["reflex", "反应"], ["tech", "技术"], ["intelligence", "智力"], ["cool", "酷"]]:
			var sv := int(r.stats[String(pair[0])])
			_stat_row(String(pair[1]), sv, UIStyle.stat_color(sv))
		_section("战力")
		var powers := UIStyle.hbox(6)
		_body.add_child(powers)
		for pair in [["combat", "战斗"], ["hack", "黑客"], ["social", "社交"]]:
			powers.add_child(UIStyle.chip("%s %d" % [pair[1], r.power(String(pair[0]))], Color(0.75, 0.9, 1.0)))
		_section("需求")
		for pair in [["hunger", "饥饿"], ["fun", "娱乐"], ["health", "健康"], ["cyberware", "义体"]]:
			var key := String(pair[0])
			var v := float(r.needs[key])
			var line := UIStyle.hbox(6)
			_body.add_child(line)
			var name := UIStyle.label(12, UIStyle.MUTED)
			name.text = String(pair[1])
			name.custom_minimum_size = Vector2(32, 0)
			line.add_child(name)
			var bar := UIStyle.meter(100.0, UIStyle.need_color(v))
			bar.value = v
			line.add_child(bar)
			_need_bars[key] = bar
		var traits := UIStyle.hbox(6)
		var any := false
		if float(r.reward_mult) > 1.01:
			traits.add_child(UIStyle.chip("报酬 +%d%%" % int(round((float(r.reward_mult) - 1.0) * 100.0)), UIStyle.MONEY))
			any = true
		if float(r.rep_mult) > 1.01:
			traits.add_child(UIStyle.chip("声望 +%d%%" % int(round((float(r.rep_mult) - 1.0) * 100.0)), UIStyle.GOLD))
			any = true
		if float(r.injury_mult) < 0.9:
			traits.add_child(UIStyle.chip("不易受伤", Color(0.7, 0.9, 1.0)))
			any = true
		if any:
			_body.add_child(traits)
		if r.injured(Game.tick):
			var hurt := UIStyle.label(12, UIStyle.DANGER)
			hurt.text = "受伤中，送去诊所，或者等一会儿。"
			hurt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(hurt)
	for k in _need_bars.keys():
		var bar: ProgressBar = _need_bars[k]
		if not is_instance_valid(bar):
			continue
		var v := float(r.needs[k])
		bar.value = v
		UIStyle.paint_meter(bar, UIStyle.need_color(v))
	_btn_up.visible = false
	_btn_fix.visible = false
	_btn_del.visible = false
	var can: bool = (not Game.boss.is_empty()) and (not Game.boss_busy()) and int(r.state) != Resident.State.AWAY and (not r.injured(Game.tick))
	_btn_hunt.visible = not Game.boss.is_empty()
	_btn_hunt.disabled = not can

func _section(text: String) -> void:
	var l := UIStyle.label(11, UIStyle.DIM)
	l.text = text
	_body.add_child(l)

func _stat_row(name: String, val: int, col: Color) -> void:
	var line := UIStyle.hbox(6)
	_body.add_child(line)
	var k := UIStyle.label(12, UIStyle.MUTED)
	k.text = name
	k.custom_minimum_size = Vector2(32, 0)
	line.add_child(k)
	var bar := UIStyle.meter(100.0, col)
	bar.value = float(val)
	line.add_child(bar)
	var n := UIStyle.label(12, col)
	n.text = str(val)
	n.custom_minimum_size = Vector2(24, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(n)

func _near_text(b: Dictionary) -> String:
	var bits: PackedStringArray = []
	if String(b["theme"]) != "deco" and Game._near_fid(b, "biolum_tree", 2):
		bits.append("生物光树 +5% 收入")
	if Game._near_fid(b, "neon_mushroom", 2):
		bits.append("霓虹菇让客人多恢复一点")
	if Game._near_fid(b, "chrome_vine", 2):
		bits.append("铬藤挡住一部分破坏")
	return "，".join(bits)
