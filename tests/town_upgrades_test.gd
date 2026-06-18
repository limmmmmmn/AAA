extends Node
## 마을 설치물 인크리멘탈: 항아리·보물상자 해금/증설/쿨다운 업글 + 인덱스별 독립 쿨타임.
## godot --headless --path . res://tests/TownUpgradesTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _buy(id: StringName) -> void:
	GameState.gold = 999999
	GameState.purchase(GameState.catalog[id])


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var field: Node = get_tree().get_first_node_in_group("field")
	var pot0: Node = field.find_child("Pot", true, false)
	var pot1: Node = field.find_child("Pot2", true, false)
	var chest0: Node = field.find_child("TreasureChest", true, false)
	var chest1: Node = field.find_child("Chest2", true, false)

	# ── 해금 전 = 숨김 + 상점 게이팅 ──
	_check(not pot0.visible and not chest0.visible, "해금 전엔 항아리·상자 숨김")
	_check(not GameState.upgrades_for_axis("field").has(GameState.catalog[&"pot_count"]),
		"해금 전엔 증설 업글 숨김(requires_flag)")

	# ── 항아리 설치 ──
	_buy(&"pot_unlock")
	_check(GameState.pot_unlocked and GameState.pot_count == 1, "항아리 설치 → 갯수 1")
	_check(pot0.visible and not pot1.visible, "1번 항아리만 보이고 2번은 숨김")
	_check(GameState.upgrades_for_axis("field").has(GameState.catalog[&"pot_count"]),
		"해금 후 증설 업글 노출")

	# ── 항아리 증설 → 2개, 각각 독립 쿨타임 ──
	_buy(&"pot_count")
	_check(GameState.pot_count == 2 and pot1.visible, "증설 → 갯수 2, 2번 항아리 등장")
	GameState.play_time = 1000.0
	GameState.pot_ready_ats[0] = 0.0
	GameState.pot_ready_ats[1] = 0.0
	_check(GameState.pot_ready(0) and GameState.pot_ready(1), "두 항아리 모두 준비됨")
	GameState.break_pot(0)
	_check(not GameState.pot_ready(0) and GameState.pot_ready(1), "0번만 깨짐 — 쿨타임 독립")

	# ── 항아리 쿨다운 업글 → 복구 빨라짐 ──
	var pcd0 := GameState.pot_cooldown_now()
	_buy(&"pot_cooldown")
	_check(GameState.pot_cooldown_now() < pcd0, "항아리 쿨다운 업글 → 복구 시간 단축")

	# ── 보물상자 설치/증설/쿨다운 (더 비싸지만 동일 구조) ──
	_check(GameState.catalog[&"chest_unlock"].base_cost > GameState.catalog[&"pot_unlock"].base_cost,
		"보물상자 설치가 항아리보다 비쌈")
	_buy(&"chest_unlock")
	_check(GameState.chest_unlocked and GameState.chest_count == 1 and chest0.visible, "보물상자 설치 → 1개")
	_buy(&"chest_count")
	_check(GameState.chest_count == 2 and chest1.visible, "보물상자 증설 → 2개")
	GameState.play_time = 5000.0
	GameState.chest_ready_ats[0] = 0.0
	GameState.chest_ready_ats[1] = 0.0
	GameState.open_chest(0)
	_check(not GameState.chest_ready(0) and GameState.chest_ready(1), "0번 상자만 열림 — 독립")
	var ccd0 := GameState.chest_cooldown_now()
	_buy(&"chest_cooldown")
	_check(GameState.chest_cooldown_now() < ccd0, "보물상자 쿨다운 업글 → 복구 단축")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
