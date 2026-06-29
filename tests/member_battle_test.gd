extends Node
## 멤버별 전투 행동 검증 (용사+승려 각자 공격, 적은 멤버를 노려 반격).
## godot --headless --path . res://tests/MemberBattleTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _dummy(hp: int, atk: int) -> MonsterData:
	var d := MonsterData.new()
	d.id = &"dummy"; d.display_name = "허수아비"; d.max_hp = hp; d.attack = atk; d.defense = 0
	return d


func _log_has(lines: Array, sub: String) -> bool:
	for s: String in lines:
		if s.contains(sub):
			return true
	return false


func _ready() -> void:
	GameState.reset_to_new_game() # 이전 세이브 영향 없이 1지역 솔로 용사로 깨끗하게 시작
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.crit_chance = 0.0
	GameState.max_battle_windows = 5

	# ── 데미지 on(1지역부터), 용사 1인 ── 한 라운드 = 용사 공격 + 적 반격(데미지)
	GameState.full_heal()
	var hero_hp0 := GameState.member_hp(0)
	var acted_a := [0]
	var enemy_a := [0]
	var log_a: Array = []
	var d1 := _dummy(1000, 5)
	var hp1 := 1000
	var b1 := BattleManager.start_battle([d1])
	b1.party_acted.connect(func(_t: int, _d: int, _c: bool) -> void: acted_a[0] += 1)
	b1.enemy_acted.connect(func(_d: int) -> void: enemy_a[0] += 1)
	b1.log_line.connect(func(s: String) -> void: log_a.append(s))
	b1.tick(GameState.turn_interval)
	_check(acted_a[0] == 1, "한 라운드에 멤버 1명 공격 (용사)")
	_check(b1.enemies[0].hp == hp1 - GameState.hero_attack, "용사 데미지가 적에게 들어감")
	_check(enemy_a[0] == 1 and GameState.member_hp(0) == hero_hp0 - 5, "1지역에서도 적 반격이 용사에게 -5")
	_check(_log_has(log_a, "%s의 공격" % GameState.config.hero_name), "용사 공격 로그")
	BattleManager.abort_all()

	# ── 용사+승려 ── 한 라운드 = 용사 공격 + 승려 공격 + 적 반격
	GameState.damage_enabled = true
	var priest: CompanionData = GameState.companion_catalog.get(&"priest")
	GameState.add_companion(priest)
	GameState.full_heal()
	_check(GameState.member_count() == 2, "승려 합류 → 멤버 2명")
	var atks := GameState.member_attacks()
	_check(atks.size() == 2 and atks[0] == GameState.hero_attack and atks[1] == priest.attack_bonus, "멤버별 공격력 [용사, 승려]")

	var acted_b := [0]
	var enemy_b := [0]
	var log_b: Array = []
	GameState.crit_chance = 0.0 # 회심 끄기 — 데미지/로그 결정적으로 (승려 운으로 가끔 크리 → 플래키 방지)
	var d2 := _dummy(1000, 6)
	var b2 := BattleManager.start_battle([d2])
	b2.party_acted.connect(func(_t: int, _d: int, _c: bool) -> void: acted_b[0] += 1)
	b2.enemy_acted.connect(func(_d: int) -> void: enemy_b[0] += 1)
	b2.log_line.connect(func(s: String) -> void: log_b.append(s))
	b2.tick(GameState.turn_interval)
	_check(acted_b[0] == 2, "2지역: 한 라운드에 멤버 2명 각자 공격")
	_check(b2.enemies[0].hp == 1000 - (GameState.hero_attack + priest.attack_bonus), "두 멤버 데미지 합산이 적에게 들어감")
	_check(enemy_b[0] == 1 and GameState.total_hp() == GameState.total_max_hp() - 6, "적이 멤버 1명을 노려 -6 (개별 HP)")
	_check(_log_has(log_b, "%s의 공격! %d의 데미지" % [GameState.config.hero_name, GameState.hero_attack]), "용사 공격 로그")
	_check(_log_has(log_b, "%s의 공격! %d의 데미지" % [priest.display_name, priest.attack_bonus]), "승려 공격 로그 (이제 승려도 공격!)")
	_check(_log_has(log_b, "허수아비의 공격! ") and (_log_has(log_b, "용사에게") or _log_has(log_b, "승려에게")), "적이 특정 멤버를 지목해 반격")
	BattleManager.abort_all()

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
