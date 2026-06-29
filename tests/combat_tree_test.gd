extends Node
## Phase 3 — 전투 트리(cmb_*) + 새 전투 수식 검증.
## hero_attack 가산 · party_damage_mult 곱 · 크리 · 용사 HP · 적 골드 · 전체공격 · 옛 노드 제거.
## godot --headless --path . res://tests/CombatTreeTest.tscn

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
	GameState.gold = 1000000

	# ── 1. 옛 전투 노드 제거 ──
	for old in [&"sword_copper", &"sword_iron", &"sword_steel", &"sword_mythril",
			&"armor_leather", &"armor_chain", &"spell_gira", &"spell_begirama", &"spell_catalog"]:
		_check(_u(old) == null, "옛 노드 제거: %s" % old)

	# ── 2. 16 cmb 노드 로드 ──
	var ids: Array[StringName] = [
		&"cmb_atk_1", &"cmb_hp_1", &"cmb_atk_2", &"cmb_auto_command", &"cmb_quick_swing",
		&"cmb_reward_study", &"cmb_skill_slash", &"cmb_combo", &"cmb_crit", &"cmb_fire_spell",
		&"cmb_boss_slayer", &"cmb_overkill", &"cmb_limit_break", &"cmb_element_mastery",
		&"cmb_legend_sword", &"cmb_screen_wipe"]
	var loaded := 0
	for id in ids:
		if _u(id) != null and _u(id).branch == "combat":
			loaded += 1
	_check(loaded == 16, "cmb 전투 16노드 로드 (%d)" % loaded)

	# ── 3. 경로 잠금: cmb_atk_1은 core_start 선행 ──
	_check(not GameState.node_unlocked(_u(&"cmb_atk_1")), "cmb_atk_1 잠김(core_start 선행)")
	GameState.purchase(_u(&"core_start"))
	_check(GameState.node_unlocked(_u(&"cmb_atk_1")), "core_start 구매 → cmb_atk_1 해금")

	# ── 4. 용사 공격력 가산 (hero_attack) ──
	var base := GameState.hero_attack
	GameState.purchase(_u(&"cmb_atk_1"))
	_check(GameState.hero_attack == base + 1, "cmb_atk_1 → 용사 공격력 +1")
	GameState.purchase(_u(&"cmb_atk_2"))
	_check(GameState.hero_attack == base + 3, "cmb_atk_2 → 누적 +3")

	# ── 5. 파티 피해 배율 (party_damage_mult) ──
	var pre := GameState.hero_attack
	GameState.purchase(_u(&"cmb_legend_sword")) # ×2
	_check(GameState.hero_attack == pre * 2, "cmb_legend_sword → 용사 공격력 ×2")
	# member_attacks 합 = party_attack (일관성)
	var sum := 0
	for a in GameState.member_attacks():
		sum += a
	_check(sum == GameState.party_attack, "member_attacks 합 == party_attack")

	# ── 6. 회심 ──
	var crit0 := GameState.crit_chance
	GameState.purchase(_u(&"cmb_crit"))
	_check(is_equal_approx(GameState.crit_chance, crit0 + 0.05), "cmb_crit → 치명타 확률 +5%")
	_check(is_equal_approx(float(GameState.stat("crit_damage_mult")), 1.5), "cmb_crit → 치명타 피해 ×1.5")

	# ── 7. 용사 최대 HP ──
	var hp0 := GameState.member_max_hp(0)
	GameState.purchase(_u(&"cmb_hp_1"))
	_check(GameState.member_max_hp(0) == hp0 + 10, "cmb_hp_1 → 용사 최대 HP +10")

	# ── 8. 적 골드 배율 ──
	GameState.purchase(_u(&"cmb_reward_study")) # 적 골드 ×1.25 (운0 → 순수 배율)
	_check(is_equal_approx(GameState.combat_gold_mult(false), 1.25), "cmb_reward_study → 전투 골드 ×1.25")

	# ── 9. 전체 공격 ──
	_check(not GameState.all_attack, "구매 전 전체공격 off")
	GameState.purchase(_u(&"cmb_fire_spell"))
	_check(GameState.all_attack, "cmb_fire_spell → 전체 공격 on")

	# ── 10. 공격 속도 → 턴 간격 ──
	GameState.reset_to_new_game()
	GameState.gold = 1000
	var ti0 := GameState.turn_interval
	GameState.purchase(_u(&"cmb_auto_command")) # 공속 ×1.15
	_check(GameState.turn_interval < ti0, "cmb_auto_command → 턴 간격 단축")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
