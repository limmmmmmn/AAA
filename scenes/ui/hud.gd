extends Control
## 좌상단 골드(미니멀), 좌하단 파티 HP 카드, 우측 Quick Slot Bar, 토스트, 위험 비네트.
## 데이터는 전부 GameState에서 읽는다 (하드코딩 금지).

@onready var _info: Label = $TopInfo
@onready var _members: HBoxContainer = $Members
@onready var _menu_button: Button = $MenuButton
@onready var _slots: VBoxContainer = $QuickSlots
@onready var _vignette: TextureRect = $DangerVignette
@onready var _toast: Label = $ToastLabel

# 파티 멤버 4글자 코드 (캐릭터 데이터에 코드가 없으니 위치 기준 폴백 — 스펙의 기본값)
const MEMBER_CODES := ["HERO", "PRST", "KNIG", "MAGE"]
const PANEL_BG := Color(0.04, 0.04, 0.06, 0.96)
const PANEL_BORDER := Color(0.95, 0.95, 0.95)

var _card_codes: Array[Label] = []
var _card_hps: Array[Label] = []
var _dig_slot: Button = null
var _toast_tween: Tween
var _danger_tween: Tween
var _in_danger: bool = false


func _ready() -> void:
	EventBus.gold_changed.connect(func(_g: int) -> void: _refresh_info())
	EventBus.gems_changed.connect(func(_g: int) -> void: _refresh_info())
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.show_toast.connect(_show_toast)
	EventBus.party_hp_changed.connect(_on_party_hp_changed)
	EventBus.companion_joined.connect(_on_companion_joined)
	EventBus.dig_changed.connect(func() -> void: _update_dig_slot())
	EventBus.debug_mode_changed.connect(func(_on: bool) -> void: _refresh_info())
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.theme_type_variation = &"Bold"
	_info.theme_type_variation = &"Bold" # 골드 = 강조 (굵게)
	_menu_button.pressed.connect(func() -> void: EventBus.request_menu.emit())
	_info.gui_input.connect(_on_gold_input) # 디버그: 골드 라벨 클릭 +100
	_rebuild_members()
	_rebuild_slots()
	_on_party_hp_changed()


func _process(_delta: float) -> void:
	_refresh_info() # 골드/보석/시간 (시간은 매 프레임 갱신)
	if GameState.has_shovel and _dig_slot:
		_update_dig_slot()


# ─── 좌상단 미니멀 정보 (G 360   GEM 2   02:15) ───

func _refresh_info() -> void:
	var t := "GOLD %d" % GameState.gold
	if GameState.gems > 0:
		t += "   GEM %d" % GameState.gems
	var sec := int(GameState.play_time)
	t += "   %02d:%02d" % [sec / 60, sec % 60]
	if GameState.debug_mode:
		t += "   [+100]"
	_info.text = t


## 디버그 모드에서 골드 라벨 좌클릭 → 100골드
func _on_gold_input(event: InputEvent) -> void:
	if not GameState.debug_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.add_gold(100)


# ─── 좌하단 파티 HP 카드 (검정창 + 흰 테두리, 코드 + cur/max) ───

func _member_code(index: int) -> String:
	return MEMBER_CODES[index] if index < MEMBER_CODES.size() else "P%d" % (index + 1)


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.set_border_width_all(2)
	s.border_color = PANEL_BORDER
	s.set_content_margin_all(3)
	return s


func _rebuild_members() -> void:
	for child in _members.get_children():
		_members.remove_child(child)
		child.queue_free()
	_card_codes.clear()
	_card_hps.clear()
	for i in GameState.member_count():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _panel_style())
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.custom_minimum_size = Vector2(48, 0)
		var code := Label.new()
		code.theme_type_variation = &"Bold" # 멤버 코드 = 강조
		code.add_theme_font_size_override("font_size", 9)
		code.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		code.text = _member_code(i)
		var hp := Label.new()
		hp.add_theme_font_size_override("font_size", 11)
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(code)
		vb.add_child(hp)
		card.add_child(vb)
		_members.add_child(card)
		_card_codes.append(code)
		_card_hps.append(hp)
	_refresh_hp()


func _refresh_hp() -> void:
	for i in _card_hps.size():
		var cur := GameState.member_hp(i)
		var mx := GameState.member_max_hp(i)
		_card_hps[i].text = "%d/%d" % [cur, mx]
		var ko := GameState.damage_enabled and cur <= 0
		_card_hps[i].add_theme_color_override("font_color",
			Color(0.8, 0.35, 0.35) if ko else Color(0.95, 0.95, 0.95))


func _on_companion_joined(_comp: CompanionData) -> void:
	_rebuild_members()


# ─── 우측 Quick Slot Bar (해금된 바로가기만 표시) ───

func _on_stats_changed() -> void:
	_rebuild_slots() # 해금 상태(원격상점/자동화/삽)가 바뀌면 슬롯 갱신
	_refresh_info()


## 각 슬롯: {label, shown(해금여부), press}. 스펙의 데이터 기반 렌더 방식.
func _slot_specs() -> Array[Dictionary]:
	return [
		{"label": "MON", "shown": true,
			"press": func() -> void: EventBus.request_monsters.emit()},
		{"label": "SHOP", "shown": GameState.remote_shop_unlocked,
			"press": func() -> void: EventBus.request_shop.emit()},
		{"label": "FORGE", "shown": GameState.auto_enhance or GameState.auto_deliver,
			"press": func() -> void: EventBus.request_forge.emit()},
		{"label": "DIG", "shown": GameState.has_shovel,
			"press": func() -> void: _do_dig()},
	]


func _rebuild_slots() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	_dig_slot = null
	for spec in _slot_specs():
		if not spec["shown"]:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.theme_type_variation = &"Bold" # 슬롯 라벨 = 강조
		b.add_theme_font_size_override("font_size", 9)
		b.text = spec["label"]
		b.pressed.connect(spec["press"])
		_slots.add_child(b)
		if spec["label"] == "DIG":
			_dig_slot = b
	_update_dig_slot()


func _do_dig() -> void:
	var r := GameState.do_dig()
	if not r.ok:
		return
	if r.sparkle:
		_show_toast(Locale.t("✨ 반짝이는 땅에서 %s!") % r.msg)
	elif r.msg != "":
		_show_toast(Locale.t("땅속에서 %s!") % r.msg)
	else:
		_show_toast("아무것도 나오지 않았다...")


## DIG 슬롯 상태색: 쿨타임=어둡게, 반짝임 위=금색, 평소=흰색.
func _update_dig_slot() -> void:
	if _dig_slot == null:
		return
	if not GameState.dig_ready():
		_dig_slot.disabled = true
		_dig_slot.modulate = Color(0.55, 0.55, 0.55)
	elif GameState.has_sparkling_ground and GameState.party_on_sparkle:
		_dig_slot.disabled = false
		_dig_slot.modulate = Color(1, 0.9, 0.4)
	else:
		_dig_slot.disabled = false
		_dig_slot.modulate = Color(1, 1, 1)


# ─── 죽음의 예고 (총 HP ≤ 30%면 붉은 비네트 + 카드 점멸) ───

func _on_party_hp_changed() -> void:
	_refresh_hp()
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


# ─── 토스트 ───

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
