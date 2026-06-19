class_name Party extends CharacterBody2D
## 1지역의 파티 = 용사 1인. 방향키/WASD 직접 조작.
## 자동 추적은 compass_hunt 업그레이드로 해금 (GameState.auto_hunt_unlocked).
##
## 자동이동 우선순위 (A-5):
##   1. 수동 입력이 항상 최우선 — 입력 중엔 자동 추적 정지
##   2. 입력이 멈춘 뒤 auto_resume_delay 경과 시 자동 추적 재개
## (마을 안에서도 자동 추적은 동작한다 — 몬스터가 마을에 못 들어오므로 가까운 바깥 사냥감으로 향한다)

const HP_BAR := preload("res://scenes/field/field_hp_bar.gd")
const WALK_HOLD_FRAMES := 8   # 동료가 멈춤 판정되기까지 버티는 프레임 (불연속 추적 사이 걷기 유지)

@export var auto_resume_delay: float = 1.5
@export var follow_gap: float = 24.0   # 동료 줄줄이 행군 간격(px) — 멤버 간 거리 (캐릭터 폭보다 살짝 넓게)

@onready var _encounter_area: Area2D = $EncounterArea
@onready var _sprite: DirSprite = $Sprite2D

var _field: Node = null
var _idle_time: float = 0.0   # 마지막 수동 입력 이후 경과 시간
var _companion_sprites: Array[DirSprite] = []
var _hero_bar: Node2D = null               # 용사 머리 위 HP바
var _companion_bars: Array[Node2D] = []     # 동료 머리 위 HP바
var _companion_prev: Array[Vector2] = []   # 동료 방향 애니용 직전 위치
var _companion_walk_hold: Array[int] = []  # 동료별 걷기 애니 유지 프레임 (브레드크럼 불연속 이동 사이 끊김 방지)
var _path: Array[Vector2] = []   # 용사가 지나온 경로 점(촘촘), 끝이 최신 — 동료 줄줄이 추적용
var _last_pos: Vector2 = Vector2.ZERO
var _retreating: bool = false
var _retreat_target: Vector2 = Vector2.ZERO
var _retreat_hold: bool = false   # 철수 직후 마을에서 대기 — 수동 입력 전엔 자동으로 다시 나가지 않는다


func _ready() -> void:
	add_to_group("party")
	_field = _find_region()
	_sprite.z_index = 0 # 깊이는 Y-sort가 결정한다 (Party가 y_sort_enabled)
	_hero_bar = HP_BAR.new()
	_sprite.add_child(_hero_bar)
	_hero_bar.place_above(_sprite)
	EventBus.companion_joined.connect(_on_companion_joined)
	EventBus.tactic_retreat_triggered.connect(_on_retreat)
	EventBus.party_hp_changed.connect(_refresh_hp_bars)
	_refresh_companions()
	_refresh_hp_bars()


## 소속 지역(RegionBase)을 조상에서 찾는다. 그룹 등록은 부모 _ready보다 늦으므로
## 그룹 조회 대신 트리 조상을 거슬러 올라간다 (지역 로드 시점 안전).
func _find_region() -> RegionBase:
	var n := get_parent()
	while n != null:
		if n is RegionBase:
			return n
		n = n.get_parent()
	return null


## 멤버 i의 월드 좌표 (0=용사, 1+=동료). 모닥불 회복 연출 위치용.
func member_world_pos(index: int) -> Vector2:
	if index <= 0:
		return _sprite.global_position
	var ci := index - 1
	if ci < _companion_sprites.size():
		return _companion_sprites[ci].global_position
	return global_position


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
		_retreat_hold = true # 직접 움직이기 전까지 자동 추적으로 다시 나가지 않는다
		velocity = Vector2.ZERO
		EventBus.tactic_retreat_finished.emit()
		EventBus.show_toast.emit("마을로 무사히 돌아왔다.")
		return
	velocity = to_target.normalized() * GameState.move_speed
	move_and_slide()
	_update_hero_anim()
	_update_follow()


## 용사 스프라이트를 실제 이동 속도로 방향·걷기 애니 갱신.
func _update_hero_anim() -> void:
	var moving := velocity.length() > 4.0
	if moving:
		_sprite.face(velocity)
	_sprite.set_moving(moving)


func _on_companion_joined(_comp: CompanionData) -> void:
	_refresh_companions()


## 멤버별 현재 HP를 머리 위 바에 반영 (용사=0, 동료=1+).
func _refresh_hp_bars() -> void:
	if _hero_bar:
		_hero_bar.set_hp(GameState.member_hp(0), GameState.member_max_hp(0))
	for i in _companion_bars.size():
		_companion_bars[i].set_hp(GameState.member_hp(i + 1), GameState.member_max_hp(i + 1))


## 동료 줄줄이 이동 (고전 JRPG 행군): 용사가 지나온 경로를 따라 일정 간격으로 줄지어 따라온다.
## 동료 스프라이트는 Party의 자식이지만 매 프레임 글로벌 위치를 경로 점으로 덮어써 배치한다.
func _refresh_companions() -> void:
	for s in _companion_sprites:
		s.queue_free()
	_companion_sprites.clear()
	_companion_bars.clear() # 바는 스프라이트의 자식이라 함께 해제됨
	for comp: CompanionData in GameState.companions:
		var s := DirSprite.new()
		s.texture = comp.sprite
		s.z_index = 0       # 깊이는 Y-sort가 결정 (z 동일, Y로 정렬)
		# 크기·걸음걸이 모두 용사와 동일 (같은 DirSprite, 스케일 1.0)
		add_child(s)
		var bar := HP_BAR.new()
		s.add_child(bar)
		bar.place_above(s)
		_companion_sprites.append(s)
		_companion_bars.append(bar)
	_reset_follow()
	_refresh_hp_bars()


## 거리 기반 브레드크럼: 용사 경로에 점을 촘촘히 남기고, 멤버 i를 경로상
## (i+1)*follow_gap 만큼 뒤의 점에 놓는다 (속도·프레임레이트와 무관하게 간격 일정).
func _update_follow() -> void:
	if _companion_sprites.is_empty():
		return
	var head := global_position
	# 지역 전환·부활·철수 등 순간이동이면 줄을 끊고 용사에게 모은다.
	if head.distance_to(_last_pos) > 64.0:
		_reset_follow()
		return
	_last_pos = head
	if _path.is_empty() or _path[_path.size() - 1].distance_to(head) >= 3.0:
		_path.append(head)
		var max_points := int(follow_gap * (_companion_sprites.size() + 1) / 3.0) + 8
		while _path.size() > max_points:
			_path.remove_at(0)
	for i in _companion_sprites.size():
		var pos := _path_point_back((i + 1) * follow_gap)
		var prev: Vector2 = _companion_prev[i] if i < _companion_prev.size() else pos
		var move := pos - prev
		_companion_sprites[i].global_position = pos
		# 브레드크럼은 ~3px 단위로 불연속 갱신돼 move가 프레임마다 0/양수로 튄다.
		# 움직인 프레임엔 유지 카운터를 채우고, 빈 프레임엔 줄여 걷기 애니가 끊기지 않게 한다.
		if move.length() > 0.4:
			_companion_sprites[i].face(move)
			if i < _companion_walk_hold.size():
				_companion_walk_hold[i] = WALK_HOLD_FRAMES
		elif i < _companion_walk_hold.size() and _companion_walk_hold[i] > 0:
			_companion_walk_hold[i] -= 1
		var moving := i < _companion_walk_hold.size() and _companion_walk_hold[i] > 0
		_companion_sprites[i].set_moving(moving)
		if i < _companion_prev.size():
			_companion_prev[i] = pos


## 경로 끝에서 dist 만큼 거슬러 올라간 지점 (선분 보간).
## 시작점을 '용사의 실시간 위치(global_position)'로 잡는다 — 브레드크럼은 3px마다 띄엄띄엄
## 추가돼 그걸 끝점으로 쓰면 동료가 계단식으로 튄다("드드득"). 라이브 헤드부터 보간해 부드럽게.
func _path_point_back(dist: float) -> Vector2:
	var remaining := dist
	var from := global_position
	for i in range(_path.size() - 1, -1, -1):
		var b := _path[i]
		var seg := from.distance_to(b)
		if seg >= remaining:
			return from.lerp(b, remaining / seg) if seg > 0.0 else b
		remaining -= seg
		from = b
	return _path[0] if not _path.is_empty() else global_position


func _reset_follow() -> void:
	_path.clear()
	_path.append(global_position)
	_last_pos = global_position
	_companion_prev.clear()
	_companion_walk_hold.clear()
	for s in _companion_sprites:
		s.global_position = global_position
		s.set_moving(false)
		_companion_prev.append(global_position)
		_companion_walk_hold.append(0)


func _physics_process(delta: float) -> void:
	if _retreating: # 자동 철수 중에는 다른 이동/인카운트 무시
		_do_retreat(delta)
		return
	# 전투창이 가득 차면 정지. 멀티창 해금 전엔 1칸=가득이라 첫 전투부터 멈추고,
	# 2칸이면 1개 떠 있을 땐 걸을 수 있으며 2개로 가득 차면 멈춘다.
	if _movement_locked():
		velocity = Vector2.ZERO
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if dir != Vector2.ZERO:
			_idle_time = 0.0
			_retreat_hold = false # 플레이어가 조작을 잡으면 대기 해제
		else:
			_idle_time += delta
			if _can_auto_hunt():
				dir = _auto_hunt_direction()
		velocity = dir * GameState.move_speed
	move_and_slide()
	_update_hero_anim()
	_update_follow()
	_check_encounters()


## 전투창이 가득 찼는가 (= 새 전투를 더 못 여는 상태). 가득이면 필드 이동을 멈춘다.
func _movement_locked() -> bool:
	return BattleManager.active_battles.size() >= GameState.max_battle_windows


func _can_auto_hunt() -> bool:
	# 자동이동 스킬(나침반) 해금 + 우측 토글 ON + 새 전투 가능
	if not GameState.auto_hunt_unlocked or not GameState.auto_move_on or not BattleManager.can_start_battle():
		return false
	if _idle_time < auto_resume_delay:           # 수동 입력 직후 유예
		return false
	if _retreat_hold:                            # 자동 철수 직후 마을 대기 (v3 §9)
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
