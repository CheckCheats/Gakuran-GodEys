@echo off
chcp 65001 >nul
setlocal

echo ==============================
echo   加库兰 上帝之眼 · 一键推送
echo ==============================

REM 1) 从 Real workspace 复制扫描结果
set SRC=%LOCALAPPDATA%\Real\workspace\GakuranTianYan\data.json
set DST=%~dp0data.json

if exist "%SRC%" (
  copy /y "%SRC%" "%DST%" >nul
  echo [1/3] 已复制最新扫描数据
) else (
  echo [错误] 找不到扫描数据: "%SRC%"
  echo        请先运行游戏内 scan_gakuran.luau 生成数据
  goto :fail
)

REM 2) 校验
node -e "const d=require('%DST%');console.log('[2/3] '+d.players.length+' 人, 头像 '+d.players.filter(x=>x.avatar).length)" 2>nul

REM 3) git 提交 + 推送
cd /d "%~dp0"
git add data.json
git commit -m "god-eye data update" 2>nul
git push

echo.
echo ✅ 已同步到 GitHub, 天眼已更新!
echo    https://checkcheats.github.io/Gakuran-GodEys/
pause
goto :eof

:fail
echo ❌ 推送中止
pause