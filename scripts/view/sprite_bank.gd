extends RefCounted
## 把抠好的像素图读进来。缺文件时调用方继续用色块。

var buildings: Dictionary = {}
var idles: Dictionary = {}
var walks: Dictionary = {}
var bosses: Dictionary = {}

func _init() -> void:
	# 从 ConfigDB 派生，不再手工维护清单：新增设施只要在
	# facilities.json 标 implemented 并放好 PNG 就会自动加载。
	for fid in _building_ids():
		var fallback := _tex("res://assets/buildings/%s.png" % fid)
		var rots: Array[Texture2D] = []
		var any := false
		for i in 4:
			var face := _tex("res://assets/buildings/%s_%d.png" % [fid, i])
			if face == null:
				face = fallback
			rots.append(face)
			if face != null:
				any = true
		if any:
			buildings[fid] = rots
	# 职业按 sprite 字段回退到现有行走图（新职业先复用旧动画，用 color 区分）。
	for job: Dictionary in ConfigDB.job_list:
		var jid := String(job["id"])
		var folder := String(job.get("sprite", jid))
		var idle := _tex("res://assets/characters/%s/idle.png" % folder)
		if idle != null:
			idles[jid] = idle
		var frames: Array[Texture2D] = []
		for i in 4:
			var frame := _tex("res://assets/characters/%s/walk_%d.png" % [folder, i])
			if frame != null:
				frames.append(frame)
		if frames.size() == 4:
			walks[jid] = frames
	for boss_id in _boss_ids():
		var tex := _tex("res://assets/bosses/%s.png" % boss_id)
		if tex != null:
			bosses[boss_id] = tex

## 需要贴图的设施：已实装的都算，缺图时 _tex 返回 null，调用方回退色块。
func _building_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for f: Dictionary in ConfigDB.facility_list:
		if bool(f.get("implemented", false)):
			out.append(String(f["id"]))
	return out

func _boss_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for b: Dictionary in ConfigDB.bosses:
		out.append(String(b["id"]))
	return out

func building_tex(fid: String, rot: int = 0) -> Texture2D:
	var rots: Array = buildings.get(fid, [])
	if rots.is_empty():
		return null
	var tex: Texture2D = rots[posmod(rot, rots.size())]
	if tex == null:
		for face in rots:
			if face != null:
				return face
	return tex

func _tex(path: String) -> Texture2D:
	# 必须走资源系统。早先用 Image.load() 直读磁盘，编辑器里正常，
	# 但导出后 .pck 里没有原始 png，49 个素材会全部回退成色块。
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
