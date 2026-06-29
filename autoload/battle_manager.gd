extends Node
## 모든 BattleInstance의 생성·틱·소멸 관리. _physics_process에서 일괄 틱.

var active_battles: Array[BattleInstance] = []


func can_start_battle() -> bool:
	return active_battles.size() < GameState.max_battle_windows


## monsters: Array[MonsterData] — 인카운터 포메이션의 적 무리 (1~6마리).
func start_battle(monsters: Array, world_pos: Vector2 = Vector2.ZERO, formation_id: StringName = &"") -> BattleInstance:
	if not can_start_battle() or monsters.is_empty():
		return null
	var battle := BattleInstance.new(monsters, world_pos)
	battle.formation_id = formation_id
	# 1번 전투창은 100% 화력, 추가로 열리는 창은 extra_window_efficiency(기본 0.45, 노드로 ↑·최대 1.0).
	battle.window_efficiency = 1.0 if active_battles.is_empty() \
		else minf(1.0, float(GameState.stat("extra_window_efficiency")))
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
	# 포메이션 보상: 적별 골드 합 + 무리 전멸 완료 보너스(2마리+5% … 6마리+25%), 포메이션 배율.
	var fdef: EncounterFormationDef = GameState.formation_def(battle.formation_id)
	var reward_mult: float = fdef.reward_mult if fdef != null else 1.0
	var count: int = int(result.get("group", 1))
	var clear_bonus: float = float(result.gold) * 0.05 * maxi(0, count - 1)
	var gold: int = int(round((float(result.gold) + clear_bonus) * reward_mult * GameState.combat_gold_mult()))
	GameState.add_gold(gold, &"combat")
	GameState.total_exp += result.exp
	GameState.total_battles_won += 1
	# 무리 전멸 → 지역 조사도 증가 (적/포메이션 해금이 여기에 반응)
	if fdef != null and fdef.survey_reward > 0.0:
		GameState.add_survey(GameState.current_region, fdef.survey_reward)
	# 적별로 사망 처리 (kill_count·지역킬·존 해금·재료 드롭이 여기에 반응)
	for e in battle.enemies:
		GameState.register_kill(e.data)
		GameState.roll_monster_drops(e.data)
		EventBus.monster_died.emit(e.data, battle.origin_pos)
	EventBus.battle_ended.emit(battle, result)


## 메탈 도주 등: 보상·토벌수 없이 전투만 제거 (v3 §2)
func _on_battle_fled(_message: String, battle: BattleInstance) -> void:
	active_battles.erase(battle)
