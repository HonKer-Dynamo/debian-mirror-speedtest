# ==================================================
# Debian 镜像站 HTTP 延迟与有效性测速 (Windows PowerShell)
# ==================================================

# 强制使用 TLS 1.2/1.3
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# --- 配置区 (已完美同步截图中的所有官方源+国内极速源) ---
$Mirrors = @(
    # 官方源说明：deb.debian.org 和 ftp.cn.debian.org 为官方调度入口，日常够用
    "deb.debian.org", "ftp.cn.debian.org", "debian-archive.trafficmanager.net",
    
    "mirrors.163.com", "mirrors.ustc.edu.cn", "mirror.lzu.edu.cn",
    "mirrors.bfsu.edu.cn", "mirror.nju.edu.cn", "mirrors.hit.edu.cn",
    "mirrors.neusoft.edu.cn", "mirror.nyist.edu.cn", "mirrors.jlu.edu.cn",
    "mirrors.tuna.tsinghua.edu.cn",
    
    "mirrors.aliyun.com", "mirrors.cloud.tencent.com", "mirrors.huaweicloud.com",
    "mirrors.ctyun.cn", "mirrors.volces.com",
    
    "mirrors.pku.edu.cn", "mirrors.zju.edu.cn", "mirrors.sjtug.sjtu.edu.cn",
    "mirrors.hust.edu.cn", "mirror.iscas.ac.cn", "mirrors.cstcloud.cn"
)

$TestPath = "/debian/ls-lR.gz"
$Rounds = 3
$TimeoutSec = 3
$UserAgent = "Debian APT-HTTP/1.3 (2.7.14)"

$Results = @()

# --- 动态速度格式化函数 ---
function Format-Speed {
    param([double]$BytesPerSec)
    if ($BytesPerSec -ge 1MB) { return ("{0:N2} MB/s" -f ($BytesPerSec / 1MB)) }
    elseif ($BytesPerSec -ge 1KB) { return ("{0:N2} KB/s" -f ($BytesPerSec / 1KB)) }
    else { return ("{0:N0} B/s" -f $BytesPerSec) }
}

# --- TCP 443 端口极速探测 ---
function Test-PortFast {
    param([string]$HostName, [int]$Port = 443, [int]$Timeout = 1000)
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $tcpClient.BeginConnect($HostName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
        if ($wait) { $tcpClient.EndConnect($connect); return $true } 
        else { return $false }
    } catch { return $false } 
    finally { $tcpClient.Close() }
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "      Debian 镜像站 HTTP 延迟与有效性测速 (Windows)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$Codename = Read-Host "请输入你当前的 Debian 版本代号 (如 buster, bullseye, bookworm, trixie) [默认: trixie]"
if ([string]::IsNullOrWhiteSpace($Codename)) { $Codename = "trixie" }
Write-Host "`n当前测试版本: $Codename`n" -ForegroundColor Yellow

foreach ($m in $Mirrors) {
    Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 200)
    Write-Host ("[{0,-40}] " -f $m) -NoNewline

    # 1. TCP 端口检测
    if (-not (Test-PortFast -HostName $m -Port 443 -Timeout 1000)) {
        Write-Host "-> [跳过] 端口不通/宕机" -ForegroundColor DarkGray
        continue
    }

    # 2. InRelease 有效性预检
    $inrelease_url = "https://$m/debian/dists/$Codename/InRelease"
    $httpCode = ""
    try {
        # -4: 强制 IPv4, -L: 跟随重定向, -k: 忽略证书, -A: 伪装 UA
        $httpCode = & curl.exe -4 -L -k -o NUL -s -w "%{http_code}" -A $UserAgent -m $TimeoutSec $inrelease_url 2>$null
        if ($httpCode -eq "000") {
            Start-Sleep -Milliseconds 300
            $httpCode = & curl.exe -4 -L -k -o NUL -s -w "%{http_code}" -A $UserAgent -m $TimeoutSec $inrelease_url 2>$null
        }
    } catch { $httpCode = "000" }

    if ($httpCode -ne "200") {
        if ($httpCode -eq "403") { Write-Host "-> [跳过] 触发防刷策略 (HTTP 403)" -ForegroundColor DarkYellow }
        elseif ($httpCode -eq "000") { Write-Host "-> [跳过] 连接超时 (HTTP 000)" -ForegroundColor DarkGray }
        else { Write-Host "-> [跳过] 元数据无效 (HTTP $httpCode)" -ForegroundColor DarkGray }
        continue
    }

    # 3. 真实测速
    $url = "https://$m$TestPath"
    $totalMs = 0; $totalSpeedBytes = 0; $success = 0

    for ($i = 1; $i -le $Rounds; $i++) {
        $curlOut = & curl.exe -4 -L -k -o NUL -s -w "%{time_total} %{speed_download}" -A $UserAgent -m $TimeoutSec $url 2>$null
        if ($curlOut) {
            $parts = $curlOut -split ' '
            if ($parts.Count -eq 2 -and $parts[0] -match '^\d+\.\d+$') {
                $timeSec = [double]$parts[0]
                $speedBps = [double]$parts[1]
                
                # 过滤掉极小速度 (被拦截假响应)
                if ($speedBps -lt 10240) { continue }

                $totalMs += [math]::Round($timeSec * 1000)
                $totalSpeedBytes += $speedBps
                $success++
            }
        }
    }

    if ($success -gt 0) {
        $avgMs = [math]::Round($totalMs / $success)
        $avgBytes = $totalSpeedBytes / $success
        $avgSpeedStr = Format-Speed -BytesPerSec $avgBytes
        
        Write-Host "-> $avgMs ms | $avgSpeedStr" -ForegroundColor Green
        
        $Results += [PSCustomObject]@{
            Mirror = $m
            Latency = $avgMs
            SpeedBytes = $avgBytes
            SpeedStr = $avgSpeedStr
        }
    } else {
        Write-Host "-> [测速失败/被拦截]" -ForegroundColor Red
    }
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "                      [ 测速结果排名 ]" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

if ($Results.Count -eq 0) {
    Write-Host "所有镜像测试均失败或元数据过期，请检查网络连接。" -ForegroundColor Red
} else {
    $Sorted = $Results | Sort-Object Latency
    $Rank = 1
    foreach ($r in $Sorted) {
        if ($Rank -eq 1) {
            Write-Host ("[最优选] ★ 延迟: {0} ms | 速度: {1} | 镜像: {2}" -f $r.Latency, $r.SpeedStr, $r.Mirror) -ForegroundColor Yellow
        } else {
            Write-Host ("[第 {0,-2} 名] 延迟: {1} ms | 速度: {2} | 镜像: {3}" -f $Rank, $r.Latency, $r.SpeedStr, $r.Mirror)
        }
        $Rank++
    }

    $BestMirror = $Sorted[0].Mirror
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "               [ 推荐配置 (复制到 Linux 执行) ]" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    
    Write-Host "`n>>> 方案 A: 官方推荐的新格式 (适用于 Debian 12+，放入 /etc/apt/sources.list.d/debian.sources)" -ForegroundColor Yellow
    Write-Host "Types: deb" -ForegroundColor Gray
    Write-Host "URIs: https://$BestMirror/debian/" -ForegroundColor Gray
    Write-Host "Suites: $Codename" -ForegroundColor Gray
    Write-Host "Components: main contrib non-free non-free-firmware" -ForegroundColor Gray
    Write-Host "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg`n" -ForegroundColor Gray

    Write-Host "Types: deb" -ForegroundColor Gray
    Write-Host "URIs: https://$BestMirror/debian-security/" -ForegroundColor Gray
    Write-Host "Suites: $Codename-security" -ForegroundColor Gray
    Write-Host "Components: main contrib non-free non-free-firmware" -ForegroundColor Gray
    Write-Host "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg" -ForegroundColor Gray

    Write-Host "`n>>> 方案 B: 传统 sources.list 格式 (适用于所有版本，放入 /etc/apt/sources.list)" -ForegroundColor Yellow
    Write-Host "deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://$BestMirror/debian/ $Codename main contrib non-free non-free-firmware" -ForegroundColor Gray
    Write-Host "deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://$BestMirror/debian-security/ $Codename-security main contrib non-free non-free-firmware" -ForegroundColor Gray
    Write-Host "deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://$BestMirror/debian/ $Codename-updates main contrib non-free non-free-firmware" -ForegroundColor Gray
    Write-Host "========================================================`n" -ForegroundColor Cyan
}

Read-Host "按回车键退出..."