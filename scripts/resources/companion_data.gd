class_name CompanionData extends Resource
## 동료 1명. 지역 게이트 보상으로 합류한다 (1지역에선 빈 배열).
## role/heal_per_turn은 2지역(공유 HP)부터 의미를 가진다.

@export var id: StringName
@export var display_name: String
@export var sprite: Texture2D
@export var attack_bonus: int = 0
@export var role: StringName            # "priest", "warrior" ...
@export var heal_per_turn: int = 0      # priest용: 턴마다 shared_hp 회복
