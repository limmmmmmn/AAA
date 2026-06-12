extends PanelContainer
## BattleInstance(enemies 배열)를 구독해서 그리기만 하는 전투창. 로직 없음.
## 좌측: 용사+동료 4슬롯(1지역엔 1칸만 채움, 나머지는 동료가 올 빈 자리).
## 우측: 적 스프라이트(1지역 1마리). 상단: 적 전체 HP바. 데미지 팝업.

const SLOT_SIZE := Vector2(22, 22)
const ENEMY_SIZE := Vector2(40, 40)

var battle: BattleInstance

@onready var _name_label: Label = $Margin/VBox/Top/NameLabel
@onready var _hp_bar: ProgressBar = $Margin/VBox/Top/HPBar
@onready var _party_grid: GridContainer = $Margin/VBox/Arena/PartyGrid
@onready var _enemy_box: HBoxContainer = $Margin/VBox/Arena/EnemyBox
@onready var _status: Label = $Margin/VBox/Status

var _party_slots: Array[TextureRect] = []
var _enemy_slots: Array[TextureRect] = []


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func bind(new_battle: BattleInstance) -> void:
	battle = new_battle
	_build_party_slots()
	_build_enemy_slots()
	var front := battle.front_data()
	_name_label.text = front.display_name
	_hp_bar.max_value = _total_max_hp()
	_hp_bar.value = _total_hp()
	_status.text = "전투 중..."
	battle.turn_played.connect(_on_turn_played)
	battle.state_updated.connect(_refresh)
	battle.finished.connect(_on_finished)
	battle.aborted.connect(_on_aborted)


func _build_party_slots() -> void:
	var members := GameState.party_members()
	for i in 4: # 처음부터 4칸 구조 (빈 자리는 동료가 올 자리)
		var slot := TextureRect.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if i < members.size():
			slot.texture = members[i].sprite
		else:
			slot.modulate = Color(1, 1, 1, 0.12) # 빈 슬롯 = 희미하게
		_party_grid.add_child(slot)
		_party_slots.append(slot)


func _build_enemy_slots() -> void:
	for e in battle.enemies:
		var tex := TextureRect.new()
		tex.custom_minimum_size = ENEMY_SIZE
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture = e.data.sprite
		_enemy_box.add_child(tex)
		_enemy_slots.append(tex)


func _total_hp() -> int:
	var sum := 0
	for e in battle.enemies:
		sum += int(e.hp)
	return sum


func _total_max_hp() -> int:
	var sum := 0
	for e in battle.enemies:
		sum += int(e.data.max_hp)
	return sum


func _refresh() -> void:
	if battle:
		_hp_bar.value = _total_hp()
		# 죽은 적 슬롯은 흐리게
		for i in _enemy_slots.size():
			_enemy_slots[i].modulate.a = 1.0 if battle.enemies[i].hp > 0 else 0.25


func _on_turn_played(target_index: int, party_damage: int, incoming_damage: int) -> void:
	if target_index < 0:
		# 베기라: 살아있는 모든 적에게 팝업
		for i in _enemy_slots.size():
			if battle.enemies[i].hp >= 0:
				_spawn_damage_popup(_enemy_slots[i], party_damage, Color(0.7, 0.9, 1.0))
				_flash(_enemy_slots[i])
	else:
		var enemy_anchor: Control = _enemy_slots[target_index] if target_index < _enemy_slots.size() else self
		_spawn_damage_popup(enemy_anchor, party_damage, Color(1.0, 0.95, 0.4))
		_flash(enemy_anchor)
	if incoming_damage > 0 and not _party_slots.is_empty():
		_spawn_damage_popup(_party_slots[0], incoming_damage, Color(1.0, 0.45, 0.4))


func _on_aborted() -> void:
	# 패배로 강제 종료 — 즉시 사라진다 (승리 연출 없음)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _spawn_damage_popup(anchor: Control, amount: int, color: Color) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	label.add_theme_font_size_override("font_size", 12)
	label.z_index = 10
	# PanelContainer/Container는 자식 위치를 강제하므로 앵커(TextureRect)에 붙인다
	anchor.add_child(label)
	label.position = Vector2(anchor.size.x * 0.5 - 5.0, 0.0)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 18.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.15)
	tween.tween_callback(label.queue_free)


func _flash(target: Control) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(2.0, 1.2, 1.2), 0.06)
	tween.tween_property(target, "modulate", Color.WHITE, 0.12)


func _on_finished(result: Dictionary) -> void:
	_hp_bar.value = 0
	if result.get("one_shot", false):
		_status.text = "회심의 일격!! +%d G" % int(result.gold)
		_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		_status.text = "승리! +%d G" % int(result.gold)
	# 창이 "팍" 닫히는 속도감 — 승리 연출 후 즉시 제거
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.2, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
