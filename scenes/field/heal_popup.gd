extends Node2D
## 회복 연출: "+N" 초록 숫자가 뾰뵤뵹 튀어올라(탄성) 위로 둥실 떠오르며 사라진다.
## 모닥불이 멤버를 회복할 때마다 그 머리 위에 하나씩 띄운다.

@onready var _label: Label = $Label

var amount: int = 1   # add_child 전에 설정


func _ready() -> void:
	z_index = 200
	z_as_relative = false
	_label.text = "+%d" % amount
	scale = Vector2(0.2, 0.2)          # 작게 시작 → 탄성으로 뾰뵹 팝
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "position:y", position.y - 16.0, 0.7) \
		.set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
