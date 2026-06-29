class_name TreeLinks extends Control
## 패시브 트리의 연결선(노드 사이 가지)과 중앙 허브를 그린다.
## shop_ui가 segs를 채우고 queue_redraw()를 호출한다. 좌표는 캔버스 로컬(허브=원점).

var segs: Array = [] # 각 원소 = {from: Vector2, to: Vector2, on: bool}

const COL_ON := Color(0.42, 0.76, 0.5)   # 양끝 모두 할당된 활성 가지
const COL_OFF := Color(0.3, 0.32, 0.38)  # 아직 잠긴 가지


func _draw() -> void:
	for s: Dictionary in segs:
		var g: float = s.get("grow", 1.0)
		if g <= 0.001:
			continue # 아직 안 뻗은 선분(숨김 노드)
		var endp: Vector2 = s.from.lerp(s.to, g) # grow<1이면 "쭈욱" 자라는 중
		draw_line(s.from, endp, COL_ON if s.on else COL_OFF, 2.0)
	# 중앙 허브(육각 느낌의 링) — 처음엔 이것만 보인다
	draw_circle(Vector2.ZERO, 8.0, Color(0.6, 0.85, 0.65))
	draw_circle(Vector2.ZERO, 5.5, Color(0.12, 0.16, 0.14))
