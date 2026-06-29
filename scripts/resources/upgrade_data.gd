class_name UpgradeData extends Resource
## 상점 업그레이드 1종. 효과는 effects Dictionary로 선언하고
## GameState.recalculate_stats()만이 해석한다.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export_enum("combat", "field") var axis: String = "combat" # 상점 윗줄/아랫줄 (레거시 — 테스트용)
## v0.1 트리 — 가지(브랜치)와 노드 종류. 트리 UI 모양/색·등장 위치 분류에 쓴다.
## branch: core(중앙척추)·combat·village·command·trinket·bridge(교차)·infinite(반복)
## node_type: 노드 모양 — stat(원형)·unlock(사각)·automation·boss/region(왕관)·trinket(보라)·bridge(다이아)·repeatable(톱니)
@export_enum("core", "combat", "village", "command", "trinket", "bridge", "infinite") var branch: String = "combat"
@export_enum("stat", "unlock", "automation", "boss", "region", "trinket", "bridge", "repeatable") var node_type: String = "stat"
@export var min_region: int = 1   # 이 지역 번호 이상에서만 상점에 노출 (1지역=1, 2지역=2)
@export var requires_shovel: bool = false # 삽 보유 시에만 상점에 노출 (좋은 삽/꼬마돼지)
@export var requires_flag: StringName = &"" # 이 GameState bool 플래그가 true일 때만 노출 (예: &"pot_unlocked")
@export var base_cost: int = 10
@export var cost_growth: float = 1.0   # 반복 구매형이면 >1.0
@export var max_purchases: int = 1
## ─ 패시브 노드 트리(상점) ─ 그리드 좌표와 선행 노드.
## tree_pos: 허브(0,0) 기준 그리드 칸. tree_links: 연결된 선행 노드 id들(&"core"=중앙 허브).
## 경로 잠금: tree_links 중 하나라도 보유(허브 포함)해야 구매 가능(shop_ui가 강제).
@export var tree_pos: Vector2i = Vector2i.ZERO
@export var tree_links: Array[StringName] = []
## true면 tree_links를 모두 보유해야 해금(교차 노드 brg_* — 두 가지의 시너지). 기본 false=하나라도.
@export var requires_all: bool = false
## 지원 키: party_attack(+int), turn_interval_mult(×float), move_speed_mult(×float),
##          respawn_delay_mult(×float), max_battle_windows(+int), auto_hunt(bool)
@export var effects: Dictionary
