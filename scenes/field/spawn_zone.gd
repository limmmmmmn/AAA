class_name SpawnZone extends Area2D
## 존별 스폰 관리. 자식 CollisionShape2D(RectangleShape2D)들이 스폰 영역을 정의한다.
## 충돌 감지는 하지 않음 (monitoring/monitorable 꺼짐) — 영역 정의 용도.
##
## unlock_milestone이 비어 있으면 시작부터 활성. 아니면 누적 토벌 조건 충족 시
## "세계가 깨어나는" 연출과 함께 활성화된다 (A-2).

@export var monster_data: MonsterData
@export var max_count: int = 4
@export var respawn_delay: float = 5.0
@export var zone_id: StringName
@export var unlock_milestone: Dictionary = {}   # 예: {"slime": 15}. 빈 값이면 시작부터 활성.
@export_multiline var unlock_toast: String = "" # 해금 시 화면 상단 알림

const MONSTER_SCENE := preload("res://scenes/field/Monster.tscn")

var _alive: int = 0
var _active: bool = false
var _rects: Array[Rect2] = [] # 글로벌 좌표


func _ready() -> void:
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node and shape_node.shape is RectangleShape2D:
			var size: Vector2 = shape_node.shape.size
			_rects.append(Rect2(shape_node.global_position - size * 0.5, size))
	if GameState.milestone_met(unlock_milestone):
		_activate(false) # 이미 조건 충족(세이브 로드 등) → 조용히 활성
	else:
		EventBus.monster_died.connect(_on_monster_died)


func _on_monster_died(_data: MonsterData, _pos: Vector2) -> void:
	if not _active and GameState.milestone_met(unlock_milestone):
		_activate(true)


func _activate(announce: bool) -> void:
	if _active:
		return
	_active = true
	if EventBus.monster_died.is_connected(_on_monster_died):
		EventBus.monster_died.disconnect(_on_monster_died)
	for i in max_count:
		_spawn()
	if announce:
		EventBus.zone_unlocked.emit(zone_id)
		if unlock_toast != "":
			EventBus.show_toast.emit(unlock_toast)


func _spawn() -> void:
	if monster_data == null or _rects.is_empty():
		return
	var monster: Monster = MONSTER_SCENE.instantiate()
	monster.data = monster_data
	monster.vanished.connect(_on_monster_vanished)
	monster.position = to_local(_random_point())
	add_child(monster)
	_alive += 1


func _random_point() -> Vector2:
	var rect: Rect2 = _rects[randi() % _rects.size()]
	return Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y)
	)


func _on_monster_vanished(_monster: Monster) -> void:
	_alive -= 1
	if not is_inside_tree():
		return
	var delay := respawn_delay * GameState.respawn_delay_mult
	get_tree().create_timer(delay).timeout.connect(_on_respawn_timer)


func _on_respawn_timer() -> void:
	if is_inside_tree() and _active and _alive < max_count:
		_spawn()
