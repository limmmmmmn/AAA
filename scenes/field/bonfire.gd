extends Area2D
## 모닥불 회복존: 상점에서 해금(구매)하면 마을에 나타난다.
## 파티가 회복 반경 안에 있으면 bonfire_interval()마다 가장 다친 멤버를 조금씩 회복하고
## 그 머리 위에 "+N" 연출을 띄운다. 레벨이 높을수록 간격이 짧고(빨리) 반경이 넓다(멀리).
## 회복 반경은 평소엔 숨겨두고, 파티가 들어오는 순간 "깨짝" 떠올랐다 스르륵 사라진다(핑).

const HEAL_POPUP := preload("res://scenes/field/HealPopup.tscn")

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _party: Node2D = null
var _accum: float = 0.0
var _radius: float = 42.0   # 현재 회복 반경 (그리기·감지 공용)
var _reveal: float = 0.0    # 범위 핑 표시 강도 0~1 (평소 0=숨김, 진입 시 깨짝)
var _flicker: Tween
var _reveal_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.upgrade_purchased.connect(func(_u: UpgradeData) -> void: _refresh())
	EventBus.stats_changed.connect(_refresh)
	set_process(false)
	_refresh()


## 해금 여부·레벨에 따라 표시/감지 반경/불꽃·불빛 애니를 갱신한다.
func _refresh() -> void:
	var on := GameState.bonfire_unlocked
	visible = on
	monitoring = on
	if not on:
		_kill_tweens()
		_party = null
		set_process(false)
		queue_redraw()
		return
	# 레벨에 맞춰 감지 반경 갱신 (인스턴스마다 독립 shape로)
	_radius = GameState.bonfire_radius()
	var c := CircleShape2D.new()
	c.radius = _radius
	_shape.shape = c
	queue_redraw()
	if _flicker == null or not _flicker.is_valid():
		_flicker = create_tween().set_loops()
		_flicker.tween_property(_sprite, "scale", Vector2(1.0, 1.12), 0.28).set_trans(Tween.TRANS_SINE)
		_flicker.tween_property(_sprite, "scale", Vector2(1.04, 0.94), 0.22).set_trans(Tween.TRANS_SINE)
	# 해금/확장 순간 이미 반경 안에 서 있던 경우도 회복이 시작되게 한다.
	_grab_overlap.call_deferred()


func _kill_tweens() -> void:
	if _flicker and _flicker.is_valid():
		_flicker.kill()
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()


func _set_reveal(v: float) -> void:
	_reveal = v
	queue_redraw()


## 범위 핑: 깨짝 떠올랐다(빠르게) 스르륵 사라진다(천천히). 진입 때마다 1회.
func _blink() -> void:
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_method(_set_reveal, 0.0, 1.0, 0.14).set_trans(Tween.TRANS_SINE) # 깨짝 등장
	_reveal_tween.tween_method(_set_reveal, 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)  # 스르륵 소멸


## 따뜻한 불빛 원(회복 범위)을 그린다. 평소엔 _reveal=0이라 안 보이고, 진입 핑 때만 잠깐.
func _draw() -> void:
	if _reveal <= 0.001:
		return
	var r := _radius * (0.9 + 0.1 * _reveal) # 살짝 퍼지며 나타나는 핑 느낌
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.2, 0.12 * _reveal))                  # 은은한 채움
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 0.74, 0.38, 0.6 * _reveal), 1.5, true) # 외곽 링


func _grab_overlap() -> void:
	for b in get_overlapping_bodies():
		if b is Party:
			_on_body_entered(b)


func _on_body_entered(body: Node2D) -> void:
	if body is Party and GameState.bonfire_unlocked:
		_party = body
		_accum = 0.0
		set_process(true)
		_blink() # 진입하는 순간 회복 범위를 깨짝 보여준다


func _on_body_exited(body: Node2D) -> void:
	if body is Party:
		_party = null
		set_process(false)


func _process(delta: float) -> void:
	if _party == null:
		return
	_accum += delta
	var interval := GameState.bonfire_interval()
	while _accum >= interval:
		_accum -= interval
		var idx := GameState.bonfire_heal_tick()
		if idx >= 0:
			_pop(idx)


## 회복한 멤버 머리 위로 "+N" 연출.
func _pop(member_index: int) -> void:
	var p: Node2D = HEAL_POPUP.instantiate()
	p.amount = GameState.bonfire_heal_amount()
	add_child(p)
	var pos: Vector2 = _party.member_world_pos(member_index) if _party else global_position
	p.global_position = pos + Vector2(0, -14)
