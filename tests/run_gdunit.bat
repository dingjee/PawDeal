@echo off
:: run_gdunit.bat - Windows 版本的 GdUnit4 测试运行脚本
:: 
:: 用法: 
::   .\tests\run_gdunit.bat                              # 运行所有 GdUnit4 测试
::   .\tests\run_gdunit.bat tests/gdunit/test_xxx.gd    # 运行指定测试文件
::   .\tests\run_gdunit.bat tests/gdunit/ --gui         # GUI 模式运行
::
:: 功能:
:: 1. 运行 GdUnit4 测试套件
:: 2. 支持 GUI 模式查看测试过程
:: 3. 报告输出到 tests/reports/ 目录

set GODOT_PATH="D:\Software\Godot\Godot_v4.6-stable_win64_console.exe"
set TEST_PATH=%1
set GUI_FLAG=%2
set REPORT_DIR=tests/reports

:: 默认测试路径
if "%TEST_PATH%"=="" (
    set TEST_PATH="res://tests/gdunit/"
)

:: 检查是否使用 GUI 模式
if "%GUI_FLAG%"=="--gui" (
    set HEADLESS_FLAG=
    echo [GdUnit4] Mode: GUI (with window)
) else (
    set HEADLESS_FLAG=--headless
    echo [GdUnit4] Mode: Headless (ignoring headless mode check)
)

echo [GdUnit4] Running tests: %TEST_PATH%
echo [GdUnit4] Reports will be saved to: %REPORT_DIR%
echo ==========================================

:: 使用 --ignoreHeadlessMode 跳过 headless 模式检查
:: 使用 --report-directory 指定报告输出目录
%GODOT_PATH% %HEADLESS_FLAG% --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --report-directory %REPORT_DIR% --add %TEST_PATH% 2>&1

echo ==========================================
echo [GdUnit4] Tests completed
