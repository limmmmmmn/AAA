extends Node
## 새 UI 시각 확인. godot --path . res://tests/UIShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout

	# 동료 합류 + 자동화/삽/원격상점 해금 → 우측 슬롯 다 보이게
	var priest: CompanionData = GameState.companion_catalog.get(&"priest")
	if priest:
		GameState.add_companion(priest)
	GameState.gold = 360
	GameState.gems = 2
	GameState.auto_enhance = true
	GameState.set_hunted(&"slime", true)
	GameState.recalculate_stats()
	EventBus.stats_changed.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://ui_field.png"))

	# MONSTERS 패널
	EventBus.request_monsters.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://ui_monsters.png"))
	EventBus.request_close_modals.emit()

	# 상점 패널 (검정 JRPG 리스트)
	GameState.set_region(&"stage_forest") # 2단계 상점 = 더 많은 아이템
	EventBus.request_shop.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://ui_shop.png"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
