class_name RegionBase extends Node2D
## 지역(Region) 공통 베이스. 타일 페인팅·통행/마을 판정·카메라 한계·입구를 제공한다.
## 파생 지역(field=1지역, region2=2지역)은 _tile_for()만 다르게 구현한다.
## 모든 지역은 그룹 "field"에 속해 Party/Monster/SpawnZone가 종류와 무관하게 참조한다.

@export var map_size := Vector2i(44, 34) # 타일 수 (32px 타일)

const GRASS_DECO := preload("res://scenes/field/GrassDeco.tscn")
const GRASS_DENSITY := 0.10  # 풀 타일당 풀 장식이 놓일 확률
const GRASS_MAX := 160       # 성능 상한 (Area2D 수)

const TILE_GRASS_LIGHT := Vector2i(0, 0)
const TILE_GRASS_MID := Vector2i(1, 0)
const TILE_GRASS_DARK := Vector2i(2, 0)
const TILE_VILLAGE := Vector2i(3, 0)
const TILE_PATH := Vector2i(4, 0)
const TILE_WATER := Vector2i(5, 0)
const TILE_MOUNTAIN := Vector2i(6, 0)
const TILE_BRIDGE := Vector2i(7, 0)

@onready var _tiles: TileMapLayer = $TileMapLayer


func _ready() -> void:
	add_to_group("field")
	_paint_map()
	_scatter_grass()


func _paint_map() -> void:
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			_tiles.set_cell(cell, 0, _tile_for(cell))


## 초원/숲 타일 위에 풀 장식(밟으면 눕는다)을 흩뿌린다. 배치는 지역마다 일정(시드 고정).
func _scatter_grass() -> void:
	var grass := [TILE_GRASS_LIGHT, TILE_GRASS_MID, TILE_GRASS_DARK]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(region_id())) # 같은 지역은 항상 같은 배치 (저장 불필요)
	var placed := 0
	for y in map_size.y:
		for x in map_size.x:
			if placed >= GRASS_MAX:
				return
			var cell := Vector2i(x, y)
			if not grass.has(_tile_for(cell)):
				continue
			if rng.randf() > GRASS_DENSITY:
				continue
			var deco := GRASS_DECO.instantiate()
			deco.position = _tiles.map_to_local(cell) \
				+ Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
			add_child(deco)
			placed += 1


## 파생 클래스가 오버라이드한다.
func _tile_for(_cell: Vector2i) -> Vector2i:
	return TILE_GRASS_LIGHT


func is_walkable(world_pos: Vector2) -> bool:
	var cell := _tiles.local_to_map(_tiles.to_local(world_pos))
	var atlas := _tiles.get_cell_atlas_coords(cell)
	if atlas == Vector2i(-1, -1):
		return false
	return atlas != TILE_WATER and atlas != TILE_MOUNTAIN


func is_village(world_pos: Vector2) -> bool:
	var cell := _tiles.local_to_map(_tiles.to_local(world_pos))
	return _tiles.get_cell_atlas_coords(cell) == TILE_VILLAGE


func camera_limit() -> Rect2:
	return Rect2(0, 0, map_size.x * 32, map_size.y * 32)


func region_id() -> StringName:
	return &"region"


## 특수 배치용 입구 좌표 (예: "church" 부활점). 기본은 맵 중앙.
func entrance(_id: StringName) -> Vector2:
	return Vector2(map_size.x * 16, map_size.y * 16)
