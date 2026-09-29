@echo off
chcp 65001 >nul
cd /d "%~dp0"

rem 优先使用 GODOT_EXE 环境变量；否则按下面的候选路径依次查找。
set "GODOT="

if defined GODOT_EXE if exist "%GODOT_EXE%" set "GODOT=%GODOT_EXE%"

rem 启动编辑器用无控制台的 GUI 版，避免多一个黑窗口。
if not defined GODOT call :probe "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT call :probe "D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT call :probe "D:\Godot\godot.exe"
if not defined GODOT call :probe "C:\Godot\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT call :probe "%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe"

rem 兜底：桌面 / D: / C: 下搜 Godot*.exe，排除 console 版
if not defined GODOT for /f "delims=" %%F in ('dir /b /s "%USERPROFILE%\Desktop\Godot*.exe" 2^>nul ^| findstr /v /i "console"') do if not defined GODOT set "GODOT=%%F"
if not defined GODOT for /f "delims=" %%F in ('dir /b /s "D:\Godot*.exe" 2^>nul ^| findstr /v /i "console"') do if not defined GODOT set "GODOT=%%F"
if not defined GODOT for /f "delims=" %%F in ('dir /b /s "C:\Godot*.exe" 2^>nul ^| findstr /v /i "console"') do if not defined GODOT set "GODOT=%%F"

if not defined GODOT goto :notfound

echo 使用引擎: %GODOT%
start "" "%GODOT%" --path "%cd%"
exit /b 0

:probe
if exist "%~1" set "GODOT=%~1"
exit /b 0

:notfound
echo.
echo   找不到 Godot 引擎。
echo.
echo   请下载 Godot 4.7.x 标准版（非 .NET 版）放到桌面或 D:\Godot\
echo   下载地址: https://godotengine.org/download/windows/
echo.
echo   或者设置环境变量指向 exe 全路径，例如:
echo       set GODOT_EXE=E:\tools\Godot_v4.7.2-stable_win64.exe
echo.
pause
exit /b 1
