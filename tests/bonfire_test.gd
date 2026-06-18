extends Node
## 모닥불 회복존: 상점 해금 → 설치/표시, 근처에서 회복, 레벨↑ → 회복 빨라짐.
## godot --headless --path . res://tests/BonfireTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _ready() -> void:
	GameState.reset_to_new_game() # 이전 세이브(모닥불 구매 등) 영향 없이 깨끗한 상태에서 시작
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var field: Node = get_tree().get_first_node_in_group("field")
	var party: Node = get_tree().get_first_node_in_group("party")
	var bonfire: Node = field.find_child("Bonfire", true, false)
	GameState.damage_enabled = true

	# ── 모닥불 해금 (범위·속도·회복량은 별도 업글) ──
	var up_unlock: UpgradeData = GameState.catalog.get(&"bonfire")
	var up_speed: UpgradeData = GameState.catalog.get(&"bonfire_speed")
	var up_range: UpgradeData = GameState.catalog.get(&"bonfire_range")
	var up_heal: UpgradeData = GameState.catalog.get(&"bonfire_heal")
	_check(up_unlock and up_speed and up_range and up_heal, "모닥불 업글 4종 존재")
	_check(GameState.upgrades_for_axis("field").has(up_unlock), "상점에 모닥불(해금) 노출")
	_check(not GameState.upgrades_for_axis("field").has(up_speed), "해금 전엔 속도/범위/회복량 업글 숨김")
	_check(bonfire != null and not bonfire.visible, "구매 전엔 모닥불 숨김")

	GameState.gold = 99999
	GameState.purchase(up_unlock)
	_check(GameState.bonfire_unlocked, "해금 → 설치")
	_check(bonfire.visible, "구매 후 마을에 모닥불 표시")
	_check(GameState.upgrades_for_axis("field").has(up_speed), "해금 후 속도/범위/회복량 업글 노출")
	_check(is_equal_approx(bonfire._shape.shape.radius, GameState.bonfire_radius()), "감지 반경이 현재 범위에 적용")

	# ── 속도 업글 → 간격↓ ──
	var interval0 := GameState.bonfire_interval()
	GameState.purchase(up_speed)
	_check(GameState.bonfire_interval() < interval0, "속도 업글 → 회복 간격 단축")

	# ── 범위 업글 → 반경↑ (감지 영역에도 반영) ──
	var radius0 := GameState.bonfire_radius()
	GameState.purchase(up_range)
	_check(GameState.bonfire_radius() > radius0, "범위 업글 → 회복 반경 확장")
	_check(is_equal_approx(bonfire._shape.shape.radius, GameState.bonfire_radius()), "확장된 반경이 감지 영역에 반영")

	# ── 회복량 업글 → 1틱 +HP↑ ──
	var heal0 := GameState.bonfire_heal_amount()
	GameState.purchase(up_heal)
	_check(GameState.bonfire_heal_amount() == heal0 + 1, "회복량 업글 → 1틱 회복량 증가")

	# ── 근처에서 회복 + 연출 ──
	GameState.damage_member(0, 12) # 용사 부상
	var hp0 := GameState.member_hp(0)
	_check(hp0 < GameState.member_max_hp(0), "용사 부상 상태 준비")
	bonfire._on_body_entered(party)        # 파티가 모닥불 근처로
	bonfire._process(GameState.bonfire_interval() + 0.01) # 1틱 경과
	_check(GameState.member_hp(0) == hp0 + GameState.bonfire_heal_amount(), "근처에서 1틱 회복(회복량 반영)")
	_check(bonfire.get_node_or_null("HealPopup") != null, "회복 시 +N 연출 스폰")

	# ── 가득 차면 회복/연출 없음 ──
	GameState.full_heal()
	_check(GameState.bonfire_heal_tick() == -1, "가득 차면 회복 안 함")

	# ── 멀어지면 멈춤 ──
	bonfire._on_body_exited(party)
	_check(not bonfire.is_processing(), "멀어지면 회복 정지")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
