extends Node
## 풀 y-소트(발 기준) 검증 — 용사 발을 풀 위에 맞춰, 풀이 발치만 덮고 몸통/얼굴은 안 가리는지 본다.
## godot --path . res://tests/GrassYsortShot.tscn  →  user://screenshot_grass_ysort.png

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var field: Node = get_tree().get_first_node_in_group("field")
	var party: Node2D = get_tree().get_first_node_in_group("party")
	var grass: Node2D = field.find_child("GrassField", false, false)
	var cam: Camera2D = main.get_node("Camera2D")
	var ms: Vector2i = field.map_size
	var lift: float = field.grass_foot_lift

	# 안쪽 풀밭의 한 풀(땅 접점)을 골라, 용사 '발'이 그 위에 오게 세운다.
	var g: Vector2 = party.global_position
	for i in grass._ground.size():
		var cell: Vector2i = field._tiles.local_to_map(field._tiles.to_local(grass._ground[i]))
		if cell.x > ms.x * 0.45 and cell.x < ms.x - 16 and cell.y > ms.y * 0.6 and cell.y < ms.y - 16:
			g = grass._ground[i]
			break

	grass.set_process(false) # 밟기 끄고 다 세움(고정)
	for s: Sprite2D in grass._sprites:
		s.texture = grass._tex_stand
	party.set_physics_process(false)
	party.set_process(false)
	party.global_position = Vector2(g.x, g.y - lift) # 발(중심+lift)이 풀 땅 접점에 오게
	cam.zoom = Vector2(5.5, 5.5)
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://screenshot_grass_ysort.png"))

	GameState.reset_to_new_game()
	get_tree().quit()
