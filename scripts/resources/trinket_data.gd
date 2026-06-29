class_name TrinketData extends Resource
## 트링켓 1종. 장착하면 effects가 GameState.recalculate_stats()에서 스탯에 더해진다
## (업그레이드와 같은 효과 키 사용 — party_damage_mult, pot_gold_mult, enemy_gold_mult ...).
## 빌드를 "망가뜨리는" 장치 — 강한 효과에 패널티가 붙기도 한다(저주/스타터).

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var effects: Dictionary           # 제너릭 스탯 키 → 값 (장착 시 1회 적용)
@export var tags: Array[StringName] = []  # 세트 효과 태그 (trk_tags)
@export var rarity: int = 0               # 0 일반, 1 희귀
@export var cursed: bool = false          # 저주 트링켓 (높은 효과 + 패널티)
@export var pool: StringName = &"common"  # 드랍 풀 (common / pot ...)
## 파티원 슬롯 친화 (R4): 이 역할 멤버에게 장착되면 affinity_bonus가 추가로 적용된다.
## 값: &"hero" / &"warrior" / &"mage" / &"priest" / &"" (없음)
@export var affinity_role: StringName = &""
@export var affinity_bonus: Dictionary = {} # affinity_role 일치 시 추가 효과 (제너릭 스탯 키)
