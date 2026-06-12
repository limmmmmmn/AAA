extends Control
## 골드, 활성 전투창 수, EXP 표시 + 토스트 메시지.

@onready var _time_label: Label = $TopBar/HBox/TimeLabel
@onready var _gold_label: Label = $TopBar/HBox/GoldLabel
@onready var _battle_label: Label = $TopBar/HBox/BattleLabel
@onready var _exp_label: Label = $TopBar/HBox/ExpLabel
@onready var _hp_box: PanelContainer = $HPBox
@onready var _hp_bar: ProgressBar = $HPBox/HPInner/HPBar
@onready var _remote_shop_button: Button = $RemoteShopButton
@onready var _toast: Label = $ToastLabel

var _toast_tween: Tween


func _ready() -> void:
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.stats_changed.connect(_refresh)
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.show_toast.connect(_show_toast)
	EventBus.shared_hp_changed.connect(_on_shared_hp_changed)
	_remote_shop_button.pressed.connect(func() -> void: EventBus.party_entered_village.emit())
	_refresh()
	if GameState.damage_enabled: # 세이브 로드로 2지역 상태면 즉시 표시
		_on_shared_hp_changed(GameState.shared_hp, GameState.shared_hp_max)


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


func _on_shared_hp_changed(current: int, maximum: int) -> void:
	if not _hp_box.visible:
		# 2지역 진입 시 등장 연출
		_hp_box.visible = true
		_hp_box.modulate.a = 0.0
		create_tween().tween_property(_hp_box, "modulate:a", 1.0, 0.4)
	_hp_bar.max_value = maximum
	_hp_bar.value = current


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
