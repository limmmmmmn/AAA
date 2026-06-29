extends Node
## 시각 검증: 상점 패시브 트리에 새 중앙 스토리 스파인(core_*)이 위로 뻗는지.
## 렌더링 필요 — godot --path . res://tests/CoreSpineShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	GameState.gold = 500000

	# 스파인을 따라 구매 → 위로 해금되며 드러난다 (지역 노드는 단계도 전진)
	for id in [&"core_start", &"core_first_gold", &"core_slime_contract", &"core_town_permit",
			&"core_multi_hint", &"core_meadow_boss", &"core_forest_path", &"core_quest_board",
			&"core_cave_map"]:
		GameState.purchase(GameState.catalog[id])
	GameState.gold = 500000

	EventBus.request_shop.emit()
	await get_tree().create_timer(1.4).timeout # 등장 애니 정착
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_core_spine.png"))
	print("SHOT core_spine — 단계=%d(%s)" % [GameState.region_number(), GameState.stage_name()])
	get_tree().quit()
