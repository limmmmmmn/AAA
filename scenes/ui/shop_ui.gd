extends Control
## 상점 UI — 검정 JRPG 메뉴창 (제목/목록/설명). 아이템·가격·설명은 전부 실제
## 업그레이드 데이터(UpgradeData)에서 가져온다 (하드코딩 금지).
## 비일시정지: 마우스 호버로 선택/미리보기, 클릭 또는 Enter로 구매. 멀어지면/Esc로 닫힘.
## (방향키는 용사를 움직이므로 목록 이동에 쓰지 않는다.)

@onready var _title: Label = $Center/Layout/TitleBox/Title
@onready var _list: VBoxContainer = $Center/Layout/Body/ListBox/Scroll/List
@onready var _d_name: Label = $Center/Layout/Body/DescBox/Desc/DName
@onready var _d_level: Label = $Center/Layout/Body/DescBox/Desc/DLevel
@onready var _d_text: Label = $Center/Layout/Body/DescBox/Desc/DText
@onready var _d_status: Label = $Center/Layout/Body/DescBox/Desc/DStatus
@onready var _close_button: Button = $Center/Layout/CloseButton

var _items: Array[UpgradeData] = []
var _cursors: Array[Label] = []
var _names: Array[Label] = []
var _prices: Array[Label] = []
var _selected: int = 0


func _ready() -> void:
	visible = false
	add_to_group("closable_modal") # Esc로 닫히는 모달
	EventBus.party_entered_village.connect(_open) # 원격 상점 버튼/호환
	EventBus.request_shop.connect(_open)          # 상점 [열기]/Space
	EventBus.request_shop_close.connect(_close)   # 상점 [닫기]/멀어짐
	EventBus.party_exited_village.connect(_close)
	EventBus.request_close_modals.connect(_close) # Esc
	EventBus.gold_changed.connect(func(_g: int) -> void: if visible: _refresh_prices())
	EventBus.upgrade_purchased.connect(func(_u: UpgradeData) -> void: if visible: _refresh_prices())
	_close_button.pressed.connect(_close)


## 상점 패널만 띄운다. 일시정지 안 함 (대장간처럼 계속 움직일 수 있음).
func _open() -> void:
	visible = true
	_rebuild()


## [닫기]/Esc/멀어짐 → 패널을 내린다. 상점 버튼 동기화를 위해 shop_closed 통지.
func _close() -> void:
	if not visible:
		return
	visible = false
	EventBus.shop_closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Enter = 선택 아이템 구매 (Space는 '상호작용'이라 상점 토글에 쓰여 충돌 → 제외)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_buy()
		get_viewport().set_input_as_handled()


# ─── 목록 구성 (실제 업그레이드 데이터) ───

func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_cursors.clear()
	_names.clear()
	_prices.clear()
	# 현재 지역 상점 = 전투 축 + 필드 축 (각각 가격순 정렬됨)
	_items = GameState.upgrades_for_axis("combat")
	_items.append_array(GameState.upgrades_for_axis("field"))
	for i in _items.size():
		_list.add_child(_make_row(i))
	_selected = clampi(_selected, 0, maxi(0, _items.size() - 1))
	_select(_selected)


## "> 이름 ............ 가격" 한 줄.
func _make_row(i: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size = Vector2(0, 17)
	row.add_theme_constant_override("separation", 2)

	var cursor := Label.new()
	cursor.custom_minimum_size = Vector2(11, 0)
	cursor.add_theme_font_size_override("font_size", 11)
	cursor.add_theme_color_override("font_color", Color(1, 0.9, 0.4))

	var nm := Label.new()
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_theme_font_size_override("font_size", 11)
	nm.text = _items[i].display_name

	var price := Label.new()
	price.custom_minimum_size = Vector2(52, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.add_theme_font_size_override("font_size", 11)

	row.add_child(cursor)
	row.add_child(nm)
	row.add_child(price)
	row.mouse_entered.connect(_select.bind(i))
	row.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select(i)
			_buy())
	_cursors.append(cursor)
	_names.append(nm)
	_prices.append(price)
	return row


func _select(i: int) -> void:
	if _items.is_empty():
		return
	_selected = clampi(i, 0, _items.size() - 1)
	for j in _cursors.size():
		_cursors[j].text = ">" if j == _selected else ""
		_names[j].add_theme_color_override("font_color",
			Color(1, 1, 1) if j == _selected else Color(0.7, 0.7, 0.7))
	_refresh_prices()
	_update_desc()


## 가격/품절 표시 갱신 (구매·골드 변동 시).
func _refresh_prices() -> void:
	for i in _prices.size():
		var up := _items[i]
		if GameState.owned_count(up) >= up.max_purchases:
			_prices[i].text = "MAX"
			_prices[i].add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		else:
			var cost := GameState.current_cost(up)
			_prices[i].text = "%d" % cost
			_prices[i].add_theme_color_override("font_color",
				Color(1, 0.95, 0.5) if GameState.gold >= cost else Color(0.7, 0.45, 0.45))
	if _selected < _items.size():
		_update_status(_items[_selected])


## 설명창: 이름 / Lv x/y / 효과 설명 / 구매 상태.
func _update_desc() -> void:
	if _selected >= _items.size():
		return
	var up := _items[_selected]
	_d_name.text = up.display_name
	_d_level.text = "Lv %d/%d" % [GameState.owned_count(up), up.max_purchases]
	_d_text.text = up.description
	_update_status(up)


func _update_status(up: UpgradeData) -> void:
	if GameState.owned_count(up) >= up.max_purchases:
		_d_status.text = "보유 완료"
		_d_status.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		return
	var cost := GameState.current_cost(up)
	if GameState.gold >= cost:
		_d_status.text = "%d G — 구매 가능" % cost
		_d_status.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	else:
		_d_status.text = "%d G — 골드 부족" % cost
		_d_status.add_theme_color_override("font_color", Color(0.9, 0.55, 0.55))


func _buy() -> void:
	if _selected >= _items.size():
		return
	GameState.purchase(_items[_selected]) # 골드 차감·레벨업·재계산은 기존 로직
