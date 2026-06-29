extends Node
## A-5(마을 안전지대) / A-6(게이트 → 동료 합류 컷) 동작 검증.
## godot --headless --path . res://tests/BehaviorTest.tscn

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

	# A-5: 마을 안전지대 판정 (칠한 맵엔 village 타일이 없어 마을 영역으로 정의)
	_check(field.is_village(field.home_point), "마을 중앙 = 안전지대")
	_check(not field.is_village(Vector2(120, 200)), "외곽은 안전지대 아님")

	# A-6: 지역 노드 구매 전 실루엣 상태
	var preview := field.get_node("CompanionPreview")
	var sprite: Sprite2D = preview.get_node("Sprite2D")
	var silhouette_tex := sprite.texture
	_check(GameState.companions.is_empty(), "초기: 동료 없음(실루엣)")

	# 숲길 지역 노드 구매 → 단계 전환 + 승려 합류 컷
	GameState.gold = 1000
	var joined := [false]
	EventBus.companion_joined.connect(func(_c: CompanionData) -> void: joined[0] = true)
	GameState.purchase(GameState.catalog[&"core_forest_path"]) # 숲길 해금
	GameState.party_in_town = true
	GameState.travel_to_region(&"stage_forest") # 마을 표지판 이동 → 숲길 + 승려
	await get_tree().process_frame
	_check(GameState.current_region == &"stage_forest", "마을에서 이동 → 숲길")
	_check(joined[0], "승려 합류 시그널 발신")
	_check(sprite.texture != silhouette_tex, "동료 실루엣 → 컬러로 전환 (합류 컷)")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
