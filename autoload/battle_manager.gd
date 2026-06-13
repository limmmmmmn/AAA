extends Node
## 모든 BattleInstance의 생성·틱·소멸 관리. _physics_process에서 일괄 틱.

var active_battles: Array[BattleInstance] = []


func can_start_battle() -> bool:
	return active_battles.size() < GameState.max_battle_windows


## monsters: Array[MonsterData] — 1지역에선 길이 1, 2지역 휘말림에서 2+.
func start_battle(monsters: Array, world_pos: Vector2 = Vector2.ZERO) -> BattleInstance:
	if not can_start_battle() or monsters.is_empty():
		return null
	var battle := BattleInstance.new(monsters, world_pos)
	active_battles.append(battle)
	battle.finished.connect(_on_battle_finished.bind(battle))
	battle.fled.connect(_on_battle_fled.bind(battle))
	EventBus.battle_started.emit(battle)
	return battle


func _physics_process(delta: float) -> void:
	for battle in active_battles.duplicate():
		battle.tick(delta)


## 패배 시: 모든 전투를 보상 없이 즉시 종료 (B-2)
func abort_all() -> void:
	var battles := active_battles.duplicate()
	active_battles.clear()
	for battle in battles:
		battle.abort()


func _on_battle_finished(result: Dictionary, battle: BattleInstance) -> void:
	active_battles.erase(battle)
	GameState.add_gold(result.gold)
	GameState.total_exp += result.exp
	GameState.total_battles_won += 1
	# 적별로 사망 처리 (kill_count·존 해금이 여기에 반응)
	for e in battle.enemies:
		GameState.register_kill(e.data)
		EventBus.monster_died.emit(e.data, battle.origin_pos)
	EventBus.battle_ended.emit(battle, result)


## 메탈 도주 등: 보상·토벌수 없이 전투만 제거 (v3 §2)
func _on_battle_fled(_message: String, battle: BattleInstance) -> void:
	active_battles.erase(battle)
