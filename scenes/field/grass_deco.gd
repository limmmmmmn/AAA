extends Area2D
## 바닥 풀 장식. 아군(Party)이 밟으면 2번째 프레임(눕는 풀)로 바뀌었다가 잠시 뒤 다시 선다.
## 스프라이트시트: 가로 2프레임 (0=서있음, 1=밟힘).

@export var revert_delay: float = 0.45

@onready var _sprite: Sprite2D = $Sprite2D

var _revert: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_process(false)


func _on_body_entered(body: Node2D) -> void:
	if body is Party:
		_sprite.frame = 1        # 눕는 풀 (밟힘)
		_revert = revert_delay
		set_process(true)


func _process(delta: float) -> void:
	_revert -= delta
	if _revert <= 0.0:
		_sprite.frame = 0        # 다시 선다
		set_process(false)
