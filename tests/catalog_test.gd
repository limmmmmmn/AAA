extends Node
## R5 — 비정지 카탈로그 UI 검증 (토글/탭 채움/비정지/수동 장착/구매).
## godot --headless --path . res://tests/CatalogTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	GameState.reset_to_new_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var cat: Control = main.get_node("UILayer/CatalogUI")

	# ── 1. 토글 + 비정지 ──
	_check(cat != null, "카탈로그 UI 존재")
	_check(not cat.visible, "처음엔 닫힘")
	EventBus.request_catalog.emit()
	await get_tree().process_frame
	_check(cat.visible, "카탈로그 슬롯 → 열림")
	_check(not get_tree().paused, "비정지 (게임 안 멈춤)")
	_check(cat._tabs.get_tab_count() == 5, "5탭 (구매/파티/트링켓/이동/도감)")

	# ── 2. 탭이 데이터로 채워진다 ──
	GameState.gold = 100000
	GameState.purchase(GameState.catalog[&"core_start"])
	cat._refresh_all()
	_check(cat._bodies["buy"].get_child_count() > 0, "구매 탭 채워짐 (살 수 있는 업글)")
	_check(cat._bodies["party"].get_child_count() > 0, "파티 탭 채워짐 (멤버)")
	_check(cat._bodies["bestiary"].get_child_count() > 0, "도감 탭 채워짐 (몬스터)")

	# ── 3. 이동 탭: 해금 지역 표시 ──
	GameState.purchase(GameState.catalog[&"core_forest_path"]) # 숲길 해금
	GameState.party_in_town = true
	cat._refresh_all()
	_check(cat._bodies["travel"].get_child_count() >= 2, "이동 탭: 초원+숲길 행")

	# ── 4. 트링켓 탭: 멤버 수동 장착 (UI가 호출하는 GameState API) ──
	GameState.purchases[&"trk_unlock"] = 1
	GameState.recalculate_stats()
	GameState.add_companion(GameState.companion_catalog[&"mage"])
	GameState.add_companion(GameState.companion_catalog[&"knight"])
	GameState.discover_trinket(&"t_small_bell") # 전사 친화
	# 친화는 전사지만 수동으로 마법사에게 고정
	GameState.equip_trinket_on(&"mage", &"t_small_bell")
	_check(GameState.member_trinkets[&"mage"].has(&"t_small_bell"), "수동 장착: 작은종 → 마법사 (친화 무시)")
	_check(not GameState.member_trinkets.get(&"warrior", []).has(&"t_small_bell"), "전사 슬롯엔 없음")
	cat._refresh_all()
	_check(cat._bodies["trinket"].get_child_count() > 0, "트링켓 탭 채워짐")
	GameState.clear_manual_trinkets() # 자동 배치로 → 친화(전사)로 복귀
	_check(GameState.member_trinkets.get(&"warrior", []).has(&"t_small_bell"), "자동 배치 → 작은종이 전사(친화)로")

	# ── 5. 구매 탭 버튼이 실제 구매로 이어진다 ──
	var owned_before := GameState.owned_count(GameState.catalog[&"cmb_atk_1"])
	GameState.purchase(GameState.catalog[&"cmb_atk_1"]) # UI 버튼이 호출하는 경로
	_check(GameState.owned_count(GameState.catalog[&"cmb_atk_1"]) == owned_before + 1, "구매 동작")

	# ── 6. 닫기 ──
	EventBus.request_catalog.emit()
	await get_tree().process_frame
	_check(not cat.visible, "다시 토글 → 닫힘")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
