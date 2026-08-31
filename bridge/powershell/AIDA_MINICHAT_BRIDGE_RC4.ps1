$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$BaseDir = $PSScriptRoot
$ConfigPath = Join-Path $BaseDir "bridge_config.json"
$LogPath = Join-Path $BaseDir "AIDA_MiniChat_Bridge.log"
$DedupePath = Join-Path $BaseDir "bridge_seen.json"

function Write-BridgeLog([string]$Text, [string]$Level = "INFO") {
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Text
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Load-Config {
    if (-not (Test-Path $ConfigPath)) { throw "Не найден bridge_config.json" }
    return (Get-Content -Raw -Encoding UTF8 $ConfigPath | ConvertFrom-Json)
}

function Normalize-Text([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    return (($Value.Trim() -replace '\s+', ' ').ToUpperInvariant())
}

function Test-AidaPort([string]$ApiUrl) {
    try {
        $uri = [Uri]$ApiUrl
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $iar = $client.BeginConnect($uri.Host, $uri.Port, $null, $null)
            if (-not $iar.AsyncWaitHandle.WaitOne(1200, $false)) { return $false }
            $client.EndConnect($iar)
            return $client.Connected
        }
        finally { $client.Close() }
    }
    catch { return $false }
}

function Is-SupportedUrl([string]$Url) {
    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    try { $uri = [Uri]$Url } catch { return $false }
    if ($uri.Scheme -ne "http" -and $uri.Scheme -ne "https") { return $false }
    $urlHost = $uri.Host.ToLowerInvariant()
    $path = $uri.AbsolutePath.ToLowerInvariant()
    if ($urlHost -eq "youtu.be") { return $true }
    if ($urlHost -eq "youtube.com" -or $urlHost.EndsWith(".youtube.com")) { return $true }
    if ($urlHost -eq "music.yandex.ru" -or $urlHost -eq "music.yandex.com") { return $true }
    if ($urlHost -eq "vk.com" -or $urlHost -eq "www.vk.com" -or $urlHost -eq "vk.ru" -or $urlHost -eq "www.vk.ru") { return $path.StartsWith("/video") }
    if ($urlHost -eq "vkvideo.ru" -or $urlHost.EndsWith(".vkvideo.ru")) {
        if ($urlHost.StartsWith("images.")) { return $false }
        if ($path.StartsWith("/user/")) { return $false }
        return $true
    }
    return $false
}

function Get-SupportedUrl($Data) {
    foreach ($part in @($Data.MessageKit)) {
        if ($null -eq $part) { continue }
        if (([string]$part.Type) -ine "URL") { continue }
        $candidate = [string]$part.Data.URL
        if (Is-SupportedUrl $candidate) { return $candidate.Trim() }
    }
    $message = [string]$Data.Message
    if (-not [string]::IsNullOrWhiteSpace($message)) {
        $matches = [regex]::Matches($message, 'https?://[^\s"''<>\\]+', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($match in $matches) {
            $candidate = $match.Value.Trim().TrimEnd('.', ',', ';', ':', '!', ')', ']', '}')
            if (Is-SupportedUrl $candidate) { return $candidate }
        }
    }
    return ""
}

function Load-Seen([int]$TtlSeconds) {
    $result = @{}
    if (Test-Path $DedupePath) {
        try {
            $obj = Get-Content -Raw -Encoding UTF8 $DedupePath | ConvertFrom-Json
            foreach ($p in $obj.PSObject.Properties) { $result[$p.Name] = [long]$p.Value }
        } catch { Write-BridgeLog "Файл дедупликации повреждён, создаю заново." "WARN" }
    }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    foreach ($k in @($result.Keys)) { if (($now - [long]$result[$k]) -gt $TtlSeconds) { $result.Remove($k) } }
    return $result
}

function Save-Seen($Seen) {
    $ordered = [ordered]@{}
    foreach ($k in $Seen.Keys) { $ordered[$k] = [long]$Seen[$k] }
    ($ordered | ConvertTo-Json -Depth 4) | Set-Content -Path $DedupePath -Encoding UTF8
}

function Get-EventKey($Data, [string]$Url) {
    $guid = [string]$Data.GUID
    if (-not [string]::IsNullOrWhiteSpace($guid)) { return "guid:" + $guid.Trim() }
    $source = "{0}|{1}|{2}|{3}|{4}" -f ([string]$Data.Service), ([string]$Data.UserID), ([string]$Data.Name), $Url, ([string]$Data.Date)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($source)
        $hash = $sha.ComputeHash($bytes)
        return "sha256:" + (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    } finally { $sha.Dispose() }
}

function Send-MiniChatMessage($Ws, [string]$Service, [string]$Message) {
    $payload = @{ Type = "Message"; Data = @{ Service = $Service; Message = $Message; Hide = $false } } | ConvertTo-Json -Depth 8 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $segment = [ArraySegment[byte]]::new($bytes)
    $Ws.SendAsync($segment,[System.Net.WebSockets.WebSocketMessageType]::Text,$true,[Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
}

function Receive-WebSocketText($Ws) {
    $buffer = New-Object byte[] 65536
    $segment = [ArraySegment[byte]]::new($buffer)
    $ms = New-Object System.IO.MemoryStream
    try {
        do {
            $result = $Ws.ReceiveAsync($segment,[Threading.CancellationToken]::None).GetAwaiter().GetResult()
            if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { return $null }
            $ms.Write($buffer, 0, $result.Count)
        } while (-not $result.EndOfMessage)
        return [Text.Encoding]::UTF8.GetString($ms.ToArray())
    } finally { $ms.Dispose() }
}

function Submit-ToAida([string]$ApiUrl, [string]$UserName, [string]$Url) {
    $payload = @{ nick = $UserName; message = $Url; source = "VK Video Live — AIDA MUSIC Direct" } | ConvertTo-Json -Compress
    $lastError = ""
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300
            return [pscustomobject]@{ Accepted = (($response.ok -eq $true) -or ($response.accepted -eq $true)); Message = [string]$response.message; ErrorCode = [string]$response.error }
        }
        catch { $lastError = $_.Exception.Message; if ($attempt -lt 2) { Start-Sleep -Seconds 1 } }
    }
    return [pscustomobject]@{ Accepted = $false; Message = "AIDA Music Orders не ответила"; ErrorCode = "api_unavailable"; Detail = $lastError }
}

$config = Load-Config
if ($config.enabled -ne $true) { Write-Host "AIDA MiniChat Bridge отключён в bridge_config.json"; exit 0 }
$rewardNormalized = Normalize-Text ([string]$config.reward_name)
$ttl = [int]$config.dedupe_ttl_seconds
$seen = Load-Seen $ttl

Write-Host "========================================================"
Write-Host " AIDA Music Orders v1.0.4 - MiniChat Bridge RC4"
Write-Host "========================================================"
Write-Host "Streamer.bot для AIDA MUSIC НЕ НУЖЕН."
Write-Host "Возврат баллов при отказе НЕ выполняется."
Write-Host ""

if (Test-AidaPort ([string]$config.aida_order_api)) { Write-BridgeLog "AIDA API ONLINE: 127.0.0.1:18765" }
else { Write-BridgeLog "AIDA API OFFLINE: сначала запусти AIDA Music Orders и открой заказы." "WARN" }

$backoff = @(1, 2, 5)
$attempt = 0
while ($true) {
    $ws = $null
    try {
        Write-BridgeLog ("Подключение к MiniChat: " + [string]$config.minichat_ws)
        $ws = [System.Net.WebSockets.ClientWebSocket]::new()
        $ws.ConnectAsync([Uri]([string]$config.minichat_ws),[Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
        Write-BridgeLog "MiniChat CONNECTED."
        Write-BridgeLog ("Ожидаю награду: " + [string]$config.reward_name)
        $attempt = 0
        while ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $raw = Receive-WebSocketText $ws
            if ($null -eq $raw) { throw "MiniChat закрыл WebSocket." }
            try { $frame = $raw | ConvertFrom-Json } catch { Write-BridgeLog "Пропущен некорректный JSON от MiniChat." "WARN"; continue }
            if (([string]$frame.Type) -ine "Live") { continue }
            $data = $frame.Data
            if ($null -eq $data) { continue }
            if (([string]$data.Type) -ine "Reward") { continue }
            if ((Normalize-Text ([string]$data.Name)) -ne $rewardNormalized) { continue }
            $service = [string]$data.Service
            $userName = [string]$data.UserName
            if ([string]::IsNullOrWhiteSpace($userName)) { $userName = "Неизвестный зритель" }
            $url = Get-SupportedUrl $data
            $eventKey = Get-EventKey $data $url
            $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            if ($seen.ContainsKey($eventKey) -and (($now - [long]$seen[$eventKey]) -le $ttl)) { Write-BridgeLog ("DUPLICATE ignored: " + $eventKey); continue }
            $seen[$eventKey] = $now
            Save-Seen $seen
            Write-BridgeLog ("REWARD | user=" + $userName + " | service=" + $service + " | url=" + $url)
            if ([string]::IsNullOrWhiteSpace($url)) {
                if ($config.reply_on_reject -eq $true) { Send-MiniChatMessage $ws $service "↩️ @$userName, в награде не найдена ссылка на YouTube, VK Video или Яндекс Музыку." }
                Write-BridgeLog "REJECTED: missing_link" "WARN"
                continue
            }
            if (-not (Test-AidaPort ([string]$config.aida_order_api))) {
                if ($config.reply_on_reject -eq $true) { Send-MiniChatMessage $ws $service "↩️ @$userName, AIDA Music Orders сейчас не запущена. Заказ не добавлен." }
                Write-BridgeLog "REJECTED: api_offline_before_post" "WARN"
                continue
            }
            $result = Submit-ToAida ([string]$config.aida_order_api) $userName $url
            if ($result.Accepted) {
                if ($config.reply_on_accept -eq $true) { Send-MiniChatMessage $ws $service "🎵 @$userName, заказ принят и добавлен в очередь." }
                Write-BridgeLog "ACCEPTED -> AIDA queue"
            } else {
                $reason = [string]$result.Message
                if ([string]::IsNullOrWhiteSpace($reason)) { $reason = "заказ не принят" }
                $reason = $reason.Trim().TrimEnd('.', '!', '?', ' ')
                if ($config.reply_on_reject -eq $true) { Send-MiniChatMessage $ws $service "↩️ @$userName, $reason." }
                Write-BridgeLog ("REJECTED: " + [string]$result.ErrorCode + " | " + $reason) "WARN"
            }
        }
    } catch { Write-BridgeLog ("Соединение MiniChat потеряно: " + $_.Exception.Message) "WARN" }
    finally { if ($null -ne $ws) { try { $ws.Abort() } catch {}; try { $ws.Dispose() } catch {} } }
    $wait = $backoff[[Math]::Min($attempt, $backoff.Count - 1)]
    Write-BridgeLog ("Повторное подключение к MiniChat через " + $wait + " сек...")
    Start-Sleep -Seconds $wait
    if ($attempt -lt ($backoff.Count - 1)) { $attempt++ }
}
