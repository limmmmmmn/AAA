extends "res://scenes/field/interactable.gd"
## 마을 여관 (상점 해금). 해금하면 마을에 나타나고, 가까이 가서 Space/[여관]로 InnUI를 연다.
## 여관이 열리면 세계가 정지하지만, 이 건물은 ALWAYS로 돌려 Space로 다시 닫을 수 있게 한다.

@onready var _col: CollisionShape2D = $CollisionShape2D

var _open: bool = false


func _setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 정지 중에도 Space로 닫기 토글이 동작하게
	EventBus.inn_closed.connect(_on_inn_closed)
	EventBus.upgrade_purchased.connect(func(_u: UpgradeData) -> void: _refresh_active())
	EventBus.stats_changed.connect(_refresh_active) # 해금 → 등장
	_refresh_active()


## 설치(해금) 여부에 따라 표시/감지를 켜고 끈다.
func _refresh_active() -> void:
	var on := GameState.inn_unlocked
	visible = on
	monitoring = on
	_col.disabled = not on
	if not on and _prompt:
		_prompt.visible = false
	_tick()


## 닫을 때(_open)는 정지 중이어도 허용. 열 때는 설치됨 + 세계가 안 멈춰 있을 때만.
func _can_interact() -> bool:
	if not GameState.inn_unlocked:
		return false
	return _open or not get_tree().paused


func _interact() -> void:
	if _open:
		EventBus.request_inn_close.emit() # 닫힘은 inn_closed 콜백이 _open=false로 동기화
	else:
		EventBus.request_inn.emit()
		_open = true


func _on_inn_closed() -> void:
	_open = false
	_tick()


func _prompt_text() -> String:
	return "여관 닫기" if _open else "여관 [Space]"
