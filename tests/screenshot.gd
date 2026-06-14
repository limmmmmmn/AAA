extends Node
## 시각 검증용: Main을 띄우고 몇 프레임 뒤 스크린샷을 저장하고 종료한다.
## godot --path . res://tests/Screenshot.tscn (헤드리스 불가 — 렌더링 필요)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	# 전투창 모습도 찍기 위해 전투 하나 시작
	await get_tree().create_timer(0.5).timeout
	BattleManager.start_battle([load("res://data/monsters/slime.tres")])
	await get_tree().create_timer(1.5).timeout
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("user://screenshot.png"))
	print("screenshot saved: " + ProjectSettings.globalize_path("user://screenshot.png"))
	# 상점 UI도 확인
	GameState.add_gold(30)
	EventBus.party_entered_village.emit()
	await get_tree().create_timer(0.3).timeout
	var shop_image := get_viewport().get_texture().get_image()
	shop_image.save_png(ProjectSettings.globalize_path("user://screenshot_shop.png"))
	EventBus.party_exited_village.emit()
	GameState.gold = 0
	GameState.purchases.clear()
	GameState.recalculate_stats()

	# 다리 게이트 + 동료 실루엣 영역 (A-6)
	var party: Node2D = get_tree().get_first_node_in_group("party")
	party.global_position = Vector2(704, 900)
	await get_tree().create_timer(0.6).timeout
	var bridge_image := get_viewport().get_texture().get_image()
	bridge_image.save_png(ProjectSettings.globalize_path("user://screenshot_bridge.png"))

	# 2지역 진입 (B 전체)
	GameState.add_gold(600)
	var field: Node = get_tree().get_first_node_in_group("field")
	field.get_node("BridgeGate")._on_confirmed()
	await get_tree().create_timer(1.6).timeout
	# 마을(여관/게시판/상점/교회)이 보이게 파티를 마을로 이동
	var p2: Node2D = get_tree().get_first_node_in_group("party")
	p2.global_position = Vector2(336, 1040)
	await get_tree().create_timer(0.5).timeout
	var region2_image := get_viewport().get_texture().get_image()
	region2_image.save_png(ProjectSettings.globalize_path("user://screenshot_region2.png"))

	# 의뢰 게시판 UI (B-4)
	GameState.accept_quest(GameState.quest_catalog[&"quest_snake"])
	EventBus.request_quest_board.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_quest.png"))
	EventBus.party_exited_village.emit()

	# 2지역 상점 (B-6) — 신규 아이템
	GameState.add_gold(3000)
	EventBus.party_entered_village.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_shop2.png"))
	EventBus.party_exited_village.emit()

	# 죽음의 예고 (v3 §7) + 회심(§1) + 철수 토글(§9) + 사냥 허가(§8)
	GameState.tactic_retreat_enabled = false # 토글은 보이되 발동은 막아 연출 캡처
	GameState.crit_chance = 1.0
	GameState.party_attack = 12
	if GameState.member_hps.size() >= 2:
		GameState.member_hps[0] = 8
		GameState.member_hps[1] = 6 # 총 14 / 60 → 위험 (붉은 비네트)
	EventBus.party_hp_changed.emit()
	BattleManager.start_battle([load("res://data/monsters/snake.tres")])
	await get_tree().create_timer(1.4).timeout # 첫 턴(회심) 연출이 뜨는 시점
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_danger.png"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
