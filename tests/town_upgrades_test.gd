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

	# ── 해금 전 = 숨김 + 경로 잠금 ──
	_check(not pot0.visible and not chest0.visible, "해금 전엔 항아리·상자 숨김")
	_check(not GameState.node_unlocked(GameState.catalog[&"vlg_pot_plus"]),
		"vlg_pot_1 사기 전엔 항아리 증설 잠김(경로)")

	# ── 항아리 설치 (vlg_pot_1) ──
	_buy(&"vlg_pot_1")
	_check(GameState.pot_unlocked and GameState.pot_count == 1, "항아리 설치 → 갯수 1")
	_check(pot0.visible and not pot1.visible, "1번 항아리만 보이고 2번은 숨김")
	_check(GameState.node_unlocked(GameState.catalog[&"vlg_pot_plus"]),
		"vlg_pot_1 구매 → 증설 해금")

	# ── 항아리 증설 (vlg_pot_plus) → 2개, 각각 독립 쿨타임 ──
	_buy(&"vlg_pot_plus")
	_check(GameState.pot_count == 2 and pot1.visible, "증설 → 갯수 2, 2번 항아리 등장")
	GameState.play_time = 1000.0
	GameState.pot_ready_ats[0] = 0.0
	GameState.pot_ready_ats[1] = 0.0
	_check(GameState.pot_ready(0) and GameState.pot_ready(1), "두 항아리 모두 준비됨")
	GameState.break_pot(0)
	_check(not GameState.pot_ready(0) and GameState.pot_ready(1), "0번만 깨짐 — 쿨타임 독립")

	# ── 항아리 재생 업글 (vlg_pot_respawn_1) → 복구 빨라짐 ──
	var pcd0 := GameState.pot_cooldown_now()
	_buy(&"vlg_pot_respawn_1")
	_check(GameState.pot_cooldown_now() < pcd0, "재생설(×0.8) → 복구 시간 단축")

	# ── 항아리 골드 업글 (vlg_pot_gold_1·big_pot) → 항아리 골드 ↑ ──
	_buy(&"vlg_pot_gold_1") # 기본 +2
	_check(int(GameState.stat("pot_base_gold")) == 2, "더 수상한 항아리 → 항아리 기본 골드 +2")

	# ── 보물상자 설치 (vlg_chest) ──
	_check(GameState.catalog[&"vlg_chest"].base_cost > GameState.catalog[&"vlg_pot_1"].base_cost,
		"보물상자가 항아리보다 비쌈")
	_buy(&"vlg_chest")
	_check(GameState.chest_unlocked and GameState.chest_count == 1 and chest0.visible, "보물상자 설치 → 1개")
	GameState.play_time = 5000.0
	GameState.chest_ready_ats[0] = 0.0
	GameState.open_chest(0)
	_check(not GameState.chest_ready(0), "보물상자 개봉 → 쿨타임 진입")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
