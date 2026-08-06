# 加库兰 上帝之眼 · 自动推送 watcher
# 后台运行: 监视 Real workspace 的 data.json 变化 -> 自动复制 + git push
# 用法: PowerShell 运行  .\auto_push.ps1   (最小化窗口挂着即可)
# 停止: Ctrl+C 或关窗口

$REPO = "C:\Users\CARSER\Desktop\Gakuran\FindHTML"
$SRC = Join-Path $env:LOCALAPPDATA "Real\workspace\GakuranTianYan\data.json"
$DST = Join-Path $REPO "data.json"
$POLL = 10  # 检测间隔(秒)

Write-Host "God-Eye auto-push watcher started" -ForegroundColor Green
Write-Host "Watch: $SRC"
Write-Host "Repo : $REPO  (push to CheckCheats/Gakuran-GodEys)"
Write-Host "Press Ctrl+C to stop`n"

$lastHash = $null
if (Test-Path $DST) {
    $lastHash = (Get-FileHash $DST -Algorithm MD5).Hash
}

while ($true) {
    Start-Sleep -Seconds $POLL
    try {
        if (Test-Path $SRC) {
            $h = (Get-FileHash $SRC -Algorithm MD5).Hash
            if ($h -ne $lastHash) {
                Write-Host ("[{0}] data.json changed, pushing..." -f (Get-Date -Format "HH:mm:ss")) -ForegroundColor Yellow
                Copy-Item $SRC $DST -Force
                Push-Location $REPO
                git add data.json 2>$null
                git commit -m ("god-eye auto data " + (Get-Date -Format "yyyy-MM-dd HH:mm")) 2>$null | Out-Null
                $pushOut = git push 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  -> pushed OK, live site updated" -ForegroundColor Green
                    $lastHash = $h
                } else {
                    Write-Host "  -> push failed: $pushOut" -ForegroundColor Red
                }
                Pop-Location
            }
        }
    } catch {
        Write-Host ("watcher error: " + $_.Exception.Message) -ForegroundColor Red
    }
}