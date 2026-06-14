extends Node
## 메뉴 UI + HUD 메뉴 버튼 시각 확인. godot --path . res://tests/MenuShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	# HUD 메뉴 버튼이 보이는 평상시 화면
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_hud_menu.png"))
	# 메뉴 열기
	EventBus.request_menu.emit()
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_menu.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
