extends Node
## 운(Luck): 회심·발견 골드·아이템 발견 ↑, 항아리 꽝 존재(운 높이면 ↓), 파티 운 = 멤버 중 최고.
## godot --headless --path . res://tests/LuckTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _count_nothing(rolls: int) -> int:
	var n := 0
	for i in rolls:
		if String(GameState._roll_pot().type) == "nothing":
			n += 1
	return n


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var cfg = GameState.config

	# ── 기본: 운 0, 회심 = 기본값 ──
	_check(GameState.party_luck == 0, "시작 운 0")
	_check(is_equal_approx(GameState.crit_chance, cfg.base_crit_chance), "운 0 → 회심 = 기본값")

	# ── 항아리 꽝 존재 ──
	var n0 := _count_nothing(400)
	_check(n0 > 0, "항아리에 꽝 존재 (운0 400회 중 %d회)" % n0)

	# ── 행운 업글 → 운/회심/발견 골드/발견 확률 ↑ ──
	GameState.gold = 999999
	for i in 8:
		GameState.purchase(GameState.catalog[&"luck_charm"])
	_check(GameState.hero_luck == 8 and GameState.party_luck == 8, "행운 부적 ×8 → 운 8")
	_check(is_equal_approx(GameState.crit_chance, cfg.base_crit_chance + 8 * cfg.luck_crit_per), "운 → 회심 확률 ↑")
	_check(is_equal_approx(GameState.gold_find_mult(), 1.0 + 8 * cfg.luck_gold_per), "운 → 발견 골드 배수 ↑ (%.2f)" % GameState.gold_find_mult())
	_check(is_equal_approx(GameState.item_find_mult(), 1.0 + 8 * cfg.luck_find_per), "운 → 아이템 발견 배수 ↑ (%.2f)" % GameState.item_find_mult())

	# ── 운 높이면 꽝 줄어든다 ──
	var n8 := _count_nothing(400)
	_check(n8 < n0, "운 높이면 항아리 꽝 ↓ (%d → %d)" % [n0, n8])
	_check(String(GameState._grant({"type": "nothing"})) == "꽝...", "꽝 결과 문자열")

	# ── 파티 운 = 멤버 중 최고값 (합 아님) ──
	GameState.add_companion(GameState.companion_catalog[&"priest"]) # 승려 운 2
	_check(GameState.party_luck == 8, "파티 운 = 최고(8), 합(10) 아님")
	var ml := GameState.member_lucks()
	_check(ml.size() == 2 and ml[0] == 8 and ml[1] == 2, "멤버별 운 = [용사8, 승려2]")

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
