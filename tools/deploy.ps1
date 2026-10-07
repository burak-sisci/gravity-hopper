# Oyunu telefona kabloyla yükler: dışa aktar → yükle → başlat → (isteğe bağlı) ekran görüntüsü → Godot günlüğü.
# Kullanım: powershell -NoProfile -ExecutionPolicy Bypass -File tools/deploy.ps1 [-Screenshot <png yolu>]
# Çıkış kodu: 0 = başarılı, 1 = dışa aktarma/yükleme hatası, 2 = telefon bağlı değil.
param(
	[string]$Godot = "C:\Users\burak\Godot\Godot_v4.7.2-stable_win64_console.exe",
	[string]$Screenshot = "",
	[int]$WaitSeconds = 4
)

$root = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
$apk = Join-Path $root "builds\android\gravity-hopper-debug.apk"
$package = "com.gravityhopper.dev"

# 0) adb sunucusunu borudan bağımsız başlat. Sunucu kapalıyken ilk adb komutu onu bu betiğin
#    çıktı borusunu miras alarak başlatır; sunucu boruyu kapatmadığı için betiği boruya bağlayan
#    çağıran (ör. "| Select-Object") sonsuza kadar bekler (M1-05'te yaşandı).
#    Start-Process (ShellExecute) boruyu miras vermez. -Wait kullanılmaz: PowerShell 5.1'de
#    alt süreçleri de bekler ve sunucu hiç kapanmaz; yalnızca istemci süreci beklenir.
$starter = Start-Process -FilePath $adb -ArgumentList "start-server" -WindowStyle Hidden -PassThru
$starter.WaitForExit()

# 1) Telefon bağlı mı?
$devices = & $adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match "\tdevice$" }
if (-not $devices) {
	Write-Output "TELEFON YOK: kabloyu ve telefondaki USB hata ayıklama iznini kontrol et."
	exit 2
}

# 2) Dışa aktar
New-Item -ItemType Directory -Force -Path (Split-Path $apk) | Out-Null
$export = & $Godot --headless --path $root --export-debug "Android" $apk 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) {
	Write-Output "DIŞA AKTARMA BAŞARISIZ:"; $export | Where-Object { $_ -match "ERROR" }
	exit 1
}
Write-Output "OK   dışa aktarma ($([math]::Round((Get-Item $apk).Length / 1MB)) MB)"

# 3) Yükle (Xiaomi: telefonda onay ekranı çıkabilir)
$install = & $adb install -r $apk 2>&1 | ForEach-Object { "$_" }
if (-not ($install -match "^Success")) {
	Write-Output "YÜKLEME BAŞARISIZ (telefondaki 'USB üzerinden yükle' onayını kontrol et):"; $install
	exit 1
}
Write-Output "OK   yükleme"

# 4) Başlat
& $adb logcat -c
& $adb shell am force-stop $package
& $adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Start-Sleep -Seconds $WaitSeconds
$appPid = (& $adb shell pidof $package) -join ""
if (-not $appPid) {
	Write-Output "BAŞLATMA BAŞARISIZ: uygulama çalışmıyor."
	& $adb logcat -d -s godot:* AndroidRuntime:E 2>&1 | Select-Object -Last 20
	exit 1
}
Write-Output "OK   başlatma (pid $appPid)"

# 5) Ekran görüntüsü
if ($Screenshot) {
	cmd /c "`"$adb`" exec-out screencap -p > `"$Screenshot`""
	Write-Output "OK   ekran görüntüsü: $Screenshot"
}

# 6) Godot günlüğündeki hata ve uyarılar
$log = & $adb logcat -d -s godot:* 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match "ERROR|WARNING" }
if ($log) { Write-Output "GÜNLÜKTE SORUN:"; $log } else { Write-Output "OK   Godot günlüğü temiz" }
exit 0
