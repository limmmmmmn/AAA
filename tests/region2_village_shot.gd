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
	for id in [&"pot_unlock", &"pot_count", &"pot_count", &"pot_count",
			&"chest_unlock", &"chest_count", &"chest_count", &"bonfire", &"inn_unlock"]:
		GameState.purchase(GameState.catalog[id])

	# 2지역으로 전환 (다리 통과)
	GameState.gold = 99999
	var field: Node = get_tree().get_first_node_in_group("field")
	field.get_node("BridgeGate")._on_confirmed()
	await get_tree().create_timer(1.6).timeout

	# 2지역 마을(남쪽)로 파티 이동 후 캡처
	var party: Node2D = get_tree().get_first_node_in_group("party")
	party.global_position = Vector2(336, 1060)
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_region2_village.png"))

	GameState.reset_to_new_game()
	get_tree().quit()
