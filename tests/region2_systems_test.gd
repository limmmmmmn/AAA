extends Node
## B-6 상점(지역 필터/신규 효과) + B-3 여관 + B-4 게시판 검증.
## godot --headless --path . res://tests/Region2SystemsTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0
var _quest_done := false


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _has(list: Array, id: StringName) -> bool:
	for u in list:
		if u.id == id:
			return true
	return false


func _field() -> RegionBase:
	return get_tree().get_first_node_in_group("field")


func _ready() -> void:
	GameState.reset_to_new_game() # 이전 세이브(2지역 등) 영향 없이 1지역에서 시작
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	EventBus.quest_completed.connect(func(_q: QuestData) -> void: _quest_done = true)

	# 초원(1단계)에선 2단계 전용 필드 아이템(용맹의 깃발)이 안 보인다
	_check(not _has(GameState.upgrades_for_axis("field"), &"banner_valor"), "초원 상점에 용맹의 깃발 미노출")

	# 숲길(2단계) 전환 — 지역 노드 구매
	GameState.gold = 1000
	GameState.purchase(GameState.catalog[&"core_forest_path"]) # 지역 노드 구매 → 숲길
	await get_tree().process_frame
	_check(GameState.region_number() == 2, "2단계(숲길) 진입")

	# 2단계 상점엔 신규 필드 아이템(용맹의 깃발) 노출
	_check(_has(GameState.upgrades_for_axis("field"), &"banner_valor"), "숲길 상점에 용맹의 깃발 노출")

	GameState.add_gold(5000)
	# 무리 출현 (용맹의 깃발 — 필드 가지)
	_check(GameState.purchase(GameState.catalog[&"banner_valor"]), "용맹의 깃발 구매")
	_check(GameState.group_table.size() == 2, "무리 출현: 2마리 확률표")
	# 전체 공격 (마법서: 파이어 — 전투 가지)
	_check(GameState.purchase(GameState.catalog[&"cmb_fire_spell"]), "파이어 구매")
	_check(GameState.all_attack, "파이어: 전투창 전체 공격 on")

	# (2지역 전용 여관/게시판/성소는 삭제됨 — 의뢰 시스템은 GameState로 직접 검증)
	# 의뢰 수주/완료 (게시판 건물 없이도 시스템은 동작)
	var snake: MonsterData = load("res://data/monsters/snake.tres")
	var quest: QuestData = GameState.quest_catalog[&"quest_snake"]
	_check(GameState.accept_quest(quest), "의뢰 수주 (독사 10)")
	_check(not GameState.accept_quest(GameState.quest_catalog[&"quest_wolf"]), "동시 수주 1개 제한")
	var gold_before := GameState.gold
	for i in 10:
		GameState.register_kill(snake)
	_check(_quest_done and GameState.active_quest_id == &"", "의뢰 완료 → 수주 해제")
	_check(GameState.gold == gold_before + quest.reward_gold, "의뢰 보상 +%dG" % quest.reward_gold)

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
