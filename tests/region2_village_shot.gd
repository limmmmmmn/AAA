extends Node
## 2지역 마을에 1지역 해금 건물(항아리·상자·대장간·영입·모닥불)이 그대로 이어지는지 시각 확인.
## godot --path . res://tests/Region2VillageShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	# 1지역에서 마을 건물 해금/증설
	GameState.gold = 99999
	for id in [&"vlg_pot_1", &"vlg_pot_plus", &"vlg_big_pot",
			&"vlg_chest", &"vlg_inn"]:
		GameState.purchase(GameState.catalog[id])

	# 숲길로 전환 (지역 노드 구매 — 맵은 그대로, 적/틴트만 바뀜)
	GameState.gold = 99999
	GameState.purchase(GameState.catalog[&"core_forest_path"])
	var field: RegionBase = get_tree().get_first_node_in_group("field")
	await get_tree().create_timer(0.7).timeout

	# 마을(건물 모인 곳)로 파티 이동 후 캡처
	var party: Node2D = get_tree().get_first_node_in_group("party")
	party.global_position = field.home_point
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_region2_village.png"))

	GameState.reset_to_new_game()
	get_tree().quit()
