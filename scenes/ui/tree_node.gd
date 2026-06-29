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


## 구매 순간 "퍽!" — 크게 부풀었다 탄성으로 돌아오며 살짝 흔들린다.
func purchase_pop() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	scale = Vector2(1.6, 1.6)
	rotation = 0.18
	queue_redraw()
	_tw = create_tween().set_parallel(true)
	_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "rotation", 0.0, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ─── 노드 모양 (node_type별, 스펙 §14) ───
# 원형=stat · 사각=unlock/automation · 다이아=bridge · 왕관=boss/region · 톱니=repeatable
# 트링켓(trinket)은 사각 + 보라 테두리.
const PURPLE := Color(0.74, 0.5, 0.98) # 트링켓 테두리

# 16x16 기준 폴리곤 점들 (모양별) — Vector2 생성자는 const 평가가 안 되므로 static var
static var DIAMOND := PackedVector2Array([Vector2(8, 0), Vector2(16, 8), Vector2(8, 16), Vector2(0, 8)])
static var CROWN := PackedVector2Array([ # 아래 사각 + 위 3갈래 (왕관)
	Vector2(1, 15), Vector2(15, 15), Vector2(15, 6), Vector2(12, 2), Vector2(10, 5),
	Vector2(8, 1), Vector2(6, 5), Vector2(4, 2), Vector2(1, 6)])
static var GEAR := PackedVector2Array([ # 팔각형 (톱니 느낌)
	Vector2(5, 0), Vector2(11, 0), Vector2(16, 5), Vector2(16, 11),
	Vector2(11, 16), Vector2(5, 16), Vector2(0, 11), Vector2(0, 5)])


## 이 노드의 모양 키. up이 없으면 사각.
func _shape() -> String:
	if up == null:
		return "square"
	match up.node_type:
		"stat": return "circle"
		"bridge": return "diamond"
		"boss", "region": return "crown"
		"repeatable": return "gear"
		_: return "square" # unlock / automation / trinket


# ─── 그리기: 모양 배경 + 아이콘 + 상태 테두리 ───

func _draw() -> void:
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
	var shape := _shape()
	# 트링켓: 테두리를 보라색으로 (상태 밝기 유지)
	if up != null and up.node_type == "trinket":
		border = PURPLE if state != State.LOCKED else PURPLE.darkened(0.45)

	_fill_shape(shape, bg)
	if up != null and up.icon != null:
		var mod := Color.WHITE
		if state == State.LOCKED:
			mod = Color(0.42, 0.44, 0.5, 1.0)
		elif state == State.POOR:
			mod = Color(0.78, 0.78, 0.8, 1.0)
		# 원형/다이아/왕관/톱니는 아이콘을 살짝 안쪽으로 (모서리가 모양 밖으로 안 삐져나오게)
		var pad := 0.0 if shape == "square" else 2.0
		draw_texture_rect(up.icon, Rect2(pad, pad, SIZE - pad * 2, SIZE - pad * 2), false, mod)
	var bw := 2.0 if (state == State.OWNED or state == State.MAXED or _hot) else 1.0
	_stroke_shape(shape, border if not _hot else Color(1, 1, 1, 0.95), bw)


## 모양 채우기.
func _fill_shape(shape: String, col: Color) -> void:
	match shape:
		"circle":
			draw_circle(Vector2(SIZE, SIZE) * 0.5, SIZE * 0.5, col)
		"diamond":
			draw_colored_polygon(DIAMOND, col)
		"crown":
			draw_colored_polygon(CROWN, col)
		"gear":
			draw_colored_polygon(GEAR, col)
		_:
			draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), col)


## 모양 테두리(외곽선).
func _stroke_shape(shape: String, col: Color, w: float) -> void:
	match shape:
		"circle":
			draw_arc(Vector2(SIZE, SIZE) * 0.5, SIZE * 0.5 - w * 0.5, 0.0, TAU, 28, col, w)
		"diamond":
			draw_polyline(_closed(DIAMOND), col, w)
		"crown":
			draw_polyline(_closed(CROWN), col, w)
		"gear":
			draw_polyline(_closed(GEAR), col, w)
		_:
			draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), col, false, w)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := PackedVector2Array(pts)
	c.append(pts[0])
	return c

