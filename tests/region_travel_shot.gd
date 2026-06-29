extends Node
## 시각 검증: 마을 표지판(지역 이동) + 이동 전후 필드 변화.
## 렌더링 필요 — godot --path . res://tests/RegionTravelShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	GameState.gold = 9999999
	GameState.purchase(GameState.catalog[&"core_start"])
	GameState.purchase(GameState.catalog[&"core_forest_path"]) # 숲길 해금

	var party: Node2D = get_tree().get_first_node_in_group("party")
	# 표지판(300,460) 옆으로 이동 → 근접 프롬프트
	party.global_position = Vector2(322, 460)
	for i in 8:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_signpost.png"))
	print("SHOT signpost — 마을 안=%s, 해금지역=%s" % [GameState.party_in_town, GameState.unlocked_regions])

	# 표지판에서 숲길로 이동 → 필드(틴트/적)만 바뀐다
	var r := GameState.travel_to_region(&"stage_forest")
	for i in 12:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_forest.png"))
	print("SHOT forest — 이동결과=%s, 현재=%s, 파티=%d명" % [r, GameState.current_region, GameState.member_count()])
	get_tree().quit()
