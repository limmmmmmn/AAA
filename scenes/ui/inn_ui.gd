extends Control
## 여관 UI — 상점과 같은 모던 패널. 열리면 세계 정지(필드·전투 멈춤).
## 지금은 [잠자기] 하나: 소지금 일부(inn_cost)를 내고 체력 전량 회복. Enter/클릭으로 실행.

@onready var _title: Label = $Center/Panel/Margin/VBox/HeaderBox/Header/Title
@onready var _gold: Label = $Center/Panel/Margin/VBox/HeaderBox/Header/Gold
@onready var _hp: Label = $Center/Panel/Margin/VBox/Hp
@onready var _info: Label = $Center/Panel/Margin/VBox/Info
@onready var _sleep: Button = $Center/Panel/Margin/VBox/SleepButton
@onready var _close_button: Button = $Center/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # 정지 중에도 입력
	add_to_group("closable_modal") # Esc로 닫히는 모달
	EventBus.request_inn.connect(_open)
	EventBus.request_inn_close.connect(_close)
	EventBus.request_close_modals.connect(_close) # Esc
	EventBus.gold_changed.connect(func(_g: int) -> void: if visible: _refresh())
	EventBus.party_hp_changed.connect(func() -> void: if visible: _refresh())
	EventBus.language_changed.connect(func() -> void: if visible: _refresh())
	_sleep.pressed.connect(_do_sleep)
	_close_button.pressed.connect(_close)


## 여관 패널을 띄우고 세계를 정지시킨다.
func _open() -> void:
	visible = true
	_refresh()
	get_tree().paused = true


## [닫기]/Esc/멀어짐 → 패널을 내리고 정지를 푼다. 여관 버튼 동기화를 위해 inn_closed 통지.
func _close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	EventBus.inn_closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Enter = 잠자기 (Space는 여관 토글이라 충돌 → 제외)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_do_sleep()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var ko := GameState.language == "ko"
	_title.text = "여관" if ko else "INN"
	_gold.text = "GOLD %d" % GameState.gold
	var hp := GameState.total_hp()
	var mx := GameState.total_max_hp()
	_hp.text = "파티 HP  %d / %d" % [hp, mx]
	var cost := GameState.inn_cost()
	if hp >= mx:
		_info.text = "이미 쌩쌩하다. 다음에 오시게."
		_sleep.text = "잠자기"
		_sleep.disabled = true
	elif GameState.gold < cost:
		_info.text = Locale.t("하룻밤 %d G — 돈이 모자라는군.") % cost
		_sleep.text = Locale.t("잠자기  (%d G)") % cost
		_sleep.disabled = true
	else:
		_info.text = "푹 자면 체력이 가득 찬다."
		_sleep.text = Locale.t("잠자기  (%d G)") % cost
		_sleep.disabled = false


func _do_sleep() -> void:
	if GameState.inn_sleep():
		EventBus.show_toast.emit("♪ 푹 잤다! 체력이 가득 찼다.")
		_close()
