extends Control
## 게임 메뉴 (일시정지). Esc 또는 HUD "메뉴" 버튼으로 연다.
## "처음부터 다시하기" = 세이브 삭제 + 상태 초기화 + 씬 리로드 (확인 팝업 필수 — 되돌릴 수 없음).

@onready var _restart_button: Button = $Panel/Margin/VBox/RestartButton
@onready var _close_button: Button = $Panel/Margin/VBox/CloseButton
@onready var _debug_toggle: CheckButton = $Panel/Margin/VBox/DebugToggle
@onready var _confirm: ConfirmationDialog = $ConfirmRestart


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # 정지 토글을 직접 다루므로 항상 입력 처리
	_restart_button.pressed.connect(_on_restart_pressed)
	_close_button.pressed.connect(_close)
	_debug_toggle.toggled.connect(func(on: bool) -> void: GameState.set_debug_mode(on))
	_confirm.confirmed.connect(_on_confirm_restart)
	EventBus.request_menu.connect(_toggle)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # Esc
		if _handle_escape():
			get_viewport().set_input_as_handled()


## Esc 한 방으로: 메뉴 열려 있으면 닫고, 다른 모달이 열려 있으면 그걸 닫고,
## 아무것도 없으면(필드) 메뉴를 연다. 처리했으면 true.
func _handle_escape() -> bool:
	if visible:
		_close()
		return true
	var open_modals := get_tree().get_nodes_in_group("closable_modal").filter(
		func(m: Node) -> bool: return m.visible)
	if not open_modals.is_empty(): # 상점/대장간/게시판 등 → 닫기
		EventBus.request_close_modals.emit()
		return true
	if get_tree().paused: # 여관 팝업 등 다른 정지 요소는 스스로 Esc 처리하게 둔다
		return false
	_open() # 필드에서 Esc → 메뉴
	return true


func _toggle() -> void: # HUD "메뉴" 버튼용
	if visible:
		_close()
	elif not get_tree().paused:
		_open()


func _open() -> void:
	visible = true
	_debug_toggle.set_pressed_no_signal(GameState.debug_mode) # 현재 상태 반영
	get_tree().paused = true


func _close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _on_restart_pressed() -> void:
	_confirm.popup_centered()


func _on_confirm_restart() -> void:
	get_tree().paused = false
	GameState.reset_to_new_game()
	get_tree().reload_current_scene() # Main을 새로 구성 → 1지역부터 다시 시작
