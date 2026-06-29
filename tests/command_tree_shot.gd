extends Node
## 시각 검증: (1) 동시 2개 전투창 가동(핵심 훅), (2) 상점에 지휘 가지(cmd_*).
## 렌더링 필요 — godot --path . res://tests/CommandTreeShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	GameState.gold = 9999999

	# 지휘 가지를 따라 구매 (전사 합류 + 전투창 2개 + 효율)
	for id in [&"core_start", &"core_slime_contract", &"core_multi_hint",
			&"cmd_recruit_warrior", &"cmd_auto_loot", &"cmd_battle_queue",
			&"cmd_window_2", &"cmd_window_train", &"cmd_healer"]:
		GameState.purchase(GameState.catalog[id])
	GameState.hero_attack = 1 # 전투가 잠깐 지속되게 (캡처용)

	# (1) 동시 2개 전투창 — BattleManager로 직접 2개 시작
	var slime: MonsterData = load("res://data/monsters/slime.tres")
	BattleManager.start_battle([slime])
	BattleManager.start_battle([slime])
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_multiwindow.png"))
	print("SHOT multiwindow — 활성 전투 %d, 전투창 한도 %d" % [
		BattleManager.active_battles.size(), GameState.max_battle_windows])

	# (2) 상점의 지휘 가지
	GameState.gold = 9999999
	EventBus.request_shop.emit()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_command_tree.png"))
	print("SHOT command_tree — 카탈로그 %d종" % GameState.catalog.size())
	get_tree().quit()
