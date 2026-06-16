extends Node
## 골드, 보유 업그레이드, 파티 스탯 집계, 해금 상태. 저장/로드 담당.
## 효과 적용은 recalculate_stats() 한 곳에서만 — 개별 노드가 스탯을 직접 만지지 않는다.

const SAVE_PATH := "user://save.json"
const CONFIG_PATH := "res://data/config/game_config.tres"
const UPGRADE_DIR := "res://data/upgrades"
const COMPANION_DIR := "res://data/companions"
const QUEST_DIR := "res://data/quests"

var config: GameConfig

# ─── 진행 상태 (저장 대상) ───
var gold: int = 0
var total_gold_earned: int = 0
var total_exp: int = 0
var total_battles_won: int = 0
var play_time: float = 0.0
var purchases: Dictionary = {}          # id(StringName) -> 구매 횟수
var kill_count: Dictionary = {}         # monster id(StringName) -> 누적 토벌 수
var companions: Array[CompanionData] = [] # 합류한 동료 (1지역에선 빈 배열)
var hunt_list: Dictionary = {}          # monster id -> bool (자동 추적 허가, v3 §8)
var monster_catalog: Dictionary = {}    # monster id -> MonsterData (HuntList 표시용)
var _retreat_active: bool = false       # 자동 철수 진행 중 (중복 발동 방지)
var elder_stage: int = 0                # 0: 미해금, 1: 멀티창2, 2: 멀티창3
var can_move_in_battle: bool = false
var elder_window_bonus: int = 0
var dual_battle_celebrated: bool = false
var gate_paid: bool = false
var first_sword_time: float = -1.0      # 동검 첫 구매 시점 (play_time 기준)

# ─── PART B: 멤버별 HP / 지역 / 의뢰 (저장 대상) ───
var member_hps: Array[int] = []         # 멤버별 현재 HP (0=용사, 1+=동료 순서)
var member_max_hps: Array[int] = []     # 멤버별 최대 HP
var damage_enabled: bool = false        # 1지역 off, 2지역 진입 시 on (B-2)
var tactic_retreat_unlocked: bool = false # 승려 합류 시 해금 (v3 §9)
var tactic_retreat_enabled: bool = false  # HUD 토글
var current_region: StringName = &"region1"
var active_quest_id: StringName = &""   # 동시 수주 1개
var quest_progress_base: int = 0        # 수주 시점의 target 토벌 수 (이후 증가분만 카운트)

# ─── 마을 오브젝트: 재화/재료/대장간/쿨타임 (저장 대상) ───
var gems: int = 0                       # 보석 (상위 재화 — 검 판매로 획득, 자동화 구매)
var materials: Dictionary = {}          # id(StringName) -> 수량 (stone/herb/pot_shard/enhance_stone/medal_shard/wood_key)
var rusty_swords: int = 0               # 미강화 녹슨 검 보유 수
var forge_level: int = -1               # 화로에 올린 검의 강화 수치 (-1 = 검 없음)
var equipped_sword_level: int = -1      # 장착한 검의 강화 수치 (-1 = 맨손) → 용사 공격력 +
var pot_ready_at: float = 0.0           # 이 play_time에 항아리를 깰 수 있게 됨 (≤ play_time 이면 준비됨)
var chest_ready_at: float = 0.0
var chest_keys_unlocked: bool = false   # 보물상자 열쇠 시스템 해금 (중반)
var chest_required_key: StringName = &"" # 다음 개봉에 필요한 열쇠 (해금 후)
var chest_opens: int = 0                # 누적 개봉 수 (열쇠 시스템 해금 판정용)
var auto_pot: bool = false              # 자동 항아리꾼 (보석 업그레이드)
var auto_enhance: bool = false          # 자동 강화 (재료 있으면 검 자동 강화)
var auto_deliver: bool = false          # 자동 납품 (최대치 검 자동 판매 + 다음 검 자동 장전)

# ─── 땅파기 (삽 → 쿨타임마다 채굴, 반짝임이면 100%) ───
var dig_ready_at: float = 0.0           # 이 play_time에 다시 팔 수 있음
var has_sparkling_ground: bool = false  # 반짝이는 땅 존재 (그 위에서 파면 100% 보상)
var sparkle_area: StringName = &""      # 반짝임이 생긴 지역 (지역별 표시 게이트)
var party_on_sparkle: bool = false      # 파티가 반짝이는 땅 위에 서 있음 (런타임, SparkleGround가 갱신)
var wisdom: int = 0                     # 지혜 스탯 (높을수록 반짝임 발견 ↑). 현재 구조용 0 기본

# ─── 파생 스탯 (recalculate_stats만 계산) ───
var party_attack: int = 3               # 용사 + 동료 합산 (파티 총 공격력)
var hero_attack: int = 3                # 용사 단독 공격력 (기본 + 무기/주문 업그레이드, 동료 제외)
var turn_interval: float = 1.2
var turn_beat_delay: float = 0.25       # 라운드 내 파티→적 행동 텀 (A-2, config에서)
var move_speed: float = 80.0
var respawn_delay_mult: float = 1.0
var max_battle_windows: int = 1
var auto_hunt_unlocked: bool = false
var vision_zoom: float = 1.0            # 카메라 줌 (작을수록 넓게)
var crit_chance: float = 0.02          # 회심의 일격 확률 (v3 §1)
var damage_reduction_mult: float = 1.0 # 사슬 갑옷 등 피격 경감 (B-6)
var all_attack: bool = false           # 베기라: 전체 공격 (B-6)
var remote_shop_unlocked: bool = false # 주문 카탈로그: 원격 구매 (B-6)
var has_shovel: bool = false           # 삽 보유 (상점 구매 → 땅파기 해금)
var has_pig_companion: bool = false    # 꼬마돼지 영입 (반짝임 발견 ↑)
var dig_cooldown: float = 60.0         # 땅파기 쿨타임 (좋은 삽으로 감소)

# ─── 무리 출현 확률표 (v3 §4). [1.0] = 항상 1마리. 배너로 확장 ───
var group_table: Array[float] = [1.0]

var catalog: Dictionary = {}            # id(StringName) -> UpgradeData
var companion_catalog: Dictionary = {}  # id(StringName) -> CompanionData
var quest_catalog: Dictionary = {}      # id(StringName) -> QuestData

var _heal_accum: float = 0.0            # 공유 HP 회복 틱 누적
var _forge_accum: float = 0.0           # 자동 강화/납품 틱 누적

# ─── 디버그 (저장 안 함 — 실행마다 off로 시작) ───
var debug_mode: bool = false


func set_debug_mode(on: bool) -> void:
	debug_mode = on
	EventBus.debug_mode_changed.emit(on)


func _ready() -> void:
	config = load(CONFIG_PATH)
	vision_zoom = config.base_vision_zoom
	turn_beat_delay = config.turn_beat_delay
	_load_catalog()
	_load_companion_catalog()
	_load_quest_catalog()
	load_game()
	recalculate_stats()
	_ensure_member_hp() # 멤버별 HP 배열을 멤버 수에 맞춰 정리 (로드 값 보존, 부족분 가득)
	if chest_keys_unlocked and chest_required_key == &"":
		_assign_chest_key() # 해금됐는데 열쇠 미지정이면 보정 (구 세이브 대비)
	EventBus.zone_unlocked.connect(_on_zone_unlocked) # 정예존 해금 → 시야 보상 (v3 §6)
	var autosave := Timer.new()
	autosave.wait_time = config.autosave_interval
	autosave.timeout.connect(save_game)
	add_child(autosave)
	autosave.start()


func _process(delta: float) -> void:
	play_time += delta
	_tick_heal(delta)
	if auto_pot and pot_ready(): # 자동 항아리꾼: 쿨타임마다 자동으로 깬다
		break_pot()
	_tick_forge(delta)
	_tick_sparkle() # 꼬마돼지: 준비되면 반짝이는 땅을 맵에 띄운다


## 동료(승려)의 상시 회복 — turn_interval 주기마다 가장 다친 멤버를 회복 (B-2)
func _tick_heal(delta: float) -> void:
	if not damage_enabled or total_hp() <= 0 or total_hp() >= total_max_hp():
		return
	var heal_per_turn := 0
	for c in companions:
		heal_per_turn += c.heal_per_turn
	if heal_per_turn <= 0:
		return
	_heal_accum += delta
	while _heal_accum >= turn_interval:
		_heal_accum -= turn_interval
		heal_lowest(heal_per_turn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ─── 카탈로그 로드 ───

func _load_catalog() -> void:
	catalog.clear()
	var dir := DirAccess.open(UPGRADE_DIR)
	if dir == null:
		push_error("업그레이드 디렉터리를 열 수 없음: " + UPGRADE_DIR)
		return
	for file in dir.get_files():
		var fname := file.trim_suffix(".remap") # 익스포트 빌드 대응
		if not fname.ends_with(".tres"):
			continue
		var upgrade: UpgradeData = load(UPGRADE_DIR + "/" + fname)
		if upgrade:
			catalog[upgrade.id] = upgrade


func _load_companion_catalog() -> void:
	companion_catalog.clear()
	var dir := DirAccess.open(COMPANION_DIR)
	if dir == null:
		return # 1지역엔 동료 데이터가 아직 없을 수 있다
	for file in dir.get_files():
		var fname := file.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var comp: CompanionData = load(COMPANION_DIR + "/" + fname)
		if comp:
			companion_catalog[comp.id] = comp


func _load_quest_catalog() -> void:
	quest_catalog.clear()
	var dir := DirAccess.open(QUEST_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		var fname := file.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var quest: QuestData = load(QUEST_DIR + "/" + fname)
		if quest:
			quest_catalog[quest.id] = quest


func quests_all() -> Array[QuestData]:
	var list: Array[QuestData] = []
	for q: QuestData in quest_catalog.values():
		list.append(q)
	list.sort_custom(func(a: QuestData, b: QuestData) -> bool: return a.reward_gold < b.reward_gold)
	return list


func region_number() -> int:
	return 2 if current_region == &"region2" else 1


## 무리 출현 규모 추첨 (v3 §4). group_table[i] = (i+1)마리 확률.
func roll_group_size() -> int:
	var r := randf()
	var acc := 0.0
	for i in group_table.size():
		acc += group_table[i]
		if r < acc:
			return i + 1
	return group_table.size()


func upgrades_for_axis(axis: String) -> Array[UpgradeData]:
	var list: Array[UpgradeData] = []
	var region := region_number()
	for upgrade: UpgradeData in catalog.values():
		if upgrade.axis == axis and upgrade.min_region <= region:
			if upgrade.requires_shovel and not has_shovel:
				continue # 삽이 없으면 좋은 삽/꼬마돼지는 아직 숨긴다
			list.append(upgrade)
	list.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.base_cost < b.base_cost)
	return list


func owned_count(upgrade: UpgradeData) -> int:
	return purchases.get(upgrade.id, 0)


func current_cost(upgrade: UpgradeData) -> int:
	return int(round(upgrade.base_cost * pow(upgrade.cost_growth, owned_count(upgrade))))


func purchase(upgrade: UpgradeData) -> bool:
	if owned_count(upgrade) >= upgrade.max_purchases:
		return false
	var cost := current_cost(upgrade)
	if gold < cost:
		return false
	gold -= cost
	EventBus.gold_changed.emit(gold)
	purchases[upgrade.id] = owned_count(upgrade) + 1
	if upgrade.id == &"sword_copper" and first_sword_time < 0.0:
		first_sword_time = play_time
	recalculate_stats()
	EventBus.upgrade_purchased.emit(upgrade)
	return true


# ─── 골드 ───

func add_gold(amount: int) -> void:
	gold += amount
	if amount > 0:
		total_gold_earned += amount
	EventBus.gold_changed.emit(gold)


func try_spend(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold)
	return true


# ─── 토벌 수 / 마일스톤 (A-2) ───

func register_kill(data: MonsterData) -> void:
	if data == null:
		return
	ensure_hunt_entry(data)
	kill_count[data.id] = kills(data.id) + 1
	_check_quest_progress(data.id)


## 처치 시 재료/녹슨 검 드롭 (전투 → 마을 루프). BattleManager가 적별로 호출.
func roll_monster_drops(data: MonsterData) -> void:
	if data == null:
		return
	if data.stone_drop > 0.0 and randf() < data.stone_drop:
		add_material(&"stone", 1)
	if data.sword_drop > 0.0 and randf() < data.sword_drop:
		rusty_swords += 1
		EventBus.materials_changed.emit()
		EventBus.show_toast.emit("%s가 녹슨 검을 떨어뜨렸다!" % data.display_name)


# ─── 사냥 허가 리스트 (v3 §8) ───

func ensure_hunt_entry(data: MonsterData) -> void:
	if data == null:
		return
	# 데이터를 처음 알게 된 시점에도 갱신해야 HUD가 표시 이름을 채운다
	# (세이브로 hunt_list엔 있지만 monster_catalog는 비어 있던 경우)
	var changed := not monster_catalog.has(data.id)
	monster_catalog[data.id] = data
	if not hunt_list.has(data.id):
		hunt_list[data.id] = data.hunt_default
		changed = true
	if changed:
		EventBus.hunt_list_changed.emit()


func is_hunted(id: StringName) -> bool:
	return hunt_list.get(id, true)


func set_hunted(id: StringName, on: bool) -> void:
	hunt_list[id] = on


# ─── 시야 보상 (v3 §6): 골드 상점 대신 무료 보상으로 시야가 넓어진다 ───

func _on_zone_unlocked(zone_id: StringName) -> void:
	if zone_id == &"elite_zone":
		widen_vision(config.elite_vision_zoom, "시야가 트였다!")


func widen_vision(zoom: float, msg: String) -> void:
	if zoom < vision_zoom:
		vision_zoom = zoom
		EventBus.stats_changed.emit()
		if msg != "":
			EventBus.show_toast.emit(msg)


func kills(id: StringName) -> int:
	return kill_count.get(id, 0)


## milestone: {"slime": 15} 형태. 빈 Dictionary면 항상 true.
func milestone_met(milestone: Dictionary) -> bool:
	for id: String in milestone:
		if kills(StringName(id)) < int(milestone[id]):
			return false
	return true


# ─── 동료 (A-1 / A-6) ───

func add_companion(comp: CompanionData) -> void:
	if comp == null or _has_companion(comp.id):
		return
	companions.append(comp)
	_ensure_member_hp() # 새 동료가 자기 HP를 가득 채운 채 합류
	if comp.role == &"priest": # 승려 합류 = 첫 전술 해금 (v3 §9)
		tactic_retreat_unlocked = true
		EventBus.show_toast.emit("철수의 지혜를 배웠다!")
	recalculate_stats()
	EventBus.companion_joined.emit(comp)


func _has_companion(id: StringName) -> bool:
	for c in companions:
		if c.id == id:
			return true
	return false


## 전투창 좌측 슬롯 표시용: 용사 + 동료 순서
func party_members() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"name": config.hero_name, "sprite": config.hero_sprite})
	for c in companions:
		list.append({"name": c.display_name, "sprite": c.sprite})
	return list


func member_count() -> int:
	return 1 + companions.size()


## 멤버별 단독 공격력 (용사, 동료1, 동료2 ...). 합 = party_attack (총 공격력에서 파생).
## 용사 = party_attack - 동료 보너스 합 (= 기본 + 무기/주문 업그레이드).
func member_attacks() -> Array[int]:
	var bonus := 0
	for c in companions:
		bonus += c.attack_bonus
	var arr: Array[int] = [maxi(0, party_attack - bonus)]
	for c in companions:
		arr.append(c.attack_bonus)
	return arr


# ─── 멤버별 개별 HP (각자 자기 HP) ───

## index번째 멤버의 최대 HP (0=용사=config, 1+=동료=CompanionData.max_hp).
func member_max_hp_for(index: int) -> int:
	if index == 0:
		return config.hero_max_hp
	var ci := index - 1
	return companions[ci].max_hp if ci < companions.size() else 0


## 멤버 수에 맞춰 HP 배열을 정리 — 최대치는 항상 갱신, 현재 HP는 기존값 보존(없으면 가득).
func _ensure_member_hp() -> void:
	var n := member_count()
	var old := member_hps.duplicate()
	member_max_hps.resize(n)
	member_hps.resize(n)
	for i in n:
		member_max_hps[i] = member_max_hp_for(i)
		if i < old.size():
			member_hps[i] = clampi(old[i], 0, member_max_hps[i])
		else:
			member_hps[i] = member_max_hps[i] # 새 멤버는 가득 찬 상태로 합류
	EventBus.party_hp_changed.emit()


func member_hp(index: int) -> int:
	return member_hps[index] if index >= 0 and index < member_hps.size() else 0


func member_max_hp(index: int) -> int:
	return member_max_hps[index] if index >= 0 and index < member_max_hps.size() else 0


## 해당 멤버가 행동 가능한가 (1지역은 죽지 않으므로 항상 true).
func member_alive(index: int) -> bool:
	if not damage_enabled:
		return true
	return index >= 0 and index < member_hps.size() and member_hps[index] > 0


func total_hp() -> int:
	var s := 0
	for h in member_hps:
		s += h
	return s


func total_max_hp() -> int:
	var s := 0
	for h in member_max_hps:
		s += h
	return s


func front_living_member() -> int:
	for i in member_hps.size():
		if member_hps[i] > 0:
			return i
	return 0


func random_living_member() -> int:
	var alive: Array[int] = []
	for i in member_hps.size():
		if member_hps[i] > 0:
			alive.append(i)
	return alive[randi() % alive.size()] if not alive.is_empty() else front_living_member()


# ─── 피격 / 회복 / 패배 / 부활 ───

## 특정 멤버를 공격 (BattleInstance가 적 반격마다 호출). damage_enabled일 때만.
func damage_member(index: int, raw: int) -> void:
	if not damage_enabled or raw <= 0:
		return
	if index < 0 or index >= member_hps.size() or member_hps[index] <= 0:
		index = front_living_member()
	if index >= member_hps.size() or member_hps[index] <= 0:
		return
	var dmg := maxi(1, int(round(raw * damage_reduction_mult)))
	member_hps[index] = maxi(0, member_hps[index] - dmg)
	EventBus.party_hp_changed.emit()
	if total_hp() <= 0:
		EventBus.party_defeated.emit()
	elif tactic_retreat_enabled and not _retreat_active and total_hp() <= 0.25 * total_max_hp():
		_retreat_active = true # 자동 철수 (v3 §9) — 죽기 전에 발을 뺀다
		EventBus.tactic_retreat_triggered.emit()


## 외부/테스트 호환: 앞 멤버부터 피해
func apply_damage(raw: int) -> void:
	damage_member(front_living_member(), raw)


func heal_member(index: int, amount: int) -> void:
	if amount <= 0 or index < 0 or index >= member_hps.size() or member_hps[index] <= 0:
		return
	member_hps[index] = mini(member_max_hps[index], member_hps[index] + amount)
	if total_hp() > 0.3 * total_max_hp():
		_retreat_active = false # 위험 구간을 벗어나면 다음 철수 재무장
	EventBus.party_hp_changed.emit()


## 가장 다친(비율 최저) 살아있는 멤버 1명 회복 (승려)
func heal_lowest(amount: int) -> void:
	var target := -1
	var worst := 2.0
	for i in member_hps.size():
		if member_hps[i] > 0 and member_hps[i] < member_max_hps[i]:
			var ratio := float(member_hps[i]) / float(maxi(1, member_max_hps[i]))
			if ratio < worst:
				worst = ratio
				target = i
	if target >= 0:
		heal_member(target, amount)


func full_heal() -> void:
	for i in member_hps.size():
		member_hps[i] = member_max_hps[i]
	_retreat_active = false
	EventBus.party_hp_changed.emit()


## 패배 처리: 소지금 절반 차감 + 전원 부활 (창 닫기/이동은 호출측 연출이 담당)
func apply_defeat_penalty() -> void:
	gold = gold / 2
	EventBus.gold_changed.emit(gold)
	full_heal()
	EventBus.party_revived.emit()


func enable_damage_for_region2() -> void:
	damage_enabled = true
	full_heal()


# ─── 지역 (B-1 인프라) ───

func set_region(region_id: StringName) -> void:
	current_region = region_id
	EventBus.region_changed.emit(region_id)


# ─── 의뢰 (B-4) ───

func accept_quest(quest: QuestData) -> bool:
	if quest == null or active_quest_id != &"":
		return false
	active_quest_id = quest.id
	quest_progress_base = kills(quest.target_monster)
	EventBus.quest_accepted.emit(quest)
	return true


func active_quest() -> QuestData:
	return quest_catalog.get(active_quest_id)


func quest_progress() -> int:
	var q := active_quest()
	if q == null:
		return 0
	return mini(q.target_count, kills(q.target_monster) - quest_progress_base)


func _check_quest_progress(monster_id: StringName) -> void:
	var q := active_quest()
	if q == null or q.target_monster != monster_id:
		return
	if quest_progress() >= q.target_count:
		add_gold(q.reward_gold)
		var done := q
		active_quest_id = &""
		quest_progress_base = 0
		if done.reward_unlock == &"vision_eagle": # 시야 보상 (v3 §6)
			widen_vision(config.quest_vision_zoom, "독수리의 시야를 얻었다!")
		EventBus.quest_completed.emit(done)


# ─── 마을 오브젝트: 재화/재료 ───

func add_gems(n: int) -> void:
	gems += n
	EventBus.gems_changed.emit(gems)


func spend_gems(n: int) -> bool:
	if gems < n:
		return false
	gems -= n
	EventBus.gems_changed.emit(gems)
	return true


func material_count(id: StringName) -> int:
	return materials.get(id, 0)


func add_material(id: StringName, n: int) -> void:
	materials[id] = material_count(id) + n
	EventBus.materials_changed.emit()


func spend_material(id: StringName, n: int) -> bool:
	if material_count(id) < n:
		return false
	materials[id] = material_count(id) - n
	EventBus.materials_changed.emit()
	return true


const MAT_NAMES := {
	&"stone": "돌멩이", &"herb": "약초", &"pot_shard": "항아리 조각",
	&"enhance_stone": "강화석", &"medal_shard": "메달 조각", &"wood_key": "나무 열쇠",
	&"map_shard": "낡은 지도 조각",
}


func material_name(id: StringName) -> String:
	return MAT_NAMES.get(id, String(id))


# ─── 항아리 (쿨타임마다 랜덤 보상) ───

func pot_ready() -> bool:
	return play_time >= pot_ready_at


func pot_remaining() -> float:
	return maxf(0.0, pot_ready_at - play_time)


## 항아리를 깬다. 준비됐으면 보상 토스트 문자열 반환, 아니면 "".
func break_pot() -> String:
	if not pot_ready():
		return ""
	var msg := _grant(_roll_pot())
	pot_ready_at = play_time + config.pot_cooldown
	EventBus.pot_changed.emit()
	return msg


func _roll_pot() -> Dictionary:
	return _weighted_pick([
		{"w": 5.0, "type": "gold", "min": 1, "max": 5},
		{"w": 4.0, "type": "mat", "id": &"stone", "n": 1},
		{"w": 3.0, "type": "mat", "id": &"herb", "n": 1},
		{"w": 2.0, "type": "mat", "id": &"pot_shard", "n": 1},
		{"w": 1.0, "type": "mat", "id": &"wood_key", "n": 1},  # 보물상자 열쇠
		{"w": 0.5, "type": "mat", "id": &"medal_shard", "n": 1},
	])


# ─── 보물상자 ───

func chest_ready() -> bool:
	return play_time >= chest_ready_at


func chest_remaining() -> float:
	return maxf(0.0, chest_ready_at - play_time)


## 열쇠 시스템 해금 후엔 지정된 열쇠가 필요하다 (중반).
func chest_needs_key() -> bool:
	return chest_keys_unlocked and chest_required_key != &""


func chest_can_open() -> bool:
	if not chest_ready():
		return false
	return not chest_needs_key() or material_count(chest_required_key) > 0


func open_chest() -> String:
	if not chest_can_open():
		return ""
	if chest_needs_key():
		spend_material(chest_required_key, 1)
	var msg := _grant(_roll_chest())
	chest_ready_at = play_time + config.chest_cooldown
	chest_opens += 1
	if chest_opens >= config.chest_key_unlock_opens:
		chest_keys_unlocked = true
	_assign_chest_key() # 다음 개봉에 필요한 열쇠 지정
	EventBus.chest_changed.emit()
	return msg


## 다음 사이클의 필요 열쇠 지정 (MVP는 나무 열쇠 한 종류).
func _assign_chest_key() -> void:
	chest_required_key = &"wood_key" if chest_keys_unlocked else &""


func _roll_chest() -> Dictionary:
	return _weighted_pick([
		{"w": 5.0, "type": "gold", "min": 30, "max": 80},
		{"w": 3.0, "type": "sword", "n": 1},
		{"w": 3.0, "type": "mat", "id": &"enhance_stone", "n": 1},
		{"w": 3.0, "type": "mat", "id": &"stone", "n": 2},
		{"w": 0.7, "type": "mat", "id": &"medal_shard", "n": 1},
	])


func _weighted_pick(table: Array) -> Dictionary:
	var total := 0.0
	for e in table:
		total += float(e.w)
	var r := randf() * total
	for e in table:
		r -= float(e.w)
		if r <= 0.0:
			return e
	return table[table.size() - 1]


## 보상 적용 + 토스트용 문자열 반환
func _grant(e: Dictionary) -> String:
	match e.type:
		"gold":
			var g := randi_range(int(e["min"]), int(e["max"]))
			add_gold(g)
			return "골드 +%d" % g
		"mat":
			add_material(e.id, int(e.n))
			return "%s +%d" % [material_name(e.id), int(e.n)]
		"sword":
			rusty_swords += int(e.n)
			EventBus.materials_changed.emit()
			return "녹슨 검 +%d" % int(e.n)
		"gem":
			add_gems(int(e.n))
			return "보석 +%d" % int(e.n)
	return ""


# ─── 대장간 (검 강화 → 판매) ───

func forge_has_sword() -> bool:
	return forge_level >= 0


## 화로에 녹슨 검을 올린다 (보유분에서 1개 소모).
func forge_put_sword() -> bool:
	if forge_has_sword() or rusty_swords <= 0:
		return false
	rusty_swords -= 1
	forge_level = 0
	EventBus.forge_changed.emit()
	EventBus.materials_changed.emit()
	return true


## 현재 검을 +1 강화하는 비용 {gold, mat, n}.
func forge_cost() -> Dictionary:
	match forge_level:
		0: return {"gold": 25, "mat": &"stone", "n": 1}
		1: return {"gold": 40, "mat": &"stone", "n": 2}
		2: return {"gold": 60, "mat": &"stone", "n": 3}
		3: return {"gold": 80, "mat": &"stone", "n": 4}
		_: return {"gold": 120, "mat": &"enhance_stone", "n": 1}


func forge_can_enhance() -> bool:
	if not forge_has_sword() or forge_level >= config.sword_max_level:
		return false
	var c := forge_cost()
	return gold >= int(c.gold) and material_count(c.mat) >= int(c.n)


func forge_enhance() -> bool:
	if not forge_can_enhance():
		return false
	var c := forge_cost()
	try_spend(int(c.gold))
	spend_material(c.mat, int(c.n))
	forge_level += 1
	EventBus.forge_changed.emit()
	return true


func forge_can_sell() -> bool:
	return forge_level >= config.sword_max_level


func forge_sell() -> bool:
	if not forge_can_sell():
		return false
	add_gems(config.sword_sell_gems)
	forge_level = -1
	EventBus.forge_changed.emit()
	return true


## 화로의 검을 장착 (판매 대신) → 용사 공격력 상승. "강해질까 vs 보석" 선택.
func equip_forge_sword() -> bool:
	if not forge_has_sword():
		return false
	equipped_sword_level = forge_level
	forge_level = -1
	recalculate_stats() # 장착검 공격력 반영 (stats_changed 발신)
	EventBus.forge_changed.emit()
	return true


func equipped_attack_bonus() -> int:
	return equipped_sword_level * config.sword_attack_per_level if equipped_sword_level >= 0 else 0


# ─── 땅파기 (삽 → 쿨타임마다 채굴) ───

func dig_unlocked() -> bool:
	return has_shovel


func dig_ready() -> bool:
	return has_shovel and play_time >= dig_ready_at


func dig_remaining() -> float:
	return maxf(0.0, dig_ready_at - play_time)


## 반짝이는 땅 생성 확률 = 기본 + 지혜 보정 + 꼬마돼지 보정.
func sparkle_chance() -> float:
	var c := config.sparkle_base_chance + wisdom * config.wisdom_sparkle_per
	if has_pig_companion:
		c += config.pig_sparkle_bonus
	return clampf(c, 0.0, 1.0)


## 현재 위치를 판다 (땅파기 버튼). 반환 {ok, sparkle, msg}.
## 반짝이는 땅 "위에서" 파면 100% 보상, 아니면 낮은 확률로만 보상.
func do_dig() -> Dictionary:
	if not dig_ready():
		return {"ok": false, "sparkle": false, "msg": ""}
	var on_sparkle := has_sparkling_ground and party_on_sparkle
	var msg := ""
	if on_sparkle:
		msg = _grant(_roll_dig_sparkle())
		_clear_sparkle()
	elif randf() < config.dig_success_chance:
		msg = _grant(_roll_dig())
	dig_ready_at = play_time + dig_cooldown
	# 지혜 확률로 새 반짝임 생성 (꼬마돼지는 _tick_sparkle이 확정으로 처리)
	if not has_pig_companion and not has_sparkling_ground and randf() < sparkle_chance():
		_spawn_sparkle()
	EventBus.dig_changed.emit()
	return {"ok": true, "sparkle": on_sparkle, "msg": msg}


## 반짝이는 땅을 맵에 띄운다. 실제 위치는 SparkleGround(맵 노드)가 랜덤으로 정한다.
func _spawn_sparkle() -> void:
	has_sparkling_ground = true
	sparkle_area = current_region
	var t := "🐷 꼬마돼지가 수상한 냄새를 맡았다!" if has_pig_companion else "✨ 수상하게 반짝이는 땅이 나타났다!"
	EventBus.show_toast.emit(t)
	EventBus.dig_changed.emit()


func _clear_sparkle() -> void:
	has_sparkling_ground = false
	sparkle_area = &""
	party_on_sparkle = false


## 꼬마돼지: 삽 보유 + 쿨타임 종료 시 반짝이는 땅을 확정으로 찾아준다 (맵 랜덤 위치에 등장).
func _tick_sparkle() -> void:
	if has_pig_companion and has_shovel and not has_sparkling_ground and dig_ready():
		_spawn_sparkle()


func _roll_dig() -> Dictionary:
	return _weighted_pick([
		{"w": 5.0, "type": "gold", "min": 1, "max": 20},
		{"w": 4.0, "type": "mat", "id": &"stone", "n": randi_range(1, 3)},
		{"w": 2.0, "type": "mat", "id": &"pot_shard", "n": 1},
		{"w": 1.5, "type": "mat", "id": &"enhance_stone", "n": 1},
		{"w": 1.0, "type": "mat", "id": &"wood_key", "n": 1},
		{"w": 0.6, "type": "mat", "id": &"map_shard", "n": 1},
		{"w": 0.3, "type": "mat", "id": &"medal_shard", "n": 1},
	])


## 반짝이는 땅 보상 (100%, 더 짭짤하게).
func _roll_dig_sparkle() -> Dictionary:
	return _weighted_pick([
		{"w": 4.0, "type": "gold", "min": 30, "max": 90},
		{"w": 3.0, "type": "mat", "id": &"enhance_stone", "n": 2},
		{"w": 2.5, "type": "mat", "id": &"medal_shard", "n": 1},
		{"w": 2.0, "type": "mat", "id": &"map_shard", "n": 1},
		{"w": 2.0, "type": "sword", "n": 1},
		{"w": 1.5, "type": "gem", "n": 1},
	])


# ─── 보석 자동화 ───

func buy_auto_pot() -> bool:
	if auto_pot or not spend_gems(config.auto_pot_gem_cost):
		return false
	auto_pot = true
	EventBus.forge_changed.emit()
	return true


func buy_auto_enhance() -> bool:
	if auto_enhance or not spend_gems(config.auto_enhance_gem_cost):
		return false
	auto_enhance = true
	EventBus.forge_changed.emit()
	return true


func buy_auto_deliver() -> bool:
	if auto_deliver or not spend_gems(config.auto_deliver_gem_cost):
		return false
	auto_deliver = true
	EventBus.forge_changed.emit()
	return true


## 자동 강화/납품: 인터벌마다 한 스텝 (판매 → 강화 → 다음 검 장전 순) 진행해
## 검 → 보석 공장을 굴린다.
func _tick_forge(delta: float) -> void:
	if not (auto_enhance or auto_deliver):
		return
	_forge_accum += delta
	while _forge_accum >= config.auto_forge_interval:
		_forge_accum -= config.auto_forge_interval
		if not _forge_auto_step():
			_forge_accum = 0.0 # 할 일 없으면 누적 멈춤
			break


func _forge_auto_step() -> bool:
	if auto_deliver and forge_can_sell():
		return forge_sell()
	if auto_enhance and forge_can_enhance():
		return forge_enhance()
	if auto_deliver and not forge_has_sword() and rusty_swords > 0:
		return forge_put_sword()
	return false


# ─── 스탯 집계 ───

func recalculate_stats() -> void:
	party_attack = config.base_party_attack
	turn_interval = config.base_turn_interval
	move_speed = config.base_move_speed
	respawn_delay_mult = 1.0
	max_battle_windows = config.initial_max_battle_windows + elder_window_bonus
	auto_hunt_unlocked = false
	crit_chance = config.base_crit_chance
	damage_reduction_mult = 1.0
	all_attack = false
	remote_shop_unlocked = false
	has_shovel = false
	has_pig_companion = false
	var dig_levels := 0
	group_table = [1.0]
	for id: StringName in purchases:
		var upgrade: UpgradeData = catalog.get(id)
		if upgrade == null:
			continue
		var count: int = purchases[id]
		for key: String in upgrade.effects:
			var value: Variant = upgrade.effects[key]
			match key:
				"party_attack":
					party_attack += int(value) * count
				"turn_interval_mult":
					turn_interval *= pow(float(value), count)
				"move_speed_mult":
					move_speed *= pow(float(value), count)
				"respawn_delay_mult":
					respawn_delay_mult *= pow(float(value), count)
				"max_battle_windows":
					max_battle_windows += int(value) * count
				"auto_hunt":
					auto_hunt_unlocked = bool(value)
				"damage_reduction_mult":
					damage_reduction_mult *= pow(float(value), count) # 사슬 갑옷
				"group_table":
					# 가장 진보한 표(항목 수 많은 쪽)를 채택 (용맹의 깃발, v3 §4)
					if value is Array and value.size() > group_table.size():
						var t: Array[float] = []
						for p in value:
							t.append(float(p))
						group_table = t
				"all_attack":
					all_attack = bool(value)                        # 베기라
				"remote_shop":
					remote_shop_unlocked = bool(value)              # 주문 카탈로그
				"has_shovel":
					has_shovel = bool(value)                        # 삽 → 땅파기 해금
				"dig_cooldown_reduce":
					dig_levels += count                             # 좋은 삽 누적 단계
				"pig_companion":
					has_pig_companion = bool(value)                 # 꼬마돼지 영입
				_:
					push_warning("알 수 없는 효과 키: %s (%s)" % [key, upgrade.id])
	if equipped_sword_level >= 0: # 장착한 강화검 — 용사가 든다
		party_attack += equipped_sword_level * config.sword_attack_per_level
	hero_attack = party_attack # 용사 = 기본 + 무기/주문 업그레이드 + 장착검 (동료 보너스 제외)
	# 동료 공격력 기여 (용사 + 동료 합산 = 파티 총 공격력)
	for c in companions:
		party_attack += c.attack_bonus
	# 땅파기 쿨타임: 좋은 삽 단계당 감소, 하한 적용
	dig_cooldown = maxf(config.dig_min_cooldown,
		config.dig_base_cooldown - dig_levels * config.dig_cooldown_per_level)
	EventBus.stats_changed.emit()


func advance_elder_stage() -> void:
	elder_stage += 1
	if elder_stage == 1:
		can_move_in_battle = true
		elder_window_bonus = 1
		EventBus.show_toast.emit("전수 완료! 이제 전투 중에도 걸을 수 있다 (동시 전투 2)")
	elif elder_stage == 2:
		elder_window_bonus = 2
		EventBus.show_toast.emit("동시 전투창이 3개로 늘었다!")
	recalculate_stats()


# ─── 처음부터 다시하기 (메뉴) ───
## 세이브를 지우고 모든 상태를 기본값으로 되돌린다. 오토로드는 씬 리로드로 재초기화되지
## 않으므로 여기서 직접 리셋한다. 호출 후 호출측이 get_tree().reload_current_scene()로 재구성.
func reset_to_new_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	# 진행 상태
	gold = 0
	total_gold_earned = 0
	total_exp = 0
	total_battles_won = 0
	play_time = 0.0
	purchases.clear()
	kill_count.clear()
	companions.clear()
	hunt_list.clear()
	monster_catalog.clear()
	elder_stage = 0
	can_move_in_battle = false
	elder_window_bonus = 0
	dual_battle_celebrated = false
	gate_paid = false
	first_sword_time = -1.0
	# 멤버 HP / 지역 / 의뢰 / 전술
	member_hps.clear()
	member_max_hps.clear()
	damage_enabled = false
	tactic_retreat_unlocked = false
	tactic_retreat_enabled = false
	current_region = &"region1"
	active_quest_id = &""
	quest_progress_base = 0
	vision_zoom = config.base_vision_zoom
	_retreat_active = false
	_heal_accum = 0.0
	# 마을 오브젝트
	gems = 0
	materials.clear()
	rusty_swords = 0
	forge_level = -1
	equipped_sword_level = -1
	pot_ready_at = 0.0
	chest_ready_at = 0.0
	chest_keys_unlocked = false
	chest_required_key = &""
	chest_opens = 0
	auto_pot = false
	auto_enhance = false
	auto_deliver = false
	dig_ready_at = 0.0
	has_sparkling_ground = false
	sparkle_area = &""
	party_on_sparkle = false
	wisdom = 0
	recalculate_stats()
	_ensure_member_hp() # 용사만, 가득


# ─── 저장/로드 ───

func _hunt_list_out() -> Dictionary:
	var out := {}
	for id: StringName in hunt_list:
		out[String(id)] = hunt_list[id]
	return out


func _materials_out() -> Dictionary:
	var out := {}
	for id: StringName in materials:
		out[String(id)] = materials[id]
	return out


func save_game() -> void:
	var purchases_out := {}
	for id: StringName in purchases:
		purchases_out[String(id)] = purchases[id]
	var kills_out := {}
	for id: StringName in kill_count:
		kills_out[String(id)] = kill_count[id]
	var companions_out: Array = []
	for c in companions:
		companions_out.append(String(c.id))
	var data := {
		"gold": gold,
		"total_gold_earned": total_gold_earned,
		"total_exp": total_exp,
		"total_battles_won": total_battles_won,
		"play_time": play_time,
		"purchases": purchases_out,
		"kill_count": kills_out,
		"companions": companions_out,
		"elder_stage": elder_stage,
		"can_move_in_battle": can_move_in_battle,
		"elder_window_bonus": elder_window_bonus,
		"dual_battle_celebrated": dual_battle_celebrated,
		"gate_paid": gate_paid,
		"first_sword_time": first_sword_time,
		"member_hps": member_hps.duplicate(),
		"damage_enabled": damage_enabled,
		"current_region": String(current_region),
		"active_quest_id": String(active_quest_id),
		"quest_progress_base": quest_progress_base,
		"vision_zoom": vision_zoom,
		"hunt_list": _hunt_list_out(),
		"tactic_retreat_unlocked": tactic_retreat_unlocked,
		"tactic_retreat_enabled": tactic_retreat_enabled,
		"gems": gems,
		"materials": _materials_out(),
		"rusty_swords": rusty_swords,
		"forge_level": forge_level,
		"equipped_sword_level": equipped_sword_level,
		"pot_ready_at": pot_ready_at,
		"chest_ready_at": chest_ready_at,
		"chest_keys_unlocked": chest_keys_unlocked,
		"chest_required_key": String(chest_required_key),
		"chest_opens": chest_opens,
		"auto_pot": auto_pot,
		"auto_enhance": auto_enhance,
		"auto_deliver": auto_deliver,
		"dig_ready_at": dig_ready_at,
		"has_sparkling_ground": has_sparkling_ground,
		"sparkle_area": String(sparkle_area),
		"wisdom": wisdom,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	gold = int(data.get("gold", 0))
	total_gold_earned = int(data.get("total_gold_earned", 0))
	total_exp = int(data.get("total_exp", 0))
	total_battles_won = int(data.get("total_battles_won", 0))
	play_time = float(data.get("play_time", 0.0))
	elder_stage = int(data.get("elder_stage", 0))
	can_move_in_battle = bool(data.get("can_move_in_battle", false))
	elder_window_bonus = int(data.get("elder_window_bonus", 0))
	dual_battle_celebrated = bool(data.get("dual_battle_celebrated", false))
	gate_paid = bool(data.get("gate_paid", false))
	first_sword_time = float(data.get("first_sword_time", -1.0))
	member_hps.clear()
	for h in data.get("member_hps", []):
		member_hps.append(int(h)) # _ensure_member_hp가 멤버 수에 맞춰 정리
	damage_enabled = bool(data.get("damage_enabled", false))
	current_region = StringName(data.get("current_region", "region1"))
	active_quest_id = StringName(data.get("active_quest_id", ""))
	quest_progress_base = int(data.get("quest_progress_base", 0))
	vision_zoom = float(data.get("vision_zoom", config.base_vision_zoom))
	tactic_retreat_unlocked = bool(data.get("tactic_retreat_unlocked", false))
	tactic_retreat_enabled = bool(data.get("tactic_retreat_enabled", false))
	gems = int(data.get("gems", 0))
	rusty_swords = int(data.get("rusty_swords", 0))
	forge_level = int(data.get("forge_level", -1))
	equipped_sword_level = int(data.get("equipped_sword_level", -1))
	pot_ready_at = float(data.get("pot_ready_at", 0.0))
	chest_ready_at = float(data.get("chest_ready_at", 0.0))
	chest_keys_unlocked = bool(data.get("chest_keys_unlocked", false))
	chest_required_key = StringName(data.get("chest_required_key", ""))
	chest_opens = int(data.get("chest_opens", 0))
	auto_pot = bool(data.get("auto_pot", false))
	auto_enhance = bool(data.get("auto_enhance", false))
	auto_deliver = bool(data.get("auto_deliver", false))
	dig_ready_at = float(data.get("dig_ready_at", 0.0))
	has_sparkling_ground = bool(data.get("has_sparkling_ground", false))
	sparkle_area = StringName(data.get("sparkle_area", ""))
	wisdom = int(data.get("wisdom", 0))
	materials.clear()
	var mats_in: Dictionary = data.get("materials", {})
	for key: String in mats_in:
		materials[StringName(key)] = int(mats_in[key])
	hunt_list.clear()
	var hunt_in: Dictionary = data.get("hunt_list", {})
	for key: String in hunt_in:
		hunt_list[StringName(key)] = bool(hunt_in[key])
	purchases.clear()
	var purchases_in: Dictionary = data.get("purchases", {})
	for key: String in purchases_in:
		purchases[StringName(key)] = int(purchases_in[key])
	kill_count.clear()
	var kills_in: Dictionary = data.get("kill_count", {})
	for key: String in kills_in:
		kill_count[StringName(key)] = int(kills_in[key])
	companions.clear()
	var companions_in: Array = data.get("companions", [])
	for cid: String in companions_in:
		var comp: CompanionData = companion_catalog.get(StringName(cid))
		if comp:
			companions.append(comp)
