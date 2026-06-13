extends Node
## A-2 전투 리듬(턴 교대) 검증: 파티 행동 → 텀 → 적 행동.
## godot --headless --path . res://tests/TurnRhythmTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0
var _events: Array[String] = []
var _logs: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _wire(b: BattleInstance) -> void:
	b.party_acted.connect(func(_t: int, _d: int, _c: bool) -> void: _events.append("party"))
	b.enemy_acted.connect(func(_d: int) -> void: _events.append("enemy"))
	b.log_line.connect(func(t: String) -> void: _logs.append(t))


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame

	# 2지역 조건(데미지 on)에서 적 반격이 실제로 일어난다
	GameState.enable_damage_for_region2()
	GameState.crit_chance = 0.0
	GameState.party_attack = 1   # 적이 한 라운드에 안 죽도록

	var snake: MonsterData = load("res://data/monsters/snake.tres")
	var beat: float = minf(GameState.turn_beat_delay, GameState.turn_interval * 0.5)
	var windup: float = GameState.turn_interval - beat

	# ── 비트 분리: windup만 지나면 파티만 행동, 적은 아직 텀 대기 ──
	var b := BattleManager.start_battle([snake])
	_wire(b)
	b.tick(windup + 0.001)
	_check(_events == ["party"], "windup 경과: 파티만 행동(적은 텀 대기) — %s" % str(_events))
	b.tick(beat)
	_check(_events == ["party", "enemy"], "텀(beat) 경과: 그제서야 적 행동 — %s" % str(_events))
	# 로그도 파티 → 적 순서로 한 줄씩
	_check(_logs.size() == 2 and _logs[0].contains("용사의 공격") and _logs[1].contains("독사의 공격"),
		"로그 순서: 파티 공격 → 적 공격 (%s)" % str(_logs))
	BattleManager.abort_all()

	# ── 라운드 총합 = turn_interval: 한 번의 tick(turn_interval)이 정확히 1라운드 ──
	_events.clear()
	_logs.clear()
	var b2 := BattleManager.start_battle([snake])
	_wire(b2)
	b2.tick(GameState.turn_interval)
	_check(_events == ["party", "enemy"], "tick(turn_interval) = 정확히 1라운드(파티1·적1) — %s" % str(_events))
	BattleManager.abort_all()

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
