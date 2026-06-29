class_name EncounterFormationDef extends Resource
## 인카운터 포메이션 1종 — 전투창에 나오는 적 "무리"의 구성.
## 적 1마리가 아니라 고전 JRPG처럼 여러 종이 섞여 나온다 (1~6마리).

@export var id: StringName
@export var display_name: String
@export var region_id: StringName            # 이 지역(stage)에서만 등장
## 적 슬롯: 각 원소 = {"enemy_id": &"slime", "count_min": 1, "count_max": 2}
@export var enemy_slots: Array = []
@export var spawn_weight: float = 1.0        # 가중 추첨 비중
@export var unlock: Dictionary = {}          # 해금 조건 (비면 시작부터). region_kills/survey/discovered/monster_kills/requires_flag
@export var reward_mult: float = 1.0         # 이 포메이션 보상 배율
@export var survey_reward: float = 0.0       # 전멸 시 지역 조사도 +이만큼 (0~1)
@export var tags: Array[StringName] = []
@export var is_boss: bool = false
@export var is_rare: bool = false
