extends Node2D
## 场景装配：把 World / Camera / HUD 接起来

var world
var camera: Camera2D
var hud

func _ready() -> void:
	world = get_node("World")
	camera = get_node("Camera2D")
	hud = get_node("UI/HUD")
	world.camera = camera
	hud.view = world
	hud.visible = false
	var center: Vector2 = world.iso(Vector2(Game.GW * 0.5, Game.GH * 0.5))
	camera.position = Vector2(center.x - 24.0, center.y + 46.0)
	camera.zoom = Vector2(0.88, 0.88)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	var menu = preload("res://scripts/ui/main_menu.gd").new()
	menu.hud = hud
	get_node("UI").add_child(menu)
