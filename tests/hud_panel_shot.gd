extends Node
## 파티 패널 확장(스탯창) 시각 확인. godot --path . res://tests/HudPanelShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	# 스탯에 값이 보이도록 약간 강화
	GameState.gold = 9999
	GameState.purchase(GameState.catalog[&"cmb_atk_1"]) # 공격력
	GameState.purchase(GameState.catalog[&"boots_swift"])   # 속도
	for i in 4:
		GameState.purchase(GameState.catalog[&"luck_charm"]) # 운
	GameState.add_companion(GameState.companion_catalog[&"priest"]) # 동료 개별 스탯
	var hud: Node = main.find_child("HUD", true, false)
	hud._user_expanded = true
	hud._update_expanded(true) # 펼침(애니)
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_hud_panel.png"))

	GameState.reset_to_new_game()
	get_tree().quit()
