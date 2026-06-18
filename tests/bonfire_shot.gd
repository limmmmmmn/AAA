extends Node
## 모닥불 회복 연출 시각 확인: 해금 → 파티 부상 → 모닥불 옆에서 "+N" 팝.
## godot --path . res://tests/BonfireShot.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _ready() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var field: Node = get_tree().get_first_node_in_group("field")
	var party: Node2D = get_tree().get_first_node_in_group("party")
	var bonfire: Node2D = field.find_child("Bonfire", true, false)

	# 모닥불 해금 + 파티를 모닥불 옆으로 + 크게 부상
	GameState.gold = 9999
	GameState.purchase(GameState.catalog[&"bonfire"])
	GameState.purchase(GameState.catalog[&"bonfire"]) # 레벨2 (빠른 회복 → 팝 잘 보이게)
	GameState.damage_member(0, 25)
	party.global_position = bonfire.global_position + Vector2(10, 6)
	# 진입 핑이 막 떠오른 순간을 잡는다 (깨짝 → 사라짐 0.14+0.6초)
	await get_tree().create_timer(0.22).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://screenshot_bonfire.png"))

	GameState.reset_to_new_game() # 종료 시 자동저장이 깨끗한 상태로 쓰이도록 (다음 실행 오염 방지)
	get_tree().quit()
