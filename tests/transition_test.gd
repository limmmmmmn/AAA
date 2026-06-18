extends Node
## B-1 지역 전환 + 동료 합류 + 패배/부활 통합 검증.
## godot --headless --path . res://tests/TransitionTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _current_region() -> RegionBase:
	return get_tree().get_first_node_in_group("field")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# 시작: 1지역, 데미지 on(1지역부터), 용사 솔로
	_check(GameState.current_region == &"region1", "시작 지역 = region1")
	_check(_current_region().region_id() == &"region1", "현재 지역 노드 = region1")
	_check(GameState.damage_enabled, "1지역부터 데미지 on")
	_check(GameState.party_members().size() == 1, "1지역 파티 1인")

	# 통행료 지불 → 2지역 전환
	GameState.add_gold(600)
	var gate := _current_region().get_node("BridgeGate")
	gate._on_confirmed()
	await get_tree().create_timer(1.4).timeout  # 페이드 + 스왑 + 페이드

	_check(GameState.current_region == &"region2", "전환 후 지역 = region2")
	_check(_current_region().region_id() == &"region2", "현재 지역 노드 = region2")
	_check(GameState.damage_enabled, "2지역 데미지 on")
	_check(GameState.party_members().size() == 2, "승려 합류 → 파티 2인")
	_check(GameState.party_attack == 3 + 4, "승려 공격 보너스 +4 합산")
	var party: Node2D = get_tree().get_first_node_in_group("party")
	_check(party.global_position.y < 200, "파티가 북쪽 입구에 배치됨 (y=%d)" % int(party.global_position.y))

	# 2지역: 시작 시 독사존만 활성
	await get_tree().process_frame
	var snakes := 0
	for m: Node2D in get_tree().get_nodes_in_group("monsters"):
		if m.data and m.data.id == &"snake":
			snakes += 1
	_check(snakes > 0, "2지역 독사존 활성 (%d마리)" % snakes)

	# 패배 → 교회 부활 (전원 KO)
	GameState.gold = 80
	for i in GameState.member_count():
		GameState.member_hps[i] = 0
	GameState.member_hps[0] = 1
	GameState.apply_damage(99)  # 마지막 멤버 KO → party_defeated
	await get_tree().create_timer(2.4).timeout  # 사망 연출 + 부활

	_check(GameState.gold == 40, "패배: 소지금 절반 (80→40)")
	_check(GameState.total_hp() == GameState.total_max_hp(), "부활: 전량 회복")
	var church := _current_region().entrance(&"church")
	var p2: Node2D = get_tree().get_first_node_in_group("party")
	_check(p2.global_position.distance_to(church) < 2.0, "교회 부활 지점에 배치됨")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
