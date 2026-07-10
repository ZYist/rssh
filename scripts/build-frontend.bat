@echo off
setlocal
rem ============================================================
rem  RSSH frontend-only build (vite)
rem  Fastest compile check (~3s). Use after editing Svelte/TS to
rem  confirm it compiles. No Rust, no NASM, no proxy needed.
rem ============================================================

cd /d "%~dp0.."

echo === Running: npm run build  (frontend only, ~3s) ===
call npm run build
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (echo === BUILD OK ===) else (echo === BUILD FAILED, exit code %RC% ===)
pause
endlocal
