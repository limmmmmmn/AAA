extends Node
## 패시브 트리 상점 시각 확인. godot --path . res://tests/TreeShopShot.tscn
## 결과: user://screenshot_tree_{intro,fresh,bought,full}.png

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://screenshot_tree_%s.png" % name))


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var shop_ui: Node = main.find_child("ShopUI", true, false)

	# ① 갓 열린 순간 — 허브에서 루트로 선이 "쭈욱" 자라는 중(점진 등장)
	GameState.gold = 300
	EventBus.request_shop.emit()
	await get_tree().create_timer(0.12).timeout
	_shot("intro")

	# ② 정착: 새 게임이라 허브 + 루트 3개(열 수 있는 곳)만 보인다
	await get_tree().create_timer(0.7).timeout
	_shot("fresh")

	# ③ 경로를 따라 구매 → 끝 노드를 사면 다음 연결 노드가 새로 등장
	for id in [&"sword_copper", &"sword_iron", &"spell_gira",
			&"pot_unlock", &"bonfire", &"bonfire_speed",
			&"boots_swift", &"luck_charm", &"horde"]:
		GameState.purchase(GameState.catalog[id])
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.6).timeout
	_shot("bought")

	# ④ 2지역 전체(많이 보유한 상태로 재오픈) + 노드 호버 띠링
	EventBus.request_shop_close.emit()
	GameState.current_region = &"region2"
	GameState.gold = 999999
	EventBus.request_shop.emit()
	await get_tree().create_timer(1.3).timeout # 펼쳐짐 정착 대기
	var hovered: SkillNode = shop_ui._node_map[&"sword_steel"]
	hovered._on_enter()
	await get_tree().create_timer(0.12).timeout
	_shot("full")

	GameState.reset_to_new_game() # 종료 자동저장 오염 방지
	get_tree().quit()
