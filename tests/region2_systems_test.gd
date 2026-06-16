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
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	EventBus.quest_completed.connect(func(_q: QuestData) -> void: _quest_done = true)

	# B-6: 1지역에선 2지역 상점 아이템이 안 보인다
	_check(not _has(GameState.upgrades_for_axis("combat"), &"spell_begirama"), "1지역 상점에 베기라 미노출")

	# 2지역 전환
	GameState.add_gold(600)
	_field().get_node("BridgeGate")._on_confirmed()
	await get_tree().create_timer(1.4).timeout
	_check(GameState.current_region == &"region2", "2지역 진입")

	# B-6: 2지역 상점엔 신규 아이템 노출
	var combat := GameState.upgrades_for_axis("combat")
	_check(_has(combat, &"armor_chain") and _has(combat, &"spell_begirama"), "2지역 상점에 사슬갑옷·베기라 노출")
	_check(_has(combat, &"sword_copper"), "2지역 상점은 1지역 아이템 포함(상위 단계)")

	GameState.add_gold(5000)
	_check(GameState.purchase(GameState.catalog[&"armor_chain"]), "사슬 갑옷 구매")
	_check(is_equal_approx(GameState.damage_reduction_mult, 0.8), "피격 경감 0.8 반영")
	_check(GameState.purchase(GameState.catalog[&"banner_valor"]), "용맹의 깃발 구매")
	_check(GameState.group_table.size() == 2, "무리 출현: 2마리 확률표")
	_check(GameState.purchase(GameState.catalog[&"spell_begirama"]), "베기라 구매")
	_check(GameState.all_attack, "베기라: 전체 공격 on")
	_check(GameState.purchase(GameState.catalog[&"spell_catalog"]), "주문 카탈로그 구매")
	_check(GameState.remote_shop_unlocked, "원격 구매 해금")

	# B-3: 여관
	GameState.member_hps[0] = 10 # 용사 부상
	GameState.gold = 100
	var inn := _field().get_node("Village/Inn")
	inn._on_confirmed() # 확인 팝업 승낙 → 숙박 결제
	_check(GameState.total_hp() == GameState.total_max_hp() and GameState.gold == 80, "여관: 20G로 전량 회복")

	# B-4: 게시판 의뢰
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
