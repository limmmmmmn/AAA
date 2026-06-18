extends Control
## 몬스터 허가 패널 (검정 JRPG 메뉴창). 우측 MON 슬롯으로 연다.
## 기존 사냥 허가 데이터(hunt_list / monster_catalog)를 그대로 사용 — 새 시스템 아님.
## 일시정지 없음. 행 클릭으로 ON/OFF 토글, Esc/닫기로 닫는다.

@onready var _list: VBoxContainer = $Panel/VBox/List
@onready var _close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	visible = false
	add_to_group("closable_modal") # Esc로 닫히는 모달
	EventBus.request_monsters.connect(_open)
	EventBus.request_close_modals.connect(_close)
	EventBus.hunt_list_changed.connect(func() -> void: if visible: _rebuild())
	EventBus.language_changed.connect(func() -> void: if visible: _rebuild())
	_close_button.pressed.connect(_close)


func _open() -> void:
	visible = true
	_rebuild()


func _close() -> void:
	if not visible:
		return
	visible = false


func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids := GameState.hunt_list.keys()
	if ids.is_empty():
		var empty := Label.new()
		empty.add_theme_font_size_override("font_size", 9)
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		empty.text = "아직 만난 몬스터가 없다"
		_list.add_child(empty)
		return
	for id: StringName in ids:
		_list.add_child(_make_row(id))
	# 자동 철수 토글 (승려 합류 시 해금, v3 §9) — 사냥/전투 설정이라 여기 같이 둔다
	if GameState.tactic_retreat_unlocked:
		var sep := HSeparator.new()
		_list.add_child(sep)
		var rt := Button.new()
		rt.focus_mode = Control.FOCUS_NONE
		rt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		rt.custom_minimum_size = Vector2(196, 18)
		rt.add_theme_font_size_override("font_size", 10)
		_style_retreat(rt)
		rt.pressed.connect(func() -> void:
			GameState.tactic_retreat_enabled = not GameState.tactic_retreat_enabled
			_style_retreat(rt))
		_list.add_child(rt)


## "이름 ............ ON/OFF" 한 줄. 클릭하면 허가 토글.
func _make_row(id: StringName) -> Button:
	var mdata: MonsterData = GameState.monster_catalog.get(id)
	var nm := mdata.display_name if mdata else String(id)
	var row := Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(196, 18)
	row.add_theme_font_size_override("font_size", 10)
	_style_row(row, id, nm)
	row.pressed.connect(func() -> void:
		GameState.set_hunted(id, not GameState.is_hunted(id))
		_style_row(row, id, nm))
	return row


func _style_row(row: Button, id: StringName, nm: String) -> void:
	var on := GameState.is_hunted(id)
	row.text = "%s        %s" % [Locale.t(nm), "ON" if on else "OFF"]
	row.add_theme_color_override("font_color",
		Color(0.85, 0.95, 0.8) if on else Color(0.6, 0.6, 0.6))


func _style_retreat(row: Button) -> void:
	var on := GameState.tactic_retreat_enabled
	row.text = Locale.t("자동 철수        %s") % ("ON" if on else "OFF")
	row.add_theme_color_override("font_color",
		Color(0.95, 0.85, 0.6) if on else Color(0.6, 0.6, 0.6))
