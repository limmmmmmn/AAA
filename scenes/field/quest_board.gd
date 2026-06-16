extends "res://scenes/field/interactable.gd"
## 2지역 의뢰 게시판 (B-4). 가까이 가서 Space/[게시판 열기]로 UI를 연다.


func _interact() -> void:
	EventBus.request_quest_board.emit()


func _prompt_text() -> String:
	return "게시판 열기 [Space]"
