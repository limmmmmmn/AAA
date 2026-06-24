extends Control
## 상점 UI — 고전 드퀘식 커맨드 창의 정체성(어두운 창·픽셀 폰트·또렷한 테두리)은 지키되,
## 모던 가독성을 얹었다: 한 덩어리 둥근 창 + 선택 하이라이트 바 + 분류 헤더(전투/필드)
## + 헤더 소지금 + 우측 상세(이름·Lv 바·효과·상태 칩).dd
## 열리면 세계 정지(필드·전투 멈춤). 키보드 ↑/↓로 이동, Enter로 구매. Space는 상점 토글이라 제외.

@onready var _title: Label = $Center/Panel/Margin/Layout/HeaderBox/Header/Title
@onready var _gold: Label = $Center/Panel/Margin/Layout/HeaderBox/Header/Gold
@onready var _scroll: ScrollContainer = $Center/Panel/Margin/Layout/Body/ListBox/Scroll
@onready var _list: VBoxContainer = $Center/Panel/Margin/Layout/Body/ListBox/Scroll/List
@onready var _d_name: Label = $Center/Panel/Margin/Layout/Body/DescBox/Desc/DName
@onready var _d_level: Label = $Center/Panel/Margin/Layout/Body/DescBox/Desc/DLevel
@onready var _d_text: Label = $Center/Panel/Margin/Layout/Body/DescBox/Desc/DText
@onready var _d_status_box: PanelContainer = $Center/Panel/Margin/Layout/Body/DescBox/Desc/DStatusBox
@onready var _d_status: Label = $Center/Panel/Margin/Layout/Body/DescBox/Desc/DStatusBox/DStatus
@onready var _close_button: Button = $Center/Panel/Margin/Layout/CloseButton

# ─ 팔레트 (모던 드퀘) ─
const COL_SEL_NAME := Color(1, 1, 1)              # 선택 행 이름
const COL_NAME := Color(0.78, 0.8, 0.86)          # 비선택 행 이름
const COL_PRICE_OK := Color(1, 0.86, 0.4)         # 살 수 있는 가격(금색)
const COL_PRICE_POOR := Color(0.95, 0.55, 0.5)    # 골드 부족(빨강)
const COL_PRICE_MAX := Color(0.55, 0.58, 0.64)    # 보유 완료(회색)
const COL_HEADER := Color(0.55, 0.72, 1.0)        # 분류 헤더

var _items: Array[UpgradeData] = []
var _rows: Array[PanelContainer] = []
var _cursors: Array[Label] = []
var _names: Array[Label] = []
var _prices: Array[Label] = []
var _selected: int = 0

var _sel_style: StyleBoxFlat       # 선택 행 하이라이트 바
var _norm_style: StyleBoxEmpty     # 비선택 행 (자리 동일하게 빈 박스)
var _pill: StyleBoxFlat            # 상태 칩 배경 (색만 바꿔 재사용)


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # 세계가 정지해도 구매 입력은 받는다
	add_to_group("closable_modal") # Esc로 닫히는 모달
	_build_styles()
	EventBus.party_entered_village.connect(_open) # 원격 상점 버튼/호환
	EventBus.request_shop.connect(_open)          # 상점 [열기]/Space
	EventBus.request_shop_close.connect(_close)   # 상점 [닫기]/멀어짐
	EventBus.party_exited_village.connect(_close)
	EventBus.request_close_modals.connect(_close) # Esc
	EventBus.gold_changed.connect(func(_g: int) -> void: if visible: _refresh_prices(); _refresh_gold())
	EventBus.upgrade_purchased.connect(func(_u: UpgradeData) -> void: if visible: _refresh_prices())
	EventBus.language_changed.connect(func() -> void: if visible: _rebuild())
	_close_button.pressed.connect(_close)


## 코드로 만드는 스타일들 (선택 바·상태 칩). 행마다 같은 안쪽 여백이라 선택 시 글자가 안 흔들린다.
func _build_styles() -> void:
	_sel_style = StyleBoxFlat.new()
	_sel_style.bg_color = Color(0.16, 0.4, 0.86, 0.96)
	_sel_style.border_width_left = 3
	_sel_style.border_color = Color(0.6, 0.85, 1.0)
	_sel_style.corner_radius_top_left = 4
	_sel_style.corner_radius_top_right = 4
	_sel_style.corner_radius_bottom_right = 4
	_sel_style.corner_radius_bottom_left = 4
	_sel_style.content_margin_left = 7
	_sel_style.content_margin_right = 7
	_sel_style.content_margin_top = 2
	_sel_style.content_margin_bottom = 2

	_norm_style = StyleBoxEmpty.new()
	_norm_style.content_margin_left = 7
	_norm_style.content_margin_right = 7
	_norm_style.content_margin_top = 2
	_norm_style.content_margin_bottom = 2

	_pill = StyleBoxFlat.new()
	_pill.corner_radius_top_left = 4
	_pill.corner_radius_top_right = 4
	_pill.corner_radius_bottom_right = 4
	_pill.corner_radius_bottom_left = 4
	_pill.content_margin_top = 3
	_pill.content_margin_bottom = 3
	_d_status_box.add_theme_stylebox_override("panel", _pill)


## 상점 패널을 띄우고 세계를 정지시킨다 (필드 이동·전투 모두 멈춤).
func _open() -> void:
	visible = true
	_rebuild()
	get_tree().paused = true


## [닫기]/Esc/멀어짐 → 패널을 내리고 정지를 푼다. 상점 버튼 동기화를 위해 shop_closed 통지.
func _close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	EventBus.shop_closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		# ↑/↓ (또는 W/S) = 목록 커서 이동. 세계가 정지라 방향키가 용사를 안 움직인다.
		KEY_UP, KEY_W:
			_select(_selected - 1)
			get_viewport().set_input_as_handled()
		KEY_DOWN, KEY_S:
			_select(_selected + 1)
			get_viewport().set_input_as_handled()
		# Enter = 선택 아이템 구매 (Space는 '상호작용'이라 상점 토글에 쓰여 충돌 → 제외)
		KEY_ENTER, KEY_KP_ENTER:
			_buy()
			get_viewport().set_input_as_handled()


# ─── 목록 구성 (실제 업그레이드 데이터) ───

func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_cursors.clear()
	_names.clear()
	_prices.clear()

	# 현재 지역 상점 = 전투 축 + 필드 축. 축마다 헤더를 달아 한눈에 묶이게 한다.
	var combat := GameState.upgrades_for_axis("combat")
	var field := GameState.upgrades_for_axis("field")
	_items = []
	_items.append_array(combat)
	_items.append_array(field)

	var ko := GameState.language == "ko"
	_title.text = "상점" if ko else "SHOP"
	_refresh_gold()

	if not combat.is_empty():
		_list.add_child(_make_header("전투" if ko else "COMBAT"))
		for i in combat.size():
			_add_row(i)
	if not field.is_empty():
		_list.add_child(_make_header("필드" if ko else "FIELD"))
		for i in range(combat.size(), _items.size()):
			_add_row(i)

	_selected = clampi(_selected, 0, maxi(0, _items.size() - 1))
	_select(_selected)


## "── 전투 ──" 같은 분류 헤더 (선택 불가, 목록 가독성용).
func _make_header(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = "─  %s" % text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", COL_HEADER)
	lbl.custom_minimum_size = Vector2(0, 15)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return lbl


func _add_row(i: int) -> void:
	_list.add_child(_make_row(i))


## "▶ 이름 ............ 가격" 한 줄 — PanelContainer로 감싸 선택 시 하이라이트 바가 깔린다.
func _make_row(i: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _norm_style)

	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 2)
	hb.custom_minimum_size = Vector2(0, 18)
	row.add_child(hb)

	var cursor := Label.new()
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.custom_minimum_size = Vector2(12, 0)
	cursor.add_theme_font_size_override("font_size", 11)
	cursor.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var nm := Label.new()
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_theme_font_size_override("font_size", 12)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.text = _items[i].display_name

	var price := Label.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.custom_minimum_size = Vector2(56, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 12)

	hb.add_child(cursor)
	hb.add_child(nm)
	hb.add_child(price)
	row.mouse_entered.connect(_select.bind(i))
	row.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select(i)
			_buy())
	_rows.append(row)
	_cursors.append(cursor)
	_names.append(nm)
	_prices.append(price)
	return row


func _select(i: int) -> void:
	if _items.is_empty():
		return
	_selected = clampi(i, 0, _items.size() - 1)
	for j in _rows.size():
		var on := j == _selected
		_rows[j].add_theme_stylebox_override("panel", _sel_style if on else _norm_style)
		_cursors[j].text = "▶" if on else ""
		_names[j].add_theme_color_override("font_color", COL_SEL_NAME if on else COL_NAME)
	_refresh_prices()
	_update_desc()
	if _selected < _rows.size():
		_scroll.ensure_control_visible(_rows[_selected]) # 키보드 이동 시 화면 밖이면 따라 스크롤


func _refresh_gold() -> void:
	_gold.text = "GOLD %d" % GameState.gold


## 가격/품절 표시 갱신 (구매·골드 변동 시).
func _refresh_prices() -> void:
	for i in _prices.size():
		var up := _items[i]
		if GameState.owned_count(up) >= up.max_purchases:
			_prices[i].text = "MAX"
			_prices[i].add_theme_color_override("font_color", COL_PRICE_MAX)
		else:
			var cost := GameState.current_cost(up)
			_prices[i].text = "%d" % cost
			_prices[i].add_theme_color_override("font_color",
				COL_PRICE_OK if GameState.gold >= cost else COL_PRICE_POOR)
	if _selected < _items.size():
		_update_status(_items[_selected])


## 설명창: 이름 / Lv 바 / 효과 설명 / 상태 칩.
func _update_desc() -> void:
	if _selected >= _items.size():
		return
	var up := _items[_selected]
	_d_name.text = up.display_name
	_d_level.text = _level_text(up)
	_d_text.text = up.description
	_update_status(up)


## Lv 표시. 반복 구매형(최대>1)이면 [###--] 진행 바를 붙여 한눈에 보이게 한다.
func _level_text(up: UpgradeData) -> String:
	var owned := GameState.owned_count(up)
	var mx := up.max_purchases
	if mx <= 1:
		return "Lv %d / %d" % [owned, mx]
	var bar := ""
	for k in mx:
		bar += "#" if k < owned else "-"
	return "Lv %d / %d  [%s]" % [owned, mx, bar]


## 상태 칩: 보유 완료(회색) / 구매 가능(초록) / 골드 부족(빨강).
func _update_status(up: UpgradeData) -> void:
	var ko := GameState.language == "ko"
	if GameState.owned_count(up) >= up.max_purchases:
		_pill.bg_color = Color(0.22, 0.24, 0.28, 1)
		_d_status.text = "보유 완료" if ko else "OWNED"
		_d_status.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		return
	var cost := GameState.current_cost(up)
	if GameState.gold >= cost:
		_pill.bg_color = Color(0.13, 0.42, 0.2, 1)
		_d_status.text = ("구매 가능   %d G" % cost) if ko else ("BUY   %d G" % cost)
		_d_status.add_theme_color_override("font_color", Color(0.75, 1, 0.78))
	else:
		_pill.bg_color = Color(0.42, 0.15, 0.15, 1)
		_d_status.text = ("골드 부족   %d G" % cost) if ko else ("NEED   %d G" % cost)
		_d_status.add_theme_color_override("font_color", Color(1, 0.78, 0.74))


func _buy() -> void:
	if _selected >= _items.size():
		return
	GameState.purchase(_items[_selected]) # 골드 차감·레벨업·재계산은 기존 로직
