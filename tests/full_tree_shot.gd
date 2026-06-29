extends Node
## 시각 검증: v0.1 트리 전체 — 5가지(core/combat/village/command/trinket) + 교차 + 반복.
## 렌더링 필요 — godot --path . res://tests/FullTreeShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")

const OWN := [
	# core 스파인
	&"core_start", &"core_first_gold", &"core_slime_contract", &"core_town_permit",
	&"core_multi_hint", &"core_meadow_boss", &"core_forest_path", &"core_quest_board",
	&"core_cave_map", &"core_airship_toy", &"core_castle_shadow",
	# combat
	&"cmb_atk_1", &"cmb_hp_1", &"cmb_atk_2", &"cmb_auto_command", &"cmb_quick_swing",
	&"cmb_reward_study", &"cmb_skill_slash", &"cmb_combo", &"cmb_crit", &"cmb_fire_spell",
	&"cmb_boss_slayer", &"cmb_legend_sword",
	# village
	&"vlg_pot_1", &"vlg_pot_plus", &"vlg_pot_gold_1", &"vlg_pot_respawn_1", &"vlg_pot_worker",
	&"vlg_crate", &"vlg_npc", &"vlg_shop", &"vlg_inn", &"vlg_pot_chain", &"vlg_village_worker",
	&"vlg_chest", &"vlg_big_pot", &"vlg_tax_office", &"vlg_festival",
	# command
	&"cmd_recruit_warrior", &"cmd_auto_loot", &"cmd_battle_queue", &"cmd_window_2",
	&"cmd_window_train", &"cmd_healer", &"cmd_target_rules", &"cmd_window_mini",
	&"cmd_party_orders", &"cmd_window_3", &"cmd_window_4", &"cmb_warrior_oath",
	# trinket
	&"trk_unlock", &"trk_drop_slime", &"trk_boss_guarantee", &"trk_slot_2", &"trk_reroll_shop",
	# bridge (선행 충족분)
	&"brg_throw_pot", &"brg_shop_merc", &"brg_quest_trinkets", &"brg_inn_combo",
	# infinite
	&"inf_sharpen_blade", &"inf_gold_rumor",
]


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	for id in OWN:
		GameState.purchases[id] = 1
	GameState.gold = 99999999
	GameState.recalculate_stats()

	EventBus.request_shop.emit()
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_full_tree.png"))
	print("SHOT full_tree — 보유 %d / 카탈로그 %d" % [GameState.purchases.size(), GameState.catalog.size()])
	get_tree().quit()
