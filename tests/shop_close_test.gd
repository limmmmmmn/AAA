extends Node
## 상점: Space로 열고, 멀어지면 닫힌다 (대장간과 동일, 일시정지 없음).
## godot --headless --path . res://tests/ShopCloseTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var field: Node = get_tree().get_first_node_in_group("field")
	var shop: Node = field.find_child("ShopBuilding", true, false)
	var shop_ui: Node = main.find_child("ShopUI", true, false)
	var party: Node = get_tree().get_first_node_in_group("party")

	_check(shop != null and shop_ui != null, "상점 건물/UI 존재")
	_check(not shop_ui.visible, "처음엔 상점 닫혀 있음")

	# 가까이 감 → 프롬프트 표시
	shop._on_body_entered(party)
	_check(shop._in_range, "상점 근처 진입")

	# Space/[열기] → 상점 열림, 일시정지 안 함
	shop._activate()
	_check(shop_ui.visible, "Space로 상점 열림")
	_check(not get_tree().paused, "상점 열려도 일시정지 아님 (계속 이동)")

	# 멀어지면 자동으로 닫힘
	shop._on_body_exited(party)
	_check(not shop_ui.visible, "멀어지면 상점 닫힘")
	_check(not get_tree().paused, "닫힌 뒤에도 정지 아님")

	# 다시 열고 Esc(모달 닫기 요청)로 닫기
	shop._on_body_entered(party)
	shop._activate()
	_check(shop_ui.visible, "다시 열림")
	EventBus.request_close_modals.emit() # Esc 경로
	_check(not shop_ui.visible, "Esc로 상점 닫힘")
	# Esc로 닫혀도 건물 상태 동기화 (다음 Space가 다시 연다)
	shop._activate()
	_check(shop_ui.visible, "Esc로 닫은 뒤 Space로 재오픈")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
