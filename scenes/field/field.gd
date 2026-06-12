extends RegionBase
## 1지역 맵 (시작 평원). 동심원 난이도 — 마을에서 멀수록 강한 존.
## 공통 로직(페인팅·통행/마을 판정·카메라)은 RegionBase에 있다.

@export var village_center := Vector2i(22, 15)
@export var village_radius := 4                # 체비쇼프 거리 (타일)
@export var slime_radius := 8
@export var bat_radius := 12
@export var bridge_x := 21                     # 다리는 bridge_x, bridge_x+1 두 열


func region_id() -> StringName:
	return &"region1"


func entrance(_id: StringName) -> Vector2:
	return Vector2(720, 576) # 파티 시작 지점


func _tile_for(cell: Vector2i) -> Vector2i:
	var w := map_size.x
	var h := map_size.y
	# 남쪽 다리 (물 위를 지나는 통로 — 통행료 게이트가 여기 있다)
	if cell.x >= bridge_x and cell.x <= bridge_x + 1 and cell.y >= h - 4 and cell.y <= h - 2:
		return TILE_BRIDGE
	# 남쪽: 강 (충돌 있음 — 다리로만 건넌다)
	if cell.y >= h - 2:
		return TILE_WATER
	# 북쪽/동서: 산맥 (막힘)
	if cell.y <= 1 or cell.x <= 1 or cell.x >= w - 2:
		return TILE_MOUNTAIN
	# 마을 → 다리로 이어지는 길
	if cell.x >= bridge_x and cell.x <= bridge_x + 1 \
			and cell.y > village_center.y + village_radius and cell.y < h - 4:
		return TILE_PATH
	var dist := maxi(absi(cell.x - village_center.x), absi(cell.y - village_center.y))
	if dist <= village_radius:
		return TILE_VILLAGE
	if dist <= slime_radius:
		return TILE_GRASS_LIGHT
	if dist <= bat_radius:
		return TILE_GRASS_MID
	return TILE_GRASS_DARK
