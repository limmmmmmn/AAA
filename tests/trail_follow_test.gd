extends Node
## A-4 동료 줄줄이 이동(trail-follow) 검증.
## godot --headless --path . res://tests/TrailFollowTest.tscn
## 순수 위치 재생이라 렌더링 없이 검증 가능하다.

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var party: Node2D = get_tree().get_first_node_in_group("party")

	# 1지역(용사 1인): 동료 없음 → 트레일 비활성
	party.global_position = Vector2(500, 500)
	for k in 20:
		party.global_position += Vector2(2, 0)
		party._update_follow()
	_check(party._companion_sprites.is_empty(), "용사 1인: 동료 스프라이트 없음(트레일 미동작)")

	# 동료 합류 → 줄줄이 따라온다
	GameState.add_companion(load("res://data/companions/priest.tres"))
	await get_tree().process_frame
	_check(party._companion_sprites.size() == 1, "동료 합류 → 동료 스프라이트 1개")
	var comp: Node2D = party._companion_sprites[0]

	# 합류 직후엔 용사 위치에 스냅
	party.global_position = Vector2(500, 500)
	party._reset_follow()
	_check(comp.global_position.distance_to(party.global_position) < 0.5, "합류 직후 동료는 용사에 스냅")

	# 일직선 이동: 동료는 경로상 follow_gap(px) 뒤를 따른다 (1번째 동료 = 1×follow_gap)
	var step := Vector2(2, 0)
	for k in 60:
		party.global_position += step
		party._update_follow()
	var expected_lag: float = party.follow_gap
	var actual_lag := party.global_position.x - comp.global_position.x
	_check(abs(comp.global_position.y - party.global_position.y) < 0.5, "동료는 용사의 경로(같은 y) 위에 있다")
	_check(comp.global_position.x < party.global_position.x, "동료는 용사 뒤에 있다")
	_check(abs(actual_lag - expected_lag) < step.length() + 0.5, "지연 거리 ≈ follow_gap %.0f (실제 %.0f)" % [expected_lag, actual_lag])

	# 순간이동(지역 전환·부활) → 트레일 끊고 동료 스냅 (화면 가로질러 날아오지 않음)
	party.global_position = Vector2(3000, 3000)
	party._update_follow()
	_check(comp.global_position.distance_to(party.global_position) < 0.5, "순간이동 시 동료는 즉시 스냅(트레일 리셋)")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
