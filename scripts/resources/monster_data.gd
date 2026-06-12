class_name MonsterData extends Resource
## 몬스터 1종의 모든 데이터. 몬스터별 씬을 만들지 않고 이 .tres로 표현한다.

@export var id: StringName
@export var display_name: String
@export var sprite: Texture2D
@export var max_hp: int = 1
@export var attack: int = 0
@export var gold_reward: int = 0
@export var exp_reward: int = 0
@export var move_speed: float = 30.0        # 필드 위 배회 속도 (px/s)
@export var erratic_movement: bool = false  # 박쥐용: 불규칙 이동
@export var flees_after_sec: float = 0.0    # 메탈슬라임용: 0이면 도주 안 함
