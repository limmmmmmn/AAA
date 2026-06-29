extends Node
## 시각 검증: 상점 트리에서 옛 검 노드 대신 새 전투 가지(cmb_*)가 오른쪽으로 뻗는지.
## 렌더링 필요 — godot --path . res://tests/CombatTreeShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	GameState.gold = 500000
	# core_start → 전투 가지를 따라 구매 (오른쪽으로 드러남)
	for id in [&"core_start", &"cmb_atk_1", &"cmb_hp_1", &"cmb_atk_2", &"cmb_auto_command",
			&"cmb_quick_swing", &"cmb_reward_study", &"cmb_skill_slash", &"cmb_combo", &"cmb_crit"]:
		GameState.purchase(GameState.catalog[id])
	GameState.gold = 500000

	EventBus.request_shop.emit()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_combat_tree.png"))
	print("SHOT combat_tree — 용사 공격력 %d, 카탈로그 %d종" % [GameState.hero_attack, GameState.catalog.size()])
	get_tree().quit()
