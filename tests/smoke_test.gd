extends Node
## 헤드리스 스모크 테스트 (v2): godot --headless --path . res://tests/SmokeTest.tscn
## 코어 루프 + v2 구조(솔로 용사, enemies 배열, 존 단계 해금, 시야 줌)를 검증한다.

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	GameState.reset_to_new_game() # 이전 세이브(삽/해금 등) 영향 없이 깨끗한 카탈로그/상점 검증
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var field: RegionBase = get_tree().get_first_node_in_group("field")
	var tiles: TileMapLayer = field.get_node("TileMapLayer")
	_check(tiles.get_used_cells().size() == field.map_size.x * field.map_size.y, "타일맵 전체 칠해짐")

	# A-2: 시작 시 슬라임존만 활성 (6마리), 박쥐/정예존은 잠금
	_check(get_tree().get_nodes_in_group("monsters").size() == 6, "시작 시 슬라임존만 활성(6마리)")
	_check(GameState.catalog.size() == 34, "업그레이드 카탈로그 34종 (+여관 설치)")
	# 1지역 상점엔 1지역 아이템만 노출. 해금 전 증설/쿨다운/모닥불 스탯 업글은 숨김(requires_flag).
	_check(GameState.upgrades_for_axis("combat").size() == 5, "1지역 상점 전투 5종")
	_check(GameState.upgrades_for_axis("field").size() == 13, "1지역 상점 필드 13종 (+여관 설치)")

	# A-1: 솔로 용사 — 파티 멤버 1명, 기본 공격력 3
	_check(GameState.party_members().size() == 1, "파티 = 용사 1인")
	_check(GameState.party_attack == 3, "용사 기본 공격력 3")

	# A-3: enemies 배열 구조 — 1지역은 길이 1
	var slime: MonsterData = load("res://data/monsters/slime.tres")
	var gold_before: int = GameState.gold
	var battle := BattleManager.start_battle([slime])
	_check(battle != null and battle.enemies.size() == 1, "전투 시작 (enemies 길이 1)")
	_check(not BattleManager.can_start_battle(), "전투창 1개 제한 동작")
	var result: Dictionary = await battle.finished
	_check(result.turns == 3, "슬라임 3턴 격파 (실제 %d턴)" % result.turns)
	_check(GameState.gold == gold_before + slime.gold_reward, "골드 +%d 지급" % slime.gold_reward)

	await get_tree().create_timer(1.0).timeout
	var container := main.get_node("UILayer/BattleWindowContainer")
	_check(container.get_child_count() == 0, "승리 후 전투창 닫힘")

	# A-2: 슬라임 15토벌 → 박쥐존 해금 (몬스터 수 증가)
	for i in 15:
		GameState.register_kill(slime)
	EventBus.monster_died.emit(slime, Vector2.ZERO)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("monsters").size() >= 11, "박쥐존 해금 → 몬스터 증가(6+5)")

	# 상점 구매 → 스탯 재계산
	GameState.add_gold(50)
	var atk_before: int = GameState.party_attack
	var sword: UpgradeData = GameState.catalog[&"sword_copper"]
	_check(GameState.purchase(sword), "구리 검 구매")
	_check(GameState.party_attack == atk_before + 3, "공격력 +3 반영")
	_check(not GameState.purchase(sword), "중복 구매 차단")

	# 1턴 격파 플래그
	GameState.party_attack = 99
	var battle2 := BattleManager.start_battle([slime])
	var result2: Dictionary = await battle2.finished
	_check(result2.one_shot, "회심의 일격(1턴 격파) 플래그")
	GameState.recalculate_stats()

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
