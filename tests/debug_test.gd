extends Node
## 디버그 모드 + 골드 클릭 +100 검증.
## godot --headless --path . res://tests/DebugTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0
var _signal_on := false


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


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud := main.get_node("UILayer/HUD")
	var gold_label: Label = hud.get_node("TopInfo") # 미니멀 골드/정보 라벨 (클릭 시 디버그 +100)
	EventBus.debug_mode_changed.connect(func(on: bool) -> void: _signal_on = on)

	GameState.gold = 0
	_check(not GameState.debug_mode, "기본: 디버그 off")
	gold_label.gui_input.emit(_click())
	_check(GameState.gold == 0, "디버그 off: 골드 클릭 무효")

	GameState.set_debug_mode(true)
	_check(_signal_on and GameState.debug_mode, "디버그 on + 시그널 발신")
	_check(gold_label.text.contains("[+100]"), "디버그 골드 라벨에 [+100] 힌트")

	gold_label.gui_input.emit(_click())
	_check(GameState.gold == 100, "디버그 on: 골드 클릭 +100")
	gold_label.gui_input.emit(_click())
	gold_label.gui_input.emit(_click())
	_check(GameState.gold == 300, "연속 클릭 누적 (+100씩)")

	# 우클릭은 무효
	var rclick := InputEventMouseButton.new()
	rclick.button_index = MOUSE_BUTTON_RIGHT
	rclick.pressed = true
	gold_label.gui_input.emit(rclick)
	_check(GameState.gold == 300, "우클릭은 무효 (좌클릭만)")

	GameState.set_debug_mode(false)
	gold_label.gui_input.emit(_click())
	_check(GameState.gold == 300, "디버그 off 후 클릭 무효")
	_check(not gold_label.text.contains("[+100]"), "디버그 off: 힌트 사라짐")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
