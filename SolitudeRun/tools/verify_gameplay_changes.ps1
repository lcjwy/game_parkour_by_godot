param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Read-ProjectFile([string]$RelativePath) {
    return Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $RelativePath)
}

function Assert-Contains([string]$Content, [string]$Pattern, [string]$Message) {
    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotContains([string]$Content, [string]$Pattern, [string]$Message) {
    if ($Content -match $Pattern) {
        throw $Message
    }
}

$gameRoot = Read-ProjectFile 'scripts/game/game_root.gd'
$audioManager = Read-ProjectFile 'autoload/audio_manager.gd'
$mainMenu = Read-ProjectFile 'scripts/ui/main_menu.gd'
$settingsManager = Read-ProjectFile 'autoload/settings_manager.gd'
$roadGenerator = Read-ProjectFile 'scripts/world/road_generator.gd'
$weatherSystem = Read-ProjectFile 'scripts/world/weather_system.gd'
$grasslandMap = Read-ProjectFile 'resources/maps/jungle.tres'
$translations = Read-ProjectFile 'autoload/translation_service.gd'

Assert-NotContains $audioManager 'play_preset\(GameState\.selected_audio_preset\(\)\)' 'AudioManager must not auto-play before the run starts.'
Assert-NotContains $mainMenu 'func _start_game\(\) -> void:[\s\S]*AudioManager\.play_preset' 'Start button must not play audio before entering the run.'
Assert-Contains $gameRoot '_begin_driving\(\)' 'GameRoot should start audio only when countdown finishes.'
Assert-Contains $gameRoot '_fail_run\("result\.released_accelerate"\)' 'Releasing W/accelerate during gameplay should fail immediately.'
Assert-Contains $gameRoot 'const ACCELERATE_GRACE_SECONDS: float = 5\.0' 'W/accelerate release detection should start after a 5 second grace period.'
Assert-Contains $gameRoot '_elapsed >= ACCELERATE_GRACE_SECONDS' 'W/accelerate release detection should be delayed by elapsed run time.'
Assert-Contains $settingsManager 'var control_hint_position: StringName = &"top_center"' 'Control hint position should default to top center.'
Assert-Contains $settingsManager 'func set_control_hint_position\(value: StringName\) -> void:' 'Control hint position should be configurable before starting.'
Assert-Contains $mainMenu '_hint_position_option' 'Main menu should expose a control hint position option.'
Assert-Contains $gameRoot '_control_hint_label' 'Game HUD should display a forward/boost key hint.'
Assert-Contains $gameRoot '_apply_control_hint_position\(\)' 'Game HUD should apply the configured edge position.'
Assert-Contains $translations '"hud\.controls":' 'HUD control hint text should be translated.'

Assert-Contains $grasslandMap 'id = &"grassland"' 'The former jungle map should become grassland.'
Assert-Contains $grasslandMap 'atmosphere = &"grassland"' 'Grassland map should use grassland atmosphere.'
Assert-Contains $grasslandMap 'weather_enabled = false' 'Grassland should not have constant rain.'
Assert-Contains $translations '"map\.jungle": "草原"' 'Chinese map label should show grassland.'
Assert-Contains $translations '"map\.jungle": "Grassland"' 'English map label should show grassland.'

Assert-Contains $weatherSystem '_build_grassland_breeze\(\)' 'WeatherSystem should use a non-rain grassland effect.'
Assert-Contains $roadGenerator '_rebuild_desert_plants' 'RoadGenerator should add desert plant decoration.'
Assert-Contains $roadGenerator 'const RIDGE_INTERVAL: int = 7' 'Desert dunes should be denser.'
Assert-Contains $roadGenerator 'const ROAD_CURVE_SUBDIVISIONS: int = 4' 'Road mesh should use subdivision sampling for smoother curves.'
Assert-Contains $roadGenerator 'var road_rows := visible_segments \* ROAD_CURVE_SUBDIVISIONS' 'Road mesh should generate more longitudinal rows than terrain segments.'
Assert-Contains $roadGenerator 'var road_step := segment_length / float\(ROAD_CURVE_SUBDIVISIONS\)' 'Road mesh should sample curve points at sub-segment intervals.'

Write-Host 'Gameplay change verification passed.'
