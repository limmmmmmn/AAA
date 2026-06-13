class_name Party extends CharacterBody2D
## 1지역의 파티 = 용사 1인. 방향키/WASD 직접 조작.
## 자동 추적은 compass_hunt 업그레이드로 해금 (GameState.auto_hunt_unlocked).
##
## 자동이동 우선순위 (A-5):
##   1. 수동 입력이 항상 최우선 — 입력 중엔 자동 추적 정지
##   2. 입력이 멈춘 뒤 auto_resume_delay 경과 시 자동 추적 재개
##   3. 마을(안전지대) 타일 위에서는 자동 추적 비활성

@export var auto_resume_delay: float = 1.5

@onready var _encounter_area: Area2D = $EncounterArea
@onready var _sprite: Sprite2D = $Sprite2D

var _field: Node = null
var _idle_time: float = 0.0   # 마지막 수동 입력 이후 경과 시간
var _companion_sprites: Array[Sprite2D] = []
var _retreating: bool = false
var _retreat_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("party")
	_field = _find_region()
	EventBus.companion_joined.connect(_on_companion_joined)
	EventBus.tactic_retreat_triggered.connect(_on_retreat)
	_refresh_companions()


## 소속 지역(RegionBase)을 조상에서 찾는다. 그룹 등록은 부모 _ready보다 늦으므로
## 그룹 조회 대신 트리 조상을 거슬러 올라간다 (지역 로드 시점 안전).
func _find_region() -> RegionBase:
	var n := get_parent()
	while n != null:
		if n is RegionBase:
			return n
		n = n.get_parent()
	return null


## 자동 철수 (v3 §9): 전투 일제 종료 → 마을로 자동 귀환 (귀환 중 인카운트 없음)
func _on_retreat() -> void:
	if _retreating:
		return
	BattleManager.abort_all()
	_retreating = true
	_retreat_target = _field.entrance(&"church") if _field else global_position
	EventBus.show_toast.emit("위험! 전투를 멈추고 마을로 철수한다...")


func _do_retreat(_delta: float) -> void:
	var to_target := _retreat_target - global_position
	if to_target.length() < 10.0 or (_field and _field.is_village(global_position)):
		_retreating = false
		velocity = Vector2.ZERO
		EventBus.tactic_retreat_finished.emit()
		EventBus.show_toast.emit("마을로 무사히 돌아왔다.")
		return
	velocity = to_target.normalized() * GameState.move_speed
	move_and_slide()


func _on_companion_joined(_comp: CompanionData) -> void:
	_refresh_companions()


## 필드 파티 스프라이트: 용사 뒤에 동료를 한 명씩 배치 (B-1)
func _refresh_companions() -> void:
	for s in _companion_sprites:
		s.queue_free()
	_companion_sprites.clear()
	var offsets := [Vector2(-8, -3), Vector2(8, -3), Vector2(0, -6)]
	for i in GameState.companions.size():
		var comp: CompanionData = GameState.companions[i]
		var s := Sprite2D.new()
		s.texture = comp.sprite
		s.position = offsets[i] if i < offsets.size() else Vector2(0, -8)
		s.z_index = -1 # 용사 뒤
		s.scale = Vector2(0.8, 0.8)
		_sprite.add_child(s)
		_companion_sprites.append(s)


func _physics_process(delta: float) -> void:
	if _retreating: # 자동 철수 중에는 다른 이동/인카운트 무시
		_do_retreat(delta)
		return
	# 전투 중 이동 규칙: 해금 전엔 전투 활성 중 정지
	var battle_locked := not BattleManager.active_battles.is_empty() and not GameState.can_move_in_battle
	if battle_locked:
		velocity = Vector2.ZERO
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if dir != Vector2.ZERO:
			_idle_time = 0.0
		else:
			_idle_time += delta
			if _can_auto_hunt():
				dir = _auto_hunt_direction()
		velocity = dir * GameState.move_speed
	move_and_slide()
	_check_encounters()


func _can_auto_hunt() -> bool:
	if not GameState.auto_hunt_unlocked or not BattleManager.can_start_battle():
		return false
	if _idle_time < auto_resume_delay:           # 수동 입력 직후 유예
		return false
	if _field and _field.is_village(global_position): # 마을 = 안전지대
		return false
	return true


func _auto_hunt_direction() -> Vector2:
	# 사냥 허가 리스트에 체크된 종만 목표로 삼는다 (v3 §8)
	var nearest: Node2D = null
	var best := INF
	for node: Node2D in get_tree().get_nodes_in_group("monsters"):
		var m := node as Monster
		if m == null or m.data == null or not GameState.is_hunted(m.data.id):
			continue
		var dist := global_position.distance_squared_to(m.global_position)
		if dist < best:
			best = dist
			nearest = m
	if nearest == null:
		return Vector2.ZERO
	var to_target := nearest.global_position - global_position
	return to_target.normalized() if to_target.length() > 4.0 else Vector2.ZERO


func _check_encounters() -> void:
	# 시그널 대신 폴링: 창이 가득 찼다 비워질 때 이미 겹쳐 있던 몬스터도 잡기 위함
	if not BattleManager.can_start_battle():
		return
	for area in _encounter_area.get_overlapping_areas():
		if not BattleManager.can_start_battle():
			break
		var monster := area as Monster
		if monster and is_instance_valid(monster) and monster.data and not monster.is_leaving():
			_start_encounter(monster)


## 무리 출현 (v3 §4): 필드 몬스터 1마리와 충돌 → 전투창 안에서 같은 종이 무리로 출현.
## 필드의 다른 몬스터는 끌어들이지 않는다. 무리 규모는 전투창이 정한다.
func _start_encounter(primary: Monster) -> void:
	var count := 1
	if primary.data.allow_group: # 메탈은 항상 1마리
		count = GameState.roll_group_size()
	var datas: Array = []
	for i in count:
		datas.append(primary.data)
	if BattleManager.start_battle(datas, primary.global_position) != null:
		primary.consume()
