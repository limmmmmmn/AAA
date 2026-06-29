extends Node
## Phase 7 — 교차(brg_*, 2선행 AND) + 반복(inf_*, cost_growth) 노드 검증.
## godot --headless --path . res://tests/BridgeInfiniteTest.tscn

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

	# ── 1. 로드 ──
	var brg: Array[StringName] = [&"brg_throw_pot", &"brg_bloody_pots", &"brg_quest_trinkets",
		&"brg_inn_combo", &"brg_shop_merc", &"brg_fire_festival", &"brg_castle_pots", &"brg_final_machine"]
	var b_loaded := 0
	for id in brg:
		if _u(id) != null and _u(id).branch == "bridge" and _u(id).requires_all:
			b_loaded += 1
	_check(b_loaded == 8, "교차 8노드 로드(2선행 AND) (%d)" % b_loaded)
	var inf: Array[StringName] = [&"inf_sharpen_blade", &"inf_more_pots", &"inf_better_routes",
		&"inf_gold_rumor", &"inf_trinket_polish"]
	var i_loaded := 0
	for id in inf:
		if _u(id) != null and _u(id).branch == "infinite" and _u(id).max_purchases > 1 and _u(id).cost_growth > 1.0:
			i_loaded += 1
	_check(i_loaded == 5, "반복 5노드 로드(cost_growth) (%d)" % i_loaded)

	# ── 2. 교차 노드 AND 게이팅 ──
	var tp := _u(&"brg_throw_pot") # vlg_pot_worker AND cmb_skill_slash
	_check(not GameState.node_unlocked(tp), "교차: 선행 0개 → 잠김")
	GameState.purchases[&"vlg_pot_worker"] = 1
	GameState.recalculate_stats()
	_check(not GameState.node_unlocked(tp), "교차: 선행 1개만 → 여전히 잠김 (AND)")
	GameState.purchases[&"cmb_skill_slash"] = 1
	GameState.recalculate_stats()
	_check(GameState.node_unlocked(tp), "교차: 선행 2개 모두 → 해금")

	# ── 3. 교차 효과 적용 (선행 기여 위에 곱해진다 — before/after 델타로 검증) ──
	var pdm_before := float(GameState.stat("party_damage_mult"))
	GameState.gold = 99999999
	GameState.purchase(_u(&"brg_throw_pot"))
	_check(is_equal_approx(float(GameState.stat("party_damage_mult")), pdm_before * 1.1), "brg_throw_pot → 파티 피해 ×1.1")
	GameState.purchases[&"vlg_shop"] = 1
	GameState.purchases[&"cmd_recruit_warrior"] = 1
	GameState.recalculate_stats()
	var cm_before := float(GameState.stat("upgrade_cost_mult"))
	GameState.gold = 99999999
	GameState.purchase(_u(&"brg_shop_merc")) # 비용 ×0.9
	_check(is_equal_approx(float(GameState.stat("upgrade_cost_mult")), cm_before * 0.9), "brg_shop_merc → 노드 비용 ×0.9")

	# ── 4. 반복 노드: 레벨 누적 + 비용 증가 ──
	GameState.reset_to_new_game()
	var ig := _u(&"inf_gold_rumor") # 레벨당 적 골드 ×1.1
	var c0 := GameState.current_cost(ig)
	GameState.gold = 99999999
	GameState.purchase(ig)
	_check(GameState.owned_count(ig) == 1, "반복: 1레벨 구매")
	_check(is_equal_approx(float(GameState.stat("enemy_gold_mult")), 1.1), "반복 1레벨 → 적 골드 ×1.1")
	var c1 := GameState.current_cost(ig)
	_check(c1 > c0, "반복: 비용 증가 (%d → %d)" % [c0, c1])
	_check(c1 == int(round(ig.base_cost * 1.5)), "반복 비용 = base × growth^1")
	GameState.purchase(ig)
	_check(GameState.owned_count(ig) == 2, "반복: 2레벨")
	_check(is_equal_approx(float(GameState.stat("enemy_gold_mult")), 1.1 * 1.1), "반복 2레벨 → 1.1^2 복리")

	# ── 5. 반복 노드는 안 떨어지지 않는다(max 99) ──
	_check(_u(&"inf_sharpen_blade").max_purchases >= 50, "반복 노드 최대치 충분히 큼")

	# ── 6. 레거시 axis 헬퍼는 brg/inf 제외 ──
	var leaked := false
	for u: UpgradeData in GameState.upgrades_for_axis("combat"):
		if u.branch == "bridge" or u.branch == "infinite":
			leaked = true
	_check(not leaked, "교차/반복은 레거시 axis 목록에 안 샘")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
