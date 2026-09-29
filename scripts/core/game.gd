extends Node
## 模拟内核：时间、建造、居民、委托、赛博精神病。与渲染无关。

const GW := 14
const GH := 10
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
]
const MAX_STAR := 5

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
var _intro_boss_spawned := false
var _low_sat_day := 0

func _ready() -> void:
	rng.seed = 20770531
	_setup_astar()
	at_menu = true
	speed = 0

## 委托板容量随星级增长：名气越大，找上门的活越多。
## 高星玩家有 8 名居民能同时跑两队，固定 3 条会让他们闲着。
func board_capacity() -> int:
	return 3 + (star - 1)

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
	if tick % 40 == 0:
		_warn_satisfaction()
	if tick % TICKS_PER_PERIOD == 0:
		EventBus.time_changed.emit(day(), period())
		_on_period()

func _on_period() -> void:
	var p := period()
	if p == 1:
		if gigs_blocked():
			EventBus.notice.emit("数据风暴还没停，今天没有新委托")
		else:
			var before := gig_board.size()
			_fill_gigs(board_capacity())
			if gig_board.size() > before:
				EventBus.notice.emit("早晨，委托板上有新活")
				EventBus.board_changed.emit()
		_roll_event()
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
	if gigs_done < int(req["gigs"]):
		parts.append("成功委托 %d/%d" % [gigs_done, int(req["gigs"])])
	if bosses_killed < int(req["bosses"]):
		parts.append("讨伐 %d/%d" % [bosses_killed, int(req["bosses"])])
	if rep < int(req["rep"]):
		parts.append("声望 %d/%d" % [rep, int(req["rep"])])
	if buildings.size() < int(req["buildings"]):
		parts.append("建筑 %d/%d" % [buildings.size(), int(req["buildings"])])
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
	astar.region = Rect2i(0, 0, GW, GH)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

func in_bounds(gx: int, gy: int) -> bool:
	return gx >= 0 and gy >= 0 and gx < GW and gy < GH

func can_build(fid: String, gx: int, gy: int) -> bool:
	var f: Dictionary = ConfigDB.get_facility(fid)
	if f.is_empty():
		return false
	if star < ConfigDB.star_requirement(fid):
		return false
	var s := int(f["size"])
	if gx < 0 or gy < 0 or gx + s > GW or gy + s > GH:
		return false
	for y in range(gy, gy + s):
		for x in range(gx, gx + s):
			if occupancy.has(Vector2i(x, y)):
				return false
	return money >= int(f["cost"])

func build(fid: String, gx: int, gy: int, rot: int = 0) -> bool:
	if not can_build(fid, gx, gy):
		return false
	var f: Dictionary = ConfigDB.get_facility(fid)
	var s := int(f["size"])
	add_money(-int(f["cost"]))
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

func remove_bid(bid: int, refund: bool = true) -> void:
	var idx := index_of_bid(bid)
	if idx < 0:
		return
	var b: Dictionary = buildings[idx]
	var s := int(b["size"])
	for y in range(int(b["gy"]), int(b["gy"]) + s):
		for x in range(int(b["gx"]), int(b["gx"]) + s):
			occupancy.erase(Vector2i(x, y))
			astar.set_point_solid(Vector2i(x, y), false)
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
	for y in GH:
		for x in GW:
			astar.set_point_solid(Vector2i(x, y), false)
	_reindex_occupancy()

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
	return in_bounds(cell.x, cell.y) and not occupancy.has(cell)

func is_hacked(b: Dictionary) -> bool:
	return tick < int(b.get("disabled_until", 0))

func nearest_walkable(from: Vector2i) -> Vector2i:
	if is_walkable(from):
		return from
	for radius in range(1, maxi(GW, GH)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var c := from + Vector2i(dx, dy)
				if is_walkable(c):
					return c
	return random_walkable()

func random_walkable() -> Vector2i:
	for _i in 40:
		var c := Vector2i(rng.randi_range(1, GW - 2), rng.randi_range(1, GH - 2))
		if is_walkable(c):
			return c
	return Vector2i(GW / 2, GH / 2)

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
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		_combo_of[int(b["bid"])] = _calc_combo(i)

func _calc_combo(i: int) -> float:
	if i < 0 or i >= _fids_cache.size():
		return 1.0
	var fids: Dictionary = _fids_cache[i]
	var self_fid := String(buildings[i]["fid"])
	var supper := fids.has("neon_noodle") and fids.has("neon_bar")
	var market := supper and fids.has("used_cyber_stall")
	var mine := self_fid == "neon_noodle" or self_fid == "neon_bar" or self_fid == "used_cyber_stall"
	if not mine:
		return 1.0
	if supper and (self_fid == "neon_noodle" or self_fid == "neon_bar"):
		_discover("street_supper", "街头夜宵")
	if market:
		_discover("night_market", "义体夜市")
		return 1.5
	if supper and self_fid != "used_cyber_stall":
		return 1.3
	return 1.0

func _discover(id: String, title: String) -> void:
	if combos_found.has(id):
		return
	combos_found[id] = true
	EventBus.notice.emit("发现相性「%s」！这几栋贴在一起的店收入更高" % title)

func combo_mult_for(idx: int) -> float:
	if idx < 0 or idx >= buildings.size():
		return 1.0
	return float(_combo_of.get(int(buildings[idx]["bid"]), 1.0))

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
	_spawn_residents(8)
	_fill_gigs(board_capacity())
	_emit_world()
	session_started = true
	save_slot(true)
	EventBus.notice.emit("新游戏")

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
	return r

# ---------------------------------------------------------------- 经济

func add_money(v: int) -> void:
	money += v
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
	if bool(b.get("damaged", false)):
		mult *= 0.55
	return int(round(float(b["base_income"]) * mult))

func payout(r, idx: int) -> int:
	var amount := estimate_income(idx)
	if amount > 0:
		add_money(amount)
	var b: Dictionary = buildings[idx]
	b["visits"] = int(b["visits"]) + 1
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

func battle_power(r, key: String) -> int:
	var p: int = r.power(key)
	if String(r.power_key) == key or key == "any":
		p = int(round(float(p) * 1.15))
	return p

func _grant_xp(r, amount: int) -> void:
	r.xp = int(r.xp) + amount
	var guard := 0
	while int(r.xp) >= 30 * int(r.level) and int(r.level) < 8 and guard < 4:
		r.xp = int(r.xp) - 30 * int(r.level)
		r.level = int(r.level) + 1
		var keys: PackedStringArray = _growth_keys(String(r.power_key))
		for k in keys:
			r.stats[k] = mini(100, int(r.stats[k]) + 4)
		EventBus.notice.emit("%s 升到 Lv%d" % [String(r.rname), int(r.level)])
		guard += 1

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
	var s := 0.0
	for r in residents:
		s += r.satisfaction()
	if s / float(residents.size()) < 40.0:
		_low_sat_day = day()
		EventBus.notice.emit("居民在抱怨，缺吃的、缺玩的，或者该去诊所了")

# ---------------------------------------------------------------- 委托

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

func team_power(rids: Array, key: String) -> int:
	var total := 0
	for rid in rids:
		var r = resident_by_id(int(rid))
		if r != null:
			total += battle_power(r, key)
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
	missions.append({
		"rids": team,
		"kind": "gig",
		"left": int(gig["hours"]) * TICKS_PER_HOUR,
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
	else:
		_resolve_gig(team, m["gig"])
	EventBus.board_changed.emit()

func _resolve_gig(rids: Array, gig: Dictionary) -> void:
	var key := String(gig["power"])
	var pwr := gig_team_power(rids, key)
	var need := maxi(1, int(gig["need"]))
	var ratio := float(pwr) / float(need)
	var pay := int(round(float(int(gig["pay"])) * team_reward_mult(rids)))
	var rep_gain := apply_rep_mult(int(gig["rep"]), team_rep_mult(rids))
	var outcome := grade_text(ratio)
	if ratio >= 1.5:
		pay = int(round(float(pay) * 1.5))
		rep_gain = int(round(float(rep_gain) * 1.5))
		_grant_team_xp(rids, 30)
		gigs_done += 1
	elif ratio >= 1.0:
		_grant_team_xp(rids, 20)
		gigs_done += 1
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
		remove_bid(int(b["bid"]), false)
		EventBus.notice.emit("「%s」把「%s」拆成废墟了" % [String(boss["name"]), nm])

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
	var pwr := team_power(rids, key)
	var need := maxi(1, int(boss["power"]))
	var ratio := float(pwr) / float(need)
	if ratio >= 0.82:
		var pay := int(round(float(int(boss["pay"])) * team_reward_mult(rids)))
		var rp := apply_rep_mult(int(boss["rep"]), team_rep_mult(rids))
		if ratio < 1.0:
			pay = int(round(float(pay) * 0.7))
		# 故障体掉落翻倍，补偿它战力不可预测的风险。
		if String(boss.get("kind", "")) == "glitch":
			pay *= 2
		add_money(pay)
		add_rep(rp)
		bosses_killed += 1
		_grant_team_xp(rids, 36)
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
	# 升星会解锁更高星委托、也会扩容委托板，立刻补上不用等到次日早晨。
	_fill_gigs(board_capacity())
	EventBus.board_changed.emit()

func _meets_req(req: Dictionary) -> bool:
	return gigs_done >= int(req["gigs"]) \
		and bosses_killed >= int(req["bosses"]) \
		and rep >= int(req["rep"]) \
		and buildings.size() >= int(req["buildings"])
