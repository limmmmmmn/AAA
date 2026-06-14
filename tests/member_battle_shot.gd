extends Node
## 멤버별 전투 로그 시각 확인 (용사·승려가 번갈아 공격, 적 반격).
## godot --path . res://tests/MemberBattleShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	# 2지역 상태 + 승려 합류 (멤버 2명)
	GameState.damage_enabled = true
	GameState.crit_chance = 0.0
	GameState.add_companion(GameState.companion_catalog.get(&"priest"))
	GameState.full_heal()
	# 오래 버티는 적 1마리 → 라운드가 여러 번 돌며 로그가 쌓인다
	var d := MonsterData.new()
	d.id = &"snake"; d.display_name = "독사"; d.max_hp = 300; d.attack = 6; d.defense = 0
	d.sprite = load("res://assets/snake.svg")
	BattleManager.start_battle([d])
	await get_tree().create_timer(2.2).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_member_battle.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
