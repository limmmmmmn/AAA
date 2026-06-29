extends Node
## 자동 풀(GrassField): 칠한 풀 타일에 깔리고, 파티가 밟으면 눕었다가 다시 선다.
## godot --headless --path . res://tests/GrassPressTest.tscn

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
	var field: Node = get_tree().get_first_node_in_group("field")
	var party: Node2D = get_tree().get_first_node_in_group("party")
	var grass: Node2D = field.find_child("GrassField", false, false)

	_check(grass != null, "GrassField 자동 생성됨")
	var n: int = grass._sprites.size() if grass != null else 0
	print("  (풀 개수: %d)" % n)
	_check(n > 100, "칠한 풀 타일에 깔림(>100, 옛 160캡·top-load 버그 해소)")
	_check(grass != null and grass.y_sort_enabled, "GrassField y_sort 켜짐(캐릭터와 정렬)")
	_check(grass._tex_stand != null and grass._tex_pressed != null
		and grass._tex_stand != grass._tex_pressed, "grass_1(평소)/grass_2(밟힘) 로드됨")

	# 평소엔 grass_1
	var blade: Sprite2D = grass._sprites[0]
	var ground: Vector2 = grass._ground[0]
	_check(blade.texture == grass._tex_stand, "평소엔 grass_1(서있음)")
	# 정렬 키(position.y)가 땅 접점보다 위 = 발 기준 정렬(foot_lift 적용)
	_check(blade.position.y < ground.y, "정렬 키가 발 높이로 올라감(foot_lift)")

	# 풀 땅 위로 파티 → 밟으면 grass_2
	party.global_position = ground
	grass._process(0.0)
	_check(blade.texture == grass._tex_pressed, "파티가 밟으면 grass_2(눕힘)")

	# 멀리 가고 revert_delay 넘게 흐르면 → 다시 grass_1
	party.global_position = ground + Vector2(2000, 2000)
	grass._process(grass._revert + 0.1)
	_check(blade.texture == grass._tex_stand, "잠시 뒤 다시 grass_1(서있음)")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
