@echo off
setlocal
rem ============================================================
rem  RSSH full release build -> rssh.exe + msi + nsis installer
rem  Use when you changed Rust code, or want distributable
rem  installers. Injects NASM + Clash proxy.
rem ============================================================

rem --- Environment (edit these two for your machine) ---
set "NASM_DIR=C:\Program Files\NASM"
set "PROXY=http://127.0.0.1:7890"

set "PATH=%NASM_DIR%;%PATH%"
set "HTTPS_PROXY=%PROXY%"
set "HTTP_PROXY=%PROXY%"

cd /d "%~dp0.."

echo === Running: npm run tauri build  (full: exe + msi + nsis) ===
call npm run tauri build
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (echo === BUILD OK ===) else (echo === BUILD FAILED, exit code %RC% ===)
echo Artifacts: src-tauri\target\release\rssh.exe  (+ bundle\msi\*.msi, bundle\nsis\*-setup.exe)
pause
endlocal
