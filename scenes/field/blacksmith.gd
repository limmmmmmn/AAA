extends "res://scenes/field/interactable.gd"
## 마을 대장간: 가까이 가서 Space/[열기]로 ForgeUI를 연다. [닫기]/멀어지면 닫힌다.
## 일시정지 없음 — 패널이 떠 있어도 계속 움직일 수 있다.

var _open: bool = false


func _setup() -> void:
	EventBus.forge_closed.connect(_on_forge_closed)


func _interact() -> void:
	if _open:
		EventBus.request_forge_close.emit()
	else:
		EventBus.request_forge.emit()
	_open = not _open


func _on_leave() -> void:
	if _open:
		EventBus.request_forge_close.emit()
		_open = false


func _on_forge_closed() -> void:
	_open = false
	_tick()


func _prompt_text() -> String:
	return "대장간 닫기" if _open else "대장간 열기 [Space]"
