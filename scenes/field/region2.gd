extends RegionBase
## 2지역 "강 건너 가도". 동심원이 아닌 남북으로 긴 가도(길).
## 북쪽 입구(다리) → 중간에 마을 → 남쪽 끝에 다음 게이트(산길 관문).
## 가도(길)는 안전, 길에서 벗어난 숲/습지가 강한 몬스터 구역.

@export var road_left := 9
@export var road_right := 12
@export var village_top := 28
@export var village_bottom := 37


func region_id() -> StringName:
	return &"region2"


func entrance(id: StringName) -> Vector2:
	match id:
		&"north":
			return Vector2((road_left + road_right) * 16, 96) # 다리에서 진입
		&"church":
			return Vector2((road_left + road_right) * 16, (village_top + 5) * 32) # 교회 부활점
		_:
			return Vector2((road_left + road_right) * 16, (village_top + 5) * 32)


func _tile_for(cell: Vector2i) -> Vector2i:
	var w := map_size.x
	var h := map_size.y
	# 동서 산맥 (막힘)
	if cell.x <= 1 or cell.x >= w - 2:
		return TILE_MOUNTAIN
	# 남쪽 끝 산맥 (게이트 너머)
	if cell.y >= h - 1:
		return TILE_MOUNTAIN
	# 북쪽 벽 — 가도 폭만 열려 있다 (다리에서 진입)
	if cell.y <= 1:
		if cell.x >= road_left and cell.x <= road_right:
			return TILE_PATH
		return TILE_MOUNTAIN
	# 중간 마을 (안전지대)
	if cell.y >= village_top and cell.y <= village_bottom:
		return TILE_VILLAGE
	# 가도 (길)
	if cell.x >= road_left and cell.x <= road_right:
		return TILE_PATH
	# 길 옆: 가까우면 풀(약), 멀면 숲(강)
	var d := mini(absi(cell.x - road_left), absi(cell.x - road_right))
	if d <= 2:
		return TILE_GRASS_MID
	return TILE_GRASS_DARK
