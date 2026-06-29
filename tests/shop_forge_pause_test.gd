extends Node
## 상점·대장간: 열리면 세계 정지(필드·전투 멈춤), 키보드(↑/↓ + Enter)로 조작 가능.
## godot --headless --path . res://tests/ShopForgePauseTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _key(node: Node, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	node._input(ev)


func _ready() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var field: Node = get_tree().get_first_node_in_group("field")
	var party: Node = get_tree().get_first_node_in_group("party")
	var shop: Node = field.find_child("ShopBuilding", true, false)
	var shop_ui: Node = main.find_child("ShopUI", true, false)
	var forge: Node = field.find_child("Blacksmith", true, false)
	var forge_ui: Node = main.find_child("ForgeUI", true, false)

	# ─── 상점: 정지 + 키보드 구매 ───
	GameState.gold = 99999
	shop._on_body_entered(party)
	shop._activate() # Space로 열기
	_check(shop_ui.visible and get_tree().paused, "상점 열림 → 세계 정지")

	# 트리: 루트 노드(허브 연결)는 해금 상태 → 클릭 구매 / 잠긴 노드는 구매 거부
	var root: UpgradeData = GameState.catalog[&"core_start"]
	var locked: UpgradeData = GameState.catalog[&"core_first_gold"] # core_start 선행 없이 잠김
	_check(GameState.node_unlocked(root), "허브 연결 루트 노드는 해금")
	_check(not GameState.node_unlocked(locked), "선행 안 산 노드는 경로 잠금")
	_check(not shop_ui._try_buy(locked), "잠긴 노드 구매 거부")
	var owned_before := GameState.owned_count(root)
	_check(shop_ui._try_buy(root), "해금 노드 클릭 구매")
	_check(GameState.owned_count(root) == owned_before + 1, "구매 반영")

	# Space(건물 토글)로 닫기 → 정지 해제
	shop._activate()
	_check(not shop_ui.visible and not get_tree().paused, "Space로 상점 닫힘 → 정지 해제")

	# ─── 대장간: 정지 + 키보드 실행 ───
	GameState.rusty_swords = 1
	GameState.gold = 1000
	GameState.materials[&"stone"] = 20
	GameState.add_material(&"enhance_stone", 3)
	GameState.forge_level = -1
	forge._on_body_entered(party)
	forge._activate() # 대장간 열기
	_check(forge_ui.visible and get_tree().paused, "대장간 열림 → 세계 정지")
	_check(not forge_ui._nav.is_empty(), "대장간 키보드 커서 목록 구성됨")

	# 커서 첫 버튼 = '녹슨 검 올리기' (rusty 1자루 보유) → Enter
	_check(forge_ui._nav[forge_ui._focus] == forge_ui._put, "첫 커서 = 녹슨 검 올리기")
	_key(forge_ui, KEY_ENTER)
	_check(GameState.forge_level == 0, "Enter로 녹슨 검 화로에 올림(+0)")

	# 화로에 검이 올라가면 다음 커서 후보는 '강화' → Enter로 +1
	_check(forge_ui._nav[forge_ui._focus] == forge_ui._enhance, "올린 뒤 커서 = 강화")
	_key(forge_ui, KEY_ENTER)
	_check(GameState.forge_level == 1, "Enter로 강화(+1)")

	# 닫기 → 정지 해제
	forge._activate()
	_check(not forge_ui.visible and not get_tree().paused, "대장간 닫힘 → 정지 해제")

	# ─── 정지 중엔 새 전투가 시작되지 않는다 ───
	GameState.gold = 99999
	shop._on_body_entered(party)
	shop._activate()
	_check(get_tree().paused, "상점 재오픈 → 정지")
	var before := BattleManager.active_battles.size()
	BattleManager._physics_process(0.1) # 정지여도 직접 틱은 돌지만, 시작은 파티가 멈춰 안 일어남
	_check(BattleManager.active_battles.size() == before, "정지 중 전투 수 변화 없음")
	shop._activate()

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
