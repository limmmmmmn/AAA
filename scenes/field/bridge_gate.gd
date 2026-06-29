extends Area2D
## 남쪽 길 표지판. 단계 진행은 이제 패시브 트리(중앙 스파인의 지역 노드)가 주도한다 —
## "골드로 다음 지역을 산다". 이 표지판은 다음 목표가 트리에 있음을 알려줄 뿐, 직접 전환하지 않는다.

@export var gate_id: StringName = &"bridge_south"

@onready var _sign: Label = $SignLabel
@onready var _dialog: ConfirmationDialog = $ConfirmationDialog


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _dialog:
		_dialog.hide()
	EventBus.region_changed.connect(func(_id: StringName) -> void: _refresh_sign())
	_refresh_sign()


func _refresh_sign() -> void:
	_sign.text = Locale.t("남쪽 길 — 다음 지역은\n패시브 트리에서 연다")


func _on_body_entered(body: Node2D) -> void:
	if not body is Party:
		return
	EventBus.show_toast.emit(Locale.t("다음 지역은 패시브 트리(상점)에서 해금한다."))
