extends Node
## 골드, 보유 업그레이드, 파티 스탯 집계, 해금 상태. 저장/로드 담당.
## 효과 적용은 recalculate_stats() 한 곳에서만 — 개별 노드가 스탯을 직접 만지지 않는다.

const SAVE_PATH := "user://save.json"
const CONFIG_PATH := "res://data/config/game_config.tres"
const UPGRADE_DIR := "res://data/upgrades"
const COMPANION_DIR := "res://data/companions"
const QUEST_DIR := "res://data/quests"
const STAGE_DIR := "res://data/stages"
const TRINKET_DIR := "res://data/trinkets"

var config: GameConfig

# ─── 진행 상태 (저장 대상) ───
var gold: int = 0
var language: String = "ko"              # UI 언어 (ko/en) — Locale가 폰트/번역 적용
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
var damage_enabled: bool = true         # 1지역부터 적 공격이 아군에게 데미지
var tactic_retreat_unlocked: bool = false # 승려 합류 시 해금 (v3 §9)
var tactic_retreat_enabled: bool = false  # HUD 토글
var current_region: StringName = &"stage_meadow" # 현재 단계 id (맵은 하나, 단계만 갈아끼움)
var active_quest_id: StringName = &""   # 동시 수주 1개
var quest_progress_base: int = 0        # 수주 시점의 target 토벌 수 (이후 증가분만 카운트)

# ─── 마을 오브젝트: 재화/재료/대장간/쿨타임 (저장 대상) ───
var gems: int = 0                       # 보석 (상위 재화 — 검 판매로 획득, 자동화 구매)
var materials: Dictionary = {}          # id(StringName) -> 수량 (stone/herb/pot_shard/enhance_stone/medal_shard/wood_key)
var rusty_swords: int = 0               # 미강화 녹슨 검 보유 수
var forge_level: int = -1               # 화로에 올린 검의 강화 수치 (-1 = 검 없음)
var equipped_sword_level: int = -1      # 장착한 검의 강화 수치 (-1 = 맨손) → 용사 공격력 +
# 마을 설치물은 전부 상점 업그레이드로 해금/증설한다 (인크리멘탈). 갯수만큼 인덱스별 쿨타임.
var pot_unlocked: bool = false          # 항아리 설치 해금
var chest_unlocked: bool = false        # 보물상자 설치 해금
var pot_count: int = 0                  # 설치된 항아리 수 (해금 시 1 + 증설)
var chest_count: int = 0                # 설치된 보물상자 수
var pot_cooldown_lv: int = 0            # 항아리 복구 속도 업글 단계
var chest_cooldown_lv: int = 0          # 보물상자 복구 속도 업글 단계
var pot_ready_ats: Array[float] = []    # 인덱스별 복구 완료 시각 (≤ play_time 이면 준비됨)
var chest_ready_ats: Array[float] = []
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
var spawn_count_bonus: int = 0          # 존별 최대 몬스터 수 +α (몹 증식 업글)
var max_battle_windows: int = 1
var auto_hunt_unlocked: bool = false
var auto_move_on: bool = false          # 자동 이동 토글 (우측 버튼 온/오프)
var crit_chance: float = 0.02          # 회심의 일격 확률 (v3 §1) — 운이 더해진 최종값
var party_luck: int = 0                # 파티 운 = 멤버 중 가장 높은 운 (회심·골드·발견에 영향)
var hero_luck: int = 0                 # 용사 단독 운 (기본 + 행운 업글)
var damage_reduction_mult: float = 1.0 # 사슬 갑옷 등 피격 경감 (B-6)
var all_attack: bool = false           # 베기라: 전체 공격 (B-6)
var remote_shop_unlocked: bool = false # 주문 카탈로그: 원격 구매 (B-6)
var has_shovel: bool = false           # 삽 보유 (상점 구매 → 땅파기 해금)
var has_pig_companion: bool = false    # 꼬마돼지 영입 (반짝임 발견 ↑)
var dig_cooldown: float = 60.0         # 땅파기 쿨타임 (좋은 삽으로 감소)
var inn_unlocked: bool = false         # 여관 설치 여부 (상점 구매)
var bonfire_unlocked: bool = false     # 모닥불 설치 여부 (상점 구매)
var bonfire_speed_lv: int = 0          # 회복 속도 업글 단계 (간격↓)
var bonfire_range_lv: int = 0          # 회복 범위 업글 단계 (반경↑)
var bonfire_heal_lv: int = 0           # 회복량 업글 단계 (1틱 +HP↑)

# ─── 무리 출현 확률표 (v3 §4). [1.0] = 항상 1마리. 배너로 확장 ───
var group_table: Array[float] = [1.0]

# ─── 제너릭 스탯 사전 (업그레이드 트리 v0.1) ───
## 스펙의 baseStats. 새 노드는 effects의 키로 이 사전을 건드린다. recalculate_stats가
## 기본값에서 다시 빌드하고, 알 수 없는(레거시 외) 키는 _apply_generic_stat이 분류 적용한다.
## 곱(_STAT_MULT): 기본 1.0, 효과는 거듭곱. / 합(_STAT_ADD): 기본값에 합. / 불(_STAT_BOOL): set true.
var stats: Dictionary = {}
const _STAT_MULT := {
	"party_damage_mult": 1.0, "party_hp_mult": 1.0, "attack_speed_mult": 1.0,
	"enemy_gold_mult": 1.0, "boss_gold_mult": 1.0, "boss_damage_mult": 1.0,
	"pot_gold_mult": 1.0, "pot_respawn_mult": 1.0,
	"upgrade_cost_mult": 1.0, "village_gold_mult": 1.0, "all_gold_mult": 1.0,
	"crit_damage_mult": 1.0, "enemy_hp_mult": 1.0,
}
const _STAT_ADD := {
	"combat_slots": 1, "extra_window_efficiency": 0.45,
	"pot_base_gold": 0, "auto_pot_interval_sec": 0,
	"crate_count": 0, "trinket_slots": 0,
	"trinket_drop_chance": 0.0, "rare_trinket_chance": 0.0,
	"hero_max_hp": 0,
}
const _STAT_BOOL := {
	"auto_battle_restart": false, "auto_loot": false, "auto_boss_retry": false,
	"boss_does_not_pause_farm": false, "npc_talk_enabled": false,
	"shop_enabled": false, "healer_enabled": false, "trinkets_enabled": false,
	"target_priority_enabled": false,
	# ─ 트링켓 시스템 해금 플래그 ─
	"boss_trinket_guarantee": false, "trinket_reroll_enabled": false,
	"trinket_sets_enabled": false, "cursed_trinkets_enabled": false,
	"pot_trinket_pool_enabled": false, "trinket_loadouts_enabled": false,
	"trinket_collection_bonus": false,
	# ─ core 스파인 해금 플래그 (가지 노출·시스템 게이팅용) ─
	"adventure_started": false, "village_tree_unlocked": false,
	"command_tree_unlocked": false, "meadow_boss_cleared": false,
	"quest_unlocked": false, "ending_reached": false,
}
## 스탯이 아니라 "행동"인 효과 키 — recalculate_stats에선 무시하고 purchase가 처리한다.
const _ACTION_KEYS := ["set_stage", "recruit", "discover_trinkets"]

var catalog: Dictionary = {}            # id(StringName) -> UpgradeData
var companion_catalog: Dictionary = {}  # id(StringName) -> CompanionData
var quest_catalog: Dictionary = {}      # id(StringName) -> QuestData
var stage_catalog: Array[StageData] = [] # 단계 목록 (index 오름차순) — 맵 1개를 갈아끼우는 단위
var trinket_catalog: Dictionary = {}    # id(StringName) -> TrinketData
var owned_trinkets: Array[StringName] = []    # 발견한 트링켓 (수집 도감 — trk_collection)
var equipped_trinkets: Array[StringName] = [] # 장착 중 (trinket_slots 만큼 자동 채움)

var _heal_accum: float = 0.0            # 공유 HP 회복 틱 누적
var _forge_accum: float = 0.0           # 자동 강화/납품 틱 누적

# ─── 디버그 (저장 안 함 — 실행마다 off로 시작) ───
var debug_mode: bool = false
## 골드/분 추적 — 출처별(전투/마을/보스). add_gold(amount, source)가 기록.
var last_purchase_time: float = 0.0     # 마지막 노드 구매 시각(play_time) — 구매 간격 측정
var _gold_events: Array = []            # [{t, amt, src}] — 최근 60s 윈도우 (오래된 건 즉시 폐기)
const _GPM_WINDOW := 60.0               # 골드/분 측정 윈도우(s)


func set_debug_mode(on: bool) -> void:
	debug_mode = on
	EventBus.debug_mode_changed.emit(on)


func _ready() -> void:
	config = load(CONFIG_PATH)
	turn_beat_delay = config.turn_beat_delay
	_load_catalog()
	_load_companion_catalog()
	_load_quest_catalog()
	_load_stage_catalog()
	_load_trinket_catalog()
	load_game()
	recalculate_stats()
	_ensure_member_hp() # 멤버별 HP 배열을 멤버 수에 맞춰 정리 (로드 값 보존, 부족분 가득)
	if chest_keys_unlocked and chest_required_key == &"":
		_assign_chest_key() # 해금됐는데 열쇠 미지정이면 보정 (구 세이브 대비)
	var autosave := Timer.new()
	autosave.wait_time = config.autosave_interval
	autosave.timeout.connect(save_game)
	add_child(autosave)
	autosave.start()


func _process(delta: float) -> void:
	play_time += delta
	_tick_heal(delta)
	if auto_pot: # 자동 항아리꾼: 쿨타임마다 준비된 항아리를 전부 자동으로 깬다
		for i in pot_count:
			if pot_ready(i):
				break_pot(i)
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


# ─── 단계(Stage) — 맵 하나로 1~최종 지역 커버 ───

func _load_stage_catalog() -> void:
	stage_catalog.clear()
	var dir := DirAccess.open(STAGE_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		var fname := file.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var s: StageData = load(STAGE_DIR + "/" + fname)
		if s:
			stage_catalog.append(s)
	stage_catalog.sort_custom(func(a: StageData, b: StageData) -> bool: return a.index < b.index)


## 현재 단계 데이터 (없으면 첫 단계, 카탈로그 미로드면 null).
func current_stage() -> StageData:
	for s: StageData in stage_catalog:
		if s.id == current_region:
			return s
	return stage_catalog[0] if not stage_catalog.is_empty() else null


func _stage_by_index(idx: int) -> StageData:
	for s: StageData in stage_catalog:
		if s.index == idx:
			return s
	return null


## 현재 단계 번호 (옛 region_number — 상점 min_region 게이팅에 그대로 쓰인다).
func region_number() -> int:
	var s := current_stage()
	return s.index if s != null else 1


## 현재 단계 지역명 (HUD 제목용).
func stage_name() -> String:
	var s := current_stage()
	return s.display_name if s != null else ""


## 현재 단계에서 role(near/mid/far/rare)에 해당하는 몬스터 (SpawnZone이 호출).
func stage_monster(role: StringName) -> MonsterData:
	var s := current_stage()
	return s.monster_for(role) if s != null else null


func _stage_by_id(id: StringName) -> StageData:
	for s: StageData in stage_catalog:
		if s.id == id:
			return s
	return null


## 특정 단계로 전진(역행 불가). core 스파인의 지역 노드를 사면 호출된다 = "골드로 지역을 산다".
## 첫 도달이면 동료 합류 + full_heal. 성공 시 region_changed 발신. 현재 이하/모르는 단계면 false.
func set_stage_to(stage_id: StringName) -> bool:
	var target := _stage_by_id(stage_id)
	if target == null or target.index <= region_number():
		return false # 전진만 — 현재 이하면 무시
	current_region = stage_id
	gate_paid = true
	full_heal() # 새 지역 = 새 출발, 가득 채워 보낸다
	if target.joins_companion != &"":
		var comp: CompanionData = companion_catalog.get(target.joins_companion)
		if comp and not _has_companion(comp.id):
			add_companion(comp)
	sparkle_area = current_region
	has_sparkling_ground = false # 새 단계 → 반짝임 리셋
	EventBus.region_changed.emit(current_region)
	return true


## 다음 단계로 진행(순차). set_stage_to의 얇은 래퍼 — 테스트/디버그용.
func advance_stage() -> bool:
	var nxt := _stage_by_index(region_number() + 1)
	return set_stage_to(nxt.id) if nxt != null else false


# ─── 트링켓 (빌드를 망가뜨리는 장신구) ───

func _load_trinket_catalog() -> void:
	trinket_catalog.clear()
	var dir := DirAccess.open(TRINKET_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		var fname := file.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var t: TrinketData = load(TRINKET_DIR + "/" + fname)
		if t:
			trinket_catalog[t.id] = t


## 트링켓 슬롯 수 (trk_unlock/slot_2/slot_3).
func trinket_slots() -> int:
	return int(stat("trinket_slots"))


## 트링켓을 처음 발견 → 도감(owned)에 등록. 빈 슬롯이 있으면 자동 장착. 새로 발견했으면 true.
func discover_trinket(id: StringName) -> bool:
	if not trinket_catalog.has(id) or id in owned_trinkets:
		return false
	owned_trinkets.append(id)
	recalculate_stats() # 슬롯 자동 채움 + 효과 반영
	EventBus.show_toast.emit(Locale.t("장신구 발견: %s") % Locale.t(trinket_catalog[id].display_name))
	return true


## 저주 트링켓은 trk_cursed 해금 전엔 드랍 풀에서 빠진다.
func _trinket_drop_pool() -> Array[StringName]:
	var pool: Array[StringName] = []
	for id: StringName in trinket_catalog:
		var t: TrinketData = trinket_catalog[id]
		if t.cursed and not bool(stat("cursed_trinkets_enabled")):
			continue
		if t.pool == &"pot" and not bool(stat("pot_trinket_pool_enabled")):
			continue # 항아리 풀은 trk_pot_pool 해금 후
		if id not in owned_trinkets:
			pool.append(id)
	return pool


## 적 처치 시 트링켓 드랍 시도 (희귀 확률은 rare_trinket_chance가 가산).
func try_drop_trinket() -> void:
	if not bool(stat("trinkets_enabled")):
		return
	var chance := float(stat("trinket_drop_chance")) + float(stat("rare_trinket_chance"))
	if chance <= 0.0 or randf() >= chance * item_find_mult():
		return
	var pool := _trinket_drop_pool()
	if not pool.is_empty():
		discover_trinket(pool[randi() % pool.size()])


## 슬롯 수에 맞춰 owned에서 장착분을 채운다(부족하면 채우고, 슬롯이 줄면 잘라낸다).
func _autofill_trinket_slots() -> void:
	var slots := trinket_slots()
	equipped_trinkets = equipped_trinkets.filter(func(id: StringName) -> bool: return id in owned_trinkets)
	if equipped_trinkets.size() > slots:
		equipped_trinkets.resize(slots)
	for id: StringName in owned_trinkets:
		if equipped_trinkets.size() >= slots:
			break
		if id not in equipped_trinkets:
			equipped_trinkets.append(id)


## 세트 효과(trk_tags): 장착 트링켓 중 같은 태그가 2개 이상이면 태그당 파티 피해 ×1.1.
func _apply_trinket_sets() -> void:
	var tag_counts := {}
	for tid: StringName in equipped_trinkets:
		var trk: TrinketData = trinket_catalog.get(tid)
		if trk == null:
			continue
		for tag: StringName in trk.tags:
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
	for tag: StringName in tag_counts:
		if int(tag_counts[tag]) >= 2:
			stats["party_damage_mult"] = float(stats["party_damage_mult"]) * 1.1


## 구 세이브(지역 id "region1"/"region2") → 단계 id 마이그레이션.
func _migrate_stage_id(id: StringName) -> StringName:
	match id:
		&"region1": return &"stage_meadow"
		&"region2": return &"stage_forest"
	# 이미 stage_* 이거나, 카탈로그에 있으면 그대로. 없으면 첫 단계로.
	for s: StageData in stage_catalog:
		if s.id == id:
			return id
	return stage_catalog[0].id if not stage_catalog.is_empty() else &"stage_meadow"


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
		# 새 스펙 가지(core/village/command/trinket/bridge/infinite)는 레거시 axis 목록에서 제외.
		# 레거시 노드(branch 미설정="combat")만 남는다. 라이브 트리는 tree_upgrades를 쓴다.
		if upgrade.branch in ["core", "village", "command", "trinket", "bridge", "infinite"]:
			continue
		if upgrade.axis == axis and upgrade.min_region <= region:
			if upgrade.requires_shovel and not has_shovel:
				continue # 삽이 없으면 좋은 삽/꼬마돼지는 아직 숨긴다
			if upgrade.requires_flag != &"" and not get(upgrade.requires_flag):
				continue # 해금 전 증설/속도 업글은 숨긴다 (항아리/보물상자/모닥불)
			list.append(upgrade)
	list.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.base_cost < b.base_cost)
	return list


func owned_count(upgrade: UpgradeData) -> int:
	return purchases.get(upgrade.id, 0)


# ─── 패시브 트리(상점) ───
const TREE_CORE := &"core"

## 현재 지역에 노출되는 모든 노드(잠긴 것 포함 — 트리는 숨기지 않고 회색으로 보여준다).
func tree_upgrades() -> Array[UpgradeData]:
	var list: Array[UpgradeData] = []
	var region := region_number()
	for upgrade: UpgradeData in catalog.values():
		if upgrade.min_region <= region:
			list.append(upgrade)
	return list


func upgrade_by_id(id: StringName) -> UpgradeData:
	return catalog.get(id)


## 노드가 "할당됨"(트리 경로상 활성)인가 — 한 번이라도 샀으면 활성. 허브(core)는 항상 활성.
func node_allocated(id: StringName) -> bool:
	if id == TREE_CORE:
		return true
	var up: UpgradeData = catalog.get(id)
	return up != null and owned_count(up) >= 1


## 경로 잠금 해제 여부.
## 기본: 연결된 선행 중 하나라도 할당되면 OK. requires_all(교차 노드): 전부 할당돼야 OK.
func node_unlocked(upgrade: UpgradeData) -> bool:
	if upgrade.tree_links.is_empty():
		return true # 링크 미설정 노드는 잠그지 않음(안전장치)
	if upgrade.requires_all:
		for link: StringName in upgrade.tree_links:
			if not node_allocated(link):
				return false
		return true
	for link: StringName in upgrade.tree_links:
		if node_allocated(link):
			return true
	return false


func current_cost(upgrade: UpgradeData) -> int:
	var raw := upgrade.base_cost * pow(upgrade.cost_growth, owned_count(upgrade))
	return maxi(0, int(round(raw * float(stats.get("upgrade_cost_mult", 1.0)))))


func purchase(upgrade: UpgradeData) -> bool:
	if owned_count(upgrade) >= upgrade.max_purchases:
		return false
	var cost := current_cost(upgrade)
	if gold < cost:
		return false
	gold -= cost
	EventBus.gold_changed.emit(gold)
	purchases[upgrade.id] = owned_count(upgrade) + 1
	last_purchase_time = play_time
	if upgrade.id == &"cmb_atk_1" and first_sword_time < 0.0:
		first_sword_time = play_time # 첫 전투 업글 시점 (촌장 이벤트 타이밍)
	recalculate_stats()
	# core 스파인의 지역 노드: 사는 즉시 그 지역을 연다 (set_stage 효과 = 행동)
	if upgrade.effects.has("set_stage"):
		set_stage_to(StringName(upgrade.effects["set_stage"]))
	# 지휘 트리 동료 영입 (recruit 효과 = 행동) — 이미 합류했으면 무시
	if upgrade.effects.has("recruit"):
		var comp: CompanionData = companion_catalog.get(StringName(upgrade.effects["recruit"]))
		if comp:
			add_companion(comp)
	# 트링켓 발견 (trk_unlock의 스타터 3개 등) — discover_trinkets 효과 = 행동
	if upgrade.effects.has("discover_trinkets"):
		for tid: Variant in upgrade.effects["discover_trinkets"]:
			discover_trinket(StringName(tid))
	EventBus.upgrade_purchased.emit(upgrade)
	return true


# ─── 골드 ───

## source: &"combat" / &"village" / &"boss" / &"" (기타). 디버그 GPM 출처 분류용.
func add_gold(amount: int, source: StringName = &"") -> void:
	gold += amount
	if amount > 0:
		total_gold_earned += amount
		_record_gold_event(amount, source)
	EventBus.gold_changed.emit(gold)


## 골드 획득을 60s 윈도우에 기록(디버그 GPM). 윈도우 밖은 즉시 폐기해 배열을 작게 유지.
func _record_gold_event(amount: int, source: StringName) -> void:
	_gold_events.append({"t": play_time, "amt": amount, "src": source})
	var cutoff := play_time - _GPM_WINDOW
	while not _gold_events.is_empty() and _gold_events[0]["t"] < cutoff:
		_gold_events.pop_front()


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
	var find := item_find_mult() # 운 = 아이템 발견 확률↑
	if data.stone_drop > 0.0 and randf() < data.stone_drop * find:
		add_material(&"stone", 1)
	if data.sword_drop > 0.0 and randf() < data.sword_drop * find:
		rusty_swords += 1
		EventBus.materials_changed.emit()
		EventBus.show_toast.emit(Locale.t("%s가 녹슨 검을 떨어뜨렸다!") % Locale.t(data.display_name))
	try_drop_trinket() # 트링켓 드랍 (trk_drop_slime/rare_chance — 해금 전엔 무효)


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


## 외부(영입 NPC 등)에서 동료 보유 여부 확인.
func has_companion(id: StringName) -> bool:
	return _has_companion(id)


## 전투창 좌측 슬롯 표시용: 용사 + 동료 순서
func party_members() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"name": config.hero_name, "sprite": config.hero_sprite})
	for c in companions:
		list.append({"name": c.display_name, "sprite": c.sprite})
	return list


func member_count() -> int:
	return 1 + companions.size()


## 멤버별 단독 공격력 (용사, 동료1, 동료2 ...). 합 = party_attack.
## 동료 = 보너스 × 파티 피해 배율, 용사 = party_attack - 동료합 (= 배율 적용된 hero_attack).
## party_attack에서 파생하므로 테스트가 party_attack을 직접 세팅해도 용사 화력이 따라온다.
func member_attacks() -> Array[int]:
	var pdm := float(stats.get("party_damage_mult", 1.0))
	var comp_attacks: Array[int] = []
	var comp_total := 0
	for c in companions:
		var ca := int(round(c.attack_bonus * pdm))
		comp_attacks.append(ca)
		comp_total += ca
	var arr: Array[int] = [maxi(0, party_attack - comp_total)]
	arr.append_array(comp_attacks)
	return arr


## 멤버별 운 (용사, 동료1, ...). 파티 운은 이 중 최고값(party_luck).
func member_lucks() -> Array[int]:
	var arr: Array[int] = [hero_luck]
	for c in companions:
		arr.append(c.luck)
	return arr


## 발견 골드 배수 (운이 높을수록 ↑). 항아리·상자·땅파기·전투 골드에 적용.
func gold_find_mult() -> float:
	return 1.0 + party_luck * config.luck_gold_per


## 아이템/드롭 발견 확률 배수 (운이 높을수록 ↑). 몬스터 드롭 등에 적용.
func item_find_mult() -> float:
	return 1.0 + party_luck * config.luck_find_per


## 제너릭 스탯 접근자 (없으면 기본값). 외부에서 stats[...] 직접 접근 대신 이걸 권장.
func stat(key: String) -> Variant:
	if stats.has(key):
		return stats[key]
	if _STAT_MULT.has(key): return _STAT_MULT[key]
	if _STAT_ADD.has(key): return _STAT_ADD[key]
	if _STAT_BOOL.has(key): return _STAT_BOOL[key]
	return null


## 전투 골드 총배율 = 운(발견) × 적 골드 배율 × 전체 골드 배율. (보스는 boss_gold_mult 추가 곱)
func combat_gold_mult(is_boss: bool = false) -> float:
	var m := gold_find_mult() * float(stat("enemy_gold_mult")) * float(stat("all_gold_mult"))
	if is_boss:
		m *= float(stat("boss_gold_mult"))
	return m


## 마을(항아리·상자·땅파기) 골드 총배율 = 운 × 마을 골드 배율 × 전체 골드 배율.
func village_gold_mult() -> float:
	return gold_find_mult() * float(stat("village_gold_mult")) * float(stat("all_gold_mult"))


## 디버그 패널용 — 골드/분(출처별), 마지막 구매 후 경과, 현재 구매가능 노드 수.
func debug_stats() -> Dictionary:
	var cutoff := play_time - _GPM_WINDOW
	var span := minf(_GPM_WINDOW, maxf(1.0, play_time)) # 플레이 60s 미만이면 실제 경과로 나눔
	var sums := {&"combat": 0, &"village": 0, &"boss": 0, &"": 0}
	for ev: Dictionary in _gold_events:
		if ev["t"] >= cutoff:
			var s: StringName = ev["src"]
			sums[s] = int(sums.get(s, 0)) + int(ev["amt"])
	var per := 60.0 / span
	var buyable := 0
	for up: UpgradeData in catalog.values():
		if up.min_region <= region_number() and node_unlocked(up) \
				and owned_count(up) < up.max_purchases and gold >= current_cost(up):
			buyable += 1
	var total_gpm := 0.0
	for k in sums:
		total_gpm += float(sums[k]) * per
	return {
		"gpm": int(round(total_gpm)),
		"gpm_combat": int(round(sums[&"combat"] * per)),
		"gpm_village": int(round(sums[&"village"] * per)),
		"gpm_boss": int(round(sums[&"boss"] * per)),
		"since_purchase": play_time - last_purchase_time,
		"buyable": buyable,
	}


# ─── 멤버별 개별 HP (각자 자기 HP) ───

## index번째 멤버의 최대 HP (0=용사=config, 1+=동료=CompanionData.max_hp).
func member_max_hp_for(index: int) -> int:
	if index == 0:
		return config.hero_max_hp + int(stat("hero_max_hp")) # cmb_hp_* 보너스
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


## 가장 다친(비율 최저) 살아있는 멤버 1명 회복 (승려/모닥불). 회복한 멤버 인덱스 반환(-1=없음).
func heal_lowest(amount: int) -> int:
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
	return target


## 모닥불 회복 1틱 간격(초). 속도 업글마다 짧아진다(하한 적용).
func bonfire_interval() -> float:
	return maxf(config.bonfire_min_interval,
		config.bonfire_base_interval - bonfire_speed_lv * config.bonfire_interval_per_level)


## 모닥불 회복 반경(px). 범위 업글마다 넓어진다 (나중엔 맵 전체까지).
func bonfire_radius() -> float:
	return config.bonfire_base_radius + bonfire_range_lv * config.bonfire_radius_per_level


## 모닥불 1틱 회복량(HP). 회복량 업글마다 커진다.
func bonfire_heal_amount() -> int:
	return config.bonfire_heal + bonfire_heal_lv


## 모닥불 회복 1틱: 가장 다친 멤버를 bonfire_heal_amount()만큼 회복. 회복한 멤버 인덱스(-1=없음).
func bonfire_heal_tick() -> int:
	if not damage_enabled or total_hp() <= 0 or total_hp() >= total_max_hp():
		return -1
	return heal_lowest(bonfire_heal_amount())


func full_heal() -> void:
	for i in member_hps.size():
		member_hps[i] = member_max_hps[i]
	_retreat_active = false
	EventBus.party_hp_changed.emit()


## 여관 숙박료 = 소지금의 일정 비율 (하한 적용). 부유할수록 비싸진다.
func inn_cost() -> int:
	return maxi(config.inn_min_cost, int(floor(gold * config.inn_cost_ratio)))


## 여관에서 잔다: 숙박료 지불 → 전량 회복. 성공 시 true.
func inn_sleep() -> bool:
	if total_hp() >= total_max_hp():
		return false # 이미 가득
	var cost := inn_cost()
	if not try_spend(cost):
		return false
	full_heal()
	EventBus.inn_rested.emit()
	return true


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
	return Locale.t(MAT_NAMES.get(id, String(id))) # 현재 언어로 (ko면 그대로 한글)


# ─── 항아리 (쿨타임마다 랜덤 보상) ───

## 인덱스별 쿨타임 배열을 현재 갯수에 맞춘다 (늘어난 칸은 0=준비됨).
func _ensure_town_arrays() -> void:
	while pot_ready_ats.size() < pot_count:
		pot_ready_ats.append(0.0)
	while chest_ready_ats.size() < chest_count:
		chest_ready_ats.append(0.0)


## 항아리 복구 시간(초). 복구 속도 업글(레거시 lv) + pot_respawn_mult(vlg) 둘 다 적용.
func pot_cooldown_now() -> float:
	return config.pot_cooldown * pow(config.pot_cooldown_mult_per_level, pot_cooldown_lv) \
		* float(stat("pot_respawn_mult"))


func pot_ready(i: int = 0) -> bool:
	return i >= 0 and i < pot_ready_ats.size() and play_time >= pot_ready_ats[i]


func pot_remaining(i: int = 0) -> float:
	if i < 0 or i >= pot_ready_ats.size():
		return 0.0
	return maxf(0.0, pot_ready_ats[i] - play_time)


## 항아리 i를 깬다. 준비됐으면 보상 토스트 문자열 반환, 아니면 "".
func break_pot(i: int = 0) -> String:
	if not pot_ready(i):
		return ""
	# 항아리 골드: 기본 +pot_base_gold, ×pot_gold_mult (vlg_pot_gold_1·big_pot·chain·kingdom)
	var msg := _grant(_roll_pot(), int(stat("pot_base_gold")), float(stat("pot_gold_mult")))
	pot_ready_ats[i] = play_time + pot_cooldown_now()
	EventBus.pot_changed.emit()
	return msg


func _roll_pot() -> Dictionary:
	return _weighted_pick([
		{"w": 6.0, "type": "nothing", "lf": -1.0},                       # 꽝 — 운 높으면 확 줄어든다
		{"w": 5.0, "type": "gold", "min": 1, "max": 6},
		{"w": 4.0, "type": "mat", "id": &"stone", "n": 1},
		{"w": 3.0, "type": "mat", "id": &"herb", "n": 1, "lf": 0.4},
		{"w": 2.0, "type": "mat", "id": &"pot_shard", "n": 1, "lf": 0.7},
		{"w": 1.0, "type": "mat", "id": &"wood_key", "n": 1, "lf": 1.0},  # 보물상자 열쇠
		{"w": 0.5, "type": "mat", "id": &"medal_shard", "n": 1, "lf": 1.5}, # 희귀 — 운 높으면 잘 나온다
	])


# ─── 보물상자 ───

## 보물상자 복구 시간(초). 복구 속도 업글마다 짧아진다.
func chest_cooldown_now() -> float:
	return config.chest_cooldown * pow(config.chest_cooldown_mult_per_level, chest_cooldown_lv)


func chest_ready(i: int = 0) -> bool:
	return i >= 0 and i < chest_ready_ats.size() and play_time >= chest_ready_ats[i]


func chest_remaining(i: int = 0) -> float:
	if i < 0 or i >= chest_ready_ats.size():
		return 0.0
	return maxf(0.0, chest_ready_ats[i] - play_time)


## 열쇠 시스템 해금 후엔 지정된 열쇠가 필요하다 (중반).
func chest_needs_key() -> bool:
	return chest_keys_unlocked and chest_required_key != &""


func chest_can_open(i: int = 0) -> bool:
	if not chest_ready(i):
		return false
	return not chest_needs_key() or material_count(chest_required_key) > 0


func open_chest(i: int = 0) -> String:
	if not chest_can_open(i):
		return ""
	if chest_needs_key():
		spend_material(chest_required_key, 1)
	var msg := _grant(_roll_chest())
	chest_ready_ats[i] = play_time + chest_cooldown_now()
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
		{"w": 3.0, "type": "sword", "n": 1, "lf": 0.5},
		{"w": 3.0, "type": "mat", "id": &"enhance_stone", "n": 1, "lf": 0.6},
		{"w": 3.0, "type": "mat", "id": &"stone", "n": 2},
		{"w": 0.7, "type": "mat", "id": &"medal_shard", "n": 1, "lf": 1.5},
	])


## 가중치 추첨. 운(party_luck)이 높으면 "lf" 키로 좋은 항목↑·꽝/잡템↓ 으로 편향된다.
## 항목에 "lf" (luck factor): +면 운 높을수록 잘 나오고, -면 운 높을수록 덜 나온다.
func _weighted_pick(table: Array) -> Dictionary:
	var weights: Array[float] = []
	var total := 0.0
	for e in table:
		var lf: float = float(e.get("lf", 0.0))
		var w: float = maxf(0.05, float(e.w) * (1.0 + lf * party_luck * config.luck_drop_weight_per))
		weights.append(w)
		total += w
	var r := randf() * total
	for i in table.size():
		r -= weights[i]
		if r <= 0.0:
			return table[i]
	return table[table.size() - 1]


## 보상 적용 + 토스트용 문자열 반환
## gold_add/gold_mult: 출처별 골드 보정 (항아리는 pot_base_gold/pot_gold_mult를 넘긴다).
func _grant(e: Dictionary, gold_add: int = 0, gold_mult: float = 1.0) -> String:
	match e.type:
		"nothing":
			return Locale.t("꽝...")
		"gold":
			var raw := (randi_range(int(e["min"]), int(e["max"])) + gold_add) * gold_mult
			var g := int(round(raw * village_gold_mult())) # 운·마을 골드 배율
			add_gold(g, &"village")
			return Locale.t("골드 +%d") % g
		"mat":
			add_material(e.id, int(e.n))
			return Locale.t("%s +%d") % [material_name(e.id), int(e.n)]
		"sword":
			rusty_swords += int(e.n)
			EventBus.materials_changed.emit()
			return Locale.t("녹슨 검 +%d") % int(e.n)
		"gem":
			add_gems(int(e.n))
			return Locale.t("보석 +%d") % int(e.n)
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

## 제너릭 스탯을 기본값으로 초기화 (recalculate_stats 시작 시).
func _init_generic_stats() -> void:
	stats = {}
	for k: String in _STAT_MULT: stats[k] = _STAT_MULT[k]
	for k: String in _STAT_ADD: stats[k] = _STAT_ADD[k]
	for k: String in _STAT_BOOL: stats[k] = _STAT_BOOL[k]


## effects의 키를 제너릭 스탯 분류에 따라 적용. 처리했으면 true, 모르는 키면 false(레거시 경고).
func _apply_generic_stat(key: String, value: Variant, count: int) -> bool:
	if key in _ACTION_KEYS:
		return true # 행동 키(set_stage 등)는 스탯이 아니므로 recalc에선 무시 (purchase가 처리)
	if _STAT_MULT.has(key):
		stats[key] = float(stats[key]) * pow(float(value), count)
		return true
	if _STAT_ADD.has(key):
		stats[key] = stats[key] + value * count
		return true
	if _STAT_BOOL.has(key):
		if bool(value):
			stats[key] = true
		return true
	return false


func recalculate_stats() -> void:
	party_attack = config.base_party_attack
	turn_interval = config.base_turn_interval
	move_speed = config.base_move_speed
	respawn_delay_mult = 1.0
	spawn_count_bonus = 0
	max_battle_windows = config.initial_max_battle_windows + elder_window_bonus
	auto_hunt_unlocked = false
	crit_chance = config.base_crit_chance
	damage_reduction_mult = 1.0
	all_attack = false
	remote_shop_unlocked = false
	has_shovel = false
	has_pig_companion = false
	pot_unlocked = false
	chest_unlocked = false
	pot_count = 0
	chest_count = 0
	pot_cooldown_lv = 0
	chest_cooldown_lv = 0
	inn_unlocked = false
	bonfire_unlocked = false
	bonfire_speed_lv = 0
	bonfire_range_lv = 0
	bonfire_heal_lv = 0
	var dig_levels := 0
	var hero_luck_acc := config.hero_base_luck
	group_table = [1.0]
	_init_generic_stats()
	for id: StringName in purchases:
		var upgrade: UpgradeData = catalog.get(id)
		if upgrade == null:
			continue
		var count: int = purchases[id]
		for key: String in upgrade.effects:
			var value: Variant = upgrade.effects[key]
			match key:
				"party_attack", "hero_attack":
					party_attack += int(value) * count # 용사 평타 가산 (cmb_atk_*)
				"crit_bonus":
					crit_chance += float(value) * count # 회심 확률 가산 (cmb_crit)
				"turn_interval_mult":
					turn_interval *= pow(float(value), count)
				"move_speed_mult":
					move_speed *= pow(float(value), count)
				"respawn_delay_mult":
					respawn_delay_mult *= pow(float(value), count)
				"spawn_count":
					spawn_count_bonus += int(value) * count # 존당 몬스터 +α (몹 바글바글)
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
				"pot_unlock":
					pot_unlocked = bool(value)                      # 항아리 설치
				"pot_count":
					pot_count += int(value) * count                 # 항아리 증설
				"pot_cooldown_lv":
					pot_cooldown_lv += count                        # 항아리 복구 속도
				"auto_pot":
					if bool(value): auto_pot = true                 # 항아리꾼 고용 (자동 깨기) — 끄지 않음
				"chest_unlock":
					chest_unlocked = bool(value)                    # 보물상자 설치
				"chest_count":
					chest_count += int(value) * count               # 보물상자 증설
				"chest_cooldown_lv":
					chest_cooldown_lv += count                      # 보물상자 복구 속도
				"inn_unlock":
					inn_unlocked = bool(value)                      # 여관 설치
				"bonfire":
					bonfire_unlocked = bool(value)                  # 모닥불 설치
				"bonfire_speed":
					bonfire_speed_lv += count                       # 회복 속도
				"bonfire_range":
					bonfire_range_lv += count                       # 회복 범위
				"bonfire_heal":
					bonfire_heal_lv += count                        # 회복량
				"luck":
					hero_luck_acc += int(value) * count             # 용사 운 (행운 부적)
				_:
					if not _apply_generic_stat(key, value, count):
						push_warning("알 수 없는 효과 키: %s (%s)" % [key, upgrade.id])
	# ─── 장착 트링켓 효과 (업그레이드와 같은 제너릭 스탯 키로 가산) ───
	_autofill_trinket_slots()
	for tid: StringName in equipped_trinkets:
		var trk: TrinketData = trinket_catalog.get(tid)
		if trk == null:
			continue
		for tkey: String in trk.effects:
			_apply_generic_stat(tkey, trk.effects[tkey], 1)
	if bool(stats["trinket_sets_enabled"]):
		_apply_trinket_sets() # 같은 태그 2개+ → 세트 보너스
	if bool(stats["trinket_collection_bonus"]):
		# 수집벽: 발견 트링켓 1개당 모든 골드 +1%, 최대 +50%
		stats["all_gold_mult"] = float(stats["all_gold_mult"]) * (1.0 + minf(0.5, owned_trinkets.size() * 0.01))
	# 갯수 = 해금 시 기본 1 + 증설, 잠금 시 0. 인덱스별 쿨타임 배열을 갯수에 맞춘다.
	pot_count = (pot_count + 1) if pot_unlocked else 0
	chest_count = (chest_count + 1) if chest_unlocked else 0
	_ensure_town_arrays()
	if equipped_sword_level >= 0: # 장착한 강화검 — 용사가 든다
		party_attack += equipped_sword_level * config.sword_attack_per_level
	# 여기까지 party_attack = 용사 단독 raw(기본 + 평타 업글 + 장착검). 파티 피해 배율을 곱한다.
	var pdm := float(stats["party_damage_mult"]) # cmb_legend_sword 등 (기본 1.0 = 무변화)
	hero_attack = int(round(party_attack * pdm)) # 용사 최종 공격력 (동료 제외)
	party_attack = hero_attack
	for c in companions: # 동료 기여도 같은 배율로 (용사 + 동료 = 파티 총합)
		party_attack += int(round(c.attack_bonus * pdm))
	# 운: 파티 운 = 멤버 중 최고값. 회심 확률에 운을 더한다.
	hero_luck = hero_luck_acc
	party_luck = hero_luck
	for c in companions:
		party_luck = maxi(party_luck, c.luck)
	crit_chance += party_luck * config.luck_crit_per
	# 땅파기 쿨타임: 좋은 삽 단계당 감소, 하한 적용
	dig_cooldown = maxf(config.dig_min_cooldown,
		config.dig_base_cooldown - dig_levels * config.dig_cooldown_per_level)
	# ─── 제너릭 스탯 → 레거시 변수 파생 (기본값이면 무변화) ───
	turn_interval /= maxf(0.05, float(stats["attack_speed_mult"]))     # 공격속도 ↑ → 라운드 ↓
	max_battle_windows += int(stats["combat_slots"]) - 1               # 추가 전투슬롯
	if not member_max_hps.is_empty(): # 용사 최대 HP 업글(cmb_hp_*) 반영 — 현재 HP는 보존
		_ensure_member_hp()
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
	damage_enabled = true
	tactic_retreat_unlocked = false
	tactic_retreat_enabled = false
	current_region = &"stage_meadow"
	active_quest_id = &""
	quest_progress_base = 0
	_retreat_active = false
	_heal_accum = 0.0
	# 마을 오브젝트
	gems = 0
	materials.clear()
	rusty_swords = 0
	forge_level = -1
	equipped_sword_level = -1
	pot_ready_ats.clear()
	chest_ready_ats.clear()
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
	auto_move_on = false
	owned_trinkets.clear()
	equipped_trinkets.clear()
	last_purchase_time = 0.0
	_gold_events.clear()
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
		"hunt_list": _hunt_list_out(),
		"tactic_retreat_unlocked": tactic_retreat_unlocked,
		"tactic_retreat_enabled": tactic_retreat_enabled,
		"gems": gems,
		"materials": _materials_out(),
		"rusty_swords": rusty_swords,
		"forge_level": forge_level,
		"equipped_sword_level": equipped_sword_level,
		"pot_ready_ats": pot_ready_ats.duplicate(),
		"chest_ready_ats": chest_ready_ats.duplicate(),
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
		"language": language,
		"auto_move_on": auto_move_on,
		"owned_trinkets": owned_trinkets.map(func(s: StringName) -> String: return String(s)),
		"equipped_trinkets": equipped_trinkets.map(func(s: StringName) -> String: return String(s)),
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
	damage_enabled = true # 이제 1지역부터 항상 데미지 ON (구 세이브의 false 무시)
	current_region = _migrate_stage_id(StringName(data.get("current_region", "stage_meadow")))
	active_quest_id = StringName(data.get("active_quest_id", ""))
	quest_progress_base = int(data.get("quest_progress_base", 0))
	tactic_retreat_unlocked = bool(data.get("tactic_retreat_unlocked", false))
	tactic_retreat_enabled = bool(data.get("tactic_retreat_enabled", false))
	gems = int(data.get("gems", 0))
	rusty_swords = int(data.get("rusty_swords", 0))
	forge_level = int(data.get("forge_level", -1))
	equipped_sword_level = int(data.get("equipped_sword_level", -1))
	pot_ready_ats.clear()
	for v in data.get("pot_ready_ats", []):
		pot_ready_ats.append(float(v))
	chest_ready_ats.clear()
	for v in data.get("chest_ready_ats", []):
		chest_ready_ats.append(float(v))
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
	language = String(data.get("language", "ko"))
	auto_move_on = bool(data.get("auto_move_on", false))
	owned_trinkets.clear()
	for t: Variant in data.get("owned_trinkets", []):
		owned_trinkets.append(StringName(t))
	equipped_trinkets.clear()
	for t: Variant in data.get("equipped_trinkets", []):
		equipped_trinkets.append(StringName(t))
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
