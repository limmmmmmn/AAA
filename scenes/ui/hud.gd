extends Control
## 골드, 활성 전투창 수, EXP 표시 + 토스트 메시지 + 멤버별 HP 표시(A-3).

@onready var _time_label: Label = $TopBar/HBox/TimeLabel
@onready var _gold_label: Label = $TopBar/HBox/GoldLabel
@onready var _gem_label: Label = $TopBar/HBox/GemLabel
@onready var _battle_label: Label = $TopBar/HBox/BattleLabel
@onready var _exp_label: Label = $TopBar/HBox/ExpLabel
@onready var _hp_box: PanelContainer = $HPBox
@onready var _members: HBoxContainer = $HPBox/HPInner/Members
@onready var _remote_shop_button: Button = $RemoteShopButton
@onready var _menu_button: Button = $MenuButton
@onready var _hunt_panel: PanelContainer = $HuntPanel
@onready var _hunt_list: VBoxContainer = $HuntPanel/VBox/HuntList
@onready var _retreat_toggle: CheckButton = $HuntPanel/VBox/RetreatToggle
@onready var _vignette: TextureRect = $DangerVignette
@onready var _dig_button: Button = $DigButton
@onready var _toast: Label = $ToastLabel

var _member_bars: Array[ProgressBar] = []
var _member_labels: Array[Label] = []
var _member_names: Array[String] = []
var _toast_tween: Tween
var _danger_tween: Tween
var _in_danger: bool = false


func _ready() -> void:
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.stats_changed.connect(_refresh)
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.show_toast.connect(_show_toast)
	EventBus.party_hp_changed.connect(_on_party_hp_changed)
	EventBus.gems_changed.connect(func(_g: int) -> void: _refresh())
	EventBus.hunt_list_changed.connect(_rebuild_hunt_list)
	EventBus.companion_joined.connect(_on_companion_joined)
	_remote_shop_button.pressed.connect(func() -> void: EventBus.party_entered_village.emit())
	_menu_button.pressed.connect(func() -> void: EventBus.request_menu.emit())
	_retreat_toggle.toggled.connect(func(on: bool) -> void: GameState.tactic_retreat_enabled = on)
	_dig_button.pressed.connect(_on_dig_pressed)
	_dig_button.focus_mode = Control.FOCUS_NONE # Space는 상호작용 전용 (땅파기 재발동 방지)
	EventBus.dig_changed.connect(_refresh_dig)
	_gold_label.gui_input.connect(_on_gold_input)              # 디버그: 골드 클릭 +100
	EventBus.debug_mode_changed.connect(func(_on: bool) -> void: _refresh())
	_refresh()
	_refresh_dig()
	_rebuild_hunt_list()
	# 1지역에서도 HP를 보여준다 (용사 한 칸, damage off라 줄지 않음)
	_rebuild_members()
	_on_party_hp_changed()


# ─── 멤버별 개별 HP 표시 ───
## 각 멤버가 자기 HP 바를 갖는다. 적은 멤버 1명을 노려 그 멤버 HP를 깎는다.

func _on_companion_joined(_comp: CompanionData) -> void:
	_refresh()
	_rebuild_members()
	_refresh_hp()


func _rebuild_members() -> void:
	for child in _members.get_children():
		_members.remove_child(child)
		child.queue_free()
	_member_bars.clear()
	_member_labels.clear()
	_member_names.clear()
	for m in GameState.party_members():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(46, 9)
		bar.show_percentage = false
		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 7)
		name_label.text = m.name
		name_label.modulate = Color(0.85, 0.85, 0.85)
		col.add_child(bar)
		col.add_child(name_label)
		_members.add_child(col)
		_member_bars.append(bar)
		_member_labels.append(name_label)
		_member_names.append(m.name)


## 멤버별 개별 HP를 각자 바에 그린다. HP 0이면 "쓰러짐".
func _refresh_hp() -> void:
	for i in _member_bars.size():
		_member_bars[i].max_value = maxi(1, GameState.member_max_hp(i))
		_member_bars[i].value = GameState.member_hp(i)
		if GameState.damage_enabled and GameState.member_hp(i) <= 0:
			_member_labels[i].text = "쓰러짐"
			_member_labels[i].modulate = Color(0.7, 0.35, 0.35)
		else:
			_member_labels[i].text = _member_names[i]
			_member_labels[i].modulate = Color(0.85, 0.85, 0.85)


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
	if GameState.has_shovel:
		_refresh_dig() # 쿨타임 카운트다운 갱신


# ─── 땅파기 (삽 보유 시 노출) ───

func _on_dig_pressed() -> void:
	var r := GameState.do_dig()
	if not r.ok:
		return
	if r.sparkle:
		_show_toast("✨ 반짝이는 땅에서 %s!" % r.msg)
	elif r.msg != "":
		_show_toast("땅속에서 %s!" % r.msg)
	else:
		_show_toast("아무것도 나오지 않았다...")


func _refresh_dig() -> void:
	_dig_button.visible = GameState.has_shovel
	if not GameState.has_shovel:
		return
	if not GameState.dig_ready():
		_dig_button.disabled = true
		_dig_button.text = "땅파기 (%s)" % TownFmt.time(GameState.dig_remaining())
		_dig_button.modulate = Color(1, 1, 1)
	elif GameState.has_sparkling_ground and GameState.party_on_sparkle:
		_dig_button.disabled = false
		_dig_button.text = "✨ 반짝임! 파기"
		_dig_button.modulate = Color(1, 0.95, 0.5)
	else:
		_dig_button.disabled = false
		_dig_button.text = "땅파기"
		_dig_button.modulate = Color(1, 1, 1)


func _on_gold_changed(_amount: int) -> void:
	_refresh()


func _on_battle_started(_battle: BattleInstance) -> void:
	_refresh()


func _on_battle_ended(_battle: BattleInstance, _result: Dictionary) -> void:
	_refresh()


## 디버그 모드에서 골드 라벨 좌클릭 → 100골드 획득
func _on_gold_input(event: InputEvent) -> void:
	if not GameState.debug_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.add_gold(100)


func _refresh() -> void:
	_gold_label.text = "골드: %d G  [+100]" % GameState.gold if GameState.debug_mode else "골드: %d G" % GameState.gold
	_gem_label.text = "보석: %d" % GameState.gems
	_battle_label.text = "전투: %d / %d" % [BattleManager.active_battles.size(), GameState.max_battle_windows]
	_exp_label.text = "EXP: %d   격파: %d" % [GameState.total_exp, GameState.total_battles_won]
	_remote_shop_button.visible = GameState.remote_shop_unlocked # 주문 카탈로그 (B-6)
	_retreat_toggle.visible = GameState.tactic_retreat_unlocked   # 자동 철수 (v3 §9)
	_refresh_dig()                                               # 삽 구매 시 버튼 노출


func _on_party_hp_changed() -> void:
	_refresh_hp()
	# 죽음의 예고 (v3 §7): 파티 총 HP ≤ 30%면 붉은 비네트 + HP바 점멸
	var cur := GameState.total_hp()
	var ratio := float(cur) / float(maxi(1, GameState.total_max_hp()))
	var danger := GameState.damage_enabled and cur > 0 and ratio <= 0.3
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
	_danger_tween.parallel().tween_property(_members, "modulate:a", 0.3, 0.5)
	_danger_tween.tween_property(_vignette, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
	_danger_tween.parallel().tween_property(_members, "modulate:a", 1.0, 0.5)


func _exit_danger() -> void:
	_in_danger = false
	if _danger_tween:
		_danger_tween.kill()
		_danger_tween = null
	_vignette.modulate.a = 0.0
	_members.modulate.a = 1.0


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
