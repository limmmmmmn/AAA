extends Area2D
## 2지역 여관 (B-3). 파티 진입 → "하룻밤 N G" 확인 팝업 → 지불 시 전량 회복.
## 자동 귀환/자동 숙박은 넣지 않는다 — HP를 보고 플레이어가 스스로 내리는 결정.

@export var cost: int = 20

@onready var _dialog: ConfirmationDialog = $ConfirmationDialog

var _party_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_dialog.confirmed.connect(_on_confirmed)


func _on_body_entered(body: Node2D) -> void:
	if not body is Party:
		return
	_party_inside = true
	if GameState.shared_hp >= GameState.shared_hp_max:
		EventBus.show_toast.emit("여관: 아직 쌩쌩하구먼. 다음에 오게.")
		return
	if GameState.gold < cost:
		EventBus.show_toast.emit("여관: 하룻밤 %dG라네... 돈이 모자라는군." % cost)
		return
	_dialog.dialog_text = "하룻밤 %dG. 푹 쉬고 가시겠소? (체력 전량 회복)" % cost
	_dialog.popup_centered()


func _on_body_exited(body: Node2D) -> void:
	if body is Party:
		_party_inside = false


func _on_confirmed() -> void:
	if not _party_inside:
		return
	if GameState.try_spend(cost):
		GameState.full_heal()
		EventBus.inn_rested.emit()
		EventBus.show_toast.emit("♪ 푹 잤다! 체력이 가득 찼다.")
