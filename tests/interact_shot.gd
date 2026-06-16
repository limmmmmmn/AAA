extends Node
## 근접 상호작용 프롬프트 시각 확인. godot --path . res://tests/InteractShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var party: Node2D = get_tree().get_first_node_in_group("party")

	# ① 상점 근처 → "상점 열기 [Space]" 프롬프트
	if party:
		party.global_position = Vector2(652, 470)
	for i in 12:
		await get_tree().physics_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://shot_shop_prompt.png"))

	# ② Space 작동 시뮬 → 상점 열림
	EventBus.request_shop.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://shot_shop_open.png"))

	# ③ Esc 시뮬 → 모달 닫힘
	EventBus.request_close_modals.emit()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://shot_shop_closed.png"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit()
