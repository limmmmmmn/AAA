extends Node2D
## 칠한 풀 타일에 풀을 자동으로 깐다.
## 평소엔 grass_1(서있음), 파티가 밟으면 grass_2(눕힘)로 바뀌었다가 잠시 뒤 다시 grass_1로.
## 각 풀은 개별 Sprite2D. **정렬 키를 캐릭터 발 높이에 맞춰** y_sort 한다(foot_lift):
##   캐릭터는 보통 중심(배) 기준 정렬 → 그대로면 풀이 배까지 겹친다. 풀 정렬 키를 발-오프셋만큼
##   위로 올려, 풀이 캐릭터 '발' 기준으로 앞뒤가 갈리게 한다(발치만 겹치고, 내려가면 바로 뒤로).
##   그림 위치(타일 중앙)와 밟기 판정(땅 기준)은 그대로 둔다.

const PRESS_RADIUS := 11.0 # 파티 중심에서 이 반경 안의 풀이 눕는다(px)

var _tiles: TileMapLayer
var _revert := 0.45
var _tex_stand: Texture2D     # grass_1 — 평소
var _tex_pressed: Texture2D   # grass_2 — 밟힘
var _sprites: Array[Sprite2D] = []   # 전체(테스트/카운트용)
var _ground: Array[Vector2] = []     # 각 풀의 땅 접점(밟기 판정용 — 정렬 키와 별개)
var _by_cell: Dictionary = {}        # Vector2i 셀 -> [index...]
var _pressed: Dictionary = {}        # Sprite2D -> 남은 눕기 시간(눕는 중인 것만)
var _party: Node2D


## region_base가 풀 셀 목록을 모아 호출한다.
func build(tex_stand: Texture2D, tex_pressed: Texture2D, tiles: TileMapLayer, cells: Array,
		revert: float, jitter: float, foot_lift: float, seed_val: int) -> void:
	_tiles = tiles
	_revert = revert
	_tex_stand = tex_stand
	_tex_pressed = tex_pressed
	y_sort_enabled = true # Field도 y_sort라 풀이 캐릭터와 한 묶음으로 정렬된다
	var fw := float(tex_stand.get_width())
	var fh := float(tex_stand.get_height())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for cell: Vector2i in cells:
		var s := Sprite2D.new()
		s.texture = tex_stand
		s.centered = false
		# offset(+lift로 아래로)·position(정렬키, -lift로 위로) → 그림은 타일중앙 그대로,
		# 정렬 키만 발 높이(중심+lift)에 맞게 위로. lift=캐릭터 중심→발 거리.
		s.offset = Vector2(-fw * 0.5, -fh + foot_lift)
		var ground := tiles.map_to_local(cell) + Vector2(
			rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		s.position = (ground + Vector2(0, fh * 0.5 - foot_lift)).round()
		add_child(s)
		var idx := _sprites.size()
		_sprites.append(s)
		_ground.append(ground.round())
		if not _by_cell.has(cell):
			_by_cell[cell] = []
		_by_cell[cell].append(idx)


func _process(delta: float) -> void:
	# 1) 눕는 중인 풀 타이머 감소 → 다 되면 다시 grass_1(서있음)
	if not _pressed.is_empty():
		for s: Sprite2D in _pressed.keys():
			var t: float = _pressed[s] - delta
			if t <= 0.0:
				s.texture = _tex_stand
				_pressed.erase(s)
			else:
				_pressed[s] = t
	# 2) 파티 주변(3x3 셀) 풀 눕히기 → grass_2(밟힘). 판정은 땅 접점(_ground) 기준.
	if _party == null or not is_instance_valid(_party):
		_party = get_tree().get_first_node_in_group("party")
	if _party != null:
		var ppos := to_local(_party.global_position)
		var pcell := _tiles.local_to_map(_tiles.to_local(_party.global_position))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var arr: Variant = _by_cell.get(pcell + Vector2i(dx, dy))
				if arr == null:
					continue
				for idx: int in arr:
					if ppos.distance_to(_ground[idx]) <= PRESS_RADIUS:
						_sprites[idx].texture = _tex_pressed
						_pressed[_sprites[idx]] = _revert
