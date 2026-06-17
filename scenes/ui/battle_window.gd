extends PanelContainer
## 1인칭 전투창 (드퀘 1~2 스타일, A-1). 아군 스프라이트를 그리지 않는다.
## 상단: 적 스프라이트(들) + 개별 HP바. 하단: 텍스트 로그(최근 몇 줄).
## 로직 없음 — BattleInstance의 시그널을 구독해 그리기만 한다.

const ENEMY_SIZE := Vector2(40, 40)
const MAX_LOG_LINES := 3

# 보상/희귀도/위험도 기준 카드 테마 (몬스터 이름 하드코딩 금지 — 전부 데이터로 판정).
const THEME_BLACK := {"bg": Color(0.04, 0.04, 0.06, 0.96), "border": Color(0.95, 0.95, 0.95)}
const THEME_ORANGE := {"bg": Color(0.42, 0.24, 0.05, 0.96), "border": Color(1, 0.65, 0.2)}
const THEME_TEAL := {"bg": Color(0.05, 0.22, 0.28, 0.96), "border": Color(0.4, 0.85, 1)}
const THEME_PURPLE := {"bg": Color(0.2, 0.07, 0.3, 0.96), "border": Color(0.82, 0.5, 1)}
const THEME_RED := {"bg": Color(0.34, 0.06, 0.08, 0.96), "border": Color(1, 0.45, 0.45)}
const GOLD_RICH_THRESHOLD := 8 # 이 이상이면 골드 보상 높음(주황)으로 본다

var battle: BattleInstance

@onready var _enemy_row: HBoxContainer = $VBox/EnemyRow
@onready var _log: VBoxContainer = $VBox/Log

var _enemy_sprites: Array[TextureRect] = []
var _enemy_bars: Array[ProgressBar] = []
var _hit_tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func bind(new_battle: BattleInstance) -> void:
	battle = new_battle
	_apply_card_theme()
	_build_enemy_slots()
	_push_line(battle.intro_text())
	battle.log_line.connect(_push_line)
	battle.party_acted.connect(_on_party_acted)
	battle.enemy_acted.connect(_on_enemy_acted)
	battle.state_updated.connect(_refresh)
	battle.finished.connect(_on_finished)
	battle.aborted.connect(_on_aborted)
	battle.fled.connect(_on_fled)


## 전투의 보상/희귀도/위험도 데이터로 카드 색을 정한다 (몬스터 종류 직접 매핑 아님).
## 우선순위: 메탈/특수(보라) > 위험(빨강) > 희귀 드랍(청록) > 골드 높음(주황) > 기본(검정).
func get_battle_card_theme() -> Dictionary:
	var metal := false
	var dangerous := false
	var rare := false
	var gold := 0
	for e in battle.enemies:
		var d: MonsterData = e.data
		if d.flee_after_hits > 0 or d.flee_after_seconds > 0:
			metal = true                       # 메탈류 = 특수/희귀
		if not d.hunt_default or d.attack >= 12:
			dangerous = true                   # 위협종(오크 등) 또는 고공격
		if d.sword_drop > 0.0:
			rare = true                        # 희귀 드랍(녹슨 검 등)
		gold = maxi(gold, d.gold_reward)
	if metal:
		return THEME_PURPLE
	if dangerous:
		return THEME_RED
	if rare:
		return THEME_TEAL
	if gold >= GOLD_RICH_THRESHOLD:
		return THEME_ORANGE
	return THEME_BLACK


func _apply_card_theme() -> void:
	var t := get_battle_card_theme()
	var sb := StyleBoxFlat.new()
	sb.bg_color = t.bg
	sb.set_border_width_all(2)
	sb.border_color = t.border
	sb.content_margin_left = 6
	sb.content_margin_top = 5
	sb.content_margin_right = 6
	sb.content_margin_bottom = 5
	add_theme_stylebox_override("panel", sb)


func _build_enemy_slots() -> void:
	for e in battle.enemies:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var tex := TextureRect.new()
		tex.custom_minimum_size = ENEMY_SIZE
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture = e.data.sprite
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(ENEMY_SIZE.x, 4)
		bar.show_percentage = false
		bar.max_value = e.data.max_hp
		bar.value = e.hp
		col.add_child(tex)
		col.add_child(bar)
		_enemy_row.add_child(col)
		_enemy_sprites.append(tex)
		_enemy_bars.append(bar)


func _refresh() -> void:
	if not battle:
		return
	for i in _enemy_bars.size():
		var alive: bool = battle.enemies[i].hp > 0
		_enemy_bars[i].value = battle.enemies[i].hp
		_enemy_sprites[i].modulate.a = 1.0 if alive else 0.25
		_enemy_bars[i].modulate.a = 1.0 if alive else 0.25


# ─── 텍스트 로그 (최근 MAX_LOG_LINES줄만 보인다) ───

func _push_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.86))
	label.modulate.a = 0.0
	_log.add_child(label)
	label.create_tween().tween_property(label, "modulate:a", 1.0, 0.12)
	while _log.get_child_count() > MAX_LOG_LINES:
		var oldest := _log.get_child(0)
		_log.remove_child(oldest)
		oldest.queue_free()


# ─── 연출 ───

func _on_party_acted(target_index: int, damage: int, is_crit: bool) -> void:
	var color := Color(1.0, 0.85, 0.1) if is_crit else Color(1.0, 0.95, 0.4)
	if target_index < 0:
		# 베기라: 살아있는 모든 적에게 팝업
		for i in _enemy_sprites.size():
			if battle.enemies[i].hp >= 0:
				_spawn_damage_popup(_enemy_sprites[i], damage, color, is_crit)
				_flash(_enemy_sprites[i])
	else:
		var anchor: Control = _enemy_sprites[target_index] if target_index < _enemy_sprites.size() else self
		_spawn_damage_popup(anchor, damage, color, is_crit)
		_flash(anchor)
	if is_crit:
		_show_crit_banner()
		EventBus.screen_shake.emit(5.0)


## 적 반격 — 1인칭이라 맞을 아군 스프라이트가 없으니 프레임을 붉게 깜빡인다.
func _on_enemy_acted(_damage: int) -> void:
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	modulate = Color(1.0, 0.7, 0.7, modulate.a)
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.25)


func _show_crit_banner() -> void:
	var label := Label.new()
	label.text = "회심의 일격!"
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.0))
	label.add_theme_font_size_override("font_size", 13)
	label.z_index = 12
	add_child(label)
	label.position = Vector2(8, 4)
	var tween := label.create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


func _on_fled(message: String) -> void:
	_push_line(message)
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _on_aborted() -> void:
	# 패배로 강제 종료 — 즉시 사라진다 (승리 연출 없음)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _spawn_damage_popup(anchor: Control, amount: int, color: Color, big: bool) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	label.add_theme_font_size_override("font_size", 20 if big else 12)
	label.z_index = 10
	# Container가 자식 위치를 강제하므로 앵커(TextureRect)에 붙인다
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
	if result.get("one_shot", false):
		_push_line("회심의 일격!! +%d G" % int(result.gold))
	else:
		_push_line("이겼다! +%d G" % int(result.gold))
	# 창이 "팍" 닫히는 속도감 — 승리 연출 후 즉시 제거
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.2, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
