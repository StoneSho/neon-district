@echo off
chcp 65001 >nul
cd /d "%~dp0"

rem ── 定位引擎 ──────────────────────────────────────────────
set "GODOT="
rem 验证优先用 _console 版：它会把日志写到 stdout，能抓到完整报错。
if defined GODOT_EXE if exist "%GODOT_EXE%" set "GODOT=%GODOT_EXE%"
if not defined GODOT if exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64_console.exe" set "GODOT=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64_console.exe"
if not defined GODOT if exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe" set "GODOT=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT for /f "delims=" %%F in ('dir /b /s "%USERPROFILE%\Desktop\Godot*console.exe" 2^>nul') do if not defined GODOT set "GODOT=%%F"
if not defined GODOT for /f "delims=" %%F in ('dir /b /s "D:\Godot*.exe" 2^>nul') do if not defined GODOT set "GODOT=%%F"
if not defined GODOT for /f "delims=" %%F in ('dir /b /s "C:\Godot*.exe" 2^>nul') do if not defined GODOT set "GODOT=%%F"

if not defined GODOT (
    echo 找不到 Godot。请设置 GODOT_EXE 环境变量指向 exe 全路径。
    pause
    exit /b 1
)

echo ════════════════════════════════════════════════════
echo   引擎: %GODOT%
"%GODOT%" --version
echo ════════════════════════════════════════════════════
echo.

rem ── 第一步：首次导入资源，生成 .godot 缓存 ────────────────
echo [1/3] 导入资源（首次会比较慢，要处理 82 张图 + 49 个精灵）...
"%GODOT%" --headless --path "%cd%" --import
echo.

rem ── 第二步：逐文件语法/类型校验 ───────────────────────────
echo [2/3] 校验 GDScript ...
set FAIL=0
for %%F in (
    "scripts\core\event_bus.gd"
    "scripts\core\config_db.gd"
    "scripts\core\ui_font.gd"
    "scripts\core\game.gd"
    "scripts\core\main.gd"
    "scripts\sim\resident.gd"
    "scripts\ui\hud.gd"
    "scripts\view\district_view.gd"
    "scripts\view\sprite_bank.gd"
) do (
    "%GODOT%" --headless --path "%cd%" --check-only --script "%%~F" >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] %%~F
        set FAIL=1
    ) else (
        echo   [ ok ] %%~F
    )
)
echo.

rem ── 第三步：空跑若干帧，抓运行时错误 ──────────────────────
echo [3/3] 空跑 300 帧，捕获运行时报错 ...
"%GODOT%" --headless --path "%cd%" --quit-after 300 2>&1 | findstr /i "error script warning SCRIPT" && echo   ^(以上为捕获到的告警^) || echo   无报错输出
echo.

echo ════════════════════════════════════════════════════
if "%FAIL%"=="1" (
    echo   结果: 有脚本校验失败，见上方 [FAIL] 行
) else (
    echo   结果: 全部脚本通过校验
)
echo ════════════════════════════════════════════════════
pause
