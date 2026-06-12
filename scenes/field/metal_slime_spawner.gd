extends Node2D
## 메탈슬라임 전용 스포너. unlock_milestone(누적 토벌) 충족 뒤부터
## 랜덤 간격으로 외곽 영역에 1마리씩 스폰한다 (A-2).

@export var monster_data: MonsterData
@export var min_interval: float = 60.0
@export var max_interval: float = 120.0
@export var spawn_rect: Rect2 = Rect2(96, 880, 1344, 280) # 글로벌 px
@export var unlock_milestone: Dictionary = {"elite_bat": 5}
@export_multiline var unlock_toast: String = "들판에 무언가 반짝인다...?"

const MONSTER_SCENE := preload("res://scenes/field/Monster.tscn")

var _current: Monster = null
var _announced: bool = false


func _ready() -> void:
	_schedule()


func _schedule() -> void:
	get_tree().create_timer(randf_range(min_interval, max_interval)).timeout.connect(_try_spawn)


func _try_spawn() -> void:
	if not is_inside_tree():
		return
	if GameState.milestone_met(unlock_milestone) and _current == null and monster_data:
		if not _announced:
			_announced = true
			EventBus.show_toast.emit(unlock_toast)
		var monster: Monster = MONSTER_SCENE.instantiate()
		monster.data = monster_data
		monster.vanished.connect(_on_vanished)
		monster.position = to_local(Vector2(
			randf_range(spawn_rect.position.x, spawn_rect.end.x),
			randf_range(spawn_rect.position.y, spawn_rect.end.y)
		))
		add_child(monster)
		_current = monster
	_schedule()


func _on_vanished(_monster: Monster) -> void:
	_current = null
