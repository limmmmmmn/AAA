class_name Monster extends Area2D
## 하나의 범용 몬스터 씬. MonsterData(.tres)를 꽂아 슬라임/박쥐/정예/메탈슬라임을 전부 표현한다.

signal vanished(monster: Monster)

@export var data: MonsterData
@export var wander_radius: float = 96.0
@export var flee_detect_range: float = 160.0 # 도주형 몬스터가 파티를 피하는 감지 거리

var _origin: Vector2
var _target: Vector2
var _wait_time: float = 0.0
var _alive_time: float = 0.0
var _leaving: bool = false
var _field: Node = null

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("monsters")
	_field = get_tree().get_first_node_in_group("field")
	_origin = global_position
	if data:
		_sprite.texture = data.sprite
	_pick_new_target()


func _physics_process(delta: float) -> void:
	if data == null or _leaving:
		return
	if data.flees_after_sec > 0.0:
		_alive_time += delta
		if _alive_time >= data.flees_after_sec:
			flee_away()
			return
		if _alive_time >= data.flees_after_sec - 3.0:
			_sprite.modulate.a = 0.55 + 0.45 * sin(_alive_time * 18.0) # 사라지기 전 반짝임
		# 파티가 다가오면 반대로 도망 — 초기 이속으론 못 잡는 게 의도.
		# 단, 물/산은 못 넘는다 (벽에 막히면 파티가 구석으로 몰 수 있다).
		var party := get_tree().get_first_node_in_group("party") as Node2D
		if party and global_position.distance_to(party.global_position) < flee_detect_range:
			var away := (global_position - party.global_position).normalized()
			_move_blocked(away * data.move_speed * delta)
			return
	if _wait_time > 0.0:
		_wait_time -= delta
		return
	var to_target := _target - global_position
	if to_target.length() < 4.0:
		_pick_new_target()
		_wait_time = randf_range(0.0, 0.3) if data.erratic_movement else randf_range(0.3, 1.2)
		return
	# 다음 칸이 막혀 있으면 새 목표를 고른다 (벽에 붙어 떨지 않게)
	if not _move_blocked(to_target.normalized() * data.move_speed * delta):
		_pick_new_target()


func _pick_new_target() -> void:
	var spread := wander_radius * (0.5 if data and data.erratic_movement else 1.0)
	_target = _origin + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))


## 충돌을 존중하며 motion만큼 이동. 막히면 축별로 미끄러진다.
## 조금이라도 이동했으면 true, 완전히 막혔으면 false.
func _move_blocked(motion: Vector2) -> bool:
	if _field == null:
		global_position += motion
		return true
	if _field.is_walkable(global_position + motion):
		global_position += motion
		return true
	if absf(motion.x) > 0.01 and _field.is_walkable(global_position + Vector2(motion.x, 0.0)):
		global_position.x += motion.x
		return true
	if absf(motion.y) > 0.01 and _field.is_walkable(global_position + Vector2(0.0, motion.y)):
		global_position.y += motion.y
		return true
	return false


## 이미 전투에 휘말렸거나 도주 중인가 (중복 인카운트 방지)
func is_leaving() -> bool:
	return _leaving


## 파티와 접촉해 전투가 시작됨 — 필드에서 즉시 제거
func consume() -> void:
	if _leaving:
		return
	_leaving = true
	vanished.emit(self)
	queue_free()


## 도주 (메탈슬라임): 반짝이며 사라짐
func flee_away() -> void:
	if _leaving:
		return
	_leaving = true
	vanished.emit(self)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(self, "scale", Vector2(0.2, 1.4), 0.4)
	tween.tween_callback(queue_free)
