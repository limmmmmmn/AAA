class_name TownFmt
## 마을 오브젝트 쿨타임 표시용 시간 포맷 (공유).

static func time(sec: float) -> String:
	var s := int(ceil(sec))
	if s >= 60:
		return "%d:%02d" % [s / 60, s % 60]
	return "%ds" % s
