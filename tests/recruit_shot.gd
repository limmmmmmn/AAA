extends Node
## 영입 NPC + 동료 합류 후 개별 스탯 패널 시각 확인. godot --path . res://tests/RecruitShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var field: Node = get_tree().get_first_node_in_group("field")
	var npc: Node2D = field.find_child("RecruitNPC", true, false)

	# 1) NPC 등장 컷 (느낌표)
	GameState.gold = 12
	npc._update()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_recruit_npc.png"))

	# 2) 합류 후 개별 스탯 패널
	var party: Node = get_tree().get_first_node_in_group("party")
	npc._on_body_entered(party)
	GameState.purchase(GameState.catalog[&"cmb_atk_1"]) # 용사 공격력 차이 보이게
	var hud: Node = main.find_child("HUD", true, false)
	hud._user_expanded = true
	hud._update_expanded(true)
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_recruit_stats.png"))

	GameState.reset_to_new_game()
	get_tree().quit()
