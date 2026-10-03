extends Control
## 成就与统计页（阶段 C）：已解锁成就 + 里程碑统计。
## 只读 Game 状态与 ConfigDB 数据表，不改规则。

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
	# 进度用粗粒度采样，避免每帧重建。
	var sig := "%d/%d" % [Game.achievement_unlocked_count(), ConfigDB.achievements.size()]
	sig += "|%d|%d|%d|%d" % [Game.buildings.size(), Game.residents.size(), Game.gigs_done, Game.bosses_killed]
	sig += "|%d|%d|%d" % [Game.ruins_cleared, Game.implants_installed, Game.combos_found.size()]
	if sig == _sig:
		return
	_sig = sig
	_rebuild()

func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var total := ConfigDB.achievements.size()
	var done := Game.achievement_unlocked_count()
	var head := UIStyle.label(13, UIStyle.MUTED)
	head.text = "成就 %d / %d" % [done, total]
	_body.add_child(head)
	var prog := UIStyle.meter(float(maxi(1, total)), UIStyle.GOLD)
	prog.value = float(done)
	prog.custom_minimum_size = Vector2(0, 10)
	_body.add_child(prog)
	for a in ConfigDB.achievements:
		_body.add_child(_ach_row(a))
	_body.add_child(_stats_block())

## 一条成就：已解锁金色高亮 + 进度条；未解锁显示条件与当前进度。
func _ach_row(a: Dictionary) -> PanelContainer:
	var aid := String(a["id"])
	var got: bool = Game.achievement_unlocked(aid)
	var accent := UIStyle.GOLD if got else Color(0.5, 0.55, 0.68)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 44)
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent, got))
	var row := UIStyle.hbox(8)
	card.add_child(row)
	var mark := UIStyle.label(14, UIStyle.GOLD if got else UIStyle.DIM)
	mark.text = "🏆" if got else "○"
	row.add_child(mark)
	var col := UIStyle.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := UIStyle.label(13, UIStyle.INK if got else Color(0.76, 0.8, 0.9))
	name.text = "%s · %s" % [String(a["name"]), String(a["desc"])]
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(name)
	var pr: Vector2 = Game.achievement_progress(a)
	var bar := UIStyle.meter(pr.y, UIStyle.GOLD if got else Color(0.6, 0.65, 0.8))
	bar.value = pr.x
	bar.custom_minimum_size = Vector2(0, 6)
	col.add_child(bar)
	var info := UIStyle.label(11, UIStyle.MUTED)
	info.text = "%d / %d" % [int(pr.x), int(pr.y)]
	row.add_child(info)
	var pay := int(a.get("money", 0))
	var rp := int(a.get("rep", 0))
	if pay > 0 or rp > 0:
		var reward := PackedStringArray()
		if pay > 0:
			reward.append("€%s" % UIStyle.group(pay))
		if rp > 0:
			reward.append("声望 +%d" % rp)
		# 未解锁用暗色静态标签，解锁后才高亮——避免看起来像能点击领奖。
		row.add_child(UIStyle.chip(" / ".join(reward), UIStyle.MONEY if got else UIStyle.DIM))
	return card

## 里程碑统计块：让玩家回看自己的经营成果。
func _stats_block() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(Color(0.55, 0.7, 1.0), false))
	var col := UIStyle.vbox(4)
	card.add_child(col)
	var title := UIStyle.label(13, Color(0.7, 0.82, 1.0))
	title.text = "里程碑统计"
	col.add_child(title)
	var rows := [
		["游戏天数", "%d 天（第 %d 年）" % [Game.day(), Game.day() / Game.YEAR_DAYS + 1]],
		["累计收入", "€%s" % UIStyle.group(Game.lifetime_income)],
		["当前现金", "€%s" % UIStyle.group(Game.money)],
		["声望 / 星级", "%s · ★%d %s" % [UIStyle.group(Game.rep), Game.star, Game.star_title()]],
		["建筑 / 满级", "%d 栋 · 满级 %d" % [Game.buildings.size(), Game.maxed_building_count()]],
		["人口 / 上限", "%d / %d 人" % [Game.residents.size(), Game.resident_cap()]],
		["委托 / 讨伐", "%d 条 · %d 只" % [Game.gigs_done, Game.bosses_killed]],
		["相性 / 研究", "%d 组 · %d 条" % [Game.combos_found.size(), Game.research_done.size()]],
		["废墟清理 / 义体安装", "%d 格 · %d 件" % [Game.ruins_cleared, Game.implants_installed]],
		["地图规模", "%d × %d 格" % [Game.unlocked_w, Game.unlocked_h]],
	]
	for r in rows:
		var line := UIStyle.hbox(8)
		var k := UIStyle.label(11, UIStyle.MUTED)
		k.text = String(r[0])
		k.custom_minimum_size = Vector2(120, 0)
		line.add_child(k)
		var v := UIStyle.label(12, UIStyle.INK)
		v.text = String(r[1])
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.clip_text = true
		line.add_child(v)
		col.add_child(line)
	return card
