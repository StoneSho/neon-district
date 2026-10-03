extends PanelContainer
## 点选建筑或居民后出现在右侧。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

const SLOT_TEXT := {
	"neural": "神经", "ocular": "眼部", "os": "OS", "skeletal": "骨骼",
	"leg": "腿", "dermal": "皮肤", "arm": "手臂",
}
const STAT_TEXT := {
	"body": "体质", "reflex": "反应", "tech": "技术", "intelligence": "智力", "cool": "酷",
}

## 职业被动的中文说明（jobs.json 的 passive id → 检视/转职面板文案）。
const PASSIVE_TEXT := {
	"heist_bonus": "劫持委托战力 +10%",
	"fast_sabotage": "破坏委托耗时 -30%",
	"allround": "三系战力 +4",
	"extract_bonus": "提取报酬 +20%",
	"ninja": "破坏/Boss 结算 +25%",
	"boss_hunter": "对 Boss 战力 ×1.5",
	"field_medic": "结算治疗全队",
	"genetic": "升级主属性额外 +2",
	"mech": "战斗战力 ×1.2",
	"intel": "在城时委托板 +1",
	"corporate": "企业建筑造价 -20%",
	"nomad": "移速 ×2",
}

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
var _btn_job: Button
var _picker_open := false

func _ready() -> void:
	clip_contents = true
	add_theme_stylebox_override("panel", UIStyle.panel_box(UIStyle.GOLD))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := UIStyle.vbox(8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	var sc := UIStyle.fill_scroll()
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
	_btn_job = UIStyle.make_button("转职", UIStyle.GOLD, Vector2(0, 32))
	_btn_job.pressed.connect(_open_job_picker)
	root.add_child(_btn_job)

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
	_btn_job.visible = false
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
	var im := ""
	for slot in r.implants.keys():
		im += "%s:%d;" % [String(slot), int(r.implants[slot]["dur"])]
	var stim_total := 0
	for k in Game.stims.keys():
		stim_total += int(Game.stims[k])
	var sig := "r|%d|%d|%s|%d|%d|%d|%s|%s|%d|%d|%d" % [rid, int(r.level), r.status_text(Game.tick), stat_sum, int(r.mastered.size()), 1 if _picker_open else 0, String(r.weapon_id), im, int(Game.junk), stim_total, Game.money]
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
		_section("训练（€%d · %d 小时）" % [Game.TRAIN_COST, Game.TRAIN_HOURS])
		var train_grid := GridContainer.new()
		train_grid.columns = 2
		_body.add_child(train_grid)
		for pair in [["body", "体质"], ["reflex", "反应"], ["tech", "技术"], ["intelligence", "智力"], ["cool", "酷"]]:
			var st := String(pair[0])
			var ok := Game.can_train(rid, st)
			var label2 := ""
			if ok:
				label2 = "%s +%d · €%d" % [pair[1], Game.train_gain(st), Game.TRAIN_COST]
			else:
				var has_site := false
				for fid in Game.train_sites(st):
					if Game._has_fid(fid):
						has_site = true
				if not has_site:
					var names := PackedStringArray()
					for fid in Game.train_sites(st):
						names.append(String(ConfigDB.get_facility(fid).get("name", fid)))
					label2 = "%s（缺 %s）" % [pair[1], "、".join(names)]
				elif int(r.stats[st]) >= 100:
					label2 = "%s 已满" % pair[1]
				else:
					label2 = "%s（€%d）" % [pair[1], Game.TRAIN_COST]
			var tbtn := UIStyle.make_button(label2, Color(0.75, 0.9, 1.0), Vector2(0, 26))
			tbtn.disabled = not ok
			tbtn.pressed.connect(func() -> void:
				if Game.train_stat(rid, st):
					_sig = ""
					refresh()
			)
			train_grid.add_child(tbtn)
		_section("战力")
		var powers := UIStyle.hbox(6)
		_body.add_child(powers)
		for pair in [["combat", "战斗"], ["hack", "黑客"], ["social", "社交"]]:
			powers.add_child(UIStyle.chip("%s %d" % [pair[1], Game.battle_power(r, String(pair[0]))], Color(0.75, 0.9, 1.0)))
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
		for pid in r.passive_ids():
			traits.add_child(UIStyle.chip(String(PASSIVE_TEXT.get(String(pid), String(pid))), Color(0.62, 0.95, 0.72)))
			any = true
		if any:
			_body.add_child(traits)
		if not r.mastered.is_empty():
			_body.add_child(UIStyle.chip("精通 ×%d（转职保留被动）" % r.mastered.size(), UIStyle.GOLD))
		_section("武器")
		var wname := "无"
		if String(r.weapon_id) != "":
			var w: Dictionary = ConfigDB.weapons.get(String(r.weapon_id), {})
			wname = String(w.get("name", r.weapon_id))
		var wline := UIStyle.hbox(6)
		_body.add_child(wline)
		wline.add_child(UIStyle.chip("装备：%s" % wname, Color(0.9, 0.8, 0.55)))
		if String(r.weapon_id) != "":
			var off := UIStyle.make_button("卸下", UIStyle.DANGER, Vector2(64, 26))
			off.pressed.connect(func() -> void:
				Game.unequip_weapon(rid)
				_sig = ""
				refresh()
			)
			wline.add_child(off)
		for wid in Game.warehouse.keys():
			if int(Game.warehouse[wid]) <= 0:
				continue
			var w2: Dictionary = ConfigDB.weapons.get(String(wid), {})
			var wbtn := UIStyle.make_button("装备 %s ×%d" % [
				String(w2.get("name", wid)), int(Game.warehouse[wid])], Color(0.7, 0.9, 1.0), Vector2(0, 26))
			wbtn.pressed.connect(func() -> void:
				if Game.equip_weapon(rid, String(wid)):
					_sig = ""
					refresh()
			)
			_body.add_child(wbtn)
		_section("义体")
		if r.implants.is_empty():
			var nocy := UIStyle.label(11, UIStyle.MUTED)
			nocy.text = "未安装义体（不装就不会有义体需求）"
			_body.add_child(nocy)
		else:
			for slot in r.implants.keys():
				var rec: Dictionary = r.implants[slot]
				var cw: Dictionary = ConfigDB.cyberware.get(String(rec["id"]), {})
				var maxd := int(cw.get("dura", 6))
				var dur := int(rec["dur"])
				var dcol := Color(0.62, 0.95, 0.72)
				if dur <= 0:
					dcol = UIStyle.DANGER
				elif dur <= 2:
					dcol = UIStyle.GOLD
				_body.add_child(UIStyle.chip("%s · %s · 耐久 %d/%d" % [
					SLOT_TEXT.get(String(slot), String(slot)),
					String(cw.get("name", rec["id"])), dur, maxd], dcol))
		if Game.can_repair_implants(rid):
			var fix := UIStyle.make_button("维护义体 €%d/件（需地下诊所）" % Game.IMPLANT_REPAIR_COST, UIStyle.GOLD, Vector2(0, 28))
			fix.pressed.connect(func() -> void:
				Game.repair_implants(rid)
				_sig = ""
				refresh()
			)
			_body.add_child(fix)
		for wid in Game.warehouse.keys():
			if int(Game.warehouse[wid]) <= 0 or not ConfigDB.cyberware.has(String(wid)):
				continue
			if not Game.can_install_implant(rid, String(wid)):
				continue
			var cw2: Dictionary = ConfigDB.cyberware[String(wid)]
			var ibtn := UIStyle.make_button("安装 %s（%s槽）" % [String(cw2["name"]), SLOT_TEXT.get(String(cw2["slot"]), String(cw2["slot"]))], Color(0.5, 0.9, 0.72), Vector2(0, 28))
			ibtn.pressed.connect(func() -> void:
				if Game.install_implant(rid, String(wid)):
					_sig = ""
					refresh()
			)
			_body.add_child(ibtn)
		var gift_row := UIStyle.hbox(6)
		_body.add_child(gift_row)
		var gift_btn := UIStyle.make_button("赠礼（赛博垃圾 ×%d）" % Game.junk, Color(0.8, 0.7, 0.95), Vector2(0, 28))
		gift_btn.disabled = Game.junk < 1
		gift_btn.pressed.connect(func() -> void:
			if Game.gift(rid):
				_sig = ""
				refresh()
		)
		gift_row.add_child(gift_btn)
		for stat in ["body", "reflex", "tech", "intelligence", "cool"]:
			if int(Game.stims.get(stat, 0)) <= 0:
				continue
			var sbtn := UIStyle.make_button("%s+1 ×%d" % [STAT_TEXT[stat], int(Game.stims[stat])], Color(0.95, 0.75, 0.9), Vector2(0, 28))
			sbtn.pressed.connect(func() -> void:
				if Game.use_stim(rid, String(stat)):
					_sig = ""
					refresh()
			)
			gift_row.add_child(sbtn)
		if r.injured(Game.tick):
			var hurt := UIStyle.label(12, UIStyle.DANGER)
			hurt.text = "受伤中，送去诊所，或者等一会儿。"
			hurt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(hurt)
		if _picker_open:
			_section("选择新职业 · 旧职业被动保留")
			var grid := GridContainer.new()
			grid.columns = 2
			_body.add_child(grid)
			for j: Dictionary in ConfigDB.job_list:
				var jid := String(j["id"])
				var ptext := String(PASSIVE_TEXT.get(String(j.get("passive", "")), ""))
				var btn := UIStyle.make_button(
					"%s%s" % [String(j["name"]), "" if ptext.is_empty() else "\n" + ptext],
					UIStyle.INK, Vector2(0, 44))
				btn.disabled = jid == String(r.job_id)
				btn.pressed.connect(_on_job_picked.bind(rid, jid))
				grid.add_child(btn)
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
	# 转职按钮：Lv10 起、人在城内才显示。
	var can_change: bool = int(r.level) >= Game.MASTERY_LEVEL and int(r.state) != Resident.State.AWAY
	_btn_job.visible = can_change
	if can_change:
		_btn_job.text = "转职 €%s · 声望 %d" % [UIStyle.group(Game.JOB_CHANGE_COST), Game.JOB_CHANGE_REP]
		_btn_job.disabled = not Game.can_change_job(rid)

func _open_job_picker() -> void:
	_picker_open = not _picker_open
	_sig = ""
	refresh()

func _on_job_picked(rid: int, jid: String) -> void:
	if Game.change_job(rid, jid):
		_picker_open = false
		_sig = ""
		refresh()

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
