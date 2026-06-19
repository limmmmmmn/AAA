extends Node
## 마을 영입 NPC: 골드 조건 충족 시 등장, 접촉 시 동료 합류 → 파티 패널에 개별 스탯 표시.
## godot --headless --path . res://tests/RecruitTest.tscn

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _label_texts(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Label:
			out.append(c.text)
		out.append_array(_label_texts(c))
	return out


func _ready() -> void:
	GameState.reset_to_new_game()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var field: Node = get_tree().get_first_node_in_group("field")
	var party: Node = get_tree().get_first_node_in_group("party")
	var npc: Node = field.find_child("RecruitNPC", true, false)
	var hud: Node = main.find_child("HUD", true, false)

	_check(npc != null and npc.companion != null, "영입 NPC 존재 (전사)")

	# 골드 부족 → 숨김
	GameState.gold = 0
	npc._update()
	_check(not npc.visible, "골드 부족 시 NPC 숨김")

	# 골드 충족 → "!" 와 함께 등장
	GameState.gold = GameState.config.recruit_gold_threshold
	npc._update()
	_check(npc.visible and npc.get_node("Mark").visible, "골드 모이면 NPC 등장 (느낌표)")

	# 접촉(말 걸기) → 동료 합류, NPC 사라짐
	var before := GameState.member_count()
	npc._on_body_entered(party)
	_check(GameState.member_count() == before + 1, "말 걸면 동료 합류 (파티 +1)")
	_check(GameState.has_companion(&"knight"), "전사가 파티에 합류")
	_check(not npc.visible, "합류 후 NPC 사라짐")

	# 파티 패널에 전사 개별 스탯 표시
	hud._user_expanded = true
	hud._update_expanded(false)
	var texts := _label_texts(hud._stats_content)
	_check("전사" in texts, "패널에 동료(전사) 이름 표시")
	var knight: CompanionData = GameState.companion_catalog.get(&"knight")
	_check(("%d" % knight.attack_bonus) in texts, "동료 개별 공격력 표시 (%d)" % knight.attack_bonus)
	_check(("%d/%d" % [knight.max_hp, knight.max_hp]) in texts, "동료 개별 HP 표시 (%d)" % knight.max_hp)

	print("RESULT: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	get_tree().quit(1 if _fails > 0 else 0)
