extends Node
## 코드 엣지 블렌딩 확인용: 산맥 모서리 + 강 물가를 프레임에 담아 스크린샷.
const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var field: RegionBase = get_tree().get_first_node_in_group("field")
	var party := get_tree().get_first_node_in_group("party")

	# 북서쪽 산맥 모서리 (맵 좌상단 근처 풀밭)
	party.global_position = Vector2(170, 170)
	await get_tree().create_timer(0.4).timeout
	var img1 := get_viewport().get_texture().get_image()
	img1.save_png("user://screenshot_edge_mountain.png")

	# 남쪽 강가 + 다리 (다리 서쪽 물가)
	party.global_position = Vector2(560, field.map_size.y * 16 - 120)
	await get_tree().create_timer(0.4).timeout
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("user://screenshot_edge_water.png")

	get_tree().quit()
