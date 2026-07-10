@echo off
setlocal
rem ============================================================
rem  RSSH build rssh.exe only (skip msi/nsis installer packaging)
rem  Faster than full release when you just want a runnable exe
rem  to test. Injects NASM + Clash proxy.
rem ============================================================

rem --- Environment (edit these two for your machine) ---
set "NASM_DIR=C:\Program Files\NASM"
set "PROXY=http://127.0.0.1:7890"

set "PATH=%NASM_DIR%;%PATH%"
set "HTTPS_PROXY=%PROXY%"
set "HTTP_PROXY=%PROXY%"

cd /d "%~dp0.."

echo === Running: npm run tauri build -- --no-bundle  (rssh.exe only) ===
call npm run tauri build -- --no-bundle
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (echo === BUILD OK ===) else (echo === BUILD FAILED, exit code %RC% ===)
echo Artifact: src-tauri\target\release\rssh.exe
pause
endlocal
