extends "res://scenes/field/interactable.gd"
## 마을 상점 건물. 가까이 가서 Space/[상점 열기]로 상점 UI를 연다. [닫기]/Esc/멀어지면 닫힌다.
## 상점이 열리면 세계가 정지하지만, 이 건물은 ALWAYS로 돌려 Space로 다시 닫을 수 있게 한다.

var _open: bool = false


func _setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 정지 중에도 Space로 닫기 토글이 동작하게
	EventBus.shop_closed.connect(_on_shop_closed)


## 닫을 때(_open)는 정지 중이어도 허용. 열 때는 세계가 안 멈춰 있을 때만 (메뉴 뒤로 안 열리게).
func _can_interact() -> bool:
	return _open or not get_tree().paused


func _interact() -> void:
	if _open:
		EventBus.request_shop_close.emit() # 닫힘은 shop_closed 콜백이 _open=false로 동기화
	else:
		EventBus.request_shop.emit()
		_open = true


func _on_leave() -> void:
	if _open:
		EventBus.request_shop_close.emit()
		_open = false


func _on_shop_closed() -> void:
	_open = false
	_tick()


func _prompt_text() -> String:
	return "상점 닫기" if _open else "상점 열기 [Space]"
