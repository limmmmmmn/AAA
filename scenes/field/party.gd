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


func _ready() -> void:
	add_to_group("party")
	_field = get_tree().get_first_node_in_group("field")
	EventBus.companion_joined.connect(_on_companion_joined)
	_refresh_companions()


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
	var nearest: Node2D = null
	var best := INF
	for monster: Node2D in get_tree().get_nodes_in_group("monsters"):
		var dist := global_position.distance_squared_to(monster.global_position)
		if dist < best:
			best = dist
			nearest = monster
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


## 충돌 몬스터 + (2지역) 반경 내 휘말린 몬스터를 한 전투로 묶어 시작 (A-3 구조).
func _start_encounter(primary: Monster) -> void:
	var pulled: Array[Monster] = [primary]
	if GameState.max_enemies_per_battle > 1 and GameState.encounter_pull_radius > 0.0:
		var r2 := GameState.encounter_pull_radius * GameState.encounter_pull_radius
		for node: Node2D in get_tree().get_nodes_in_group("monsters"):
			if pulled.size() >= GameState.max_enemies_per_battle:
				break
			var m := node as Monster
			if m and m != primary and not m.is_leaving() and m.data \
					and primary.global_position.distance_squared_to(m.global_position) <= r2:
				pulled.append(m)
	var datas: Array = []
	for m in pulled:
		datas.append(m.data)
	if BattleManager.start_battle(datas, primary.global_position) != null:
		for m in pulled:
			m.consume()
