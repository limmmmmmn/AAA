extends Node
## 파티 패널 확장: 클릭 토글 + 스탯 표시 + 상점 자동 확장 + 닫기.
## godot --headless --path . res://tests/HudPanelTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


## 스탯 본문의 모든 Label 텍스트 수집 (재귀).
func _label_texts(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Label:
			out.append(c.text)
		out.append_array(_label_texts(c))
	return out


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: Node = main.find_child("HUD", true, false)
	var box: Control = hud._stats_box

	_check(box != null and not box.visible, "처음엔 스탯창 접힘")

	# 클릭 → 펼침 + 스탯 값 표시
	hud._on_party_clicked(_click())
	_check(hud._user_expanded and box.visible, "클릭 → 위로 펼침")
	var texts := _label_texts(hud._stats_content)
	_check("속도" in texts and "회심" in texts and "전투창" in texts, "파티 공통 스탯 표시")
	_check(GameState.config.hero_name in texts, "멤버: 용사 이름 표시")
	_check(("%d" % GameState.member_attacks()[0]) in texts, "용사 개별 공격력 표시")

	# 다시 클릭 → 접힘 (애니 종료 후 숨김)
	hud._on_party_clicked(_click())
	_check(not hud._user_expanded, "다시 클릭 → 접기 요청")
	await get_tree().create_timer(0.25).timeout
	_check(not box.visible, "접힘 애니 후 숨김")

	# 상점 열기 → 자동 확장, 닫기 → 자동 접힘
	hud._set_shop_expanded(true)
	_check(box.visible, "상점 이용 중 자동 확장")
	hud._set_shop_expanded(false)
	await get_tree().create_timer(0.25).timeout
	_check(not box.visible, "상점 닫으면 자동 접힘")

	# 사용자가 펼친 상태면 상점 닫혀도 유지
	hud._on_party_clicked(_click()) # 사용자 펼침
	hud._set_shop_expanded(true)
	hud._set_shop_expanded(false)
	_check(box.visible, "사용자가 펼쳐둔 건 상점 닫혀도 유지")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
