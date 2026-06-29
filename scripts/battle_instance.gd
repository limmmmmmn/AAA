class_name BattleInstance extends RefCounted
## 전투 시뮬레이션 본체. 비주얼 없음 — BattleWindow가 시그널을 구독해 그리기만 한다.
## enemies는 같은 종의 무리(GroupEncounter, v3 §4). 1마리~3마리. 메탈은 항상 1마리.
##
## 전투 리듬 (JRPG): 한 라운드 = 멤버들이 차례로 공격(용사 → 동료 → ...) → 적 반격.
## 각 행동(비트)이 텍스트 로그 한 줄 + 데미지 팝업으로 또렷이 보인다.
## 라운드 전체 시간은 여전히 turn_interval (전투 길이 불변) — 비트가 늘면 비트당 시간이 짧아질 뿐.
## 라운드 총 데미지 = sum(member_attacks) = party_attack 이라 밸런스도 불변.

signal state_updated
signal party_acted(target_index: int, damage: int, is_crit: bool)  # 멤버 1명의 행동 (적 -1 = 전체 공격)
signal enemy_acted(damage: int)                                     # 적 반격
signal log_line(text: String)                                      # 1인칭 전투창 텍스트 로그
signal finished(result: Dictionary)
signal fled(message: String)   # 메탈 도주 등 (보상 없음, v3 §2)
signal aborted                 # 패배로 강제 종료 (B-2)

var enemies: Array[Dictionary] = []   # 각 항목: {"data": MonsterData, "hp": int, "hits": int}
var origin_pos: Vector2
var window_efficiency: float = 1.0    # 이 전투창의 화력 비율 (1번 창=1.0, 추가 창=extra_window_efficiency)
var turns: int = 0
var elapsed: float = 0.0
var is_finished: bool = false

var _beats: Array = []           # 이번 라운드에 남은 행동 큐 (멤버들 → 적)
var _beats_per_round: int = 2
var _phase_timer: float = 0.0


func _init(monster_list: Array, world_pos: Vector2 = Vector2.ZERO) -> void:
	var hp_mult := float(GameState.stat("enemy_hp_mult")) # cmd_squad_clone: 적 HP ×1.4
	for data: MonsterData in monster_list:
		var hp := maxi(1, int(round(data.max_hp * hp_mult)))
		enemies.append({"data": data, "hp": hp, "hits": 0})
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
		return Locale.t("%s ×%d 나타났다!") % [Locale.t(d.display_name), n]
	return Locale.t("%s 나타났다!") % _iga(d.display_name)


# ─── 한글 조사 (로그가 자연스럽게 읽히도록). 영문 로케일에선 조사 없이 번역명만. ───

static func _has_batchim(s: String) -> bool:
	if s.is_empty():
		return false
	var c := s.unicode_at(s.length() - 1)
	if c < 0xAC00 or c > 0xD7A3:   # 한글 음절 영역 밖이면 받침 판정 불가
		return false
	return (c - 0xAC00) % 28 != 0

static func _iga(s: String) -> String:
	if TranslationServer.get_locale().begins_with("en"):
		return TranslationServer.translate(s)
	return s + ("이" if _has_batchim(s) else "가")

static func _eulreul(s: String) -> String:
	if TranslationServer.get_locale().begins_with("en"):
		return TranslationServer.translate(s)
	return s + ("을" if _has_batchim(s) else "를")


# ─── 틱: 라운드 비트 진행 (멤버별 순차 행동) ───

func tick(delta: float) -> void:
	if is_finished:
		return
	elapsed += delta
	if _check_time_flee():
		return
	_phase_timer += delta
	# 큰 수동 틱(테스트)도 정확히 처리되도록 while로 비트를 소진한다.
	while not is_finished:
		if _beats.is_empty():
			_start_round()
		var beat_time: float = GameState.turn_interval / float(maxi(1, _beats_per_round))
		if _phase_timer < beat_time:
			break
		_phase_timer -= beat_time
		_run_beat(_beats.pop_front())


## 새 라운드: 멤버들이 차례로 공격 → 적들이 각자 멤버 1명씩 반격.
func _start_round() -> void:
	turns += 1
	_beats.clear()
	for i in GameState.member_count():
		_beats.append({"t": "member", "i": i})
	for j in enemies.size():
		_beats.append({"t": "enemy", "i": j})
	_beats_per_round = _beats.size()


func _run_beat(beat: Dictionary) -> void:
	if beat.t == "member":
		_member_attack(int(beat.i))
	else:
		_enemy_attack(int(beat.i))


## 멤버 1명의 공격 (회심은 멤버별로 굴린다). 쓰러진 멤버는 행동하지 않는다.
func _member_attack(index: int) -> void:
	var target := _front_index()
	if target == -1 or not GameState.member_alive(index):
		return
	var attacks := GameState.member_attacks()
	if index >= attacks.size():
		return
	var atk: int = int(round(attacks[index] * window_efficiency)) # 추가 전투창은 화력 감소
	var mname: String = _member_name(index)
	var is_crit: bool = randf() < GameState.crit_chance
	var crit_atk: int = int(round(atk * float(GameState.stat("crit_damage_mult")))) # 회심 피해 배율(cmb_crit)
	var before: Array[int] = []
	for e in enemies:
		before.append(int(e.hp))
	var shown := 0
	if GameState.all_attack:
		# 베기라: 살아있는 모든 적을 동시에 공격 (각자 방어력 적용)
		for e in enemies:
			if e.hp > 0:
				var d: int = crit_atk if is_crit else maxi(atk - int(e.data.defense), 0)
				e.hp = maxi(0, e.hp - d)
				e.hits += 1
		shown = crit_atk if is_crit else maxi(atk - int(enemies[target].data.defense), 0)
		log_line.emit(_member_attack_text(mname, is_crit, shown, true))
		party_acted.emit(-1, shown, is_crit)
	else:
		shown = crit_atk if is_crit else maxi(atk - int(enemies[target].data.defense), 0)
		enemies[target].hp = maxi(0, enemies[target].hp - shown)
		enemies[target].hits += 1
		log_line.emit(_member_attack_text(mname, is_crit, shown, false))
		party_acted.emit(target, shown, is_crit)
	state_updated.emit()
	for i in enemies.size():
		if before[i] > 0 and enemies[i].hp == 0:
			log_line.emit(Locale.t("%s 쓰러뜨렸다!") % _eulreul(enemies[i].data.display_name))
	if _all_dead():
		is_finished = true
		finished.emit(_build_result())
		return
	_check_hit_flee()


## 적 1마리의 반격 — 살아있는 멤버 1명을 노려 그 멤버의 HP를 깎는다.
func _enemy_attack(j: int) -> void:
	if is_finished or j < 0 or j >= enemies.size() or enemies[j].hp <= 0:
		return # 죽은 적은 반격하지 않는다
	var aname: String = Locale.t(enemies[j].data.display_name)
	var atk: int = int(enemies[j].data.attack)
	if atk <= 0:
		return # 공격력 0 (메탈) — 반격 없음
	if not GameState.damage_enabled:
		# 1지역은 죽을 위험이 없다 — 반격은 가볍게 막아낸다
		log_line.emit(Locale.t("%s의 공격! 파티가 가볍게 막아냈다") % aname)
		return
	var target := GameState.random_living_member()
	var tname := _member_name(target)
	log_line.emit(Locale.t("%s의 공격! %s에게 %d의 데미지") % [aname, tname, atk])
	enemy_acted.emit(atk)
	GameState.damage_member(target, atk)


func _member_name(index: int) -> String:
	var members := GameState.party_members()
	return Locale.t(members[index].name) if index >= 0 and index < members.size() else Locale.t("동료")


func _member_attack_text(mname: String, is_crit: bool, dmg: int, all_hit: bool) -> String:
	if is_crit:
		return Locale.t("%s의 회심의 일격! %d의 데미지") % [mname, dmg]
	if dmg <= 0:
		return Locale.t("%s의 공격! 통하지 않는다") % mname
	if all_hit:
		return Locale.t("%s의 일제 공격! %d의 데미지") % [mname, dmg]
	return Locale.t("%s의 공격! %d의 데미지") % [mname, dmg]


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
	fled.emit(Locale.t("%s — 도망쳤다!") % Locale.t(monster_name))


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
