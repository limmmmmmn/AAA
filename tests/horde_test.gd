extends Node
## 몹 증식/리스폰 가속/질주 업그레이드: 사냥터 몬스터가 바글바글 늘어나고 더 빨리 리스폰.
## godot --headless --path . res://tests/HordeTest.tscn

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
	await get_tree().process_frame
	GameState.gold = 999999

	var before := get_tree().get_nodes_in_group("monsters").size()
	_check(before == 6, "시작: 슬라임존 6마리")

	# ── 몹 증식: 존 최대치 +1, 즉시 충원 ──
	GameState.purchase(GameState.catalog[&"horde"])
	_check(GameState.spawn_count_bonus == 1, "몹 증식 → spawn_count_bonus 1")
	await get_tree().process_frame
	await get_tree().process_frame
	var after := get_tree().get_nodes_in_group("monsters").size()
	_check(after == before + 1, "구매 즉시 충원 → %d마리 (실제 %d)" % [before + 1, after])

	# 두 번 더 사면 더 바글바글
	GameState.purchase(GameState.catalog[&"horde"])
	GameState.purchase(GameState.catalog[&"horde"])
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("monsters").size() == before + 3, "3단계 → +3 더 바글바글")

	# ── 리스폰 가속 (반복) ──
	var r0 := GameState.respawn_delay_mult
	GameState.purchase(GameState.catalog[&"respawn_swift"])
	_check(GameState.respawn_delay_mult < r0, "소굴 자극 → 리스폰 더 빨라짐 (%.2f→%.2f)" % [r0, GameState.respawn_delay_mult])
	GameState.purchase(GameState.catalog[&"respawn_swift"])
	_check(GameState.respawn_delay_mult < 0.85 * r0 + 0.001, "반복 구매 → 리스폰 더 더 빨라짐")

	# ── 질주 (반복 이동 속도) ──
	var s0 := GameState.move_speed
	GameState.purchase(GameState.catalog[&"haste_charm"])
	_check(GameState.move_speed > s0, "질주의 부적 → 이동 속도↑ (%.0f→%.0f)" % [s0, GameState.move_speed])
	GameState.purchase(GameState.catalog[&"haste_charm"])
	_check(GameState.move_speed > 1.1 * s0, "반복 구매 → 더 빠르게")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
