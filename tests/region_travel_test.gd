extends Node
## R3 — 지역 이동 마을-게이트화 + 예약 이동 검증.
## godot --headless --path . res://tests/RegionTravelTest.tscn

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	GameState.reset_to_new_game()
	GameState.gold = 9999999
	GameState.purchase(GameState.catalog[&"core_start"])

	# ── 1. 시작: 초원만 이동 가능 ──
	_check(GameState.region_unlocked(&"stage_meadow"), "시작 = 초원 이동 가능")
	_check(not GameState.region_unlocked(&"stage_forest"), "숲길은 아직 잠김")
	_check(GameState.unlocked_regions.size() == 1, "해금 지역 1개")

	# ── 2. 지역 노드 구매 = 해금만(이동 X) ──
	GameState.purchase(GameState.catalog[&"core_forest_path"])
	_check(GameState.region_unlocked(&"stage_forest"), "forest_path 구매 → 숲길 해금")
	_check(GameState.current_region == &"stage_meadow", "구매만으론 이동 안 함")

	# ── 3. 마을 밖 → 이동 거부 ──
	GameState.party_in_town = false
	var r1 := GameState.travel_to_region(&"stage_forest")
	_check(not r1["ok"] and String(r1["msg"]).contains("마을"), "마을 밖 → 거부 (마을 안내 메시지)")
	_check(GameState.current_region == &"stage_meadow", "거부되어 초원 유지")

	# ── 4. 안 해금된 지역 → 거부 ──
	var r2 := GameState.travel_to_region(&"stage_cave")
	_check(not r2["ok"], "해금 안 된 동굴 → 거부")

	# ── 5. 마을 안 → 이동 성공 (+ 승려 합류) ──
	var party0 := GameState.member_count()
	GameState.party_in_town = true
	var r3 := GameState.travel_to_region(&"stage_forest")
	_check(r3["ok"], "마을 안 → 숲길 이동 성공")
	_check(GameState.current_region == &"stage_forest", "단계 = 숲길")
	_check(GameState.member_count() == party0 + 1, "숲길 도달 → 승려 합류")

	# ── 6. 같은 지역 → 거부 ──
	var r4 := GameState.travel_to_region(&"stage_forest")
	_check(not r4["ok"], "이미 그 지역 → 거부")

	# ── 7. 되돌아가기(초원)도 마을 안이면 가능 ──
	var r5 := GameState.travel_to_region(&"stage_meadow")
	_check(r5["ok"] and GameState.current_region == &"stage_meadow", "초원으로 되돌아가기 가능")

	# ── 8. 예약 이동: 마을 밖에서 예약 → 마을 도착 시 실행 ──
	GameState.party_in_town = false
	GameState.auto_hunt_unlocked = true # 자동 이동 해금돼야 예약 가능
	var rr := GameState.reserve_travel(&"stage_forest")
	_check(rr["ok"] and GameState.pending_travel == &"stage_forest", "예약 이동 등록")
	_check(GameState.current_region == &"stage_meadow", "예약만으론 아직 초원")
	GameState.party_in_town = true
	GameState.try_pending_travel() # 마을 도착(party.gd가 호출하는 지점)
	_check(GameState.current_region == &"stage_forest", "마을 도착 → 예약 이동 실행")
	_check(GameState.pending_travel == &"", "예약 소진")

	# ── 9. next_unlocked_region 순환 ──
	GameState.purchase(GameState.catalog[&"core_quest_board"])
	GameState.purchase(GameState.catalog[&"core_cave_map"]) # 동굴 해금
	var nxt := GameState.next_unlocked_region()
	_check(nxt != GameState.current_region and GameState.region_unlocked(nxt), "다음 해금 지역 반환")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
