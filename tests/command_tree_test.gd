extends Node
## Phase 5 — 지휘/멀티 전투창 트리(cmd_*) 검증. 핵심 훅 = 추가 전투창 효율.
## 전투창 +1 · 추가창 효율 0.45→ · 동료 영입 · 분신술(효율 1.0 + 적 HP ×1.4).
## godot --headless --path . res://tests/CommandTreeTest.tscn

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

	# ── 1. window_expand 제거 + cmd 로드 ──
	_check(_u(&"window_expand") == null, "옛 window_expand 제거")
	var ids: Array[StringName] = [
		&"cmd_recruit_warrior", &"cmd_auto_loot", &"cmd_battle_queue", &"cmd_window_2",
		&"cmd_window_train", &"cmd_healer", &"cmd_target_rules", &"cmd_window_mini",
		&"cmd_party_orders", &"cmd_window_3", &"cmd_parallel_boss", &"cmd_auto_boss_retry",
		&"cmd_window_mastery", &"cmd_window_4", &"cmd_squad_clone", &"cmd_window_5", &"cmd_window_6"]
	var loaded := 0
	for id in ids:
		if _u(id) != null and _u(id).branch == "command":
			loaded += 1
	_check(loaded == 17, "cmd 지휘 17노드 로드 (%d)" % loaded)
	_check(_u(&"cmb_warrior_oath") != null, "cmb_warrior_oath(이월) 존재")

	# ── 2. 경로 잠금: cmd_recruit_warrior는 core_multi_hint 선행 ──
	_check(not GameState.node_unlocked(_u(&"cmd_recruit_warrior")), "cmd_recruit_warrior 잠김")
	_buy(&"core_multi_hint")
	_check(GameState.node_unlocked(_u(&"cmd_recruit_warrior")), "core_multi_hint → 지휘 가지 해금")

	# ── 3. 동료 영입 ──
	var m0 := GameState.member_count()
	_buy(&"cmd_recruit_warrior")
	_check(GameState.has_companion(&"knight") and GameState.member_count() == m0 + 1, "전사 고용 → 전사 합류")
	_buy(&"cmd_healer")
	_check(GameState.has_companion(&"priest"), "힐러 고용 → 승려 합류")

	# ── 4. 전투창 +1 (combat_slots → max_battle_windows) ──
	var w0 := GameState.max_battle_windows
	_buy(&"cmd_window_2")
	_check(GameState.max_battle_windows == w0 + 1, "동시 전투창 I → 전투창 +1")
	_buy(&"cmd_window_3")
	_buy(&"cmd_window_4")
	_check(GameState.max_battle_windows == w0 + 3, "창 II·III → 전투창 누적 +3")

	# ── 5. 추가창 효율 (핵심 훅) ──
	_check(is_equal_approx(float(GameState.stat("extra_window_efficiency")), 0.45), "기본 추가창 효율 0.45")
	_buy(&"cmd_window_train") # +0.15
	_check(is_equal_approx(float(GameState.stat("extra_window_efficiency")), 0.60), "훈련 → 0.60")
	_buy(&"cmd_window_mastery") # +0.25
	_check(is_equal_approx(float(GameState.stat("extra_window_efficiency")), 0.85), "숙련 → 0.85")

	# ── 6. 멀티 전투창: 2번째 창은 화력 감소 ──
	var slime: MonsterData = load("res://data/monsters/slime.tres")
	BattleManager.abort_all()
	var b1 := BattleManager.start_battle([slime])
	var b2 := BattleManager.start_battle([slime]) # max_windows≥2라 열린다
	_check(b1 != null and b2 != null, "동시에 2개 전투창 열림")
	_check(is_equal_approx(b1.window_efficiency, 1.0), "1번 창 = 100% 화력")
	_check(is_equal_approx(b2.window_efficiency, 0.85), "2번 창 = 추가창 효율(0.85)")
	BattleManager.abort_all()

	# ── 7. 파티 분신술: 효율 1.0 + 적 HP ×1.4 ──
	_buy(&"cmd_squad_clone")
	_check(float(GameState.stat("extra_window_efficiency")) >= 1.0, "분신술 → 추가창 효율 1.0 이상")
	BattleManager.abort_all()
	var b3 := BattleManager.start_battle([slime])
	var b4 := BattleManager.start_battle([slime])
	_check(is_equal_approx(b4.window_efficiency, 1.0), "분신술 후 2번 창도 100% (캡 1.0)")
	# 적 HP ×1.4 (slime 10 → 14)
	_check(b3.enemies[0].hp == int(round(slime.max_hp * 1.4)), "분신술 → 적 HP ×1.4 (%d)" % b3.enemies[0].hp)
	BattleManager.abort_all()

	# ── 8. cmb_warrior_oath ──
	var pa0 := GameState.hero_attack
	_buy(&"cmb_warrior_oath") # 파티 피해 ×1.25
	_check(GameState.hero_attack == int(round(pa0 * 1.25)), "전사의 맹세 → 파티 피해 ×1.25")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
