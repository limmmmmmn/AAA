extends Node
## 동료 줄줄이 행군 시각 확인. godot --path . res://tests/FollowShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _companion(cid: StringName, tex: String) -> CompanionData:
	var c := CompanionData.new()
	c.id = cid
	c.sprite = load(tex)
	return c


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	# 깔끔한 샷을 위해 필드 몬스터 제거 (인카운트로 멈추지 않게)
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	var party: Node2D = get_tree().get_first_node_in_group("party")
	GameState.add_companion(_companion(&"s1", "res://assets/characters/priest.png"))
	GameState.add_companion(_companion(&"s2", "res://assets/characters/knight.png"))
	GameState.add_companion(_companion(&"s3", "res://assets/characters/mage.png"))
	party.global_position = Vector2(300, 620) # 건물 없는 가로 레인
	party._refresh_companions()
	# 오른쪽으로 직선 행군 → 동료가 용사 왼쪽으로 줄지어 따라온다
	for i in 58:
		party.global_position += Vector2(6, 0)
		await get_tree().physics_frame
	# 카메라 스무딩이 따라잡도록 잠시 대기
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_follow.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
