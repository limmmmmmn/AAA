extends Node
## 동료 줄줄이 따라오기 + 전투창 만석 이동정지 검증.
## godot --headless --path . res://tests/PartyMoveTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _make_companion(cid: StringName) -> CompanionData:
	var c := CompanionData.new()
	c.id = cid
	c.display_name = String(cid)
	c.sprite = load("res://assets/priest.svg")
	return c


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var party: Node2D = get_tree().get_first_node_in_group("party")
	var slime: MonsterData = load("res://data/monsters/slime.tres")

	# ── 전투창 만석 이동정지 ──
	# 1지역 기본 max=1 → 한 전투만 떠도 만석
	GameState.max_battle_windows = 1 # 결정적 검증 (세이브 잔여 영향 배제)
	var b1 := BattleManager.start_battle([slime])
	_check(b1 != null and party._movement_locked(), "전투창 1칸 만석 → 이동 정지")
	BattleManager.abort_all()
	_check(not party._movement_locked(), "전투 종료 → 이동 가능")

	# 멀티창 2칸: 1개 떠 있을 땐 이동, 2개 차면 정지
	GameState.max_battle_windows = 2
	_check(not party._movement_locked(), "2칸 비었음 → 이동 가능")
	BattleManager.start_battle([slime])
	_check(not party._movement_locked(), "2칸 중 1개 → 이동 가능")
	BattleManager.start_battle([slime])
	_check(party._movement_locked(), "2칸 만석(2개) → 이동 정지")
	BattleManager.abort_all()

	# ── 동료 줄줄이 따라오기 ──
	GameState.add_companion(_make_companion(&"d1"))
	GameState.add_companion(_make_companion(&"d2"))
	_check(party._companion_sprites.size() == 2, "동료 2명 필드 스프라이트 생성")

	# 용사를 오른쪽으로 직선 행군시킨다 (수동으로 위치를 옮겨 경로를 쌓는다)
	party.global_position = Vector2(720, 400)
	party._refresh_companions() # 머리에 모은 뒤 출발
	for i in 70:
		party.global_position += Vector2(5, 0)
		await get_tree().physics_frame

	var head := party.global_position
	var c0: Vector2 = party._companion_sprites[0].global_position
	var c1: Vector2 = party._companion_sprites[1].global_position
	var gap: float = party.follow_gap
	# 직선 행군이므로 동료는 용사 왼쪽(뒤)으로 gap, 2*gap 만큼 떨어져 한 줄로 선다
	_check(absf((head.x - c0.x) - gap) < 4.0, "동료1이 용사 뒤 %.0fpx (실제 %.1f)" % [gap, head.x - c0.x])
	_check(absf((head.x - c1.x) - 2.0 * gap) < 5.0, "동료2가 용사 뒤 %.0fpx (실제 %.1f)" % [2.0 * gap, head.x - c1.x])
	_check(absf(c0.y - head.y) < 3.0 and absf(c1.y - head.y) < 3.0, "동료들이 같은 행렬(y) 위에 정렬")
	_check(c0.x > c1.x, "동료 순서: 용사 — 동료1 — 동료2")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
