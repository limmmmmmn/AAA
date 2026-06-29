extends Node
## 시각 검증: 4인 파티(용사+전사+마법사+힐러)가 필드를 줄줄이 따라 걷는다.
## 렌더링 필요 — godot --path . res://tests/PartyShot.tscn  (--headless 금지)

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	GameState.reset_to_new_game()
	add_child(MAIN_SCENE.instantiate())
	await get_tree().process_frame
	# 4인 파티 구성
	for cid in [&"knight", &"mage", &"priest"]:
		GameState.add_companion(GameState.companion_catalog[cid])
	var party: Node2D = get_tree().get_first_node_in_group("party")
	party.global_position = Vector2(520, 470)
	await get_tree().process_frame

	# 오른쪽으로 걸어 트레일이 줄줄이 늘어서게
	for i in 60:
		party.global_position.x += 3.0
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://shot_party.png"))
	print("SHOT party — 멤버 %d명 (%s)" % [
		GameState.member_count(),
		", ".join(GameState.party_members().map(func(m: Dictionary) -> String: return m.name))])
	get_tree().quit()
