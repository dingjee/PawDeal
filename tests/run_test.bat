@echo off
:: run_test.bat - Windows 版本的测试运行脚本
:: 用法: 
::   .\tests\run_test.bat <path_to_scene.tscn>           # headless 模式（无 GUI，适合逻辑测试）
::   .\tests\run_test.bat <path_to_scene.tscn> --gui     # GUI 模式（有窗口，适合 UI 截图测试）
::
:: 功能:
:: 1. 运行指定的测试场景
:: 2. GUI 模式下支持自动截图保存到 tests/snapshots/ 目录

set GODOT_PATH="D:\Software\Godot\Godot_v4.5.1-stable_win64_console.exe"
set TEST_SCENE=%1
set GUI_FLAG=%2
set HEADLESS_FLAG=--headless

if "%TEST_SCENE%"=="" (
    set TEST_SCENE="res://tests/scenes/universal_test_harness.tscn"
)

:: 检查是否使用 GUI 模式
if "%GUI_FLAG%"=="--gui" (
    set HEADLESS_FLAG=
    echo [Wrapper] Mode: GUI (with window)
) else (
    echo [Wrapper] Mode: Headless (no GUI)
)

echo [Wrapper] Running Godot Test: %TEST_SCENE%
%GODOT_PATH% --path . %HEADLESS_FLAG% %TEST_SCENE% 2>&1