extends Node
## 마을 오브젝트 + 대장간 UI 시각 확인. godot --path . res://tests/TownShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	# 마을 설치물 전부 해금/증설해서 보이게 (항아리 4, 보물상자 3, 모닥불)
	GameState.gold = 999999
	for id in [&"pot_unlock", &"pot_count", &"pot_count", &"pot_count",
			&"chest_unlock", &"chest_count", &"chest_count", &"bonfire"]:
		GameState.purchase(GameState.catalog[id])
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_town.png"))

	# 대장간 UI
	GameState.gems = 1
	GameState.rusty_swords = 2
	GameState.add_material(&"stone", 8)
	GameState.add_material(&"enhance_stone", 1)
	GameState.forge_put_sword()
	GameState.forge_enhance()
	EventBus.request_forge.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_forge.png"))

	GameState.reset_to_new_game() # 종료 자동저장 오염 방지
	get_tree().quit()
