extends Node
## 땅파기 시각 확인: 삽 구매 → HUD 땅파기 버튼 + 상점 삽/좋은 삽/꼬마돼지.
## godot --path . res://tests/DigShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout

	# 삽 + 꼬마돼지 → 맵 랜덤 위치에 반짝이는 땅 등장 (_tick_sparkle이 띄움)
	GameState.gold = 5000
	GameState.purchase(GameState.catalog[&"shovel"])
	GameState.purchase(GameState.catalog[&"pig_companion"])
	GameState.dig_ready_at = 0.0
	await get_tree().create_timer(0.4).timeout
	GameState.party_on_sparkle = true # 그 위에 서 있다고 가정 → 버튼 강조 (스크린샷용)
	EventBus.dig_changed.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_dig_hud.png"))

	# 상점 열어 삽 계열 노출 확인
	EventBus.party_entered_village.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_dig_shop.png"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
