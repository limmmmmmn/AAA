extends Control
## 상점 — 패스 오브 엑자일식 패시브 노드 트리.
## 중앙 허브에서 세 갈래(검=오른쪽 / 마을=아래 / 사냥=왼쪽)로 뻗고, 연결된 앞 노드를
## 사야 다음이 해금되는 경로 잠금. 노드는 16x16, 마우스 올리면 노드 위에 툴팁.
## WASD로 패닝 · 배경 드래그로 이동 · 노드 클릭으로 구매. 열리면 세계 정지.
##
## 경로 잠금은 여기(표현 계층)에서만 강제한다 — GameState.purchase()는 골드/최대치만 보고,
## 테스트가 선행 노드 없이 직접 구매할 수 있게 둔다(시뮬레이션/렌더링 분리).

const SPACING := 30.0    # 그리드 1칸 = 30px
const PAN_SPEED := 220.0 # WASD 패닝 속도(px/s)
const REVEAL_STEP := 0.07 # 깊이 한 겹당 등장 지연(s) — 허브에서 바깥으로 번지게
const REVEAL_GROW := 0.18 # 선이 "쭈욱" 자라는 시간(s)

# ─ 팔레트 ─
const COL_BACKDROP := Color(0.07, 0.08, 0.11, 1.0) # 불투명 — 뒤 월드/HUD 가림
const COL_OK := Color(1, 0.86, 0.4)     # 살 수 있는 가격(금색)
const COL_POOR := Color(0.95, 0.55, 0.5) # 골드 부족(빨강)
const COL_MAX := Color(0.6, 0.85, 0.62)  # 보유 완료(초록)
const COL_LOCK := Color(0.6, 0.62, 0.68) # 잠김(회색)

var _canvas: Control
var _links: TreeLinks
var _nodes: Control
var _tooltip: PanelContainer
var _tip_name: Label
var _tip_lv: Label
var _tip_desc: Label
var _tip_cost: Label
var _gold_label: Label
var _title: Label
var _hint: Label

var _node_map: Dictionary = {}   # StringName id -> SkillNode
var _seg_by_id: Dictionary = {}  # StringName id -> 선분 dict(부모→이 노드)
var _shown: Dictionary = {}      # StringName id -> 이미 등장함(중복 애니 방지)
var _pan := Vector2.ZERO
var _pan_ext := Vector2(280, 220) # 패닝 허용 범위(±)
var _tree_center := Vector2.ZERO  # 트리 바운딩 박스 중심(px) — 열 때 화면 가운데로
var _dragging := false
var _hover_id: StringName = &""


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # 세계가 정지해도 트리 조작은 받는다
	add_to_group("closable_modal")           # Esc로 닫히는 모달
	mouse_filter = Control.MOUSE_FILTER_STOP  # 배경 드래그(패닝)를 받기 위해
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	EventBus.party_entered_village.connect(_open) # 원격 상점 버튼/호환
	EventBus.request_shop.connect(_open)          # 상점 [열기]/Space
	EventBus.request_shop_close.connect(_close)   # 상점 [닫기]/멀어짐
	EventBus.party_exited_village.connect(_close)
	EventBus.request_close_modals.connect(_close) # Esc
	EventBus.gold_changed.connect(func(_g: int) -> void: if visible: _refresh_all())
	EventBus.upgrade_purchased.connect(func(_u: UpgradeData) -> void: if visible: _refresh_all())
	EventBus.language_changed.connect(func() -> void: if visible: _rebuild())


# ─── UI 골격(코드 생성) ───

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = COL_BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 트리가 얹히는 캔버스(패닝 시 통째로 이동). 자식 좌표는 허브(0,0) 기준.
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_links = TreeLinks.new()
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_links)
	_nodes = Control.new()
	_nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_nodes)

	# 헤더(제목 + 소지금)
	_title = _chrome_label(8, 6, 14, Color(0.92, 0.94, 1))
	_gold_label = _chrome_label(8, 22, 12, COL_OK)

	# 하단 조작 힌트
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.73, 0.8))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(8, -18)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_hint)

	# 닫기 버튼(우상단)
	var close := Button.new()
	close.text = "X"
	close.add_theme_font_size_override("font_size", 12)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.position = Vector2(-26, 6)
	close.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	close.custom_minimum_size = Vector2(20, 18)
	close.pressed.connect(_close)
	add_child(close)

	_build_tooltip()


func _chrome_label(x: float, y: float, fsize: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = Vector2(x, y)
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	add_child(lbl)
	return lbl


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.14, 0.98)
	sb.border_color = Color(0.5, 0.55, 0.66)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	_tooltip.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	_tooltip.add_child(vb)
	_tip_name = _tip_label(vb, 12, Color(1, 1, 1))
	_tip_lv = _tip_label(vb, 10, Color(0.7, 0.78, 0.92))
	_tip_desc = _tip_label(vb, 10, Color(0.82, 0.84, 0.9))
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(150, 0)
	_tip_cost = _tip_label(vb, 11, COL_OK)
	add_child(_tooltip) # 항상 맨 위


func _tip_label(parent: Node, fsize: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)
	return lbl


# ─── 열기/닫기(세계 정지) ───

func _open() -> void:
	visible = true
	_rebuild()
	_pan = -_tree_center # 트리 전체를 화면 가운데에 두고 시작
	get_tree().paused = true


func _close() -> void:
	if not visible:
		return
	visible = false
	_hide_tooltip()
	get_tree().paused = false
	EventBus.shop_closed.emit()


# ─── 트리 구성 ───

func _rebuild() -> void:
	for c in _nodes.get_children():
		c.queue_free()
	_node_map.clear()
	_seg_by_id.clear()
	_shown.clear()
	_hover_id = &""
	_links.segs.clear()

	var ups := GameState.tree_upgrades()
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for up in ups:
		var p := Vector2(up.tree_pos) * SPACING
		lo = lo.min(p)
		hi = hi.max(p)
		var node := SkillNode.new()
		node.up = up
		node.position = p - Vector2(SkillNode.SIZE, SkillNode.SIZE) * 0.5
		node.visible = false        # 처음엔 다 숨김 — 해금되는 순서대로 등장
		node.scale = Vector2.ZERO
		node.hovered.connect(_on_node_hover)
		node.unhovered.connect(_on_node_unhover)
		node.picked.connect(_on_node_pick)
		_nodes.add_child(node)
		_node_map[up.id] = node
		# 부모→이 노드 선분(grow=0이면 안 그려짐). 등장 때 0→1로 "쭈욱".
		var pid: StringName = up.tree_links[0] if not up.tree_links.is_empty() else GameState.TREE_CORE
		var seg := {"from": _grid_local(pid), "to": p, "on": false, "grow": 0.0}
		_links.segs.append(seg)
		_seg_by_id[up.id] = seg

	# 패닝 범위: 트리 절반폭 + 여유. 작은 트리도 가운데를 크게 못 벗어나게.
	var half := (hi - lo) * 0.5
	_tree_center = (lo + hi) * 0.5
	_pan_ext = Vector2(maxf(half.x, 40) + 150, maxf(half.y, 40) + 110) + _tree_center.abs()

	var ko := GameState.language == "ko"
	_title.text = "상점 — 패시브 트리" if ko else "SHOP — PASSIVE TREE"
	_hint.text = ("WASD 패닝 · 드래그 이동 · 클릭 구매 · Esc 닫기" if ko
		else "WASD pan · drag · click to buy · Esc")

	for id: StringName in _node_map:
		_update_node_state(id)
	_update_link_colors()
	_refresh_gold()
	# 허브에서 바깥으로 한 겹씩(깊이 순) 등장시킨다 — 원 하나 → 선 쭈욱 → 노드 팝
	for id: StringName in _node_map:
		var up2: UpgradeData = _node_map[id].up
		if _node_visible(up2):
			_schedule_reveal(id, float(_depth(up2) - 1) * REVEAL_STEP)


func _refresh_all() -> void:
	for id: StringName in _node_map:
		_update_node_state(id)
	_update_link_colors()
	_refresh_gold()
	# 구매로 새로 해금된 노드를 즉시 등장(선 쭈욱 + 팝)
	for id: StringName in _node_map:
		if _node_visible(_node_map[id].up) and not _shown.get(id, false):
			_schedule_reveal(id, 0.0)
	if _hover_id != &"":
		_update_tooltip(_hover_id)


func _update_node_state(id: StringName) -> void:
	var node: SkillNode = _node_map[id]
	node.set_state(_state_of(node.up))


func _state_of(up: UpgradeData) -> int:
	var owned := GameState.owned_count(up)
	if owned >= up.max_purchases:
		return SkillNode.State.MAXED
	if owned >= 1:
		return SkillNode.State.OWNED # 일부 보유(반복형) — 더 살 수 있음
	if not GameState.node_unlocked(up):
		return SkillNode.State.LOCKED
	return (SkillNode.State.BUYABLE if GameState.gold >= GameState.current_cost(up)
		else SkillNode.State.POOR)


## 노드가 보일 대상인가 — 보유했거나(소유) 선행이 할당돼 해금된(프론티어) 노드만 등장.
## 그 너머(선행 미보유)는 숨긴다 → 끝 노드를 사야 다음이 생긴다.
func _node_visible(up: UpgradeData) -> bool:
	return GameState.owned_count(up) >= 1 or GameState.node_unlocked(up)


## 허브(깊이0)에서의 거리 — 루트=1, 그 자식=2 … 등장 스태거에 쓴다.
func _depth(up: UpgradeData) -> int:
	var d := 0
	var cur := up
	while cur != null and not cur.tree_links.is_empty() and cur.tree_links[0] != GameState.TREE_CORE:
		cur = GameState.upgrade_by_id(cur.tree_links[0])
		d += 1
		if d > 30:
			break
	return d + 1


## 선분 색만 갱신(grow는 안 건드림). 양끝 모두 할당되면 활성(초록).
func _update_link_colors() -> void:
	for id: StringName in _seg_by_id:
		var up: UpgradeData = _node_map[id].up
		var pid: StringName = up.tree_links[0] if not up.tree_links.is_empty() else GameState.TREE_CORE
		_seg_by_id[id]["on"] = GameState.node_allocated(pid) and GameState.owned_count(up) >= 1
	_links.queue_redraw()


## 노드 등장: (delay 후) 선이 쭈욱 자라고 → 노드가 팝 하고 나타난다.
func _schedule_reveal(id: StringName, delay: float) -> void:
	if _shown.get(id, false):
		return
	_shown[id] = true
	var node: SkillNode = _node_map[id]
	var seg: Dictionary = _seg_by_id[id]
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # 상점=세계정지 중에도 등장 애니가 돈다
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_method(_set_seg_grow.bind(seg), 0.0, 1.0, REVEAL_GROW) # 선 쭈욱
	t.tween_callback(_show_node.bind(node))                        # 노드 켜기
	t.tween_property(node, "scale", Vector2(1.25, 1.25), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)      # 팝
	t.tween_property(node, "scale", Vector2.ONE, 0.1)


func _set_seg_grow(v: float, seg: Dictionary) -> void:
	seg["grow"] = v
	_links.queue_redraw()


func _show_node(node: SkillNode) -> void:
	node.visible = true
	node.scale = Vector2.ZERO


func _grid_local(id: StringName) -> Vector2:
	if id == GameState.TREE_CORE:
		return Vector2.ZERO
	var up := GameState.upgrade_by_id(id)
	return Vector2(up.tree_pos) * SPACING if up != null else Vector2.ZERO


func _refresh_gold() -> void:
	var ko := GameState.language == "ko"
	_gold_label.text = ("골드 %d" % GameState.gold) if ko else ("GOLD %d" % GameState.gold)


# ─── 패닝 / 드래그 ───

func _process(delta: float) -> void:
	if not visible:
		return
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): v.y += 1.0
	if Input.is_key_pressed(KEY_S): v.y -= 1.0
	if Input.is_key_pressed(KEY_A): v.x += 1.0
	if Input.is_key_pressed(KEY_D): v.x -= 1.0
	if v != Vector2.ZERO:
		_pan += v * PAN_SPEED * delta
	_pan = _pan.clamp(-_pan_ext, _pan_ext)
	_canvas.position = (size * 0.5 + _pan).round()
	if _hover_id != &"":
		_place_tooltip(_hover_id)


func _gui_input(e: InputEvent) -> void:
	# 배경(노드/버튼이 아닌 곳) 드래그 → 트리 패닝.
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
	elif e is InputEventMouseMotion and _dragging:
		_pan += e.relative


# ─── 호버 툴팁 / 구매 ───

func _on_node_hover(node: SkillNode) -> void:
	_hover_id = node.up.id
	_update_tooltip(_hover_id)
	_place_tooltip(_hover_id)
	_tooltip.visible = true


func _on_node_unhover(node: SkillNode) -> void:
	if _hover_id == node.up.id:
		_hide_tooltip()


func _on_node_pick(node: SkillNode) -> void:
	_try_buy(node.up)


func _try_buy(up: UpgradeData) -> bool:
	if GameState.owned_count(up) >= up.max_purchases:
		return false
	if not GameState.node_unlocked(up):
		return false # 경로 잠금: 선행 노드 먼저
	return GameState.purchase(up) # 성공 시 upgrade_purchased → _refresh_all


func _update_tooltip(id: StringName) -> void:
	if not _node_map.has(id):
		return
	var up: UpgradeData = _node_map[id].up
	var ko := GameState.language == "ko"
	_tip_name.text = up.display_name
	_tip_lv.text = _level_text(up)
	_tip_desc.text = up.description
	var owned := GameState.owned_count(up)
	if owned >= up.max_purchases:
		_tip_cost.text = "보유 완료" if ko else "OWNED"
		_tip_cost.add_theme_color_override("font_color", COL_MAX)
	elif not GameState.node_unlocked(up):
		_tip_cost.text = "잠김 — 앞 노드 먼저" if ko else "LOCKED — buy a linked node"
		_tip_cost.add_theme_color_override("font_color", COL_LOCK)
	else:
		var cost := GameState.current_cost(up)
		_tip_cost.text = ("%d G" % cost)
		_tip_cost.add_theme_color_override("font_color",
			COL_OK if GameState.gold >= cost else COL_POOR)


## "Lv N / M" — 반복 구매형이면 [###--] 진행 바를 붙인다.
func _level_text(up: UpgradeData) -> String:
	var owned := GameState.owned_count(up)
	var mx := up.max_purchases
	if mx <= 1:
		return "Lv %d / %d" % [owned, mx]
	var bar := ""
	for k in mx:
		bar += "#" if k < owned else "-"
	return "Lv %d / %d  [%s]" % [owned, mx, bar]


## 툴팁을 호버 노드 위쪽에 띄우고 화면 안으로 클램프.
func _place_tooltip(id: StringName) -> void:
	if not _node_map.has(id):
		return
	var node: SkillNode = _node_map[id]
	_tooltip.reset_size()
	var ts := _tooltip.size
	var center := _canvas.position + node.position + Vector2(SkillNode.SIZE, SkillNode.SIZE) * 0.5
	var pos := center + Vector2(-ts.x * 0.5, -ts.y - SkillNode.SIZE * 0.5 - 4.0)
	pos.x = clampf(pos.x, 4.0, maxf(4.0, size.x - ts.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, size.y - ts.y - 4.0))
	_tooltip.position = pos.round()


func _hide_tooltip() -> void:
	_hover_id = &""
	_tooltip.visible = false
