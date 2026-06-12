extends HFlowContainer
## battle_started를 받아 BattleWindow를 인스턴싱해 붙인다. 창이 늘면 자동 정렬.

const BATTLE_WINDOW_SCENE := preload("res://scenes/ui/BattleWindow.tscn")


func _ready() -> void:
	EventBus.battle_started.connect(_on_battle_started)


func _on_battle_started(battle: BattleInstance) -> void:
	var window := BATTLE_WINDOW_SCENE.instantiate()
	add_child(window)
	window.bind(battle)
