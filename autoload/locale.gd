extends Node
## 언어 전환 + 언어별 폰트. 추천 ②번 방식: 언어를 바꾸면 폰트도 통째로 바뀐다.
## 영문 = Pixel Operator 3단(본문/강조/제목), 한글 = 둥근모꼴. 한 화면에 섞이지 않는다.
## 표시 문자열은 TranslationServer(번역 CSV)로 처리 — 정적 라벨은 auto_translate, 동적/포맷은 Locale.t().
##
## 위계: 본문(얇게) / "Bold" 타입(굵게: 골드·코드·슬롯) / "Title" 타입(스몰캡 볼드: 패널 제목).
## 라벨은 theme_type_variation = "Bold"/"Title"로 골라 쓴다 (없으면 본문).

## 영문 3단 (있어보이는 위계): 본문=얇게, 강조=굵게, 제목=스몰캡 볼드.
const EN_BODY := "res://assets/Fonts/PixelOperator.ttf"
const EN_BOLD := "res://assets/Fonts/PixelOperator-Bold.ttf"
const EN_TITLE := "res://assets/Fonts/PixelOperatorSC-Bold.ttf"
const KO_FONT := "res://assets/Fonts/DungGeunMo.ttf"
const THEME := "res://assets/Fonts/ui_theme.tres"

const SUPPORTED := ["ko", "en"]


func _ready() -> void:
	apply(GameState.language)


## 현재 언어로 번역 (포맷 문자열·RefCounted 등 tr() 못 쓰는 곳에서 사용).
func t(key: String) -> String:
	return TranslationServer.translate(key)


func current() -> String:
	return GameState.language


## 한국어 ↔ English 순환 토글.
func toggle() -> void:
	var i := SUPPORTED.find(GameState.language)
	set_language(SUPPORTED[(i + 1) % SUPPORTED.size()])


func set_language(lang: String) -> void:
	if lang == GameState.language or not SUPPORTED.has(lang):
		return
	GameState.language = lang
	GameState.save_game()
	apply(lang)
	EventBus.language_changed.emit()


## 로케일 + 폰트를 적용한다. 시작 시·전환 시 공통.
## 본문/"Bold"/"Title" 세 슬롯을 한 번에 채운다 (한글은 둥근모 단일 — 위계는 크기로).
func apply(lang: String) -> void:
	TranslationServer.set_locale(lang)
	var theme := load(THEME) as Theme
	if theme == null:
		return
	# theme_type_variation이 먹으려면 변형을 등록해야 한다 (Control 기반 → Label·Button 공통).
	theme.set_type_variation("Bold", "Control")
	theme.set_type_variation("Title", "Control")
	if lang == "ko":
		var ko := _font(KO_FONT)
		theme.default_font = ko
		theme.set_font("font", "Bold", ko)
		theme.set_font("font", "Title", ko)
	else:
		theme.default_font = _font(EN_BODY)
		theme.set_font("font", "Bold", _font(EN_BOLD))
		theme.set_font("font", "Title", _font(EN_TITLE))


func _font(path: String) -> FontFile:
	var f := load(path) as FontFile
	if f:
		# 이모지/특수문자만 시스템 폰트로 폴백 (라틴·한글·숫자는 폰트가 직접 담당)
		var emoji := SystemFont.new()
		emoji.font_names = PackedStringArray(["Segoe UI Emoji", "Malgun Gothic"])
		f.fallbacks = [emoji]
	return f
