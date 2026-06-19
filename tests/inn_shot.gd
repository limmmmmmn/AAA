extends Node
## 여관: 마을 등장 + 상점식 UI(잠자기) 시각 확인. godot --path . res://tests/InnShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var field: Node = get_tree().get_first_node_in_group("field")
	var inn: Node = field.find_child("InnBuilding", true, false)

	GameState.gold = 240
	GameState.purchase(GameState.catalog[&"inn_unlock"])
	GameState.damage_member(0, 22) # 부상 → 잠자기 활성
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_inn_field.png"))

	# UI 열기
	EventBus.request_inn.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_inn_ui.png"))

	GameState.reset_to_new_game()
	get_tree().quit()
