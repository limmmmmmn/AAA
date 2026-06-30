extends Node
## 시각 검증: 레거시 NPC 제거 후 마을 — 촌장(=지역 이동 표지판)이 상점 건물과 분리되어 있다.
## 렌더링 필요 — godot --path . res://tests/VillageLayoutShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	GameState.gold = 99999999
	GameState.purchase(GameState.catalog[&"core_start"])
	GameState.purchase(GameState.catalog[&"core_forest_path"]) # 숲길 해금 (이동 가능)

	var party: Node2D = get_tree().get_first_node_in_group("party")
	party.global_position = Vector2(431, 470) # 촌장 바로 아래
	for i in 10:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_village_layout.png"))
	var field: Node = get_tree().get_first_node_in_group("field")
	print("SHOT village — ElderNPC=%s RecruitNPC=%s BridgeGate=%s 마을안=%s" % [
		field.find_child("ElderNPC", true, false) != null,
		field.find_child("RecruitNPC", true, false) != null,
		field.find_child("BridgeGate", true, false) != null,
		GameState.party_in_town])
	get_tree().quit()
