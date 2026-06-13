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
@export var base_vision_zoom: float = 1.0   # 카메라 기본 줌 (작을수록 넓게 보임)
@export var base_crit_chance: float = 0.02  # 회심의 일격 확률 (방어 무시, v3 §1)
@export var elite_vision_zoom: float = 0.85 # 정예존 해금 보상 시야 (v3 §6)
@export var quest_vision_zoom: float = 0.7  # 2지역 의뢰 보상 시야 (v3 §6)

@export_group("Elder Events")
@export var elder_battles_threshold: int = 15        # 누적 전투 N회
@export var elder_seconds_after_sword: float = 300.0 # 또는 동검 구매 후 N초
@export var elder_second_gold_threshold: int = 250   # 2단계: 보유 골드

@export_group("Metal Slime")
@export var metal_slime_unlock_gold_earned: int = 300 # 누적 획득 골드 도달 시 등장 시작

@export_group("Save")
@export var autosave_interval: float = 30.0
