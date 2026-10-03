extends Control
## 顶栏、左侧竖轨、按需展开的面板、右侧详情。规则仍在 Game 里。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

var view
var bank

var _money_label: Label
var _star_label: Label
var _star_bar: ProgressBar
var _star_box: PanelContainer
var _rep_label: Label
var _pop_label: Label
var _clock_label: Label
var _speed_buttons: Array = []
var _rail_buttons: Dictionary = {}
var _threat_dot: ColorRect
var _drawer: PanelContainer
var _pages: Dictionary = {}
var _hint: Label
var _hint_time := 3.0
var _head: PanelContainer
var _head_body: Label
var _head_time := 0.0
var _notice_box: VBoxContainer
var _drawer_tween: Tween
var _drawer_open := true
var _menu: PanelContainer
var _ask: PanelContainer
var _intro_warn: PanelContainer
var _intro_body: Label
var _resume_speed := 1
var _news: PanelContainer
var _news_title: Label
var _news_body: Label
var _news_speed := 1
var _cycle: PanelContainer
var _cycle_list: VBoxContainer
var _cycle_items: Array = []
var _cycle_rid := -1

var _tab := "build"
var picking_uid := -1
var picked: Array = []
var boss_picked: Array = []

const _TAB_NAME := {
	"build": "建造",
	"gig": "委托",
	"people": "居民",
	"threat": "威胁",
	"armory": "军火",
	"cyber": "义体",
	"research": "研究",
	"combos": "相性",
	"ach": "成就",
	"expand": "扩张",
}
const _TAB_COLOR := {
	"build": Color(1.0, 0.62, 0.28),
	"gig": Color(0.4, 0.88, 1.0),
	"people": Color(0.78, 0.55, 1.0),
	"threat": Color(1.0, 0.38, 0.45),
	"armory": Color(0.9, 0.8, 0.55),
	"cyber": Color(0.5, 0.9, 0.72),
	"research": Color(0.55, 0.72, 1.0),
	"combos": Color(1.0, 0.85, 0.4),
	"ach": Color(1.0, 0.92, 0.6),
	"expand": Color(0.65, 1.0, 0.8),
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIFont.build_theme()
	bank = preload("res://scripts/view/sprite_bank.gd").new()
	_build_top()
	_build_rail()
	_build_drawer()
	_build_inspect()
	_build_notices()
	_build_headline()
	_build_hint()
	_build_goal_card()
	_build_pause_menu()
	_build_confirm()
	_build_intro_warning()
	_build_news()
	_build_cycle()
	EventBus.money_changed.connect(_on_money)
	EventBus.notice.connect(_on_notice)
	EventBus.speed_changed.connect(_on_speed)
	EventBus.star_up.connect(_on_star)
	EventBus.board_changed.connect(_invalidate_pages)
	EventBus.boss_changed.connect(_invalidate_pages)
	EventBus.intro_boss.connect(_on_intro_boss)
	EventBus.news_paper.connect(_on_news_paper)
	EventBus.cycle_ready.connect(_on_cycle_ready)
	EventBus.achievement_unlocked.connect(_on_achievement)
	_on_money(Game.money)
	_on_speed(Game.speed)
	_open_tab("build", false)

func _process(delta: float) -> void:
	_clock_label.text = "%s 第%d天 %02d:00" % [
		Game.PERIOD_ICONS[Game.period()], Game.day(), Game.hour_of_day()]
	var ev := Game.event_text()
	if ev != "":
		_clock_label.text += "  " + ev
	_pop_label.text = "%d人 · %.0f%%" % [Game.residents.size(), _avg_satisfaction()]
	_star_label.text = "★%d %s" % [Game.star, Game.star_title()]
	_rep_label.text = "声望 %s" % UIStyle.group(Game.rep)
	_star_bar.value = _star_ratio() * 100.0
	_star_box.tooltip_text = Game.next_goal()
	if _threat_dot != null:
		_threat_dot.visible = not Game.boss.is_empty()
	_paint_rail()
	if _drawer_open and _pages.has(_tab):
		_pages[_tab].refresh()
	_pages["inspect"].refresh()
	_tick_goal_card()
	_tick_hint(delta)
	_tick_notices(delta)
	_tick_headline(delta)

func _input(_event: InputEvent) -> void:
	_hint_time = 3.0

func building_texture(fid: String) -> Texture2D:
	if bank == null:
		return null
	return bank.building_tex(fid, 0)

func portrait(job_id: String) -> Texture2D:
	if bank == null:
		return null
	return bank.idles.get(job_id, null)

func on_build(fid: String) -> void:
	if view == null:
		return
	view.demolish = false
	if view.build_mode == fid:
		view.build_mode = ""
	else:
		view.build_mode = fid
		view.selected_bid = -1
		view.selected_rid = -1
		EventBus.notice.emit("点格子，放下「%s」" % ConfigDB.get_facility(fid)["name"])

func on_rotate() -> void:
	if view == null:
		return
	if view.build_mode == "":
		EventBus.notice.emit("先选一栋建筑")
		return
	view.rotate_build()

func on_demolish_mode() -> void:
	if view == null:
		return
	view.build_mode = ""
	view.demolish = not view.demolish
	if view.demolish:
		EventBus.notice.emit("拆除：点一栋房子，返还一半造价")

func start_pick(uid: int) -> void:
	picking_uid = uid
	picked.clear()
	_pages["gig"].invalidate()

func cancel_pick() -> void:
	picking_uid = -1
	picked.clear()
	_pages["gig"].invalidate()

func toggle_pick(rid: int) -> void:
	if picked.has(rid):
		picked.erase(rid)
	elif picked.size() < Game.MAX_SQUAD and Game.can_send(rid):
		picked.append(rid)
	_pages["gig"].invalidate()

func send_gig(uid: int) -> void:
	if Game.dispatch_gig(uid, picked):
		picking_uid = -1
		picked.clear()
		_pages["gig"].invalidate()
	else:
		EventBus.notice.emit("队伍里有人现在出不了门")

func toggle_boss_pick(rid: int) -> void:
	if boss_picked.has(rid):
		boss_picked.erase(rid)
	elif boss_picked.size() < Game.MAX_SQUAD and Game.can_send(rid):
		boss_picked.append(rid)
	_pages["threat"].invalidate()

func send_boss() -> void:
	if Game.dispatch_boss(boss_picked):
		boss_picked.clear()
		_pages["threat"].invalidate()
	else:
		EventBus.notice.emit("队伍里有人现在出不了门")

func on_resident(rid: int) -> void:
	if view == null:
		return
	view.focus_on(rid)

func on_upgrade() -> void:
	if view == null:
		return
	var bid := int(view.selected_bid)
	var cost := Game.upgrade_cost(bid)
	if cost < 0:
		return
	if not Game.upgrade(bid):
		EventBus.notice.emit("升级要 €%d" % cost)

func on_repair() -> void:
	if view == null:
		return
	if not Game.repair(int(view.selected_bid)):
		EventBus.notice.emit("修复要 €%d" % Game.REPAIR_COST)

func on_inspect_demolish() -> void:
	if view == null:
		return
	var bid := int(view.selected_bid)
	var idx := Game.index_of_bid(bid)
	if idx < 0:
		return
	var nm := String(Game.buildings[idx]["name"])
	Game.remove_bid(bid)
	view.selected_bid = -1
	EventBus.notice.emit("已拆除「%s」，返还一半造价" % nm)

func on_hunt() -> void:
	if view == null:
		return
	if not Game.dispatch_boss([int(view.selected_rid)]):
		EventBus.notice.emit("这个人现在出不了门")

func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 40.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var top_box: StyleBoxFlat = UIStyle.panel_box(Color(0.35, 0.85, 1.0))
	top_box.content_margin_top = 4
	top_box.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", top_box)
	add_child(bar)
	var row := UIStyle.hbox(10)
	bar.add_child(row)
	_money_label = UIStyle.label(20, UIStyle.MONEY)
	row.add_child(_money_label)
	_star_box = PanelContainer.new()
	_star_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_star_box.add_theme_stylebox_override("panel", UIStyle.chip_box(UIStyle.GOLD, 0.12))
	row.add_child(_star_box)
	var star_col := UIStyle.vbox(1)
	_star_box.add_child(star_col)
	_star_label = UIStyle.label(13, UIStyle.GOLD)
	star_col.add_child(_star_label)
	_star_bar = UIStyle.meter(100.0, UIStyle.GOLD)
	_star_bar.custom_minimum_size = Vector2(72, 4)
	star_col.add_child(_star_bar)
	_rep_label = UIStyle.label(13, Color(0.78, 0.84, 1.0))
	row.add_child(_rep_label)
	_pop_label = UIStyle.label(13, Color(1.0, 0.78, 0.92))
	row.add_child(_pop_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_clock_label = UIStyle.label(13, UIStyle.INK)
	row.add_child(_clock_label)
	var labels := ["停", "1×", "2×", "3×"]
	for i in labels.size():
		var b := UIStyle.make_button(labels[i], Color(0.7, 0.92, 1.0), Vector2(36, 26))
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_speed_button.bind(i))
		row.add_child(b)
		_speed_buttons.append(b)

func _build_rail() -> void:
	var rail := PanelContainer.new()
	rail.anchor_top = 0.0
	rail.anchor_bottom = 1.0
	rail.offset_top = 48.0
	rail.offset_bottom = -8.0
	rail.offset_left = 8.0
	rail.offset_right = 76.0
	rail.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := UIStyle.panel_box(Color(0.55, 0.7, 1.0))
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	rail.add_theme_stylebox_override("panel", sb)
	add_child(rail)
	var col := UIStyle.vbox(4)
	rail.add_child(col)
	for id in ["build", "gig", "people", "threat", "armory", "cyber", "research", "combos", "ach", "expand"]:
		var accent: Color = _TAB_COLOR[id]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(60, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = false
		b.pressed.connect(_on_rail.bind(id))
		var inner := UIStyle.vbox(1)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(inner)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 10)
		swatch.color = accent
		swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(swatch)
		var name := UIStyle.label(12, UIStyle.INK)
		name.text = _TAB_NAME[id]
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.clip_text = false
		inner.add_child(name)
		if id == "threat":
			_threat_dot = ColorRect.new()
			_threat_dot.color = UIStyle.DANGER
			_threat_dot.custom_minimum_size = Vector2(8, 8)
			_threat_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_threat_dot.visible = false
			_threat_dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			_threat_dot.offset_left = -12.0
			_threat_dot.offset_right = -4.0
			_threat_dot.offset_top = 4.0
			_threat_dot.offset_bottom = 12.0
			b.add_child(_threat_dot)
		col.add_child(b)
		_rail_buttons[id] = b

func _build_drawer() -> void:
	_drawer = PanelContainer.new()
	_drawer.anchor_top = 0.0
	_drawer.anchor_bottom = 1.0
	_drawer.offset_top = 48.0
	_drawer.offset_bottom = -8.0
	_drawer.offset_left = 84.0
	_drawer.offset_right = 564.0
	_drawer.clip_contents = true
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.add_theme_stylebox_override("panel", UIStyle.panel_box(Color(0.45, 0.75, 1.0)))
	add_child(_drawer)
	var stack := MarginContainer.new()
	stack.clip_contents = true
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.add_child(stack)
	var scripts := {
		"build": preload("res://scripts/ui/panel_build.gd"),
		"gig": preload("res://scripts/ui/panel_gig.gd"),
		"people": preload("res://scripts/ui/panel_people.gd"),
		"threat": preload("res://scripts/ui/panel_threat.gd"),
		"armory": preload("res://scripts/ui/panel_armory.gd"),
		"cyber": preload("res://scripts/ui/panel_cyber.gd"),
		"research": preload("res://scripts/ui/panel_research.gd"),
		"combos": preload("res://scripts/ui/panel_combos.gd"),
		"ach": preload("res://scripts/ui/panel_achievements.gd"),
		"expand": preload("res://scripts/ui/panel_expand.gd"),
	}
	for id in scripts.keys():
		var page = scripts[id].new()
		page.host = self
		page.clip_contents = true
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.visible = false
		stack.add_child(page)
		_pages[id] = page

func _build_inspect() -> void:
	var page = preload("res://scripts/ui/panel_inspect.gd").new()
	page.host = self
	page.anchor_left = 1.0
	page.anchor_right = 1.0
	page.anchor_top = 0.0
	page.anchor_bottom = 1.0
	page.offset_left = -292.0
	page.offset_right = -12.0
	page.offset_top = 48.0
	page.offset_bottom = -8.0
	page.clip_contents = true
	page.visible = false
	add_child(page)
	_pages["inspect"] = page

func _build_notices() -> void:
	_notice_box = VBoxContainer.new()
	_notice_box.alignment = BoxContainer.ALIGNMENT_END
	_notice_box.add_theme_constant_override("separation", 6)
	_notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_box.anchor_left = 0.0
	_notice_box.anchor_right = 0.0
	_notice_box.anchor_top = 1.0
	_notice_box.anchor_bottom = 1.0
	_notice_box.offset_left = 572.0
	_notice_box.offset_right = 920.0
	_notice_box.offset_top = -220.0
	_notice_box.offset_bottom = -16.0
	_notice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_notice_box)

func _build_headline() -> void:
	_head = PanelContainer.new()
	_head.anchor_left = 0.5
	_head.anchor_right = 0.5
	_head.anchor_top = 0.5
	_head.anchor_bottom = 0.5
	_head.offset_left = -220.0
	_head.offset_right = 220.0
	_head.offset_top = -70.0
	_head.offset_bottom = 50.0
	_head.add_theme_stylebox_override("panel", UIStyle.news_box())
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.visible = false
	add_child(_head)
	var col := UIStyle.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_head.add_child(col)
	var title := UIStyle.label(13, UIStyle.GOLD)
	title.text = "号外"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_head_body = UIStyle.label(20, Color(0.95, 0.95, 1.0))
	_head_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_head_body)

var _goal_card: PanelContainer
var _goal_title: Label
var _goal_text: Label
var _goal_hint: Label
var _goal_bar: ProgressBar

## 新手引导目标卡（阶段 B）：显示当前目标与提示，全部完成后变灰收起。
func _build_goal_card() -> void:
	_goal_card = PanelContainer.new()
	_goal_card.anchor_left = 0.0
	_goal_card.anchor_top = 0.0
	_goal_card.offset_left = 590.0
	_goal_card.offset_top = 56.0
	_goal_card.offset_right = 1000.0
	_goal_card.custom_minimum_size = Vector2(410, 0)
	_goal_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_card.add_theme_stylebox_override("panel", UIStyle.card_box(UIStyle.GOLD, false))
	add_child(_goal_card)
	var col := UIStyle.vbox(3)
	_goal_card.add_child(col)
	_goal_title = UIStyle.label(11, UIStyle.GOLD)
	col.add_child(_goal_title)
	_goal_text = UIStyle.label(14, UIStyle.INK)
	_goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_goal_text)
	_goal_hint = UIStyle.label(11, UIStyle.MUTED)
	_goal_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_goal_hint)
	_goal_bar = UIStyle.meter(float(maxi(1, ConfigDB.tutorial_steps.size())), UIStyle.GOLD)
	_goal_bar.custom_minimum_size = Vector2(0, 6)
	col.add_child(_goal_bar)

func _tick_goal_card() -> void:
	if _goal_card == null:
		return
	if Game.at_menu:
		_goal_card.visible = false
		return
	_goal_card.visible = true
	var goal: Dictionary = Game.current_goal()
	var prog: Vector2i = Game.goal_progress()
	_goal_bar.max_value = float(maxi(1, prog.y))
	_goal_bar.value = float(prog.x)
	if goal.is_empty():
		_goal_title.text = "✓ 新手引导完成 %d/%d" % [prog.x, prog.y]
		_goal_text.text = "自由发展吧：升星、扩张、凑更多相性"
		_goal_hint.text = "按空格暂停 · Esc 取消当前操作"
		return
	_goal_title.text = "当前目标 %d/%d" % [prog.x + 1, prog.y]
	_goal_text.text = String(goal.get("text", ""))
	_goal_hint.text = String(goal.get("hint", ""))

func _build_hint() -> void:
	_hint = UIStyle.label(12, Color(0.7, 0.76, 0.9, 0.9))
	_hint.text = "左键放置或点选 · R 旋转 · 右键拖画面 · 滚轮缩放 · 空格暂停 · Esc 取消"
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 576.0
	_hint.offset_right = -300.0
	_hint.offset_top = -28.0
	_hint.offset_bottom = -8.0
	add_child(_hint)

func _cancel_build_modes() -> void:
	if view == null:
		return
	if view.build_mode == "" and not view.demolish and not view.road_mode and not view.clear_mode:
		return
	view.build_mode = ""
	view.demolish = false
	view.road_mode = false
	view.clear_mode = false
	EventBus.notice.emit("已取消建造")

func on_road_mode() -> void:
	if view == null:
		return
	view.build_mode = ""
	view.demolish = false
	view.clear_mode = false
	view.road_mode = not view.road_mode
	if view.road_mode:
		EventBus.notice.emit("铺路：点可走的格子，€%d/格" % Game.ROAD_COST)

func on_clear_mode() -> void:
	if view == null:
		return
	view.build_mode = ""
	view.demolish = false
	view.road_mode = false
	view.clear_mode = not view.clear_mode
	if view.clear_mode:
		EventBus.notice.emit("清废墟：点暗红色的格子，€%d/格" % Game.RUIN_CLEAR_COST)

func _open_tab(id: String, animate: bool = true) -> void:
	if id != "build":
		_cancel_build_modes()
	if id != "gig":
		picking_uid = -1
		picked.clear()
	if id != "threat":
		boss_picked.clear()
	_tab = id
	for k in ["build", "gig", "people", "threat", "armory", "cyber", "research", "combos", "ach", "expand"]:
		_pages[k].visible = k == id
	if _pages.has(id):
		_pages[id].invalidate()
	_slide_drawer(true, animate)

func _close_drawer(animate: bool = true) -> void:
	_cancel_build_modes()
	_tab = ""
	for k in ["build", "gig", "people", "threat", "armory", "cyber", "research", "combos", "ach", "expand"]:
		_pages[k].visible = false
	_slide_drawer(false, animate)

func _on_rail(id: String) -> void:
	if _tab == id and _drawer_open:
		_close_drawer()
	else:
		_open_tab(id)

func _slide_drawer(open: bool, animate: bool) -> void:
	_drawer_open = open
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	var x := 84.0 if open else -360.0
	if not animate:
		_drawer.offset_left = x
		_drawer.offset_right = x + 360.0
		_drawer.visible = open
		_drawer.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
		return
	_drawer.visible = true
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer_tween = create_tween()
	_drawer_tween.tween_property(_drawer, "offset_left", x, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_tween.parallel().tween_property(_drawer, "offset_right", x + 360.0, 0.18)
	if not open:
		_drawer_tween.finished.connect(func() -> void:
			if not _drawer_open:
				_drawer.visible = false
				_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		)

func _paint_rail() -> void:
	for id in _rail_buttons.keys():
		var b: Button = _rail_buttons[id]
		var accent: Color = _TAB_COLOR[id]
		var on: bool = _drawer_open and _tab == String(id)
		b.add_theme_stylebox_override("normal", UIStyle.button_box(accent, on))
		b.add_theme_stylebox_override("hover", UIStyle.button_box(accent, true))
		b.add_theme_stylebox_override("pressed", UIStyle.button_box(accent, true))

func _star_ratio() -> float:
	var req := {}
	for r in Game.STAR_REQS:
		if int(r["star"]) == Game.star + 1:
			req = r
			break
	if req.is_empty():
		return 1.0
	var n := 0
	var acc := 0.0
	var cur := {
		"gigs": Game.gigs_done,
		"bosses": Game.bosses_killed,
		"rep": Game.rep,
		"buildings": Game.buildings.size(),
		"t5": Game.t5_gigs_done,
		"maxed": Game.maxed_building_count(),
		"mastery": Game.top_mastery_count(),
	}
	for key in cur.keys():
		var goal := int(req.get(key, 0))
		if goal <= 0:
			continue
		n += 1
		acc += clampf(float(cur[key]) / float(goal), 0.0, 1.0)
	if n == 0:
		return 1.0
	return acc / float(n)

func _avg_satisfaction() -> float:
	if Game.residents.is_empty():
		return 0.0
	var s := 0.0
	for r in Game.residents:
		s += r.satisfaction()
	return s / float(Game.residents.size())

func _on_money(amount: int) -> void:
	_money_label.text = "€%s" % UIStyle.group(amount)

func _build_pause_menu() -> void:
	_menu = PanelContainer.new()
	_menu.anchor_left = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_top = 0.5
	_menu.anchor_bottom = 0.5
	_menu.offset_left = -140.0
	_menu.offset_right = 140.0
	_menu.offset_top = -150.0
	_menu.offset_bottom = 150.0
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.add_theme_stylebox_override("panel", UIStyle.panel_box(Color(0.45, 0.85, 1.0)))
	_menu.visible = false
	add_child(_menu)
	var col := UIStyle.vbox(10)
	_menu.add_child(col)
	var title := UIStyle.label(16, UIStyle.INK)
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var resume := UIStyle.make_button("继续", UIStyle.MONEY, Vector2(220, 36))
	resume.pressed.connect(_resume_play)
	col.add_child(resume)
	var save := UIStyle.make_button("存档", UIStyle.GOLD, Vector2(220, 36))
	save.pressed.connect(func() -> void: Game.save_slot())
	col.add_child(save)
	var fresh := UIStyle.make_button("新游戏", UIStyle.DANGER, Vector2(220, 36))
	fresh.pressed.connect(_start_new_game)
	col.add_child(fresh)
	var back := UIStyle.make_button("返回主菜单", Color(0.75, 0.82, 1.0), Vector2(220, 36))
	back.pressed.connect(func() -> void: EventBus.return_to_menu.emit())
	col.add_child(back)

func _build_confirm() -> void:
	_ask = PanelContainer.new()
	_ask.anchor_left = 0.5
	_ask.anchor_right = 0.5
	_ask.anchor_top = 0.5
	_ask.anchor_bottom = 0.5
	_ask.offset_left = -180.0
	_ask.offset_right = 180.0
	_ask.offset_top = -110.0
	_ask.offset_bottom = 110.0
	_ask.mouse_filter = Control.MOUSE_FILTER_STOP
	_ask.add_theme_stylebox_override("panel", UIStyle.panel_box(UIStyle.GOLD))
	_ask.visible = false
	add_child(_ask)
	var col := UIStyle.vbox(10)
	_ask.add_child(col)
	var title := UIStyle.label(16, UIStyle.GOLD)
	title.text = "覆盖存档？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var body := UIStyle.label(13, UIStyle.INK)
	body.text = "新游戏会覆盖当前存档。上一份会留在 slot1.json.bak。"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(300, 0)
	col.add_child(body)
	var yes := UIStyle.make_button("确认新游戏", UIStyle.DANGER, Vector2(300, 36))
	yes.pressed.connect(_confirm_new_game)
	col.add_child(yes)
	var no := UIStyle.make_button("取消", UIStyle.INK, Vector2(300, 36))
	no.pressed.connect(func() -> void: _ask.visible = false)
	col.add_child(no)

func _build_intro_warning() -> void:
	_intro_warn = PanelContainer.new()
	_intro_warn.anchor_left = 0.5
	_intro_warn.anchor_right = 0.5
	_intro_warn.anchor_top = 0.5
	_intro_warn.anchor_bottom = 0.5
	_intro_warn.offset_left = -210.0
	_intro_warn.offset_right = 210.0
	_intro_warn.offset_top = -120.0
	_intro_warn.offset_bottom = 120.0
	_intro_warn.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_warn.add_theme_stylebox_override("panel", UIStyle.panel_box(UIStyle.DANGER))
	_intro_warn.visible = false
	add_child(_intro_warn)
	var col := UIStyle.vbox(10)
	_intro_warn.add_child(col)
	var title := UIStyle.label(16, UIStyle.DANGER)
	title.text = "教学威胁"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_intro_body = UIStyle.label(14, UIStyle.INK)
	_intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_body.custom_minimum_size = Vector2(360, 0)
	col.add_child(_intro_body)
	var go := UIStyle.make_button("去威胁栏", UIStyle.DANGER, Vector2(360, 36))
	go.pressed.connect(_dismiss_intro)
	col.add_child(go)

func _on_intro_boss(boss_name: String, hours: int, power: int) -> void:
	_intro_body.text = "「%s」闯进街区，战力 %d。\n%d 小时后才会动手。第一下只让店停业，不会拆掉最后一栋。\n时间已暂停。" % [boss_name, power, hours]
	_intro_warn.visible = true
	if _menu != null:
		_menu.visible = false

func _dismiss_intro() -> void:
	Game.intro_warning = false
	_intro_warn.visible = false
	_open_tab("threat")
	Game.set_speed(1)

## 报纸（阶段 12）：升星/首次相性/首次讨伐某类 Boss 时弹出并暂停。
func _build_news() -> void:
	_news = PanelContainer.new()
	_news.anchor_left = 0.5
	_news.anchor_right = 0.5
	_news.anchor_top = 0.5
	_news.anchor_bottom = 0.5
	_news.offset_left = -240.0
	_news.offset_right = 240.0
	_news.offset_top = -120.0
	_news.offset_bottom = 120.0
	_news.mouse_filter = Control.MOUSE_FILTER_STOP
	_news.add_theme_stylebox_override("panel", UIStyle.panel_box(UIStyle.GOLD))
	_news.visible = false
	add_child(_news)
	var col := UIStyle.vbox(10)
	_news.add_child(col)
	_news_title = UIStyle.label(18, UIStyle.GOLD)
	_news_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_news_title)
	_news_body = UIStyle.label(13, UIStyle.INK)
	_news_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news_body.custom_minimum_size = Vector2(400, 0)
	_news_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_news_body)
	var go := UIStyle.make_button("继续", UIStyle.MONEY, Vector2(400, 36))
	go.pressed.connect(_dismiss_news)
	col.add_child(go)

func _on_news_paper(title: String, body: String) -> void:
	if _news == null:
		return
	_news_speed = Game.speed if Game.speed > 0 else 1
	Game.set_speed(0)
	_news_title.text = title
	_news_body.text = body
	_news.visible = true
	if _menu != null:
		_menu.visible = false

func _dismiss_news() -> void:
	if _news != null:
		_news.visible = false
	if not Game.at_menu and not Game.intro_warning:
		Game.set_speed(_news_speed)

## 周目结算面板（阶段 12）：第 15 年早晨弹出。
func _build_cycle() -> void:
	_cycle = PanelContainer.new()
	_cycle.anchor_left = 0.5
	_cycle.anchor_right = 0.5
	_cycle.anchor_top = 0.5
	_cycle.anchor_bottom = 0.5
	_cycle.offset_left = -260.0
	_cycle.offset_right = 260.0
	_cycle.offset_top = -260.0
	_cycle.offset_bottom = 260.0
	_cycle.mouse_filter = Control.MOUSE_FILTER_STOP
	_cycle.add_theme_stylebox_override("panel", UIStyle.panel_box(Color(0.35, 0.9, 1.0)))
	_cycle.visible = false
	add_child(_cycle)
	var col := UIStyle.vbox(8)
	_cycle.add_child(col)
	var title := UIStyle.label(18, UIStyle.GOLD)
	title.text = "第 15 年 · 街区传奇已成"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var body := UIStyle.label(12, UIStyle.MUTED)
	body.text = "新周目可保留：2 件物品、1 名居民（属性/等级/精通）、相性图鉴"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	_cycle_list = UIStyle.vbox(6)
	col.add_child(_cycle_list)
	var go := UIStyle.make_button("开启新周目", UIStyle.MONEY, Vector2(460, 36))
	go.pressed.connect(_confirm_cycle)
	col.add_child(go)
	var stay := UIStyle.make_button("继续经营", UIStyle.INK, Vector2(460, 36))
	stay.pressed.connect(_dismiss_cycle)
	col.add_child(stay)

func _on_cycle_ready() -> void:
	_cycle_items.clear()
	_cycle_rid = -1
	_rebuild_cycle_choices()
	_cycle.visible = true
	if _menu != null:
		_menu.visible = false

func _rebuild_cycle_choices() -> void:
	for c in _cycle_list.get_children():
		c.queue_free()
	var items_title := UIStyle.label(11, UIStyle.DIM)
	items_title.text = "选 2 件物品（可空）"
	_cycle_list.add_child(items_title)
	var grid := GridContainer.new()
	grid.columns = 2
	_cycle_list.add_child(grid)
	for wid in Game.warehouse.keys():
		if int(Game.warehouse[wid]) <= 0:
			continue
		var nm := String(wid)
		if ConfigDB.weapons.has(String(wid)):
			nm = String(ConfigDB.weapons[String(wid)]["name"])
		elif ConfigDB.cyberware.has(String(wid)):
			nm = "义体·" + String(ConfigDB.cyberware[String(wid)]["name"])
		var on: bool = _cycle_items.has(String(wid))
		var b := UIStyle.make_button(("✓ " if on else "") + nm + " ×%d" % int(Game.warehouse[wid]), UIStyle.INK, Vector2(0, 26))
		b.pressed.connect(func() -> void:
			if _cycle_items.has(String(wid)):
				_cycle_items.erase(String(wid))
			elif _cycle_items.size() < 2:
				_cycle_items.append(String(wid))
			_rebuild_cycle_choices()
		)
		grid.add_child(b)
	var res_title := UIStyle.label(11, UIStyle.DIM)
	res_title.text = "选 1 名居民（可空）"
	_cycle_list.add_child(res_title)
	var rgrid := GridContainer.new()
	rgrid.columns = 2
	_cycle_list.add_child(rgrid)
	for r in Game.residents:
		var on: bool = _cycle_rid == int(r.id)
		var b2 := UIStyle.make_button(("✓ " if on else "") + "%s · %s Lv%d" % [String(r.rname), String(r.job_name), int(r.level)], UIStyle.INK, Vector2(0, 26))
		b2.pressed.connect(func() -> void:
			_cycle_rid = -1 if on else int(r.id)
			_rebuild_cycle_choices()
		)
		rgrid.add_child(b2)

func _confirm_cycle() -> void:
	Game.start_new_cycle(_cycle_items, _cycle_rid)
	_cycle.visible = false
	Game.set_speed(1)

func _dismiss_cycle() -> void:
	_cycle.visible = false
	Game.set_speed(1)

func _resume_play() -> void:
	Game.set_speed(_resume_speed if _resume_speed > 0 else 1)

func _start_new_game() -> void:
	if Game.has_save() or Game.session_started:
		_ask.visible = true
		return
	_confirm_new_game()

func _confirm_new_game() -> void:
	_ask.visible = false
	if view != null:
		view.build_mode = ""
		view.demolish = false
		view.road_mode = false
		view.clear_mode = false
		view.selected_bid = -1
		view.selected_rid = -1
	Game.new_game()
	_resume_speed = 1
	Game.set_speed(1)
	_invalidate_pages()

func _on_speed(s: int) -> void:
	if s > 0:
		_resume_speed = s
	for i in _speed_buttons.size():
		var b: Button = _speed_buttons[i]
		var on: bool = i == s
		var accent := UIStyle.GOLD if on else Color(0.55, 0.88, 1.0)
		b.add_theme_color_override("font_color", accent)
		b.add_theme_stylebox_override("normal", UIStyle.button_box(accent, on))
		b.add_theme_stylebox_override("hover", UIStyle.button_box(accent, true))
		b.add_theme_stylebox_override("pressed", UIStyle.button_box(accent, true))
	if _menu != null:
		_menu.visible = s == 0 and not Game.at_menu and not Game.intro_warning

func _on_speed_button(s: int) -> void:
	Game.set_speed(s)

func _on_notice(text: String) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UIStyle.toast_box())
	p.set_meta("t", 2.5)
	var l := UIStyle.label(13, Color(1.0, 0.94, 0.8))
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.custom_minimum_size = Vector2(300, 0)
	p.add_child(l)
	_notice_box.add_child(p)
	_notice_box.move_child(p, 0)
	while _notice_box.get_child_count() > 3:
		var last := _notice_box.get_child(_notice_box.get_child_count() - 1)
		_notice_box.remove_child(last)
		last.queue_free()

func _tick_notices(delta: float) -> void:
	for i in range(_notice_box.get_child_count() - 1, -1, -1):
		var p := _notice_box.get_child(i)
		var t := float(p.get_meta("t")) - delta
		p.set_meta("t", t)
		p.modulate.a = clampf(t / 0.35, 0.0, 1.0)
		if t <= 0.0:
			p.queue_free()

func _tick_hint(delta: float) -> void:
	if _hint_time > 0.0:
		_hint_time -= delta
	_hint.modulate.a = clampf(_hint_time / 0.4, 0.0, 1.0)

func _tick_headline(delta: float) -> void:
	if _head_time <= 0.0:
		return
	_head_time -= delta
	_head.modulate.a = clampf(_head_time / 0.4, 0.0, 1.0)
	if _head_time <= 0.0:
		_head.visible = false

func _on_star(star: int, title: String) -> void:
	_head_body.text = "%d 星\n%s" % [star, title]
	_head.visible = true
	_head_time = 3.4
	_head.modulate.a = 1.0
	_head.scale = Vector2(0.92, 0.92)

## 成就解锁：复用头条条插播一条金色提示（阶段 C）。
func _on_achievement(_id: String, title: String, desc: String, money: int, rep: int) -> void:
	var extra := PackedStringArray()
	if money > 0:
		extra.append("€%s" % UIStyle.group(money))
	if rep > 0:
		extra.append("声望 +%d" % rep)
	_head_body.text = "🏆 %s\n%s%s" % [title, desc, ("  ·  " + " / ".join(extra)) if extra.size() > 0 else ""]
	_head.visible = true
	_head_time = 3.0
	_head.modulate.a = 1.0
	_head.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	tw.tween_property(_head, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _pages.has("build"):
		_pages["build"].invalidate()

func _invalidate_pages() -> void:
	for id in ["gig", "threat", "people", "build", "armory", "cyber", "research", "combos", "ach", "expand"]:
		if _pages.has(id):
			_pages[id].invalidate()
