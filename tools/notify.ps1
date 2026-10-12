# Telefona bildirim ve telefondan gelen mesajlar (ntfy, ADR-033).
# Kullanım (powershell -NoProfile -ExecutionPolicy Bypass -File tools/notify.ps1 ...):
#   -Message "M2-17 bitti; M2-18 oyun testin bekliyor"  → bildirim gönderir
#   -Read   → son okumadan beri kullanıcının yazdıklarını yazar ("MESAJ YOK" ya da "MESAJ ...")
#   -Wait   → kullanıcı yazana kadar bekler (PollSeconds'ta bir bakar); yazınca mesajları yazıp çıkar
# Konu adı depoda değil: %LOCALAPPDATA%\gravity-hopper\ntfy_topic.txt (tek satır). Son okunan
# mesajın kimliği aynı klasörde (ntfy_last_id.txt). Claude'un gönderdikleri başlıkla işaretlenir ve
# okurken atlanır. Bildirimde gizli bilgi olmaz: konu ntfy.sh'de herkese açıktır.
param(
	[string]$Message = "",
	[switch]$Read,
	[switch]$Wait,
	[int]$PollSeconds = 30
)

$ErrorActionPreference = "Stop"
$dir = Join-Path $env:LOCALAPPDATA "gravity-hopper"
$topicFile = Join-Path $dir "ntfy_topic.txt"
$lastFile = Join-Path $dir "ntfy_last_id.txt"
$title = "Claude - Gravity Hopper"

if (-not (Test-Path -LiteralPath $topicFile)) {
	Write-Output "NTFY YOK: $topicFile (konu adını tek satır olarak yaz)"; exit 1
}
$topic = (Get-Content -LiteralPath $topicFile -Raw).Trim()
$base = "https://ntfy.sh/$topic"

function Send-Note([string]$text) {
	$bytes = [Text.Encoding]::UTF8.GetBytes($text)
	Invoke-RestMethod -Method Post -Uri $base -Body $bytes -ContentType "text/plain; charset=utf-8" `
		-Headers @{ Title = $title } | Out-Null
}

# Son okunandan sonraki mesajlar; kullanıcınınkileri döndürür, son kimliği kaydeder.
function Get-NewMessages {
	$since = "all"
	if (Test-Path -LiteralPath $lastFile) { $since = (Get-Content -LiteralPath $lastFile -Raw).Trim() }
	$response = Invoke-WebRequest -UseBasicParsing -Uri "$base/json?poll=1&since=$since"
	$text = [Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray())
	$found = @()
	$last = $null
	foreach ($line in ($text -split "`n")) {
		if (-not $line.Trim()) { continue }
		$note = $line | ConvertFrom-Json
		if ($note.event -ne "message") { continue }
		$last = $note.id
		if ($note.title -eq $title) { continue }
		$found += $note
	}
	if ($last) { [IO.File]::WriteAllText($lastFile, $last) }
	return ,$found
}

function Write-Messages($notes) {
	foreach ($note in $notes) {
		$when = [DateTimeOffset]::FromUnixTimeSeconds([int64]$note.time).LocalDateTime.ToString("yyyy-MM-dd HH:mm")
		Write-Output "MESAJ $when $($note.message)"
	}
}

if ($Message) {
	Send-Note $Message
	Write-Output "OK   bildirim gönderildi"
}
if ($Read) {
	$notes = Get-NewMessages
	if ($notes.Count -eq 0) { Write-Output "MESAJ YOK" } else { Write-Messages $notes }
}
if ($Wait) {
	while ($true) {
		try {
			$notes = Get-NewMessages
			if ($notes.Count -gt 0) { Write-Messages $notes; exit 0 }
		} catch {
			# Ağ kesintisi beklemeyi bitirmez; bir sonraki turda yeniden denenir.
		}
		Start-Sleep -Seconds $PollSeconds
	}
}
