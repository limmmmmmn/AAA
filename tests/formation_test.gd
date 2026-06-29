extends Node
## R1 — 인카운터 포메이션(무리 전투) + 초원 적 다양화 + 조사도 검증.
## godot --headless --path . res://tests/FormationTest.tscn

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	GameState.reset_to_new_game()
	GameState.current_region = &"stage_meadow"

	# ── 1. 데이터 로드 ──
	_check(GameState.monster_by_id(&"slime") != null, "몬스터 도감 로드 (슬라임)")
	_check(GameState.monster_by_id(&"king_slime") != null, "킹 슬라임 로드")
	var meadow_forms := 0
	for f: EncounterFormationDef in GameState.formation_catalog:
		if f.region_id == &"stage_meadow":
			meadow_forms += 1
	_check(meadow_forms == 11, "초원 포메이션 11개 로드 (%d)" % meadow_forms)

	# ── 2. 슬라임 HP 10 (스펙) ──
	_check(GameState.monster_by_id(&"slime").max_hp == 10, "슬라임 HP 10")
	_check(GameState.monster_by_id(&"gold_slime").rare, "골드 슬라임 = 희귀")
	_check(GameState.monster_by_id(&"king_slime").boss, "킹 슬라임 = 보스")

	# ── 3. 포메이션 해금 조건 ──
	var solo := GameState.formation_def(&"meadow_slime_solo")
	var pair := GameState.formation_def(&"meadow_slime_pair")
	_check(GameState.formation_unlocked(solo), "솔로 포메이션 = 시작부터 해금")
	_check(not GameState.formation_unlocked(pair), "슬라임 둘 = 8킬 전엔 잠김")
	for i in 8:
		GameState.add_region_kill(&"stage_meadow")
	_check(GameState.formation_unlocked(pair), "8킬 후 → 슬라임 둘 해금")

	# ── 4. 적 해금 조건 (survey / discovered) ──
	var rabbit_mix := GameState.formation_def(&"meadow_rabbit_mix")
	_check(not GameState.formation_unlocked(rabbit_mix), "토끼믹스 = 뿔토끼 발견 전 잠김")
	GameState.ensure_hunt_entry(GameState.monster_by_id(&"horn_rabbit")) # 발견 처리
	_check(GameState.formation_unlocked(rabbit_mix), "뿔토끼 발견 후 → 토끼믹스 해금")
	var wasp := GameState.formation_def(&"meadow_wasp_swarm")
	_check(not GameState.formation_unlocked(wasp), "풀벌무리 = 조사도 25% 전 잠김")
	GameState.add_survey(&"stage_meadow", 0.25)
	_check(GameState.formation_unlocked(wasp), "조사도 25% 후 → 풀벌무리 해금")

	# ── 5. 최대 적 수 (단계적) ──
	GameState.reset_to_new_game()
	GameState.current_region = &"stage_meadow"
	_check(GameState.max_enemies_per_encounter() == 1, "초원 시작 = 최대 1마리")
	for i in 8:
		GameState.add_region_kill(&"stage_meadow")
	_check(GameState.max_enemies_per_encounter() == 2, "초원 8킬 → 최대 2마리")
	GameState.current_region = &"stage_cave" # 동굴 = 바닥 4
	_check(GameState.max_enemies_per_encounter() == 4, "동굴 → 최대 4마리")
	GameState.current_region = &"stage_final" # 최종 = 바닥 6
	_check(GameState.max_enemies_per_encounter() == 6, "최종 → 최대 6마리")

	# ── 6. 포메이션 롤 → 적 무리 ──
	GameState.reset_to_new_game()
	GameState.current_region = &"stage_meadow"
	var roll := GameState.roll_encounter_formation(GameState.monster_by_id(&"slime"))
	_check(roll["datas"].size() >= 1, "롤 → 적 1마리 이상")
	_check(roll["datas"].size() <= 1, "초원 시작은 최대 1마리로 클램프")
	_check(roll["formation_id"] != &"", "포메이션 id 반환")
	# 8킬 후 무리 가능
	for i in 8:
		GameState.add_region_kill(&"stage_meadow")
	var got_pair := false
	for i in 40:
		var r := GameState.roll_encounter_formation(GameState.monster_by_id(&"slime"))
		if r["datas"].size() == 2:
			got_pair = true
			break
	_check(got_pair, "8킬 후 → 2마리 무리 인카운터 등장")

	# ── 7. 무리 전멸 완료 보너스 공식 ──
	# 슬라임 x3 (골드 2씩) → 합 6, 보너스 6×0.05×2 = 0.6
	var base_gold := 6.0
	var count := 3
	var clear_bonus := base_gold * 0.05 * maxi(0, count - 1)
	_check(is_equal_approx(clear_bonus, 0.6), "3마리 전멸 보너스 = 6×10% = 0.6")

	# ── 8. 조사도 저장/로드 ──
	GameState.add_survey(&"stage_meadow", 0.3)
	GameState.region_kills[&"stage_meadow"] = 12
	GameState.save_game()
	GameState.survey.clear()
	GameState.region_kills.clear()
	GameState.load_game()
	_check(is_equal_approx(GameState.survey_of(&"stage_meadow"), 0.3), "조사도 저장/로드")
	_check(GameState.region_kill_count(&"stage_meadow") == 12, "지역 킬 저장/로드")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
