class_name BattleInstance extends RefCounted
## 전투 시뮬레이션 본체. 비주얼 없음 — BattleWindow가 시그널을 구독해 그리기만 한다.
## BattleManager가 _physics_process에서 tick(delta)를 호출한다.
##
## enemies는 처음부터 Array 구조 (1지역에선 항상 길이 1).
## 2지역 휘말림(EncounterPull)에서 구조 변경 없이 길이만 2+ 로 확장된다.

signal state_updated
signal turn_played(target_index: int, party_damage: int, incoming_damage: int)
signal finished(result: Dictionary)
signal aborted   # 패배 등으로 보상 없이 강제 종료 (B-2)

var enemies: Array[Dictionary] = []   # 각 항목: {"data": MonsterData, "hp": int}
var origin_pos: Vector2
var turns: int = 0
var turn_timer: float = 0.0
var is_finished: bool = false


func _init(monster_list: Array, world_pos: Vector2 = Vector2.ZERO) -> void:
	for data: MonsterData in monster_list:
		enemies.append({"data": data, "hp": data.max_hp})
	origin_pos = world_pos


## 호환/편의: 첫 적 (1지역에선 유일한 적)
func front_data() -> MonsterData:
	var idx := _front_index()
	return enemies[idx].data if idx >= 0 else enemies[0].data


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
	turn_timer += delta
	# turn_interval은 GameState에서 매번 읽는다 — 전투 중 구매한 업그레이드도 즉시 반영
	while turn_timer >= GameState.turn_interval and not is_finished:
		turn_timer -= GameState.turn_interval
		_play_turn()


func _play_turn() -> void:
	turns += 1
	var target := _front_index()
	if target == -1:
		return
	var party_damage: int = GameState.party_attack
	if GameState.all_attack:
		# 베기라: 살아있는 모든 적을 동시에 공격
		for e in enemies:
			if e.hp > 0:
				e.hp = maxi(0, e.hp - party_damage)
		target = -1 # 전체 타격 (창은 -1을 모든 적 팝업으로 해석)
	else:
		# 앞에서부터 단일 타겟 공격
		enemies[target].hp = maxi(0, enemies[target].hp - party_damage)
	# 살아남은 모든 적이 반격 (1지역 연출용, 2지역 공유 HP 차감)
	var incoming: int = 0
	for e in enemies:
		if e.hp > 0:
			incoming += int(e.data.attack)
	turn_played.emit(target, party_damage, incoming)
	state_updated.emit()
	GameState.apply_damage(incoming) # damage_enabled일 때만 실제로 깎인다
	if _all_dead():
		is_finished = true
		finished.emit(_build_result())


## 패배 등으로 보상 없이 즉시 종료 (BattleManager.abort_all에서 호출)
func abort() -> void:
	if is_finished:
		return
	is_finished = true
	aborted.emit()


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
		"one_shot": turns == 1, # "회심의 일격!" 연출 플래그
	}
