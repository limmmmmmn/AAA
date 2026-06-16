extends Control
## 대장간 UI: 녹슨 검을 화로에 올려 강화(골드+재료) → 최대치에서 판매(보석).
## 보석으로 자동화(자동 항아리꾼)를 산다. 열리면 세계 정지(상점 패턴).

@onready var _mats: Label = $Panel/Margin/VBox/MatsLabel
@onready var _sword: Label = $Panel/Margin/VBox/SwordLabel
@onready var _equipped: Label = $Panel/Margin/VBox/EquippedLabel
@onready var _put: Button = $Panel/Margin/VBox/Buttons/PutButton
@onready var _enhance: Button = $Panel/Margin/VBox/Buttons/EnhanceButton
@onready var _sell: Button = $Panel/Margin/VBox/Buttons/SellButton
@onready var _equip: Button = $Panel/Margin/VBox/Buttons/EquipButton
@onready var _autopot: Button = $Panel/Margin/VBox/AutoPotButton
@onready var _autoenhance: Button = $Panel/Margin/VBox/AutoEnhanceButton
@onready var _autodeliver: Button = $Panel/Margin/VBox/AutoDeliverButton
@onready var _close_button: Button = $Panel/Margin/VBox/CloseButton


func _ready() -> void:
	visible = false
	add_to_group("closable_modal") # Esc로 닫히는 모달
	EventBus.request_forge.connect(_open)
	EventBus.request_forge_close.connect(_close)
	EventBus.request_close_modals.connect(_close) # Esc
	EventBus.forge_changed.connect(_refresh)
	EventBus.materials_changed.connect(_refresh)
	EventBus.gems_changed.connect(func(_g: int) -> void: _refresh())
	EventBus.gold_changed.connect(func(_g: int) -> void: if visible: _refresh())
	_put.pressed.connect(func() -> void: GameState.forge_put_sword())
	_enhance.pressed.connect(func() -> void: GameState.forge_enhance())
	_sell.pressed.connect(func() -> void: GameState.forge_sell())
	_equip.pressed.connect(func() -> void: GameState.equip_forge_sword())
	_autopot.pressed.connect(func() -> void: GameState.buy_auto_pot())
	_autoenhance.pressed.connect(func() -> void: GameState.buy_auto_enhance())
	_autodeliver.pressed.connect(func() -> void: GameState.buy_auto_deliver())
	_close_button.pressed.connect(_close)
	# Space가 포커스된 버튼을 또 누르지 않도록 (Space = 대장간 닫기 전용)
	for b: Button in [_put, _enhance, _sell, _equip, _autopot, _autoenhance, _autodeliver, _close_button]:
		b.focus_mode = Control.FOCUS_NONE


## 대장간에서 [열기] → 패널만 띄운다. 일시정지 안 함 (계속 움직일 수 있음).
func _open() -> void:
	visible = true
	_refresh()


## [닫기]/멀어짐 → 패널을 내린다. 대장간 버튼이 동기화되도록 forge_closed 통지.
func _close() -> void:
	if not visible:
		return
	visible = false
	EventBus.forge_closed.emit()


func _refresh() -> void:
	if not visible:
		return
	_mats.text = "보석 %d    돌멩이 %d    강화석 %d    녹슨 검 %d" % [
		GameState.gems, GameState.material_count(&"stone"),
		GameState.material_count(&"enhance_stone"), GameState.rusty_swords]

	if GameState.forge_has_sword():
		_sword.text = "화로: 녹슨 검 +%d / +%d" % [GameState.forge_level, GameState.config.sword_max_level]
	else:
		_sword.text = "화로: 비어있음 — 녹슨 검을 올려 강화하세요"

	_put.visible = not GameState.forge_has_sword()
	_put.disabled = GameState.rusty_swords <= 0
	_put.text = "녹슨 검 올리기"

	_enhance.visible = GameState.forge_has_sword() and GameState.forge_level < GameState.config.sword_max_level
	if _enhance.visible:
		var c := GameState.forge_cost()
		_enhance.text = "강화 → +%d  (%dG + %s %d)" % [
			GameState.forge_level + 1, int(c.gold), GameState.material_name(c.mat), int(c.n)]
		_enhance.disabled = not GameState.forge_can_enhance()

	_sell.visible = GameState.forge_can_sell()
	_sell.text = "판매 (보석 +%d)" % GameState.config.sword_sell_gems

	# 장착: 화로의 검을 파티 공격력으로 (보석 ↔ 강함 선택)
	if GameState.equipped_sword_level >= 0:
		_equipped.text = "장착: +%d 검  (공격력 +%d)" % [
			GameState.equipped_sword_level, GameState.equipped_attack_bonus()]
	else:
		_equipped.text = "장착: 없음"
	_equip.visible = GameState.forge_has_sword()
	if _equip.visible:
		var bonus := GameState.forge_level * GameState.config.sword_attack_per_level
		_equip.text = "장착 (공격력 +%d)" % bonus
		# 이미 더 강한 검을 장착 중이면 막는다
		_equip.disabled = GameState.forge_level <= GameState.equipped_sword_level

	_gem_btn(_autopot, GameState.auto_pot, GameState.config.auto_pot_gem_cost, "자동 항아리꾼")
	_gem_btn(_autoenhance, GameState.auto_enhance, GameState.config.auto_enhance_gem_cost, "자동 강화")
	_gem_btn(_autodeliver, GameState.auto_deliver, GameState.config.auto_deliver_gem_cost, "자동 납품")


func _gem_btn(btn: Button, owned: bool, cost: int, label: String) -> void:
	if owned:
		btn.text = "%s  [보유중]" % label
		btn.disabled = true
	else:
		btn.text = "%s  (보석 %d)" % [label, cost]
		btn.disabled = GameState.gems < cost
