extends "res://scenes/field/interactable.gd"
## 마을 상점 건물. 가까이 가서 Space/[상점 열기]로 상점 UI를 연다. [닫기]/Esc/멀어지면 닫힌다.
## 일시정지 없음 — 대장간과 동일하게 패널이 떠 있어도 계속 움직일 수 있다.

var _open: bool = false


func _setup() -> void:
	EventBus.shop_closed.connect(_on_shop_closed)


func _interact() -> void:
	if _open:
		EventBus.request_shop_close.emit()
	else:
		EventBus.request_shop.emit()
	_open = not _open


func _on_leave() -> void:
	if _open:
		EventBus.request_shop_close.emit()
		_open = false


func _on_shop_closed() -> void:
	_open = false
	_tick()


func _prompt_text() -> String:
	return "상점 닫기" if _open else "상점 열기 [Space]"
