extends SceneTree
## 일회성: tileset.tres에 Terrain(오토타일) 설정을 API로 구성해 저장한다.
## 에디터 "Terrains" 탭으로 풀/길/물/산/마을/다리를 슥슥 칠할 수 있게 됨.
## 실행: godot --headless --path . --script res://tools/setup_terrains.gd

const TS_PATH := "res://data/tileset.tres"


func _init() -> void:
	var ts: TileSet = load(TS_PATH)
	var src: TileSetAtlasSource = ts.get_source(0)

	# 기존 terrain set 제거 후 새로 (멱등)
	while ts.get_terrain_sets_count() > 0:
		ts.remove_terrain_set(0)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)

	# 지형 정의: 이름·색 (색은 에디터 오버레이용)
	var defs := [
		{"name": "Grass", "color": Color(0.30, 0.65, 0.30)},
		{"name": "Path", "color": Color(0.80, 0.60, 0.35)},
		{"name": "Water", "color": Color(0.25, 0.55, 0.95)},
		{"name": "Mountain", "color": Color(0.45, 0.40, 0.38)},
		{"name": "Village", "color": Color(0.95, 0.85, 0.30)},
		{"name": "Bridge", "color": Color(0.55, 0.35, 0.20)},
	]
	for i in defs.size():
		ts.add_terrain(0)
		ts.set_terrain_name(0, i, defs[i].name)
		ts.set_terrain_color(0, i, defs[i].color)

	# 단일 타일 지형 (사방 자기 자신과 연결)
	_set_single(src, Vector2i(0, 0), 0)   # Grass
	_set_single(src, Vector2i(2, 0), 4)   # Village (풀처럼 보이지만 안전지대 태그)

	# 3×3 나인슬라이스 지형 (블록 좌상단, 지형 id)
	_set_ninepatch(src, Vector2i(0, 1), 1)  # Path
	_set_ninepatch(src, Vector2i(0, 4), 2)  # Water
	_set_ninepatch(src, Vector2i(0, 7), 3)  # Mountain

	# 세로 다리 (좌난간/판/우난간) — 좌우 끝만 열림
	_set_bridge(src, Vector2i(0, 13), 5, false, true)   # 좌: 오른쪽만 연결
	_set_bridge(src, Vector2i(1, 13), 5, true, true)    # 판: 좌우 연결
	_set_bridge(src, Vector2i(2, 13), 5, true, false)   # 우: 왼쪽만 연결

	var err := ResourceSaver.save(ts, TS_PATH)
	print("setup_terrains: ", "OK" if err == OK else "ERR %d" % err)
	quit()


func _td(src: TileSetAtlasSource, coord: Vector2i) -> TileData:
	return src.get_tile_data(coord, 0)


func _set_single(src: TileSetAtlasSource, coord: Vector2i, terrain: int) -> void:
	var td := _td(src, coord)
	td.terrain_set = 0
	td.terrain = terrain
	for n in [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]:
		td.set_terrain_peering_bit(n, terrain)


func _set_ninepatch(src: TileSetAtlasSource, block: Vector2i, terrain: int) -> void:
	for row in 3:
		for col in 3:
			var td := _td(src, block + Vector2i(col, row))
			td.terrain_set = 0
			td.terrain = terrain
			# 안쪽(연결)인 변에만 peering 설정, 풀과 맞닿은 변은 미설정(-1)
			if row != 0:
				td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, terrain)
			if row != 2:
				td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, terrain)
			if col != 0:
				td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, terrain)
			if col != 2:
				td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, terrain)


func _set_bridge(src: TileSetAtlasSource, coord: Vector2i, terrain: int,
		left_open: bool, right_open: bool) -> void:
	var td := _td(src, coord)
	td.terrain_set = 0
	td.terrain = terrain
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, terrain)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, terrain)
	if left_open:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, terrain)
	if right_open:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, terrain)
