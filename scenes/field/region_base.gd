class_name RegionBase extends Node2D
## 지역(Region) 공통 베이스. 타일 페인팅·통행/마을 판정·카메라 한계·입구를 제공한다.
## 파생 지역(field=1지역, region2=2지역)은 _tile_for()만 다르게 구현한다.
## 모든 지역은 그룹 "field"에 속해 Party/Monster/SpawnZone가 종류와 무관하게 참조한다.

@export var map_size := Vector2i(88, 68) # 타일 수 (16px 타일 — 옛 32px 대비 2배 촘촘)
## true = 코드로 맵 생성(레거시). false = 에디터에서 칠한 TileMapLayer를 그대로 사용.
@export var procedural := false

const GRASS_FIELD := preload("res://scenes/field/grass_field.gd")
## 칠한 풀 타일에 자동으로 깔리는 '살랑이는 풀'(2프레임 sway). 에디터에서 바로 조절하라고 export.
@export var grass_frame_a: Texture2D = preload("res://assets/deco/grass_1.png")
@export var grass_frame_b: Texture2D = preload("res://assets/deco/grass_2.png")
@export_range(0.0, 1.0) var grass_density := 0.45 # 풀 타일당 풀 확률(1=빈틈없이, 낮출수록 듬성)
@export var grass_jitter := 5.0                  # 타일 안에서 위치 흔들기(px)
@export var grass_revert_delay := 0.45           # 밟힌 풀이 다시 서기까지(s)
@export var grass_foot_lift := 12.0              # 캐릭터 중심→발 거리(px). 풀을 발 기준 정렬해 발치만 겹치게(↑일수록 빨리 뒤로)

const TILE_GRASS_LIGHT := Vector2i(0, 0)
const TILE_GRASS_MID := Vector2i(1, 0)
const TILE_GRASS_DARK := Vector2i(2, 0)
const TILE_VILLAGE := Vector2i(3, 0)
const TILE_PATH := Vector2i(4, 0)
const TILE_WATER := Vector2i(5, 0)
const TILE_MOUNTAIN := Vector2i(6, 0)
const TILE_BRIDGE := Vector2i(7, 0)

# 비주얼 아틀라스: 각 지형의 3×3 나인슬라이스 블록 좌상단 (코드 기반 엣지 블렌딩)
# 블록 내 오프셋: col = 풀W?0:(풀E?2:1), row = 풀N?0:(풀S?2:1)
const VIS_GRASS := Vector2i(0, 0)
const VIS_VILLAGE_GRASS := Vector2i(2, 0) # 풀처럼 보이지만 안전지대로 구분되는 타일
const VIS_PATH := Vector2i(0, 1)
const VIS_WATER := Vector2i(0, 4)
const VIS_MOUNTAIN := Vector2i(0, 7)
# 세로 다리: 위치(좌끝/중앙/우끝)에 따라 난간/판 선택
const VIS_BRIDGE_LEFT := Vector2i(0, 13)
const VIS_BRIDGE_DECK := Vector2i(1, 13)
const VIS_BRIDGE_RIGHT := Vector2i(2, 13)

var _type_grid: Array = [] # [y][x] = 기반 지형 타입(TILE_*). 통행/마을 판정은 이 격자로.

@onready var _tiles: TileMapLayer = $TileMapLayer


func _ready() -> void:
	add_to_group("field")
	if procedural:
		_paint_map() # 레거시: 코드로 생성
	else:
		_build_type_grid_from_tiles() # 에디터에서 칠한 맵을 읽어 통행/마을 격자 구축
	_scatter_grass()
	_apply_stage_tint()
	EventBus.region_changed.connect(func(_id: StringName) -> void: _apply_stage_tint())


## 현재 단계의 분위기(타일 틴트)를 맵에 입힌다 — 맵은 그대로, 색감만 바뀌어 새 지역 느낌.
func _apply_stage_tint() -> void:
	var s := GameState.current_stage()
	_tiles.modulate = s.tile_tint if s != null else Color.WHITE


## 에디터에서 칠한 TileMapLayer를 읽어 기반 지형 격자를 만든다 (아틀라스 좌표 → 타입).
func _build_type_grid_from_tiles() -> void:
	var used := _tiles.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		map_size = used.position + used.size # 칠한 범위에 맞춰 카메라/격자 확장
	_type_grid.clear()
	for y in map_size.y:
		var row := []
		for x in map_size.x:
			row.append(_type_from_atlas(_tiles.get_cell_atlas_coords(Vector2i(x, y))))
		_type_grid.append(row)


## 아틀라스 좌표가 어느 지형 블록인지로 기반 타입 판정.
func _type_from_atlas(a: Vector2i) -> Vector2i:
	if a == Vector2i(-1, -1):
		return TILE_MOUNTAIN # 빈 칸 = 막힘
	if a == VIS_VILLAGE_GRASS:
		return TILE_VILLAGE
	if a.y == 13:
		return TILE_BRIDGE
	if a.y >= 1 and a.y <= 3:
		return TILE_PATH
	if a.y >= 4 and a.y <= 6:
		return TILE_WATER
	if a.y >= 7 and a.y <= 9:
		return TILE_MOUNTAIN
	if a.y >= 10 and a.y <= 12:
		return TILE_VILLAGE
	return TILE_GRASS_LIGHT


func _paint_map() -> void:
	# 1패스: 기반 지형 타입 격자 구축 (통행/마을 판정용 — 비주얼과 분리)
	_type_grid.clear()
	for y in map_size.y:
		var row := []
		for x in map_size.x:
			row.append(_tile_for(Vector2i(x, y)))
		_type_grid.append(row)
	# 2패스: 이웃을 보고 엣지 블렌딩한 나인슬라이스 타일로 페인트
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			_tiles.set_cell(cell, 0, _resolve_visual(cell))


## 기반 지형 타입(맵 밖은 산맥=막힘).
func _type_at(cell: Vector2i) -> Vector2i:
	if _type_grid.is_empty() \
			or cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
		return TILE_MOUNTAIN
	return _type_grid[cell.y][cell.x]


func _is_grass(t: Vector2i) -> bool:
	# 마을 땅도 풀로 그리므로(흙 삭제) 블렌딩상 풀 취급
	return t == TILE_GRASS_LIGHT or t == TILE_GRASS_MID or t == TILE_GRASS_DARK \
			or t == TILE_VILLAGE


## 해당 칸이 풀인가 (맵 밖은 false — 맵 경계엔 엣지 안 생김).
func _is_grass_at(cell: Vector2i) -> bool:
	if _type_grid.is_empty() \
			or cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
		return false
	return _is_grass(_type_grid[cell.y][cell.x])


## 기반 타입 + 풀 이웃을 보고 실제로 그릴 아틀라스 좌표 결정.
func _resolve_visual(cell: Vector2i) -> Vector2i:
	var t: Vector2i = _type_grid[cell.y][cell.x]
	# 마을: 풀처럼 보이되 구분 가능한 타일 (안전지대 식별용)
	if t == TILE_VILLAGE:
		return VIS_VILLAGE_GRASS
	if _is_grass(t):
		return VIS_GRASS
	# 세로 다리: 좌끝=좌난간 / 우끝=우난간 / 그 외=판
	if t == TILE_BRIDGE:
		if _type_at(cell + Vector2i(-1, 0)) != TILE_BRIDGE:
			return VIS_BRIDGE_LEFT
		if _type_at(cell + Vector2i(1, 0)) != TILE_BRIDGE:
			return VIS_BRIDGE_RIGHT
		return VIS_BRIDGE_DECK
	var block: Vector2i
	match t:
		TILE_PATH: block = VIS_PATH
		TILE_WATER: block = VIS_WATER
		TILE_MOUNTAIN: block = VIS_MOUNTAIN
		_: return VIS_GRASS
	# 풀과 맞닿은 변/모서리 → 해당 나인슬라이스 칸 선택
	var col := 0 if _is_grass_at(cell + Vector2i(-1, 0)) \
			else (2 if _is_grass_at(cell + Vector2i(1, 0)) else 1)
	var row := 0 if _is_grass_at(cell + Vector2i(0, -1)) \
			else (2 if _is_grass_at(cell + Vector2i(0, 1)) else 1)
	return block + Vector2i(col, row)


## 에디터에서 칠한 풀 타일을 전부 찾아 '움직이는 풀'을 자동으로 깐다(범위 지정 불필요).
## 클럼프마다 노드를 두지 않고 GrassField 한 노드에 모아 그린다 → 칠한 풀 전체를 빈틈없이 덮어도 가볍다.
func _scatter_grass() -> void:
	if grass_frame_a == null or grass_frame_b == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(region_id())) # 같은 지역은 항상 같은 배치 (저장 불필요)
	var cells: Array[Vector2i] = []
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			if not _is_grass_at(cell):
				continue
			if grass_density < 1.0 and rng.randf() > grass_density:
				continue # density<1이면 솎아낸다(고정 시드라 항상 같은 패턴)
			cells.append(cell)
	if cells.is_empty():
		return
	var field: Node2D = GRASS_FIELD.new()
	field.name = "GrassField"
	field.z_index = 0 # 타일맵 위 · 캐릭터 아래(Field가 y_sort라 y=0이면 캐릭터 뒤로 깔림)
	add_child(field)
	field.build(grass_frame_a, grass_frame_b, _tiles, cells, grass_revert_delay, grass_jitter,
		grass_foot_lift, int(hash(region_id())))


## 파생 클래스가 오버라이드한다.
func _tile_for(_cell: Vector2i) -> Vector2i:
	return TILE_GRASS_LIGHT


func is_walkable(world_pos: Vector2) -> bool:
	var t := _type_at(_tiles.local_to_map(_tiles.to_local(world_pos)))
	return t != TILE_WATER and t != TILE_MOUNTAIN


func is_village(world_pos: Vector2) -> bool:
	return _type_at(_tiles.local_to_map(_tiles.to_local(world_pos))) == TILE_VILLAGE


func camera_limit() -> Rect2:
	return Rect2(0, 0, map_size.x * 16, map_size.y * 16)


func region_id() -> StringName:
	return &"region"


## 특수 배치용 입구 좌표 (예: "church" 부활점). 기본은 맵 중앙.
func entrance(_id: StringName) -> Vector2:
	return Vector2(map_size.x * 8, map_size.y * 8)
