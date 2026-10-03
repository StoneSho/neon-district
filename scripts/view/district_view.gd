extends Node2D
## 等距街区。只读 Game / ConfigDB，不改规则。

const TW := 96.0
## 当前建筑贴图的底座约为 2.8:1。地面使用同一透视，贴图前角才能落在格点上。
const TH := 34.0
const BUILD_H := 46.0
const DECO_H := 26.0

var camera: Camera2D
var build_mode: String = ""
var build_rot: int = 0
var demolish := false
var road_mode := false
var clear_mode := false
var selected_bid: int = -1
var selected_rid: int = -1
var hover := Vector2i(-1000, -1000)
var focus_rid: int = -1
var focus_left: float = 0.0

var _dragging := false
var _floaters: Array = []
var _font: Font
var _bank
var _face: Dictionary = {}

func _ready() -> void:
	_font = UIFont.get_font()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bank = preload("res://scripts/view/sprite_bank.gd").new()
	EventBus.payout.connect(_on_payout)

func iso(c: Vector2) -> Vector2:
	return Vector2((c.x - c.y) * TW * 0.5, (c.x + c.y) * TH * 0.5)

func uniso(p: Vector2) -> Vector2:
	var a := p.x / (TW * 0.5)
	var b := p.y / (TH * 0.5)
	return Vector2((b + a) * 0.5, (b - a) * 0.5)

func corner(gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy) * TW * 0.5, (gx + gy) * TH * 0.5)

func cell_at_world(p: Vector2) -> Vector2i:
	var g := uniso(p)
	return Vector2i(floori(g.x), floori(g.y))

func footprint(b: Dictionary) -> PackedVector2Array:
	var gx := float(b["gx"])
	var gy := float(b["gy"])
	var s := float(b["size"])
	return PackedVector2Array([
		corner(gx, gy), corner(gx + s, gy), corner(gx + s, gy + s), corner(gx, gy + s),
	])

func cell_diamond(c: Vector2i) -> PackedVector2Array:
	return footprint({ "gx": c.x, "gy": c.y, "size": 1 })

func focus_on(rid: int) -> void:
	focus_rid = rid
	focus_left = 1.3
	selected_rid = rid
	selected_bid = -1

func _process(delta: float) -> void:
	queue_redraw()
	_pan_camera(delta)
	if focus_left > 0.0 and camera != null:
		focus_left -= delta
		var r = Game.resident_by_id(focus_rid)
		if r != null and r.state != Resident.State.AWAY:
			var target: Vector2 = iso(r.pos)
			camera.position = camera.position.lerp(target, 1.0 - exp(-delta * 7.0))
			_clamp_camera()
	for i in range(_floaters.size() - 1, -1, -1):
		_floaters[i]["life"] = float(_floaters[i]["life"]) - delta
		_floaters[i]["pos"] = Vector2(_floaters[i]["pos"]) + Vector2(0, -26.0 * delta)
		if float(_floaters[i]["life"]) <= 0.0:
			_floaters.remove_at(i)
	_update_hover()

func _draw() -> void:
	_draw_ground()
	var items: Array = []
	for i in Game.buildings.size():
		var b: Dictionary = Game.buildings[i]
		items.append({ "d": float(b["gx"] + b["gy"]) + float(b["size"]) - 1.0, "kind": 0, "ref": i })
	for r in Game.residents:
		if r.state == Resident.State.AWAY:
			continue
		items.append({ "d": float(r.pos.x + r.pos.y) + 0.5, "kind": 1, "ref": r })
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	for it: Dictionary in items:
		if int(it["kind"]) == 0:
			_draw_building(int(it["ref"]))
		else:
			_draw_resident(it["ref"])
	_draw_boss()
	_draw_hover()
	_draw_floaters()

func _draw_ground() -> void:
	# 常态画面只保留连续地坪；结构网格进入建造模式后再出现，避免网格和贴图底座互相暴露透视差。
	var island := PackedVector2Array([
		corner(0.0, 0.0), corner(float(Game.unlocked_w), 0.0),
		corner(float(Game.unlocked_w), float(Game.unlocked_h)), corner(0.0, float(Game.unlocked_h)),
	])
	draw_colored_polygon(island, Color("#0d1026"))
	var center := (island[0] + island[2]) * 0.5
	for ring in range(4, 0, -1):
		var t := float(ring) / 4.0
		var glow := PackedVector2Array()
		for point: Vector2 in island:
			glow.append(center + (point - center) * t)
		draw_colored_polygon(glow, Color(0.08, 0.16, 0.34, 0.022))
	var rim := PackedVector2Array([island[0], island[1], island[2], island[3], island[0]])
	draw_polyline(rim, Color(0.12, 0.38, 0.72, 0.20), 9.0, true)
	draw_polyline(rim, Color(0.28, 0.78, 1.0, 0.72), 1.8, true)
	# 废墟与道路（阶段 9）：废墟暗红、不可建不可走；道路泛蓝、加速行走。
	for c in Game.ruins.keys():
		var rc: Vector2i = c
		draw_colored_polygon(cell_diamond(rc), Color(0.26, 0.10, 0.12, 0.92))
	for c in Game.roads.keys():
		var rd: Vector2i = c
		draw_colored_polygon(cell_diamond(rd), Color(0.22, 0.30, 0.52, 0.85))
	if build_mode != "":
		for x in Game.unlocked_w + 1:
			var major := x % 4 == 0
			draw_line(corner(float(x), 0.0), corner(float(x), float(Game.unlocked_h)),
				Color(0.30, 0.58, 0.95, 0.30 if major else 0.13), 1.4 if major else 1.0, true)
		for y in Game.unlocked_h + 1:
			var major := y % 4 == 0
			draw_line(corner(0.0, float(y)), corner(float(Game.unlocked_w), float(y)),
				Color(0.30, 0.58, 0.95, 0.30 if major else 0.13), 1.4 if major else 1.0, true)
	# 扩张提示（阶段 D）：把"还能征的地"用金色斜纹条带标出来，让玩家看得见扩张目标。
	var pend: Vector2i = Game.pending_land()
	if pend.x > 0:
		for y in Game.unlocked_h:
			var c3 := Vector2i(Game.unlocked_w, y)
			draw_colored_polygon(cell_diamond(c3), Color(1.0, 0.85, 0.35, 0.28))
		draw_line(corner(float(Game.unlocked_w), 0.0), corner(float(Game.unlocked_w), float(Game.unlocked_h)),
			Color(1.0, 0.9, 0.4, 0.8), 2.6, true)
	if pend.y > 0:
		for x in Game.unlocked_w:
			var c4 := Vector2i(x, Game.unlocked_h)
			draw_colored_polygon(cell_diamond(c4), Color(1.0, 0.85, 0.35, 0.28))
		draw_line(corner(0.0, float(Game.unlocked_h)), corner(float(Game.unlocked_w), float(Game.unlocked_h)),
			Color(1.0, 0.9, 0.4, 0.8), 2.6, true)
	for i in Game.buildings.size():
		var tier: Dictionary = Game.region_tier_for(i)
		if int(tier["count"]) < 3:
			continue
		var b: Dictionary = Game.buildings[i]
		var col: Color = ConfigDB.theme_color(String(b["theme"]))
		col.a = 0.14
		draw_colored_polygon(footprint(b), col)

func _draw_building(idx: int) -> void:
	var b: Dictionary = Game.buildings[idx]
	var s := int(b["size"])
	var theme_id := String(b["theme"])
	var base: Color = ConfigDB.theme_color(theme_id, "base")
	var neon: Color = ConfigDB.theme_color(theme_id, "neon")
	var h := BUILD_H if s >= 2 else DECO_H
	if bool(b.get("damaged", false)):
		base = base.darkened(0.25)
		neon = neon.lerp(Color(1.0, 0.45, 0.2), 0.45)
	if Game.is_hacked(b):
		neon = Color(0.4, 0.85, 1.0)

	var gx := float(b["gx"])
	var gy := float(b["gy"])
	var fs := float(s)
	var c0 := corner(gx, gy)
	var c1 := corner(gx + fs, gy)
	var c2 := corner(gx + fs, gy + fs)
	var c3 := corner(gx, gy + fs)
	var up := Vector2(0, -h)
	var tex: Texture2D = _bank.building_tex(String(b["fid"]), int(b.get("rot", 0)))
	var sprite_top := (c0 + c2) * 0.5 + up

	if tex == null:
		var shadow_poly := PackedVector2Array()
		for p: Vector2 in footprint(b):
			shadow_poly.append(p + Vector2(4, 5))
		draw_colored_polygon(shadow_poly, Color(0, 0, 0, 0.35))
		draw_colored_polygon(PackedVector2Array([c3, c2, c2 + up, c3 + up]), base.darkened(0.18))
		draw_colored_polygon(PackedVector2Array([c2, c1, c1 + up, c2 + up]), base.darkened(0.42))
		var top := PackedVector2Array([c0 + up, c1 + up, c2 + up, c3 + up])
		draw_colored_polygon(top, base.lightened(0.18))
		var outline := PackedVector2Array([top[0], top[1], top[2], top[3], top[0]])
		var glow := neon
		glow.a = 0.28
		draw_polyline(outline, glow, 7.0, true)
		draw_polyline(outline, neon, 2.0, true)
		for bp: Vector2 in [c1, c2, c3]:
			draw_line(bp, bp + up, Color(neon.r, neon.g, neon.b, 0.55), 1.5, true)
		sprite_top = (c0 + c2) * 0.5 + up
		if Game.combo_mult_for(idx) > 1.05:
			draw_circle(top[0], 4.0, Color(1.0, 0.85, 0.35, 0.95))
	else:
		var mod := Color.WHITE
		if bool(b.get("damaged", false)):
			mod = Color(1.0, 0.62, 0.52)
		elif Game.is_hacked(b):
			mod = Color(0.62, 0.95, 1.15)
		# 用地块接触阴影代替高对比度黑色地皮，贴图边缘会和连续地坪自然过渡。
		var contact := PackedVector2Array()
		for p: Vector2 in footprint(b):
			contact.append(p + Vector2(0, 2.5))
		draw_colored_polygon(contact, Color(0.0, 0.0, 0.0, 0.18 if s >= 2 else 0.10))
		if s >= 2:
			draw_colored_polygon(footprint(b), Color(0.025, 0.03, 0.065, 0.42))
		var cover := 0.62 if s == 1 else 1.05
		var dest_w := float(s) * TW * cover
		var dest_h := dest_w * float(tex.get_height()) / float(tex.get_width())
		# 前角直接对齐地块前端；小植物的茎落在地块正中，光晕可以露在外面。
		var foot := c2 if s >= 2 else (c0 + c2) * 0.5 + Vector2(0, 3.0)
		var rect := _draw_bottom(tex, foot, dest_w, dest_h, false, mod)
		sprite_top = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)
		if bool(b.get("damaged", false)):
			draw_line(rect.position, rect.position + rect.size, Color(1.0, 0.35, 0.25, 0.55), 2.0, true)
		if Game.combo_mult_for(idx) > 1.05:
			draw_circle(sprite_top + Vector2(-dest_w * 0.28, 8), 4.0, Color(1.0, 0.85, 0.35, 0.95))

	if int(b["bid"]) == selected_bid:
		var f := footprint(b)
		draw_polyline(PackedVector2Array([f[0], f[1], f[2], f[3], f[0]]), Color(1, 1, 1, 0.9), 3.0, true)

	if tex == null:
		var label_c := sprite_top
		var tier: Dictionary = Game.region_tier_for(idx)
		var text := "%s Lv%d" % [String(b["name"]), int(b["level"])]
		if int(tier["count"]) >= 3:
			text += " ×%.1f" % float(tier["mult"])
		var label_w := 168.0 if s >= 2 else 96.0
		_outlined(label_c + Vector2(-label_w * 0.5, -16), text, 14 if s >= 2 else 12, Color(0.95, 0.97, 1.0), label_w)

func _draw_resident(r) -> void:
	# 格子坐标是地块的后角，人要站在地块中心，脚才落在砖面上
	var foot := iso(r.pos + Vector2(0.5, 0.5)) + Vector2(0, 8)
	var moving: bool = int(r.state) == Resident.State.MOVE and not r.path.is_empty()
	if moving:
		var nxt: Vector2 = iso(Vector2(r.path[0]))
		_face[int(r.id)] = nxt.x < foot.x
	var flip := bool(_face.get(int(r.id), false))
	var job := String(r.job_id)
	var frames: Array = _bank.walks.get(job, [])
	var tex: Texture2D = null
	if moving and frames.size() == 4:
		tex = frames[(int(Time.get_ticks_msec() / 130) + int(r.id)) % 4]
	else:
		tex = _bank.idles.get(job, null)
		if tex == null and frames.size() > 0:
			tex = frames[0]
	var mod := Color.WHITE
	if r.injured(Game.tick):
		mod = Color(1.0, 0.55, 0.55)
	if int(r.id) == selected_rid:
		mod = mod.lerp(Color(1.0, 0.95, 0.65), 0.35)
	if tex == null:
		_shadow(foot, 8.0)
		draw_circle(foot + Vector2(0, -10), 7.0, r.color if not r.injured(Game.tick) else Color(1, 0.4, 0.4))
		var comp0 := Game.complaint_text(int(r.id))
		if comp0 != "":
			_outlined(foot + Vector2(0, -24), comp0, 11, Color(1.0, 0.78, 0.4), 90.0)
		return
	_shadow(foot, 9.0)
	var rect := _draw_bottom(tex, foot, 0.0, 46.0, flip, mod)
	var key: String = r.most_urgent()
	if float(r.needs[key]) < Resident.URGENT:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
		draw_circle(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 2), 3.0, Color(1.0, 0.35, 0.35, pulse))
	if int(r.id) == selected_rid:
		_outlined(Vector2(rect.position.x + rect.size.x * 0.5 - 40, rect.position.y - 16), String(r.rname), 13, Color(1.0, 0.95, 0.7), 80.0)
	# 意见气泡（阶段 12）：需求低或缺设施时头顶显示短句。
	var comp := Game.complaint_text(int(r.id))
	if comp != "":
		_outlined(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 26), comp, 11, Color(1.0, 0.78, 0.4), 90.0)

func _draw_boss() -> void:
	if Game.boss.is_empty():
		return
	var idx := Game.index_of_bid(int(Game.boss.get("target_bid", -1)))
	if idx < 0:
		return
	var b: Dictionary = Game.buildings[idx]
	var fs := float(b["size"])
	var front := corner(float(b["gx"]) + fs, float(b["gy"]) + fs)
	var p := front + Vector2(0, 8.0 + sin(Time.get_ticks_msec() / 220.0) * 1.5)
	var boss_id := "hacker" if String(Game.boss.get("kind", "")) == "hack" else "berserk"
	var tex: Texture2D = _bank.bosses.get(boss_id, null)
	if tex == null:
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 140.0)
		draw_circle(p, 16.0, Color(1.0, 0.15, 0.25, 0.22 * pulse))
		draw_circle(p, 9.0, Color(0.35, 0.02, 0.06, 0.95))
		_outlined(p + Vector2(-70, -22), String(Game.boss["name"]), 14, Color(1.0, 0.55, 0.55), 140.0)
		return
	_shadow(p, 12.0)
	var rect := _draw_bottom(tex, p, 0.0, 62.0, false, Color.WHITE)
	_outlined(Vector2(rect.position.x + rect.size.x * 0.5 - 70, rect.position.y - 4), String(Game.boss["name"]), 14, Color(1.0, 0.55, 0.55), 140.0)

func _shadow(foot: Vector2, rx: float) -> void:
	var ry := rx * 0.38
	draw_colored_polygon(PackedVector2Array([
		foot + Vector2(-rx, 0),
		foot + Vector2(0, -ry),
		foot + Vector2(rx, 0),
		foot + Vector2(0, ry),
	]), Color(0, 0, 0, 0.35))

func _draw_bottom(tex: Texture2D, foot: Vector2, width: float, height: float, flip: bool, mod: Color) -> Rect2:
	var aspect := float(tex.get_width()) / float(tex.get_height())
	var h := height
	var w := width
	if w <= 0.0:
		w = h * aspect
	else:
		h = w / aspect
	var left := foot.x - w * 0.5
	var top := foot.y - h
	if flip:
		draw_texture_rect(tex, Rect2(left + w, top, -w, h), false, mod)
	else:
		draw_texture_rect(tex, Rect2(left, top, w, h), false, mod)
	return Rect2(left, top, w, h)

func _draw_hover() -> void:
	if demolish:
		var bid := Game.bid_at(hover)
		var idx := Game.index_of_bid(bid)
		if idx >= 0:
			var d := footprint(Game.buildings[idx])
			draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Color(1.0, 0.35, 0.4, 0.9), 3.0, true)
		return
	if road_mode:
		if hover.x >= 0 and hover.y >= 0 and Game.in_bounds(hover.x, hover.y):
			var ok: bool = Game.can_build_road(hover)
			var col := Color(0.35, 1.0, 0.6, 0.6) if ok else Color(1.0, 0.35, 0.4, 0.6)
			draw_polyline(cell_diamond(hover) + PackedVector2Array([cell_diamond(hover)[0]]), col, 2.5, true)
			draw_colored_polygon(cell_diamond(hover), Color(col.r, col.g, col.b, 0.25))
		return
	if clear_mode:
		if Game.is_ruin(hover):
			var ok: bool = Game.can_clear_ruin(hover)
			var col := Color(0.35, 1.0, 0.6, 0.6) if ok else Color(1.0, 0.35, 0.4, 0.6)
			draw_polyline(cell_diamond(hover) + PackedVector2Array([cell_diamond(hover)[0]]), col, 2.5, true)
			draw_colored_polygon(cell_diamond(hover), Color(col.r, col.g, col.b, 0.25))
		return
	if build_mode == "" or hover.x < 0 or hover.y < 0:
		return
	if hover.x >= Game.unlocked_w or hover.y >= Game.unlocked_h:
		return
	var f: Dictionary = ConfigDB.get_facility(build_mode)
	if f.is_empty():
		return
	var s := int(f["size"])
	var gx := clampi(hover.x, 0, Game.unlocked_w - s)
	var gy := clampi(hover.y, 0, Game.unlocked_h - s)
	var ok: bool = Game.can_build(build_mode, gx, gy)
	var col := Color(0.35, 1.0, 0.6, 0.55) if ok else Color(1.0, 0.35, 0.4, 0.55)
	var d := footprint({ "gx": gx, "gy": gy, "size": s })
	draw_colored_polygon(d, Color(col.r, col.g, col.b, 0.22))
	draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), col, 2.5, true)
	var ghost: Texture2D = _bank.building_tex(build_mode, build_rot)
	if ghost != null:
		var cover := 0.62 if s == 1 else 1.05
		var dest_w := float(s) * TW * cover
		var dest_h := dest_w * float(ghost.get_height()) / float(ghost.get_width())
		var c0 := corner(float(gx), float(gy))
		var c2 := corner(float(gx + s), float(gy + s))
		var foot := c2 if s >= 2 else (c0 + c2) * 0.5 + Vector2(0, 3.0)
		var tint := Color(1, 1, 1, 0.78) if ok else Color(1.0, 0.45, 0.45, 0.55)
		_draw_bottom(ghost, foot, dest_w, dest_h, false, tint)

func _draw_floaters() -> void:
	for f: Dictionary in _floaters:
		var a: float = clampf(float(f["life"]) / 1.1, 0.0, 1.0)
		_outlined(f["pos"], String(f["text"]), 17, Color(0.5, 1.0, 0.7, a), 120.0)

func _outlined(pos: Vector2, text: String, size: int, col: Color, width: float) -> void:
	var shadow := Color(0, 0, 0, col.a * 0.9)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(_font, pos + off, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, shadow)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)

func _on_payout(cell: Vector2, amount: int) -> void:
	var jitter_x := float(posmod(amount * 37, 46)) - 23.0
	var jitter_y := float(posmod(amount * 17, 14)) - 7.0
	_floaters.append({
		"pos": iso(cell) + Vector2(-60 + jitter_x, -70 + jitter_y),
		"text": "+€%d" % amount,
		"life": 1.1,
	})

func _update_hover() -> void:
	hover = cell_at_world(get_global_mouse_position())

func _pan_camera(delta: float) -> void:
	if camera == null:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		focus_left = 0.0
		camera.position += dir.normalized() * 520.0 * delta / camera.zoom.x
	_clamp_camera()

func _clamp_camera() -> void:
	var min_c := corner(0.0, float(Game.unlocked_h))
	var max_c := corner(float(Game.unlocked_w), 0.0)
	var pad := 220.0
	camera.position.x = clampf(camera.position.x, min_c.x - pad, max_c.x + pad)
	camera.position.y = clampf(camera.position.y, min_c.y - pad, max_c.y + pad + BUILD_H)

func _zoom(factor: float) -> void:
	if camera == null:
		return
	var z: float = clampf(camera.zoom.x * factor, 0.45, 2.4)
	camera.zoom = Vector2(z, z)

func _unhandled_input(event: InputEvent) -> void:
	if Game.at_menu:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / 1.1)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
			if mb.pressed:
				focus_left = 0.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_click()
		return
	if event is InputEventMouseMotion:
		if _dragging and camera != null:
			camera.position -= (event as InputEventMouseMotion).relative / camera.zoom
			_clamp_camera()
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		match ke.keycode:
			KEY_ESCAPE:
				build_mode = ""
				demolish = false
				road_mode = false
				clear_mode = false
				selected_bid = -1
				selected_rid = -1
				EventBus.notice.emit("已取消")
			KEY_Q, KEY_SPACE:
				Game.set_speed(0 if Game.speed > 0 else 1)
			KEY_1:
				Game.set_speed(1)
			KEY_2:
				Game.set_speed(2)
			KEY_3:
				Game.set_speed(3)
			KEY_R:
				if build_mode != "":
					rotate_build()

func rotate_build() -> void:
	build_rot = (build_rot + 1) % 4
	EventBus.notice.emit("朝向 %d/4 · 再按 R 继续转" % [build_rot + 1])

func _click() -> void:
	var c := cell_at_world(get_global_mouse_position())
	if road_mode:
		if Game.build_road(c):
			EventBus.notice.emit("铺了一段路 · €%d" % Game.ROAD_COST)
		else:
			EventBus.notice.emit("这里铺不了路")
		return
	if clear_mode:
		if Game.clear_ruin(c):
			EventBus.notice.emit("废墟清理完毕 · €%d" % Game.RUIN_CLEAR_COST)
		else:
			EventBus.notice.emit("这里没有可清理的废墟")
		return
	if demolish:
		var di := Game.bid_at(c)
		if di >= 0:
			var dname := String(Game.buildings[Game.index_of_bid(di)]["name"])
			Game.remove_bid(di)
			if selected_bid == di:
				selected_bid = -1
			EventBus.notice.emit("已拆除「%s」，返还一半造价" % dname)
		return
	if build_mode != "":
		var f: Dictionary = ConfigDB.get_facility(build_mode)
		if f.is_empty():
			return
		var s := int(f["size"])
		var gx := clampi(c.x, 0, Game.unlocked_w - s)
		var gy := clampi(c.y, 0, Game.unlocked_h - s)
		if Game.build(build_mode, gx, gy, build_rot):
			EventBus.notice.emit("建成「%s」· 朝向 %d/4" % [String(f["name"]), build_rot + 1])
			_check_region_banner(gx, gy)
		elif Game.star < ConfigDB.star_requirement(build_mode):
			EventBus.notice.emit("还没解锁")
		elif Game.money < int(f["cost"]):
			EventBus.notice.emit("资金不足，需要 €%d" % int(f["cost"]))
		else:
			EventBus.notice.emit("这里放不下")
		return
	var bid := Game.bid_at(c)
	if bid >= 0:
		selected_bid = bid
		selected_rid = -1
		var b: Dictionary = Game.buildings[Game.index_of_bid(bid)]
		var state := ""
		if bool(b.get("damaged", false)):
			state = " · 受损"
		elif Game.is_hacked(b):
			state = " · 停业"
		EventBus.notice.emit("%s · 这次消费 €%d%s" % [String(b["name"]), Game.estimate_income(Game.index_of_bid(bid)), state])
		return
	var hit = _resident_under_mouse()
	if hit != null:
		focus_on(int(hit.id))
		EventBus.notice.emit("%s · %s Lv%d · 战斗%d 黑客%d 社交%d" % [
			String(hit.rname), String(hit.job_name), int(hit.level),
			hit.power("combat"), hit.power("hack"), hit.power("social")])
		return
	selected_bid = -1
	selected_rid = -1

func _resident_under_mouse():
	var mp := get_global_mouse_position()
	var best = null
	var best_d := 22.0
	for r in Game.residents:
		if r.state == Resident.State.AWAY:
			continue
		var d: float = mp.distance_to(iso(r.pos) + Vector2(0, -8))
		if d < best_d:
			best_d = d
			best = r
	return best

func _check_region_banner(gx: int, gy: int) -> void:
	var idx := Game.index_of_bid(Game.bid_at(Vector2i(gx, gy)))
	if idx < 0:
		return
	var tier: Dictionary = Game.region_tier_for(idx)
	if int(tier["count"]) == 3:
		var b: Dictionary = Game.buildings[idx]
		EventBus.notice.emit("%s区连成 3 栋了，收入 ×%.1f" % [ConfigDB.theme_name(String(b["theme"])), float(tier["mult"])])
