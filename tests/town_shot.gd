extends Node
## 마을 오브젝트 + 대장간 UI 시각 확인. godot --path . res://tests/TownShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	# 마을 오브젝트(항아리·보물상자·대장간)가 보이는 시작 화면
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_town.png"))

	# 대장간 UI
	GameState.gold = 500
	GameState.gems = 1
	GameState.rusty_swords = 2
	GameState.add_material(&"stone", 8)
	GameState.add_material(&"enhance_stone", 1)
	GameState.forge_put_sword()
	GameState.forge_enhance()
	GameState.forge_enhance()
	GameState.forge_enhance()
	EventBus.request_forge.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_forge.png"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
