class_name BattleInstance extends RefCounted
## 전투 시뮬레이션 본체. 비주얼 없음 — BattleWindow가 시그널을 구독해 그리기만 한다.
## enemies는 같은 종의 무리(GroupEncounter, v3 §4). 1마리~3마리. 메탈은 항상 1마리.
##
## A-2 전투 리듬: 한 라운드 = 파티 행동 → (turn_beat_delay 텀) → 적 행동.
## 라운드 전체 시간은 여전히 turn_interval (전투 길이 불변). 비트 사이 텀만 끼워
## 누가 때리는지 또렷해지고 A-1 텍스트 로그가 한 줄씩 읽힌다.

signal state_updated
signal party_acted(target_index: int, damage: int, is_crit: bool)  # 파티 행동 (적 -1 = 전체 공격)
signal enemy_acted(damage: int)                                     # 적 반격
signal log_line(text: String)                                      # 1인칭 전투창 텍스트 로그 (A-1)
signal finished(result: Dictionary)
signal fled(message: String)   # 메탈 도주 등 (보상 없음, v3 §2)
signal aborted                 # 패배로 강제 종료 (B-2)

const _PHASE_WINDUP := 0       # 라운드 시작 대기 (직전 줄을 읽는 시간)
const _PHASE_PARTY_DONE := 1   # 파티 행동 완료 → 적 행동까지 텀 대기

var enemies: Array[Dictionary] = []   # 각 항목: {"data": MonsterData, "hp": int, "hits": int}
var origin_pos: Vector2
var turns: int = 0
var elapsed: float = 0.0
var is_finished: bool = false

var _phase: int = _PHASE_WINDUP
var _phase_timer: float = 0.0


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


## 적 등장 줄 (창 바인드 직후 시드용). "슬라임이 나타났다!" / "박쥐 ×3가 나타났다!"
func intro_text() -> String:
	var d := front_data()
	var n := group_size()
	if n > 1:
		return "%s ×%d 나타났다!" % [d.display_name, n]
	return "%s 나타났다!" % _iga(d.display_name)


# ─── 한글 조사 (로그가 자연스럽게 읽히도록) ───

static func _has_batchim(s: String) -> bool:
	if s.is_empty():
		return false
	var c := s.unicode_at(s.length() - 1)
	if c < 0xAC00 or c > 0xD7A3:   # 한글 음절 영역 밖이면 받침 판정 불가
		return false
	return (c - 0xAC00) % 28 != 0

static func _iga(s: String) -> String:
	return s + ("이" if _has_batchim(s) else "가")

static func _eulreul(s: String) -> String:
	return s + ("을" if _has_batchim(s) else "를")


# ─── 틱: 라운드 비트 진행 (A-2) ───

func tick(delta: float) -> void:
	if is_finished:
		return
	elapsed += delta
	if _check_time_flee():
		return
	_phase_timer += delta
	# 큰 수동 틱(테스트)도 정확히 처리되도록 while로 비트를 소진한다.
	while not is_finished:
		var beat := _beat_delay()
		var windup: float = maxf(0.0, GameState.turn_interval - beat)
		if _phase == _PHASE_WINDUP:
			if _phase_timer < windup:
				break
			_phase_timer -= windup
			_party_beat()
			_phase = _PHASE_PARTY_DONE
		else:
			if _phase_timer < beat:
				break
			_phase_timer -= beat
			_enemy_beat()
			_phase = _PHASE_WINDUP


## 비트 텀은 turn_interval 절반을 넘지 않게 (라운드 총합 = turn_interval 보장, windup>0 보장).
func _beat_delay() -> float:
	return minf(GameState.turn_beat_delay, GameState.turn_interval * 0.5)


## 회심 여부에 따른 1회 공격 데미지 (방어력 적용/무시)
func _roll_damage(target_defense: int) -> Array:
	var is_crit: bool = randf() < GameState.crit_chance
	var dmg: int = GameState.party_attack if is_crit else maxi(GameState.party_attack - target_defense, 0)
	return [dmg, is_crit]


func _party_beat() -> void:
	turns += 1
	var target := _front_index()
	if target == -1:
		return
	var roll := _roll_damage(enemies[target].data.defense)
	var party_damage: int = roll[0]
	var is_crit: bool = roll[1]
	var before: Array[int] = []
	for e in enemies:
		before.append(int(e.hp))
	if GameState.all_attack:
		# 베기라: 살아있는 모든 적을 동시에 공격 (각자 방어력 적용, 회심은 공유)
		for e in enemies:
			if e.hp > 0:
				var d: int = GameState.party_attack if is_crit else maxi(GameState.party_attack - int(e.data.defense), 0)
				e.hp = maxi(0, e.hp - d)
				e.hits += 1
		log_line.emit(_attack_text(is_crit, party_damage, true))
		party_acted.emit(-1, party_damage, is_crit)
	else:
		enemies[target].hp = maxi(0, enemies[target].hp - party_damage)
		enemies[target].hits += 1
		log_line.emit(_attack_text(is_crit, party_damage, false))
		party_acted.emit(target, party_damage, is_crit)
	state_updated.emit()
	# 이번 비트에 쓰러진 적 처리 (kill 로그)
	for i in enemies.size():
		if before[i] > 0 and enemies[i].hp == 0:
			log_line.emit("%s 쓰러뜨렸다!" % _eulreul(enemies[i].data.display_name))
	if _all_dead():
		is_finished = true
		finished.emit(_build_result())
		return
	_check_hit_flee()


func _enemy_beat() -> void:
	if is_finished:
		return
	var attacker := _front_index()
	var incoming: int = 0
	for e in enemies:
		if e.hp > 0:
			incoming += int(e.data.attack)
	if incoming <= 0:
		return
	var attacker_name: String = enemies[attacker].data.display_name if attacker >= 0 else "적"
	if not GameState.damage_enabled:
		# 1지역은 죽을 위험이 없다 — 반격은 가볍게 막아낸다(허수 데미지 표시 안 함)
		log_line.emit("%s의 공격! 가볍게 막아냈다" % attacker_name)
		return
	log_line.emit("%s의 공격! %d의 데미지" % [attacker_name, incoming])
	enemy_acted.emit(incoming)
	GameState.apply_damage(incoming)


func _attack_text(is_crit: bool, dmg: int, all_hit: bool) -> String:
	if is_crit:
		return "회심의 일격! %d의 데미지" % dmg
	var who := GameState.config.hero_name
	if all_hit:
		return "%s 일행의 일제 공격! %d의 데미지" % [who, dmg]
	return "%s의 공격! %d의 데미지" % [who, dmg]


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
