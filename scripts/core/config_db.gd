extends Node
## 静态数据表。设施目录按星级分批开放，避免一上来把整张表堆进底栏。
##
## 数据约定（facilities.json 是唯一真源，改数值不要碰代码）：
##   star        解锁门槛，玩家星级 >= 它才能建
##   implemented 是否已实装。没有这个标记的条目是预留设计稿——
##               缺美术资源、效果也没写进 Game，不进建造目录。

var themes: Dictionary = {}
var facilities: Dictionary = {}
var facility_list: Array = []
var jobs: Dictionary = {}
var job_list: Array = []
var gig_templates: Array = []
var bosses: Array = []
var weapons: Dictionary = {}
var weapon_list: Array = []
var cyberware: Dictionary = {}
var cyberware_list: Array = []
var research_lines: Dictionary = {}
var research_list: Array = []
var combos: Array = []
var theme_jobs: Dictionary = {}
var start_town: Array = []
## 新手引导目标链（tutorial.json）。
var tutorial_steps: Array = []
## 成就表（achievements.json）。
var achievements: Array = []

## 底栏分组顺序。不在这里的主题排在最后。
const THEME_ORDER: PackedStringArray = [
	"street", "underground", "gang", "corporate", "neon", "deco",
]

func _ready() -> void:
	themes = _load("res://data/themes.json")
	var arr = _load("res://data/facilities.json")
	if arr is Array:
		for f in arr:
			f["size"] = int(f.get("size", 2))
			f["cost"] = int(f.get("cost", 0))
			f["income"] = int(f.get("income", 0))
			f["star"] = int(f.get("star", 1))
			f["max_level"] = int(f.get("max_level", 1))
			f["implemented"] = bool(f.get("implemented", false))
			facilities[String(f["id"])] = f
			facility_list.append(f)
	var jarr = _load("res://data/jobs.json")
	if jarr is Array:
		for j in jarr:
			j["injury"] = float(j.get("injury", 1))
			j["reward"] = float(j.get("reward", 1))
			j["rep"] = float(j.get("rep", 1))
			jobs[String(j["id"])] = j
			job_list.append(j)
	var garr = _load("res://data/gigs.json")
	if garr is Array:
		for g in garr:
			g["need"] = int(g["need"])
			g["pay"] = int(g["pay"])
			g["rep"] = int(g["rep"])
			g["hours"] = int(g["hours"])
			g["star"] = int(g.get("star", 1))
			gig_templates.append(g)
	var barr = _load("res://data/bosses.json")
	if barr is Array:
		for b in barr:
			b["power"] = int(b["power"])
			b["pay"] = int(b["pay"])
			b["rep"] = int(b["rep"])
			bosses.append(b)
	var warr = _load("res://data/weapons.json")
	if warr is Array:
		for w in warr:
			w["price"] = int(w["price"])
			w["star"] = int(w.get("star", 1))
			w["rarity"] = int(w.get("rarity", 1))
			weapons[String(w["id"])] = w
			weapon_list.append(w)
	var carr = _load("res://data/cyberware.json")
	if carr is Array:
		for c in carr:
			c["price"] = int(c["price"])
			c["star"] = int(c.get("star", 1))
			c["rarity"] = int(c.get("rarity", 1))
			c["dura"] = int(c.get("dura", 6))
			cyberware[String(c["id"])] = c
			cyberware_list.append(c)
	var rarr = _load("res://data/research.json")
	if rarr is Array:
		for rl in rarr:
			rl["cost"] = int(rl["cost"])
			rl["hours"] = int(rl["hours"])
			research_lines[String(rl["id"])] = rl
			research_list.append(rl)
	var cobj = _load("res://data/combos.json")
	if cobj is Dictionary:
		for c in cobj.get("combos", []):
			combos.append(c)
		theme_jobs = cobj.get("theme_jobs", {})
	var tobj = _load("res://data/start_town.json")
	if tobj is Dictionary:
		for t in tobj.get("buildings", []):
			start_town.append(t)
	var tut = _load("res://data/tutorial.json")
	if tut is Dictionary:
		for st in tut.get("steps", []):
			st["n"] = float(st.get("n", 1))
			tutorial_steps.append(st)
	var ach = _load("res://data/achievements.json")
	if ach is Dictionary:
		for a in ach.get("achievements", []):
			a["n"] = float(a.get("n", 1))
			a["money"] = int(a.get("money", 0))
			a["rep"] = int(a.get("rep", 0))
			achievements.append(a)

func _load(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("缺少数据表: " + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var res: Variant = JSON.parse_string(txt)
	if res == null:
		push_error("JSON 解析失败: " + path)
		return {}
	return res

func theme_color(theme_id: String, key: String = "neon") -> Color:
	var t: Dictionary = themes.get(theme_id, {})
	return Color.from_string(String(t.get(key, "#ffffff")), Color.WHITE)

func theme_name(theme_id: String) -> String:
	var t: Dictionary = themes.get(theme_id, {})
	return String(t.get("name", theme_id))

func get_facility(fid: String) -> Dictionary:
	return facilities.get(fid, {})

## 解锁门槛。未实装的条目返回 99，等于永远建不了。
func star_requirement(fid: String) -> int:
	var f: Dictionary = facilities.get(fid, {})
	if f.is_empty() or not bool(f.get("implemented", false)):
		return 99
	return int(f.get("star", 1))

## 建造目录：只含已实装设施，按主题分组、组内按星级升序。
func catalog_entries() -> Array:
	var by_theme: Dictionary = {}
	for f: Dictionary in facility_list:
		if not bool(f.get("implemented", false)):
			continue
		var th := String(f.get("theme", ""))
		if not by_theme.has(th):
			by_theme[th] = []
		f["need_star"] = int(f.get("star", 1))
		by_theme[th].append(f)

	var themes_sorted: Array = []
	for th in THEME_ORDER:
		if by_theme.has(th):
			themes_sorted.append(th)
	for th in by_theme.keys():
		if not themes_sorted.has(th):
			themes_sorted.append(th)

	var out: Array = []
	for th in themes_sorted:
		var group: Array = by_theme[th]
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["need_star"]) < int(b["need_star"]))
		out.append_array(group)
	return out
