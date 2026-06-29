extends Node
## 시각 검증: 같은 1지역 맵에서 단계만 바뀌며 적/틴트가 교체되는지 스크린샷.
## 렌더링 필요 — godot --path . res://tests/StageShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	var party: Node2D = get_tree().get_first_node_in_group("party")
	party.global_position = Vector2(640, 500) # 마을 + 근접존 적이 함께 보이게

	await _settle()
	await _shot("stage1_meadow") # 슬라임 + 흰색
	GameState.advance_stage()    # → 숲길
	await _settle()
	await _shot("stage2_forest") # 독사 + 초록 틴트
	GameState.advance_stage()    # → 동굴
	await _settle()
	await _shot("stage3_cave")   # 들개/오크 + 파랑 틴트

	get_tree().quit()


func _settle() -> void:
	# 단계 전환 후 deferred 스폰 + 몇 프레임 정착 대기
	for i in 8:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://shot_%s.png" % name))
	var near := GameState.stage_monster(&"near")
	print("SHOT %s — 근접존=%s, 틴트=%s" % [name, near.display_name if near else "?", GameState.current_stage().tile_tint])
