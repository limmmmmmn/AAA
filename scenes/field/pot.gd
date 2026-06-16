extends "res://scenes/field/interactable.gd"
## 마을 항아리: 가까이 가서 Space/[깨기]로 깬다 (자동 아님). 쿨타임 후 복구.
## 상태/쿨타임은 GameState가 play_time 기준으로 관리 (자동 항아리꾼은 위치 무관 발동).

@export var ready_texture: Texture2D
@export var broken_texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _status: Label = $Label # 쿨타임 표시 (항상)


func _setup() -> void:
	EventBus.pot_changed.connect(_tick)


func _can_interact() -> bool:
	return GameState.pot_ready()


func _interact() -> void:
	var msg := GameState.break_pot()
	if msg != "":
		EventBus.show_toast.emit("항아리에서 %s!" % msg)
		_pop()


func _prompt_text() -> String:
	return "깨기" if GameState.pot_ready() else "복구 %s" % TownFmt.time(GameState.pot_remaining())


func _tick() -> void:
	var r := GameState.pot_ready()
	_sprite.texture = ready_texture if r else broken_texture
	_sprite.modulate.a = 1.0 if r else 0.7
	_status.visible = not r
	if not r:
		_status.text = "복구 %s" % TownFmt.time(GameState.pot_remaining())


func _pop() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2(1.25, 0.8), 0.08)
	t.tween_property(_sprite, "scale", Vector2.ONE, 0.12)
