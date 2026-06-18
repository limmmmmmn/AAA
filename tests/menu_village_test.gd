extends Node
## 마을 자동이동 허용 + 처음부터 다시하기(리셋) 검증.
## godot --headless --path . res://tests/MenuVillageTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _field() -> RegionBase:
	return get_tree().get_first_node_in_group("field")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame

	# ── 마을에서도 자동 추적 가능 ──
	var party: Node2D = get_tree().get_first_node_in_group("party")
	GameState.auto_hunt_unlocked = true
	party._idle_time = 999.0 # 수동 입력 유예 지난 상태
	party.global_position = _field().entrance(&"default") # 마을 안 스폰 지점
	_check(_field().is_village(party.global_position), "파티가 마을 타일 위")
	_check(party._can_auto_hunt(), "마을 안에서도 자동 추적 허용")

	# 자동 철수 직후엔 수동 입력 전까지 대기 (마을에서 다시 안 나감)
	party._retreat_hold = true
	_check(not party._can_auto_hunt(), "철수 직후 대기 중엔 자동 추적 보류")
	party._retreat_hold = false
	_check(party._can_auto_hunt(), "대기 해제 후 자동 추적 재개")

	# ── 처음부터 다시하기 (리셋) ──
	# 진행을 더럽힌 뒤 세이브
	GameState.gold = 999
	GameState.total_battles_won = 42
	GameState.kill_count[&"slime"] = 30
	GameState.gate_paid = true
	GameState.current_region = &"region2"
	GameState.damage_enabled = true
	if not GameState.member_hps.is_empty():
		GameState.member_hps[0] = 5 # 용사 부상 상태
	GameState.tactic_retreat_unlocked = true
	GameState.purchases[&"sword_copper"] = 1
	GameState.hunt_list[&"orc"] = false
	GameState.save_game()
	_check(FileAccess.file_exists(GameState.SAVE_PATH), "리셋 전 세이브 존재")

	GameState.reset_to_new_game()

	_check(not FileAccess.file_exists(GameState.SAVE_PATH), "리셋: 세이브 파일 삭제")
	_check(GameState.gold == 0, "리셋: 골드 0")
	_check(GameState.total_battles_won == 0, "리셋: 격파 수 0")
	_check(GameState.kill_count.is_empty(), "리셋: 토벌 수 초기화")
	_check(not GameState.gate_paid, "리셋: 통행료 미지불")
	_check(GameState.current_region == &"region1", "리셋: 1지역으로")
	_check(GameState.damage_enabled, "리셋: 데미지 on (1지역부터)")
	_check(GameState.member_count() == 1 and GameState.member_max_hp(0) == GameState.config.hero_max_hp, "리셋: 용사 HP 기본값")
	_check(GameState.total_hp() == GameState.total_max_hp(), "리셋: HP 가득")
	_check(not GameState.tactic_retreat_unlocked, "리셋: 자동 철수 잠금")
	_check(GameState.purchases.is_empty(), "리셋: 구매 초기화")
	_check(GameState.hunt_list.is_empty(), "리셋: 사냥 허가 초기화")
	_check(GameState.party_attack == GameState.config.base_party_attack, "리셋: 파티 공격력 기본값(재계산)")

	# 리셋 후 다시 저장하면 깨끗한 상태가 적힌다
	GameState.save_game()
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	_check(int(d.get("gold", -1)) == 0 and String(d.get("current_region", "")) == "region1", "리셋 후 세이브가 깨끗함")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
