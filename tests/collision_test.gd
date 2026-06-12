extends Node
## 몬스터가 물/산 타일을 넘지 못하는지 검증.
## godot --headless --path . res://tests/CollisionTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var field: RegionBase = get_tree().get_first_node_in_group("field")

	# is_walkable 기본 판정
	_check(field.is_walkable(field.village_center * 32), "마을 중앙은 통행 가능")
	_check(not field.is_walkable(Vector2(field.map_size.x * 32 - 16, 200)), "동쪽 산맥은 막힘")
	_check(not field.is_walkable(Vector2(700, field.map_size.y * 32 - 16)), "남쪽 강은 막힘")
	_check(field.is_walkable(Vector2(field.bridge_x * 32 + 16, field.map_size.y * 32 - 64)), "다리는 통행 가능")

	# 메탈슬라임을 강 쪽으로 200스텝 밀어붙여도 물 위로 못 감
	var ms_scene := load("res://scenes/field/Monster.tscn")
	var ms = ms_scene.instantiate()
	ms.data = load("res://data/monsters/metal_slime.tres")
	ms.position = Vector2(700, field.map_size.y * 32 - 96) # 강 바로 위
	field.add_child(ms)
	await get_tree().process_frame
	var escaped := false
	for i in 240:
		# 강(아래) 방향으로 강제 이동 시도
		var ok = ms._move_blocked(Vector2(0, 6))
		if not field.is_walkable(ms.global_position):
			escaped = true
			break
	_check(not escaped, "메탈슬라임이 강을 넘지 못함 (최종 y=%d)" % int(ms.global_position.y))

	# 산맥(동쪽)으로도 밀어붙이기
	ms.global_position = Vector2(field.map_size.x * 32 - 96, 400)
	var escaped_x := false
	for i in 240:
		ms._move_blocked(Vector2(6, 0))
		if not field.is_walkable(ms.global_position):
			escaped_x = true
			break
	_check(not escaped_x, "메탈슬라임이 산맥을 넘지 못함 (최종 x=%d)" % int(ms.global_position.x))

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
