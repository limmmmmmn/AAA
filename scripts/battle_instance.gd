class_name BattleInstance extends RefCounted
## 전투 시뮬레이션 본체. 비주얼 없음 — BattleWindow가 시그널을 구독해 그리기만 한다.
## enemies는 같은 종의 무리(GroupEncounter, v3 §4). 1마리~3마리. 메탈은 항상 1마리.

signal state_updated
signal turn_played(target_index: int, party_damage: int, incoming_damage: int, is_crit: bool)
signal finished(result: Dictionary)
signal fled(message: String)   # 메탈 도주 등 (보상 없음, v3 §2)
signal aborted                 # 패배로 강제 종료 (B-2)

var enemies: Array[Dictionary] = []   # 각 항목: {"data": MonsterData, "hp": int, "hits": int}
var origin_pos: Vector2
var turns: int = 0
var turn_timer: float = 0.0
var elapsed: float = 0.0
var is_finished: bool = false


func _init(monster_list: Array, world_pos: Vector2 = Vector2.ZERO) -> void:
	for data: MonsterData in monster_list:
		enemies.append({"data": data, "hp": data.max_hp, "hits": 0})
	origin_pos = world_pos


func front_data() -> MonsterData:
	var idx := _front_index()
	return enemies[idx].data if idx >= 0 else enemies[0].data


func group_size() -> int:
	return enemies.size()


func _front_index() -> int:
	for i in enemies.size():
		if enemies[i].hp > 0:
			return i
	return -1


func _all_dead() -> bool:
	return _front_index() == -1


func tick(delta: float) -> void:
	if is_finished:
		return
	elapsed += delta
	if _check_time_flee():
		return
	turn_timer += delta
	while turn_timer >= GameState.turn_interval and not is_finished:
		turn_timer -= GameState.turn_interval
		_play_turn()


## 회심 여부에 따른 1회 공격 데미지 (방어력 적용/무시)
func _roll_damage(target_defense: int) -> Array:
	var is_crit: bool = randf() < GameState.crit_chance
	var dmg: int = GameState.party_attack if is_crit else maxi(GameState.party_attack - target_defense, 0)
	return [dmg, is_crit]


func _play_turn() -> void:
	turns += 1
	var target := _front_index()
	if target == -1:
		return
	var roll := _roll_damage(enemies[target].data.defense)
	var party_damage: int = roll[0]
	var is_crit: bool = roll[1]
	if GameState.all_attack:
		# 베기라: 살아있는 모든 적을 동시에 공격 (각자 방어력 적용, 회심은 공유)
		for e in enemies:
			if e.hp > 0:
				var d: int = GameState.party_attack if is_crit else maxi(GameState.party_attack - int(e.data.defense), 0)
				e.hp = maxi(0, e.hp - d)
				e.hits += 1
		target = -1
	else:
		enemies[target].hp = maxi(0, enemies[target].hp - party_damage)
		enemies[target].hits += 1
	var incoming: int = 0
	for e in enemies:
		if e.hp > 0:
			incoming += int(e.data.attack)
	turn_played.emit(target, party_damage, incoming, is_crit)
	state_updated.emit()
	GameState.apply_damage(incoming)
	if _all_dead():
		is_finished = true
		finished.emit(_build_result())
	elif _check_hit_flee():
		pass


func _check_hit_flee() -> bool:
	var i := _front_index()
	if i == -1:
		return false
	var d: MonsterData = enemies[i].data
	if d.flee_after_hits > 0 and enemies[i].hits >= d.flee_after_hits:
		_flee(d.display_name)
		return true
	return false


func _check_time_flee() -> bool:
	var i := _front_index()
	if i == -1:
		return false
	var d: MonsterData = enemies[i].data
	if d.flee_after_seconds > 0.0 and elapsed >= d.flee_after_seconds:
		_flee(d.display_name)
		return true
	return false


func _flee(monster_name: String) -> void:
	if is_finished:
		return
	is_finished = true
	fled.emit("%s — 도망쳤다!" % monster_name)


func _build_result() -> Dictionary:
	var gold: int = 0
	var exp: int = 0
	for e in enemies:
		gold += int(e.data.gold_reward)
		exp += int(e.data.exp_reward)
	return {
		"gold": gold,
		"exp": exp,
		"turns": turns,
		"group": enemies.size(),
		"one_shot": turns == 1,
	}


func abort() -> void:
	if is_finished:
		return
	is_finished = true
	aborted.emit()
