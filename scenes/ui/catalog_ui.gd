extends Control
## 비정지 카탈로그 (R5) — 게임은 뒤에서 계속 돈다. HUD 카탈로그 슬롯/Esc로 토글.
## 탭: 구매 · 파티 · 트링켓 · 이동(지역) · 도감(몬스터). R1~R4 시스템을 한 패널로 묶는다.
## 일시정지하지 않는다(get_tree().paused 안 건드림) — "돈 되면 산다" 루프를 멈추지 않으려고.

const ROLE_LABELS := {&"hero": "용사", &"warrior": "전사", &"mage": "마법사", &"priest": "힐러"}

var _tabs: TabContainer
var _panel: Panel
var _bodies: Dictionary = {} # tab key -> VBoxContainer
var _refresh_accum := 0.0


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE # 패널 밖은 게임으로 입력 통과 (비정지)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("closable_modal")
	_build()
	_center_panel()
	get_viewport().size_changed.connect(_center_panel)
	EventBus.request_catalog.connect(_toggle)
	EventBus.request_close_modals.connect(func() -> void: if visible: _close())
	EventBus.upgrade_purchased.connect(func(_u: Variant) -> void: _refresh_if_open())
	EventBus.companion_joined.connect(func(_c: Variant) -> void: _refresh_if_open())
	EventBus.region_changed.connect(func(_r: Variant) -> void: _refresh_if_open())
	EventBus.language_changed.connect(_refresh_if_open)


func _build() -> void:
	# 고정 크기 Panel(비-컨테이너 — 콘텐츠로 팽창하지 않음). 위치/크기는 _center_panel에서 명시 설정.
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = panel
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 0.98)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.45, 0.6)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "카탈로그"
	title.theme_type_variation = &"Bold"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close)
	header.add_child(close)
	vbox.add_child(header)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)
	for spec in [["buy", "구매"], ["party", "파티"], ["trinket", "트링켓"], ["travel", "이동"], ["bestiary", "도감"]]:
		var scroll := ScrollContainer.new()
		scroll.name = String(spec[0])
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED # 세로만 — 행이 패널 폭에 맞게
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 3)
		scroll.add_child(body)
		_tabs.add_child(scroll)
		_tabs.set_tab_title(_tabs.get_tab_count() - 1, Locale.t(spec[1]))
		_bodies[spec[0]] = body


## 패널을 뷰포트 중앙에 명시적으로 배치 (컨테이너 사이징에 의존하지 않음).
func _center_panel() -> void:
	if _panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var sz := Vector2(minf(612, vp.x - 16), minf(340, vp.y - 16))
	_panel.size = sz
	_panel.position = ((vp - sz) * 0.5).floor()


func _toggle() -> void:
	visible = not visible
	if visible:
		_center_panel()
		_refresh_all()


func _close() -> void:
	visible = false


func _refresh_if_open(_a: Variant = null) -> void:
	if visible:
		_refresh_all()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_accum += delta
	if _refresh_accum >= 0.5: # 골드/가용 갱신 (라이브)
		_refresh_accum = 0.0
		_refresh_buy()
		_refresh_travel()


func _refresh_all() -> void:
	_refresh_buy()
	_refresh_party()
	_refresh_trinket()
	_refresh_travel()
	_refresh_bestiary()


# ─── 공통 위젯 ───

func _clear(body: VBoxContainer) -> void:
	for c in body.get_children():
		c.queue_free()


func _section(body: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"Bold"
	l.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	body.add_child(l)


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h


func _label(text: String, expand := false, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	if enabled:
		b.pressed.connect(cb)
	return b


# ─── 탭: 구매 (살 수 있는 업그레이드) ───

func _refresh_buy() -> void:
	var body: VBoxContainer = _bodies["buy"]
	_clear(body)
	var list: Array = []
	for up: UpgradeData in GameState.catalog.values():
		if GameState.owned_count(up) >= up.max_purchases:
			continue
		if not GameState.node_unlocked(up):
			continue
		list.append(up)
	list.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool:
		return GameState.current_cost(a) < GameState.current_cost(b))
	if list.is_empty():
		body.add_child(_label(Locale.t("지금 살 수 있는 항목이 없습니다."), false, Color(0.7, 0.7, 0.7)))
		return
	_section(body, Locale.t("살 수 있는 업그레이드 (%d)") % list.size())
	for up: UpgradeData in list:
		var cost := GameState.current_cost(up)
		var afford := GameState.gold >= cost
		var h := _row()
		h.add_child(_label(Locale.t(up.display_name), true, Color.WHITE if afford else Color(0.6, 0.6, 0.65)))
		h.add_child(_label("%dG" % cost, false, Color(1, 0.9, 0.4) if afford else Color(0.6, 0.55, 0.4)))
		h.add_child(_button(Locale.t("구매"), func() -> void:
			if GameState.purchase(up):
				_refresh_all(), afford))
		body.add_child(h)


# ─── 탭: 파티 (멤버 + HP + 트링켓) ───

func _refresh_party() -> void:
	var body: VBoxContainer = _bodies["party"]
	_clear(body)
	_section(body, Locale.t("파티 (%d / %d)") % [GameState.member_count(), GameState.MAX_PARTY_SIZE])
	var roles := GameState.member_roles()
	var members := GameState.party_members()
	for i in members.size():
		var role: StringName = roles[i] if i < roles.size() else &""
		var h := _row()
		h.add_child(_label(String(members[i].get("name", "?")), true))
		h.add_child(_label(String(ROLE_LABELS.get(role, role)), false, Color(0.6, 0.85, 1.0)))
		h.add_child(_label("HP %d" % GameState.member_max_hp_for(i), false, Color(0.6, 1.0, 0.6)))
		var trks: Array = GameState.member_trinkets.get(role, [])
		var tnames := ""
		for tid: StringName in trks:
			var trk: TrinketData = GameState.trinket_catalog.get(tid)
			if trk != null:
				tnames += ("  ◆ " + Locale.t(trk.display_name))
		h.add_child(_label(tnames if tnames != "" else Locale.t("(트링켓 없음)"), false, Color(0.8, 0.7, 1.0)))
		body.add_child(h)


# ─── 탭: 트링켓 (보유 + 멤버 수동 장착) ───

func _refresh_trinket() -> void:
	var body: VBoxContainer = _bodies["trinket"]
	_clear(body)
	if not bool(GameState.stat("trinkets_enabled")):
		body.add_child(_label(Locale.t("트링켓 시스템을 먼저 해금하세요."), false, Color(0.7, 0.7, 0.7)))
		return
	var roles := GameState.member_roles()
	_section(body, Locale.t("멤버 장착 (슬롯 %d/명)") % GameState.trinket_slots())
	for role: StringName in roles:
		var trks: Array = GameState.member_trinkets.get(role, [])
		var names := ""
		for tid: StringName in trks:
			var trk: TrinketData = GameState.trinket_catalog.get(tid)
			if trk != null:
				names += (Locale.t(trk.display_name) + "  ")
		body.add_child(_label("• %s: %s" % [ROLE_LABELS.get(role, role), names if names != "" else "—"], false, Color(0.85, 0.8, 1.0)))
	body.add_child(_button(Locale.t("자동 배치로"), func() -> void:
		GameState.clear_manual_trinkets()
		_refresh_all()))
	_section(body, Locale.t("보유 트링켓 — 장착할 멤버를 누르세요"))
	if GameState.owned_trinkets.is_empty():
		body.add_child(_label(Locale.t("아직 발견한 트링켓이 없습니다."), false, Color(0.7, 0.7, 0.7)))
		return
	for tid: StringName in GameState.owned_trinkets:
		var trk: TrinketData = GameState.trinket_catalog.get(tid)
		if trk == null:
			continue
		var holder := _trinket_holder(tid)
		var h := _row()
		h.add_child(_label(Locale.t(trk.display_name), true))
		for role: StringName in roles:
			var on := holder == role
			h.add_child(_button(("●" if on else "") + String(ROLE_LABELS.get(role, role)),
				func() -> void:
					GameState.equip_trinket_on(role, tid)
					_refresh_all()))
		body.add_child(h)


func _trinket_holder(tid: StringName) -> StringName:
	for role: StringName in GameState.member_trinkets:
		if tid in GameState.member_trinkets[role]:
			return role
	return &""


# ─── 탭: 이동 (지역 — 마을 안에서만) ───

func _refresh_travel() -> void:
	var body: VBoxContainer = _bodies["travel"]
	_clear(body)
	var in_town: bool = GameState.party_in_town
	_section(body, Locale.t("지역 이동 — %s") % (Locale.t("마을 안") if in_town else Locale.t("마을 밖(이동은 마을에서)")))
	var regions := GameState.unlocked_regions.duplicate()
	regions.sort_custom(func(a: StringName, b: StringName) -> bool:
		return GameState._stage_index_of(a) < GameState._stage_index_of(b))
	for rid: StringName in regions:
		var cur := rid == GameState.current_region
		var h := _row()
		h.add_child(_label(("● " if cur else "○ ") + GameState.stage_display_name(rid), true,
			Color(1, 0.95, 0.6) if cur else Color.WHITE))
		if cur:
			h.add_child(_label(Locale.t("현재 위치"), false, Color(0.7, 0.9, 0.7)))
		elif in_town:
			h.add_child(_button(Locale.t("이동"), func() -> void:
				var r := GameState.travel_to_region(rid)
				EventBus.show_toast.emit(r.get("msg", ""))
				_refresh_all()))
		elif GameState.auto_hunt_unlocked:
			h.add_child(_button(Locale.t("예약"), func() -> void:
				var r := GameState.reserve_travel(rid)
				EventBus.show_toast.emit(r.get("msg", ""))))
		else:
			h.add_child(_label(Locale.t("마을에서"), false, Color(0.6, 0.6, 0.6)))
		body.add_child(h)


# ─── 탭: 도감 (발견한 몬스터) ───

func _refresh_bestiary() -> void:
	var body: VBoxContainer = _bodies["bestiary"]
	_clear(body)
	var ids: Array = GameState.monster_defs.keys()
	ids.sort()
	var found := 0
	for id: StringName in ids:
		if GameState.is_monster_discovered(id):
			found += 1
	_section(body, Locale.t("몬스터 도감 (%d / %d)") % [found, ids.size()])
	for id: StringName in ids:
		var mon: MonsterData = GameState.monster_defs[id]
		var h := _row()
		if GameState.is_monster_discovered(id):
			var tag := ""
			if mon.boss:
				tag = " ♛"
			elif mon.rare:
				tag = " ★"
			h.add_child(_label(Locale.t(mon.display_name) + tag, true))
			h.add_child(_label("HP %d" % mon.max_hp, false, Color(0.6, 1, 0.6)))
			h.add_child(_label("%dG" % mon.gold_reward, false, Color(1, 0.9, 0.4)))
		else:
			h.add_child(_label("??? " + Locale.t("(미발견)"), true, Color(0.5, 0.5, 0.55)))
		body.add_child(h)
