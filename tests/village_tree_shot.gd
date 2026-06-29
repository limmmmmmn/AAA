extends Node
## 시각 검증: 상점 트리에서 옛 항아리/상자/여관 대신 새 마을 가지(vlg_*)가 왼쪽으로 뻗는지.
## 렌더링 필요 — godot --path . res://tests/VillageTreeShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	GameState.gold = 9999999
	# core_town_permit → 마을 가지를 따라 구매 (왼쪽으로 드러남)
	for id in [&"core_start", &"core_first_gold", &"core_town_permit",
			&"vlg_pot_1", &"vlg_pot_plus", &"vlg_pot_gold_1", &"vlg_pot_respawn_1",
			&"vlg_pot_worker", &"vlg_crate", &"vlg_npc", &"vlg_shop", &"vlg_inn"]:
		GameState.purchase(GameState.catalog[id])
	GameState.gold = 9999999

	EventBus.request_shop.emit()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_village_tree.png"))
	print("SHOT village_tree — 항아리 %d개, 여관 %s, 카탈로그 %d종" % [
		GameState.pot_count, GameState.inn_unlocked, GameState.catalog.size()])
	get_tree().quit()
