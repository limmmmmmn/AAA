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

# ─── PART B: 공유 HP / 지역 / 의뢰 (저장 대상) ───
var shared_hp: int = 50
var shared_hp_max: int = 50
var damage_enabled: bool = false        # 1지역 off, 2지역 진입 시 on (B-2)
var tactic_retreat_unlocked: bool = false # 승려 합류 시 해금 (v3 §9)
var tactic_retreat_enabled: bool = false  # HUD 토글
var current_region: StringName = &"region1"
var active_quest_id: StringName = &""   # 동시 수주 1개
var quest_progress_base: int = 0        # 수주 시점의 target 토벌 수 (이후 증가분만 카운트)

# ─── 파생 스탯 (recalculate_stats만 계산) ───
var party_attack: int = 3               # 용사 + 동료 합산
var turn_interval: float = 1.2
var move_speed: float = 80.0
var respawn_delay_mult: float = 1.0
var max_battle_windows: int = 1
var auto_hunt_unlocked: bool = false
var vision_zoom: float = 1.0            # 카메라 줌 (작을수록 넓게)
var crit_chance: float = 0.02          # 회심의 일격 확률 (v3 §1)
var damage_reduction_mult: float = 1.0 # 사슬 갑옷 등 피격 경감 (B-6)
var all_attack: bool = false           # 베기라: 전체 공격 (B-6)
var remote_shop_unlocked: bool = false # 주문 카탈로그: 원격 구매 (B-6)

# ─── 무리 출현 확률표 (v3 §4). [1.0] = 항상 1마리. 배너로 확장 ───
var group_table: Array[float] = [1.0]

var catalog: Dictionary = {}            # id(StringName) -> UpgradeData
var companion_catalog: Dictionary = {}  # id(StringName) -> CompanionData
var quest_catalog: Dictionary = {}      # id(StringName) -> QuestData

var _heal_accum: float = 0.0            # 공유 HP 회복 틱 누적


func _ready() -> void:
	config = load(CONFIG_PATH)
	vision_zoom = config.base_vision_zoom
	_load_catalog()
	_load_companion_catalog()
	_load_quest_catalog()
	load_game()
	recalculate_stats()
	EventBus.zone_unlocked.connect(_on_zone_unlocked) # 정예존 해금 → 시야 보상 (v3 §6)
	var autosave := Timer.new()
	autosave.wait_time = config.autosave_interval
	autosave.timeout.connect(save_game)
	add_child(autosave)
	autosave.start()


func _process(delta: float) -> void:
	play_time += delta
	_tick_heal(delta)


## 동료(승려)의 상시 회복 — 전역으로 turn_interval 주기마다 shared_hp 회복 (B-2)
func _tick_heal(delta: float) -> void:
	if not damage_enabled or shared_hp <= 0 or shared_hp >= shared_hp_max:
		return
	var heal_per_turn := 0
	for c in companions:
		heal_per_turn += c.heal_per_turn
	if heal_per_turn <= 0:
		return
	_heal_accum += delta
	while _heal_accum >= turn_interval:
		_heal_accum -= turn_interval
		heal(heal_per_turn)


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


# ─── 공유 HP / 패배 / 부활 (B-2) ───

## BattleInstance가 턴마다 호출. damage_enabled일 때만 공유 풀을 깎는다.
func apply_damage(raw: int) -> void:
	if not damage_enabled or raw <= 0 or shared_hp <= 0:
		return
	var dmg := maxi(1, int(round(raw * damage_reduction_mult)))
	shared_hp = maxi(0, shared_hp - dmg)
	EventBus.shared_hp_changed.emit(shared_hp, shared_hp_max)
	if shared_hp <= 0:
		EventBus.party_defeated.emit()
	elif tactic_retreat_enabled and not _retreat_active and shared_hp <= 0.25 * shared_hp_max:
		# 자동 철수 전술 발동 (v3 §9) — 죽기 전에 발을 뺀다
		_retreat_active = true
		EventBus.tactic_retreat_triggered.emit()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	shared_hp = mini(shared_hp_max, shared_hp + amount)
	if shared_hp > 0.3 * shared_hp_max:
		_retreat_active = false # 위험 구간을 벗어나면 다음 철수 재무장
	EventBus.shared_hp_changed.emit(shared_hp, shared_hp_max)


func full_heal() -> void:
	shared_hp = shared_hp_max
	_retreat_active = false
	EventBus.shared_hp_changed.emit(shared_hp, shared_hp_max)


## 패배 처리: 소지금 절반 차감 + 전량 회복 (창 닫기/이동은 호출측 연출이 담당)
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
				_:
					push_warning("알 수 없는 효과 키: %s (%s)" % [key, upgrade.id])
	# 동료 공격력 기여 (용사 + 동료 합산)
	for c in companions:
		party_attack += c.attack_bonus
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


# ─── 저장/로드 ───

func _hunt_list_out() -> Dictionary:
	var out := {}
	for id: StringName in hunt_list:
		out[String(id)] = hunt_list[id]
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
		"shared_hp": shared_hp,
		"shared_hp_max": shared_hp_max,
		"damage_enabled": damage_enabled,
		"current_region": String(current_region),
		"active_quest_id": String(active_quest_id),
		"quest_progress_base": quest_progress_base,
		"vision_zoom": vision_zoom,
		"hunt_list": _hunt_list_out(),
		"tactic_retreat_unlocked": tactic_retreat_unlocked,
		"tactic_retreat_enabled": tactic_retreat_enabled,
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
	shared_hp = int(data.get("shared_hp", 50))
	shared_hp_max = int(data.get("shared_hp_max", 50))
	damage_enabled = bool(data.get("damage_enabled", false))
	current_region = StringName(data.get("current_region", "region1"))
	active_quest_id = StringName(data.get("active_quest_id", ""))
	quest_progress_base = int(data.get("quest_progress_base", 0))
	vision_zoom = float(data.get("vision_zoom", config.base_vision_zoom))
	tactic_retreat_unlocked = bool(data.get("tactic_retreat_unlocked", false))
	tactic_retreat_enabled = bool(data.get("tactic_retreat_enabled", false))
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
