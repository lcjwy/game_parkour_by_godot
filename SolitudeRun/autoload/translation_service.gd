extends Node
## 简单内置多语言表。后续可替换为 CSV/.translation 导入流程。

signal locale_changed(locale: String)

const SUPPORTED_LOCALES: Array[String] = ["zh", "en", "ko"]
const MESSAGES: Dictionary = {
	"zh": {
		"game.title": "孤独跑酷",
		"menu.start": "开始",
		"menu.settings": "设置",
		"menu.map": "地图",
		"menu.audio": "音效",
		"menu.price": "中国地区 1 RMB，其他地区 1 USD",
		"settings.language": "语言",
		"settings.resolution": "分辨率",
		"settings.master_volume": "主音量",
		"settings.sfx_volume": "音效音量",
		"settings.controller": "手柄支持",
		"settings.keybinds": "键位",
		"settings.back": "返回",
		"map.desert": "沙漠",
		"map.desert.desc": "大漠孤烟直，长河落日圆。没有建筑，只有风、沙和远方。",
		"map.jungle": "草原",
		"map.jungle.desc": "开阔草地、晴朗天空和偶尔吹过的轻风。",
		"audio.wind": "荒漠风声",
		"audio.rain": "草原微风",
		"audio.engine": "低沉引擎",
		"hud.played": "已游玩",
		"toast.one_hour": "已经坚持1小时",
		"toast.two_half_hours": "放弃也许会更好，欢迎再次体验",
		"result.failed": "未达到终点，放弃也许是一种更好的选择。",
		"result.released_accelerate": "你松开了 W 键，本局结束。",
		"result.success": "你也许浪费了3小时，但是超越孤独的勇者，人生的意义就在对抗孤独。",
		"result.back": "返回主菜单"
	},
	"en": {
		"game.title": "Solitude Run",
		"menu.start": "Start",
		"menu.settings": "Settings",
		"menu.map": "Map",
		"menu.audio": "Sound",
		"menu.price": "China: 1 RMB. Other regions: 1 USD.",
		"settings.language": "Language",
		"settings.resolution": "Resolution",
		"settings.master_volume": "Master Volume",
		"settings.sfx_volume": "SFX Volume",
		"settings.controller": "Controller",
		"settings.keybinds": "Keybinds",
		"settings.back": "Back",
		"map.desert": "Desert",
		"map.desert.desc": "A lone smoke column over the vast desert; a long river under the setting sun.",
		"map.jungle": "Grassland",
		"map.jungle.desc": "Open grass, clear sky, and occasional soft wind.",
		"audio.wind": "Desert Wind",
		"audio.rain": "Grassland Breeze",
		"audio.engine": "Low Engine",
		"hud.played": "Played",
		"toast.one_hour": "You have endured 1 hour.",
		"toast.two_half_hours": "Giving up may be better. Welcome back anytime.",
		"result.failed": "You did not reach the finish. Giving up may be a better choice.",
		"result.released_accelerate": "You released W. This run is over.",
		"result.success": "You may have wasted 3 hours, but a hero who surpasses loneliness finds meaning in resisting it.",
		"result.back": "Back to Menu"
	},
	"ko": {
		"game.title": "고독의 주행",
		"menu.start": "시작",
		"menu.settings": "설정",
		"menu.map": "맵",
		"menu.audio": "효과음",
		"menu.price": "중국 1 RMB, 기타 지역 1 USD",
		"settings.language": "언어",
		"settings.resolution": "해상도",
		"settings.master_volume": "마스터 볼륨",
		"settings.sfx_volume": "효과음 볼륨",
		"settings.controller": "컨트롤러",
		"settings.keybinds": "키 설정",
		"settings.back": "뒤로",
		"map.desert": "사막",
		"map.desert.desc": "넓은 사막의 외로운 연기와 지는 해 아래 긴 강.",
		"map.jungle": "초원",
		"map.jungle.desc": "넓은 풀밭, 맑은 하늘, 가끔 스치는 산들바람.",
		"audio.wind": "사막 바람",
		"audio.rain": "초원 산들바람",
		"audio.engine": "낮은 엔진음",
		"hud.played": "플레이 시간",
		"toast.one_hour": "1시간을 버텼습니다.",
		"toast.two_half_hours": "포기하는 편이 더 나을지도 모릅니다. 다시 찾아와 주세요.",
		"result.failed": "종점에 도달하지 못했습니다. 포기도 더 나은 선택일 수 있습니다.",
		"result.released_accelerate": "W 키를 놓았습니다. 이번 주행은 종료됩니다.",
		"result.success": "당신은 3시간을 낭비했을지 모릅니다. 그러나 고독을 넘어선 용자에게 삶의 의미는 고독에 맞서는 데 있습니다.",
		"result.back": "메뉴로"
	}
}

var _locale: String = "zh"

func _ready() -> void:
	_locale = SettingsManager.locale
	SettingsManager.locale_changed.connect(set_locale)

func set_locale(value: String) -> void:
	if not SUPPORTED_LOCALES.has(value):
		value = "en"
	if _locale == value:
		return
	_locale = value
	locale_changed.emit(_locale)

func current_locale() -> String:
	return _locale

func text(key: String) -> String:
	var table: Dictionary = MESSAGES.get(_locale, MESSAGES["en"])
	return str(table.get(key, key))
