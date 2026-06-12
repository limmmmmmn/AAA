extends Area2D
## 마을 장로. 조건 충족 시 "!" 표시, 대화로 멀티 전투창을 해금한다.

@onready var _mark: Label = $Mark

var _dialog: AcceptDialog

const STAGE_TEXTS := {
	0: "전투 중에도 발을 멈추지 않는 법을 알려주마.\n이제 싸우면서 걸을 수 있고,\n전투를 동시에 2개까지 치를 수 있다.",
	1: "제법 단련되었구나. 정신을 둘로 나누는 법이다.\n이제 동시에 3개의 전투를 치를 수 있다.",
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_dialog = AcceptDialog.new()
	_dialog.title = "마을 장로"
	_dialog.ok_button_text = "전수받는다"
	_dialog.confirmed.connect(_on_dialog_confirmed)
	add_child(_dialog)
	var check := Timer.new()
	check.wait_time = 0.5
	check.timeout.connect(_update_mark)
	add_child(check)
	check.start()
	_update_mark()


func _is_available() -> bool:
	match GameState.elder_stage:
		0:
			if GameState.total_battles_won >= GameState.config.elder_battles_threshold:
				return true
			return GameState.first_sword_time >= 0.0 \
				and GameState.play_time - GameState.first_sword_time >= GameState.config.elder_seconds_after_sword
		1:
			return GameState.gold >= GameState.config.elder_second_gold_threshold
		_:
			return false


func _update_mark() -> void:
	_mark.visible = _is_available()


func _on_body_entered(body: Node2D) -> void:
	if body is Party and _is_available() and not _dialog.visible:
		_dialog.dialog_text = STAGE_TEXTS.get(GameState.elder_stage, "")
		_dialog.popup_centered()


func _on_dialog_confirmed() -> void:
	if _is_available():
		GameState.advance_elder_stage()
		_update_mark()
