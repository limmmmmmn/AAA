extends Area2D
## 고전 JRPG식 근접 상호작용 베이스 (서브클래스가 path로 extends).
## 가까이 가면 [상호작용] 버튼(프롬프트)이 뜨고,
## Space(또는 클릭)로 작동한다. 멀어지면 닫힌다. 일시정지 없음 — 떠 있어도 계속 움직인다.
##
## 서브클래스는 _setup/_tick/_on_leave/_can_interact/_interact/_prompt_text 만 구현.

@onready var _prompt: Button = get_node_or_null("Prompt")

var _in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt:
		_prompt.focus_mode = Control.FOCUS_NONE # Space가 포커스 버튼을 또 누르지 않도록
		_prompt.visible = false
		_prompt.pressed.connect(_activate)
	_setup()
	_tick()


func _on_body_entered(body: Node2D) -> void:
	if body is Party:
		_in_range = true
		if _prompt:
			_prompt.visible = true
		_tick()


func _on_body_exited(body: Node2D) -> void:
	if body is Party:
		_in_range = false
		if _prompt:
			_prompt.visible = false
		_on_leave()
		_tick()


func _process(_delta: float) -> void:
	_tick() # 매 프레임 상태 갱신 (쿨타임 카운트다운 등)
	if _prompt and _in_range:
		_prompt.text = _prompt_text()
		_prompt.disabled = not _can_interact()
	if _in_range and Input.is_action_just_pressed("interact"):
		_activate()


## Space 또는 프롬프트 클릭 → 조건 맞으면 상호작용.
func _activate() -> void:
	if _in_range and _can_interact():
		_interact()
	_tick()


# ── 서브클래스 훅 (필요한 것만 오버라이드) ──
func _setup() -> void: pass             ## _ready 시 1회 (시그널 연결 등)
func _tick() -> void: pass              ## 매 프레임 시각 갱신 (스프라이트/상태 라벨)
func _on_leave() -> void: pass          ## 범위에서 벗어날 때 (열린 패널 닫기 등)
func _can_interact() -> bool: return true  ## 지금 작동 가능한가 (쿨타임/열쇠 등)
func _interact() -> void: pass          ## 실제 작동 (깨기/열기/UI 토글)
func _prompt_text() -> String: return "열기 [Space]" ## 프롬프트 버튼 글자
