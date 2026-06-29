extends Area2D
## 반짝이는 땅: 꼬마돼지/지혜 조건이 맞으면 맵의 "랜덤 위치"에 등장한다.
## 자동으로 캐지지 않는다 — 이 위에 서서 땅파기 버튼을 눌러야 100% 보상 (do_dig).

@export var spawn_area: Rect2 = Rect2(540, 580, 360, 150) # 반짝임이 뜰 수 있는 영역 (열린 땅)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $Label

var _glow: Tween
var _placed: bool = false # 현재 반짝임의 위치를 이미 뽑았는가


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.dig_changed.connect(_refresh)
	_refresh()


func _shown() -> bool:
	return GameState.has_sparkling_ground # 맵이 하나라 현재 맵에 항상 노출


func _refresh() -> void:
	var show_it := _shown()
	if show_it and not _placed:
		# 새 반짝임 → 맵의 랜덤 위치로 이동
		position = Vector2(
			randf_range(spawn_area.position.x, spawn_area.end.x),
			randf_range(spawn_area.position.y, spawn_area.end.y))
		_placed = true
	elif not show_it:
		_placed = false
	visible = show_it
	if show_it:
		if _glow == null or not _glow.is_valid():
			_glow = create_tween().set_loops()
			_glow.tween_property(_sprite, "modulate:a", 0.5, 0.5).set_trans(Tween.TRANS_SINE)
			_glow.tween_property(_sprite, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	elif _glow and _glow.is_valid():
		_glow.kill()


func _on_body_entered(body: Node2D) -> void:
	if body is Party and _shown():
		GameState.party_on_sparkle = true
		EventBus.dig_changed.emit() # 버튼이 "✨ 반짝임! 파기"로 강조되도록


func _on_body_exited(body: Node2D) -> void:
	if body is Party:
		GameState.party_on_sparkle = false
		EventBus.dig_changed.emit()
