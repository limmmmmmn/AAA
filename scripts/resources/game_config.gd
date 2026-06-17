class_name GameConfig extends Resource
## 밸런스 기본값. 전부 에디터에서 수정 가능해야 한다 (하드코딩 금지 원칙).

@export_group("Hero")
@export var hero_name: String = "용사"
@export var hero_sprite: Texture2D

@export_group("Party Base Stats")
@export var base_party_attack: int = 3   # 용사 기본 공격력 (동료 보너스는 별도 합산)
@export var base_turn_interval: float = 1.2
@export var turn_beat_delay: float = 0.25 # 파티 행동 → 적 행동 사이 텀 (A-2). 텍스트 한 줄 읽는 속도
@export var base_move_speed: float = 80.0
@export var initial_max_battle_windows: int = 1
@export var hero_max_hp: int = 40           # 용사 최대 HP (멤버별 개별 HP)
@export var base_crit_chance: float = 0.02  # 회심의 일격 확률 (방어 무시, v3 §1)

@export_group("Elder Events")
@export var elder_battles_threshold: int = 15        # 누적 전투 N회
@export var elder_seconds_after_sword: float = 300.0 # 또는 동검 구매 후 N초
@export var elder_second_gold_threshold: int = 250   # 2단계: 보유 골드

@export_group("Metal Slime")
@export var metal_slime_unlock_gold_earned: int = 300 # 누적 획득 골드 도달 시 등장 시작

@export_group("Town Objects")
@export var pot_cooldown: float = 30.0          # 항아리 복구 쿨타임(초, play_time 기준)
@export var chest_cooldown: float = 180.0       # 보물상자 복구 쿨타임
@export var sword_max_level: int = 5            # 녹슨 검 최대 강화
@export var sword_sell_gems: int = 1           # +최대 녹슨 검 판매 시 보석
@export var auto_pot_gem_cost: int = 1         # 자동 항아리꾼 보석 가격
@export var auto_enhance_gem_cost: int = 3     # 자동 강화 보석 가격
@export var auto_deliver_gem_cost: int = 5     # 자동 납품 보석 가격
@export var auto_forge_interval: float = 1.5   # 자동 강화/납품 1스텝 간격(초)
@export var sword_attack_per_level: int = 2    # 장착 검: 강화 수치당 파티 공격력
@export var chest_key_unlock_opens: int = 3    # 보물상자를 N번 열면 열쇠 시스템 해금

@export_group("Digging")
@export var dig_base_cooldown: float = 60.0     # 삽 기본 쿨타임(초). 항아리보다 길게
@export var dig_cooldown_per_level: float = 10.0 # 좋은 삽 1단계당 쿨타임 감소
@export var dig_min_cooldown: float = 20.0      # 쿨타임 하한
@export var dig_success_chance: float = 0.15    # 일반 땅 보상 확률 (대부분 꽝)
@export var sparkle_base_chance: float = 0.0    # 반짝이는 땅 기본 생성 확률
@export var wisdom_sparkle_per: float = 0.005   # 지혜 1당 반짝임 확률 +
@export var pig_sparkle_bonus: float = 0.10     # 꼬마돼지 보유 시 반짝임 확률 +

@export_group("Save")
@export var autosave_interval: float = 30.0
