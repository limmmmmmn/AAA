extends Node
## 몹 바글바글 + 이름 숨김 + 깔끔한 쿨타임 시각 확인. godot --path . res://tests/HordeShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	GameState.gold = 999999
	# 몹 증식 6번 → 슬라임존 6 → 12마리 바글바글
	for i in 6:
		GameState.purchase(GameState.catalog[&"horde"])
	# 항아리 설치 후 깨서 쿨타임("10s" 형태) 표시
	GameState.purchase(GameState.catalog[&"pot_unlock"])
	GameState.purchase(GameState.catalog[&"bonfire"])
	GameState.break_pot(0)
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_horde.png"))

	GameState.reset_to_new_game()
	get_tree().quit()
