extends "res://scenes/field/interactable.gd"
## 마을 항아리 (상점 해금/증설). 가까이 가서 Space/[깨기]로 깬다. 쿨타임 후 복구.
## index = 몇 번째 항아리인지 (인덱스별 쿨타임). 해금 + index < 갯수일 때만 설치되어 보인다.
## 2프레임 스프라이트시트: frame 0 = 항아리(준비됨), frame 1 = 깨진 항아리(쿨타임 중).

@export var index: int = 0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _status: Label = $Label # 쿨타임 표시 (항상)
@onready var _col: CollisionShape2D = $CollisionShape2D


func _setup() -> void:
	EventBus.pot_changed.connect(_tick)
	EventBus.upgrade_purchased.connect(func(_u: UpgradeData) -> void: _refresh_active())
	EventBus.stats_changed.connect(_refresh_active)
	_refresh_active()


## 이 항아리가 설치되어 있는가 (해금 + index < 갯수).
func _installed() -> bool:
	return GameState.pot_unlocked and index < GameState.pot_count


## 설치 여부에 따라 표시/감지를 켜고 끈다.
func _refresh_active() -> void:
	var on := _installed()
	visible = on
	monitoring = on
	_col.disabled = not on
	if not on and _prompt:
		_prompt.visible = false
	_tick()


func _can_interact() -> bool:
	return _installed() and GameState.pot_ready(index)


func _interact() -> void:
	var msg := GameState.break_pot(index)
	if msg != "":
		EventBus.show_toast.emit(Locale.t("항아리에서 %s!") % msg)
		_pop()


func _prompt_text() -> String:
	return "깨기" if GameState.pot_ready(index) else Locale.t("복구 %s") % TownFmt.time(GameState.pot_remaining(index))


func _tick() -> void:
	if not _installed():
		return
	var r := GameState.pot_ready(index)
	_sprite.frame = 0 if r else 1   # 항아리 / 깨진 항아리
	_status.visible = not r
	if not r:
		_status.text = Locale.t("복구 %s") % TownFmt.time(GameState.pot_remaining(index))


func _pop() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2(1.25, 0.8), 0.08)
	t.tween_property(_sprite, "scale", Vector2.ONE, 0.12)
