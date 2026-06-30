extends Node
## 필드 적과 전투창 적 일치: 필드에 보이는 적 = 무리의 대표(가장 강한 적),
## 접촉 시 그 무리 그대로 전투. godot --headless --path . res://tests/FieldMatchTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	GameState.reset_to_new_game()

	# ── 1. 강함 점수 / 대표 선정 ──
	var slime: MonsterData = GameState.monster_by_id(&"slime")
	var rabbit: MonsterData = GameState.monster_by_id(&"horn_rabbit")
	var king: MonsterData = GameState.monster_by_id(&"king_slime")
	_check(GameState.strongest_of([slime, slime]) == slime, "슬라임만 → 대표 슬라임")
	_check(GameState.strongest_of([slime, rabbit]) == rabbit, "슬라임+토끼 → 대표 토끼(더 강함)")
	_check(GameState.strongest_of([slime, king, rabbit]) == king, "보스 섞이면 → 대표 보스(킹슬라임)")
	_check(GameState.strongest_of([]) == null, "빈 무리 → null")

	# ── 2. 필드 스폰: 대표 == 무리 최강, 대표가 무리에 포함 ──
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var monsters := get_tree().get_nodes_in_group("monsters")
	_check(monsters.size() > 0, "필드 몬스터 스폰 (%d)" % monsters.size())
	var with_formation := 0
	var rep_ok := 0
	var in_group := 0
	for m: Variant in monsters:
		if m.formation.is_empty():
			continue
		with_formation += 1
		var datas: Array = m.formation.get("datas", [])
		if m.data == GameState.strongest_of(datas):
			rep_ok += 1
		if m.data in datas:
			in_group += 1
	_check(with_formation > 0, "포메이션 보유 필드 몬스터 존재 (%d)" % with_formation)
	_check(rep_ok == with_formation, "필드 대표 == 무리 최강 (%d/%d)" % [rep_ok, with_formation])
	_check(in_group == with_formation, "필드 대표가 그 무리에 포함 (%d/%d)" % [in_group, with_formation])

	# ── 3. 접촉 전투가 저장된 무리를 그대로 쓴다 (대표 무관 재추첨 X) ──
	var sample: Variant = null
	for m: Variant in monsters:
		if not m.formation.is_empty():
			sample = m
			break
	if sample != null:
		var expected: Array = sample.formation.get("datas", [])
		var party: Node = get_tree().get_first_node_in_group("party")
		party._start_encounter(sample)
		await get_tree().process_frame
		var battles := BattleManager.active_battles
		_check(battles.size() == 1, "전투 1개 시작")
		if battles.size() == 1:
			var fought: Array = battles[0].enemies
			_check(fought.size() == expected.size(), "전투 적 수 == 저장 무리 (%d==%d)" % [fought.size(), expected.size()])
			# 전투의 적들이 저장 무리와 동일 (필드에 보인 그대로)
			var same := fought.size() == expected.size()
			for i in mini(fought.size(), expected.size()):
				if fought[i].data != expected[i]:
					same = false
			_check(same, "전투 적 == 필드에서 본 무리")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
