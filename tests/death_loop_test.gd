extends Node
## v3 §8 사냥 허가 + §9 자동 철수 검증 (§7 비네트는 스크린샷으로 확인).
## godot --headless --path . res://tests/DeathLoopTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0
var _retreat_triggered := false
var _retreat_finished := false


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _field() -> RegionBase:
	return get_tree().get_first_node_in_group("field")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	EventBus.tactic_retreat_triggered.connect(func() -> void: _retreat_triggered = true)
	EventBus.tactic_retreat_finished.connect(func() -> void: _retreat_finished = true)

	# 2지역 진입 (승려 합류)
	GameState.add_gold(600)
	_field().get_node("BridgeGate")._on_confirmed()
	await get_tree().create_timer(1.4).timeout
	await get_tree().process_frame

	# §9 해금
	_check(GameState.tactic_retreat_unlocked, "승려 합류 → 자동 철수 해금")

	# §8 사냥 허가
	var snake: MonsterData = load("res://data/monsters/snake.tres")
	var orc: MonsterData = load("res://data/monsters/orc.tres")
	GameState.ensure_hunt_entry(snake)
	GameState.ensure_hunt_entry(orc)
	_check(GameState.is_hunted(&"snake"), "독사 기본 사냥 허가 ON")
	_check(not GameState.is_hunted(&"orc"), "오크 기본 사냥 허가 OFF (위협종)")
	GameState.set_hunted(&"snake", false)
	_check(not GameState.is_hunted(&"snake"), "독사 사냥 허가 토글 OFF")

	# §9 자동 철수 발동
	GameState.tactic_retreat_enabled = true
	GameState.full_heal()
	GameState.shared_hp = 20            # max 50 → 25%=12.5
	BattleManager.start_battle([snake]) # 철수가 중단시킬 전투
	GameState.apply_damage(10)          # → 10 (≤25%) → 철수 발동
	await get_tree().process_frame
	_check(_retreat_triggered, "HP 25% 이하 → 자동 철수 발동")
	_check(BattleManager.active_battles.is_empty(), "철수: 전투 일제 종료")
	var party: Node2D = get_tree().get_first_node_in_group("party")
	_check(party._retreating, "파티 철수 모드 진입")

	# 마을 도착 → 철수 완료
	var church := _field().entrance(&"church")
	_check(_field().is_village(church), "교회 부활점이 마을 타일 위")
	party.global_position = church
	await get_tree().create_timer(0.3).timeout
	_check(_retreat_finished and not party._retreating, "마을 도착 → 철수 완료")

	# 여관 회복 → 위험 해제 (재무장)
	GameState.shared_hp = 5
	GameState.full_heal()
	_check(GameState.shared_hp == GameState.shared_hp_max, "여관 전량 회복")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
