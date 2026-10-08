# Web sürümünü hazırlar (M1-13, architecture.md §14): yayın çıktısı + itch.io'ya yüklenecek zip.
# Kullanım: powershell -NoProfile -ExecutionPolicy Bypass -File tools/web_build.ps1 [-Smoke] [-Shot <png>]
# -Smoke: ayrıca debug çıktısını yerel sunucuda görünmez Edge/Chrome ile açar; olay günlüğünü
#         (EVENT satırları) ve isteğe bağlı ekran görüntüsünü (-Shot) gösterir. Oyun açılmadıysa çıkış 1.
param(
	[string]$Godot = "C:\Users\burak\Godot\Godot_v4.7.2-stable_win64_console.exe",
	[switch]$Smoke,
	[string]$Shot = "",
	[int]$WaitSeconds = 15
)

$root = Split-Path -Parent $PSScriptRoot
$release = Join-Path $root "builds\web"
$zip = Join-Path $root "builds\gravity-hopper-web.zip"

function Export-Web([string]$mode, [string]$dir) {
	New-Item -ItemType Directory -Force -Path $dir | Out-Null
	Get-ChildItem $dir -File | ForEach-Object { [IO.File]::Delete($_.FullName) }
	$log = & $Godot --headless --path $root "--export-$mode" "Web" (Join-Path $dir "index.html") 2>&1 | ForEach-Object { "$_" }
	if ($LASTEXITCODE -ne 0) { Write-Output "DIŞA AKTARMA BAŞARISIZ ($mode):"; $log | Where-Object { $_ -match "ERROR" }; exit 1 }
}

# 1) Yayın çıktısı ve zip (index.html zip'in kökünde olmalı)
Export-Web "release" $release
if (Test-Path $zip) { [IO.File]::Delete($zip) }
Compress-Archive -Path (Join-Path $release "*") -DestinationPath $zip
Write-Output "OK   yayın çıktısı: $release"
Write-Output "OK   itch.io zip: $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"
if (-not $Smoke) { exit 0 }

# 2) Tarayıcı denemesi: debug çıktısı (olay günlüğünü konsola yazar), yerel sunucu, görünmez tarayıcı
$debugDir = Join-Path $root "builds\web_debug"
Export-Web "debug" $debugDir
$browser = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Google\Chrome\Application\chrome.exe") |
	Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { Write-Output "TARAYICI YOK: Edge ya da Chrome bulunamadı"; exit 1 }
$profile = Join-Path $env:TEMP "gravity-hopper-web-smoke"
New-Item -ItemType Directory -Force -Path $profile | Out-Null
$logFile = Join-Path $profile "chrome_debug.log"
if (Test-Path $logFile) { [IO.File]::Delete($logFile) }
$port = 8766
$debugPort = 9333
$server = Start-Process -FilePath "python" -ArgumentList @("-m", "http.server", "$port", "--bind", "127.0.0.1", "--directory", "`"$debugDir`"") -WindowStyle Hidden -PassThru
$browserArgs = @("--headless=new", "--user-data-dir=`"$profile`"", "--remote-debugging-port=$debugPort", "--use-angle=swiftshader",
	"--enable-unsafe-swiftshader", "--window-size=450,800", "--hide-scrollbars", "--enable-logging", "--v=0", "http://127.0.0.1:$port/index.html")
Start-Process -FilePath $browser -ArgumentList $browserArgs -WindowStyle Hidden | Out-Null
try {
	Start-Sleep -Seconds $WaitSeconds
	if ($Shot) {
		$page = (Invoke-RestMethod "http://127.0.0.1:$debugPort/json") | Where-Object { $_.type -eq "page" -and $_.url -like "*127.0.0.1*" } | Select-Object -First 1
		$ws = New-Object System.Net.WebSockets.ClientWebSocket
		$ct = [Threading.CancellationToken]::None
		$ws.ConnectAsync([Uri]$page.webSocketDebuggerUrl, $ct).Wait()
		$bytes = [Text.Encoding]::UTF8.GetBytes('{"id":1,"method":"Page.captureScreenshot","params":{"format":"png"}}')
		$ws.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
		$buf = New-Object byte[] 1048576
		$ms = New-Object IO.MemoryStream
		do { $r = $ws.ReceiveAsync([ArraySegment[byte]]::new($buf), $ct).Result; $ms.Write($buf, 0, $r.Count) } while (-not $r.EndOfMessage)
		$data = ([Text.Encoding]::UTF8.GetString($ms.ToArray()) | ConvertFrom-Json).result.data
		[IO.File]::WriteAllBytes($Shot, [Convert]::FromBase64String($data))
		$ws.Dispose()
		Write-Output "OK   ekran görüntüsü: $Shot"
	}
} finally {
	Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match [regex]::Escape($profile) } |
		ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
	Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
$events = @()
if (Test-Path $logFile) { $events = @(Get-Content $logFile | Where-Object { $_ -match "CONSOLE" -and $_ -match "EVENT|Godot Engine|Build configuration" } | ForEach-Object { ($_ -split '"')[1] }) }
$events
if (-not ($events -match "EVENT run_started")) { Write-Output "TARAYICI DENEMESİ BAŞARISIZ: oyun başlamadı"; exit 1 }
Write-Output "OK   tarayıcıda oyun çalışıyor"
exit 0