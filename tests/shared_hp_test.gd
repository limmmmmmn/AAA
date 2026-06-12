extends Node
## B-2 공유 HP & 패배 검증: godot --headless --path . res://tests/SharedHpTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0
var _defeated := false


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
	EventBus.party_defeated.connect(func() -> void: _defeated = true)

	# 1지역: damage_enabled off → 공유 HP 안 깎임
	_check(not GameState.damage_enabled, "1지역은 데미지 off")
	GameState.apply_damage(10)
	_check(GameState.shared_hp == GameState.shared_hp_max, "1지역에선 공유 HP 불변")

	# 2지역 진입 시뮬레이션
	GameState.enable_damage_for_region2()
	_check(GameState.damage_enabled and GameState.shared_hp == GameState.shared_hp_max, "2지역: 데미지 on + 전량 회복")

	# 피격 경감
	GameState.damage_reduction_mult = 0.5
	GameState.apply_damage(4)
	_check(GameState.shared_hp == GameState.shared_hp_max - 2, "사슬 갑옷: 데미지 4→2 경감")
	GameState.damage_reduction_mult = 1.0
	GameState.full_heal()

	# 전투 반격이 공유 HP를 깎는다
	var elite: MonsterData = load("res://data/monsters/elite_bat.tres")
	GameState.party_attack = 1  # 오래 버티게 (격파 지연)
	var battle := BattleManager.start_battle([elite])
	var hp_before := GameState.shared_hp
	battle.tick(GameState.turn_interval)  # 1턴
	_check(GameState.shared_hp == hp_before - elite.attack, "전투 반격이 공유 HP 차감 (-%d)" % elite.attack)

	# 패배 트리거
	GameState.shared_hp = 3
	battle.tick(GameState.turn_interval)  # incoming 4 → 0
	_check(GameState.shared_hp == 0 and _defeated, "shared_hp 0 → party_defeated 발신")

	# 패배 패널티 + 부활
	GameState.gold = 100
	GameState.apply_defeat_penalty()
	_check(GameState.gold == 50, "소지금 절반 차감")
	_check(GameState.shared_hp == GameState.shared_hp_max, "부활 시 전량 회복")

	# 전투 중단
	BattleManager.abort_all()
	_check(BattleManager.active_battles.is_empty(), "패배 시 전투 전체 중단")

	# 베기라(전체 공격): 두 적 동시 타격
	GameState.all_attack = true
	GameState.party_attack = 5
	var snake_like: MonsterData = load("res://data/monsters/slime.tres")
	var multi := BattleManager.start_battle([snake_like, snake_like])
	multi.tick(GameState.turn_interval)
	_check(multi.enemies[0].hp == 3 and multi.enemies[1].hp == 3, "베기라: 두 적 동시에 -5")
	GameState.all_attack = false

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
