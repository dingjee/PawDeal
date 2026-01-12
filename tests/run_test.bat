@echo off
:: run_test.bat
:: 接收一个参数（测试场景路径），如果为空则运行默认 HArncess

set GODOT_PATH="D:\Software\Godot\Godot_v4.5.1-stable_win64_console.exe"
set TEST_SCENE=%1

if "%TEST_SCENE%"=="" (
    set TEST_SCENE="tests/scenes/universal_test_harness.tscn"
)

echo [Wrapper] Running Godot Test: %TEST_SCENE%
%GODOT_PATH% --path . --headless %TEST_SCENE% 2>&1