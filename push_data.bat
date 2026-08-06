@echo off
setlocal

echo ==============================
echo   Gakuran God-Eye - Push Data
echo ==============================

REM 1) Copy scan result from Real workspace
set SRC=%LOCALAPPDATA%\Real\workspace\GakuranTianYan\data.json
set DST=%~dp0data.json

if exist "%SRC%" (
  copy /y "%SRC%" "%DST%" >nul
  echo [1/3] Copied latest scan data
) else (
  echo [ERROR] Could not find scan data at "%SRC%"
  echo         Run scan_gakuran.luau in-game first.
  goto :fail
)

REM 2) validate via node (best effort)
where node >nul 2>&1
if not errorlevel 1 (
  node -e "var fs=require('fs');var d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));console.log('[2/3] '+d.players.length+' players, '+d.players.filter(function(x){return x.avatar}).length+' avatars')" "%DST%"
) else (
  echo [2/3] node not found, skip validation
)

REM 3) git commit + push
cd /d "%~dp0"
git add data.json
git commit -m "god-eye data update" 2>nul
git push -u origin main

echo.
echo [OK] Synced to GitHub. Live site updated!
echo  https://checkcheats.github.io/Gakuran-GodEys/
pause
goto :eof

:fail
echo [ERROR] Push aborted.
pause