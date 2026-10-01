extends Node
## Global sinyal veri yolu.
##
## Yalnızca sinyal tanımları içerir, mantık içermez. Farklı sahne ağaçları
## (World ↔ UI ↔ autoload) arasındaki iletişim buradan geçer. Aynı sahnenin
## içindeki iletişim için kullanılmaz; orada ebeveyn çocuklarının sinyallerini bağlar.
## Katalog: docs/architecture.md §7.2

# Sinyaller başka sınıflardan yayıldığı için bu dosyada "kullanılmayan sinyal" uyarısı kapalı.
@warning_ignore_start("unused_signal")

# --- Tur yaşam döngüsü ---
signal run_started(run_seed: int, start_sector: int)
signal run_ended(result: RunResult)
signal pause_changed(paused: bool)

# --- Oyuncu ---
signal player_died(cause: GameTypes.DeathCause)
signal player_revived
signal player_flipped
signal shield_changed(active: bool)

# --- İlerleme ---
signal height_changed(meters: int)
signal sector_entered(index: int)
signal glimmer_collected(value: int)
signal near_miss(combo: int)
signal combo_ended
signal wall_proximity_changed(ratio: float)
signal beat(index: int)

# --- UI niyetleri (UI yayar, GameManager dinler) ---
signal start_requested(sector: int)
signal retry_requested
signal revive_requested
signal menu_requested
signal pause_requested
signal resume_requested

# --- Ekonomi ve ayarlar ---
signal glimmers_changed(total: int)
signal upgrade_purchased(id: StringName, level: int)
signal settings_changed

@warning_ignore_restore("unused_signal")
