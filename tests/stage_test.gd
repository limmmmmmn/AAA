extends Node
## 단일 맵 단계(stage) 시스템 검증 — 맵 1개로 1~최종 단계, 적/지역명/통행료가 단계마다 바뀐다.
## godot --headless --path . res://tests/StageTest.tscn

var _fails := 0
var _region_changes := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	GameState.reset_to_new_game()
	EventBus.region_changed.connect(func(_id: StringName) -> void: _region_changes += 1)

	# ── 1. 카탈로그 ──
	_check(GameState.stage_catalog.size() == 5, "단계 5개 로드 (%d)" % GameState.stage_catalog.size())
	var sorted := true
	for i in range(1, GameState.stage_catalog.size()):
		if GameState.stage_catalog[i].index < GameState.stage_catalog[i - 1].index:
			sorted = false
	_check(sorted, "index 오름차순 정렬")

	# ── 2. 시작 = 초원(1) ──
	_check(GameState.current_region == &"stage_meadow", "시작 단계 = stage_meadow")
	_check(GameState.region_number() == 1, "단계 번호 1")
	_check(GameState.stage_name() == "초원", "지역명 = 초원")
	_check(GameState.stage_monster(&"near").id == &"slime", "초원 근접존 = 슬라임")
	_check(GameState.stage_monster(&"mid").id == &"bat", "초원 중간존 = 박쥐")
	_check(GameState.stage_monster(&"far").id == &"elite_bat", "초원 외곽존 = 큰박쥐")
	_check(GameState.stage_monster(&"rare").id == &"metal_slime", "초원 rare = 메탈슬라임")

	# ── 3. 진행: 초원 → 숲길 (승려 합류) ──
	var party0 := GameState.member_count()
	_check(GameState.advance_stage(), "진행 성공 (초원→숲길)")
	_check(GameState.region_number() == 2, "단계 번호 2")
	_check(GameState.current_region == &"stage_forest", "단계 = stage_forest")
	_check(GameState.stage_monster(&"near").id == &"snake", "숲길 근접존 = 독사")
	_check(GameState.member_count() == party0 + 1, "숲길 진입 → 승려 합류")
	_check(GameState.has_companion(&"priest"), "승려 보유")
	_check(_region_changes == 1, "region_changed 1회 발신")

	# ── 4. 끝까지 진행 → 최종에서 멈춤 ──
	_check(GameState.advance_stage(), "숲길→동굴")
	_check(GameState.stage_name() == "동굴", "지역명 = 동굴")
	_check(GameState.advance_stage(), "동굴→마왕성 외곽")
	_check(GameState.advance_stage(), "마왕성 외곽→마왕성 정문")
	_check(GameState.region_number() == 5, "단계 번호 5 (최종)")
	_check(GameState.current_stage().advance_toll == 0, "최종 단계 통행료 0 (진행 불가)")
	_check(not GameState.advance_stage(), "최종에선 더 진행 불가")
	_check(GameState.region_number() == 5, "진행 실패해도 단계 유지")

	# ── 5. 구 세이브 마이그레이션 ──
	_check(GameState._migrate_stage_id(&"region1") == &"stage_meadow", "region1 → stage_meadow")
	_check(GameState._migrate_stage_id(&"region2") == &"stage_forest", "region2 → stage_forest")
	_check(GameState._migrate_stage_id(&"stage_cave") == &"stage_cave", "이미 stage id면 그대로")
	_check(GameState._migrate_stage_id(&"없는것") == &"stage_meadow", "모르는 id → 첫 단계")

	# ── 6. 단계 번호 = region_number (상점 min_region 게이팅의 기준) ──
	GameState.current_region = &"stage_meadow"
	_check(GameState.region_number() == 1, "초원 = 단계 1")
	GameState.current_region = &"stage_cave"
	_check(GameState.region_number() == 3, "동굴 = 단계 3")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
