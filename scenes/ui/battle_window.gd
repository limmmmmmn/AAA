extends PanelContainer
## 1인칭 전투창 (드퀘 1~2 스타일, A-1). 아군 스프라이트를 그리지 않는다.
## 상단: 적 스프라이트(들) + 개별 HP바. 하단: 텍스트 로그(최근 몇 줄).
## 로직 없음 — BattleInstance의 시그널을 구독해 그리기만 한다.

const ENEMY_PX := 24      # 적 스프라이트 원본(24×24)을 1배수로 (업스케일 없이 또렷하게)
const MAX_LOG_LINES := 2

# 보상/희귀도/위험도 기준 카드 테마 (몬스터 이름 하드코딩 금지 — 전부 데이터로 판정).
const THEME_BLACK := {"bg": Color(0.04, 0.04, 0.06, 0.96), "border": Color(0.95, 0.95, 0.95)}
const THEME_ORANGE := {"bg": Color(0.42, 0.24, 0.05, 0.96), "border": Color(1, 0.65, 0.2)}
const THEME_TEAL := {"bg": Color(0.05, 0.22, 0.28, 0.96), "border": Color(0.4, 0.85, 1)}
const THEME_PURPLE := {"bg": Color(0.2, 0.07, 0.3, 0.96), "border": Color(0.82, 0.5, 1)}
const THEME_RED := {"bg": Color(0.34, 0.06, 0.08, 0.96), "border": Color(1, 0.45, 0.45)}
const GOLD_RICH_THRESHOLD := 8 # 이 이상이면 골드 보상 높음(주황)으로 본다

var battle: BattleInstance

@onready var _enemy_row: HBoxContainer = $VBox/EnemyRow
@onready var _log: VBoxContainer = $VBox/LogBox/Log

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
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER # 확장된 적 영역에서 세로 가운데
		# 컨테이너가 위치를 강제하므로, 자유 연출(흔들/돌진)용 holder 안에 스프라이트를 둔다.
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(ENEMY_PX, ENEMY_PX)
		var tex := TextureRect.new()
		tex.size = Vector2(ENEMY_PX, ENEMY_PX)
		tex.pivot_offset = Vector2(ENEMY_PX, ENEMY_PX) * 0.5 # 스케일 중심
		tex.expand_mode = TextureRect.EXPAND_KEEP_SIZE       # 원본 크기 유지
		tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED # 1배수로 가운데 그리기
		tex.texture = e.data.sprite
		holder.add_child(tex)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(ENEMY_PX, 4)
		bar.show_percentage = false
		bar.max_value = e.data.max_hp
		bar.value = e.hp
		col.add_child(holder)
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
	label.theme_type_variation = &"Bold" # 영문은 더 두꺼운 폰트(PixelOperator-Bold)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # 길어지면 줄바꿈 (창 크기 고정)
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

## 아군이 적을 때림 → 적 피격: 좌우로 흔들 + 흰 반짝 + 데미지 팝업. 회심이면 크게 우웅(와우).
func _on_party_acted(target_index: int, damage: int, is_crit: bool) -> void:
	var color := Color(1.0, 0.85, 0.1) if is_crit else Color(1.0, 0.95, 0.4)
	var targets: Array[int] = []
	if target_index < 0: # 베기라: 살아있는 모든 적
		for i in _enemy_sprites.size():
			if battle.enemies[i].hp >= 0:
				targets.append(i)
	elif target_index < _enemy_sprites.size():
		targets.append(target_index)
	for i in targets:
		var tex: Control = _enemy_sprites[i]
		_spawn_damage_popup(tex, damage, color, is_crit)
		if damage <= 0:
			_dodge(tex)          # 통하지 않음 → 가볍게 빗나간 듯 흔들
		else:
			_hit_react(tex, is_crit)
			if is_crit:
				_crit_pop(tex)   # 회심: 크게 우웅
	if is_crit:
		_show_crit_banner()
		EventBus.screen_shake.emit(5.0)


## 적 반격 → 적이 앞으로 우웅(돌진 모션) + 창이 붉게 깜빡(피격감).
func _on_enemy_acted(_damage: int) -> void:
	for i in _enemy_sprites.size():
		if battle.enemies[i].hp > 0:
			_lunge(_enemy_sprites[i]) # 맨 앞 살아있는 적이 돌진
			break
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	modulate = Color(1.0, 0.72, 0.72, modulate.a)
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.22)


# ─── 적 스프라이트 연출 (holder 안 자유 위치/스케일) ───

## 피격: 좌우로 빠르게 흔들. is_crit이면 진폭 ↑.
func _hit_react(tex: Control, big: bool) -> void:
	var a := 6.0 if big else 3.5
	var t := tex.create_tween()
	t.tween_property(tex, "position:x", a, 0.03)
	t.tween_property(tex, "position:x", -a, 0.05)
	t.tween_property(tex, "position:x", a * 0.6, 0.04)
	t.tween_property(tex, "position:x", -a * 0.35, 0.04)
	t.tween_property(tex, "position:x", 0.0, 0.04)
	_flash(tex)


## 적 공격: 화면 앞으로(아래로) 커지며 우웅 → 복귀.
func _lunge(tex: Control) -> void:
	var t := tex.create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(tex, "scale", Vector2(1.35, 1.35), 0.13)
	t.parallel().tween_property(tex, "position:y", 7.0, 0.13)
	t.tween_property(tex, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(tex, "position:y", 0.0, 0.2)


## 회심: 크게 우웅(와우) — 큰 스케일 펀치.
func _crit_pop(tex: Control) -> void:
	var t := tex.create_tween()
	t.tween_property(tex, "scale", Vector2(1.6, 1.6), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(tex, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 빗나감(통하지 않음): 옆으로 살짝 미끄러지듯.
func _dodge(tex: Control) -> void:
	var t := tex.create_tween()
	t.tween_property(tex, "position:x", 5.0, 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(tex, "position:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE)


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
	var tween := target.create_tween()
	tween.tween_property(target, "modulate", Color(3.2, 3.2, 3.2), 0.04) # 강한 흰 반짝
	tween.tween_property(target, "modulate", Color.WHITE, 0.16)


func _on_finished(result: Dictionary) -> void:
	if result.get("one_shot", false):
		_push_line(Locale.t("회심의 일격!! +%d G") % int(result.gold))
	else:
		_push_line(Locale.t("이겼다! +%d G") % int(result.gold))
	# 창이 "팍" 닫히는 속도감 — 승리 연출 후 즉시 제거
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.2, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
