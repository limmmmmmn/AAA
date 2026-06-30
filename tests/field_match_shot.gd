extends Node
## 시각 검증: 필드 적(무리 대표=가장 강한 적)과 전투창 적이 일치한다.
## 렌더링 필요 — godot --path . res://tests/FieldMatchShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	GameState.gold = 99999999
	# 진행도를 올려 다양한 무리(혼합 포함) + 큰 무리 해금
	for mid in [&"slime", &"meadow_rat", &"horn_rabbit", &"grass_wasp", &"leaf_sprite"]:
		var m: MonsterData = GameState.monster_by_id(mid)
		if m != null:
			for i in 6:
				GameState.register_kill(m)
	GameState.add_survey(&"stage_meadow", 0.7)
	# 새 해금으로 필드 무리 다시 굴리기 (존이 region_changed에 재스폰)
	EventBus.region_changed.emit(GameState.current_region)
	for i in 8:
		await get_tree().physics_frame

	# 파티를 필드 가운데로
	var party: Node2D = get_tree().get_first_node_in_group("party")
	party.global_position = Vector2(820, 360)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_field_reps.png"))

	# 무리(2마리+) 대표를 골라 전투 시작 → 전투창과 비교
	var picked: Variant = null
	for m: Variant in get_tree().get_nodes_in_group("monsters"):
		if not m.formation.is_empty() and (m.formation.get("datas", []) as Array).size() >= 2:
			picked = m
			break
	if picked == null: # 혼합 무리가 없으면 아무거나
		for m: Variant in get_tree().get_nodes_in_group("monsters"):
			if not m.formation.is_empty():
				picked = m
				break
	var rep_name := "-"
	var grp := ""
	if picked != null:
		rep_name = picked.data.display_name
		for d: Variant in picked.formation.get("datas", []):
			grp += (d.display_name + " ")
		party._start_encounter(picked)
		for i in 6:
			await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_field_battle.png"))
	print("SHOT field — 대표=%s, 무리=[%s]" % [rep_name, grp.strip_edges()])
	get_tree().quit()
