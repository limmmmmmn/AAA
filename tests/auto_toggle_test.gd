extends Node
## 우측 퀵슬롯: 16x16, MON=슬라임 아이콘, 자동 이동 온/오프 토글.
## godot --headless --path . res://tests/AutoToggleTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const SLIME := preload("res://assets/enemies/slime.png")

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
	var hud: Node = main.find_child("HUD", true, false)
	var party: Node2D = get_tree().get_first_node_in_group("party")

	# MON 버튼에 슬라임 아이콘 (스킬 무관, 항상)
	var has_slime := false
	for b in hud._slots.get_children():
		if b.icon == SLIME:
			has_slime = true
	_check(has_slime, "MON 버튼에 슬라임 아이콘 표시")

	# 스킬 배우기 전엔 자동이동 버튼 숨김
	_check(hud._auto_slot == null, "스킬 배우기 전엔 자동이동 버튼 없음")

	# 자동이동 스킬(전투 대기열) 해금 → 버튼 등장
	GameState.gold = 9999
	GameState.purchase(GameState.catalog[&"cmd_battle_queue"]) # auto_hunt → stats_changed → 슬롯 재구성
	_check(hud._auto_slot != null, "스킬 배우면 자동이동 버튼 등장")
	_check(hud._auto_slot.custom_minimum_size == Vector2(20, 20), "버튼 20x20 크기")

	# 토글 동작 + 자동 추적 게이트
	_check(not GameState.auto_move_on, "처음엔 자동 이동 OFF")
	party._idle_time = 999.0 # 수동 입력 유예 지난 상태
	_check(not party._can_auto_hunt(), "OFF → 자동 추적 안 함")
	hud._toggle_auto()
	_check(GameState.auto_move_on, "버튼 누르면 ON")
	_check(party._can_auto_hunt(), "스킬+ON → 자동 추적 가능")
	hud._toggle_auto()
	_check(not GameState.auto_move_on and not party._can_auto_hunt(), "다시 누르면 OFF → 자동 추적 정지")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
