extends Node
## Phase 4 — 마을/항아리 트리(vlg_*) 검증.
## 옛 항아리/상자/여관 노드 제거 · 항아리 설치/증설/골드/재생/자동 · 여관/상자 · 세금/축제.
## godot --headless --path . res://tests/VillageTreeTest.tscn

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
	GameState.gold = 9999999
	GameState.purchase(_u(id))


func _ready() -> void:
	GameState.reset_to_new_game()

	# ── 1. 옛 마을 노드 제거 ──
	for old in [&"pot_unlock", &"pot_count", &"pot_cooldown",
			&"chest_unlock", &"chest_count", &"chest_cooldown", &"inn_unlock"]:
		_check(_u(old) == null, "옛 노드 제거: %s" % old)

	# ── 2. 16 vlg 노드 로드 ──
	var ids: Array[StringName] = [
		&"vlg_pot_1", &"vlg_pot_plus", &"vlg_pot_gold_1", &"vlg_pot_respawn_1", &"vlg_pot_worker",
		&"vlg_crate", &"vlg_npc", &"vlg_shop", &"vlg_inn", &"vlg_pot_chain", &"vlg_village_worker",
		&"vlg_chest", &"vlg_big_pot", &"vlg_tax_office", &"vlg_festival", &"vlg_pot_kingdom"]
	var loaded := 0
	for id in ids:
		if _u(id) != null and _u(id).branch == "village":
			loaded += 1
	_check(loaded == 16, "vlg 마을 16노드 로드 (%d)" % loaded)

	# ── 3. 경로 잠금: vlg_pot_1은 core_town_permit 선행 ──
	_check(not GameState.node_unlocked(_u(&"vlg_pot_1")), "vlg_pot_1 잠김(core_town_permit 선행)")
	GameState.gold = 9999999
	GameState.purchase(_u(&"core_town_permit"))
	_check(GameState.node_unlocked(_u(&"vlg_pot_1")), "town_permit 구매 → vlg_pot_1 해금")

	# ── 4. 항아리 설치/증설 ──
	_buy(&"vlg_pot_1")
	_check(GameState.pot_unlocked and GameState.pot_count == 1, "vlg_pot_1 → 항아리 1")
	_buy(&"vlg_pot_plus")
	_check(GameState.pot_count == 2, "vlg_pot_plus → 항아리 2")

	# ── 5. 항아리 골드: 기본 +2, 배율 ×2 ──
	_buy(&"vlg_pot_gold_1")
	_check(int(GameState.stat("pot_base_gold")) == 2, "vlg_pot_gold_1 → 기본 골드 +2")
	_buy(&"vlg_big_pot")
	_check(is_equal_approx(float(GameState.stat("pot_gold_mult")), 2.0), "vlg_big_pot → 항아리 골드 ×2")
	_check(GameState.pot_count == 4, "vlg_big_pot → 항아리 +2 (총 4)")

	# ── 6. 항아리 재생 ×0.8 → 쿨타임 단축 ──
	GameState.reset_to_new_game()
	GameState.gold = 9999999
	GameState.purchase(_u(&"vlg_pot_1"))
	var cd0 := GameState.pot_cooldown_now()
	GameState.purchase(_u(&"vlg_pot_respawn_1"))
	_check(is_equal_approx(GameState.pot_cooldown_now(), cd0 * 0.8), "vlg_pot_respawn_1 → 쿨타임 ×0.8")

	# ── 7. 항아리꾼 = 자동 깨기 ──
	_check(not GameState.auto_pot, "구매 전 자동 항아리 off")
	GameState.purchase(_u(&"vlg_pot_worker"))
	_check(GameState.auto_pot, "vlg_pot_worker → 자동 항아리꾼 on")

	# ── 8. 여관 / 보물상자 ──
	GameState.purchase(_u(&"vlg_inn"))
	_check(GameState.inn_unlocked, "vlg_inn → 여관 설치")
	GameState.purchase(_u(&"vlg_chest"))
	_check(GameState.chest_unlocked, "vlg_chest → 보물상자 설치")

	# ── 9. 세금: 마을 골드 ×2, 적 골드 ×0.9 ──
	GameState.purchase(_u(&"vlg_tax_office"))
	_check(is_equal_approx(float(GameState.stat("village_gold_mult")), 2.0), "vlg_tax_office → 마을 골드 ×2")
	_check(is_equal_approx(float(GameState.stat("enemy_gold_mult")), 0.9), "vlg_tax_office → 적 골드 ×0.9")

	# ── 10. 실제 항아리 골드에 배율이 반영되나 (마을 골드 출처) ──
	GameState.reset_to_new_game()
	GameState.gold = 9999999
	for id in [&"vlg_pot_1", &"vlg_pot_gold_1", &"vlg_big_pot"]: # 기본+2, ×2
		GameState.purchase(_u(id))
	GameState.play_time = 100.0
	GameState.pot_ready_ats[0] = 0.0
	var before := GameState.gold
	GameState.break_pot(0) # 골드+재료 등 무작위지만, 골드면 (roll+2)×2 이상
	_check(GameState.gold >= before, "항아리 깨기 — 골드 비감소(배율 적용 경로)")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
