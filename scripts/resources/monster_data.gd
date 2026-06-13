class_name MonsterData extends Resource
## 몬스터 1종의 모든 데이터. 몬스터별 씬을 만들지 않고 이 .tres로 표현한다.

@export var id: StringName
@export var display_name: String
@export var sprite: Texture2D
@export var max_hp: int = 1
@export var attack: int = 0
@export var defense: int = 0                 # 데미지 = max(attack - defense, 0). 회심은 방어 무시 (v3 §1)
@export var gold_reward: int = 0
@export var exp_reward: int = 0
@export var move_speed: float = 30.0        # 필드 위 배회 속도 (px/s)
@export var erratic_movement: bool = false  # 박쥐용: 불규칙 이동
# ─── 메탈류 (v3 §2): 전투 중 도주 ───
@export var flee_after_hits: int = 0        # 피격 N회 시 전투 도주 (0이면 도주 안 함)
@export var flee_after_seconds: float = 0.0 # 전투 시작 N초 경과 시 도주 (0이면 시간 도주 없음)
@export var allow_group: bool = true        # 무리 출현 허용 (메탈은 false → 항상 1마리, v3 §4)
@export var hunt_default: bool = true       # 사냥 허가 기본값 (오크처럼 위협적이면 false, v3 §8)
