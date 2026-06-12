class_name QuestData extends Resource
## 의뢰 게시판 1건 (B-4). 1지역의 kill_count 시스템을 재사용한다 (수주 시점 이후 카운트).

@export var id: StringName
@export var description: String          # "독사 10마리 토벌"
@export var target_monster: StringName
@export var target_count: int = 1
@export var reward_gold: int = 0
@export var reward_unlock: StringName    # 비우면 골드만. 추후 동료/기능 해금 슬롯
