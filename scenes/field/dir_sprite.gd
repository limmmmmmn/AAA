class_name DirSprite extends Sprite2D
## 4방향 캐릭터 스프라이트시트 컨트롤러.
## 시트 레이아웃: 3열 × 4행. 행 = 아래(0)/왼(1)/오른(2)/위(3), 열 = 걷기 3모션(가운데=아이들).
## 이동 방향(face)과 이동 여부(set_moving)를 받아 걷기 애니/정지 포즈를 그린다.

const COLS := 3
const ROWS := 4
const IDLE_COL := 1                 # 가운데 = 아이들
const WALK_SEQ := [0, 1, 2, 1]      # 걸을 때 열 순서 (스텝-아이들-스텝-아이들)

@export var frame_time: float = 0.14

var _facing: int = 0   # 0=아래, 1=왼, 2=오른, 3=위
var _moving: bool = false
var _t: float = 0.0
var _seq: int = 0


func _ready() -> void:
	hframes = COLS
	vframes = ROWS
	_apply()


func face(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	if absf(dir.x) > absf(dir.y):
		_facing = 2 if dir.x > 0.0 else 1   # 오른 / 왼
	else:
		_facing = 0 if dir.y > 0.0 else 3   # 아래 / 위
	_apply()


func set_moving(m: bool) -> void:
	if _moving == m:
		return
	_moving = m
	if not m:
		_seq = 0
		_t = 0.0
		_apply() # 정지하면 아이들 포즈


func _process(delta: float) -> void:
	if not _moving:
		return
	_t += delta
	if _t >= frame_time:
		_t -= frame_time
		_seq = (_seq + 1) % WALK_SEQ.size()
		_apply()


func _apply() -> void:
	var col: int = WALK_SEQ[_seq] if _moving else IDLE_COL
	frame = _facing * COLS + col
