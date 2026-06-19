extends Node
## 동료 걷기 애니: 브레드크럼이 불연속(~3px)으로 갱신돼도 걷기 프레임이 끊기지 않고 순환해야 한다.
## godot --headless --path . res://tests/CompanionWalkTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var party: Node2D = get_tree().get_first_node_in_group("party")
	GameState.add_companion(GameState.companion_catalog[&"knight"])
	await get_tree().process_frame
	_check(party._companion_sprites.size() == 1, "동료 스프라이트 1개 생성")
	var comp: Sprite2D = party._companion_sprites[0]

	# 용사를 오른쪽으로 1.3px/프레임씩 걷게 하며 follow + 걷기 애니를 수동 구동
	party.global_position = Vector2(720, 576)
	party._reset_follow()
	var seen_frames := {}
	var moving_count := 0
	var prev_pos := comp.global_position
	var min_d := INF
	var max_d := 0.0
	for f in 60:
		party.global_position += Vector2(1.3, 0.0) # 부드러운 용사 걸음
		party._update_follow()
		comp._process(0.05)                         # 걷기 프레임 진행
		if f >= 25: # 정상 추적 궤도에 오른 뒤 프레임당 이동량 측정 (부드러움 검사)
			var d := comp.global_position.distance_to(prev_pos)
			min_d = minf(min_d, d)
			max_d = maxf(max_d, d)
		if f >= 20: # 동료가 경로에 올라타 실제로 따라 걷기 시작한 뒤 측정
			seen_frames[comp.frame] = true
			if party._companion_walk_hold[0] > 0:
				moving_count += 1
		prev_pos = comp.global_position

	# 같은 크기·걸음걸이: DirSprite가 자동으로 3x4 시트 설정
	_check(comp.hframes == 3 and comp.vframes == 4, "동료 스프라이트시트 3x4 (용사와 동일)")
	_check(is_equal_approx(comp.scale.x, 1.0), "동료 크기 1.0 (용사와 동일)")
	# 핵심: 걷는 동안 프레임이 여러 개로 순환했는가 (멈춰선 채 미끄러지지 않는다)
	_check(seen_frames.size() >= 2, "걷는 동안 걷기 프레임 순환 (애니 재생, 실제 %d종)" % seen_frames.size())
	_check(moving_count >= 35, "이동 중 거의 모든 프레임에서 '걷는 중' 유지 (실제 %d/40)" % moving_count)
	# 부드러움: 매 프레임 일정하게 이동해야 한다 (멈춤 프레임 0, 계단식 큰 점프 없음)
	_check(min_d > 0.3, "동료가 매 프레임 이동 — 멈춤(0) 프레임 없음 (최소 %.2fpx)" % min_d)
	_check(max_d < 2.5, "계단식 큰 점프 없음 — 용사 걸음(1.3px)에 근접 (최대 %.2fpx)" % max_d)

	# 멈추면 잠시 뒤 정지 (걷기 유지 카운터 소진)
	for f in WALK_HOLD():
		party._update_follow() # 위치 그대로 → move 0
	_check(party._companion_walk_hold[0] <= 0, "멈추면 걷기 유지 소진 → 정지")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)


func WALK_HOLD() -> int:
	return 10
