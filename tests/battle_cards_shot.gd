extends Node
## 전투 카드 보상-기준 컬러 시각 확인 (검정/주황/청록/보라/빨강).
const MAIN_SCENE := preload("res://scenes/Main.tscn")

func _mk(nm: String, fields: Dictionary) -> MonsterData:
	var d := MonsterData.new()
	d.id = &"demo"; d.display_name = nm; d.max_hp = 80; d.attack = 2
	d.sprite = load("res://assets/slime.svg")
	for k in fields: d.set(k, fields[k])
	return d

func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.max_battle_windows = 6
	BattleManager.start_battle([_mk("Slime", {})])                       # 검정
	BattleManager.start_battle([_mk("Rich", {"gold_reward": 20})])        # 주황
	BattleManager.start_battle([_mk("Drop", {"sword_drop": 0.3})])        # 청록
	BattleManager.start_battle([_mk("Metal", {"flee_after_hits": 1})])    # 보라
	BattleManager.start_battle([_mk("Orc", {"hunt_default": false})])     # 빨강
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://ui_battle_cards.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
