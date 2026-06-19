extends Control
## 좌상단 골드(미니멀), 좌하단 파티 HP 카드, 우측 Quick Slot Bar, 토스트, 위험 비네트.
## 데이터는 전부 GameState에서 읽는다 (하드코딩 금지).

@onready var _info: Label = $TopInfo
@onready var _party_panel: VBoxContainer = $PartyPanel
@onready var _members: HBoxContainer = $PartyPanel/Members
@onready var _menu_button: Button = $MenuButton
@onready var _slots: VBoxContainer = $QuickSlots
@onready var _vignette: TextureRect = $DangerVignette
@onready var _toast: Label = $ToastLabel

# 파티 멤버 4글자 코드 (캐릭터 데이터에 코드가 없으니 위치 기준 폴백 — 스펙의 기본값)
const MEMBER_CODES := ["HERO", "PRST", "KNIG", "MAGE"]
const ROLE_CODES := {&"priest": "PRST", &"warrior": "WARR", &"mage": "MAGE", &"knight": "KNIG"}
const PANEL_BG := Color(0.04, 0.04, 0.06, 0.96)
const PANEL_BORDER := Color(0.95, 0.95, 0.95)
# 우측 퀵슬롯 16x16 아이콘
const ICON_SLIME := preload("res://assets/enemies/slime.png")
const ICON_SHOP := preload("res://assets/objects/shop_1.png")
const ICON_FORGE := preload("res://assets/objects/black_smith.png")

var _card_codes: Array[Label] = []
var _card_hps: Array[Label] = []
var _dig_slot: Button = null
var _auto_slot: Button = null
var _toast_tween: Tween
var _danger_tween: Tween
var _in_danger: bool = false

# 파티 패널 확장(스탯창)
var _stats_box: PanelContainer = null
var _stats_content: VBoxContainer = null   # 스탯 본문 (파티 공통 + 멤버별, 매번 재구성)
var _user_expanded: bool = false    # 사용자가 클릭으로 펼침
var _shop_expanded: bool = false    # 상점 이용 중 자동 펼침
var _stats_tween: Tween


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
	_build_stats_box()
	_members.gui_input.connect(_on_party_clicked) # 파티 패널 클릭 → 스탯창 토글
	# 상점 이용 중엔 자동으로 스탯창 확장 (열림/닫힘 동기화)
	EventBus.request_shop.connect(func() -> void: _set_shop_expanded(true))
	EventBus.shop_closed.connect(func() -> void: _set_shop_expanded(false))
	EventBus.language_changed.connect(_refresh_stats)
	_rebuild_members()
	_rebuild_slots()
	_on_party_hp_changed()
	_apply_expanded(false, false) # 처음엔 접힘


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
	if index == 0:
		return "HERO"
	var ci := index - 1
	if ci < GameState.companions.size(): # 역할 기반 코드 (위치 무관)
		return ROLE_CODES.get(GameState.companions[ci].role, MEMBER_CODES[index] if index < MEMBER_CODES.size() else "P%d" % (index + 1))
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
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE # 클릭은 파티 패널(토글)로 통과
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_refresh_stats()


# ─── 파티 패널 확장: 클릭 시 위로 솟아 스탯 표시 (상점 중엔 자동 확장) ───

func _build_stats_box() -> void:
	_party_panel.custom_minimum_size = Vector2(116, 0) # 접/펼침 가로 폭 일정 (세로로만 자란다)
	_stats_box = PanelContainer.new()
	_stats_box.add_theme_stylebox_override("panel", _panel_style())
	_stats_box.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	# 헤더: 제목 + 닫기(×)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "스탯"
	title.theme_type_variation = &"Bold"
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 12)
	close.custom_minimum_size = Vector2(14, 12)
	close.pressed.connect(func() -> void:
		_user_expanded = false
		_shop_expanded = false
		_update_expanded(true))
	header.add_child(title)
	header.add_child(close)
	vb.add_child(header)
	# 본문 (파티 공통 + 멤버별) — _refresh_stats가 매번 재구성
	_stats_content = VBoxContainer.new()
	_stats_content.add_theme_constant_override("separation", 3)
	vb.add_child(_stats_content)
	_stats_box.add_child(vb)
	_party_panel.add_child(_stats_box)
	_party_panel.move_child(_stats_box, 0) # 멤버 HP 행보다 위로
	_refresh_stats()


func _member_name(index: int) -> String:
	return GameState.config.hero_name if index == 0 else GameState.companions[index - 1].display_name


func _new_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 1)
	return g


## 한 줄: "이름 ........ 값" (이름 회색, 값 강조).
func _stat_row(grid: GridContainer, name: String, value: String, color: Color = Color(1, 0.95, 0.7)) -> void:
	var nm := Label.new()
	nm.text = name
	nm.add_theme_font_size_override("font_size", 9)
	nm.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	var val := Label.new()
	val.theme_type_variation = &"Bold"
	val.add_theme_font_size_override("font_size", 10)
	val.add_theme_color_override("font_color", color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.text = value
	grid.add_child(nm)
	grid.add_child(val)


func _divider() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.4, 0.45, 0.55, 0.6)
	c.custom_minimum_size = Vector2(0, 1)
	return c


## 본문을 현재 상태로 재구성: 파티 공통(속도/회심/방어/전투창) + 멤버별(HP/공격/회복).
func _refresh_stats() -> void:
	if _stats_content == null:
		return
	for c in _stats_content.get_children():
		_stats_content.remove_child(c)
		c.queue_free()

	# 파티 공통
	var party := _new_grid()
	_stat_row(party, "속도", "%d" % int(round(GameState.move_speed)))
	_stat_row(party, "회심", "%d%%" % int(round(GameState.crit_chance * 100.0)))
	_stat_row(party, "방어", "%d%%" % int(round((1.0 - GameState.damage_reduction_mult) * 100.0)))
	_stat_row(party, "전투창", "%d" % GameState.max_battle_windows)
	_stat_row(party, "운", "%d" % GameState.party_luck, Color(0.85, 0.95, 0.5)) # 파티 운 = 멤버 중 최고
	_stats_content.add_child(party)
	_stats_content.add_child(_divider())

	# 멤버별 개별 스탯
	var atks := GameState.member_attacks()
	var lucks := GameState.member_lucks()
	for i in GameState.member_count():
		var nm := Label.new()
		nm.text = _member_name(i)
		nm.theme_type_variation = &"Bold"
		nm.add_theme_font_size_override("font_size", 9)
		nm.add_theme_color_override("font_color",
			Color(0.7, 0.95, 0.7) if i == 0 else Color(0.72, 0.84, 1.0))
		_stats_content.add_child(nm)
		var g := _new_grid()
		var cur := GameState.member_hp(i)
		var mx := GameState.member_max_hp(i)
		var ko := GameState.damage_enabled and cur <= 0
		_stat_row(g, "HP", "%d/%d" % [cur, mx], Color(0.85, 0.4, 0.4) if ko else Color(0.95, 0.95, 0.95))
		_stat_row(g, "공격", "%d" % (atks[i] if i < atks.size() else 0))
		_stat_row(g, "운", "%d" % (lucks[i] if i < lucks.size() else 0), Color(0.85, 0.95, 0.5))
		if i > 0:
			var comp: CompanionData = GameState.companions[i - 1]
			if comp.heal_per_turn > 0:
				_stat_row(g, "회복", "%d/턴" % comp.heal_per_turn, Color(0.7, 1.0, 0.78))
		_stats_content.add_child(g)

	if _stats_box: # 아래 끝 기준으로 솟아오르게 회전축을 바닥에 둔다
		_stats_box.pivot_offset = Vector2(0, _stats_box.get_combined_minimum_size().y)


## 파티 HP 행 클릭 → 스탯창 토글.
func _on_party_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_user_expanded = not _user_expanded
		_update_expanded(true)


func _set_shop_expanded(on: bool) -> void:
	_shop_expanded = on
	_update_expanded(true)


func _update_expanded(animate: bool) -> void:
	_apply_expanded(_user_expanded or _shop_expanded, animate)


## 스탯창을 펼치거나 접는다. 펼침은 바닥 기준으로 위로 솟는다(세로 스케일).
func _apply_expanded(on: bool, animate: bool) -> void:
	if _stats_box == null:
		return
	if get_tree().paused:
		animate = false # 상점 등 정지 중엔 트윈이 멈추므로 즉시 적용 (자동 확장 깨짐 방지)
	if _stats_tween and _stats_tween.is_valid():
		_stats_tween.kill()
	if on:
		_refresh_stats()
		_stats_box.visible = true
		if animate:
			_stats_box.scale = Vector2(1, 0.0)
			_stats_box.modulate.a = 0.0
			_stats_tween = create_tween()
			_stats_tween.tween_property(_stats_box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_stats_tween.parallel().tween_property(_stats_box, "modulate:a", 1.0, 0.14)
		else:
			_stats_box.scale = Vector2.ONE
			_stats_box.modulate.a = 1.0
	else:
		if animate and _stats_box.visible:
			_stats_tween = create_tween()
			_stats_tween.tween_property(_stats_box, "scale:y", 0.0, 0.15).set_ease(Tween.EASE_IN)
			_stats_tween.parallel().tween_property(_stats_box, "modulate:a", 0.0, 0.15)
			_stats_tween.tween_callback(func() -> void:
				_stats_box.visible = false
				_stats_box.scale = Vector2.ONE
				_stats_box.modulate.a = 1.0)
		else:
			_stats_box.visible = false


# ─── 우측 Quick Slot Bar (해금된 바로가기만 표시) ───

func _on_stats_changed() -> void:
	_rebuild_slots() # 해금 상태(원격상점/자동화/삽)가 바뀌면 슬롯 갱신
	_refresh_info()
	_refresh_stats()


## 각 슬롯: {id, icon?/text?/toggle?, shown, press}. 16x16 컴팩트 버튼.
func _slot_specs() -> Array[Dictionary]:
	return [
		{"id": "auto", "toggle": true, "shown": GameState.auto_hunt_unlocked, # 자동이동 스킬 배우면 등장
			"press": func() -> void: _toggle_auto()},
		{"id": "mon", "icon": ICON_SLIME, "shown": true,     # 몬스터 패널 (슬라임 아이콘)
			"press": func() -> void: EventBus.request_monsters.emit()},
		{"id": "shop", "icon": ICON_SHOP, "shown": GameState.remote_shop_unlocked,
			"press": func() -> void: EventBus.request_shop.emit()},
		{"id": "forge", "icon": ICON_FORGE, "shown": GameState.auto_enhance or GameState.auto_deliver,
			"press": func() -> void: EventBus.request_forge.emit()},
		{"id": "dig", "text": "파기", "shown": GameState.has_shovel,
			"press": func() -> void: _do_dig()},
	]


## 16x16 슬롯 버튼 스타일 (어두운 칸 + 옅은 테두리).
func _slot_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(1)
	s.border_color = Color(0.55, 0.6, 0.7)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(1)
	return s


func _rebuild_slots() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	_dig_slot = null
	_auto_slot = null
	for spec in _slot_specs():
		if not spec["shown"]:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(20, 20)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END # 우측 정렬, 20폭 유지
		b.clip_contents = true # 아이콘이 버튼 밖으로 안 넘치게 (균일 20x20)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _slot_style(Color(0.08, 0.09, 0.12, 0.95)))
		b.add_theme_stylebox_override("hover", _slot_style(Color(0.16, 0.18, 0.24, 0.98)))
		b.add_theme_stylebox_override("pressed", _slot_style(Color(0.2, 0.22, 0.3, 1)))
		b.add_theme_stylebox_override("disabled", _slot_style(Color(0.06, 0.06, 0.08, 0.85)))
		if spec.has("icon"):
			b.icon = spec["icon"]
			b.expand_icon = true # 아이콘을 16x16에 맞춰 축소
		else:
			b.theme_type_variation = &"Bold"
			b.add_theme_font_size_override("font_size", 8 if spec.has("text") else 11)
			b.text = spec.get("text", "▶")
		b.pressed.connect(spec["press"])
		_slots.add_child(b)
		if spec["id"] == "dig":
			_dig_slot = b
		elif spec["id"] == "auto":
			_auto_slot = b
	_update_auto_slot()
	_update_dig_slot()


## 자동 이동 토글 → 켜고 끄기 + 버튼 색 갱신.
func _toggle_auto() -> void:
	GameState.auto_move_on = not GameState.auto_move_on
	_update_auto_slot()
	_show_toast("자동 이동 %s" % ("ON" if GameState.auto_move_on else "OFF"))


## 자동 이동 버튼 상태색 (켜짐=초록, 꺼짐=회색).
func _update_auto_slot() -> void:
	if _auto_slot == null:
		return
	_auto_slot.modulate = Color(0.55, 1.0, 0.6) if GameState.auto_move_on else Color(0.55, 0.55, 0.6)


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
