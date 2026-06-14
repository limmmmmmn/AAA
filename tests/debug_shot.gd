extends Node
## 디버그 모드 메뉴 토글 + 골드 [+100] 힌트 시각 확인. godot --path . res://tests/DebugShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	GameState.add_gold(250)
	GameState.set_debug_mode(true) # 골드 라벨에 [+100] 힌트
	EventBus.request_menu.emit()    # 메뉴 열기 (디버그 토글 ON 상태로 보임)
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_debug.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
