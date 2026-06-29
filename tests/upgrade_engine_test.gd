extends Node
## 업그레이드 트리 v0.1 — 엔진 토대(Phase 1) 검증.
## 제너릭 스탯(곱/합/불), 골드 배율(전투/마을/전체), 비용 배율, 디버그 GPM.
## 합성 UpgradeData를 카탈로그에 꽂아 실제 .tres 내용과 무관하게 엔진만 본다.
## godot --headless --path . res://tests/UpgradeEngineTest.tscn

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


## 합성 노드 하나 만들어 카탈로그에 등록.
func _mk(id: StringName, eff: Dictionary, cost := 10, growth := 1.0, mx := 1) -> UpgradeData:
	var u := UpgradeData.new()
	u.id = id
	u.display_name = String(id)
	u.base_cost = cost
	u.cost_growth = growth
	u.max_purchases = mx
	u.effects = eff
	GameState.catalog[id] = u
	return u


func _ready() -> void:
	GameState.reset_to_new_game()

	# ── 1. 기본 스탯 사전이 채워졌나 ──
	_check(GameState.stat("party_damage_mult") == 1.0, "곱 스탯 기본 1.0")
	_check(GameState.stat("all_gold_mult") == 1.0, "전체 골드 배율 기본 1.0")
	_check(float(GameState.stat("extra_window_efficiency")) == 0.45, "추가창 효율 기본 0.45")
	_check(int(GameState.stat("combat_slots")) == 1, "전투슬롯 기본 1")
	_check(GameState.stat("auto_loot") == false, "불 스탯 기본 false")
	_check(GameState.stat("없는키") == null, "모르는 키 → null")

	# ── 2. 곱 스탯: 거듭곱 + 레벨 누적 ──
	var dmg := _mk(&"_t_dmg", {"party_damage_mult": 1.5}, 10, 1.0, 3)
	GameState.gold = 9999
	GameState.purchase(dmg)
	_check(_approx(float(GameState.stat("party_damage_mult")), 1.5), "곱: 1회 → 1.5")
	GameState.purchase(dmg)
	_check(_approx(float(GameState.stat("party_damage_mult")), 2.25), "곱: 2회 → 1.5^2")

	# ── 3. 합 스탯: 합산 ──
	_mk(&"_t_slot", {"combat_slots": 1})
	var base_windows := GameState.max_battle_windows
	GameState.purchase(GameState.catalog[&"_t_slot"])
	_check(int(GameState.stat("combat_slots")) == 2, "합: 전투슬롯 1+1=2")
	_check(GameState.max_battle_windows == base_windows + 1, "전투슬롯 → 전투창 +1 파생")

	# ── 4. 공격속도 → 턴 간격 단축 ──
	var base_ti := GameState.turn_interval
	_mk(&"_t_spd", {"attack_speed_mult": 1.25})
	GameState.purchase(GameState.catalog[&"_t_spd"])
	_check(_approx(GameState.turn_interval, base_ti / 1.25), "공속 1.25 → 턴 간격 ÷1.25")

	# ── 5. 불 스탯: set true ──
	_mk(&"_t_auto", {"auto_loot": true})
	GameState.purchase(GameState.catalog[&"_t_auto"])
	_check(GameState.stat("auto_loot") == true, "불: auto_loot true")

	# ── 6. 비용 배율: upgrade_cost_mult ──
	_mk(&"_t_disc", {"upgrade_cost_mult": 0.5})
	GameState.purchase(GameState.catalog[&"_t_disc"])
	var pricey := _mk(&"_t_price", {"party_damage_mult": 1.0}, 100)
	_check(GameState.current_cost(pricey) == 50, "비용 배율 0.5 → 100G가 50G")

	# ── 7. 골드 배율 헬퍼 ──
	_mk(&"_t_egold", {"enemy_gold_mult": 2.0})
	_mk(&"_t_vgold", {"village_gold_mult": 3.0})
	_mk(&"_t_bgold", {"boss_gold_mult": 4.0})
	_mk(&"_t_agold", {"all_gold_mult": 1.5})
	GameState.purchase(GameState.catalog[&"_t_egold"])
	GameState.purchase(GameState.catalog[&"_t_vgold"])
	GameState.purchase(GameState.catalog[&"_t_bgold"])
	GameState.purchase(GameState.catalog[&"_t_agold"])
	# 운 0 → gold_find_mult()=1.0 이므로 순수 배율만 본다
	_check(_approx(GameState.combat_gold_mult(false), 2.0 * 1.5), "전투 골드 배율 = 적2 × 전체1.5")
	_check(_approx(GameState.combat_gold_mult(true), 2.0 * 1.5 * 4.0), "보스 골드 배율 = 적2 × 전체1.5 × 보스4")
	_check(_approx(GameState.village_gold_mult(), 3.0 * 1.5), "마을 골드 배율 = 마을3 × 전체1.5")

	# ── 8. 디버그 GPM: 출처별 집계 ──
	GameState._gold_events.clear()
	GameState.play_time = 30.0     # 30초 경과(윈도우 60s 미만 → 실경과로 환산)
	GameState.add_gold(100, &"combat")
	GameState.add_gold(50, &"village")
	GameState.add_gold(40, &"boss")
	var d := GameState.debug_stats()
	# 30초에 100/50/40 → 분당 200/100/80, 합 380
	_check(d["gpm_combat"] == 200, "GPM 전투 = 200")
	_check(d["gpm_village"] == 100, "GPM 마을 = 100")
	_check(d["gpm_boss"] == 80, "GPM 보스 = 80")
	_check(d["gpm"] == 380, "GPM 합 = 380")

	# ── 9. 마지막 구매 후 경과 ──
	GameState.play_time = 100.0
	GameState.last_purchase_time = 88.0
	_check(_approx(GameState.debug_stats()["since_purchase"], 12.0), "지난 구매 후 12초")

	# ── 10. 리셋이 새 필드를 비우나 ──
	GameState.reset_to_new_game()
	_check(GameState._gold_events.is_empty(), "리셋 → 골드 이벤트 비움")
	_check(GameState.last_purchase_time == 0.0, "리셋 → 마지막 구매 시각 0")

	# 합성 노드 정리 (다른 테스트에 새지 않게)
	for k in [&"_t_dmg", &"_t_slot", &"_t_spd", &"_t_auto", &"_t_disc",
			&"_t_price", &"_t_egold", &"_t_vgold", &"_t_bgold", &"_t_agold"]:
		GameState.catalog.erase(k)

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
