extends Node
## 땅파기 시스템 검증 (삽 구매 → 쿨타임 채굴 → 반짝임 100% → 삽 업글 쿨감).
## godot --headless --path . res://tests/DigTest.tscn

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
	# 깨끗한 시작
	GameState.purchases.clear()
	GameState.gold = 100000
	GameState.has_sparkling_ground = false
	GameState.sparkle_area = &""
	GameState.wisdom = 0
	GameState.dig_ready_at = 0.0
	GameState.recalculate_stats()

	# ── 삽 구매 전: 땅파기 잠김 ──
	_check(not GameState.has_shovel and not GameState.dig_unlocked(), "삽 없으면 땅파기 잠김")
	_check(not GameState.dig_ready(), "삽 없으면 dig_ready false")
	_check(GameState.do_dig().ok == false, "삽 없이 do_dig → 실패")
	# 상점: 좋은 삽/꼬마돼지는 삽 보유 전엔 숨김
	var field_ids := GameState.upgrades_for_axis("field").map(func(u: UpgradeData) -> StringName: return u.id)
	_check(field_ids.has(&"shovel"), "상점에 삽 노출")
	_check(not field_ids.has(&"shovel_sharp") and not field_ids.has(&"pig_companion"), "삽 전엔 좋은 삽/꼬마돼지 숨김")

	# ── 삽 구매 → 해금 ──
	_check(GameState.purchase(GameState.catalog[&"shovel"]), "삽 구매")
	_check(GameState.has_shovel and GameState.dig_unlocked(), "삽 구매 → 땅파기 해금")
	_check(is_equal_approx(GameState.dig_cooldown, GameState.config.dig_base_cooldown), "기본 쿨타임 60초")
	field_ids = GameState.upgrades_for_axis("field").map(func(u: UpgradeData) -> StringName: return u.id)
	_check(field_ids.has(&"shovel_sharp") and field_ids.has(&"pig_companion"), "삽 구매 후 좋은 삽/꼬마돼지 노출")

	# ── 땅파기 + 쿨타임 ──
	GameState.play_time = 1000.0
	GameState.dig_ready_at = 0.0
	_check(GameState.dig_ready(), "준비됨")
	var r := GameState.do_dig()
	_check(r.ok and not r.sparkle, "일반 땅파기 실행")
	_check(is_equal_approx(GameState.dig_ready_at, 1000.0 + GameState.dig_cooldown), "쿨타임 설정됨")
	_check(not GameState.dig_ready() and GameState.do_dig().ok == false, "쿨타임 중엔 못 판다")
	GameState.play_time = GameState.dig_ready_at + 1.0
	_check(GameState.dig_ready(), "쿨타임 경과 후 다시 준비됨")

	# ── 일반 땅파기 보상 (확률 강제 1.0로 검증) ──
	var saved_chance: float = GameState.config.dig_success_chance
	GameState.config.dig_success_chance = 1.0
	GameState.dig_ready_at = 0.0
	var dr := GameState.do_dig()
	GameState.config.dig_success_chance = saved_chance
	_check(dr.ok and not dr.sparkle and dr.msg != "", "성공률 100%%일 때 보상 지급 (%s)" % dr.msg)
	# 확률 0이면 꽝
	GameState.config.dig_success_chance = 0.0
	GameState.dig_ready_at = 0.0
	var dr0 := GameState.do_dig()
	GameState.config.dig_success_chance = saved_chance
	_check(dr0.ok and dr0.msg == "", "성공률 0일 때 꽝")

	# ── 반짝이는 땅: 위에 서서 파면 100% 보상 ──
	GameState.has_sparkling_ground = true
	GameState.sparkle_area = &"region1"
	GameState.party_on_sparkle = true # 반짝임 위에 서 있음
	GameState.dig_ready_at = 0.0
	var sr := GameState.do_dig()
	_check(sr.ok and sr.sparkle and sr.msg != "", "반짝이는 땅 위에서 → 100% 보상")
	_check(not GameState.has_sparkling_ground and not GameState.party_on_sparkle, "캔 뒤 반짝임 제거")
	# 반짝임 밖에서 파면 일반 채굴 (반짝임은 남는다)
	GameState.has_sparkling_ground = true
	GameState.sparkle_area = &"region1"
	GameState.party_on_sparkle = false # 반짝임 밖
	GameState.config.dig_success_chance = 0.0
	GameState.dig_ready_at = 0.0
	var so := GameState.do_dig()
	GameState.config.dig_success_chance = saved_chance
	_check(so.ok and not so.sparkle, "반짝임 밖에서 파면 일반 채굴")
	_check(GameState.has_sparkling_ground, "밖에서 파도 반짝이는 땅은 그대로 남음")

	# ── 삽 업그레이드: 쿨타임 감소 ──
	GameState.purchase(GameState.catalog[&"shovel_sharp"])
	_check(is_equal_approx(GameState.dig_cooldown, 50.0), "좋은 삽 1단계 → 50초")
	GameState.purchase(GameState.catalog[&"shovel_sharp"])
	GameState.purchase(GameState.catalog[&"shovel_sharp"])
	_check(is_equal_approx(GameState.dig_cooldown, 30.0), "좋은 삽 3단계 → 30초")
	_check(GameState.owned_count(GameState.catalog[&"shovel_sharp"]) == 3, "좋은 삽 최대 3단계")

	# ── 반짝임 생성 확률: 지혜 + 꼬마돼지 ──
	GameState.wisdom = 0
	GameState.has_pig_companion = false
	GameState.recalculate_stats()
	_check(is_equal_approx(GameState.sparkle_chance(), 0.0), "지혜0·돼지없음 → 반짝임 0%")
	GameState.wisdom = 20
	_check(is_equal_approx(GameState.sparkle_chance(), 20 * GameState.config.wisdom_sparkle_per), "지혜20 → 반짝임 확률 ↑")
	_check(GameState.purchase(GameState.catalog[&"pig_companion"]), "꼬마돼지 영입")
	_check(GameState.has_pig_companion, "꼬마돼지 보유 플래그")
	_check(is_equal_approx(GameState.sparkle_chance(),
		20 * GameState.config.wisdom_sparkle_per + GameState.config.pig_sparkle_bonus), "꼬마돼지 보정 합산")

	# ── 꼬마돼지: 준비되면 반짝이는 땅이 바로 맵에 등장 (확정) ──
	GameState.has_sparkling_ground = false
	GameState.party_on_sparkle = false
	GameState.play_time = 5000.0
	GameState.dig_ready_at = 0.0 # 준비 상태
	GameState._tick_sparkle()
	_check(GameState.has_sparkling_ground, "꼬마돼지 + 쿨타임 끝 → 반짝임 즉시 등장")
	_check(GameState.sparkle_area == GameState.current_region, "반짝임은 현재 지역에 생성")
	# 그 위에 서서 땅파기 버튼 → 좋은 보상
	GameState.party_on_sparkle = true
	GameState.dig_ready_at = 0.0
	var pr := GameState.do_dig()
	_check(pr.ok and pr.sparkle and pr.msg != "", "반짝임 위에서 파기 → 좋은 보상 (%s)" % pr.msg)
	_check(not GameState.has_sparkling_ground, "캔 뒤 반짝임 사라짐")
	_check(GameState.dig_ready_at > GameState.play_time, "캔 뒤 쿨타임 시작")
	GameState._tick_sparkle()
	_check(not GameState.has_sparkling_ground, "쿨타임 중엔 재등장 안 함")
	GameState.play_time = GameState.dig_ready_at + 1.0
	GameState._tick_sparkle()
	_check(GameState.has_sparkling_ground, "쿨타임 지나면 꼬마돼지가 다시 찾아줌")

	# ── 저장 / 로드 ──
	GameState.wisdom = 7
	GameState.dig_ready_at = 4242.0
	GameState.has_sparkling_ground = true
	GameState.sparkle_area = &"region2"
	GameState.save_game()
	GameState.wisdom = 0
	GameState.dig_ready_at = 0.0
	GameState.has_sparkling_ground = false
	GameState.load_game()
	_check(GameState.wisdom == 7 and is_equal_approx(GameState.dig_ready_at, 4242.0), "땅파기 상태 저장/로드")
	_check(GameState.has_sparkling_ground and GameState.sparkle_area == &"region2", "반짝임 상태 저장/로드")
	GameState.recalculate_stats()
	_check(GameState.has_shovel, "로드 후 삽 보유 복원 (purchases 기반)")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
