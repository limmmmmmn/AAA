extends Node
## 멤버별 HP & 패배 검증: godot --headless --path . res://tests/SharedHpTest.tscn

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
	GameState.crit_chance = 0.0
	GameState.max_battle_windows = 5

	# 데미지는 1지역부터 on (적 공격이 아군에게 들어간다)
	_check(GameState.damage_enabled, "데미지 기본 on (1지역부터)")
	var hp0 := GameState.total_hp()
	GameState.apply_damage(10)
	_check(GameState.total_hp() == hp0 - 10, "1지역에서도 데미지 10 적용됨")

	# 2지역 진입 → 전원 가득 회복
	GameState.enable_damage_for_region2()
	_check(GameState.damage_enabled and GameState.total_hp() == GameState.total_max_hp(), "2지역 진입: 전량 회복")
	_check(GameState.member_max_hp(0) == GameState.config.hero_max_hp, "용사 최대 HP = config.hero_max_hp")

	# 피격 경감 (사슬 갑옷): 데미지 4 → 2
	GameState.damage_reduction_mult = 0.5
	GameState.apply_damage(4)
	_check(GameState.member_hp(0) == GameState.member_max_hp(0) - 2, "사슬 갑옷: 데미지 4→2 경감")
	GameState.damage_reduction_mult = 1.0
	GameState.full_heal()

	# 전투 반격이 노린 멤버의 HP를 깎는다 (용사 1인이라 용사 피격)
	var elite: MonsterData = load("res://data/monsters/elite_bat.tres")
	GameState.party_attack = 1  # 오래 버티게
	var battle := BattleManager.start_battle([elite])
	var hero_before := GameState.member_hp(0)
	battle.tick(GameState.turn_interval)  # 1라운드 (용사 공격 + 정예 반격)
	_check(GameState.member_hp(0) == hero_before - elite.attack, "적 반격이 용사 HP 차감 (-%d)" % elite.attack)

	# 패배 트리거: 용사 HP를 낮춰 다음 반격에 KO
	GameState.member_hps[0] = 3
	battle.tick(GameState.turn_interval)  # 정예 반격 4 → 0
	_check(GameState.total_hp() == 0 and _defeated, "전원 KO → party_defeated 발신")

	# 패배 패널티 + 부활
	GameState.gold = 100
	GameState.apply_defeat_penalty()
	_check(GameState.gold == 50, "소지금 절반 차감")
	_check(GameState.total_hp() == GameState.total_max_hp(), "부활 시 전원 회복")

	BattleManager.abort_all()
	_check(BattleManager.active_battles.is_empty(), "패배 시 전투 전체 중단")

	# 베기라(전체 공격): 두 적 동시 타격
	GameState.all_attack = true
	GameState.party_attack = 5
	var slime: MonsterData = load("res://data/monsters/slime.tres")
	var multi := BattleManager.start_battle([slime, slime])
	multi.tick(GameState.turn_interval)
	_check(multi.enemies[0].hp == 3 and multi.enemies[1].hp == 3, "베기라: 두 적 동시에 -5")
	GameState.all_attack = false

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	BattleManager.abort_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
