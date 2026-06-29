extends Node
## Phase 6 — 트링켓 시스템(trk_*) 검증.
## 슬롯·도감·자동장착·장착 효과(스탯 반영)·드랍·세트·수집벽·경로잠금.
## godot --headless --path . res://tests/TrinketTreeTest.tscn

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _u(id: StringName) -> UpgradeData:
	return GameState.catalog.get(id)


func _buy(id: StringName) -> void:
	GameState.gold = 99999999
	GameState.purchase(_u(id))


func _ready() -> void:
	GameState.reset_to_new_game()

	# ── 1. 트링켓/노드 로드 ──
	_check(GameState.trinket_catalog.size() >= 6, "트링켓 카탈로그 로드 (%d)" % GameState.trinket_catalog.size())
	var ids: Array[StringName] = [
		&"trk_unlock", &"trk_drop_slime", &"trk_boss_guarantee", &"trk_slot_2", &"trk_reroll_shop",
		&"trk_tags", &"trk_cursed", &"trk_pot_pool", &"trk_rare_chance", &"trk_slot_3",
		&"trk_loadouts", &"trk_collection"]
	var loaded := 0
	for id in ids:
		if _u(id) != null and _u(id).branch == "trinket":
			loaded += 1
	_check(loaded == 12, "trk 트링켓 12노드 로드 (%d)" % loaded)

	# ── 2. 경로 잠금: trk_unlock은 cmd_window_2 선행 ──
	_check(not GameState.node_unlocked(_u(&"trk_unlock")), "trk_unlock 잠김(cmd_window_2 선행)")
	GameState.gold = 99999999
	GameState.purchase(_u(&"cmd_window_2"))
	_check(GameState.node_unlocked(_u(&"trk_unlock")), "cmd_window_2 → trk_unlock 해금")

	# ── 3. trk_unlock: 해금 + 슬롯 1 + 스타터 3개 도감 + 1개 자동 장착 ──
	_buy(&"trk_unlock")
	_check(GameState.stat("trinkets_enabled") == true, "트링켓 시스템 해금")
	_check(GameState.trinket_slots() == 1, "슬롯 1")
	_check(GameState.owned_trinkets.size() == 3, "스타터 3개 도감 등록")
	_check(GameState.equipped_trinkets.size() == 1, "슬롯 1개 자동 장착")

	# ── 4. 장착 효과가 스탯에 반영 (깨진 항아리 조각: 항아리 골드 ×2, 적 골드 ×0.85) ──
	_check(GameState.equipped_trinkets[0] == &"t_pot_shard", "1번 장착 = 깨진 항아리 조각")
	_check(is_equal_approx(float(GameState.stat("pot_gold_mult")), 2.0), "항아리 골드 ×2 (트링켓)")
	_check(is_equal_approx(float(GameState.stat("enemy_gold_mult")), 0.85), "적 골드 ×0.85 (트링켓 패널티)")

	# ── 5. 슬롯 +1 → 2개 장착, 효과 누적 ──
	_buy(&"trk_slot_2")
	_check(GameState.trinket_slots() == 2 and GameState.equipped_trinkets.size() == 2, "슬롯 2 → 2개 장착")
	# 낡은 검집: 파티 피해 ×1.25, 항아리 골드 ×0.75 → pot_gold = 2.0×0.75 = 1.5
	_check(is_equal_approx(float(GameState.stat("party_damage_mult")), 1.25), "파티 피해 ×1.25 (검집)")
	_check(is_equal_approx(float(GameState.stat("pot_gold_mult")), 1.5), "항아리 골드 2.0×0.75=1.5 (누적)")
	_buy(&"trk_slot_3")
	_check(GameState.equipped_trinkets.size() == 3, "슬롯 3 → 3개 장착")
	# 고장난 회중시계: 쿨타임 ×0.8, 적 HP ×1.15
	_check(is_equal_approx(float(GameState.stat("enemy_hp_mult")), 1.15), "적 HP ×1.15 (회중시계)")

	# ── 6. 드랍률 ──
	_buy(&"trk_drop_slime")
	_check(is_equal_approx(float(GameState.stat("trinket_drop_chance")), 0.005), "드랍률 +0.5%")

	# ── 7. 트링켓 드랍 → 도감 등록 ──
	GameState.owned_trinkets = [&"t_pot_shard"] # 일부만 보유 상태로
	GameState.stats["trinket_drop_chance"] = 1.0 # 100% (테스트)
	GameState.stats["rare_trinket_chance"] = 0.0
	GameState.stats["trinkets_enabled"] = true
	var before := GameState.owned_trinkets.size()
	GameState.try_drop_trinket()
	_check(GameState.owned_trinkets.size() == before + 1, "드랍 → 새 트링켓 도감 등록")

	# ── 8. 세트 효과 (같은 태그 2개) ──
	GameState.reset_to_new_game()
	GameState.gold = 99999999
	GameState.purchase(_u(&"cmd_window_2"))
	GameState.purchase(_u(&"trk_unlock"))
	GameState.purchase(_u(&"trk_slot_2"))
	GameState.purchase(_u(&"trk_pot_pool")) # 항아리 풀 + t_pot_idol 획득 (pot 태그)
	# 강제로 pot 태그 2개 장착 (깨진 항아리 조각 + 항아리 수호상)
	GameState.equipped_trinkets = [&"t_pot_shard", &"t_pot_idol"]
	GameState.purchase(_u(&"trk_tags")) # 세트 해금 → recalc
	# pot 태그 2개 → 파티 피해 ×1.1 세트 보너스 (트링켓 자체엔 party_damage 없음)
	_check(float(GameState.stat("party_damage_mult")) >= 1.1, "세트 효과: pot 태그 2개 → 파티 피해 ×1.1+")

	# ── 9. 수집벽 (발견 트링켓당 골드 +1%) ──
	GameState.reset_to_new_game()
	GameState.gold = 99999999
	GameState.purchase(_u(&"cmd_window_2"))
	GameState.purchase(_u(&"trk_unlock")) # 도감 3개
	var ag0 := float(GameState.stat("all_gold_mult"))
	# 수집벽 노드까지 가는 경로를 직접 보유 처리(선행 우회)
	GameState.purchases[&"trk_collection"] = 1
	GameState.recalculate_stats()
	_check(float(GameState.stat("all_gold_mult")) > ag0, "수집벽 → 도감 3개로 모든 골드 ↑")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
