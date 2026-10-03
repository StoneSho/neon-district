class_name Resident
extends RefCounted
## 居民：需求驱动去消费；被派去委托或讨伐时离城。

enum State { IDLE, MOVE, CONSUME, AWAY }

## 需求衰减（每 tick）。策划案按"每天"给值，这里除以 Game.TICKS_PER_DAY = 480。
## 饥饿 5/天 · 娱乐 8/天 · 健康 3/天 · 义体 1/天
const DECAY := {
	"hunger": 5.0 / 480.0,
	"fun": 8.0 / 480.0,
	"health": 3.0 / 480.0,
	"cyberware": 1.0 / 480.0,
}
## 一次消费的回复量（再乘设施的 satisfy 系数）。
## 原为 75 = 一次回满；衰减按策划案放慢后，回满会让需求系统形同虚设。
## 40 约等于"五天的娱乐消耗"，配合居民自发逛店的频率，
## 设施齐备时满意度稳在 98、缺某类需求时该项精准掉到 30-55。
const RESTORE := 40.0
## 低于此值居民会主动去找对应设施（原 58，配合慢衰减提高到 70 让觅食更积极）
const URGENT := 70.0
const CONSUME_TICKS := 16
const WALK_SPEED := 3.2

var id: int = 0
var rname: String = "?"
var job_id: String = ""
var job_name: String = ""
var power_key: String = "combat"
var color: Color = Color.WHITE
var pos: Vector2 = Vector2.ZERO
var cell: Vector2i = Vector2i.ZERO
var path: Array[Vector2i] = []
var state: int = State.IDLE
var timer: int = 0
var target_bid: int = -1
var needs := { "hunger": 80.0, "fun": 80.0, "health": 80.0, "cyberware": 80.0 }
var stats := { "body": 20, "reflex": 20, "tech": 20, "intelligence": 20, "cool": 20 }
var level: int = 1
var xp: int = 0
var injured_until: int = 0
var reward_mult: float = 1.0
var rep_mult: float = 1.0
var injury_mult: float = 1.0
## Lv10 精通过的职业 id（转职后旧职业被动保留）。当前职业的被动随时生效，
## 不进这个列表，转职时由 Game.change_job 把旧职业追加进来。
var mastered: Array = []
## 被动带来的移速倍率（流浪者 ×2），由 Game._refresh_passive_state 维护。
var speed_mult: float = 1.0
## 装备中的武器 id（阶段 4）。每人 1 件，加成见 weapons.json 的 bonus。
var weapon_id: String = ""
## 已安装的义体（阶段 5）：slot -> {"id": wid, "dur": 剩余耐久天数}。
var implants: Dictionary = {}
## 讨伐贡献（阶段 12 年度大赏用）：每次成功讨伐 Boss +1，大赏后清零。
var boss_acc: int = 0
## 连续不满天数（压力系统）：满意度 <35 累加，≥45 清零，满 3 天搬走。
var unhappy_days: int = 0

## 武器对某系战力的加成。
func weapon_power(key: String) -> int:
	var w: Dictionary = ConfigDB.weapons.get(weapon_id, {})
	var bonus: Dictionary = w.get("bonus", {})
	return int(bonus.get(key, 0))

## 义体对某个五维属性的加成（耐久为 0 的失效义体不计）。
func implant_bonus(stat: String) -> int:
	var total := 0
	for slot in implants.keys():
		var rec: Dictionary = implants[slot]
		if int(rec.get("dur", 0)) <= 0:
			continue
		var cw: Dictionary = ConfigDB.cyberware.get(String(rec.get("id", "")), {})
		var bonus: Dictionary = cw.get("bonus", {})
		total += int(bonus.get(stat, 0))
	return total

## 当前生效的全部被动 id：精通过的旧职业 + 当前职业。
func passive_ids() -> Array:
	var out: Array = mastered.duplicate()
	var job: Dictionary = ConfigDB.jobs.get(job_id, {})
	var p := String(job.get("passive", ""))
	if p != "" and not out.has(p):
		out.append(p)
	return out

func has_passive(pid: String) -> bool:
	return passive_ids().has(pid)

func injured(now: int) -> bool:
	return now < injured_until

func power(key: String) -> int:
	match key:
		"combat":
			return int(stats["body"]) + implant_bonus("body") + int(stats["reflex"]) + implant_bonus("reflex")
		"hack":
			return int(stats["intelligence"]) + implant_bonus("intelligence") + int(stats["tech"]) + implant_bonus("tech")
		"social":
			return int(stats["cool"]) + implant_bonus("cool") + int(stats["intelligence"]) + implant_bonus("intelligence")
		_:
			return maxi(power("combat"), maxi(power("hack"), power("social")))

func satisfaction() -> float:
	var s := 0.0
	for k in needs.keys():
		s += float(needs[k])
	return s / float(maxi(needs.size(), 1))

func most_urgent() -> String:
	var worst := ""
	var low := 999.0
	for k in needs.keys():
		var v := float(needs[k])
		if v < low:
			low = v
			worst = k
	return worst

func status_text(now: int) -> String:
	if state == State.AWAY:
		return "外出"
	if injured(now):
		return "受伤"
	if state == State.CONSUME:
		return "消费中"
	if state == State.MOVE and target_bid >= 0:
		return "赶路"
	return "闲逛"

func step(game) -> void:
	_decay(game)
	if state == State.AWAY:
		return
	match state:
		State.IDLE:
			_decide(game)
		State.MOVE:
			_advance(game)
		State.CONSUME:
			timer -= 1
			if timer <= 0:
				_finish(game)

func _decay(game) -> void:
	var scale := 0.35 if state == State.AWAY else 1.0
	scale *= game.decay_scale()   # 住所（rest）会整体放慢衰减
	for k in DECAY.keys():
		# 没装义体的居民不产生义体需求（阶段 5：不强迫他们立刻去改装）。
		if k == "cyberware" and implants.is_empty():
			continue
		var kscale := scale
		# 赛博秋叶原周边娱乐衰减减半（阶段 8）。
		if k == "fun":
			kscale *= game.fun_decay_scale(cell)
		var v := maxf(0.0, float(needs[k]) - float(DECAY[k]) * kscale)
		# 莫克斯藏身处：需求下限 60（阶段 3 收尾）。
		needs[k] = maxf(v, game.need_floor())

func _decide(game) -> void:
	var here: Vector2i = game.nearest_walkable(cell)
	if here != cell:
		cell = here
		pos = Vector2(here)
	var need := most_urgent()
	if float(needs[need]) < URGENT:
		var idx: int = _pick_facility(game, need)
		if idx >= 0 and _go(game, idx):
			return
	if game.rng.randf() < 0.45 and not game.buildings.is_empty():
		var idx2: int = game.rng.randi_range(0, game.buildings.size() - 1)
		var shop: Dictionary = game.buildings[idx2]
		if int(shop.get("base_income", 0)) > 0 and not game.is_hacked(shop) and _go(game, idx2):
			return
	var dst: Vector2i = game.random_walkable()
	var wp: Array = game.resident_path(cell, dst)
	if not wp.is_empty():
		path.clear()
		for c in wp:
			path.append(c)
		if not path.is_empty():
			path.remove_at(0)
		target_bid = -1
		state = State.MOVE

func _pick_facility(game, need: String) -> int:
	var best := -1
	var best_score := 0.0
	for i in game.buildings.size():
		var b: Dictionary = game.buildings[i]
		if game.is_hacked(b):
			continue
		var sat: Dictionary = b.get("satisfy", {})
		var amount := float(sat.get(need, 0.0))
		if amount <= 0.0:
			continue
		var d: float = float(game.dist_to_building(cell, i)) + 1.0
		var score: float = amount * float(game.region_mult_for(i)) * float(game.period_mult(String(b["theme"]), String(b["tag"]))) * 14.0 / d
		if score > best_score:
			best_score = score
			best = i
	return best

func _go(game, idx: int) -> bool:
	var bid := int(game.buildings[idx]["bid"])
	var goal: Vector2i = game.approach_cell(idx, cell)
	if goal.x < 0:
		return false
	if goal == cell:
		target_bid = bid
		path.clear()
		state = State.CONSUME
		timer = CONSUME_TICKS
		return true
	var p: Array = game.resident_path(cell, goal)
	if p.is_empty():
		return false
	path.clear()
	for c in p:
		path.append(c)
	if not path.is_empty():
		path.remove_at(0)
	target_bid = bid
	state = State.MOVE
	return true

func _advance(game) -> void:
	if target_bid >= 0 and game.index_of_bid(target_bid) < 0:
		target_bid = -1
		path.clear()
		state = State.IDLE
		return
	if path.is_empty():
		if target_bid >= 0:
			state = State.CONSUME
			timer = CONSUME_TICKS
		else:
			state = State.IDLE
		return
	var t: Vector2i = path[0]
	if not game.is_walkable(t):
		path.clear()
		target_bid = -1
		state = State.IDLE
		return
	var goal := Vector2(t)
	# 走私通道移速加成（阶段 3 收尾）：全街 +5%/栋，封顶 +15%。
	var step_len: float = WALK_SPEED * speed_mult * (1.0 + float(game.resident_speed_bonus())) \
		* float(game.road_speed_mult(cell)) / float(Game.TPS)
	if pos.distance_to(goal) <= step_len:
		pos = goal
		cell = t
		path.remove_at(0)
	else:
		pos += (goal - pos).normalized() * step_len

func _finish(game) -> void:
	var idx: int = game.index_of_bid(target_bid)
	if idx >= 0:
		game.payout(self, idx)
		var b: Dictionary = game.buildings[idx]
		if String(b.get("tag", "")) == "medic":
			injured_until = 0
	target_bid = -1
	state = State.IDLE

func pull_off_street() -> void:
	path.clear()
	target_bid = -1
	timer = 0
	state = State.AWAY
