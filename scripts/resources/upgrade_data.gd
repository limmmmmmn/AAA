class_name UpgradeData extends Resource
## 상점 업그레이드 1종. 효과는 effects Dictionary로 선언하고
## GameState.recalculate_stats()만이 해석한다.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export_enum("combat", "field") var axis: String = "combat" # 상점 윗줄/아랫줄
@export var min_region: int = 1   # 이 지역 번호 이상에서만 상점에 노출 (1지역=1, 2지역=2)
@export var requires_shovel: bool = false # 삽 보유 시에만 상점에 노출 (좋은 삽/꼬마돼지)
@export var base_cost: int = 10
@export var cost_growth: float = 1.0   # 반복 구매형이면 >1.0
@export var max_purchases: int = 1
## 지원 키: party_attack(+int), turn_interval_mult(×float), move_speed_mult(×float),
##          respawn_delay_mult(×float), max_battle_windows(+int), auto_hunt(bool)
@export var effects: Dictionary
