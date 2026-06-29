extends Node
## 시각 검증: 전투창에 적 1마리가 아니라 무리(여러 종)가 나온다.
## 렌더링 필요 — godot --path . res://tests/FormationShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	var party: Node2D = get_tree().get_first_node_in_group("party")
	party.global_position = Vector2(640, 470)
	GameState.hero_attack = 1 # 전투가 잠깐 지속되게

	# 섞인 무리 직접 출현: 풀잎 정령 + 슬라임 + 들쥐 (3마리 인카운터)
	var datas := [
		GameState.monster_by_id(&"leaf_sprite"),
		GameState.monster_by_id(&"slime"),
		GameState.monster_by_id(&"meadow_rat")]
	BattleManager.start_battle(datas, party.global_position, &"meadow_sprite_guard")

	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_formation.png"))
	var b: BattleInstance = BattleManager.active_battles[0] if not BattleManager.active_battles.is_empty() else null
	print("SHOT formation — 적 %d마리" % (b.enemies.size() if b else 0))
	get_tree().quit()
