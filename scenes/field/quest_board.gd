extends Area2D
## 2지역 의뢰 게시판 (B-4). 파티 진입 → QuestBoard UI 열기 요청.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Party:
		EventBus.request_quest_board.emit()
