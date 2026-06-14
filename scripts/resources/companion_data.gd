class_name CompanionData extends Resource
## 동료 1명. 지역 게이트 보상으로 합류한다 (1지역에선 빈 배열).
## 각자 자기 공격력(attack_bonus)·자기 HP(max_hp)를 가진다.

@export var id: StringName
@export var display_name: String
@export var sprite: Texture2D
@export var attack_bonus: int = 0       # 이 동료의 단독 공격력 (업그레이드는 용사만, 동료는 +α)
@export var max_hp: int = 20            # 이 동료의 최대 HP (각자 개별)
@export var role: StringName            # "priest", "warrior" ...
@export var heal_per_turn: int = 0      # priest용: 매 턴 가장 다친 멤버를 회복
