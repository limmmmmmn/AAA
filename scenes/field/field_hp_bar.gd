class_name FieldHpBar extends Node2D
## 필드 아군 머리 위 HP바. 초록(가득)→노랑→빨강(위험) 그라데이션.
## 주스: 피격 시 흰 잔상(ghost)이 천천히 빠지며 손실 구간을 보여주고, 채움은 즉시 갱신.

const WIDTH := 20.0
const HEIGHT := 3.0

var _target: float = 1.0   # 실제 HP 비율 (즉시 반영)
var _ghost: float = 1.0    # 흰 잔상 (천천히 따라옴 — 손실 연출)


func _ready() -> void:
	z_index = 50
	z_as_relative = false   # 항상 스프라이트 위에
	set_process(false)


## 주어진 스프라이트의 머리 위에 배치 + 부모 스케일 상쇄(동료 0.85 보정).
func place_above(sprite: Sprite2D) -> void:
	var frame_h := 24.0
	if sprite.texture and sprite.vframes > 0:
		frame_h = float(sprite.texture.get_height()) / float(sprite.vframes)
	position = Vector2(0, -(frame_h * 0.5 + 5.0))
	var sc := sprite.scale
	scale = Vector2(1.0 / maxf(0.01, sc.x), 1.0 / maxf(0.01, sc.y))


func set_hp(cur: int, mx: int) -> void:
	var r := clampf(float(cur) / float(maxi(1, mx)), 0.0, 1.0)
	if r > _target:
		_ghost = r           # 회복은 잔상도 즉시 올린다
	_target = r
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_ghost = move_toward(_ghost, _target, delta * 0.8) # 손실 잔상 천천히 빠짐
	queue_redraw()
	if is_equal_approx(_ghost, _target):
		set_process(false)


func _draw() -> void:
	var x := -WIDTH * 0.5
	var y := -HEIGHT * 0.5
	# 검정 외곽 + 빈 막대
	draw_rect(Rect2(x - 1.0, y - 1.0, WIDTH + 2.0, HEIGHT + 2.0), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(x, y, WIDTH, HEIGHT), Color(0.16, 0.06, 0.06))
	# 흰 잔상(손실 구간)
	if _ghost > _target + 0.001:
		draw_rect(Rect2(x, y, WIDTH * _ghost, HEIGHT), Color(1, 1, 1, 0.85))
	# 채움 (HP 색)
	if _target > 0.0:
		draw_rect(Rect2(x, y, WIDTH * _target, HEIGHT), _hp_color(_target))


## 1.0 초록 → 0.5 노랑 → 0.0 빨강.
func _hp_color(r: float) -> Color:
	if r > 0.5:
		return Color(0.95, 0.82, 0.2).lerp(Color(0.35, 0.9, 0.4), (r - 0.5) * 2.0)
	return Color(0.92, 0.22, 0.22).lerp(Color(0.95, 0.82, 0.2), r * 2.0)
