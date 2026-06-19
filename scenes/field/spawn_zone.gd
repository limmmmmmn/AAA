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
	EventBus.stats_changed.connect(_on_stats_changed) # 몹 증식 업글 → 즉시 충원
	if GameState.milestone_met(unlock_milestone):
		_activate(false) # 이미 조건 충족(세이브 로드 등) → 조용히 활성
	else:
		EventBus.monster_died.connect(_on_monster_died)


## 존당 최대 몬스터 수 (기본 + 몹 증식 업글 보너스).
func _max_count() -> int:
	return max_count + GameState.spawn_count_bonus


## 몹 증식 업글을 사면 활성 존을 즉시 새 최대치까지 채운다 (바글바글).
func _on_stats_changed() -> void:
	if not _active:
		return
	while _alive < _max_count():
		_spawn()


func _on_monster_died(_data: MonsterData, _pos: Vector2) -> void:
	if not _active and GameState.milestone_met(unlock_milestone):
		_activate(true)


func _activate(announce: bool) -> void:
	if _active:
		return
	_active = true
	if EventBus.monster_died.is_connected(_on_monster_died):
		EventBus.monster_died.disconnect(_on_monster_died)
	for i in _max_count():
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
	# 지역 루트(y_sort_enabled)에 직접 붙여 파티·오브젝트와 함께 깊이 정렬되게 한다.
	# _ready 중 스폰(초기 활성)이면 지역 루트가 아직 자식 구성 중이라 즉시 add_child가 실패한다.
	# 부착·배치를 deferred로 미뤄 트리 구성이 끝난 뒤 안전하게 붙인다.
	_attach.call_deferred(monster, _random_point())
	_alive += 1


## 몬스터를 y_sort된 지역 루트(RegionBase)에 붙이고 글로벌 위치로 배치 (deferred 호출용).
func _attach(monster: Monster, global_pos: Vector2) -> void:
	if not is_instance_valid(monster):
		return
	_spawn_host().add_child(monster)
	monster.place(global_pos) # _origin을 실제 스폰 지점으로 (배회 기준점 보정)


## 몬스터를 붙일 부모: y_sort된 지역 루트(RegionBase). 못 찾으면 자신(폴백).
func _spawn_host() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is RegionBase):
		n = n.get_parent()
	return n if n != null else self


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
	if is_inside_tree() and _active and _alive < _max_count():
		_spawn()
