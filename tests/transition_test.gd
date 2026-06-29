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

	# 시작: 1단계(초원), 데미지 on(1지역부터), 용사 솔로 — 맵은 1지역 하나
	_check(GameState.current_region == &"stage_meadow", "시작 단계 = 초원")
	_check(GameState.region_number() == 1, "단계 번호 1")
	_check(_current_region().region_id() == &"region1", "맵 노드는 항상 1지역(맵 1개)")
	_check(GameState.damage_enabled, "1지역부터 데미지 on")
	_check(GameState.party_members().size() == 1, "초원 파티 1인")

	# 지역 노드 구매 → 숲길로 진행 (맵 스왑 없음, 같은 맵에서 적/지역명만 바뀜)
	GameState.gold = 1000
	GameState.purchase(GameState.catalog[&"core_forest_path"]) # set_stage → stage_forest + 승려 합류
	await get_tree().process_frame

	_check(GameState.current_region == &"stage_forest", "지역 노드 구매 → 단계 = 숲길")
	_check(GameState.region_number() == 2, "단계 번호 2 (같은 맵)")
	_check(_current_region().region_id() == &"region1", "맵은 그대로 1지역")
	_check(GameState.damage_enabled, "데미지 on")
	_check(GameState.party_members().size() == 2, "승려 합류 → 파티 2인")
	_check(GameState.party_attack == 3 + 4, "승려 공격 보너스 +4 합산")

	# 단계 전환 → 근접존 적이 초원(슬라임)에서 숲길(독사)로 교체됨
	await get_tree().process_frame
	await get_tree().process_frame
	var snakes := 0
	var slimes := 0
	for m: Node2D in get_tree().get_nodes_in_group("monsters"):
		if m.data and m.data.id == &"snake":
			snakes += 1
		elif m.data and m.data.id == &"slime":
			slimes += 1
	_check(snakes > 0, "숲길 근접존 = 독사 (%d마리)" % snakes)
	_check(slimes == 0, "초원 슬라임은 전부 사라짐")

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
