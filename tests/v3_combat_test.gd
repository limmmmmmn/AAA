extends Node
## v3 §1/§2/§4 검증: 방어력·회심, 메탈 도주, 무리 출현.
## godot --headless --path . res://tests/V3CombatTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0
var _crit_seen := false
var _fled_msg := ""


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.max_battle_windows = 9 # 테스트에서 다중 전투 허용

	# §1 방어력: 일반 공격 = max(atk - def, 0)
	var orc: MonsterData = load("res://data/monsters/orc.tres")
	_check(orc.hunt_default == false, "오크 hunt_default=false (위협종)")

	GameState.crit_chance = 0.0
	GameState.party_attack = 5
	var dummy := MonsterData.new()
	dummy.id = &"dummy"; dummy.display_name = "허수아비"; dummy.max_hp = 100; dummy.defense = 3
	var b := BattleManager.start_battle([dummy])
	var hp0: int = b.enemies[0].hp
	b.tick(GameState.turn_interval)
	_check(hp0 - b.enemies[0].hp == 2, "방어력: 5-3=2 데미지 (실제 %d)" % (hp0 - b.enemies[0].hp))
	BattleManager.abort_all()

	# §1 회심: 방어 무시 = 전체 공격력
	GameState.crit_chance = 1.0
	var dummy2 := MonsterData.new()
	dummy2.id = &"d2"; dummy2.display_name = "허수아비2"; dummy2.max_hp = 100; dummy2.defense = 99
	var bc := BattleManager.start_battle([dummy2])
	bc.party_acted.connect(func(_t: int, _d: int, crit: bool) -> void: _crit_seen = crit or _crit_seen)
	var hpc: int = bc.enemies[0].hp
	bc.tick(GameState.turn_interval)
	_check(hpc - bc.enemies[0].hp == 5, "회심: 방어99 무시하고 5 데미지")
	_check(_crit_seen, "회심 플래그 party_acted 전달")
	BattleManager.abort_all()

	# §2 메탈: 평타 0, 회심만 유효 / 피격 5회 도주
	GameState.crit_chance = 0.0
	GameState.party_attack = 8
	var metal: MonsterData = load("res://data/monsters/metal_slime.tres")
	_check(metal.defense == 99 and metal.max_hp == 10, "메탈 defense99/hp10")
	_check(metal.allow_group == false, "메탈 무리 제외")
	var bm := BattleManager.start_battle([metal])
	bm.fled.connect(func(msg: String) -> void: _fled_msg = msg)
	for i in 6:
		bm.tick(GameState.turn_interval)
	_check(bm.enemies[0].hp == 10, "메탈: 평타는 0 데미지(방어99)")
	_check(_fled_msg != "", "메탈: 5피격 후 도망 (%s)" % _fled_msg)
	_check(not BattleManager.active_battles.has(bm), "도주 전투는 보상 없이 제거")

	# §2 메탈을 회심으로 처치 (수동 틱)
	GameState.crit_chance = 1.0
	GameState.party_attack = 10
	var bk := BattleManager.start_battle([load("res://data/monsters/metal_slime.tres")])
	var kres := {}
	bk.finished.connect(func(r: Dictionary) -> void: kres.merge(r))
	bk.tick(GameState.turn_interval)
	_check(kres.get("gold", 0) == 150, "메탈 회심 처치 → 보상 150G")
	BattleManager.abort_all()

	# §4 무리 출현: group_table로 규모 추첨
	GameState.group_table = [0.0, 0.0, 1.0]
	_check(GameState.roll_group_size() == 3, "무리 확률표 [0,0,1] → 3마리")
	GameState.group_table = [1.0]
	_check(GameState.roll_group_size() == 1, "기본 → 항상 1마리")

	# 무리 전투: 골드/kill 합산 (수동 틱)
	GameState.crit_chance = 0.0
	GameState.party_attack = 99
	var snake: MonsterData = load("res://data/monsters/snake.tres")
	var kills_before := GameState.kills(&"snake")
	var bg := BattleManager.start_battle([snake, snake, snake])
	var gres := {}
	bg.finished.connect(func(r: Dictionary) -> void: gres.merge(r))
	for i in 4:
		bg.tick(GameState.turn_interval)
	_check(gres.get("group", 0) == 3, "무리 전투 3마리")
	_check(gres.get("gold", 0) == snake.gold_reward * 3, "골드 마리수 합산 (%d)" % gres.get("gold", 0))
	_check(GameState.kills(&"snake") == kills_before + 3, "kill_count 마리수 합산")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
