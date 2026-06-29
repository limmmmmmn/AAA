extends Area2D
## 마을 표지판 — 지역 이동은 여기(마을 안)에서만 가능하다 (v1).
## 카탈로그/도감은 어디서나 보지만, 실제 지역 변경은 마을 표지판에서만 일어난다.
## 가까이 가서 [Space] → 다음 해금 지역으로 이동(확인 다이얼로그). 표지판은 마을 안에 있으므로
## 여기 닿았다는 건 곧 party_in_town == true 라는 뜻이다.

@onready var _sign: Label = $SignLabel
@onready var _dialog: ConfirmationDialog = $ConfirmationDialog

var _in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _dialog:
		_dialog.hide()
		_dialog.confirmed.connect(_on_confirmed)
	EventBus.region_changed.connect(func(_id: StringName) -> void: _refresh_sign())
	_refresh_sign()


func _process(_delta: float) -> void:
	if _in_range and Input.is_action_just_pressed("interact"):
		_open_travel()


func _on_body_entered(body: Node2D) -> void:
	if body is Party:
		_in_range = true
		_refresh_sign()


func _on_body_exited(body: Node2D) -> void:
	if body is Party:
		_in_range = false
		_refresh_sign()


func _refresh_sign() -> void:
	_sign.text = Locale.t("지역 이동 ▲\n[Space]") if _in_range else Locale.t("마을 표지판")


## 다음 해금 지역으로의 이동을 제안. 갈 곳이 없으면 토스트만.
func _open_travel() -> void:
	var dest := GameState.next_unlocked_region()
	if GameState.unlocked_regions.size() <= 1 or dest == GameState.current_region:
		EventBus.show_toast.emit(Locale.t("아직 갈 수 있는 다른 지역이 없다."))
		return
	_dialog.title = Locale.t("지역 이동")
	_dialog.dialog_text = Locale.t("%s(으)로 이동할까?") % GameState.stage_display_name(dest)
	_dialog.ok_button_text = Locale.t("이동")
	_dialog.cancel_button_text = Locale.t("취소")
	_dialog.set_meta("dest", dest)
	_dialog.popup_centered()


func _on_confirmed() -> void:
	var dest: StringName = _dialog.get_meta("dest", &"")
	if dest == &"":
		return
	var r := GameState.travel_to_region(dest)
	EventBus.show_toast.emit(r.get("msg", ""))
