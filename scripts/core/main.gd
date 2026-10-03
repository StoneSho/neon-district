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
	var center: Vector2 = world.iso(Vector2(Game.unlocked_w * 0.5, Game.unlocked_h * 0.5))
	camera.position = Vector2(center.x - 24.0, center.y + 46.0)
	camera.zoom = Vector2(0.88, 0.88)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	# 自动化入口：--autostart 跳过主菜单直接开局（配合 --quit-after 空跑）；
	# --selftest 开局后跑断言并退出。正式游玩不受影响。
	var args := OS.get_cmdline_user_args()
	if "--autostart" in args or "--selftest" in args:
		Game.new_game()
		if "--selftest" in args:
			Game.selftest_stage2()
			Game.selftest_stage11()
			Game.selftest_stage4()
			Game.selftest_stage5()
			Game.selftest_stage6()
			Game.selftest_stage7()
			Game.selftest_stage8()
			Game.selftest_stage9()
			Game.selftest_stage10()
			Game.selftest_stage12()
			Game.selftest_buildings()
			Game.selftest_adverse()
			Game.selftest_tutorial()
			Game.selftest_achievements()
			Game.selftest_expand()
			get_tree().quit()
		return
	var menu = preload("res://scripts/ui/main_menu.gd").new()
	menu.hud = hud
	get_node("UI").add_child(menu)
