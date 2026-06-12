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

	# A-5: 마을 타일 판정
	_check(field.is_village(Vector2(field.village_center.x * 32, field.village_center.y * 32)), "마을 중앙 = 안전지대")
	_check(not field.is_village(Vector2(120, 200)), "외곽은 안전지대 아님")

	# A-6: 게이트 통과 전 실루엣 상태
	var preview := field.get_node("CompanionPreview")
	var sprite: Sprite2D = preview.get_node("Sprite2D")
	var silhouette_tex := sprite.texture
	_check(not GameState.gate_paid, "초기: 게이트 미지불")

	# 통행료 지불 시뮬레이션 → 합류 컷
	GameState.add_gold(600)
	var gate := field.get_node("BridgeGate")
	var unlocked := [false]
	EventBus.gate_unlocked.connect(func(_id: StringName) -> void: unlocked[0] = true)
	gate._on_confirmed()  # 확인 팝업 수락과 동일
	await get_tree().process_frame
	_check(GameState.gate_paid, "통행료 지불 → gate_paid")
	_check(unlocked[0], "gate_unlocked 시그널 발신")
	_check(sprite.texture != silhouette_tex, "동료 실루엣 → 컬러로 전환 (합류 컷)")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
