extends Node
## 시각 검증: (1) 갓 연 트리 = core_start 가운데(허브 원 없음), (2) 재정렬된 전체 트리.
## 렌더링 필요 — godot --path . res://tests/LayoutVerifyShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame

	# (1) 갓 연 상태 — core_start만 가운데
	EventBus.request_shop.emit()
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_fresh_open.png"))
	EventBus.request_shop_close.emit()
	await get_tree().process_frame

	# (2) 많이 사서 전체 트리
	GameState.gold = 99999999
	for u in GameState.tree_upgrades():
		GameState.purchases[u.id] = 1
	GameState.recalculate_stats()
	EventBus.request_shop.emit()
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_relayout_full.png"))
	print("SHOT — 카탈로그 %d, core_start 위치 %s" % [
		GameState.catalog.size(), str(GameState.upgrade_by_id(&"core_start").tree_pos)])
	get_tree().quit()
