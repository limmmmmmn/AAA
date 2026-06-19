extends Node
## 자동이동 버튼 등장 비교: 스킬 전(없음) → 스킬 후(등장). godot --path . res://tests/AutoBtnShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_autobtn_before.png"))

	# 자동이동 스킬 해금 → 버튼 등장 + 켜둠(초록)
	GameState.gold = 9999
	GameState.purchase(GameState.catalog[&"compass_hunt"])
	var hud: Node = main.find_child("HUD", true, false)
	hud._toggle_auto() # ON (초록)
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_autobtn_after.png"))

	GameState.reset_to_new_game()
	get_tree().quit()
