extends Node2D
## 다리 건너편(2지역 강변)에 보이는 동료 실루엣 (A-6).
## 1지역에선 상호작용 불가, 주기적으로 손을 흔든다.
## 게이트 통과 시 컬러로 바뀌며 "동료가 되었다!" 합류 컷 → PART B로 연결.

@export var color_texture: Texture2D            # 실루엣 → 컬러 전환용
@export var companion_name: String = "승려"

@onready var _sprite: Sprite2D = $Sprite2D

var _joined: bool = false


func _ready() -> void:
	EventBus.gate_unlocked.connect(_on_gate_unlocked)
	if GameState.gate_paid:
		_reveal(false) # 이미 통과한 세이브 → 조용히 컬러 상태
	else:
		_start_waving()


func _start_waving() -> void:
	# 손 흔드는 느낌: 살짝 좌우로 기울이며 위아래로 까딱
	var tween := create_tween().set_loops()
	tween.tween_property(_sprite, "rotation_degrees", 8.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_sprite, "rotation_degrees", -8.0, 0.4).set_trans(Tween.TRANS_SINE)


func _on_gate_unlocked(_gate_id: StringName) -> void:
	if not _joined:
		_reveal(true)


func _reveal(announce: bool) -> void:
	_joined = true
	if color_texture:
		_sprite.texture = color_texture
	_sprite.rotation_degrees = 0.0
	if announce:
		# 합류 컷: 실루엣이 컬러로 바뀌며 작게 뛰어오른다
		var tween := create_tween()
		tween.tween_property(_sprite, "position:y", _sprite.position.y - 8.0, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_sprite, "position:y", _sprite.position.y, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		EventBus.show_toast.emit(Locale.t("%s가 동료가 되었다! (2지역은 Coming soon)") % Locale.t(companion_name))
