extends Node
## 시각 검증: 상점 트리에 트링켓 가지(trk_*)가 좌하단으로 뻗고, 스타터가 장착되는지.
## 렌더링 필요 — godot --path . res://tests/TrinketTreeShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	GameState.gold = 99999999
	for id in [&"core_start", &"core_first_gold", &"core_slime_contract", &"core_multi_hint",
			&"cmd_recruit_warrior", &"cmd_auto_loot", &"cmd_battle_queue", &"cmd_window_2",
			&"trk_unlock", &"trk_drop_slime", &"trk_boss_guarantee", &"trk_slot_2", &"trk_reroll_shop"]:
		GameState.purchase(GameState.catalog[id])
	GameState.gold = 99999999

	EventBus.request_shop.emit()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_trinket_tree.png"))
	print("SHOT trinket_tree — 도감 %d, 장착 %s, 슬롯 %d" % [
		GameState.owned_trinkets.size(), str(GameState.equipped_trinkets), GameState.trinket_slots()])
	get_tree().quit()
