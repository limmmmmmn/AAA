extends Node
## 시각 검증: 비정지 카탈로그 — 트링켓(멤버 장착) / 이동(지역) / 도감 탭.
## 렌더링 필요 — godot --path . res://tests/CatalogShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_catalog_%s.png" % name))


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	GameState.gold = 99999999
	# 풀파티 + 트링켓 + 지역 해금 + 몬스터 발견
	GameState.purchase(GameState.catalog[&"core_start"])
	for cid in [&"knight", &"mage", &"priest"]:
		GameState.add_companion(GameState.companion_catalog[cid])
	GameState.purchases[&"trk_unlock"] = 1
	GameState.recalculate_stats()
	for tid in [&"t_tactics_book", &"t_small_bell", &"t_golden_bait", &"t_monster_flute", &"t_coward_incense"]:
		GameState.discover_trinket(tid)
	GameState.purchase(GameState.catalog[&"core_forest_path"])
	GameState.party_in_town = true
	for mid in [&"slime", &"meadow_rat", &"horn_rabbit", &"grass_wasp"]:
		var m: MonsterData = GameState.monster_by_id(mid)
		if m != null:
			for i in 3:
				GameState.register_kill(m)
	await get_tree().process_frame

	var cat: Control = get_tree().get_first_node_in_group("closable_modal")
	for n in get_tree().get_nodes_in_group("closable_modal"):
		if n.name == "CatalogUI":
			cat = n
	EventBus.request_catalog.emit()
	await get_tree().process_frame
	cat._refresh_all()

	var tab_names := ["buy", "party", "trinket", "travel", "bestiary"]
	for i in cat._tabs.get_tab_count():
		cat._tabs.current_tab = i
		await get_tree().process_frame
		await _shot(tab_names[i])
	print("SHOT catalog — 탭 %d장, 파티 %d명, 트링켓 %d, 해금지역 %d" % [
		cat._tabs.get_tab_count(), GameState.member_count(),
		GameState.owned_trinkets.size(), GameState.unlocked_regions.size()])
	get_tree().quit()
