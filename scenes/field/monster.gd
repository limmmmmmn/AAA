class_name Monster extends Area2D
## 하나의 범용 몬스터 씬. MonsterData(.tres)를 꽂아 슬라임/박쥐/정예/메탈슬라임을 전부 표현한다.

signal vanished(monster: Monster)

@export var data: MonsterData
@export var wander_radius: float = 96.0

var _origin: Vector2
var _target: Vector2
var _wait_time: float = 0.0
var _leaving: bool = false
var _field: Node = null

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("monsters")
	_field = _find_region()
	_origin = global_position
	if data:
		_sprite.texture = data.sprite
		GameState.ensure_hunt_entry(data) # 사냥 허가 리스트에 종 등록 (v3 §8)
	_pick_new_target()


## 소속 지역(RegionBase)을 조상에서 찾는다 (그룹 등록 타이밍과 무관하게 안전).
func _find_region() -> RegionBase:
	var n := get_parent()
	while n != null:
		if n is RegionBase:
			return n
		n = n.get_parent()
	return null


func _physics_process(delta: float) -> void:
	if data == null or _leaving:
		return
	if _wait_time > 0.0:
		_wait_time -= delta
		return
	var to_target := _target - global_position
	if to_target.length() < 4.0:
		_pick_new_target()
		_wait_time = randf_range(0.0, 0.3) if data.erratic_movement else randf_range(0.3, 1.2)
		return
	# 다음 칸이 막혀 있으면(벽 또는 마을) 새 목표를 고른다
	if not _move_blocked(to_target.normalized() * data.move_speed * delta):
		_pick_new_target()


func _pick_new_target() -> void:
	var spread := wander_radius * (0.5 if data and data.erratic_movement else 1.0)
	_target = _origin + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))


## 몬스터가 들어갈 수 있는 칸인가: 물/산 막힘 + 마을 진입 금지 (v3 §3).
func _can_enter(pos: Vector2) -> bool:
	if _field == null:
		return true
	return _field.is_walkable(pos) and not _field.is_village(pos)


## 충돌을 존중하며 motion만큼 이동. 막히면 축별로 미끄러진다.
## 조금이라도 이동했으면 true, 완전히 막혔으면 false.
func _move_blocked(motion: Vector2) -> bool:
	if _can_enter(global_position + motion):
		global_position += motion
		return true
	if absf(motion.x) > 0.01 and _can_enter(global_position + Vector2(motion.x, 0.0)):
		global_position.x += motion.x
		return true
	if absf(motion.y) > 0.01 and _can_enter(global_position + Vector2(0.0, motion.y)):
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
