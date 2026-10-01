# Projenin tam kontrolü: içe aktarma + tüm GDScript dosyalarının uyarılar hataya çekilerek derlenmesi.
# Kullanım: powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1
# Çıkış kodu 0 = temiz. Godot'nun ekransız modu uyarıları yazdırmadığı için geçici bir
# override.cfg ile "Warn" seviyesindeki kurallar "Error" yapılır; dosya her durumda silinir.
param(
	[string]$Godot = "C:\Users\burak\Godot\Godot_v4.7.2-stable_win64_console.exe"
)

$root = Split-Path -Parent $PSScriptRoot
$override = Join-Path $root "override.cfg"
$enc = New-Object System.Text.UTF8Encoding($false)
$code = 0

# 1) İçe aktarma (yeni class_name'ler ve .uid dosyaları için)
$import = & $Godot --headless --path $root --import 2>&1 | ForEach-Object { "$_" }
$importErrors = $import | Where-Object { $_ -match "ERROR|WARNING" }
if ($LASTEXITCODE -ne 0 -or $importErrors) {
	Write-Output "İÇE AKTARMA SORUNLU:"; $importErrors; $code = 1
} else {
	Write-Output "OK   içe aktarma"
}

# 2) Uyarıları hataya çekip tüm betikleri derle
try {
	$keys = & $Godot --headless --path $root --script "res://tools/warning_keys.gd" 2>&1 |
		ForEach-Object { "$_" } | Where-Object { $_ -like "WARNKEY *" } | ForEach-Object { $_.Substring(8) }
	$lines = $keys | ForEach-Object { ($_ -replace '^debug/', '') + "=2" }
	[IO.File]::WriteAllText($override, "[debug]`n`n" + ($lines -join "`n") + "`n", $enc)
	Write-Output "OK   $($keys.Count) uyarı kuralı hata seviyesine çekildi"

	$out = & $Godot --headless --path $root --script "res://tools/check_scripts.gd" 2>&1 | ForEach-Object { "$_" }
	$scriptCode = $LASTEXITCODE
	$out | Where-Object { $_ -match "^(HATA|KONTROL)|SCRIPT ERROR|ERROR:" }
	if ($scriptCode -ne 0) { $code = 1 }
} finally {
	if (Test-Path -LiteralPath $override) { [IO.File]::Delete($override) }
}

if ($code -eq 0) { Write-Output "SONUÇ: TEMİZ" } else { Write-Output "SONUÇ: SORUN VAR" }
exit $code
