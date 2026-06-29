class_name StageData extends Resource
## 단계(Stage) 1종. 맵은 1지역 하나로 고정 — 단계가 바뀌면 같은 맵 위에서
## 적의 종류·지역명·분위기(타일 틴트)만 바뀐다. SpawnZone이 role로 몬스터를 받아간다.
## "맵을 새로 그리지 않고 그 위에서 지역을 갈아끼운다"는 설계의 데이터 단위.

@export var id: StringName
@export var index: int = 1                 # 단계 번호 (상점 min_region 게이팅과 비교 = 옛 지역번호)
@export var display_name: String           # 지역명 (제목 — 최소한 이건 바뀐다)
## ─ 존(role)별 몬스터: near=마을 근처(약), mid=중간, far=외곽(강), rare=메탈 자리 ─
@export var near_monster: MonsterData
@export var mid_monster: MonsterData
@export var far_monster: MonsterData
@export var rare_monster: MonsterData
## ─ 분위기 ─
@export var tile_tint: Color = Color.WHITE # 타일맵 모듈레이트 (동굴=어둡게, 마왕성=붉게)
@export_multiline var arrive_toast: String = ""   # 단계 진입 시 알림
## ─ 다음 단계로 ─
@export var advance_toll: int = 0          # 다음 단계 진행 통행료 (0 또는 최종이면 진행 불가)
@export var joins_companion: StringName = &"" # 이 단계 첫 진입 시 합류할 동료 id (선택)


## role(near/mid/far/rare)에 해당하는 몬스터.
func monster_for(role: StringName) -> MonsterData:
	match role:
		&"near": return near_monster
		&"mid": return mid_monster
		&"far": return far_monster
		&"rare": return rare_monster
	return null
