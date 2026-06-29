class_name SkillNode extends Control
## 패시브 트리의 노드 한 칸(16x16). 아이콘 + 상태색 테두리로 보유/구매가능/잠금을 보이고,
## 마우스를 올리면 "띠링" — 살짝 커지며(스케일 팝) 회전 스프링이 튕긴다(주스).
## 호버·클릭은 트리 UI(shop_ui)로 신호로 보낸다.

signal hovered(node: SkillNode)
signal unhovered(node: SkillNode)
signal picked(node: SkillNode)

const SIZE := 16.0
enum State { LOCKED, POOR, BUYABLE, OWNED, MAXED }

var up: UpgradeData
var state: int = State.LOCKED
var _hot := false
var _tw: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	pivot_offset = Vector2(SIZE, SIZE) * 0.5 # 스케일/회전 중심 = 노드 가운데
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


func set_state(s: int) -> void:
	state = s
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(self)
		accept_event() # 클릭=구매. 배경 드래그(패닝)로 새지 않게 소비.


# ─── 호버 주스: 띠링(스케일 팝 + 회전 스프링) ───

func _on_enter() -> void:
	_hot = true
	z_index = 1 # 호버 노드를 이웃 위로
	queue_redraw()
	if _tw != null and _tw.is_valid():
		_tw.kill()
	rotation = 0.22 # 살짝 기울였다가 스프링으로 풀리며 "띠링"
	_tw = create_tween().set_parallel(true)
	_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # 상점=세계정지 중에도 애니 돌게
	_tw.tween_property(self, "scale", Vector2(1.34, 1.34), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "rotation", 0.0, 0.55) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# TODO(소리): 여기서 호버 사운드 재생(예: EventBus.play_sfx.emit(&"node_hover")). 에셋 들어오면 연결.
	hovered.emit(self)


func _on_exit() -> void:
	_hot = false
	z_index = 0
	queue_redraw()
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "rotation", 0.0, 0.16)
	unhovered.emit(self)


# ─── 그리기: 배경 + 아이콘 + 상태 테두리 ───

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	var bg: Color
	var border: Color
	match state:
		State.MAXED:
			bg = Color(0.17, 0.32, 0.2); border = Color(0.72, 1, 0.78)
		State.OWNED:
			bg = Color(0.15, 0.26, 0.18); border = Color(0.55, 0.9, 0.62)
		State.BUYABLE:
			bg = Color(0.3, 0.25, 0.1); border = Color(1, 0.92, 0.5)
		State.POOR:
			bg = Color(0.18, 0.18, 0.21); border = Color(0.5, 0.5, 0.56)
		_: # LOCKED
			bg = Color(0.13, 0.14, 0.17); border = Color(0.3, 0.32, 0.38)
	draw_rect(r, bg)
	if up != null and up.icon != null:
		# 잠김/부족은 아이콘을 어둡게 탈색해 상태가 읽히게
		var mod := Color.WHITE
		if state == State.LOCKED:
			mod = Color(0.42, 0.44, 0.5, 1.0)
		elif state == State.POOR:
			mod = Color(0.78, 0.78, 0.8, 1.0)
		draw_texture_rect(up.icon, r, false, mod)
	else: # 아이콘 없을 때 폴백 점
		if state == State.OWNED or state == State.MAXED:
			draw_rect(Rect2(6, 6, 4, 4), Color(0.9, 1, 0.92))
	var bw := 2.0 if (state == State.OWNED or state == State.MAXED or _hot) else 1.0
	draw_rect(r, border if not _hot else Color(1, 1, 1, 0.95), false, bw)
