extends "res://scenes/field/interactable.gd"
## 마을 보물상자 (상점 해금/증설). 가까이 가서 Space/[열기]로 연다 (자동 아님). 긴 쿨타임 후 재생성.
## index = 몇 번째 상자인지 (인덱스별 쿨타임). 해금 + index < 갯수일 때만 설치되어 보인다.
## N회 열면 열쇠 시스템 해금 → 이후엔 나무 열쇠(항아리 드롭)가 있어야 열린다 (중반 깊이).
## 2프레임 스프라이트시트: frame 0 = 닫힘(준비됨), frame 1 = 열림(쿨타임 중).

@export var index: int = 0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _status: Label = $Label # 재생성/상태 표시 (항상)
@onready var _col: CollisionShape2D = $CollisionShape2D


func _setup() -> void:
	EventBus.chest_changed.connect(_tick)
	EventBus.upgrade_purchased.connect(func(_u: UpgradeData) -> void: _refresh_active())
	EventBus.stats_changed.connect(_refresh_active)
	_refresh_active()


## 이 상자가 설치되어 있는가 (해금 + index < 갯수).
func _installed() -> bool:
	return GameState.chest_unlocked and index < GameState.chest_count


func _refresh_active() -> void:
	var on := _installed()
	visible = on
	monitoring = on
	_col.disabled = not on
	if not on and _prompt:
		_prompt.visible = false
	_tick()


func _can_interact() -> bool:
	return _installed() and GameState.chest_can_open(index) # 준비됨 + (열쇠 불필요 또는 열쇠 보유)


func _interact() -> void:
	var msg := GameState.open_chest(index)
	if msg != "":
		EventBus.show_toast.emit(Locale.t("보물상자: %s!") % msg)


func _prompt_text() -> String:
	if not GameState.chest_ready(index):
		return Locale.t("재생성 %s") % TownFmt.time(GameState.chest_remaining(index))
	if GameState.chest_needs_key() and GameState.material_count(GameState.chest_required_key) <= 0:
		return Locale.t("🔒 %s 열쇠 필요") % GameState.material_name(GameState.chest_required_key)
	return "열기"


func _tick() -> void:
	if not _installed():
		return
	var r := GameState.chest_ready(index)
	_sprite.frame = 0 if r else 1   # 닫힘 / 열림
	_status.visible = not r
	if not r:
		_status.text = Locale.t("재생성 %s") % TownFmt.time(GameState.chest_remaining(index))
