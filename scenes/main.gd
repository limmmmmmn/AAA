extends Node
## 메인 씬. 지역(Region)을 동적으로 로드/전환하고, 카메라 추종(고정 640×360 줌)·
## 첫 동시 전투 연출·지역 전환 페이드·패배/부활을 담당한다.

const REGION1 := preload("res://scenes/field/Field.tscn") # 맵은 하나 — 단계만 갈아끼운다

@onready var _camera: Camera2D = $Camera2D
@onready var _host: Node2D = $RegionHost
@onready var _fade: ColorRect = $UILayer/Overlay/Fade
@onready var _death_label: Label = $UILayer/Overlay/DeathLabel

var _region: RegionBase
var _party: Node2D
var _busy: bool = false   # 전환/사망 연출 중 (입력성 이벤트 잠금)
var _shake: float = 0.0


func _ready() -> void:
	# 맵은 1지역 하나로 고정 — 어떤 단계든 같은 맵 위에서 시작한다.
	await _load_field(&"")
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.party_defeated.connect(_on_defeat)
	EventBus.screen_shake.connect(_on_screen_shake)
	EventBus.region_changed.connect(_on_region_changed) # 지역 노드 구매 → 도착 토스트


func _process(delta: float) -> void:
	if is_instance_valid(_party):
		_camera.global_position = _party.global_position
	# 화면 흔들림 (회심의 일격 연출, v3 §1)
	if _shake > 0.1:
		_shake = maxf(0.0, _shake - delta * 28.0)
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _on_screen_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# ─── 지역(맵) 로드 — 항상 1지역 맵 ───

func _load_field(entrance_id: StringName) -> void:
	if _region and is_instance_valid(_region):
		_region.queue_free()
	_region = REGION1.instantiate()
	_host.add_child(_region)
	await get_tree().process_frame # 지역 _ready(페인팅·파티 그룹 등록) 대기
	_party = _region.get_node("Party")
	if entrance_id != &"":
		_party.global_position = _region.entrance(entrance_id)
	var lim := _region.camera_limit()
	_camera.limit_left = int(lim.position.x)
	_camera.limit_top = int(lim.position.y)
	_camera.limit_right = int(lim.end.x)
	_camera.limit_bottom = int(lim.end.y)
	_camera.zoom = Vector2.ONE # 고정 640×360 시야 (자동 줌 없음)
	_camera.global_position = _party.global_position
	_camera.reset_smoothing()


# ─── 단계 진행 안내 (실제 전환은 패시브 트리의 지역 노드 구매가 한다) ───
## 지역 노드를 사면 GameState.set_stage_to → region_changed → 적/틴트 교체 + 도착 토스트.

func _on_region_changed(_id: StringName) -> void:
	var s := GameState.current_stage()
	if s == null:
		return
	var msg: String = s.arrive_toast if s.arrive_toast != "" \
		else Locale.t("%s 도착") % GameState.stage_name()
	EventBus.show_toast.emit(msg)


# ─── 패배 / 부활 (B-2) ───

func _on_defeat() -> void:
	if _busy:
		return
	_busy = true
	BattleManager.abort_all()
	_death_label.text = Locale.t("%s는 죽어버렸다...") % Locale.t(GameState.config.hero_name)
	await _do_fade(1.0)
	_death_label.visible = true
	await get_tree().create_timer(1.4).timeout
	GameState.apply_defeat_penalty()               # 소지금 절반 + 전량 회복
	_party.global_position = _region.entrance(&"church")
	_camera.global_position = _party.global_position
	_camera.reset_smoothing()
	_death_label.visible = false
	await _do_fade(0.0)
	EventBus.show_toast.emit("교회에서 눈을 떴다... (소지금 절반을 잃었다)")
	_busy = false


func _do_fade(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", target_alpha, 0.4)
	await tween.finished


# ─── 카메라 연출 ───

func _on_battle_started(_battle: BattleInstance) -> void:
	if BattleManager.active_battles.size() >= 2 and not GameState.dual_battle_celebrated:
		GameState.dual_battle_celebrated = true
		# 첫 동시 전투 한정: 잠깐 줌아웃해 두 전투를 보여주고 다시 640×360으로 복귀
		var tween := create_tween()
		tween.tween_property(_camera, "zoom", Vector2.ONE * 0.82, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(1.2)
		tween.tween_property(_camera, "zoom", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		EventBus.show_toast.emit("동시 전투 발생! 파티는 멈추지 않는다!")
