extends Node
## R2 — 4인 파티(용사/전사/마법사/힐러) + 파티 노드 + 마법사 광역 검증.
## godot --headless --path . res://tests/PartyTest.tscn

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _u(id: StringName) -> UpgradeData:
	return GameState.catalog.get(id)


func _ready() -> void:
	GameState.reset_to_new_game()
	GameState.current_region = &"stage_meadow"
	GameState.gold = 9999999
	GameState.purchase(GameState.catalog[&"core_start"]) # 루트(모험의 시작) — 파티 가지 선행

	# ── 1. 마법사 동료 + 파티 노드 로드 ──
	_check(GameState.companion_catalog.has(&"mage"), "마법사 동료 로드")
	var ids: Array[StringName] = [&"party_warrior_join", &"party_formation_2", &"party_mage_join",
		&"party_aoe_lesson", &"party_healer_join", &"party_status_care", &"party_full_formation", &"party_auto_roles"]
	var loaded := 0
	for id in ids:
		if _u(id) != null and _u(id).branch == "party":
			loaded += 1
	_check(loaded == 8, "파티 8노드 로드 (%d)" % loaded)

	# ── 2. 영입 조건: 전사는 초원 8킬 전 잠김 ──
	_check(not GameState.node_unlocked(_u(&"party_warrior_join")), "전사 영입 = 8킬 전 잠김(unlock 조건)")
	for i in 8:
		GameState.add_region_kill(&"stage_meadow")
	_check(GameState.node_unlocked(_u(&"party_warrior_join")), "8킬 후 → 전사 영입 해금")

	# ── 3. 4인 파티 합류 ──
	_check(GameState.member_count() == 1, "시작 = 용사 1인")
	GameState.purchase(_u(&"party_warrior_join"))
	_check(GameState.has_companion(&"knight") and GameState.member_count() == 2, "전사 합류 → 2인")
	GameState.add_survey(&"stage_meadow", 0.4)
	GameState.purchase(_u(&"party_mage_join"))
	_check(GameState.has_companion(&"mage") and GameState.member_count() == 3, "마법사 합류 → 3인")
	for i in 30:
		GameState.add_region_kill(&"stage_meadow")
	GameState.purchase(_u(&"party_healer_join"))
	_check(GameState.has_companion(&"priest") and GameState.member_count() == 4, "힐러 합류 → 4인")

	# ── 4. 최대 4명 상한 ──
	GameState.add_companion(GameState.companion_catalog[&"knight"]) # 이미 있음/상한
	_check(GameState.member_count() == 4, "파티 4명 상한 유지")

	# ── 5. 멤버 역할 ──
	_check(GameState.member_role(0) == &"hero", "0번 = 용사")
	var has_mage_member := false
	for i in GameState.member_count():
		if GameState.member_role(i) == &"mage":
			has_mage_member = true
	_check(has_mage_member, "파티에 마법사 역할 존재")

	# ── 6. party_hp_mult → 멤버 HP +10% ──
	var hp_before := GameState.member_max_hp_for(0)
	GameState.purchase(_u(&"party_formation_2")) # 파티 HP ×1.1
	_check(GameState.member_max_hp_for(0) == int(round(hp_before * 1.1)), "둘이서 서기 → 용사 HP ×1.1")

	# ── 7. party_full_formation → 파티 피해 +15% ──
	var pa_before := GameState.hero_attack
	GameState.purchase(_u(&"party_full_formation"))
	_check(GameState.hero_attack == int(round(pa_before * 1.15)), "네 명이 한 줄로 → 파티 피해 ×1.15")
	_check(GameState.stat("full_party_unlocked") == true, "풀파티 플래그")

	# ── 8. 마법사 광역: 앞이 아닌 적도 피해 ──
	GameState.purchase(_u(&"party_aoe_lesson")) # mage_aoe_enabled
	_check(GameState.stat("mage_aoe_enabled") == true, "광역 주문 해금")
	var slime: MonsterData = GameState.monster_by_id(&"slime")
	var battle := BattleInstance.new([slime, slime])
	# 여러 라운드 틱 → 마법사가 모든 적을 친다 (뒤 적도 피해)
	for i in 30:
		if battle.is_finished:
			break
		battle.tick(0.5)
	var back_damaged: bool = int(battle.enemies[1].hp) < slime.max_hp
	_check(back_damaged, "마법사 광역 → 뒤 적도 피해 (HP %d/%d)" % [battle.enemies[1].hp, slime.max_hp])

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
