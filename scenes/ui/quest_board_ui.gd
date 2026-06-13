extends Control
## 의뢰 게시판 UI (B-4). 동시 수주 1개. 의뢰 목록은 QuestData .tres에서 자동 생성.
## 진행도는 1지역 kill_count 시스템 재사용.

@onready var _active_label: Label = $Panel/Margin/VBox/ActiveLabel
@onready var _list: VBoxContainer = $Panel/Margin/VBox/QuestList
@onready var _close_button: Button = $Panel/Margin/VBox/CloseButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED # 정지 중에도 조작 가능 (v3 §5)
	EventBus.request_quest_board.connect(_open)
	EventBus.party_exited_village.connect(_close)
	EventBus.quest_accepted.connect(_on_quest_changed)
	EventBus.quest_completed.connect(_on_quest_changed)
	EventBus.monster_died.connect(_on_monster_died)
	_close_button.pressed.connect(_close)


func _open() -> void:
	visible = true
	get_tree().paused = true # 메뉴를 열면 세계가 멈춘다 (v3 §5)
	_rebuild()


func _close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _on_quest_changed(_quest: QuestData) -> void:
	if visible:
		_rebuild()


func _on_monster_died(_data: MonsterData, _pos: Vector2) -> void:
	if visible:
		_refresh_active()


func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for quest in GameState.quests_all():
		_list.add_child(_make_row(quest))
	_refresh_active()


func _make_row(quest: QuestData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 9)
	desc.text = "%s  (보상 %dG)" % [quest.description, quest.reward_gold]
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc)

	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 9)
	btn.custom_minimum_size = Vector2(72, 18)
	if GameState.active_quest_id == quest.id:
		btn.text = "수주중"
		btn.disabled = true
	elif GameState.active_quest_id != &"":
		btn.text = "수주"
		btn.disabled = true # 동시 1개 제한
	else:
		btn.text = "수주"
		btn.pressed.connect(func() -> void: GameState.accept_quest(quest))
	row.add_child(btn)
	return row


func _refresh_active() -> void:
	var q := GameState.active_quest()
	if q == null:
		_active_label.text = "수주 중인 의뢰 없음 — 무엇을 잡을지 정해보자"
	else:
		_active_label.text = "진행 중: %s  [%d / %d]" % [q.description, GameState.quest_progress(), q.target_count]
