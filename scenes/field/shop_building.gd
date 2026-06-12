extends Area2D
## 마을 상점 건물. 파티 진입 시 상점 UI가 열린다 (EventBus 경유 — 직접 참조 금지).


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is Party:
		EventBus.party_entered_village.emit()


func _on_body_exited(body: Node2D) -> void:
	if body is Party:
		EventBus.party_exited_village.emit()
