extends Node
## R4 — 트링켓 파티원 슬롯화 + 멤버 친화 보너스 + 인카운터 영향 트링켓.
## godot --headless --path . res://tests/PartyTrinketTest.tscn

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _enable_trinkets() -> void:
	GameState.purchases[&"trk_unlock"] = 1 # 트링켓 시스템 + 멤버당 슬롯 1
	GameState.recalculate_stats()


func _ready() -> void:
	GameState.reset_to_new_game()
	GameState.gold = 99999999
	GameState.current_region = &"stage_meadow"
	_enable_trinkets()

	# ── 1. 새 트링켓 로드 ──
	var ids: Array[StringName] = [&"t_monster_flute", &"t_coward_incense", &"t_golden_bait", &"t_tactics_book", &"t_small_bell"]
	var loaded := 0
	for id in ids:
		if GameState.trinket_catalog.has(id):
			loaded += 1
	_check(loaded == 5, "인카운터 트링켓 5종 로드 (%d)" % loaded)
	_check(GameState.trinket_slots() == 1, "멤버당 슬롯 1 (trk_unlock)")

	# ── 2. 솔로 용사: 슬롯 = 멤버 1명분 ──
	_check(GameState.member_roles() == [&"hero"], "솔로 = [hero] 슬롯")
	GameState.discover_trinket(&"t_tactics_book") # 마법사 친화
	_check(GameState.equipped_trinkets.size() == 1, "용사 슬롯에 1개 장착")
	_check(GameState.member_trinkets[&"hero"].size() == 1, "용사 멤버 슬롯 점유")
	# 마법사 없음 → 친화 보너스 미적용: party_damage = 1.12 (효과만)
	_check(is_equal_approx(float(GameState.stat("party_damage_mult")), 1.12), "친화 불일치 → 효과만 (×1.12)")

	# ── 3. 마법사 합류 → 친화 트링켓이 마법사에게 + 보너스 발동 ──
	GameState.add_companion(GameState.companion_catalog[&"mage"])
	_check(GameState.member_roles().has(&"mage"), "마법사 역할 슬롯 생김")
	var on_mage: bool = GameState.member_trinkets.get(&"mage", []).has(&"t_tactics_book")
	_check(on_mage, "전술서가 마법사 슬롯으로 자동 재배치(친화)")
	# 친화 일치 → 효과(1.12) + 보너스(1.12) = 1.2544
	_check(is_equal_approx(float(GameState.stat("party_damage_mult")), 1.12 * 1.12), "마법사 친화 보너스 발동 (×1.2544)")

	# ── 4. 풀파티 → 4 멤버 슬롯 ──
	GameState.add_companion(GameState.companion_catalog[&"knight"])
	GameState.add_companion(GameState.companion_catalog[&"priest"])
	_check(GameState.member_roles().size() == 4, "풀파티 = 4 멤버 슬롯(기본 4)")

	# ── 5. 인카운터 트링켓: 마물 피리 +1, 겁쟁이 향 -1 ──
	GameState.owned_trinkets = [] # 깨끗이
	GameState.recalculate_stats()
	var base_max := GameState.max_enemies_per_encounter()
	GameState.discover_trinket(&"t_monster_flute") # max_enemies_bonus +1
	_check(GameState.max_enemies_per_encounter() == base_max + 1, "마물 피리 → 무리 +1 (%d→%d)" % [base_max, base_max + 1])
	GameState.discover_trinket(&"t_coward_incense") # -1 → 상쇄
	_check(GameState.max_enemies_per_encounter() == base_max, "겁쟁이 향 → 무리 -1 (상쇄 %d)" % base_max)

	# ── 6. 친화 보너스: 황금 미끼(용사) 적 골드 + 희귀 드랍 ──
	GameState.owned_trinkets = []
	GameState.recalculate_stats()
	GameState.discover_trinket(&"t_golden_bait") # 용사 친화 → enemy_gold ×1.25 + rare +5%
	var on_hero: bool = GameState.member_trinkets.get(&"hero", []).has(&"t_golden_bait")
	_check(on_hero, "황금 미끼가 용사 슬롯에")
	_check(is_equal_approx(float(GameState.stat("enemy_gold_mult")), 1.25), "황금 미끼 효과 적 골드 ×1.25")
	_check(float(GameState.stat("rare_trinket_chance")) >= 0.05, "용사 친화 보너스 → 희귀 드랍 +5%")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
