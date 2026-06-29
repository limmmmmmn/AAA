extends Node
## Phase 2 — 중앙 스토리 스파인(core_*) 검증.
## 14노드 로드·경로잠금·지역 노드 구매가 단계를 여는지·해금 플래그.
## godot --headless --path . res://tests/CoreSpineTest.tscn

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

	# ── 1. 14 스파인 노드 로드 ──
	var ids: Array[StringName] = [
		&"core_start", &"core_first_gold", &"core_slime_contract", &"core_town_permit",
		&"core_multi_hint", &"core_meadow_boss", &"core_forest_path", &"core_quest_board",
		&"core_cave_map", &"core_airship_toy", &"core_castle_shadow", &"core_four_crystals",
		&"core_final_door", &"core_ending_machine"]
	var loaded := 0
	for id in ids:
		if _u(id) != null and _u(id).branch == "core":
			loaded += 1
	_check(loaded == 14, "core 스파인 14노드 로드 (%d)" % loaded)

	# ── 2. core_start = 트리 루트(부모 없음) + 비용 ──
	_check(_u(&"core_start").tree_links.is_empty(), "core_start는 루트(부모 링크 없음)")
	_check(_u(&"core_start").base_cost == 0, "core_start 무료")
	_check(_u(&"core_first_gold").base_cost == 4, "first_gold 4G")
	_check(_u(&"core_final_door").base_cost == 60000, "final_door 60000G")

	# ── 3. 경로 잠금: core_start 사기 전엔 first_gold 잠김 ──
	_check(GameState.node_unlocked(_u(&"core_start")), "core_start 해금됨(루트, 항상 구매가능)")
	_check(not GameState.node_unlocked(_u(&"core_first_gold")), "first_gold 잠김(core_start 선행)")
	GameState.gold = 100000
	GameState.purchase(_u(&"core_start"))
	_check(GameState.node_unlocked(_u(&"core_first_gold")), "core_start 구매 → first_gold 해금")
	_check(GameState.stat("adventure_started") == true, "core_start → 모험 시작 플래그")

	# ── 4. 스탯/플래그 효과 ──
	GameState.purchase(_u(&"core_first_gold"))
	_check(is_equal_approx(float(GameState.stat("all_gold_mult")), 1.1), "first_gold → 전체 골드 ×1.1")
	GameState.purchase(_u(&"core_town_permit"))
	_check(GameState.stat("village_tree_unlocked") == true, "town_permit → 마을 가지 해금 플래그")
	GameState.purchase(_u(&"core_multi_hint"))
	_check(GameState.stat("command_tree_unlocked") == true, "multi_hint → 지휘 가지 해금 플래그")
	GameState.purchase(_u(&"core_meadow_boss"))
	_check(GameState.stat("meadow_boss_cleared") == true, "meadow_boss → 보스 처치 플래그")

	# ── 5. 지역 노드 구매 = 지역 "해금" (실제 이동은 마을 표지판에서 — v1) ──
	_check(GameState.region_number() == 1, "구매 전 = 초원(1)")
	var party0 := GameState.member_count()
	GameState.purchase(_u(&"core_forest_path"))
	_check(GameState.region_unlocked(&"stage_forest"), "forest_path 구매 → 숲길 이동 해금")
	_check(GameState.region_number() == 1, "구매만으론 이동 안 함 (아직 초원)")
	# 마을 밖에선 이동 거부, 마을 안에서만 이동
	GameState.party_in_town = false
	_check(not GameState.travel_to_region(&"stage_forest")["ok"], "마을 밖 → 이동 거부")
	_check(GameState.region_number() == 1, "거부되어 초원 유지")
	GameState.party_in_town = true
	_check(GameState.travel_to_region(&"stage_forest")["ok"], "마을 안 → 숲길로 이동")
	_check(GameState.current_region == &"stage_forest", "단계 = 숲길")
	_check(GameState.region_number() == 2, "단계 번호 2")
	_check(GameState.member_count() == party0 + 1, "숲길 도달 → 승려 합류")
	_check(GameState.stage_monster(&"near").id == &"snake", "숲길 근접존 = 독사")

	GameState.purchase(_u(&"core_quest_board"))
	_check(GameState.stat("quest_unlocked") == true, "quest_board → 퀘스트 해금 플래그")
	GameState.purchase(_u(&"core_cave_map"))
	_check(GameState.travel_to_region(&"stage_cave")["ok"] and GameState.region_number() == 3, "cave_map 해금+이동 → 동굴(3)")
	GameState.purchase(_u(&"core_castle_shadow"))
	_check(GameState.travel_to_region(&"stage_castle")["ok"] and GameState.region_number() == 4, "castle_shadow 해금+이동 → 마왕성 외곽(4)")
	GameState.purchase(_u(&"core_four_crystals"))
	_check(is_equal_approx(float(GameState.stat("boss_gold_mult")), 2.0), "four_crystals → 보스 골드 ×2")
	GameState.purchase(_u(&"core_final_door"))
	_check(GameState.travel_to_region(&"stage_final")["ok"] and GameState.region_number() == 5, "final_door 해금+이동 → 마왕성 정문(5)")
	GameState.purchase(_u(&"core_ending_machine"))
	_check(GameState.stat("ending_reached") == true, "ending_machine → 엔딩 플래그")

	# ── 6. unlock_region은 스탯 경고를 내지 않는다(match 처리) ──
	_check(not GameState.stats.has("unlock_region"), "unlock_region은 스탯 사전에 안 들어감")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
