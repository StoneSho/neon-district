extends Node
## 模拟内核：时间、建造、居民、委托、赛博精神病。与渲染无关。

const GW := 20
const GH := 15
## 逻辑网格上限（阶段 9）：开局区 20×15，随星级向东/向北扩张。
const MAX_GW := 50
const MAX_GH := 40
## 废墟清理与铺路费用（阶段 9）。
const RUIN_CLEAR_COST := 200
const ROAD_COST := 50
const TICKS_PER_DAY := 480
const TICKS_PER_PERIOD := 120
const TICKS_PER_HOUR := 30
const TPS := 6.0
const REPAIR_COST := 180
const MAX_SQUAD := 4

## Boss 从降临到第一次动手的间隔（小时）。
## 教学 Boss 要等玩家打完第一单，并且给足一个整天再动手。
const BOSS_GRACE_HOURS := 3
const BOSS_INTRO_GRACE_HOURS := 24
const BOSS_INTRO_POWER := 200
## 攻击间隔（小时）。原为 2，配合 10 小时存活期能打满 4 次，
## 而 Lv1 建筑只扛 2 击，导致不干预就会被清空。
const BOSS_ATTACK_GAP_HOURS := 3

const PERIOD_NAMES: PackedStringArray = ["夜晚", "早晨", "下午", "傍晚"]
const PERIOD_ICONS: PackedStringArray = ["🌙", "🌅", "☀️", "🌆"]
const STAR_TITLES: PackedStringArray = [
	"", "街头混混", "地头蛇", "街区名人", "夜城掌门", "传说人物",
	"街头传奇", "企业合伙人", "地下之王", "夜之城传说", "来生之主",
]
const MAX_STAR := 10

## 职业系统（阶段 2）。居民等级上限 20，Lv10 记精通，转职花费与条件。
const MAX_RESIDENT_LEVEL := 20
const MASTERY_LEVEL := 10
const JOB_CHANGE_COST := 1500
const JOB_CHANGE_REP := 300
## 义体维护单价（阶段 5，地下诊所）。
const IMPLANT_REPAIR_COST := 50
## 训练（阶段 7）：单次费用与离城时长（小时）。
const TRAIN_COST := 200
const TRAIN_HOURS := 2
const STAT_NAMES := {
	"body": "体质", "reflex": "反应", "tech": "技术",
	"intelligence": "智力", "cool": "酷",
}
## 研究（阶段 6）：1 垃圾 → 10 知识点；强化剂 20 知识点/支；
## 研究槽 = 研究实验室×2 + 秘密服务器×1；秘密服务器每栋耗时 -20%（封顶 -40%）；
## 派 1–2 名技术系居民加速，每人 -15% 耗时。
const JUNK_KNOWLEDGE := 10
const KNOWLEDGE_STIM_COST := 20
const RESEARCH_RESIDENT_SPEED := 0.15
const RESEARCH_SERVER_SPEED := 0.2
## 周目与年度大赏（阶段 12）：1 年 = 12 游戏日，15 年（180 天）结算周目。
const YEAR_DAYS := 12
const CYCLE_DAYS := 15 * 12
## 压力与后果（阶段 A）：连续不满 3 天搬走；破产每天扣声望、第 3 天抵押建筑；
## 每 4 天检查一次口碑迁入（满意度 ≥60 且声望 ≥300）。
const UNHAPPY_LEAVE := 3
const BROKE_REP_PENALTY := 30
const BROKE_SELL_DAYS := 3
const IMMIGRATION_DAYS := 4
const IMMIGRATION_REP := 300
## 城市扩张系统（阶段 D）：地价 + 城区投资。
## 地价：基础 100，道路 +8、建筑 +5~+11、装饰再 +6、废墟 -12（半径 2 递减），钳制 20~240。
## 地价倍率：0.85 ~ 1.35，直接乘进建筑收入 → 后期布局有优化空间。
## 城区：16×12 格一块，最大地图 4×4 = 16 个城区；投资 1 级 → 区内收入 +6%、需求衰减 -4%，最高 3 级。
const LAND_BASE := 100
const LAND_MIN := 20
const LAND_MAX := 240
const DISTRICT_W := 16
const DISTRICT_H := 12
const DISTRICT_COLS := 4
const DISTRICT_ROWS := 4
const DISTRICT_MAX_LEVEL := 3
const DISTRICT_UPGRADE_COST := 800
const DISTRICT_BUILDINGS_PER_LEVEL := 4
const DISTRICT_INCOME_PER_LEVEL := 0.06
const DISTRICT_DECAY_PER_LEVEL := 0.04
## 意见气泡文案（阶段 12）。
const NEED_TEXT := {"hunger": "饿坏了", "fun": "闷得慌", "health": "要看病", "cyberware": "义体失修"}
const NEED_FAC_TEXT := {"hunger": "街上没吃的", "fun": "没地方玩", "health": "缺诊所", "cyberware": "缺义体店"}
## 训练场地要求：哪项五维需要哪些建筑（有其一即可）。
const TRAIN_SITES := {
	"body": ["street_arena", "fight_cage"],
	"reflex": ["street_arena", "fight_cage"],
	"tech": ["netrunner_den", "research_lab"],
	"intelligence": ["netrunner_den", "research_lab"],
	"cool": ["neon_bar", "neon_dance_club"],
}

## 升星门槛。按星级升序，每项列出需要达成的条件与对玩家的说明。
## 加新星级只改这张表，_recalc_star() 和 next_goal() 都从这里派生。
const STAR_REQS: Array = [
	{
		"star": 2, "gigs": 1, "bosses": 0, "rep": 0, "buildings": 0,
		"text": "成功完成 1 次委托（部分成功不算）",
	},
	{
		"star": 3, "gigs": 2, "bosses": 1, "rep": 0, "buildings": 0,
		"text": "再完成 1 次委托，并讨伐 1 次赛博精神病",
	},
	{
		"star": 4, "gigs": 25, "bosses": 5, "rep": 1500, "buildings": 10,
		"text": "完成 25 次委托 · 讨伐 5 次 · 声望 1500 · 街区 10 栋",
	},
	{
		"star": 5, "gigs": 60, "bosses": 12, "rep": 4500, "buildings": 14,
		"text": "完成 60 次委托 · 讨伐 12 次 · 声望 4500 · 街区 14 栋",
	},
	# 6–8 星沿用次数/声望/建筑条件，避免把已经能打到的 5 星突然改严。
	{
		"star": 6, "gigs": 90, "bosses": 18, "rep": 7000, "buildings": 18,
		"text": "完成 90 次委托 · 讨伐 18 次 · 声望 7000 · 街区 18 栋",
	},
	{
		"star": 7, "gigs": 130, "bosses": 26, "rep": 11000, "buildings": 22,
		"text": "完成 130 次委托 · 讨伐 26 次 · 声望 11000 · 街区 22 栋",
	},
	{
		"star": 8, "gigs": 180, "bosses": 36, "rep": 16000, "buildings": 26,
		"text": "完成 180 次委托 · 讨伐 36 次 · 声望 16000 · 街区 26 栋",
	},
	{
		"star": 9, "gigs": 240, "bosses": 50, "rep": 22000, "buildings": 30,
		"t5": 1, "maxed": 1,
		"text": "完成 240 次委托 · 讨伐 50 次 · 声望 22000 · 30 栋 · 完成过 T5 委托 · 一座设施满级",
	},
	{
		"star": 10, "gigs": 320, "bosses": 70, "rep": 30000, "buildings": 34,
		"mastery": 16,
		"text": "完成 320 次委托 · 讨伐 70 次 · 声望 30000 · 34 栋 · 培养一名全职业精通居民",
	},
]
const REGION_TIERS: Array = [
	{ "min": 10, "mult": 2.0, "name": "大型" },
	{ "min": 6, "mult": 1.5, "name": "中型" },
	{ "min": 3, "mult": 1.2, "name": "小型" },
	{ "min": 0, "mult": 1.0, "name": "萌芽" },
]
const RESIDENT_NAMES: PackedStringArray = [
	"V", "Judy", "Panam", "River", "Kerry", "Rogue", "Jackie", "Lucy",
]

## 随机事件表。加事件只改这里，`_roll_event()` 与 `event_mult()` 都从表派生。
##   mult     收入倍率
##   themes   只作用于这些主题（空 = 全街）
##   tags     只作用于这些 tag（空 = 不按 tag 过滤）
##   periods  持续几个时段（0 = 瞬时事件，走 instant 分支）
##   instant  瞬时效果标识
const EVENTS: Array = [
	# — 机遇 —
	{
		"kind": "festival", "name": "街头音乐节", "good": true,
		"mult": 2.0, "themes": ["street", "neon"], "tags": [], "periods": 2,
		"notice": "街头音乐节 · 街头和霓虹的店收入翻倍",
	},
	{
		"kind": "investor", "name": "投资人到访", "good": true,
		"mult": 1.5, "themes": [], "tags": [], "periods": 1,
		"rep": 15, "notice": "投资人到访 · 全街收入 ×1.5，声望 +15",
	},
	{
		"kind": "boom", "name": "人口涌入", "good": true,
		"mult": 1.0, "themes": [], "tags": [], "periods": 0,
		"instant": "spawn", "amount": 5, "notice": "人口涌入 · 新居民搬进了街区",
	},
	# — 危机 —
	{
		"kind": "corp_raid", "name": "企业突袭", "good": false,
		"mult": 0.5, "themes": ["corporate"], "tags": [], "periods": 2,
		"notice": "企业突袭 · 企业类建筑收入减半",
	},
	{
		"kind": "hacker_attack", "name": "黑客攻击", "good": false,
		"mult": 0.0, "themes": [], "tags": ["tech"], "periods": 1,
		"notice": "黑客攻击 · 科技类设施暂时瘫痪",
	},
	{
		"kind": "gang_war", "name": "帮派火拼", "good": false,
		"mult": 1.0, "themes": [], "tags": [], "periods": 0,
		"instant": "damage", "amount": 2, "notice": "帮派火拼 · 有店被砸了",
	},
	# — 灾难 —
	{
		"kind": "acid", "name": "酸雨", "good": false,
		"mult": 0.7, "themes": [], "tags": [], "periods": 1,
		"notice": "酸雨 · 所有店暂时少赚三成",
	},
	{
		"kind": "blackout", "name": "大停电", "good": false,
		"mult": 0.0, "themes": ["neon"], "tags": [], "periods": 1,
		"notice": "大停电 · 霓虹类设施完全停业",
	},
	{
		"kind": "data_storm", "name": "数据风暴", "good": false,
		"mult": 1.0, "themes": [], "tags": [], "periods": 1,
		"block_gigs": true, "notice": "数据风暴 · 委托暂停生成",
	},
]

var money: int = 5000
## 武器仓库：weapon_id → 持有数量（阶段 4）。义体共用（阶段 5）。
var warehouse: Dictionary = {}
## 赛博垃圾（阶段 5）：赠礼消耗 1 个；阶段 6 的黑客工作台继续用。
var junk: int = 0
## 强化剂库存：五维 id → 数量（阶段 5）。使用永久 +1 主属性。
var stims: Dictionary = {}
## 知识点（阶段 6，黑客工作台）：垃圾回收产出，兑换武器/义体/强化剂。
var knowledge: int = 0
## 进行中的研究：id -> {"left": ticks, "total": ticks, "rids": [rid]}。
var research: Dictionary = {}
## 已完成的研究 id。完成后对应设施提前 1 星可建。
var research_done: Array = []
## 已解锁矩形（阶段 9）：开局 20×15，偶数星向东 +4、奇数星向北 +4，上限 50×40。
var unlocked_w: int = GW
var unlocked_h: int = GH
## 废墟与道路（阶段 9）：cell -> true。废墟不可建不可走，€200/格清理；道路 €50/格。
var ruins: Dictionary = {}
var roads: Dictionary = {}
## T5（5 星及以上）委托成功完成次数（阶段 10 的 9 星门槛）。
var t5_gigs_done: int = 0
## 周目（阶段 12）：12 游戏日 = 1 年，15 年（180 天）结算一次周目。
var _cycle_done := false
## 居民意见气泡缓存（阶段 12）：rid -> 短句，每 15 tick 刷新，最多 4 条。
var _complaints: Dictionary = {}
## 每种 Boss 是否已被首次讨伐过（阶段 12 报纸触发）。
var boss_kinds_killed: Dictionary = {}
var rep: int = 0
var star: int = 1
var tick: int = 0
var speed: int = 0
var at_menu := true
var session_started := false
var intro_warning := false
var buildings: Array = []
var residents: Array = []
var occupancy: Dictionary = {}
var gig_board: Array = []
var missions: Array = []
var boss: Dictionary = {}
var event_kind: String = ""
var event_name: String = ""
var event_until: int = 0
var gigs_done: int = 0
var bosses_killed: int = 0
var combos_found: Dictionary = {}
var astar := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()

var _accum: float = 0.0
var _next_rid: int = 0
var _next_bid: int = 1
var _next_gig_uid: int = 1
var _region_cache: Array = []
var _fids_cache: Array = []
var _region_dirty := true
var _combo_of: Dictionary = {}
## 当前布局下激活的相性 id → true（含全局效果，如武器折扣/Boss 加成）。
var _combo_flags: Dictionary = {}
## 激活相性的成员建筑索引：id -> {idx: true}（加成只给连通簇内的建筑）。
var _combo_members: Dictionary = {}
var _intro_boss_spawned := false
var _low_sat_day := 0
## 压力系统：破产连续天数（连续 3 天没钱 → 抵押最便宜的建筑）。
var _broke_days := 0
## 新手引导：已完成的目标 id（引导链路按 data/tutorial.json 顺序推进）。
var _tutorial_done: Dictionary = {}
## 成就统计（阶段 C）：累计收入 / 清理废墟 / 安装义体次数 + 已解锁成就。
var lifetime_income: int = 0
var ruins_cleared: int = 0
var implants_installed: int = 0
var _ach_done: Dictionary = {}
## 城市扩张系统（阶段 D）：星级定土地上限，玩家花钱征地 → 新格是废墟 → 清完才能盖楼。
var expansions: int = 0
var _announced_pending := Vector2i.ZERO

func _ready() -> void:
	rng.seed = 20770531
	_setup_astar()
	at_menu = true
	speed = 0

## 委托板容量随星级增长：名气越大，找上门的活越多。
## 高星玩家有 8 名居民能同时跑两队，固定 3 条会让他们闲着。
func board_capacity() -> int:
	var cap := 3 + (star - 1)
	if _has_passive_in_town("intel"):
		cap += 1
	return cap

## 是否有某个被动在街区里生效（对应的居民不在城外即可）。
func _has_passive_in_town(pid: String) -> bool:
	for r in residents:
		if r.state != Resident.State.AWAY and r.has_passive(pid):
			return true
	return false

# ---------------------------------------------------------------- 时间

func day() -> int:
	return tick / TICKS_PER_DAY + 1

func period() -> int:
	return (tick % TICKS_PER_DAY) / TICKS_PER_PERIOD

func hour_of_day() -> int:
	return period() * 6

func clock_text() -> String:
	return "%s 第%d天 %02d:00" % [PERIOD_ICONS[period()], day(), hour_of_day()]

func set_speed(s: int) -> void:
	speed = clampi(s, 0, 3)
	EventBus.speed_changed.emit(speed)

func _process(delta: float) -> void:
	if speed <= 0:
		return
	_accum += delta * TPS * float(speed)
	var guard := 0
	while _accum >= 1.0 and guard < 64:
		_accum -= 1.0
		_tick()
		guard += 1

func _tick() -> void:
	tick += 1
	for r in residents:
		r.step(self)
	_tick_missions()
	_tick_boss()
	_tick_research()
	if tick % 15 == 0:
		_refresh_complaints()
		_check_tutorial()
		_check_achievements()
	# 创伤小队：每游戏小时治好伤员。
	if tick % TICKS_PER_HOUR == 0:
		_trauma_tick()
	# 企业办公室：每 2 游戏小时一笔固定收入。
	if tick % (2 * TICKS_PER_HOUR) == 0:
		_office_income()
	if tick % 40 == 0:
		_warn_satisfaction()
	if tick % TICKS_PER_PERIOD == 0:
		EventBus.time_changed.emit(day(), period())
		_on_period()

func _on_period() -> void:
	var p := period()
	if p == 1:
		_tick_implant_durability()
		# 压力系统：不满会搬走 · 破产有后果 · 口碑带来迁入。
		_morning_mood()
		_check_bankruptcy()
		_natural_immigration()
		if gigs_blocked():
			EventBus.notice.emit("数据风暴还没停，今天没有新委托")
		else:
			var before := gig_board.size()
			_fill_gigs(board_capacity())
			if gig_board.size() > before:
				EventBus.notice.emit("早晨，委托板上有新活")
				EventBus.board_changed.emit()
		_roll_event()
		# 来生俱乐部：每天早晨有概率招一名高属性居民。
		if _has_fid("afterlife_club") and rng.randf() < 0.6:
			_recruit_elite()
		# 年度大赏（阶段 12）：每 12 个游戏日结算一次。
		if day() > 1 and day() % YEAR_DAYS == 0:
			_yearly_awards()
		# 周目结算（阶段 12）：第 15 年（180 天）早晨触发一次。
		if day() >= CYCLE_DAYS and not _cycle_done:
			_cycle_done = true
			set_speed(0)
			EventBus.cycle_ready.emit()
		save_slot(true)
		EventBus.notice.emit("已自动存档")
	if p == 3:
		_try_intro_boss()
		# 傍晚额外补一条。板子已满或数据风暴期间不加。
		if not gigs_blocked() and gig_board.size() < board_capacity():
			var before_eve := gig_board.size()
			_fill_gigs(before_eve + 1)
			if gig_board.size() > before_eve:
				EventBus.notice.emit("傍晚，委托板上多了一条活")
				EventBus.board_changed.emit()
	if p == 0 and day() >= 3:
		_try_random_boss()

func next_goal() -> String:
	var req := _next_star_req()
	if req.is_empty():
		return "已是最高星 · 继续经营这条街"
	return "升到 %d 星：%s（%s）" % [int(req["star"]), String(req["text"]), _req_progress(req)]

## 下一级星级的门槛，已满级返回空字典。
func _next_star_req() -> Dictionary:
	for req: Dictionary in STAR_REQS:
		if int(req["star"]) == star + 1:
			return req
	return {}

## 把还差的项拼成进度文本，已达成的项不显示。
func _req_progress(req: Dictionary) -> String:
	var parts := PackedStringArray()
	if gigs_done < int(req.get("gigs", 0)):
		parts.append("成功委托 %d/%d" % [gigs_done, int(req["gigs"])])
	if bosses_killed < int(req.get("bosses", 0)):
		parts.append("讨伐 %d/%d" % [bosses_killed, int(req["bosses"])])
	if rep < int(req.get("rep", 0)):
		parts.append("声望 %d/%d" % [rep, int(req["rep"])])
	if buildings.size() < int(req.get("buildings", 0)):
		parts.append("建筑 %d/%d" % [buildings.size(), int(req["buildings"])])
	if t5_gigs_done < int(req.get("t5", 0)):
		parts.append("T5 委托 %d/%d" % [t5_gigs_done, int(req["t5"])])
	if maxed_building_count() < int(req.get("maxed", 0)):
		parts.append("满级设施 %d/%d" % [maxed_building_count(), int(req["maxed"])])
	if top_mastery_count() < int(req.get("mastery", 0)):
		parts.append("全职业精通 %d/%d" % [top_mastery_count(), int(req["mastery"])])
	if parts.is_empty():
		return "条件已满足"
	return "、".join(parts)

func star_title() -> String:
	return STAR_TITLES[clampi(star, 1, MAX_STAR)]

func event_text() -> String:
	if event_kind == "" or tick >= event_until:
		return ""
	var left_h := ceili(float(event_until - tick) / float(TICKS_PER_HOUR))
	return "%s · 剩 %d 小时" % [event_name, left_h]

func hours_left(ticks_left: int) -> int:
	return maxi(0, ceili(float(ticks_left) / float(TICKS_PER_HOUR)))

# ---------------------------------------------------------------- 建造

func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, MAX_GW, MAX_GH)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

func in_bounds(gx: int, gy: int) -> bool:
	return gx >= 0 and gy >= 0 and gx < unlocked_w and gy < unlocked_h

## 建造实际扣费。公司人被动让企业主题建筑便宜 20%。
func facility_cost(f: Dictionary) -> int:
	var cost := int(f["cost"])
	if String(f.get("theme", "")) == "corporate" and _has_passive_in_town("corp"):
		cost = int(round(float(cost) * 0.8))
	return cost

func can_build(fid: String, gx: int, gy: int) -> bool:
	var f: Dictionary = ConfigDB.get_facility(fid)
	if f.is_empty():
		return false
	if star < building_star_req(fid):
		return false
	# 传奇建筑：全图限 1 座，且对应主题要有大型区域（≥10 栋连通）。
	if _is_legendary(fid):
		if _has_fid(fid):
			return false
		if not _theme_has_large_region(String(f["theme"])):
			return false
	var s := int(f["size"])
	if gx < 0 or gy < 0 or gx + s > unlocked_w or gy + s > unlocked_h:
		return false
	for y in range(gy, gy + s):
		for x in range(gx, gx + s):
			if occupancy.has(Vector2i(x, y)) or ruins.has(Vector2i(x, y)):
				return false
	return money >= facility_cost(f)

func build(fid: String, gx: int, gy: int, rot: int = 0) -> bool:
	if not can_build(fid, gx, gy):
		return false
	var f: Dictionary = ConfigDB.get_facility(fid)
	var s := int(f["size"])
	add_money(-facility_cost(f))
	# 建筑压在道路上时，道路被覆盖移除。
	for y in range(gy, gy + s):
		for x in range(gx, gx + s):
			roads.erase(Vector2i(x, y))
	var bid := _next_bid
	_next_bid += 1
	var sat: Dictionary = f.get("satisfy", {})
	var b := {
		"bid": bid,
		"fid": fid,
		"name": f["name"],
		"theme": f["theme"],
		"tag": f.get("tag", ""),
		"satisfy": sat.duplicate(),
		"base_income": int(f["income"]),
		"cost": int(f["cost"]),
		"level": 1,
		"gx": gx, "gy": gy, "size": s,
		"rot": posmod(rot, 4),
		"visits": 0,
		"damaged": false,
		"disabled_until": 0,
	}
	buildings.append(b)
	for y in range(gy, gy + s):
		for x in range(gx, gx + s):
			occupancy[Vector2i(x, y)] = bid
			astar.set_point_solid(Vector2i(x, y), true)
	_region_dirty = true
	_scan_combos()
	EventBus.building_placed.emit(buildings.size() - 1)
	_recalc_star()   # 4 星起把街区规模算进门槛
	return true

func remove_bid(bid: int, refund: bool = true, leave_ruin: bool = false) -> void:
	var idx := index_of_bid(bid)
	if idx < 0:
		return
	var b: Dictionary = buildings[idx]
	var s := int(b["size"])
	for y in range(int(b["gy"]), int(b["gy"]) + s):
		for x in range(int(b["gx"]), int(b["gx"]) + s):
			occupancy.erase(Vector2i(x, y))
			astar.set_point_solid(Vector2i(x, y), false)
			# Boss 拆楼留下废墟（阶段 9）：不可建不可走，€200/格清理。
			if leave_ruin:
				ruins[Vector2i(x, y)] = true
				astar.set_point_solid(Vector2i(x, y), true)
	buildings.remove_at(idx)
	_reindex_occupancy()
	if refund:
		add_money(int(int(b["cost"]) * 0.5))
	_region_dirty = true
	_combo_of.erase(bid)
	_scan_combos()
	_retarget_boss()
	EventBus.building_removed.emit(idx)

func _rebuild_walk_grid() -> void:
	for y in MAX_GH:
		for x in MAX_GW:
			var c := Vector2i(x, y)
			var solid := not in_bounds(x, y) or ruins.has(c)
			astar.set_point_solid(c, solid)
	_reindex_occupancy()

# ---------------------------------------------------------------- 扩张/废墟/道路（阶段 9）

## 当前星级对应的解锁矩形：开局 20×15，偶数星向东 +4 列、奇数星向北 +4 行。
func _target_unlock() -> Vector2i:
	var w := GW
	var h := GH
	for s in range(2, star + 1):
		if s % 2 == 0:
			w += 4
		else:
			h += 4
	return Vector2i(mini(MAX_GW, w), mini(MAX_GH, h))

## 升星不再自动占地：只提示"可以征地了"，真正占地由玩家花钱扩张（expand_land）。
func _update_unlock_rect() -> void:
	var p := pending_land()
	if p.x <= _announced_pending.x and p.y <= _announced_pending.y:
		return
	_announced_pending = p
	EventBus.notice.emit("声望提升：可征地 %d 列 / %d 行（在「扩张」页花钱征地）" % [p.x, p.y])

func is_ruin(cell: Vector2i) -> bool:
	return ruins.has(cell)

func can_clear_ruin(cell: Vector2i) -> bool:
	return in_bounds(cell.x, cell.y) and ruins.has(cell) and money >= RUIN_CLEAR_COST

func clear_ruin(cell: Vector2i) -> bool:
	if not can_clear_ruin(cell):
		return false
	ruins.erase(cell)
	astar.set_point_solid(cell, false)
	ruins_cleared += 1
	add_money(-RUIN_CLEAR_COST)
	return true

func is_road(cell: Vector2i) -> bool:
	return roads.has(cell)

func can_build_road(cell: Vector2i) -> bool:
	return in_bounds(cell.x, cell.y) and is_walkable(cell) \
		and not roads.has(cell) and money >= ROAD_COST

func build_road(cell: Vector2i) -> bool:
	if not can_build_road(cell):
		return false
	roads[cell] = true
	add_money(-ROAD_COST)
	return true

## 道路移速：正常 ×1.4；酸雨期间取消道路加成并整体 ×0.7。
func road_speed_mult(cell: Vector2i) -> float:
	if String(current_event().get("kind", "")) == "acid":
		return 0.7
	if roads.has(cell):
		return 1.4
	return 1.0

# ---------------------------------------------------------------- 未实装设施的效果（等图即上线）

## 五栋传奇建筑（阶段 3 收尾）：全图各限 1 座，且对应主题要有大型区域（≥10 栋）。
const LEGENDARY_FIDS: Array = [
	"mox_hideout", "trauma_team_hq", "afterlife_club", "arasaka_branch", "netwatch_hub",
]

func _is_legendary(fid: String) -> bool:
	return LEGENDARY_FIDS.has(fid)

## 主题的连通区域是否达到大型（≥10 栋）。
func _theme_has_large_region(theme: String) -> bool:
	for i in buildings.size():
		if String(buildings[i]["theme"]) != theme:
			continue
		if int(region_tier_for(i)["count"]) >= 10:
			return true
	return false

## 走私通道：每栋 +5% 居民移速，封顶 +15%。
func resident_speed_bonus() -> float:
	return minf(0.15, 0.05 * float(count_open_fid("smuggle_tunnel")))

## 莫克斯藏身处：居民四项需求不低于 60。
func need_floor() -> float:
	return 60.0 if _has_fid("mox_hideout") else 0.0

## 企业办公室：每 2 游戏小时一笔固定收入（×等级×区域倍率，不看客流）。
func _office_income() -> void:
	for b in buildings:
		if String(b["fid"]) != "corp_office" or is_hacked(b):
			continue
		var idx := index_of_bid(int(b["bid"]))
		var mult := level_mult(int(b["level"])) * region_mult_for(idx)
		var pay := int(round(float(b["base_income"]) * mult))
		if pay > 0:
			add_money(pay)
			b["income_acc"] = int(b.get("income_acc", 0)) + pay

## 创伤小队总部：每游戏小时治好所有受伤居民。
func _trauma_tick() -> void:
	if not _has_fid("trauma_team_hq"):
		return
	var healed := 0
	for r in residents:
		if r.injured(tick):
			r.injured_until = 0
			healed += 1
	if healed > 0:
		EventBus.notice.emit("创伤小队治好了 %d 名居民" % healed)

## 来生俱乐部：招一名属性更高的居民（+8 全属性）。
func _recruit_elite() -> void:
	if residents.size() >= resident_cap():
		return
	var before := residents.size()
	_spawn_residents(1)
	if residents.size() == before:
		return
	var r = residents[residents.size() - 1]
	for k in r.stats.keys():
		r.stats[k] = mini(100, int(r.stats[k]) + 8)
	EventBus.notice.emit("「%s」在来生俱乐部招来了一名高手" % String(r.rname))

## 武器购买渠道（阶段 4 收尾）：武器店卖 ★★ 及以下、黑市卖 ★★★、军火库卖更高。
## 三店都未实装时回退为纯星级解锁（美术冻结期过渡，保证武器可买）。
func weapon_shop_available(w: Dictionary) -> bool:
	if not (_has_fid("weapon_shop") or _has_fid("black_market") or _has_fid("underground_armory")):
		return true
	var s := int(w["star"])
	if s <= 2:
		return _has_fid("weapon_shop")
	if s == 3:
		return _has_fid("black_market")
	return _has_fid("underground_armory")

## 自检辅助：绕过传奇区域规则直接插入一栋传奇建筑（仅 selftest_buildings 用）。
func _test_legend_building(fid: String, gx: int, gy: int) -> void:
	var f: Dictionary = ConfigDB.get_facility(fid)
	buildings.append({
		"bid": _next_bid, "fid": fid, "name": f["name"], "theme": f["theme"],
		"tag": f.get("tag", ""), "satisfy": {}, "base_income": int(f["income"]),
		"cost": int(f["cost"]), "level": 1, "gx": gx, "gy": gy, "size": int(f["size"]),
		"rot": 0, "visits": 0, "damaged": false, "disabled_until": 0,
	})
	_next_bid += 1
	_reindex_occupancy()
	_region_dirty = true
	_scan_combos()

## 交换（年度大赏与周目结算，阶段 12）

## 年度大赏：收入最高的建筑 + 讨伐贡献最高的居民，各发一笔奖金。
func _yearly_awards() -> void:
	var best_bid := -1
	var best_income := 0
	for b in buildings:
		if int(b.get("income_acc", 0)) > best_income:
			best_income = int(b["income_acc"])
			best_bid = int(b["bid"])
	var best_r = null
	var best_kills := 0
	for r in residents:
		if int(r.boss_acc) > best_kills:
			best_kills = int(r.boss_acc)
			best_r = r
	if best_bid < 0 and best_r == null:
		return
	if best_bid >= 0:
		var nm := String(buildings[index_of_bid(best_bid)]["name"])
		add_money(500)
		add_rep(80)
		EventBus.notice.emit("年度大赏 · 最赚钱的店「%s」 · 奖金 €500 · 声望 +80" % nm)
	if best_r != null:
		_grant_xp(best_r, 50)
		add_rep(80)
		EventBus.notice.emit("年度大赏 · 讨伐之星「%s」 · 经验 +50 · 声望 +80" % String(best_r.rname))
	for b in buildings:
		b["income_acc"] = 0
	for r in residents:
		r.boss_acc = 0

# ---------------------------------------------------------------- 意见气泡（阶段 12）

func _facility_exists_for(need: String) -> bool:
	for b in buildings:
		var sat: Dictionary = b.get("satisfy", {})
		if float(sat.get(need, 0.0)) > 0.0:
			return true
	return false

## 刷新意见气泡：需求最低项 <30 或缺对应设施，最多 4 条。
func _refresh_complaints() -> void:
	_complaints.clear()
	var cands: Array = []
	for r in residents:
		if r.state == Resident.State.AWAY:
			continue
		var worst := "hunger"
		var worst_v := 999.0
		for k in ["hunger", "fun", "health", "cyberware"]:
			if float(r.needs[k]) < worst_v:
				worst_v = float(r.needs[k])
				worst = k
		if worst_v < 30.0:
			cands.append({"rid": int(r.id), "v": worst_v, "text": String(NEED_TEXT[worst])})
		elif not _facility_exists_for(worst):
			cands.append({"rid": int(r.id), "v": worst_v, "text": String(NEED_FAC_TEXT[worst])})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["v"]) < float(b["v"]))
	for i in mini(4, cands.size()):
		_complaints[int(cands[i]["rid"])] = String(cands[i]["text"])

func complaint_text(rid: int) -> String:
	return String(_complaints.get(rid, ""))

# ---------------------------------------------------------------- 周目（阶段 12）

## 开启新周目：保留 2 件物品、1 名居民（属性/等级/精通）与相性图鉴，其余回开局。
func start_new_cycle(keep_items: Array, keep_rid: int) -> bool:
	var kept_r = null
	if keep_rid >= 0:
		var src = resident_by_id(keep_rid)
		if src != null:
			kept_r = {
				"rname": String(src.rname),
				"job_id": String(src.job_id),
				"job_name": String(src.job_name),
				"power_key": String(src.power_key),
				"color": src.color.to_html(false),
				"stats": src.stats.duplicate(),
				"level": int(src.level),
				"mastered": src.mastered.duplicate(),
			}
	var kept_items := {}
	for wid in keep_items:
		if int(warehouse.get(String(wid), 0)) > 0:
			kept_items[String(wid)] = 1
	var kept_combos := combos_found.duplicate()
	_reset_play()
	for wid in kept_items.keys():
		warehouse[String(wid)] = 1
	combos_found = kept_combos
	money = 100000
	_setup_start_town()
	money = 5000
	_spawn_residents(7 if kept_r != null else 8)
	if kept_r != null:
		var r := Resident.new()
		r.id = _next_rid
		_next_rid += 1
		r.rname = String(kept_r["rname"])
		r.job_id = String(kept_r["job_id"])
		r.job_name = String(kept_r["job_name"])
		r.power_key = String(kept_r["power_key"])
		r.color = Color.from_string("#" + String(kept_r["color"]).trim_prefix("#"), Color.WHITE)
		r.stats = kept_r["stats"].duplicate()
		r.level = int(kept_r["level"])
		r.mastered = kept_r["mastered"].duplicate()
		r.cell = random_walkable()
		r.pos = Vector2(r.cell)
		for k in r.needs.keys():
			r.needs[k] = rng.randf_range(55.0, 92.0)
		_refresh_passive_state(r)
		residents.append(r)
		EventBus.notice.emit("%s 带着传奇手艺回到了新周目" % String(r.rname))
	_cycle_done = false
	_fill_gigs(board_capacity())
	_emit_world()
	session_started = true
	save_slot(true)
	EventBus.notice.emit("新周目开启 · 装备与老手保留")
	return true

func _reindex_occupancy() -> void:
	occupancy.clear()
	for b in buildings:
		var ss := int(b["size"])
		for y in range(int(b["gy"]), int(b["gy"]) + ss):
			for x in range(int(b["gx"]), int(b["gx"]) + ss):
				occupancy[Vector2i(x, y)] = int(b["bid"])
				astar.set_point_solid(Vector2i(x, y), true)

func bid_at(cell: Vector2i) -> int:
	return int(occupancy.get(cell, -1))

func index_of_bid(bid: int) -> int:
	if bid < 0:
		return -1
	for i in buildings.size():
		if int(buildings[i]["bid"]) == bid:
			return i
	return -1

func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell.x, cell.y) and not occupancy.has(cell) and not ruins.has(cell)

func is_hacked(b: Dictionary) -> bool:
	return tick < int(b.get("disabled_until", 0))

func nearest_walkable(from: Vector2i) -> Vector2i:
	if is_walkable(from):
		return from
	for radius in range(1, maxi(unlocked_w, unlocked_h)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var c := from + Vector2i(dx, dy)
				if is_walkable(c):
					return c
	return random_walkable()

func random_walkable() -> Vector2i:
	for _i in 60:
		var c := Vector2i(rng.randi_range(1, unlocked_w - 2), rng.randi_range(1, unlocked_h - 2))
		if is_walkable(c):
			return c
	return Vector2i(unlocked_w / 2, unlocked_h / 2)

func upgrade_cost(bid: int) -> int:
	var idx := index_of_bid(bid)
	if idx < 0:
		return -1
	var b: Dictionary = buildings[idx]
	var max_lv := int(ConfigDB.get_facility(String(b["fid"])).get("max_level", 3))
	if int(b["level"]) >= max_lv:
		return -1
	return int(b["cost"]) * int(b["level"])

func upgrade(bid: int) -> bool:
	var cost := upgrade_cost(bid)
	if cost < 0 or money < cost:
		return false
	var b: Dictionary = buildings[index_of_bid(bid)]
	add_money(-cost)
	b["level"] = int(b["level"]) + 1
	EventBus.notice.emit("「%s」升到 Lv%d" % [String(b["name"]), int(b["level"])])
	return true

func repair(bid: int) -> bool:
	var idx := index_of_bid(bid)
	if idx < 0:
		return false
	var b: Dictionary = buildings[idx]
	if not bool(b.get("damaged", false)):
		return false
	if money < REPAIR_COST:
		return false
	add_money(-REPAIR_COST)
	b["damaged"] = false
	EventBus.notice.emit("修好了「%s」" % String(b["name"]))
	return true

# ---------------------------------------------------------------- 区域与相性

func region_tier_for(idx: int) -> Dictionary:
	if _region_dirty:
		_rebuild_regions()
	if idx < 0 or idx >= _region_cache.size():
		return REGION_TIERS[REGION_TIERS.size() - 1]
	return _region_cache[idx]

func region_mult_for(idx: int) -> float:
	return float(region_tier_for(idx)["mult"])

func _rebuild_regions() -> void:
	var n := buildings.size()
	var parent: Array = []
	parent.resize(n)
	for i in n:
		parent[i] = i
	for i in n:
		for j in range(i + 1, n):
			if String(buildings[i]["theme"]) != String(buildings[j]["theme"]):
				continue
			if not _footprints_touch(buildings[i], buildings[j]):
				continue
			var ri := _find(parent, i)
			var rj := _find(parent, j)
			if ri != rj:
				parent[rj] = ri
	var counts := {}
	var groups := {}
	for i in n:
		var root: int = _find(parent, i)
		counts[root] = int(counts.get(root, 0)) + 1
		if not groups.has(root):
			groups[root] = {}
		groups[root][String(buildings[i]["fid"])] = true
	_region_cache.clear()
	_fids_cache.clear()
	for i in n:
		var root: int = _find(parent, i)
		var cnt: int = int(counts[root])
		var tier: Dictionary = REGION_TIERS[REGION_TIERS.size() - 1]
		for t in REGION_TIERS:
			if cnt >= int(t["min"]):
				tier = t
				break
		var entry := tier.duplicate()
		entry["count"] = cnt
		_region_cache.append(entry)
		_fids_cache.append(groups[root])
	_region_dirty = false
	EventBus.region_changed.emit(n)

func _find(parent: Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

func _footprints_touch(a: Dictionary, b: Dictionary) -> bool:
	# 上下左右贴边算连通，只碰一个角不算
	var gx := _axis_gap(int(a["gx"]), int(a["size"]), int(b["gx"]), int(b["size"]))
	var gy := _axis_gap(int(a["gy"]), int(a["size"]), int(b["gy"]), int(b["size"]))
	return (gx == 0 and gy < 0) or (gy == 0 and gx < 0) or (gx < 0 and gy < 0)

func _axis_gap(a0: int, asz: int, b0: int, bsz: int) -> int:
	if a0 + asz <= b0:
		return b0 - (a0 + asz)
	if b0 + bsz <= a0:
		return a0 - (b0 + bsz)
	return -1

func _scan_combos() -> void:
	if _region_dirty:
		_rebuild_regions()
	_combo_of.clear()
	_combo_flags.clear()
	_combo_members.clear()
	# 先算每个组合当前是否贴邻激活（成员足迹连通）。
	for c: Dictionary in ConfigDB.combos:
		var members := _combo_members_for(c)
		if not members.is_empty():
			_combo_flags[String(c["id"])] = true
			_combo_members[String(c["id"])] = members
	for i in buildings.size():
		_combo_of[int(buildings[i]["bid"])] = _calc_combo(i)

## 组合成员是否全部在场，且按足迹贴邻连通（BFS）。
## 同名建筑可能有多栋（如两间面馆），从每个成员各试一次起点，
## 返回第一个覆盖全部所需 fid 的连通分量的成员索引集；无则返回空字典。
func _combo_members_for(combo: Dictionary) -> Dictionary:
	var need: Array = combo.get("fids", [])
	var members: Dictionary = {}
	for i in buildings.size():
		var fid := String(buildings[i]["fid"])
		if need.has(fid):
			if not members.has(fid):
				members[fid] = []
			members[fid].append(i)
	for fid in need:
		if not members.has(fid):
			return {}
	var all_idx: Array = []
	for fid in need:
		for i in members[fid]:
			all_idx.append(int(i))
	for start in all_idx:
		var seen := {}
		var queue: Array = [int(start)]
		seen[int(start)] = true
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for j in all_idx:
				if seen.has(j):
					continue
				if _footprints_touch(buildings[cur], buildings[j]):
					seen[j] = true
					queue.append(j)
		var covered := {}
		for j in seen.keys():
			covered[String(buildings[j]["fid"])] = true
		var all_covered := true
		for fid in need:
			if not covered.has(fid):
				all_covered = false
		if all_covered:
			return seen
	return {}

func _combo_active(combo: Dictionary) -> bool:
	return not _combo_members_for(combo).is_empty()

func _calc_combo(i: int) -> float:
	if i < 0 or i >= buildings.size():
		return 1.0
	var self_fid := String(buildings[i]["fid"])
	var best := 1.0
	for c: Dictionary in ConfigDB.combos:
		var need: Array = c.get("fids", [])
		if not need.has(self_fid):
			continue
		if not _combo_flags.has(String(c["id"])):
			continue
		# 只有连通簇内的成员享受收入加成（同名但不相邻的不算）。
		if not _combo_members.get(String(c["id"]), {}).has(i):
			continue
		_discover(String(c["id"]), String(c["name"]))
		best = maxf(best, float(c.get("income_mult", 1.0)))
	return best

func _discover(id: String, title: String) -> void:
	if combos_found.has(id):
		return
	combos_found[id] = true
	EventBus.notice.emit("发现相性「%s」！这几栋贴在一起的店收入更高" % title)
	# 首次发现的相性出报纸（阶段 12），不打断节奏、只做提示。
	EventBus.news_paper.emit("发现相性「%s」" % title, "已收录进相性辞典")

func combo_mult_for(idx: int) -> float:
	if idx < 0 or idx >= buildings.size():
		return 1.0
	return float(_combo_of.get(int(buildings[idx]["bid"]), 1.0))

# ---------------------------------------------------------------- 区域职业加成（阶段 8）

## 居民站在对应主题区域里，两项属性各 +4（只进战力与检视，不加基础值）。
func region_job_bonus(r, stat: String) -> int:
	var total := 0
	for theme in ConfigDB.theme_jobs.keys():
		var jobs: Dictionary = ConfigDB.theme_jobs[theme]
		var pair: Array = jobs.get(String(r.job_id), [])
		if pair.is_empty() or not pair.has(stat):
			continue
		if _theme_near(String(theme), r.cell, 2):
			total += 4
	return total

## 主题建筑是否在居民 cell 的切比雪夫距离 radius 内。
func _theme_near(theme: String, cell: Vector2i, radius: int) -> bool:
	for b in buildings:
		if String(b["theme"]) != theme:
			continue
		if _cell_near_footprint(cell, b, radius):
			return true
	return false

func _cell_near_footprint(cell: Vector2i, b: Dictionary, radius: int) -> bool:
	var s := int(b["size"])
	var dx := 0
	if cell.x < int(b["gx"]):
		dx = int(b["gx"]) - cell.x
	elif cell.x > int(b["gx"]) + s - 1:
		dx = cell.x - (int(b["gx"]) + s - 1)
	var dy := 0
	if cell.y < int(b["gy"]):
		dy = int(b["gy"]) - cell.y
	elif cell.y > int(b["gy"]) + s - 1:
		dy = cell.y - (int(b["gy"]) + s - 1)
	return maxi(dx, dy) <= radius

## 赛博秋叶原激活时，组合周边居民的娱乐衰减减半（只算连通簇成员）。
func fun_decay_scale(cell: Vector2i) -> float:
	if not _combo_flags.has("akihabara"):
		return 1.0
	for idx in _combo_members.get("akihabara", {}).keys():
		if _cell_near_footprint(cell, buildings[idx], 3):
			return 0.5
	return 1.0

## 法外狂徒激活时武器 -20%。
func weapon_price(wid: String) -> int:
	var w: Dictionary = ConfigDB.weapons.get(wid, {})
	var price := int(w.get("price", 0))
	if _combo_flags.has("outlaw"):
		var c := _combo_by_id("outlaw")
		price = int(round(float(price) * (1.0 - float(c.get("weapon_discount", 0.0)))))
	return price

## 黑客帝国激活时科技类委托耗时倍率。
func tech_gig_time_mult() -> float:
	if _combo_flags.has("matrix"):
		var c := _combo_by_id("matrix")
		return 1.0 - float(c.get("tech_gig_faster", 0.0))
	return 1.0

func _combo_by_id(cid: String) -> Dictionary:
	for c: Dictionary in ConfigDB.combos:
		if String(c["id"]) == cid:
			return c
	return {}

# ---------------------------------------------------------------- 存档

const _Save := preload("res://scripts/core/save_game.gd")

func has_save() -> bool:
	return _Save.exists()

func save_slot(quiet: bool = false) -> bool:
	var ok := _Save.write_state(to_state())
	if not quiet:
		EventBus.notice.emit("已存档" if ok else "存档失败")
	return ok

func load_slot(quiet: bool = false) -> bool:
	var data := _Save.read_state()
	if data.is_empty():
		return false
	from_state(data)
	if not quiet:
		EventBus.notice.emit("读档 · 第%d天" % day())
	return true

func new_game() -> void:
	_reset_play()
	# 开局城镇 24 栋（阶段 10）：临时注资放置，不扣起始 €5000。
	money = 100000
	_setup_start_town()
	money = 5000
	_spawn_residents(8)
	_fill_gigs(board_capacity())
	_emit_world()
	session_started = true
	save_slot(true)
	EventBus.notice.emit("新游戏")

## 按 data/start_town.json 铺开局城镇（占格不重叠，留出走道）。
func _setup_start_town() -> void:
	for e: Dictionary in ConfigDB.start_town:
		build(String(e["fid"]), int(e["gx"]), int(e["gy"]))
	_scan_combos()

func to_state() -> Dictionary:
	var people: Array = []
	for r in residents:
		people.append(_resident_state(r))
	return {
		"v": 1,
		"money": money,
		"rep": rep,
		"star": star,
		"tick": tick,
		"speed": speed,
		"gigs_done": gigs_done,
		"bosses_killed": bosses_killed,
		"event_kind": event_kind,
		"event_name": event_name,
		"event_until": event_until,
		"next_rid": _next_rid,
		"next_bid": _next_bid,
		"next_gig_uid": _next_gig_uid,
		"intro_boss": _intro_boss_spawned,
		"low_sat_day": _low_sat_day,
		"rng_seed": str(rng.seed),
		"rng_state": str(rng.state),
		"combos_found": combos_found.duplicate(),
		"warehouse": warehouse.duplicate(),
		"junk": junk,
		"stims": stims.duplicate(),
		"knowledge": knowledge,
		"research": research.duplicate(true),
		"research_done": research_done.duplicate(),
		"unlocked_w": unlocked_w,
		"unlocked_h": unlocked_h,
		"t5_gigs_done": t5_gigs_done,
		"cycle_done": _cycle_done,
		"broke_days": _broke_days,
		"tutorial": _tutorial_done.duplicate(),
		"lifetime_income": lifetime_income,
		"ruins_cleared": ruins_cleared,
		"implants_installed": implants_installed,
		"achievements": _ach_done.duplicate(),
		"expansions": expansions,
		"boss_kinds": boss_kinds_killed.duplicate(),
		"ruins": ruins.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"roads": roads.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"buildings": buildings.duplicate(true),
		"gig_board": gig_board.duplicate(true),
		"missions": missions.duplicate(true),
		"boss": boss.duplicate(true),
		"residents": people,
	}

func from_state(data: Dictionary) -> void:
	_reset_play()
	money = int(data.get("money", 5000))
	rep = int(data.get("rep", 0))
	star = clampi(int(data.get("star", 1)), 1, MAX_STAR)
	tick = int(data.get("tick", 0))
	speed = clampi(int(data.get("speed", 1)), 0, 3)
	gigs_done = int(data.get("gigs_done", 0))
	bosses_killed = int(data.get("bosses_killed", 0))
	event_kind = String(data.get("event_kind", ""))
	event_name = String(data.get("event_name", ""))
	event_until = int(data.get("event_until", 0))
	_next_rid = int(data.get("next_rid", 0))
	_next_bid = int(data.get("next_bid", 1))
	_next_gig_uid = int(data.get("next_gig_uid", 1))
	_intro_boss_spawned = bool(data.get("intro_boss", false))
	_low_sat_day = int(data.get("low_sat_day", 0))
	combos_found = data.get("combos_found", {}).duplicate()
	var raw_wh: Dictionary = data.get("warehouse", {})
	for wk in raw_wh.keys():
		warehouse[String(wk)] = int(raw_wh[wk])
	junk = int(data.get("junk", 0))
	var raw_st: Dictionary = data.get("stims", {})
	for sk in raw_st.keys():
		stims[String(sk)] = int(raw_st[sk])
	knowledge = int(data.get("knowledge", 0))
	for rk in data.get("research", {}).keys():
		var rr: Dictionary = data["research"][rk]
		var rids: Array = []
		for ridv in rr.get("rids", []):
			rids.append(int(ridv))
		research[String(rk)] = {"left": int(rr.get("left", 0)), "total": int(rr.get("total", 0)), "rids": rids}
	for dn in data.get("research_done", []):
		research_done.append(String(dn))
	unlocked_w = clampi(int(data.get("unlocked_w", GW)), GW, MAX_GW)
	unlocked_h = clampi(int(data.get("unlocked_h", GH)), GH, MAX_GH)
	t5_gigs_done = int(data.get("t5_gigs_done", 0))
	_cycle_done = bool(data.get("cycle_done", false))
	_broke_days = int(data.get("broke_days", 0))
	_tutorial_done.clear()
	for gid in data.get("tutorial", {}).keys():
		_tutorial_done[String(gid)] = true
	lifetime_income = int(data.get("lifetime_income", 0))
	ruins_cleared = int(data.get("ruins_cleared", 0))
	implants_installed = int(data.get("implants_installed", 0))
	_ach_done.clear()
	for aid in data.get("achievements", {}).keys():
		_ach_done[String(aid)] = true
	expansions = int(data.get("expansions", 0))
	_announced_pending = Vector2i.ZERO
	for bk in data.get("boss_kinds", {}).keys():
		boss_kinds_killed[String(bk)] = true
	for raw_c in data.get("ruins", []):
		ruins[Vector2i(int(raw_c[0]), int(raw_c[1]))] = true
	for raw_c in data.get("roads", []):
		roads[Vector2i(int(raw_c[0]), int(raw_c[1]))] = true
	for raw in data.get("buildings", []):
		if raw is Dictionary:
			buildings.append(_coerce_building(raw))
	for raw_g in data.get("gig_board", []):
		if raw_g is Dictionary:
			gig_board.append(raw_g.duplicate(true))
	for raw_m in data.get("missions", []):
		if raw_m is Dictionary:
			missions.append(raw_m.duplicate(true))
	var raw_boss = data.get("boss", {})
	if raw_boss is Dictionary:
		boss = raw_boss.duplicate(true)
	for raw_r in data.get("residents", []):
		if raw_r is Dictionary:
			residents.append(_resident_from(raw_r))
	var seed_text := String(data.get("rng_seed", "20770531"))
	var state_text := String(data.get("rng_state", ""))
	rng.seed = int(seed_text) if seed_text.is_valid_int() else 20770531
	if state_text.is_valid_int():
		rng.state = int(state_text)
	_rebuild_walk_grid()
	_region_dirty = true
	_scan_combos()
	session_started = true
	_emit_world()

func _reset_play() -> void:
	buildings.clear()
	residents.clear()
	gig_board.clear()
	missions.clear()
	boss = {}
	occupancy.clear()
	combos_found.clear()
	_combo_of.clear()
	warehouse.clear()
	junk = 0
	stims.clear()
	knowledge = 0
	research.clear()
	research_done.clear()
	unlocked_w = GW
	unlocked_h = GH
	ruins.clear()
	roads.clear()
	t5_gigs_done = 0
	_cycle_done = false
	_complaints.clear()
	boss_kinds_killed.clear()
	money = 5000
	rep = 0
	star = 1
	tick = 0
	speed = 1
	gigs_done = 0
	bosses_killed = 0
	event_kind = ""
	event_name = ""
	event_until = 0
	_next_rid = 0
	_next_bid = 1
	_next_gig_uid = 1
	_intro_boss_spawned = false
	_low_sat_day = 0
	_broke_days = 0
	_tutorial_done.clear()
	lifetime_income = 0
	ruins_cleared = 0
	implants_installed = 0
	_ach_done.clear()
	expansions = 0
	_announced_pending = Vector2i.ZERO
	_accum = 0.0
	_region_dirty = true
	_rebuild_walk_grid()

func _emit_world() -> void:
	EventBus.money_changed.emit(money)
	EventBus.rep_changed.emit(rep, star)
	EventBus.speed_changed.emit(speed)
	EventBus.board_changed.emit()
	EventBus.boss_changed.emit()
	EventBus.time_changed.emit(day(), period())

func _coerce_building(raw: Dictionary) -> Dictionary:
	var b := raw.duplicate(true)
	b["bid"] = int(b.get("bid", 0))
	b["gx"] = int(b.get("gx", 0))
	b["gy"] = int(b.get("gy", 0))
	b["size"] = int(b.get("size", 2))
	b["rot"] = int(b.get("rot", 0))
	b["level"] = int(b.get("level", 1))
	b["cost"] = int(b.get("cost", 0))
	b["base_income"] = int(b.get("base_income", 0))
	b["visits"] = int(b.get("visits", 0))
	b["disabled_until"] = int(b.get("disabled_until", 0))
	b["damaged"] = bool(b.get("damaged", false))
	return b

func _resident_state(r) -> Dictionary:
	var path_out: Array = []
	for c in r.path:
		path_out.append([int(c.x), int(c.y)])
	return {
		"id": int(r.id),
		"rname": String(r.rname),
		"job_id": String(r.job_id),
		"job_name": String(r.job_name),
		"power_key": String(r.power_key),
		"color": r.color.to_html(false),
		"pos": [r.pos.x, r.pos.y],
		"cell": [int(r.cell.x), int(r.cell.y)],
		"path": path_out,
		"state": int(r.state),
		"timer": int(r.timer),
		"target_bid": int(r.target_bid),
		"needs": r.needs.duplicate(),
		"stats": r.stats.duplicate(),
		"level": int(r.level),
		"xp": int(r.xp),
		"injured_until": int(r.injured_until),
		"reward_mult": float(r.reward_mult),
		"rep_mult": float(r.rep_mult),
		"injury_mult": float(r.injury_mult),
		"mastered": r.mastered.duplicate(),
		"weapon_id": String(r.weapon_id),
		"implants": r.implants.duplicate(true),
		"boss_acc": int(r.boss_acc),
		"unhappy_days": int(r.unhappy_days),
	}

func _resident_from(d: Dictionary):
	var r := Resident.new()
	r.id = int(d.get("id", 0))
	r.rname = String(d.get("rname", "?"))
	r.job_id = String(d.get("job_id", ""))
	r.job_name = String(d.get("job_name", ""))
	r.power_key = String(d.get("power_key", "combat"))
	r.color = Color.from_string("#" + String(d.get("color", "ffffff")).trim_prefix("#"), Color.WHITE)
	var pos: Array = d.get("pos", [0, 0])
	r.pos = Vector2(float(pos[0]), float(pos[1]))
	var cell: Array = d.get("cell", [0, 0])
	r.cell = Vector2i(int(cell[0]), int(cell[1]))
	r.path.clear()
	for step in d.get("path", []):
		r.path.append(Vector2i(int(step[0]), int(step[1])))
	r.state = int(d.get("state", Resident.State.IDLE))
	r.timer = int(d.get("timer", 0))
	r.target_bid = int(d.get("target_bid", -1))
	var needs: Dictionary = d.get("needs", {})
	for k in r.needs.keys():
		r.needs[k] = float(needs.get(k, r.needs[k]))
	var stats: Dictionary = d.get("stats", {})
	for k2 in r.stats.keys():
		r.stats[k2] = int(stats.get(k2, r.stats[k2]))
	r.level = int(d.get("level", 1))
	r.xp = int(d.get("xp", 0))
	r.injured_until = int(d.get("injured_until", 0))
	r.reward_mult = float(d.get("reward_mult", 1.0))
	r.rep_mult = float(d.get("rep_mult", 1.0))
	r.injury_mult = float(d.get("injury_mult", 1.0))
	r.mastered = []
	for mid in d.get("mastered", []):
		r.mastered.append(String(mid))
	r.weapon_id = String(d.get("weapon_id", ""))
	r.implants = {}
	var raw_im: Dictionary = d.get("implants", {})
	for slot in raw_im.keys():
		var rec: Dictionary = raw_im[slot]
		if rec is Dictionary:
			r.implants[String(slot)] = {"id": String(rec.get("id", "")), "dur": int(rec.get("dur", 0))}
	r.boss_acc = int(d.get("boss_acc", 0))
	r.unhappy_days = int(d.get("unhappy_days", 0))
	_refresh_passive_state(r)
	return r

# ---------------------------------------------------------------- 经济

func add_money(v: int) -> void:
	money += v
	if v > 0:
		lifetime_income += v
	EventBus.money_changed.emit(money)

func add_rep(v: int) -> void:
	rep = maxi(0, rep + v)
	EventBus.rep_changed.emit(rep, star)
	# 4 星起把声望也算进门槛，所以涨声望时要重新判定。
	if v > 0:
		_recalc_star()

func period_mult(theme: String, tag: String) -> float:
	match period():
		0:
			return 1.3 if theme == "neon" else 0.7
		1:
			return 1.3 if tag == "food" else 1.0
		2:
			return 1.2 if (tag == "train" or theme == "gang") else 1.0
		3:
			return 1.1
	return 1.0

## 事件收入倍率。themes / tags 为空表示不按该维度过滤；
## 两者都给时需同时命中才受影响。
func event_mult(theme: String, tag: String = "") -> float:
	var e := current_event()
	if e.is_empty():
		return 1.0
	var themes: Array = e.get("themes", [])
	var tags: Array = e.get("tags", [])
	if not themes.is_empty() and not themes.has(theme):
		return 1.0
	if not tags.is_empty() and not tags.has(tag):
		return 1.0
	return float(e.get("mult", 1.0))

func level_mult(level: int) -> float:
	return 1.0 + 0.5 * float(level - 1)

func estimate_income(idx: int) -> int:
	if idx < 0 or idx >= buildings.size():
		return 0
	var b: Dictionary = buildings[idx]
	if is_hacked(b):
		return 0
	var mult := level_mult(int(b["level"]))
	mult *= region_mult_for(idx)
	mult *= period_mult(String(b["theme"]), String(b["tag"]))
	mult *= event_mult(String(b["theme"]), String(b["tag"]))
	mult *= _aura_mult(b)
	mult *= combo_mult_for(idx)
	# 数据花丛：周边 2 格内科技类（tech）建筑收入 +5%。
	if String(b["tag"]) == "tech" and _near_fid(b, "data_flower", 2):
		mult *= 1.05
	# 荒坂分部（传奇）：企业主题收入 ×2。
	if String(b["theme"]) == "corporate" and _has_fid("arasaka_branch"):
		mult *= 2.0
	if bool(b.get("damaged", false)):
		mult *= 0.55
	return int(round(float(b["base_income"]) * mult))

func payout(r, idx: int) -> int:
	var amount := estimate_income(idx)
	# 地下赌场：单次消费收入在 0.3–3 倍之间随机。
	if String(buildings[idx]["fid"]) == "underground_casino" and amount > 0:
		amount = int(round(float(amount) * rng.randf_range(0.3, 3.0)))
	if amount > 0:
		add_money(amount)
	var b: Dictionary = buildings[idx]
	b["visits"] = int(b["visits"]) + 1
	# 年度大赏（阶段 12）：累计本周期收入。
	b["income_acc"] = int(b.get("income_acc", 0)) + amount
	var sat: Dictionary = b.get("satisfy", {})
	var bonus := 6.0 if _near_fid(b, "neon_mushroom", 2) else 0.0
	for k in sat.keys():
		if r.needs.has(k):
			r.needs[k] = minf(100.0, float(r.needs[k]) + Resident.RESTORE * float(sat[k]) + bonus)
	if amount > 0:
		EventBus.payout.emit(Vector2(int(b["gx"]) + int(b["size"]) * 0.5, int(b["gy"]) + int(b["size"]) * 0.5), amount)
	if int(b["visits"]) % 12 == 0:
		add_rep(apply_rep_mult(1, graffiti_rep_mult()))
	return amount

func _aura_mult(b: Dictionary) -> float:
	if String(b["theme"]) == "deco":
		return 1.0
	return 1.05 if _near_fid(b, "biolum_tree", 2) else 1.0

func _near_fid(b: Dictionary, fid: String, radius: int) -> bool:
	for other in buildings:
		if String(other["fid"]) != fid:
			continue
		if _chebyshev(b, other) <= radius:
			return true
	return false

func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	var ax0 := int(a["gx"])
	var ay0 := int(a["gy"])
	var ax1 := ax0 + int(a["size"]) - 1
	var ay1 := ay0 + int(a["size"]) - 1
	var bx0 := int(b["gx"])
	var by0 := int(b["gy"])
	var bx1 := bx0 + int(b["size"]) - 1
	var by1 := by0 + int(b["size"]) - 1
	var dx := 0
	if ax1 < bx0:
		dx = bx0 - ax1
	elif bx1 < ax0:
		dx = ax0 - bx1
	var dy := 0
	if ay1 < by0:
		dy = by0 - ay1
	elif by1 < ay0:
		dy = ay0 - by1
	return maxi(dx, dy)

func _has_fid(fid: String) -> bool:
	for b in buildings:
		if String(b["fid"]) == fid:
			return true
	return false

## 正常营业的某类建筑数量。被黑入或受损的不算。
func count_open_fid(fid: String) -> int:
	var n := 0
	for b in buildings:
		if String(b.get("fid", "")) != fid:
			continue
		if is_hacked(b) or bool(b.get("damaged", false)):
			continue
		n += 1
	return n

## 数据交易所：每栋让委托战力 +5%，最多 +15%。
func intel_power_mult() -> float:
	return 1.0 + minf(0.15, 0.05 * float(count_open_fid("data_broker")))

## 涂鸦墙：每栋让获得的声望 +2%，最多 +10%。
func graffiti_rep_mult() -> float:
	return 1.0 + minf(0.10, 0.02 * float(count_open_fid("graffiti_wall")))

## 正数声望乘倍率。有涂鸦墙时向上取整，一栋墙也能让结算数字变大。
func apply_rep_mult(base: int, mult: float) -> int:
	if base <= 0:
		return int(round(float(base) * mult))
	var scaled := float(base) * mult
	if graffiti_rep_mult() > 1.001:
		return int(ceil(scaled - 0.0001))
	return int(round(scaled))

## 统计带某个 tag 且正常营业的建筑数量。
func count_tag(tag: String) -> int:
	var n := 0
	for b in buildings:
		if String(b.get("tag", "")) != tag:
			continue
		if is_hacked(b) or bool(b.get("damaged", false)):
			continue
		n += 1
	return n

## 住所让居民需求衰减变慢。每栋 -12%，最多减到 55%。
## 对应豪华公寓「居民满意度提升」的设计。
func decay_scale() -> float:
	return maxf(0.55, 1.0 - 0.12 * float(count_tag("rest")))

# ---------------------------------------------------------------- 居民

func _spawn_residents(count: int) -> void:
	# 人数上限（阶段 10）：min(100, 8 + (星级 - 1) × 10)。
	count = mini(count, maxi(0, resident_cap() - residents.size()))
	if count <= 0:
		EventBus.notice.emit("街区人口到上限了，得先升星")
		return
	for i in count:
		var r := Resident.new()
		var seq := _next_rid   # 用全局序号而非局部 i，否则人口涌入会生成同名同职业的重复居民
		r.id = _next_rid
		_next_rid += 1
		r.rname = RESIDENT_NAMES[seq % RESIDENT_NAMES.size()]
		if seq >= RESIDENT_NAMES.size():
			r.rname += "·%d" % (seq / RESIDENT_NAMES.size() + 1)
		var job: Dictionary = ConfigDB.job_list[seq % ConfigDB.job_list.size()]
		r.job_id = String(job["id"])
		r.job_name = String(job["name"])
		r.power_key = String(job["power"])
		r.reward_mult = float(job["reward"])
		r.rep_mult = float(job["rep"])
		r.injury_mult = float(job["injury"])
		var bias: Dictionary = job.get("bias", {})
		for k in r.stats.keys():
			r.stats[k] = clampi(rng.randi_range(14, 24) + int(bias.get(k, 0)), 1, 100)
		r.color = Color.from_string(String(job.get("color", "#ffffff")), Color.WHITE)
		r.color = r.color.lightened(0.08 * float(seq % 3))
		r.mastered = []
		_refresh_passive_state(r)
		r.cell = random_walkable()
		r.pos = Vector2(r.cell)
		for k in r.needs.keys():
			r.needs[k] = rng.randf_range(55.0, 92.0)
		residents.append(r)

func resident_by_id(rid: int):
	for r in residents:
		if int(r.id) == rid:
			return r
	return null

func resident_path(from: Vector2i, to: Vector2i) -> Array:
	if not in_bounds(from.x, from.y) or not is_walkable(to):
		return []
	return astar.get_id_path(from, to)

func approach_cell(idx: int, from: Vector2i) -> Vector2i:
	if idx < 0 or idx >= buildings.size():
		return Vector2i(-1, -1)
	var b: Dictionary = buildings[idx]
	var s := int(b["size"])
	var cands: Array = []
	for y in range(int(b["gy"]), int(b["gy"]) + s):
		cands.append(Vector2i(int(b["gx"]) - 1, y))
		cands.append(Vector2i(int(b["gx"]) + s, y))
	for x in range(int(b["gx"]), int(b["gx"]) + s):
		cands.append(Vector2i(x, int(b["gy"]) - 1))
		cands.append(Vector2i(x, int(b["gy"]) + s))
	var best := Vector2i(-1, -1)
	var best_d := 99999
	for c: Vector2i in cands:
		if not is_walkable(c):
			continue
		var d: int = absi(c.x - from.x) + absi(c.y - from.y)
		if d < best_d:
			best_d = d
			best = c
	return best

func dist_to_building(from: Vector2i, idx: int) -> int:
	var b: Dictionary = buildings[idx]
	var s := int(b["size"])
	var best := 99999
	for y in range(int(b["gy"]), int(b["gy"]) + s):
		for x in range(int(b["gx"]), int(b["gx"]) + s):
			best = mini(best, absi(x - from.x) + absi(y - from.y))
	return best

func battle_power(r, key: String, vs_boss: bool = false) -> int:
	var p: int = r.power(key) + r.weapon_power(key)
	# 主题×职业区域加成（+4/项，只进战力不进基础值）。
	match key:
		"combat":
			p += region_job_bonus(r, "body") + region_job_bonus(r, "reflex")
		"hack":
			p += region_job_bonus(r, "intelligence") + region_job_bonus(r, "tech")
		"social":
			p += region_job_bonus(r, "cool") + region_job_bonus(r, "intelligence")
	# 佣兵：三系战力 +4（被动，不进居民检视的基础值）。
	if r.has_passive("allround"):
		p += 4
	if String(r.power_key) == key or key == "any":
		p = int(round(float(p) * 1.15))
	# 机甲驾驶员：战斗加成。
	if key == "combat" and r.has_passive("mech"):
		p = int(round(float(p) * 1.2))
	# 缉查队员：打赛博精神病时战力 ×1.5（不作用于委托）。
	if vs_boss and r.has_passive("boss_hunter"):
		p = int(round(float(p) * 1.5))
	return p

## 队伍里是否有某个被动生效。
func _team_has_passive(rids: Array, pid: String) -> bool:
	for rid in rids:
		var r = resident_by_id(int(rid))
		if r != null and r.has_passive(pid):
			return true
	return false

func _grant_xp(r, amount: int) -> void:
	r.xp = int(r.xp) + amount
	var guard := 0
	while int(r.xp) >= 30 * int(r.level) and int(r.level) < MAX_RESIDENT_LEVEL and guard < 16:
		r.xp = int(r.xp) - 30 * int(r.level)
		r.level = int(r.level) + 1
		# 基因编辑者：升级时主属性额外 +2。
		var bonus := 2 if r.has_passive("genetic") else 0
		var keys: PackedStringArray = _growth_keys(String(r.power_key))
		for k in keys:
			r.stats[k] = mini(100, int(r.stats[k]) + 4 + bonus)
		if int(r.level) == MASTERY_LEVEL and not r.mastered.has(String(r.job_id)):
			r.mastered.append(String(r.job_id))
			_refresh_passive_state(r)
			EventBus.notice.emit("%s 精通了「%s」职业" % [String(r.rname), String(r.job_name)])
		EventBus.notice.emit("%s 升到 Lv%d" % [String(r.rname), int(r.level)])
		guard += 1

## 被动决定的派生状态（移速倍率等）。职业变更、读档后都要刷一遍。
func _refresh_passive_state(r) -> void:
	r.speed_mult = 2.0 if r.has_passive("nomad") else 1.0

## 转职：Lv10 起可转，花 €1500 和 300 声望；旧职业被动保留。
func can_change_job(rid: int) -> bool:
	var r = resident_by_id(rid)
	return r != null and int(r.level) >= MASTERY_LEVEL \
		and money >= JOB_CHANGE_COST and rep >= JOB_CHANGE_REP

func change_job(rid: int, new_job_id: String) -> bool:
	var r = resident_by_id(rid)
	if r == null or not can_change_job(rid):
		return false
	var job: Dictionary = ConfigDB.jobs.get(new_job_id, {})
	if job.is_empty() or String(job["id"]) == String(r.job_id):
		return false
	if not r.mastered.has(String(r.job_id)):
		r.mastered.append(String(r.job_id))
	add_money(-JOB_CHANGE_COST)
	add_rep(-JOB_CHANGE_REP)
	r.job_id = String(job["id"])
	r.job_name = String(job["name"])
	r.power_key = String(job["power"])
	# 保留旧职业的系数：取对自己更有利的一侧。
	r.reward_mult = maxf(r.reward_mult, float(job["reward"]))
	r.rep_mult = maxf(r.rep_mult, float(job["rep"]))
	r.injury_mult = minf(r.injury_mult, float(job["injury"]))
	r.color = Color.from_string(String(job.get("color", "#ffffff")), r.color)
	_refresh_passive_state(r)
	EventBus.notice.emit("%s 转职成了「%s」· 旧职业被动保留" % [String(r.rname), String(job["name"])])
	EventBus.rep_changed.emit(rep, star)
	return true

# ---------------------------------------------------------------- 武器（阶段 4）

## 武器星级门槛随街区星级解锁；购买进仓库。
func can_buy_weapon(wid: String) -> bool:
	var w: Dictionary = ConfigDB.weapons.get(wid, {})
	if w.is_empty() or star < int(w["star"]):
		return false
	if not weapon_shop_available(w):
		return false
	return money >= weapon_price(wid)

func buy_weapon(wid: String) -> bool:
	if not can_buy_weapon(wid):
		return false
	var w: Dictionary = ConfigDB.weapons[wid]
	add_money(-weapon_price(wid))
	warehouse[wid] = int(warehouse.get(wid, 0)) + 1
	EventBus.notice.emit("购入「%s」，已入库" % String(w["name"]))
	return true

## 装备：仓库 -1；旧武器退回仓库。每人 1 件。
func equip_weapon(rid: int, wid: String) -> bool:
	var r = resident_by_id(rid)
	if r == null or int(warehouse.get(wid, 0)) <= 0:
		return false
	if String(r.weapon_id) != "":
		warehouse[String(r.weapon_id)] = int(warehouse.get(String(r.weapon_id), 0)) + 1
	warehouse[wid] = int(warehouse.get(wid, 0)) - 1
	r.weapon_id = wid
	EventBus.notice.emit("%s 装备了「%s」" % [String(r.rname), String(ConfigDB.weapons[wid]["name"])])
	return true

func unequip_weapon(rid: int) -> bool:
	var r = resident_by_id(rid)
	if r == null or String(r.weapon_id) == "":
		return false
	warehouse[String(r.weapon_id)] = int(warehouse.get(String(r.weapon_id), 0)) + 1
	var nm := String(ConfigDB.weapons[String(r.weapon_id)].get("name", ""))
	r.weapon_id = ""
	EventBus.notice.emit("%s 卸下了「%s」" % [String(r.rname), nm])
	return true

# ---------------------------------------------------------------- 义体（阶段 5）

## 购买渠道：义体改装店（任意稀有度）或二手义体摊（仅 ★★ 及以下）。
func can_buy_implant(wid: String) -> bool:
	var cw: Dictionary = ConfigDB.cyberware.get(wid, {})
	if cw.is_empty() or star < int(cw["star"]):
		return false
	if not _has_fid("cyberware_shop") and not _has_fid("used_cyber_stall"):
		return false
	if not _has_fid("cyberware_shop") and int(cw["rarity"]) > 2:
		return false
	return money >= int(cw["price"])

func buy_implant(wid: String) -> bool:
	if not can_buy_implant(wid):
		return false
	var cw: Dictionary = ConfigDB.cyberware[wid]
	add_money(-int(cw["price"]))
	warehouse[wid] = int(warehouse.get(wid, 0)) + 1
	EventBus.notice.emit("购入义体「%s」，已入库" % String(cw["name"]))
	return true

## 安装：需要义体改装店，同槽位只能装 1 件。
func can_install_implant(rid: int, wid: String) -> bool:
	var r = resident_by_id(rid)
	var cw: Dictionary = ConfigDB.cyberware.get(wid, {})
	if r == null or cw.is_empty():
		return false
	if int(warehouse.get(wid, 0)) <= 0 or not _has_fid("cyberware_shop"):
		return false
	return not r.implants.has(String(cw["slot"]))

func install_implant(rid: int, wid: String) -> bool:
	if not can_install_implant(rid, wid):
		return false
	var r = resident_by_id(rid)
	var cw: Dictionary = ConfigDB.cyberware[wid]
	warehouse[wid] = int(warehouse.get(wid, 0)) - 1
	r.implants[String(cw["slot"])] = {"id": wid, "dur": int(cw["dura"])}
	implants_installed += 1
	EventBus.notice.emit("%s 安装了「%s」（%s）" % [
		String(r.rname), String(cw["name"]), String(cw["slot"])])
	return true

## 维护：地下诊所花 €50/件，把该居民所有义体耐久修满。
func can_repair_implants(rid: int) -> bool:
	var r = resident_by_id(rid)
	if r == null or not _has_fid("underground_clinic"):
		return false
	for slot in r.implants.keys():
		if int(r.implants[slot]["dur"]) < _implant_max_dur(String(r.implants[slot]["id"])):
			return true
	return false

func repair_implants(rid: int) -> bool:
	var r = resident_by_id(rid)
	if r == null or not _has_fid("underground_clinic"):
		return false
	var count := 0
	for slot in r.implants.keys():
		var wid := String(r.implants[slot]["id"])
		var maxd := _implant_max_dur(wid)
		if int(r.implants[slot]["dur"]) < maxd:
			count += 1
			r.implants[slot]["dur"] = maxd
	if count == 0:
		return false
	var cost := IMPLANT_REPAIR_COST * count
	if money < cost:
		# 钱不够则回滚，避免"修了但没扣钱"。
		return false
	add_money(-cost)
	EventBus.notice.emit("诊所维护了 %s 的 %d 件义体 · €%d" % [String(r.rname), count, cost])
	return true

func _implant_max_dur(wid: String) -> int:
	var cw: Dictionary = ConfigDB.cyberware.get(wid, {})
	return int(cw.get("dura", 6))

## 每天早晨义体耐久 -1（0 后加成失效，回诊所维护）。
func _tick_implant_durability() -> void:
	for r in residents:
		for slot in r.implants.keys():
			var rec: Dictionary = r.implants[slot]
			if int(rec["dur"]) > 0:
				rec["dur"] = int(rec["dur"]) - 1
				if int(rec["dur"]) == 0:
					EventBus.notice.emit("%s 的义体「%s」耗尽了，去诊所维护" % [
						String(r.rname), String(ConfigDB.cyberware[String(rec["id"])].get("name", rec["id"]))])

## 讨伐掉落：按当前星级从义体池随机一件进仓库。
func _award_implant_drop() -> void:
	var pool: Array = []
	for cw: Dictionary in ConfigDB.cyberware_list:
		if star >= int(cw["star"]):
			pool.append(cw)
	if pool.is_empty():
		return
	var cw: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var wid := String(cw["id"])
	warehouse[wid] = int(warehouse.get(wid, 0)) + 1
	EventBus.notice.emit("缴获义体「%s」，已入库" % String(cw["name"]))

func _award_junk(n: int) -> void:
	junk += n

## 赠礼：1 个赛博垃圾，抬高该居民四条需求。
func gift(rid: int) -> bool:
	var r = resident_by_id(rid)
	if r == null or junk < 1:
		return false
	junk -= 1
	for k in r.needs.keys():
		r.needs[k] = minf(100.0, float(r.needs[k]) + 25.0)
	EventBus.notice.emit("送了一份赛博垃圾给 %s，街坊心情好了点" % String(r.rname))
	return true

## 强化剂：永久 +1 一项主属性（上限 100）。
func use_stim(rid: int, stat: String) -> bool:
	var r = resident_by_id(rid)
	if r == null or int(stims.get(stat, 0)) <= 0 or int(r.stats[stat]) >= 100:
		return false
	stims[stat] = int(stims.get(stat, 0)) - 1
	r.stats[stat] = int(r.stats[stat]) + 1
	EventBus.notice.emit("%s 注射了强化剂，%s +1" % [String(r.rname), stat])
	return true

## 自动化自检（阶段 2）。命令行：godot --headless --path . -- --selftest
## 断言失败打印 STAGE2 FAIL 并返回；全部通过打印 STAGE2 PASS。
func selftest_stage2() -> void:
	var fails := 0
	if ConfigDB.job_list.size() != 16:
		print("STAGE2 FAIL: job_list=%d (want 16)" % ConfigDB.job_list.size())
		fails += 1
	if residents.is_empty():
		print("STAGE2 FAIL: no residents")
		fails += 1
		return
	var r = residents[0]
	_grant_xp(r, 99999)
	if int(r.level) < MASTERY_LEVEL or int(r.level) > MAX_RESIDENT_LEVEL:
		print("STAGE2 FAIL: level=%d" % int(r.level))
		fails += 1
	if r.mastered.size() != 1 or String(r.mastered[0]) != String(r.job_id):
		print("STAGE2 FAIL: mastered=%s job=%s" % [str(r.mastered), String(r.job_id)])
		fails += 1
	add_rep(500)
	var old_id := String(r.job_id)
	var money_before := money
	var rep_before := rep
	var new_id := "solo" if old_id != "solo" else "merc"
	if not change_job(int(r.id), new_id):
		print("STAGE2 FAIL: change_job refused")
		fails += 1
	if money_before - money != JOB_CHANGE_COST or rep_before - rep != JOB_CHANGE_REP:
		print("STAGE2 FAIL: cost mismatch m=%d r=%d" % [money_before - money, rep_before - rep])
		fails += 1
	if not r.mastered.has(old_id):
		print("STAGE2 FAIL: old passive not kept")
		fails += 1
	var state := to_state()
	from_state(state)
	var r2 = resident_by_id(int(r.id))
	if r2 == null or r2.mastered.size() != r.mastered.size() or r2.level != r.level:
		print("STAGE2 FAIL: save/load roundtrip")
		fails += 1
	if fails == 0:
		print("STAGE2 PASS: jobs=%d level=%d mastered=%s" % [
			ConfigDB.job_list.size(), int(r2.level), str(r2.mastered)])
	else:
		print("STAGE2 FAIL: %d 项失败" % fails)

## 自动化自检（阶段 11）：委托 25 条、id 不重复、五大类都有 1 星入门委托。
func selftest_stage11() -> void:
	var fails := 0
	if ConfigDB.gig_templates.size() != 25:
		print("STAGE11 FAIL: gigs=%d (want 25)" % ConfigDB.gig_templates.size())
		fails += 1
	var seen := {}
	for g in ConfigDB.gig_templates:
		var gid := String(g["id"])
		if seen.has(gid):
			print("STAGE11 FAIL: duplicate id %s" % gid)
			fails += 1
		seen[gid] = true
	for t in ["劫持", "清剿", "提取", "快递", "破坏"]:
		var has_t1 := false
		for g in ConfigDB.gig_templates:
			if String(g["type"]) == t and int(g["star"]) == 1:
				has_t1 = true
		if not has_t1:
			print("STAGE11 FAIL: %s 缺少 1 星入门委托" % t)
			fails += 1
	if fails == 0:
		print("STAGE11 PASS: gigs=%d 五大类 1 星齐全" % ConfigDB.gig_templates.size())
	else:
		print("STAGE11 FAIL: %d 项失败" % fails)

## 自动化自检（阶段 4）：武器购买、装备/卸下、战力加成、存档往返。
func selftest_stage4() -> void:
	var fails := 0
	if ConfigDB.weapon_list.size() != 11:
		print("STAGE4 FAIL: weapons=%d (want 11)" % ConfigDB.weapon_list.size())
		fails += 1
	if not buy_weapon("knife"):
		print("STAGE4 FAIL: buy knife refused")
		fails += 1
	if int(warehouse.get("knife", 0)) != 1:
		print("STAGE4 FAIL: warehouse=%s" % str(warehouse))
		fails += 1
	var r = residents[0]
	var before: int = battle_power(r, "combat")
	if not equip_weapon(int(r.id), "knife"):
		print("STAGE4 FAIL: equip refused")
		fails += 1
	var after: int = battle_power(r, "combat")
	if r.weapon_power("combat") != 5 or after < before + 5:
		print("STAGE4 FAIL: combat power %d -> %d (want >= +5)" % [before, after])
		fails += 1
	if not unequip_weapon(int(r.id)):
		print("STAGE4 FAIL: unequip refused")
		fails += 1
	if int(warehouse.get("knife", 0)) != 1 or String(r.weapon_id) != "":
		print("STAGE4 FAIL: after unequip wh=%s wid=%s" % [str(warehouse), String(r.weapon_id)])
		fails += 1
	equip_weapon(int(r.id), "knife")
	var state := to_state()
	from_state(state)
	var r2 = resident_by_id(int(r.id))
	if r2 == null or String(r2.weapon_id) != "knife" or int(warehouse.get("knife", 0)) != 0:
		print("STAGE4 FAIL: save/load roundtrip")
		fails += 1
	if fails == 0:
		print("STAGE4 PASS: weapons=%d 装备/卸下/存档往返正常" % ConfigDB.weapon_list.size())
	else:
		print("STAGE4 FAIL: %d 项失败" % fails)

## 自动化自检（阶段 5）：义体购买/安装/耐久/维护、垃圾赠礼、强化剂、掉落、存档。
func selftest_stage5() -> void:
	var fails := 0
	if ConfigDB.cyberware_list.size() != 12:
		print("STAGE5 FAIL: cyberware=%d (want 12)" % ConfigDB.cyberware_list.size())
		fails += 1
	star = 5
	add_money(5000)
	if not build("underground_clinic", 18, 0):
		print("STAGE5 FAIL: build clinic")
		fails += 1
	if not build("cyberware_shop", 18, 2):
		print("STAGE5 FAIL: build cyberware_shop")
		fails += 1
	if not buy_implant("kiroshi_mk1"):
		print("STAGE5 FAIL: buy kiroshi_mk1 refused")
		fails += 1
	var r = residents[0]
	var before: int = r.power("combat")
	if not install_implant(int(r.id), "kiroshi_mk1"):
		print("STAGE5 FAIL: install refused")
		fails += 1
	if not r.implants.has("ocular") or r.implant_bonus("reflex") != 5 or r.power("combat") != before + 5:
		print("STAGE5 FAIL: install effect bon=%d combat %d->%d" % [r.implant_bonus("reflex"), before, r.power("combat")])
		fails += 1
	r.implants["ocular"]["dur"] = 1
	if not repair_implants(int(r.id)):
		print("STAGE5 FAIL: repair refused")
		fails += 1
	if int(r.implants["ocular"]["dur"]) != 6:
		print("STAGE5 FAIL: repair dur=%d" % int(r.implants["ocular"]["dur"]))
		fails += 1
	_award_junk(2)
	var hunger_before := float(r.needs["hunger"])
	if not gift(int(r.id)):
		print("STAGE5 FAIL: gift refused")
		fails += 1
	if junk != 1 or float(r.needs["hunger"]) <= hunger_before:
		print("STAGE5 FAIL: gift effect junk=%d" % junk)
		fails += 1
	stims["body"] = 2
	var body_before := int(r.stats["body"])
	if not use_stim(int(r.id), "body"):
		print("STAGE5 FAIL: use_stim refused")
		fails += 1
	if int(r.stats["body"]) != body_before + 1 or int(stims.get("body", 0)) != 1:
		print("STAGE5 FAIL: stim effect")
		fails += 1
	var wh_before := 0
	for k in warehouse.keys():
		wh_before += int(warehouse[k])
	_award_implant_drop()
	var wh_after := 0
	for k in warehouse.keys():
		wh_after += int(warehouse[k])
	if wh_after != wh_before + 1:
		print("STAGE5 FAIL: implant drop")
		fails += 1
	var state := to_state()
	from_state(state)
	var r2 = resident_by_id(int(r.id))
	if r2 == null or not r2.implants.has("ocular") or int(r2.implants["ocular"]["dur"]) != 6 \
		or junk != 1 or int(stims.get("body", 0)) != 1:
		print("STAGE5 FAIL: save/load roundtrip")
		fails += 1
	if fails == 0:
		print("STAGE5 PASS: cyberware=12 安装/维护/赠礼/强化剂/掉落/存档正常")
	else:
		print("STAGE5 FAIL: %d 项失败" % fails)

## 自动化自检（阶段 7）：训练场地门槛、费用、离城、格斗笼加成、结算。
func selftest_stage7() -> void:
	var fails := 0
	var r = residents[0]
	# 开局城镇已有酒吧/黑客巢穴，所以只用「体质/反应」验证无建筑时的拒绝
	#（体/反需要擂台或格斗笼，城镇里都没有）。
	if can_train(int(r.id), "body") or can_train(int(r.id), "reflex"):
		print("STAGE7 FAIL: training allowed without buildings")
		fails += 1
	star = 2
	add_money(2000)
	if not build("fight_cage", 18, 8):
		print("STAGE7 FAIL: build fight_cage")
		fails += 1
	if not can_train(int(r.id), "body"):
		print("STAGE7 FAIL: body training should be allowed with fight_cage")
		fails += 1
	var money_before := money
	var body_before := int(r.stats["body"])
	if not train_stat(int(r.id), "body"):
		print("STAGE7 FAIL: train_stat refused")
		fails += 1
	if money_before - money != TRAIN_COST or r.state != Resident.State.AWAY:
		print("STAGE7 FAIL: cost/away state")
		fails += 1
	if can_train(int(r.id), "reflex"):
		print("STAGE7 FAIL: training while already training")
		fails += 1
	for m in missions:
		if String(m["kind"]) == "train":
			m["left"] = 1
	_tick_missions()
	var expect_body: int = mini(100, body_before + 3)
	if int(r.stats["body"]) != expect_body or r.state != Resident.State.IDLE:
		print("STAGE7 FAIL: gain/state body %d->%d state=%d (want %d)" % [body_before, int(r.stats["body"]), r.state, expect_body])
		fails += 1
	var state := to_state()
	from_state(state)
	var r2 = resident_by_id(int(r.id))
	if r2 == null or int(r2.stats["body"]) != expect_body:
		print("STAGE7 FAIL: save/load roundtrip")
		fails += 1
	if fails == 0:
		print("STAGE7 PASS: 场地门槛/费用/离城/格斗笼+3/结算/存档正常")
	else:
		print("STAGE7 FAIL: %d 项失败" % fails)

## 自动化自检（阶段 8）：相性数据驱动/贴邻激活/发现/收入倍率、区域职业加成、全局效果、存档。
func selftest_stage8() -> void:
	var fails := 0
	if ConfigDB.combos.size() != 5:
		print("STAGE8 FAIL: combos=%d (want 5)" % ConfigDB.combos.size())
		fails += 1
	star = 3
	add_money(10000)
	# 赛博秋叶原：面馆(10,12) + 二手义体摊(12,12) + 全息影院(14,12) 贴邻成链。
	if not build("neon_noodle", 10, 12) or not build("used_cyber_stall", 12, 12) or not build("holo_theater", 14, 12):
		print("STAGE8 FAIL: build akihabara")
		fails += 1
	# 黑客帝国：黑客巢穴(2,12) + 数据交易所(4,12) + 秘密服务器(0,12，阶段 6 已建)。
	if not build("netrunner_den", 2, 12) or not build("data_broker", 4, 12):
		print("STAGE8 FAIL: build matrix")
		fails += 1
	_scan_combos()
	if not _combo_flags.has("akihabara") or not combos_found.has("akihabara"):
		print("STAGE8 FAIL: akihabara not active/discovered")
		fails += 1
	if not _combo_flags.has("matrix"):
		print("STAGE8 FAIL: matrix not active")
		fails += 1
	var noodle_idx := -1
	for i in buildings.size():
		if String(buildings[i]["fid"]) == "neon_noodle" and _combo_members.get("akihabara", {}).has(i):
			noodle_idx = i
	if noodle_idx < 0 or absf(combo_mult_for(noodle_idx) - 2.5) > 0.001:
		print("STAGE8 FAIL: noodle mult=%.2f" % combo_mult_for(noodle_idx))
		fails += 1
	if absf(tech_gig_time_mult() - 0.7) > 0.001:
		print("STAGE8 FAIL: matrix time mult=%.2f" % tech_gig_time_mult())
		fails += 1
	if absf(fun_decay_scale(Vector2i(13, 11)) - 0.5) > 0.001 or absf(fun_decay_scale(Vector2i(0, 0)) - 1.0) > 0.001:
		print("STAGE8 FAIL: akihabara fun decay scale")
		fails += 1
	# 区域职业加成：netrunner 站到地下主题建筑旁，tech/intelligence 各 +4（战力 +8）。
	var rnr = residents[2]
	rnr.cell = Vector2i(12, 9)
	var far_power: int = battle_power(rnr, "hack")
	rnr.cell = Vector2i(2, 11)
	var near_power: int = battle_power(rnr, "hack")
	if region_job_bonus(rnr, "tech") != 4 or region_job_bonus(rnr, "intelligence") != 4 or near_power - far_power < 8:
		print("STAGE8 FAIL: region job bonus %d -> %d" % [far_power, near_power])
		fails += 1
	var state := to_state()
	from_state(state)
	if not combos_found.has("akihabara") or not _combo_flags.has("akihabara") or not _combo_flags.has("matrix"):
		print("STAGE8 FAIL: save/load roundtrip")
		fails += 1
	if fails == 0:
		print("STAGE8 PASS: 相性读表/贴邻激活/发现/倍率 + 区域职业加成/全局效果/存档正常")
	else:
		print("STAGE8 FAIL: %d 项失败" % fails)

## 自动化自检（阶段 9）：解锁矩形/扩张废墟/清理/道路与酸雨/拆楼成废墟/存档。
func selftest_stage9() -> void:
	var fails := 0
	if unlocked_w != 20 or unlocked_h != 15:
		print("STAGE9 FAIL: start unlock %dx%d" % [unlocked_w, unlocked_h])
		fails += 1
	if not in_bounds(19, 14) or in_bounds(20, 0) or in_bounds(0, 15):
		print("STAGE9 FAIL: bounds")
		fails += 1
	star = 2
	_update_unlock_rect()
	# 阶段 D 起：升星只提高土地上限，实际占地要花钱征地（expand_land）。
	if unlocked_w != 20 or pending_land().x != 4:
		print("STAGE9 FAIL: 上限/待征 w=%d pending=%d" % [unlocked_w, pending_land().x])
		fails += 1
	add_money(5000)
	if not expand_land("x") or unlocked_w != 22:
		print("STAGE9 FAIL: 首次征地 w=%d" % unlocked_w)
		fails += 1
	if not expand_land("x") or unlocked_w != 24:
		print("STAGE9 FAIL: 二次征地 w=%d" % unlocked_w)
		fails += 1
	if not ruins.has(Vector2i(20, 0)) or is_walkable(Vector2i(20, 0)):
		print("STAGE9 FAIL: 新地块应为废墟")
		fails += 1
	if not clear_ruin(Vector2i(20, 0)) or ruins.has(Vector2i(20, 0)) or not is_walkable(Vector2i(20, 0)):
		print("STAGE9 FAIL: clear ruin")
		fails += 1
	if not build_road(Vector2i(0, 3)) or not roads.has(Vector2i(0, 3)):
		print("STAGE9 FAIL: build road")
		fails += 1
	if absf(road_speed_mult(Vector2i(0, 3)) - 1.4) > 0.001 or absf(road_speed_mult(Vector2i(9, 9)) - 1.0) > 0.001:
		print("STAGE9 FAIL: road speed")
		fails += 1
	# 酸雨：道路加成失效并整体降速。
	event_kind = "acid"
	event_until = tick + 100
	if absf(road_speed_mult(Vector2i(0, 3)) - 0.7) > 0.001:
		print("STAGE9 FAIL: acid road speed")
		fails += 1
	event_kind = ""
	event_until = 0
	# 拆楼成废墟。
	if not build("neon_noodle", 18, 10):
		print("STAGE9 FAIL: build for ruin test")
		fails += 1
	var bid := bid_at(Vector2i(18, 10))
	remove_bid(bid, false, true)
	if not ruins.has(Vector2i(18, 10)) or is_walkable(Vector2i(18, 10)) or can_build("neon_noodle", 18, 10):
		print("STAGE9 FAIL: boss ruin")
		fails += 1
	# 道路被建筑覆盖移除。
	if not build_road(Vector2i(16, 12)):
		print("STAGE9 FAIL: road prebuild")
		fails += 1
	if not build("neon_bar", 16, 12) or roads.has(Vector2i(16, 12)):
		print("STAGE9 FAIL: road under building")
		fails += 1
	var state := to_state()
	from_state(state)
	if unlocked_w != 24 or not ruins.has(Vector2i(18, 10)) or not roads.has(Vector2i(0, 3)) or roads.has(Vector2i(16, 12)):
		print("STAGE9 FAIL: save/load roundtrip")
		fails += 1
	if fails == 0:
		print("STAGE9 PASS: 解锁矩形/扩张/废墟清理/道路与酸雨/拆楼废墟/存档正常")
	else:
		print("STAGE9 FAIL: %d 项失败" % fails)

## 自动化自检（阶段 10）：星级 6-10 门槛/人数上限/开局城镇/满级与精通/存档。
func selftest_stage10() -> void:
	var fails := 0
	if STAR_REQS.size() != 9 or MAX_STAR != 10 or STAR_TITLES.size() != 11:
		print("STAGE10 FAIL: star table size")
		fails += 1
	star = 1
	if resident_cap() != 8:
		print("STAGE10 FAIL: cap star1=%d" % resident_cap())
		fails += 1
	star = 2
	if resident_cap() != 18:
		print("STAGE10 FAIL: cap star2=%d" % resident_cap())
		fails += 1
	star = 10
	if resident_cap() != 98:
		print("STAGE10 FAIL: cap star10=%d" % resident_cap())
		fails += 1
	star = 1
	var pop_before := residents.size()
	_spawn_residents(5)
	if residents.size() != pop_before:
		print("STAGE10 FAIL: spawn over cap")
		fails += 1
	new_game()
	if buildings.size() != 0 or money != 5000 or residents.size() != 8:
		print("STAGE10 FAIL: empty start b=%d money=%d pop=%d" % [buildings.size(), money, residents.size()])
		fails += 1
	# 满级设施：盖一栋面馆并升到满级。
	if not build("neon_noodle", 2, 2):
		print("STAGE10 FAIL: build noodle")
		fails += 1
	var bid0 := bid_at(Vector2i(2, 2))
	if not upgrade(bid0) or not upgrade(bid0):
		print("STAGE10 FAIL: upgrade to max")
		fails += 1
	if maxed_building_count() < 1:
		print("STAGE10 FAIL: maxed count")
		fails += 1
	# 全职业精通：直接给 0 号居民塞 16 个精通。
	var r = residents[0]
	r.mastered = []
	for j: Dictionary in ConfigDB.job_list:
		r.mastered.append(String(j["id"]))
	if top_mastery_count() != 16:
		print("STAGE10 FAIL: top mastery=%d" % top_mastery_count())
		fails += 1
	# 新门槛字段的判定。
	if not _meets_req({"star": 10, "gigs": 0, "bosses": 0, "rep": 0, "buildings": 0, "mastery": 16}):
		print("STAGE10 FAIL: _meets_req mastery")
		fails += 1
	if _meets_req({"star": 10, "gigs": 0, "bosses": 0, "rep": 0, "buildings": 0, "mastery": 17}):
		print("STAGE10 FAIL: _meets_req over-mastery")
		fails += 1
	# t5 与存档。
	t5_gigs_done = 3
	var state := to_state()
	from_state(state)
	if t5_gigs_done != 3:
		print("STAGE10 FAIL: t5 save/load")
		fails += 1
	if fails == 0:
		print("STAGE10 PASS: 星级6-10/人数上限/开局城镇/满级精通/存档正常")
	else:
		print("STAGE10 FAIL: %d 项失败" % fails)

## 自动化自检（阶段 12）：意见气泡/年度大赏/周目保留/存档。
func selftest_stage12() -> void:
	var fails := 0
	# 意见气泡：需求低 → 短句。
	var r0 = residents[0]
	r0.needs["hunger"] = 10.0
	_refresh_complaints()
	if String(_complaints.get(int(r0.id), "")) != "饿坏了":
		print("STAGE12 FAIL: complaint text=%s" % String(_complaints.get(int(r0.id), "")))
		fails += 1
	r0.needs["hunger"] = 80.0
	# 年度大赏。
	new_game()
	if not build("neon_noodle", 2, 2):
		print("STAGE12 FAIL: build noodle for awards")
		fails += 1
	var idx0 := index_of_bid(bid_at(Vector2i(2, 2)))
	buildings[idx0]["income_acc"] = 999
	residents[0].boss_acc = 3
	var m0 := money
	var rep0 := rep
	_yearly_awards()
	if money != m0 + 500 or rep != rep0 + 160 or int(buildings[idx0].get("income_acc", 0)) != 0 or int(residents[0].boss_acc) != 0:
		print("STAGE12 FAIL: yearly awards")
		fails += 1
	# 周目：保留 2 件物品 + 1 名居民（属性/等级/精通）。
	var keep_name := String(residents[1].rname)
	residents[1].level = 12
	residents[1].stats["body"] = 66
	residents[1].mastered = ["solo", "fixer"]
	warehouse["knife"] = 3
	warehouse["smg_mk1"] = 2
	if not start_new_cycle(["knife", "smg_mk1"], int(residents[1].id)):
		print("STAGE12 FAIL: cycle refused")
		fails += 1
	if money != 5000 or star != 1 or buildings.size() != 0 or residents.size() != 8:
		print("STAGE12 FAIL: cycle reset")
		fails += 1
	if int(warehouse.get("knife", 0)) != 1 or int(warehouse.get("smg_mk1", 0)) != 1:
		print("STAGE12 FAIL: cycle items")
		fails += 1
	var kept = null
	for r in residents:
		if String(r.rname) == keep_name:
			kept = r
	if kept == null or int(kept.level) != 12 or int(kept.stats["body"]) != 66 or kept.mastered.size() != 2:
		print("STAGE12 FAIL: cycle resident")
		fails += 1
	var state := to_state()
	from_state(state)
	if int(warehouse.get("knife", 0)) != 1 or buildings.size() != 0:
		print("STAGE12 FAIL: cycle save/load")
		fails += 1
	if fails == 0:
		print("STAGE12 PASS: 意见气泡/年度大赏/周目保留/存档正常")
	else:
		print("STAGE12 FAIL: %d 项失败" % fails)

## 自动化自检（建筑效果收尾）：12 栋未实装设施的效果 + 武器店三档门槛。
func selftest_buildings() -> void:
	var fails := 0
	# 把 12 栋临时标成实装（仅测试进程内），否则 can_build 锁 99 星。
	var ids12 := ["smuggle_tunnel", "weapon_shop", "black_market", "underground_armory",
		"corp_office", "underground_casino", "data_flower", "mox_hideout",
		"trauma_team_hq", "afterlife_club", "arasaka_branch", "netwatch_hub"]
	for fid in ids12:
		ConfigDB.facilities[fid]["implemented"] = true
	new_game()
	star = 8
	add_money(100000)
	# 武器店回退：三店都没建 → 纯星级解锁。
	if not can_buy_weapon("knife"):
		print("BUILDINGS FAIL: weapon fallback")
		fails += 1
	# 街头主题大型区域（10 栋涂鸦墙连成一块），供传奇建筑解锁。
	var graffiti_pos := [Vector2i(0, 8), Vector2i(2, 8), Vector2i(4, 8), Vector2i(6, 8), Vector2i(8, 8),
		Vector2i(0, 10), Vector2i(2, 10), Vector2i(4, 10), Vector2i(6, 10), Vector2i(8, 10)]
	for p in graffiti_pos:
		if not build("graffiti_wall", p.x, p.y):
			print("BUILDINGS FAIL: graffiti region")
			fails += 1
	# 传奇：企业主题还没有大型区域 → 荒坂点不下去。
	if can_build("arasaka_branch", 14, 8):
		print("BUILDINGS FAIL: legendary without large region")
		fails += 1
	# 走私通道：移速 +5%。
	if not build("smuggle_tunnel", 2, 2):
		print("BUILDINGS FAIL: tunnel build")
		fails += 1
	if absf(resident_speed_bonus() - 0.05) > 0.001:
		print("BUILDINGS FAIL: tunnel speed=%.2f" % resident_speed_bonus())
		fails += 1
	# 企业办公室：固定收入。
	if not build("corp_office", 4, 2):
		print("BUILDINGS FAIL: office build")
		fails += 1
	var m_before := money
	_office_income()
	if money <= m_before:
		print("BUILDINGS FAIL: office income")
		fails += 1
	# 数据花丛：科技建筑 +5%。
	if not build("netrunner_den", 6, 2):
		print("BUILDINGS FAIL: netrunner build")
		fails += 1
	var ni := index_of_bid(bid_at(Vector2i(6, 2)))
	var est_before := estimate_income(ni)
	if not build("data_flower", 8, 3):
		print("BUILDINGS FAIL: flower build")
		fails += 1
	var est_after := estimate_income(ni)
	if absf(float(est_after) - float(est_before) * 1.05) > 1.0:
		print("BUILDINGS FAIL: flower %d -> %d" % [est_before, est_after])
		fails += 1
	# 地下赌场：0.3–3 倍随机。
	if not build("underground_casino", 10, 2):
		print("BUILDINGS FAIL: casino build")
		fails += 1
	var ci := index_of_bid(bid_at(Vector2i(10, 2)))
	var est_c := estimate_income(ci)
	var got := payout(residents[0], ci)
	if got < est_c * 0.3 - 1 or got > est_c * 3.0 + 1:
		print("BUILDINGS FAIL: casino pay=%d est=%d" % [got, est_c])
		fails += 1
	# 莫克斯：街头大型区域已有 → 可建；需求下限 60；全图限 1 座。
	if not build("mox_hideout", 12, 8):
		print("BUILDINGS FAIL: mox build")
		fails += 1
	if can_build("mox_hideout", 14, 8):
		print("BUILDINGS FAIL: legendary limit")
		fails += 1
	var r0 = residents[0]
	r0.needs["hunger"] = 50.0
	r0._decay(self)
	if float(r0.needs["hunger"]) < 60.0:
		print("BUILDINGS FAIL: mox floor")
		fails += 1
	# 创伤小队：每小时治伤。
	_test_legend_building("trauma_team_hq", 16, 8)
	r0.injured_until = tick + 999
	_trauma_tick()
	if r0.injured(tick):
		print("BUILDINGS FAIL: trauma heal")
		fails += 1
	# 来生：招高手。
	var pop_before := residents.size()
	_recruit_elite()
	if residents.size() != pop_before + 1:
		print("BUILDINGS FAIL: afterlife recruit")
		fails += 1
	# 荒坂：企业收入 ×2。
	var oi := index_of_bid(bid_at(Vector2i(4, 2)))
	var corp_before := estimate_income(oi)
	_test_legend_building("arasaka_branch", 18, 8)
	var corp_after := estimate_income(oi)
	if corp_after < corp_before * 2 - 1:
		print("BUILDINGS FAIL: arasaka x2 %d -> %d" % [corp_before, corp_after])
		fails += 1
	# 网监：Boss 首次动手推迟 4 小时。
	_test_legend_building("netwatch_hub", 18, 10)
	_spawn_boss({"id": "berserk", "name": "狂战士", "kind": "smash", "power": 300, "pay": 1000, "rep": 40})
	if int(boss.get("attack_in", 0)) != BOSS_GRACE_HOURS * TICKS_PER_HOUR + 4 * TICKS_PER_HOUR:
		print("BUILDINGS FAIL: netwatch delay=%d" % int(boss.get("attack_in", 0)))
		fails += 1
	boss = {}
	# 武器店三档门槛。
	if not build("weapon_shop", 14, 2):
		print("BUILDINGS FAIL: weapon_shop build")
		fails += 1
	if not can_buy_weapon("knife") or can_buy_weapon("combat_shotgun"):
		print("BUILDINGS FAIL: shop tier 1")
		fails += 1
	if not build("black_market", 16, 2):
		print("BUILDINGS FAIL: black_market build")
		fails += 1
	if not can_buy_weapon("combat_shotgun") or can_buy_weapon("smart_rifle"):
		print("BUILDINGS FAIL: shop tier 2")
		fails += 1
	if not build("underground_armory", 18, 2):
		print("BUILDINGS FAIL: armory build")
		fails += 1
	if not can_buy_weapon("smart_rifle"):
		print("BUILDINGS FAIL: shop tier 3")
		fails += 1
	if fails == 0:
		print("BUILDINGS PASS: 12 栋效果 + 武器店三档门槛正常")
	else:
		print("BUILDINGS FAIL: %d 项失败" % fails)

## 自动化自检（压力与后果）：不满搬走 / 破产抵押 / 口碑迁入 / 存档。
func selftest_adverse() -> void:
	var fails := 0
	# 1) 长期不满 → 搬走（只让 0 号居民不满，其余保持满意）。
	new_game()
	tick = 6 * TICKS_PER_DAY
	for i in residents.size():
		var rr = residents[i]
		for k in rr.needs.keys():
			rr.needs[k] = 10.0 if i == 0 else 90.0
	var rid0 := int(residents[0].id)
	var pop0 := residents.size()
	_morning_mood()
	if residents.size() != pop0:
		print("STAGE_A FAIL: 第 1 天不应有人走 (pop=%d)" % residents.size())
		fails += 1
	var target = resident_by_id(rid0)
	if target == null or int(target.unhappy_days) != 1:
		print("STAGE_A FAIL: 不满计数 = %s" % ("null" if target == null else str(int(target.unhappy_days))))
		fails += 1
	_morning_mood()
	_morning_mood()
	if resident_by_id(rid0) != null or residents.size() != pop0 - 1:
		print("STAGE_A FAIL: 满 3 天应搬走 (pop=%d)" % residents.size())
		fails += 1
	# 满意度回升要清零计数。
	var r1 = residents[0]
	for k in r1.needs.keys():
		r1.needs[k] = 95.0
	_morning_mood()
	if int(r1.unhappy_days) != 0:
		print("STAGE_A FAIL: 满意后计数未清零")
		fails += 1
	# 2) 破产：第 1 天扣声望，第 3 天抵押最便宜的建筑。
	new_game()
	if not build("neon_noodle", 2, 2):
		print("STAGE_A FAIL: 建面馆失败")
		fails += 1
	rep = 500
	money = 0
	var b_before := buildings.size()
	_check_bankruptcy()
	if rep != 500 - BROKE_REP_PENALTY or buildings.size() != b_before or _broke_days != 1:
		print("STAGE_A FAIL: 破产第 1 天 rep=%d b=%d" % [rep, buildings.size()])
		fails += 1
	_check_bankruptcy()
	_check_bankruptcy()
	if buildings.size() != b_before - 1 or money <= 0 or _broke_days != 0:
		print("STAGE_A FAIL: 抵押未生效 b=%d money=%d" % [buildings.size(), money])
		fails += 1
	# 3) 口碑迁入：满意度 ≥60 且声望足够，每 4 天来人。
	# 注意 day() = tick / TICKS_PER_DAY + 1，所以第 4 天对应 tick = 3 × 480。
	new_game()
	star = 3
	rep = 1000
	for rr in residents:
		for k in rr.needs.keys():
			rr.needs[k] = 95.0
	tick = 3 * TICKS_PER_DAY
	if day() % IMMIGRATION_DAYS != 0:
		print("STAGE_A FAIL: 测试日设置错误 day=%d" % day())
		fails += 1
	var pop_before := residents.size()
	_natural_immigration()
	if residents.size() != pop_before + 1:
		print("STAGE_A FAIL: 迁入 pop=%d day=%d" % [residents.size(), day()])
		fails += 1
	# 满意度太低就不来人。
	new_game()
	star = 3
	rep = 1000
	for rr in residents:
		for k in rr.needs.keys():
			rr.needs[k] = 20.0
	tick = 3 * TICKS_PER_DAY
	var pop_low := residents.size()
	_natural_immigration()
	if residents.size() != pop_low:
		print("STAGE_A FAIL: 低满意不该迁入")
		fails += 1
	# 4) 存档往返：不满天数与破产天数。
	residents[0].unhappy_days = 2
	_broke_days = 1
	var state := to_state()
	from_state(state)
	if int(residents[0].unhappy_days) != 2 or _broke_days != 1:
		print("STAGE_A FAIL: 存档往返 unhappy=%d broke=%d" % [int(residents[0].unhappy_days), _broke_days])
		fails += 1
	if fails == 0:
		print("STAGE_A PASS: 不满搬走/清零/破产抵押/口碑迁入/存档正常")
	else:
		print("STAGE_A FAIL: %d 项失败" % fails)

## 自动化自检（新手引导）：目标链顺序推进 / 连锁完成 / 存档。
func selftest_tutorial() -> void:
	var fails := 0
	new_game()
	if ConfigDB.tutorial_steps.size() < 5:
		print("STAGE_B FAIL: 目标表只有 %d 条" % ConfigDB.tutorial_steps.size())
		fails += 1
	var first: Dictionary = current_goal()
	if String(first.get("id", "")) != "build1":
		print("STAGE_B FAIL: 首个目标 = %s" % String(first.get("id", "")))
		fails += 1
	# 建 1 栋 → 第一个目标完成，指向下一个。
	if not build("neon_noodle", 2, 2):
		print("STAGE_B FAIL: 建造失败")
		fails += 1
	_check_tutorial()
	if not _tutorial_done.has("build1"):
		print("STAGE_B FAIL: build1 未完成")
		fails += 1
	if String(current_goal().get("id", "")) == "build1":
		print("STAGE_B FAIL: 目标未推进")
		fails += 1
	# 消费一次 → earn 完成。
	var bi := index_of_bid(bid_at(Vector2i(2, 2)))
	payout(residents[0], bi)
	_check_tutorial()
	if not _tutorial_done.has("earn"):
		print("STAGE_B FAIL: earn 未完成")
		fails += 1
	# 一口气建到 3 栋 → build3 完成（连锁检查）。
	build("neon_bar", 4, 2)
	build("neon_bar", 6, 2)
	_check_tutorial()
	if not _tutorial_done.has("build3"):
		print("STAGE_B FAIL: build3 未完成")
		fails += 1
	# 相性：面馆 + 酒吧贴邻已激活 → combo 完成。
	_check_tutorial()
	if not _tutorial_done.has("combo"):
		print("STAGE_B FAIL: combo 未完成（相性=%d）" % combos_found.size())
		fails += 1
	# 进度统计与存档往返。
	var prog := goal_progress()
	if prog.x != _tutorial_done.size() or prog.y != ConfigDB.tutorial_steps.size():
		print("STAGE_B FAIL: 进度 %s" % str(prog))
		fails += 1
	var state := to_state()
	var done_n := _tutorial_done.size()
	from_state(state)
	if _tutorial_done.size() != done_n or not _tutorial_done.has("combo"):
		print("STAGE_B FAIL: 存档往返 done=%d" % _tutorial_done.size())
		fails += 1
	if fails == 0:
		print("STAGE_B PASS: 目标链顺序推进/连锁/进度/存档正常（%d 步）" % ConfigDB.tutorial_steps.size())
	else:
		print("STAGE_B FAIL: %d 项失败" % fails)

## 自动化自检（成就与统计）：解锁判定/奖励发放/进度/存档。
func selftest_achievements() -> void:
	var fails := 0
	new_game()
	if ConfigDB.achievements.size() < 10:
		print("STAGE_C FAIL: 成就表只有 %d 条" % ConfigDB.achievements.size())
		fails += 1
	# 累计收入成就：给钱 → 检查解锁 + 奖励到账。
	var a_first := _find_ach("first_money")
	if a_first.is_empty():
		print("STAGE_C FAIL: 找不到 first_money")
		fails += 1
	else:
		var need := int(a_first["n"])
		lifetime_income = need
		var m0 := money
		var rep0 := rep
		_check_achievements()
		if not achievement_unlocked("first_money"):
			print("STAGE_C FAIL: 累计收入成就未解锁")
			fails += 1
		if money != m0 + int(a_first["money"]) or rep != rep0 + int(a_first["rep"]):
			print("STAGE_C FAIL: 成就奖励未发放 money=%d rep=%d" % [money, rep])
			fails += 1
	# 建筑成就与进度显示。
	if not build("neon_noodle", 2, 2):
		print("STAGE_C FAIL: 建造失败")
		fails += 1
	var a_boom := _find_ach("boom_town")
	if not a_boom.is_empty():
		var pr: Vector2 = achievement_progress(a_boom)
		if pr.x != 1.0 or pr.y != float(int(a_boom["n"])):
			print("STAGE_C FAIL: 进度 %s" % str(pr))
			fails += 1
	# 废墟清理计数：扩一块地清一格。
	var unf := Vector2i(unlocked_w, 0)
	tick = 0
	# 直接制造一格废墟来测计数（避免依赖升星）。
	ruins[Vector2i(0, 0)] = true
	if clear_ruin(Vector2i(0, 0)):
		if ruins_cleared != 1:
			print("STAGE_C FAIL: 废墟计数 = %d" % ruins_cleared)
			fails += 1
	else:
		print("STAGE_C FAIL: clear_ruin 失败")
		fails += 1
	# 义体安装计数。
	warehouse["dermal_weave"] = 1
	if ConfigDB.cyberware.has("dermal_weave"):
		install_implant(int(residents[0].id), "dermal_weave")
		if implants_installed != 1:
			print("STAGE_C FAIL: 义体计数 = %d" % implants_installed)
			fails += 1
	# 存档往返：计数器与成就。
	lifetime_income = 4200
	var done_n := achievement_unlocked_count()
	var state := to_state()
	ruins_cleared = 0
	_ach_done.clear()
	from_state(state)
	if lifetime_income != 4200 or ruins_cleared != 1 or achievement_unlocked_count() != done_n:
		print("STAGE_C FAIL: 存档往返 income=%d ruins=%d ach=%d/%d" % [
			lifetime_income, ruins_cleared, achievement_unlocked_count(), done_n])
		fails += 1
	if fails == 0:
		print("STAGE_C PASS: 成就解锁/奖励/进度/计数器/存档正常（%d 条成就）" % ConfigDB.achievements.size())
	else:
		print("STAGE_C FAIL: %d 项失败" % fails)

## 自动化自检（城市扩张）：土地上限/征地/废墟产出/清理/价格递增/存档。
func selftest_expand() -> void:
	var fails := 0
	new_game()
	# 开局 20×15、星级 1 → 上限就是 20×15，没有可征的地。
	if unlocked_w != GW or unlocked_h != GH:
		print("STAGE_D FAIL: 开局 %dx%d" % [unlocked_w, unlocked_h])
		fails += 1
	if pending_land() != Vector2i.ZERO or can_expand("x"):
		print("STAGE_D FAIL: 开局不该有可征土地 %s" % str(pending_land()))
		fails += 1
	# 升星提高上限（偶数星 +4 列），但不自动占地。
	star = 2
	_update_unlock_rect()
	if unlocked_w != GW or pending_land().x != 4:
		print("STAGE_D FAIL: 升 2 星后 w=%d 待征=%d" % [unlocked_w, pending_land().x])
		fails += 1
	# 征地：花钱、格数变多、新格全是废墟。
	add_money(20000)
	var st0: Dictionary = land_stats()
	var cost := expand_cost()
	var m0 := money
	if not expand_land("x"):
		print("STAGE_D FAIL: 征地失败")
		fails += 1
	var st1: Dictionary = land_stats()
	if unlocked_w != GW + EXPAND_STEP or money != m0 - cost:
		print("STAGE_D FAIL: 征地结果 w=%d money=%d cost=%d" % [unlocked_w, money, cost])
		fails += 1
	if int(st1["unlocked"]) <= int(st0["unlocked"]):
		print("STAGE_D FAIL: 地块数没变多 %d -> %d" % [int(st0["unlocked"]), int(st1["unlocked"])])
		fails += 1
	if not ruins.has(Vector2i(20, 0)) or not ruins.has(Vector2i(21, 14)):
		print("STAGE_D FAIL: 新格子不是废墟")
		fails += 1
	if expand_cost() <= cost:
		print("STAGE_D FAIL: 征地价格没递增 %d -> %d" % [cost, expand_cost()])
		fails += 1
	# 清废墟 → 可建造格变多。
	var free_before := int(land_stats()["free"])
	if not clear_ruin(Vector2i(20, 0)):
		print("STAGE_D FAIL: 清理失败")
		fails += 1
	if int(land_stats()["free"]) != free_before + 1:
		print("STAGE_D FAIL: 清理后可建造格没增加 %d -> %d" % [free_before, int(land_stats()["free"])])
		fails += 1
	# 一键清废墟。
	add_money(100000)
	var cleared := clear_all_ruins()
	if cleared <= 0 or not ruins.is_empty():
		print("STAGE_D FAIL: 一键清理 cleared=%d 剩余=%d" % [cleared, ruins.size()])
		fails += 1
	# 征满上限后不能再征。
	while can_expand("x"):
		expand_land("x")
	if expand_step_size("x") != 0 or can_expand("x"):
		print("STAGE_D FAIL: 征满后还能征（step=%d）" % expand_step_size("x"))
		fails += 1
	# 存档往返。
	var ex := expansions
	var w_after := unlocked_w
	var state := to_state()
	expansions = 0
	unlocked_w = GW
	from_state(state)
	if expansions != ex or unlocked_w != w_after:
		print("STAGE_D FAIL: 存档往返 expansions=%d w=%d" % [expansions, unlocked_w])
		fails += 1
	if fails == 0:
		print("STAGE_D PASS: 土地上限/征地/废墟产出/清理/价格递增/存档正常")
	else:
		print("STAGE_D FAIL: %d 项失败" % fails)

## 自检辅助：按 id 找成就定义。
func _find_ach(aid: String) -> Dictionary:
	for a in ConfigDB.achievements:
		if String(a["id"]) == aid:
			return a
	return {}

func selftest_stage6() -> void:
	var fails := 0
	if ConfigDB.research_list.size() != 4:
		print("STAGE6 FAIL: research lines=%d (want 4)" % ConfigDB.research_list.size())
		fails += 1
	if research_slots() != 0 or can_start_research("underground_engineering"):
		print("STAGE6 FAIL: research allowed without labs/servers")
		fails += 1
	star = 3
	add_money(5000)
	if not build("secret_server", 0, 12):
		print("STAGE6 FAIL: build secret_server")
		fails += 1
	if not build("hack_bench", 18, 6):
		print("STAGE6 FAIL: build hack_bench")
		fails += 1
	if research_slots() != 1 or absf(research_speed_mult() - 0.8) > 0.001:
		print("STAGE6 FAIL: slots=%d speed=%.2f" % [research_slots(), research_speed_mult()])
		fails += 1
	_award_junk(2)
	recycle_junk()
	if not recycle_junk() or knowledge != 20:
		print("STAGE6 FAIL: recycle knowledge=%d" % knowledge)
		fails += 1
	if not exchange_stim("body") or knowledge != 0:
		print("STAGE6 FAIL: exchange stim")
		fails += 1
	if not can_start_research("underground_engineering"):
		print("STAGE6 FAIL: research prereq not met")
		fails += 1
	if not start_research("underground_engineering"):
		print("STAGE6 FAIL: start_research refused")
		fails += 1
	if not research.has("underground_engineering"):
		print("STAGE6 FAIL: research not active")
		fails += 1
	research["underground_engineering"]["left"] = 1
	_tick_research()
	if not research_done.has("underground_engineering") or research.has("underground_engineering"):
		print("STAGE6 FAIL: research not completed")
		fails += 1
	if building_star_req("holo_theater") != 2:
		print("STAGE6 FAIL: early unlock req=%d (want 2)" % building_star_req("holo_theater"))
		fails += 1
	var state := to_state()
	from_state(state)
	if knowledge != 0 or not research_done.has("underground_engineering"):
		print("STAGE6 FAIL: save/load roundtrip")
		fails += 1
	if fails == 0:
		print("STAGE6 PASS: 研究槽/前置/加速/提前解锁 + 工作台回收兑换/存档正常")
	else:
		print("STAGE6 FAIL: %d 项失败" % fails)

func _growth_keys(key: String) -> PackedStringArray:
	match key:
		"hack":
			return PackedStringArray(["intelligence", "tech"])
		"social":
			return PackedStringArray(["cool", "intelligence"])
		_:
			return PackedStringArray(["body", "reflex"])

func _warn_satisfaction() -> void:
	if residents.is_empty() or _low_sat_day == day():
		return
	if _avg_satisfaction() < 40.0:
		_low_sat_day = day()
		EventBus.notice.emit("居民在抱怨，缺吃的、缺玩的，或者该去诊所了")

# ---------------------------------------------------------------- 压力与后果（阶段 A）

## 平均满意度（0–100）。
func _avg_satisfaction() -> float:
	if residents.is_empty():
		return 0.0
	var s := 0.0
	for r in residents:
		s += r.satisfaction()
	return s / float(residents.size())

## 居民情绪结算：满意度 <35 累加不满天数，≥45 清零；满 3 天搬走。
## 开局前 5 天是宽限期，别让新玩家还没学会就被搬空。
func _morning_mood() -> void:
	if day() <= 5:
		return
	var leaving: Array = []
	for r in residents:
		if r.state == Resident.State.AWAY:
			continue
		var sat: float = r.satisfaction()
		if sat < 35.0:
			r.unhappy_days = int(r.unhappy_days) + 1
		elif sat >= 45.0:
			r.unhappy_days = 0
		if int(r.unhappy_days) == UNHAPPY_LEAVE - 1:
			EventBus.notice.emit("%s 在收拾行李：街区缺吃缺玩，再不改善就要搬走了" % String(r.rname))
		elif int(r.unhappy_days) >= UNHAPPY_LEAVE:
			leaving.append(int(r.id))
	for rid in leaving:
		var rr = resident_by_id(int(rid))
		if rr == null or rr.state == Resident.State.AWAY:
			continue
		residents.erase(rr)
		EventBus.notice.emit("%s 搬离了街区（长期不满）· 人口 -1" % String(rr.rname))
		EventBus.news_paper.emit("有人走了", "%s 收拾行李离开了 · 把吃的玩的补上才留得住人" % String(rr.rname))
	_refresh_complaints()

## 破产：声望流失，连续 3 天没钱就抵押最便宜的建筑还债。
func _check_bankruptcy() -> void:
	if money > 0:
		_broke_days = 0
		return
	_broke_days += 1
	add_rep(-BROKE_REP_PENALTY)
	if _broke_days >= BROKE_SELL_DAYS:
		_broke_days = 0
		_seize_cheapest_building()
	else:
		EventBus.news_paper.emit("资金见底",
			"声望 -%d · 再 %d 天还不上钱，就得拿建筑抵债" % [BROKE_REP_PENALTY, BROKE_SELL_DAYS - _broke_days])

## 抵押最便宜的建筑（收入最低那栋），返还半价现金。
func _seize_cheapest_building() -> void:
	if buildings.is_empty():
		return
	var pick := -1
	var lowest := 1 << 30
	for i in buildings.size():
		var inc := int(buildings[i].get("base_income", 0))
		if inc < lowest:
			lowest = inc
			pick = i
	if pick < 0:
		return
	var b: Dictionary = buildings[pick]
	var refund := maxi(50, int(float(ConfigDB.get_facility(String(b["fid"])).get("cost", 0)) * 0.5))
	var nm := String(b["name"])
	remove_bid(int(b["bid"]), false, false)
	add_money(refund)
	EventBus.news_paper.emit("抵押「%s」" % nm, "还不上钱只能拿它抵债 · 回收 €%d" % refund)

## 口碑迁入：每 4 天一次，满意度与声望够高就有人主动搬来（补上"做好就有回报"的正循环）。
func _natural_immigration() -> void:
	if day() <= 1 or day() % IMMIGRATION_DAYS != 0:
		return
	if residents.size() >= resident_cap():
		return
	if _avg_satisfaction() < 60.0 or rep < IMMIGRATION_REP:
		return
	var before := residents.size()
	_spawn_residents(1)
	if residents.size() > before:
		EventBus.notice.emit("街区口碑传开了，有人主动搬进来（人口 +1）")

# ---------------------------------------------------------------- 委托

# ---------------------------------------------------------------- 新手引导（阶段 B）

## 目标判定值：data/tutorial.json 的 check 字段 → 当前进度。
func _goal_value(check: String) -> float:
	match check:
		"buildings":
			return float(buildings.size())
		"visits":
			var best := 0
			for b in buildings:
				best = maxi(best, int(b.get("visits", 0)))
			return float(best)
		"combos":
			return float(combos_found.size())
		"gigs":
			return float(gigs_done)
		"satisfaction":
			return _avg_satisfaction()
		"bosses":
			return float(bosses_killed)
		"star":
			return float(star)
		"residents":
			return float(residents.size())
		"expansions":
			return float(expansions)
		_:
			return 0.0

## 当前目标（第一个未完成项）；全部完成返回空字典。
func current_goal() -> Dictionary:
	for st in ConfigDB.tutorial_steps:
		if not _tutorial_done.has(String(st["id"])):
			return st
	return {}

## 引导进度（已完成, 总数）。
func goal_progress() -> Vector2i:
	return Vector2i(_tutorial_done.size(), ConfigDB.tutorial_steps.size())

## 顺序推进：当前目标达成才继续检查下一个（可连锁，例如一口气建满 3 栋）。
func _check_tutorial() -> void:
	var st := current_goal()
	if st.is_empty():
		return
	if _goal_value(String(st.get("check", ""))) >= float(st.get("n", 1)):
		_tutorial_done[String(st["id"])] = true
		EventBus.notice.emit("✓ 目标完成：%s" % String(st["text"]))
		EventBus.goal_changed.emit()
		_check_tutorial()

# ---------------------------------------------------------------- 成就（阶段 C）

## 成就判定值：data/achievements.json 的 check 字段 → 当前进度。
func _ach_value(check: String) -> float:
	match check:
		"lifetime_income":
			return float(lifetime_income)
		"buildings":
			return float(buildings.size())
		"combos":
			return float(combos_found.size())
		"bosses":
			return float(bosses_killed)
		"legends":
			var n := 0
			for fid in LEGENDARY_FIDS:
				if _has_fid(String(fid)):
					n += 1
			return float(n)
		"residents":
			return float(residents.size())
		"star":
			return float(star)
		"research":
			return float(research_done.size())
		"implants":
			return float(implants_installed)
		"gigs":
			return float(gigs_done)
		"money":
			return float(money)
		"maxed":
			return float(maxed_building_count())
		"mastery":
			return float(top_mastery_count())
		"ruins":
			return float(ruins_cleared)
		"expansions":
			return float(expansions)
		_:
			return 0.0

## 成就进度（当前, 目标），给成就页显示用。
func achievement_progress(a: Dictionary) -> Vector2:
	var need := maxf(1.0, float(a.get("n", 1)))
	return Vector2(minf(_ach_value(String(a.get("check", ""))), need), need)

func achievement_unlocked(id: String) -> bool:
	return _ach_done.has(id)

func achievement_unlocked_count() -> int:
	return _ach_done.size()

## 全部成就都检查（不像引导那样按顺序）。
func _check_achievements() -> void:
	for a in ConfigDB.achievements:
		var aid := String(a["id"])
		if _ach_done.has(aid):
			continue
		if _ach_value(String(a.get("check", ""))) < float(a.get("n", 1)):
			continue
		_ach_done[aid] = true
		var pay := int(a.get("money", 0))
		var rp := int(a.get("rep", 0))
		if pay > 0:
			add_money(pay)
		if rp > 0:
			add_rep(rp)
		EventBus.achievement_unlocked.emit(aid, String(a["name"]), String(a["desc"]), pay, rp)
		EventBus.notice.emit("🏆 成就达成「%s」· %s" % [String(a["name"]), String(a["desc"])])

# ---------------------------------------------------------------- 城市扩张：征地（阶段 D）

## 星级决定"土地上限"，但不再自动占地：玩家要在「扩张」页花钱征地，
## 新征到的格子全是废墟，清完才能盖楼 —— 扩张的产出就是"可放置建筑物的格子变多"。
const EXPAND_STEP := 2
const EXPAND_COST_BASE := 1200
const EXPAND_COST_GROWTH := 1.35

## 土地上限（由星级决定：开局 20×15，偶数星 +4 列、奇数星 +4 行）。
func land_cap() -> Vector2i:
	return _target_unlock()

## 还能征多少格（列 / 行）。
func pending_land() -> Vector2i:
	var cap := _target_unlock()
	return Vector2i(maxi(0, cap.x - unlocked_w), maxi(0, cap.y - unlocked_h))

## 下一次征地价格（每征一次涨 35%）。
func expand_cost() -> int:
	return int(round(float(EXPAND_COST_BASE) * pow(EXPAND_COST_GROWTH, float(expansions))))

## 本次征地能拿到几格（受上限约束）。
func expand_step_size(axis: String) -> int:
	var p := pending_land()
	return mini(EXPAND_STEP, p.x if axis == "x" else p.y)

func can_expand(axis: String) -> bool:
	return expand_step_size(axis) > 0 and money >= expand_cost()

## 征地：增加可放置格数（新格子是废墟，需清理）。
func expand_land(axis: String) -> bool:
	var step := expand_step_size(axis)
	if step <= 0 or money < expand_cost():
		return false
	var cost := expand_cost()
	var old_w := unlocked_w
	var old_h := unlocked_h
	if axis == "x":
		unlocked_w = mini(MAX_GW, unlocked_w + step)
	else:
		unlocked_h = mini(MAX_GH, unlocked_h + step)
	var gained := 0
	for y in unlocked_h:
		for x in unlocked_w:
			if x < old_w and y < old_h:
				continue
			ruins[Vector2i(x, y)] = true
			gained += 1
	_rebuild_walk_grid()
	_reindex_occupancy()
	_region_dirty = true
	_scan_combos()
	expansions += 1
	_announced_pending = pending_land()
	add_money(-cost)
	EventBus.notice.emit("征得 %d 格土地（%s）· 全是废墟，清完才能盖楼" % [
		gained, "东扩" if axis == "x" else "北扩"])
	EventBus.region_changed.emit(expansions)
	return true

## 土地账本：给「扩张」页显示用。
func land_stats() -> Dictionary:
	var free_cells := 0
	var blockers := 0
	for y in unlocked_h:
		for x in unlocked_w:
			var c := Vector2i(x, y)
			if bid_at(c) >= 0 or ruins.has(c) or roads.has(c):
				blockers += 1
			else:
				free_cells += 1
	var cap := _target_unlock()
	return {
		"unlocked": unlocked_w * unlocked_h,
		"free": free_cells,
		"blockers": blockers,
		"ruins": ruins.size(),
		"cap": cap.x * cap.y,
		"cap_w": cap.x, "cap_h": cap.y,
		"pending": pending_land(),
		"expansions": expansions,
	}

## 一次清完全部废墟（钱够多少清多少），返回清理格数。
func clear_all_ruins() -> int:
	if ruins.is_empty() or money < RUIN_CLEAR_COST:
		return 0
	var cells: Array = ruins.keys()
	var cleared := 0
	for c in cells:
		if money < RUIN_CLEAR_COST:
			break
		if clear_ruin(c):
			cleared += 1
	_region_dirty = true
	_scan_combos()
	return cleared

func _fill_gigs(target: int) -> void:
	var pool: Array = []
	for g in ConfigDB.gig_templates:
		if star >= int(g.get("star", 1)):
			pool.append(g)
	# guard 要随目标容量放大：5 星时板子有 7 格，随机撞重复的次数也更多。
	var guard := 0
	var guard_max := 24 + target * 8
	while gig_board.size() < target and guard < guard_max:
		guard += 1
		if pool.is_empty():
			return
		var src: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var dup := false
		for g in gig_board:
			if String(g["id"]) == String(src["id"]):
				dup = true
				break
		if dup and pool.size() > gig_board.size():
			continue
		var copy: Dictionary = src.duplicate(true)
		copy["uid"] = _next_gig_uid
		_next_gig_uid += 1
		gig_board.append(copy)

func can_send(rid: int) -> bool:
	var r = resident_by_id(rid)
	return r != null and r.state != Resident.State.AWAY and not r.injured(tick)

func _clean_team(rids: Array) -> Array:
	var team: Array = []
	for rid in rids:
		var id := int(rid)
		if team.has(id):
			continue
		if not can_send(id):
			return []
		team.append(id)
		if team.size() >= MAX_SQUAD:
			break
	return team

func team_power(rids: Array, key: String, vs_boss: bool = false) -> int:
	var total := 0
	for rid in rids:
		var r = resident_by_id(int(rid))
		if r != null:
			total += battle_power(r, key, vs_boss)
	return total

## 委托战力。数据交易所的情报加成只加在这里，不进 Boss 战。
func gig_team_power(rids: Array, key: String) -> int:
	return int(round(float(team_power(rids, key)) * intel_power_mult()))

func team_names(rids: Array) -> String:
	var names := PackedStringArray()
	for rid in rids:
		var r = resident_by_id(int(rid))
		if r != null:
			names.append(String(r.rname))
	return "、".join(names)

func team_reward_mult(rids: Array) -> float:
	var best := 1.0
	for rid in rids:
		var r = resident_by_id(int(rid))
		if r != null:
			best = maxf(best, float(r.reward_mult))
	return best

func team_rep_mult(rids: Array) -> float:
	var best := 1.0
	for rid in rids:
		var r = resident_by_id(int(rid))
		if r != null:
			best = maxf(best, float(r.rep_mult))
	return best * graffiti_rep_mult()

func _grant_team_xp(rids: Array, amount: int) -> void:
	for rid in rids:
		var r = resident_by_id(int(rid))
		if r != null:
			_grant_xp(r, amount)

func grade_text(ratio: float) -> String:
	if ratio >= 1.5:
		return "大成功"
	if ratio >= 1.0:
		return "成功"
	if ratio >= 0.5:
		return "部分成功"
	return "失败"

func dispatch_gig(uid: int, rids: Array) -> bool:
	var found := -1
	for i in gig_board.size():
		if int(gig_board[i]["uid"]) == uid:
			found = i
			break
	if found < 0:
		return false
	var team: Array = _clean_team(rids)
	if team.is_empty():
		return false
	var gig: Dictionary = gig_board[found]
	gig_board.remove_at(found)
	for rid in team:
		resident_by_id(int(rid)).pull_off_street()
	# 技术专家：破坏类委托耗时 -30%。
	var left_ticks := int(gig["hours"]) * TICKS_PER_HOUR
	if String(gig["type"]) == "破坏" and _team_has_passive(team, "fast_sabotage"):
		left_ticks = int(round(float(left_ticks) * 0.7))
	# 黑客帝国激活时科技（hack 路）委托耗时 -30%。
	if String(gig["power"]) == "hack":
		left_ticks = int(round(float(left_ticks) * tech_gig_time_mult()))
	missions.append({
		"rids": team,
		"kind": "gig",
		"left": left_ticks,
		"gig": gig.duplicate(true),
	})
	EventBus.board_changed.emit()
	EventBus.notice.emit("%s 出发：%s" % [team_names(team), String(gig["name"])])
	return true

func _tick_missions() -> void:
	for i in range(missions.size() - 1, -1, -1):
		missions[i]["left"] = int(missions[i]["left"]) - 1
		if int(missions[i]["left"]) <= 0:
			var m: Dictionary = missions[i]
			missions.remove_at(i)
			_resolve_mission(m)

func _resolve_mission(m: Dictionary) -> void:
	var team: Array = m["rids"]
	for rid in team:
		var r = resident_by_id(int(rid))
		if r != null:
			r.state = Resident.State.IDLE
	if String(m["kind"]) == "boss":
		_resolve_boss(team, m)
	elif String(m["kind"]) == "train":
		_resolve_train(team, m)
	else:
		_resolve_gig(team, m["gig"])
	# 义体医生：结算时治好全队伤员。
	if _team_has_passive(team, "field_medic"):
		for rid in team:
			var rr = resident_by_id(int(rid))
			if rr != null and rr.injured(tick):
				rr.injured_until = 0
				EventBus.notice.emit("义体医生给 %s 处理了伤势" % String(rr.rname))
	EventBus.board_changed.emit()

func _resolve_gig(rids: Array, gig: Dictionary) -> void:
	var key := String(gig["power"])
	var pwr := gig_team_power(rids, key)
	# 网络黑客：劫持类委托战力 +10%。
	if String(gig["type"]) == "劫持" and _team_has_passive(rids, "heist_bonus"):
		pwr = int(round(float(pwr) * 1.1))
	var need := maxi(1, int(gig["need"]))
	var ratio := float(pwr) / float(need)
	var pay := int(round(float(int(gig["pay"])) * team_reward_mult(rids)))
	# 赏金猎人：提取类报酬 +20%。赛博忍者：破坏类报酬 +25%。
	var gtype := String(gig["type"])
	if gtype == "提取" and _team_has_passive(rids, "extract_bonus"):
		pay = int(round(float(pay) * 1.2))
	elif gtype == "破坏" and _team_has_passive(rids, "ninja"):
		pay = int(round(float(pay) * 1.25))
	var rep_gain := apply_rep_mult(int(gig["rep"]), team_rep_mult(rids))
	var outcome := grade_text(ratio)
	if ratio >= 1.5:
		pay = int(round(float(pay) * 1.5))
		rep_gain = int(round(float(rep_gain) * 1.5))
		_grant_team_xp(rids, 30)
		gigs_done += 1
		if int(gig.get("star", 0)) >= 5:
			t5_gigs_done += 1
		_award_junk(1)
	elif ratio >= 1.0:
		_grant_team_xp(rids, 20)
		gigs_done += 1
		if int(gig.get("star", 0)) >= 5:
			t5_gigs_done += 1
		_award_junk(1)
	elif ratio >= 0.5:
		pay = int(round(float(pay) * ratio))
		rep_gain = int(round(float(rep_gain) * 0.5))
		_hurt_team(rids, 0.25, 140)
		_grant_team_xp(rids, 10)
	else:
		pay = 0
		rep_gain = -8
		_hurt_team(rids, 0.5, 180)
		_grant_team_xp(rids, 5)
	if pay > 0:
		add_money(pay)
	add_rep(rep_gain)
	EventBus.notice.emit("%s「%s」%s · €%d · 声望 %+d" % [team_names(rids), String(gig["name"]), outcome, pay, rep_gain])
	_recalc_star()

func _hurt_team(rids: Array, chance: float, ticks: int) -> void:
	for rid in rids:
		var r = resident_by_id(int(rid))
		if r != null and rng.randf() < chance * float(r.injury_mult):
			r.injured_until = tick + ticks

# ---------------------------------------------------------------- 训练（阶段 7）

## 某项五维的场地要求。
func train_sites(stat: String) -> Array:
	return TRAIN_SITES.get(stat, [])

## 单次训练收益：格斗笼练体质 +3，其余 +2。
func train_gain(stat: String) -> int:
	if stat == "body" and _has_fid("fight_cage"):
		return 3
	return 2

func can_train(rid: int, stat: String) -> bool:
	var r = resident_by_id(rid)
	if r == null or r.state == Resident.State.AWAY or r.injured(tick):
		return false
	if money < TRAIN_COST or int(r.stats[stat]) >= 100:
		return false
	for fid in train_sites(stat):
		if _has_fid(fid):
			return true
	return false

## 花 €200 离城 2 小时练一项五维。训练期间不能派委托/讨伐（AWAY 状态）。
func train_stat(rid: int, stat: String) -> bool:
	if not can_train(rid, stat):
		return false
	var r = resident_by_id(rid)
	add_money(-TRAIN_COST)
	r.pull_off_street()
	missions.append({
		"rids": [int(r.id)],
		"kind": "train",
		"left": TRAIN_HOURS * TICKS_PER_HOUR,
		"stat": stat,
		"gain": train_gain(stat),
	})
	EventBus.notice.emit("%s 去训练「%s」了，%d 小时后回来" % [
		String(r.rname), String(STAT_NAMES.get(stat, stat)), TRAIN_HOURS])
	EventBus.board_changed.emit()
	return true

func _resolve_train(rids: Array, m: Dictionary) -> void:
	var stat := String(m["stat"])
	var gain := int(m.get("gain", 2))
	for rid in rids:
		var r = resident_by_id(int(rid))
		if r != null:
			r.stats[stat] = mini(100, int(r.stats[stat]) + gain)
	EventBus.notice.emit("%s 训练归来：%s +%d" % [
		team_names(rids), String(STAT_NAMES.get(stat, stat)), gain])

# ---------------------------------------------------------------- 研究 + 黑客工作台（阶段 6）

## 设施星级门槛 = 基础门槛 - 已完成研究的提前解锁（保底 1 星）。
func building_star_req(fid: String) -> int:
	var base := ConfigDB.star_requirement(fid)
	for rid2 in research_done:
		var line: Dictionary = ConfigDB.research_lines.get(String(rid2), {})
		if String(line.get("unlocks", "")) == fid:
			return maxi(1, base - 1)
	return base

## 研究槽：研究实验室 ×2（正式规则）+ 秘密服务器 ×1（美术冻结期间的过渡，见注释）。
func research_slots() -> int:
	return count_open_fid("research_lab") * 2 + count_open_fid("secret_server")

## 秘密服务器加速：每栋 -20%，封顶 -40%。
func research_speed_mult() -> float:
	return 1.0 - minf(0.4, RESEARCH_SERVER_SPEED * float(count_open_fid("secret_server")))

func active_research_count() -> int:
	return research.size()

## 找出可用的技术系（hack 路）居民，最多 max 名。
func _free_tech_residents(max: int) -> Array:
	var out: Array = []
	for r in residents:
		if String(r.power_key) != "hack":
			continue
		if r.state == Resident.State.AWAY or r.injured(tick):
			continue
		out.append(int(r.id))
		if out.size() >= max:
			break
	return out

func can_start_research(line_id: String) -> bool:
	var line: Dictionary = ConfigDB.research_lines.get(line_id, {})
	if line.is_empty():
		return false
	if research.has(line_id) or research_done.has(line_id):
		return false
	if active_research_count() >= research_slots():
		return false
	if money < int(line["cost"]) or not _has_fid(String(line["prereq"])):
		return false
	return not _free_tech_residents(1).is_empty()

## 开研究：扣费，自动派 1–2 名技术系居民（离城加速），耗时受服务器与人员影响。
func start_research(line_id: String) -> bool:
	if not can_start_research(line_id):
		return false
	var line: Dictionary = ConfigDB.research_lines[line_id]
	var team := _free_tech_residents(2)
	add_money(-int(line["cost"]))
	var mult := research_speed_mult()
	for _i in team.size():
		mult *= 1.0 - RESEARCH_RESIDENT_SPEED
	var total := maxi(1, int(round(float(int(line["hours"]) * TICKS_PER_HOUR) * mult)))
	research[line_id] = {"left": total, "total": total, "rids": team}
	for rid in team:
		var r = resident_by_id(int(rid))
		if r != null:
			r.pull_off_street()
	EventBus.notice.emit("开始研究「%s」· €%d · 预计 %d 小时" % [
		String(line["name"]), int(line["cost"]), ceili(float(total) / float(TICKS_PER_HOUR))])
	return true

func _tick_research() -> void:
	if research.is_empty():
		return
	for line_id in research.keys():
		var rec: Dictionary = research[line_id]
		rec["left"] = int(rec["left"]) - 1
		if int(rec["left"]) > 0:
			continue
		research.erase(line_id)
		research_done.append(String(line_id))
		for rid in rec.get("rids", []):
			var r = resident_by_id(int(rid))
			if r != null:
				r.state = Resident.State.IDLE
		var line: Dictionary = ConfigDB.research_lines.get(String(line_id), {})
		var unlock_name := String(ConfigDB.get_facility(String(line.get("unlocks", ""))).get("name", ""))
		EventBus.notice.emit("研究完成「%s」· %s提前 1 星解锁" % [String(line.get("name", line_id)), unlock_name])

# ---------------------------------------------------------------- 黑客工作台（阶段 6）

func can_recycle_junk() -> bool:
	return _has_fid("hack_bench") and junk >= 1

## 1 个赛博垃圾 → 10 知识点。
func recycle_junk() -> bool:
	if not can_recycle_junk():
		return false
	junk -= 1
	knowledge += JUNK_KNOWLEDGE
	EventBus.notice.emit("回收赛博垃圾 · 知识点 +%d（共 %d）" % [JUNK_KNOWLEDGE, knowledge])
	return true

func knowledge_cost(price: int) -> int:
	return ceili(float(price) / 10.0)

func can_exchange_weapon(wid: String) -> bool:
	var w: Dictionary = ConfigDB.weapons.get(wid, {})
	if w.is_empty() or not _has_fid("hack_bench"):
		return false
	return star >= int(w["star"]) and knowledge >= knowledge_cost(int(w["price"]))

func exchange_weapon(wid: String) -> bool:
	if not can_exchange_weapon(wid):
		return false
	var w: Dictionary = ConfigDB.weapons[wid]
	knowledge -= knowledge_cost(int(w["price"]))
	warehouse[wid] = int(warehouse.get(wid, 0)) + 1
	EventBus.notice.emit("兑换「%s」· 知识点 -%d" % [String(w["name"]), knowledge_cost(int(w["price"]))])
	return true

func can_exchange_implant(wid: String) -> bool:
	var cw: Dictionary = ConfigDB.cyberware.get(wid, {})
	if cw.is_empty() or not _has_fid("hack_bench"):
		return false
	return star >= int(cw["star"]) and knowledge >= knowledge_cost(int(cw["price"]))

func exchange_implant(wid: String) -> bool:
	if not can_exchange_implant(wid):
		return false
	var cw: Dictionary = ConfigDB.cyberware[wid]
	knowledge -= knowledge_cost(int(cw["price"]))
	warehouse[wid] = int(warehouse.get(wid, 0)) + 1
	EventBus.notice.emit("兑换义体「%s」· 知识点 -%d" % [String(cw["name"]), knowledge_cost(int(cw["price"]))])
	return true

func can_exchange_stim(stat: String) -> bool:
	return _has_fid("hack_bench") and knowledge >= KNOWLEDGE_STIM_COST

func exchange_stim(stat: String) -> bool:
	if not can_exchange_stim(stat):
		return false
	knowledge -= KNOWLEDGE_STIM_COST
	stims[stat] = int(stims.get(stat, 0)) + 1
	EventBus.notice.emit("兑换强化剂（%s）· 知识点 -%d" % [
		String(STAT_NAMES.get(stat, stat)), KNOWLEDGE_STIM_COST])
	return true

# ---------------------------------------------------------------- 赛博精神病

func boss_busy() -> bool:
	for m in missions:
		if String(m["kind"]) == "boss":
			return true
	return false

func _try_intro_boss() -> void:
	if _intro_boss_spawned or not boss.is_empty() or boss_busy():
		return
	if buildings.is_empty():
		return
	# 第一单还没真正成功、也还没到 2 星时，不把教学 Boss 放出来。
	if gigs_done < 1 and star < 2:
		return
	_intro_boss_spawned = true
	_spawn_boss(ConfigDB.bosses[0], BOSS_INTRO_GRACE_HOURS, true)

func _try_random_boss() -> void:
	if not boss.is_empty() or boss_busy() or ConfigDB.bosses.is_empty():
		return
	if rng.randf() > 0.5:
		return
	_spawn_boss(ConfigDB.bosses[rng.randi_range(0, ConfigDB.bosses.size() - 1)])

func _spawn_boss(src: Dictionary, grace_hours: int = BOSS_GRACE_HOURS, intro: bool = false) -> void:
	boss = src.duplicate(true)
	var stay_hours := grace_hours + 10 if intro else 10
	boss["left"] = stay_hours * TICKS_PER_HOUR
	boss["stay"] = boss["left"]
	boss["attack_in"] = grace_hours * TICKS_PER_HOUR
	# 网络监察中心：Boss 第一次动手推迟 4 小时。
	if _has_fid("netwatch_hub"):
		boss["attack_in"] = int(boss["attack_in"]) + 4 * TICKS_PER_HOUR
	boss["target_bid"] = _random_building_bid()
	if intro:
		boss["intro"] = true
		boss["intro_hits"] = 0
		boss["power"] = BOSS_INTRO_POWER
	var kind := String(boss.get("kind", ""))
	# 故障体战力开局随机，玩家看到的是区间而非真值 → 只能保守派最强队。
	# 记下基准值，boss_power_text() 要用它算区间（不能用随机后的结果）。
	if kind == "glitch":
		var base := int(boss["power"])
		boss["power_base"] = base
		boss["power"] = int(round(float(base) * rng.randf_range(0.6, 1.5)))
	if intro:
		intro_warning = true
		set_speed(0)
		EventBus.intro_boss.emit(String(boss["name"]), grace_hours, int(boss["power"]))
	elif kind == "stealth":
		# 潜行者隐藏倒计时，威胁栏不显示剩余时间。
		EventBus.notice.emit("有人在暗处盯着街区…「%s」不知道什么时候动手" % String(boss["name"]))
	else:
		EventBus.notice.emit("赛博精神病「%s」闯进街区了，%d 小时后动手 · 去威胁栏派人" % [
			String(boss["name"]), grace_hours])
	EventBus.boss_changed.emit()

## 潜行者的倒计时对玩家不可见。
func boss_timer_hidden() -> bool:
	return String(boss.get("kind", "")) == "stealth"

## 讨伐该 Boss 该看哪路战力。
##   hack    黑客 —— 要网络对抗
##   stealth 潜行者 —— 靠社交/反应去逮
##   其他    正面硬碰
func boss_power_key() -> String:
	match String(boss.get("kind", "")):
		"hack":
			return "hack"
		"stealth":
			return "social"
		_:
			return "combat"

## 玩家看到的战力。故障体只给区间，逼玩家做保守决策。
func boss_power_text() -> String:
	if boss.is_empty():
		return ""
	if String(boss.get("kind", "")) == "glitch":
		# 必须用 power_base 算区间；boss["power"] 已经随机化过了。
		var base := int(boss.get("power_base", boss["power"]))
		return "?? (%d-%d)" % [int(round(base * 0.6)), int(round(base * 1.5))]
	return str(int(boss["power"]))

func _tick_boss() -> void:
	if boss.is_empty():
		return
	boss["left"] = int(boss["left"]) - 1
	boss["attack_in"] = int(boss["attack_in"]) - 1
	if int(boss["attack_in"]) <= 0:
		_boss_attack()
		if not boss.is_empty():
			boss["attack_in"] = BOSS_ATTACK_GAP_HOURS * TICKS_PER_HOUR
	if not boss.is_empty() and int(boss["left"]) <= 0:
		EventBus.notice.emit("「%s」逃脱了 · 声望 -20" % String(boss["name"]))
		add_rep(-20)
		boss = {}
		EventBus.boss_changed.emit()

func _boss_attack() -> void:
	if boss.is_empty():
		return
	# 虫群同时铺开多处：一次打 2 栋，玩家没法靠抢修单点解决。
	if String(boss.get("kind", "")) == "swarm":
		_hit_one()
		if not boss.is_empty():
			_retarget_boss()
			_hit_one()
		if not boss.is_empty():
			_retarget_boss()
			EventBus.boss_changed.emit()
		return
	_hit_one()
	if not boss.is_empty():
		_retarget_boss()
		EventBus.boss_changed.emit()

func _hit_one() -> void:
	if boss.is_empty():
		return
	var bid := int(boss.get("target_bid", -1))
	var idx := index_of_bid(bid)
	if idx < 0:
		bid = _random_building_bid()
		boss["target_bid"] = bid
		idx = index_of_bid(bid)
	if idx < 0:
		return
	var b: Dictionary = buildings[idx]
	if bool(boss.get("intro", false)) and buildings.size() <= 1:
		EventBus.notice.emit("「%s」绕开了最后一栋店" % String(boss["name"]))
		return
	if _resisted(b):
		EventBus.notice.emit("「%s」没能破坏「%s」" % [String(boss["name"]), String(b["name"])])
		return
	if bool(boss.get("intro", false)) and int(boss.get("intro_hits", 0)) <= 0:
		boss["intro_hits"] = 1
		b["disabled_until"] = tick + 4 * TICKS_PER_HOUR
		EventBus.notice.emit("「%s」让「%s」停业了 4 小时，店还在" % [String(boss["name"]), String(b["name"])])
		return
	if String(boss.get("kind", "")) == "hack":
		b["disabled_until"] = tick + 4 * TICKS_PER_HOUR
		EventBus.notice.emit("「%s」黑入了「%s」，店暂时关了" % [String(boss["name"]), String(b["name"])])
	elif int(b["level"]) > 1:
		b["level"] = int(b["level"]) - 1
		EventBus.notice.emit("「%s」把「%s」打回 Lv%d" % [String(boss["name"]), String(b["name"]), int(b["level"])])
	elif not bool(b.get("damaged", false)):
		b["damaged"] = true
		EventBus.notice.emit("「%s」砸坏了「%s」，收入掉一半 · 花 €%d 可修" % [
			String(boss["name"]), String(b["name"]), REPAIR_COST])
	else:
		# 已受损的店不会一击消失：Boss 转去砸别家，给玩家留出抢修的余地。
		# 全街都已受损时才真正拆除，避免出现无事可做的死循环。
		var other := _undamaged_building_bid()
		if other >= 0:
			boss["target_bid"] = other
			EventBus.notice.emit("「%s」懒得再砸废墟，转向了别家" % String(boss["name"]))
			return
		var nm := String(b["name"])
		# 拆楼留下废墟（阶段 9）：不可建不可走，€200/格清理。
		remove_bid(int(b["bid"]), false, true)
		EventBus.notice.emit("「%s」把「%s」拆成废墟了 · €%d/格清理" % [
			String(boss["name"]), nm, RUIN_CLEAR_COST])

func _resisted(b: Dictionary) -> bool:
	var chance := 0.0
	if _near_fid(b, "chrome_vine", 2):
		chance += 0.45
	if _has_fid("gang_safehouse"):
		chance += 0.30
	return chance > 0.0 and rng.randf() < chance

func _retarget_boss() -> void:
	if boss.is_empty():
		return
	boss["target_bid"] = _random_building_bid()

func _random_building_bid() -> int:
	if buildings.is_empty():
		return -1
	return int(buildings[rng.randi_range(0, buildings.size() - 1)]["bid"])

## 随机挑一栋还没受损的建筑，全都受损则返回 -1。
func _undamaged_building_bid() -> int:
	var pool: Array = []
	for b in buildings:
		if not bool(b.get("damaged", false)):
			pool.append(int(b["bid"]))
	if pool.is_empty():
		return -1
	return int(pool[rng.randi_range(0, pool.size() - 1)])

func dispatch_boss(rids: Array) -> bool:
	if boss.is_empty() or boss_busy():
		return false
	var team: Array = _clean_team(rids)
	if team.is_empty():
		return false
	for rid in team:
		resident_by_id(int(rid)).pull_off_street()
	missions.append({
		"rids": team,
		"kind": "boss",
		"left": TICKS_PER_HOUR,
		"boss_id": String(boss["id"]),
	})
	EventBus.board_changed.emit()
	EventBus.notice.emit("%s 去拦「%s」" % [team_names(team), String(boss["name"])])
	return true

func _resolve_boss(rids: Array, m: Dictionary) -> void:
	if boss.is_empty() or String(boss.get("id", "")) != String(m.get("boss_id", "")):
		EventBus.notice.emit("%s 赶到的时候人已经跑了" % team_names(rids))
		return
	var key := boss_power_key()
	# 缉查队员对 Boss 的 ×1.5 在这里生效（vs_boss 开关），不进委托结算。
	var pwr := team_power(rids, key, true)
	# 法外狂徒激活时 Boss 战战力 +15%。
	if _combo_flags.has("outlaw"):
		pwr = int(round(float(pwr) * float(_combo_by_id("outlaw").get("boss_power_mult", 1.0))))
	var need := maxi(1, int(boss["power"]))
	var ratio := float(pwr) / float(need)
	if ratio >= 0.82:
		var pay := int(round(float(int(boss["pay"])) * team_reward_mult(rids)))
		var rp := apply_rep_mult(int(boss["rep"]), team_rep_mult(rids))
		if ratio < 1.0:
			pay = int(round(float(pay) * 0.7))
		# 赛博忍者：讨伐结算 +25%。
		if _team_has_passive(rids, "ninja"):
			pay = int(round(float(pay) * 1.25))
		# 故障体掉落翻倍，补偿它战力不可预测的风险。
		if String(boss.get("kind", "")) == "glitch":
			pay *= 2
		add_money(pay)
		add_rep(rp)
		bosses_killed += 1
		for rid in rids:
			var rr = resident_by_id(int(rid))
			if rr != null:
				rr.boss_acc = int(rr.boss_acc) + 1
		# 首次讨伐某类 Boss：报纸（阶段 12）。
		var bkind := String(boss.get("kind", ""))
		if bkind != "" and not boss_kinds_killed.has(bkind):
			boss_kinds_killed[bkind] = true
			EventBus.news_paper.emit("讨伐「%s」" % String(boss["name"]),
				"首次击败这类赛博精神病 · 街区声望大涨")
		_grant_team_xp(rids, 36)
		_award_junk(3)
		_award_implant_drop()
		if ratio < 1.0:
			_hurt_team(rids, 1.0, 140)
		var nm := String(boss["name"])
		boss = {}
		EventBus.boss_changed.emit()
		EventBus.notice.emit("%s 解决了「%s」· €%d · 声望 +%d" % [team_names(rids), nm, pay, rp])
		_recalc_star()
	else:
		_hurt_team(rids, 1.0, 180)
		EventBus.notice.emit("%s 被「%s」打了回来，得去诊所或者等一会儿" % [team_names(rids), String(boss["name"])])

# ---------------------------------------------------------------- 事件与星级

func _roll_event() -> void:
	if tick < event_until or day() < 2:
		return
	if rng.randf() > 0.45:
		return
	# 开局前几天只给好事，别让新手一上来就吃灾难。
	var pool: Array = []
	for e: Dictionary in EVENTS:
		if day() < 4 and not bool(e.get("good", false)):
			continue
		pool.append(e)
	if pool.is_empty():
		return
	_fire_event(pool[rng.randi_range(0, pool.size() - 1)])

func _fire_event(e: Dictionary) -> void:
	var periods := int(e.get("periods", 1))
	if periods > 0:
		event_kind = String(e["kind"])
		event_name = String(e["name"])
		event_until = tick + periods * TICKS_PER_PERIOD
	if int(e.get("rep", 0)) != 0:
		add_rep(int(e["rep"]))
	match String(e.get("instant", "")):
		"spawn":
			_spawn_residents(int(e.get("amount", 1)))
		"damage":
			_damage_random(int(e.get("amount", 1)))
	EventBus.notice.emit(String(e["notice"]))

## 随机砸坏若干栋（帮派火拼）。已受损的跳过，全受损则不再叠加。
func _damage_random(count: int) -> void:
	for _i in count:
		var bid := _undamaged_building_bid()
		if bid < 0:
			return
		var idx := index_of_bid(bid)
		if idx < 0:
			return
		buildings[idx]["damaged"] = true

func current_event() -> Dictionary:
	if event_kind == "" or tick >= event_until:
		return {}
	for e: Dictionary in EVENTS:
		if String(e["kind"]) == event_kind:
			return e
	return {}

## 数据风暴期间不刷新委托。
func gigs_blocked() -> bool:
	return bool(current_event().get("block_gigs", false))

## 按 STAR_REQS 逐级判定。条件全部满足才继续往上，中间断一级就停。
func _recalc_star() -> void:
	var next := 1
	for req: Dictionary in STAR_REQS:
		if int(req["star"]) != next + 1:
			continue
		if not _meets_req(req):
			break
		next = int(req["star"])
	if next <= star:
		return
	# 可能一次跨多级（例如补建到 10 栋时同时满足 4、5 星）
	while star < next:
		star += 1
		EventBus.rep_changed.emit(rep, star)
		EventBus.star_up.emit(star, star_title())
		# 升星报纸 + 暂停（阶段 12）。
		set_speed(0)
		EventBus.news_paper.emit("号外 · %d 星「%s」" % [star, star_title()], next_goal())
	_update_unlock_rect()
	# 升星会解锁更高星委托、也会扩容委托板，立刻补上不用等到次日早晨。
	_fill_gigs(board_capacity())
	EventBus.board_changed.emit()

func _meets_req(req: Dictionary) -> bool:
	return gigs_done >= int(req.get("gigs", 0)) \
		and bosses_killed >= int(req.get("bosses", 0)) \
		and rep >= int(req.get("rep", 0)) \
		and buildings.size() >= int(req.get("buildings", 0)) \
		and t5_gigs_done >= int(req.get("t5", 0)) \
		and maxed_building_count() >= int(req.get("maxed", 0)) \
		and top_mastery_count() >= int(req.get("mastery", 0))

## 满级设施数量（阶段 10 的 9 星门槛）。
func maxed_building_count() -> int:
	var n := 0
	for b in buildings:
		var max_lv := int(ConfigDB.get_facility(String(b["fid"])).get("max_level", 3))
		if int(b["level"]) >= max_lv:
			n += 1
	return n

## 全街最高精通职业数（阶段 10 的 10 星门槛：16 = 全职业精通）。
func top_mastery_count() -> int:
	var best := 0
	for r in residents:
		best = maxi(best, int(r.mastered.size()))
	return best

## 人数上限：min(100, 8 + (星级 - 1) × 10)。
func resident_cap() -> int:
	return mini(100, 8 + (star - 1) * 10)
