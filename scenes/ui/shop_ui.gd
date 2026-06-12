extends Control
## 마을 상점 UI. 슬롯은 UpgradeData .tres에서 자동 생성 (수동 버튼 배치 금지).
## 윗줄 = 전투 축, 아랫줄 = 필드 축. 살 수 없는 항목도 가격과 함께 회색으로 보인다.

@onready var _combat_row: HFlowContainer = $Panel/Margin/VBox/CombatRow
@onready var _field_row: HFlowContainer = $Panel/Margin/VBox/FieldRow
@onready var _close_button: Button = $Panel/Margin/VBox/CloseButton


func _ready() -> void:
	visible = false
	EventBus.party_entered_village.connect(_open)
	EventBus.party_exited_village.connect(_close)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_close_button.pressed.connect(_close)


func _open() -> void:
	visible = true
	_rebuild()


func _close() -> void:
	visible = false


func _on_gold_changed(_amount: int) -> void:
	if visible:
		_refresh()


func _on_upgrade_purchased(_upgrade: UpgradeData) -> void:
	if visible:
		_refresh()


func _rebuild() -> void:
	_fill_row(_combat_row, "combat")
	_fill_row(_field_row, "field")
	_refresh()


func _fill_row(row: Container, axis: String) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for upgrade in GameState.upgrades_for_axis(axis):
		var button := Button.new()
		button.custom_minimum_size = Vector2(84, 62)
		button.clip_text = false
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 8)
		button.set_meta("upgrade", upgrade)
		button.pressed.connect(_on_slot_pressed.bind(upgrade))
		row.add_child(button)


func _refresh() -> void:
	for row in [_combat_row, _field_row]:
		for button: Button in row.get_children():
			var upgrade: UpgradeData = button.get_meta("upgrade")
			if GameState.owned_count(upgrade) >= upgrade.max_purchases:
				button.text = "%s\n[보유중]" % upgrade.display_name
				button.disabled = true
			else:
				var cost := GameState.current_cost(upgrade)
				button.text = "%s\n%d G\n%s" % [upgrade.display_name, cost, upgrade.description]
				button.disabled = GameState.gold < cost # 회색이어도 가격은 보인다 — 다음 목표 제시


func _on_slot_pressed(upgrade: UpgradeData) -> void:
	GameState.purchase(upgrade)
