extends SceneTree
## 일회성: 코드-생성 맵을 각 지역 씬에 구워넣는다(bake).
## 안전: 씬 전체를 다시 pack하지 않고, _paint_map으로 만든 tile_map_data 한 줄만
## .tscn 텍스트에 주입한다 → 건물/스폰존 등 나머지는 전혀 건드리지 않음.
## 실행: godot --headless --path . --script res://tools/bake_maps.gd

func _init() -> void:
	for path in ["res://scenes/field/Field.tscn", "res://scenes/field/Region2.tscn"]:
		var ps: PackedScene = load(path)
		var root = ps.instantiate()
		var tml: TileMapLayer = root.get_node("TileMapLayer")
		root.set("_tiles", tml)
		root.call("_paint_map")
		var b64 := Marshalls.raw_to_base64(tml.tile_map_data)
		var line := 'tile_map_data = PackedByteArray("%s")' % b64

		var f := FileAccess.open(path, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		# TileMapLayer 노드의 tile_set 줄 바로 뒤에 주입 (기존 tile_map_data 있으면 교체)
		var tm := text.find('name="TileMapLayer"')
		var ts := text.find("tile_set = ", tm)
		var nl := text.find("\n", ts)
		# 다음 줄이 이미 tile_map_data면 제거 후 재주입 (멱등)
		var after := text.substr(nl + 1)
		if after.begins_with("tile_map_data = "):
			after = after.substr(after.find("\n") + 1)
		text = text.substr(0, nl + 1) + line + "\n" + after

		var w := FileAccess.open(path, FileAccess.WRITE)
		w.store_string(text)
		w.close()
		print("%s baked: %d cells" % [path, tml.get_used_cells().size()])
		root.free()
	quit()
