extends Node
## 여관: 상점 해금 → 마을 등장, Space로 상점식 UI 열림, 잠자기 → 소지금 일부로 전량 회복.
## godot --headless --path . res://tests/InnTest.tscn

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
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var field: Node = get_tree().get_first_node_in_group("field")
	var party: Node = get_tree().get_first_node_in_group("party")
	var inn: Node = field.find_child("InnBuilding", true, false)
	var inn_ui: Node = main.find_child("InnUI", true, false)
	GameState.damage_enabled = true

	# ── 해금 전 = 숨김 ──
	_check(inn != null and inn_ui != null, "여관 건물/UI 존재")
	_check(not inn.visible, "해금 전엔 여관 숨김")
	_check(GameState.catalog.has(&"vlg_inn"), "여관 설치 업글 존재")

	# ── 상점에서 해금 → 마을 등장 ──
	GameState.gold = 1000
	GameState.purchase(GameState.catalog[&"vlg_inn"])
	_check(GameState.inn_unlocked and inn.visible, "해금 → 마을에 여관 등장")

	# ── Space로 상점식 UI 열림 (세계 정지) ──
	inn._on_body_entered(party)
	inn._activate() # Space
	_check(inn_ui.visible and get_tree().paused, "여관 열림 → 상점식 UI + 세계 정지")

	# ── 잠자기: 소지금 일부 지불 → 전량 회복 ──
	GameState.damage_member(0, 25) # 용사 부상
	_check(GameState.total_hp() < GameState.total_max_hp(), "용사 부상 상태")
	var gold0 := GameState.gold
	var cost := GameState.inn_cost()
	_check(cost == maxi(GameState.config.inn_min_cost, int(gold0 * GameState.config.inn_cost_ratio)), "숙박료 = 소지금 10%% (%d G)" % cost)
	inn_ui._do_sleep()
	_check(GameState.total_hp() == GameState.total_max_hp(), "잠자기 → 전량 회복")
	_check(GameState.gold == gold0 - cost, "숙박료 차감")
	_check(not inn_ui.visible and not get_tree().paused, "잠자면 UI 닫히고 정지 해제")

	# ── 가득이면 잠자기 불가 ──
	_check(not GameState.inn_sleep(), "체력 가득이면 잠자기 안 됨")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
