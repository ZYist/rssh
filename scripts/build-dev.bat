@echo off
setlocal
rem ============================================================
rem  RSSH dev mode -- hot-reload, launches the app for live
rem  editing. Injects NASM (Rust compile) + Clash proxy.
rem  Stays running; press Ctrl+C in this window to stop.
rem ============================================================

rem --- Environment (edit these two for your machine) ---
set "NASM_DIR=C:\Program Files\NASM"
set "PROXY=http://127.0.0.1:7890"

set "PATH=%NASM_DIR%;%PATH%"
set "HTTPS_PROXY=%PROXY%"
set "HTTP_PROXY=%PROXY%"

cd /d "%~dp0.."

echo === Running: npm run tauri dev  (hot-reload, Ctrl+C to stop) ===
call npm run tauri dev
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (echo === DEV EXITED OK ===) else (echo === DEV EXITED, code %RC% ===)
pause
endlocal
