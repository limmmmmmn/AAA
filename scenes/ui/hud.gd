extends Control
## 골드, 활성 전투창 수, EXP 표시 + 토스트 메시지.

@onready var _time_label: Label = $TopBar/HBox/TimeLabel
@onready var _gold_label: Label = $TopBar/HBox/GoldLabel
@onready var _battle_label: Label = $TopBar/HBox/BattleLabel
@onready var _exp_label: Label = $TopBar/HBox/ExpLabel
@onready var _hp_box: PanelContainer = $HPBox
@onready var _hp_bar: ProgressBar = $HPBox/HPInner/HPBar
@onready var _remote_shop_button: Button = $RemoteShopButton
@onready var _hunt_panel: PanelContainer = $HuntPanel
@onready var _hunt_list: VBoxContainer = $HuntPanel/VBox/HuntList
@onready var _retreat_toggle: CheckButton = $HuntPanel/VBox/RetreatToggle
@onready var _vignette: TextureRect = $DangerVignette
@onready var _toast: Label = $ToastLabel

var _toast_tween: Tween
var _danger_tween: Tween
var _in_danger: bool = false


func _ready() -> void:
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.stats_changed.connect(_refresh)
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.show_toast.connect(_show_toast)
	EventBus.shared_hp_changed.connect(_on_shared_hp_changed)
	EventBus.hunt_list_changed.connect(_rebuild_hunt_list)
	EventBus.companion_joined.connect(func(_c: CompanionData) -> void: _refresh())
	_remote_shop_button.pressed.connect(func() -> void: EventBus.party_entered_village.emit())
	_retreat_toggle.toggled.connect(func(on: bool) -> void: GameState.tactic_retreat_enabled = on)
	_refresh()
	_rebuild_hunt_list()
	if GameState.damage_enabled: # 세이브 로드로 2지역 상태면 즉시 표시
		_on_shared_hp_changed(GameState.shared_hp, GameState.shared_hp_max)


# ─── 사냥 허가 리스트 (v3 §8) ───

func _rebuild_hunt_list() -> void:
	for child in _hunt_list.get_children():
		_hunt_list.remove_child(child)
		child.queue_free()
	var ids := GameState.hunt_list.keys()
	for id: StringName in ids:
		var cb := CheckBox.new()
		cb.add_theme_font_size_override("font_size", 9)
		var mdata: MonsterData = GameState.monster_catalog.get(id)
		cb.text = mdata.display_name if mdata else String(id)
		cb.button_pressed = GameState.is_hunted(id)
		cb.toggled.connect(func(on: bool) -> void: GameState.set_hunted(id, on))
		_hunt_list.add_child(cb)
	_hunt_panel.visible = not ids.is_empty()


func _process(_delta: float) -> void:
	# 밸런스 검증용 누적 플레이 시간 (mm:ss, 1시간 넘으면 h:mm:ss)
	var total := int(GameState.play_time)
	if total >= 3600:
		_time_label.text = "%d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]
	else:
		_time_label.text = "%02d:%02d" % [total / 60, total % 60]


func _on_gold_changed(_amount: int) -> void:
	_refresh()


func _on_battle_started(_battle: BattleInstance) -> void:
	_refresh()


func _on_battle_ended(_battle: BattleInstance, _result: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	_gold_label.text = "골드: %d G" % GameState.gold
	_battle_label.text = "전투: %d / %d" % [BattleManager.active_battles.size(), GameState.max_battle_windows]
	_exp_label.text = "EXP: %d   격파: %d" % [GameState.total_exp, GameState.total_battles_won]
	_remote_shop_button.visible = GameState.remote_shop_unlocked # 주문 카탈로그 (B-6)
	_retreat_toggle.visible = GameState.tactic_retreat_unlocked   # 자동 철수 (v3 §9)


func _on_shared_hp_changed(current: int, maximum: int) -> void:
	if not _hp_box.visible:
		# 2지역 진입 시 등장 연출
		_hp_box.visible = true
		_hp_box.modulate.a = 0.0
		create_tween().tween_property(_hp_box, "modulate:a", 1.0, 0.4)
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	# 죽음의 예고 (v3 §7): HP ≤ 30%면 붉은 비네트 + HP바 점멸
	var ratio := float(current) / float(maxi(1, maximum))
	var danger := GameState.damage_enabled and current > 0 and ratio <= 0.3
	if danger and not _in_danger:
		_enter_danger()
	elif not danger and _in_danger:
		_exit_danger()


func _enter_danger() -> void:
	_in_danger = true
	if _danger_tween:
		_danger_tween.kill()
	_danger_tween = create_tween().set_loops()
	_danger_tween.tween_property(_vignette, "modulate:a", 0.85, 0.5).set_trans(Tween.TRANS_SINE)
	_danger_tween.parallel().tween_property(_hp_bar, "modulate:a", 0.3, 0.5)
	_danger_tween.tween_property(_vignette, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
	_danger_tween.parallel().tween_property(_hp_bar, "modulate:a", 1.0, 0.5)


func _exit_danger() -> void:
	_in_danger = false
	if _danger_tween:
		_danger_tween.kill()
		_danger_tween = null
	_vignette.modulate.a = 0.0
	_hp_bar.modulate.a = 1.0


func _show_toast(text: String) -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)
