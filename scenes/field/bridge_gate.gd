extends Area2D
## 남쪽 출구 통행료 게이트. 시작부터 보이는 다음 목표.
## 지불 시 gate_unlocked 발신 — 2지역은 아직 없으므로 Coming soon 처리.

@export var toll: int = 500
@export var gate_id: StringName = &"bridge_south"

@onready var _sign: Label = $SignLabel
@onready var _dialog: ConfirmationDialog = $ConfirmationDialog


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_dialog.confirmed.connect(_on_confirmed)
	_refresh_sign()


func _refresh_sign() -> void:
	_sign.text = "2지역 — Coming soon!" if GameState.gate_paid else "통행료 %dG" % toll


func _on_body_entered(body: Node2D) -> void:
	if not body is Party:
		return
	if GameState.gate_paid:
		EventBus.show_toast.emit("다리 건너편은 아직 공사 중... (Coming soon)")
	elif GameState.gold >= toll:
		_dialog.dialog_text = "통행료 %dG를 지불하고 다리를 건너시겠습니까?" % toll
		_dialog.popup_centered()
	else:
		EventBus.show_toast.emit("통행료가 부족하다! (%dG 더 필요)" % (toll - GameState.gold))


func _on_confirmed() -> void:
	if GameState.try_spend(toll):
		GameState.gate_paid = true
		_refresh_sign()
		# 합류 컷(CompanionPreview)이 메시지를 이어받는다 — 여기선 토스트를 내지 않는다
		EventBus.gate_unlocked.emit(gate_id)
