extends "res://scenes/field/interactable.gd"
## 마을 보물상자: 가까이 가서 Space/[열기]로 연다 (자동 아님). 긴 쿨타임 후 재생성.
## N회 열면 열쇠 시스템 해금 → 이후엔 나무 열쇠(항아리 드롭)가 있어야 열린다 (중반 깊이).

@export var ready_texture: Texture2D
@export var open_texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _status: Label = $Label # 재생성/상태 표시 (항상)


func _setup() -> void:
	EventBus.chest_changed.connect(_tick)


func _can_interact() -> bool:
	return GameState.chest_can_open() # 준비됨 + (열쇠 불필요 또는 열쇠 보유)


func _interact() -> void:
	var msg := GameState.open_chest()
	if msg != "":
		EventBus.show_toast.emit("보물상자: %s!" % msg)


func _prompt_text() -> String:
	if not GameState.chest_ready():
		return "재생성 %s" % TownFmt.time(GameState.chest_remaining())
	if GameState.chest_needs_key() and GameState.material_count(GameState.chest_required_key) <= 0:
		return "🔒 %s 열쇠 필요" % GameState.material_name(GameState.chest_required_key)
	return "열기"


func _tick() -> void:
	var r := GameState.chest_ready()
	_sprite.texture = ready_texture if r else open_texture
	_sprite.modulate.a = 1.0 if r else 0.6
	_status.visible = not r
	if not r:
		_status.text = "재생성 %s" % TownFmt.time(GameState.chest_remaining())
