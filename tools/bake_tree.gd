extends SceneTree
## 일회성/재실행 가능: 상점 패시브 트리의 노드 좌표(tree_pos)·선행 노드(tree_links)·
## 아이콘(icon)을 각 UpgradeData(.tres)에 구워넣는다. 바꾸려면 아래 표만 고치고 다시 실행.
## 실행: godot --headless --path . --script res://tools/bake_tree.gd
##
## 레이아웃(허브 0,0 기준 그리드):
##   오른쪽(+x) = 전투(검 백본 + 갑옷/주문 분기)
##   아래(+y)   = 마을 경제(항아리/모닥불/여관/상자/삽)
##   왼쪽(-x)   = 사냥·이동(신발/부적/나침반/부활/깃발)
## 각 노드는 부모 1개로 이어지는 순수 트리 → 연결된 앞 노드를 사야 해금.

const DIR := "res://data/upgrades/"
const ICON_DIR := "res://assets/node_icons/"

## id -> [pos_x, pos_y, parent_id, icon]  (parent &"core" = 중앙 허브, icon = node_icons/<icon>.png)
const TREE := {
	# ── 전투(오른쪽) ──
	"sword_copper":   [1, 0, "core", "sword"],
	"sword_iron":     [2, 0, "sword_copper", "sword"],
	"sword_steel":    [3, 0, "sword_iron", "sword"],
	"sword_mythril":  [4, 0, "sword_steel", "sword"],
	"spell_gira":     [2, -1, "sword_iron", "mage_staff"],
	"spell_begirama": [2, -2, "spell_gira", "mage_staff"],
	"spell_catalog":  [3, -2, "spell_begirama", "mage_staff"],
	"window_expand":  [4, -1, "sword_steel", "helmet"],
	"armor_leather":  [2, 1, "sword_iron", "armor"],
	"armor_chain":    [2, 2, "armor_leather", "shield"],
	# ── 마을 경제(아래) ──
	"pot_unlock":     [0, 1, "core", "pot"],
	"bonfire":        [0, 2, "pot_unlock", "bonfire"],
	"inn_unlock":     [0, 3, "bonfire", "priest_staff"],
	"chest_unlock":   [0, 4, "inn_unlock", "chest"],
	"shovel":         [0, 5, "chest_unlock", "grass"],
	"pot_count":      [-1, 1, "pot_unlock", "pot"],
	"pot_cooldown":   [-2, 1, "pot_count", "pot"],
	"bonfire_speed":  [-1, 2, "bonfire", "bonfire"],
	"bonfire_range":  [-2, 2, "bonfire_speed", "bonfire"],
	"bonfire_heal":   [-3, 2, "bonfire_range", "bonfire"],
	"chest_count":    [-1, 4, "chest_unlock", "chest"],
	"chest_cooldown": [-2, 4, "chest_count", "chest"],
	"shovel_sharp":   [-1, 5, "shovel", "grass"],
	"pig_companion":  [-1, 6, "shovel", "gold"],
	# ── 사냥·이동(왼쪽) ──
	"boots_swift":    [-1, 0, "core", "water"],
	"haste_charm":    [-2, 0, "boots_swift", "ring"],
	"boots_wind":     [-3, 0, "haste_charm", "water"],
	"luck_charm":     [-1, -1, "boots_swift", "necklace"],
	"compass_hunt":   [-2, -1, "luck_charm", "bow"],
	"horde":          [-1, -2, "luck_charm", "slime"],
	"respawn_swift":  [-2, -2, "horde", "slime"],
	"bell_respawn":   [-3, -1, "compass_hunt", "slime"],
	"banner_valor":   [-3, -2, "bell_respawn", "helmet"],
	"banner_valor_2": [-4, -2, "banner_valor", "helmet"],
}


func _init() -> void:
	var done := 0
	for id: String in TREE:
		var path := DIR + id + ".tres"
		var up: UpgradeData = load(path)
		if up == null:
			push_error("못 찾음: " + path)
			continue
		var row: Array = TREE[id]
		up.tree_pos = Vector2i(row[0], row[1])
		var links: Array[StringName] = []
		links.append(StringName(row[2]))
		up.tree_links = links
		var icon_path: String = ICON_DIR + String(row[3]) + ".png"
		var tex: Texture2D = load(icon_path)
		if tex == null:
			push_error("아이콘 없음: " + icon_path)
		else:
			up.icon = tex
		var err := ResourceSaver.save(up, path)
		if err == OK:
			done += 1
		else:
			push_error("저장 실패(%d): %s" % [err, path])
	print("tree baked: %d / %d nodes" % [done, TREE.size()])
	quit()
