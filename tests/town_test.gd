extends Node
## 마을 오브젝트(항아리/상자/대장간/보석) 검증.
## godot --headless --path . res://tests/TownTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	# 깨끗한 시작
	GameState.gems = 0
	GameState.materials.clear()
	GameState.rusty_swords = 0
	GameState.forge_level = -1
	GameState.auto_pot = false
	# 항아리·보물상자는 이제 상점 해금 → 테스트에선 직접 해금(갯수 1)
	GameState.purchases[&"pot_unlock"] = 1
	GameState.purchases[&"chest_unlock"] = 1
	GameState.recalculate_stats()

	# ── 인벤토리 ──
	GameState.add_gems(5)
	_check(GameState.gems == 5, "보석 +5")
	_check(GameState.spend_gems(3) and GameState.gems == 2, "보석 -3")
	_check(not GameState.spend_gems(10), "보석 부족 시 사용 실패")
	GameState.add_material(&"stone", 4)
	_check(GameState.material_count(&"stone") == 4, "돌멩이 +4")
	_check(GameState.spend_material(&"stone", 1) and GameState.material_count(&"stone") == 3, "돌멩이 -1")

	# ── 항아리 ──
	GameState.play_time = 100.0
	GameState.pot_ready_ats[0] = 0.0
	_check(GameState.pot_ready(), "항아리 준비됨")
	var msg := GameState.break_pot()
	_check(msg != "", "항아리 깨기 → 보상 (%s)" % msg)
	_check(not GameState.pot_ready(), "깬 직후엔 복구 중")
	_check(is_equal_approx(GameState.pot_ready_ats[0], 100.0 + GameState.pot_cooldown_now()), "쿨타임 설정됨")
	GameState.play_time = GameState.pot_ready_ats[0] + 1.0
	_check(GameState.pot_ready(), "쿨타임 경과 후 다시 준비됨")

	# ── 보물상자 ──
	GameState.chest_ready_ats[0] = 0.0
	GameState.play_time = 300.0
	_check(GameState.chest_ready(), "보물상자 준비됨")
	_check(GameState.open_chest() != "", "보물상자 열기 → 보상")
	_check(not GameState.chest_ready() and is_equal_approx(GameState.chest_ready_ats[0], 300.0 + GameState.chest_cooldown_now()), "상자 쿨타임 설정")

	# ── 대장간: 녹슨 검 강화 → 판매 → 보석 ──
	GameState.rusty_swords = 1
	GameState.gold = 1000
	GameState.materials[&"stone"] = 20
	GameState.add_material(&"enhance_stone", 2)
	_check(GameState.forge_put_sword() and GameState.forge_level == 0, "녹슨 검 화로에 올림 (+0)")
	_check(not GameState.forge_put_sword(), "이미 검 있으면 못 올림")
	for i in 5:
		_check(GameState.forge_enhance(), "강화 → +%d" % (i + 1))
	_check(GameState.forge_level == 5 and GameState.forge_can_sell(), "최대 강화(+5) 도달, 판매 가능")
	_check(not GameState.forge_can_enhance(), "최대치에선 강화 불가")
	var gems_before := GameState.gems
	_check(GameState.forge_sell() and GameState.gems == gems_before + GameState.config.sword_sell_gems and GameState.forge_level == -1, "판매 → 보석 획득, 화로 비움")

	# ── 검 장착: 강화검 → 파티 공격력 (보석 ↔ 강함 선택) ──
	GameState.equipped_sword_level = -1
	GameState.rusty_swords = 1
	GameState.gold = 1000
	GameState.materials[&"stone"] = 20
	GameState.materials[&"enhance_stone"] = 2
	GameState.forge_level = -1
	GameState.forge_put_sword()
	for i in 3:
		GameState.forge_enhance() # +3
	GameState.recalculate_stats()
	var atk_before := GameState.party_attack
	_check(GameState.equip_forge_sword(), "검 장착 성공")
	_check(GameState.equipped_sword_level == 3 and GameState.forge_level == -1, "장착 후 화로 비움, 장착 수치 +3")
	_check(GameState.equipped_attack_bonus() == 3 * GameState.config.sword_attack_per_level, "장착 공격력 보너스")
	_check(GameState.party_attack == atk_before + 3 * GameState.config.sword_attack_per_level, "파티 공격력 증가")
	# 더 약한 검은 장착 불가 (UI에서 막지만 메서드도 동작 확인)
	GameState.rusty_swords = 1
	GameState.forge_put_sword() # +0
	var atk_eq := GameState.party_attack
	GameState.equip_forge_sword() # +0 으로 교체되면 약해짐
	_check(GameState.equipped_sword_level == 0, "메서드는 교체 수행 (UI가 약화 방지)")
	GameState.equipped_sword_level = -1
	GameState.forge_level = -1
	GameState.recalculate_stats()
	_check(GameState.party_attack == atk_eq - 3 * GameState.config.sword_attack_per_level + 0, "장착 해제 시 보너스 제거")

	# ── 보물상자 열쇠 시스템 (중반 깊이) ──
	GameState.chest_keys_unlocked = false
	GameState.chest_required_key = &""
	GameState.chest_opens = 0
	GameState.materials.erase(&"wood_key")
	_check(not GameState.chest_needs_key(), "해금 전엔 열쇠 불필요")
	for i in GameState.config.chest_key_unlock_opens:
		GameState.chest_ready_ats[0] = 0.0
		GameState.play_time = 10000.0 + i
		# 해금 전이거나 열쇠 보유 시 열림
		if GameState.chest_needs_key():
			GameState.add_material(&"wood_key", 1)
		_check(GameState.open_chest() != "", "상자 개봉 #%d" % (i + 1))
	_check(GameState.chest_keys_unlocked, "%d회 개봉 후 열쇠 시스템 해금" % GameState.config.chest_key_unlock_opens)
	_check(GameState.chest_needs_key() and GameState.chest_required_key == &"wood_key", "해금 후 나무 열쇠 필요")
	# 열쇠 없으면 못 연다
	GameState.materials.erase(&"wood_key")
	GameState.chest_ready_ats[0] = 0.0
	GameState.play_time = 20000.0
	_check(GameState.chest_ready() and not GameState.chest_can_open(), "준비됐어도 열쇠 없으면 개봉 불가")
	_check(GameState.open_chest() == "", "열쇠 없이 개봉 시도 → 실패")
	# 열쇠 주면 열리고 소비된다
	GameState.add_material(&"wood_key", 1)
	_check(GameState.chest_can_open(), "열쇠 보유 시 개봉 가능")
	_check(GameState.open_chest() != "" and GameState.material_count(&"wood_key") == 0, "개봉 → 열쇠 1개 소비")

	# ── 자동 항아리꾼 (보석 자동화) ──
	GameState.gems = GameState.config.auto_pot_gem_cost
	GameState.auto_pot = false
	GameState.pot_ready_ats[0] = 0.0
	GameState.play_time = 800.0
	_check(GameState.buy_auto_pot() and GameState.auto_pot and GameState.gems == 0, "보석으로 자동 항아리꾼 구매")
	_check(not GameState.buy_auto_pot(), "이미 보유 시 재구매 불가")
	var ready_at_before := GameState.pot_ready_ats[0]
	await get_tree().process_frame # _process가 자동으로 항아리를 깬다
	_check(GameState.pot_ready_ats[0] > ready_at_before, "자동 항아리꾼: 준비되면 자동으로 깸")

	# ── 필드 몬스터 드롭 (전투 → 마을 재료) ──
	var dm := MonsterData.new()
	dm.id = &"dropper"; dm.display_name = "드롭몬"; dm.stone_drop = 1.0; dm.sword_drop = 1.0
	var stone0 := GameState.material_count(&"stone")
	var sword0 := GameState.rusty_swords
	GameState.roll_monster_drops(dm)
	_check(GameState.material_count(&"stone") == stone0 + 1 and GameState.rusty_swords == sword0 + 1, "처치 드롭: 돌멩이+1, 녹슨 검+1")

	# ── 보석 구매: 자동 강화 / 자동 납품 ──
	GameState.gems = 10
	GameState.auto_enhance = false
	GameState.auto_deliver = false
	_check(GameState.buy_auto_enhance() and GameState.auto_enhance and GameState.gems == 10 - GameState.config.auto_enhance_gem_cost, "자동 강화 구매")
	_check(GameState.buy_auto_deliver() and GameState.auto_deliver, "자동 납품 구매")

	# ── 자동 공장: 검 자동 장전 → 강화 → 판매 → 보석 ──
	GameState.gems = 0
	GameState.gold = 2000
	GameState.materials[&"stone"] = 40
	GameState.materials[&"enhance_stone"] = 5
	GameState.rusty_swords = 2
	GameState.forge_level = -1
	GameState._forge_accum = 0.0
	for i in 20: # 충분한 스텝 (검 1자루 = 장전+5강화+판매 = 7스텝)
		GameState._tick_forge(GameState.config.auto_forge_interval)
	_check(GameState.gems == 2, "자동 공장: 검 2자루 자동 강화→판매→보석 2 (실제 %d)" % GameState.gems)
	_check(GameState.rusty_swords == 0 and GameState.forge_level == -1, "자동 공장: 재료 소진 후 화로 비움")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
