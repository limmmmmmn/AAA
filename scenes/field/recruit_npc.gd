extends Area2D
## 마을 영입 NPC: 골드가 일정 이상 모이면 머리에 "!"와 함께 나타난다.
## 가까이 가서 말을 걸면(근접) 동료로 합류하고 사라진다. (편의용 — 동료 스탯 확인 등)

@export var companion: CompanionData

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _mark: Label = $Mark
@onready var _col: CollisionShape2D = $CollisionShape2D

var _bob: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var t := Timer.new()
	t.wait_time = 0.4
	t.timeout.connect(_update)
	add_child(t)
	t.start()
	_update()


## 아직 영입 안 했고 골드 조건을 충족했는가.
func _available() -> bool:
	return companion != null and not GameState.has_companion(companion.id) \
		and GameState.gold >= GameState.config.recruit_gold_threshold


func _update() -> void:
	var on := _available()
	visible = on
	monitoring = on
	_col.disabled = not on
	if on:
		if _bob == null or not _bob.is_valid():
			_bob = create_tween().set_loops()
			_bob.tween_property(_mark, "position:y", _mark.position.y - 4.0, 0.4).set_trans(Tween.TRANS_SINE)
			_bob.tween_property(_mark, "position:y", _mark.position.y, 0.4).set_trans(Tween.TRANS_SINE)
	elif _bob and _bob.is_valid():
		_bob.kill()


func _on_body_entered(body: Node2D) -> void:
	if body is Party and _available():
		GameState.add_companion(companion)
		EventBus.show_toast.emit(Locale.t("%s가 동료가 되었다!") % Locale.t(companion.display_name))
		_update() # 합류 후 사라짐
