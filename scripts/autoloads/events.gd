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
## Oyun ağacı duraklatıldı ya da sürdü (M5-06; durum PAUSED'a girince / çıkınca).
signal pause_changed(paused: bool)
## Uygulama durumu değişti (M5-01). Aynı duruma geçiş de duyurulur
## (ör. yeni tur: RUNNING → RUNNING).
signal app_state_changed(state: GameTypes.AppState)

# --- Oyuncu ---
signal player_died(cause: GameTypes.DeathCause)
signal player_revived
## Ölümde İkinci Şans hakkı var: sonuç ekranı dirilişi teklif eder (M5-03).
signal revive_offered(height_m: int)
signal player_flipped
signal player_landed
signal shield_changed(active: bool)
signal head_start_changed(active: bool)

# --- İlerleme ---
signal height_changed(meters: int)
signal sector_entered(index: int)
signal great_storage_reached
signal chunk_placed(chunk_id: StringName, difficulty: int, sector: int)
signal glimmer_collected(value: int)
signal record_broken
signal near_miss(combo: int, multiplier: int)
signal combo_ended
signal wall_proximity_changed(ratio: float)
signal beat(index: int)

# --- UI niyetleri (UI yayar, GameManager dinler) ---
signal start_requested(sector: int)
## Seçili kontrol noktasından tur başlat (ana menüdeki Başla, M5-01 / M5-02).
signal play_requested
signal retry_requested
signal revive_requested
## Diriliş teklifi geri çevrildi: tur biter (M5-03).
signal revive_declined
signal menu_requested
## Mağaza ekranını aç (ana menü ve sonuç ekranı, M5-04).
signal shop_requested(tab: GameTypes.ShopTab)
## Ayarlar ekranını aç (ana menü; duraklatma M5-06). Ekran menünün üstünde açılır, durum
## değişmez.
signal settings_requested
## Ayarlar'daki Hakkında düğmesi (M5-09): Hakkında / lisanslar ekranı ayarların üstünde açılır.
signal about_requested
## HUD'daki duraklat düğmesi (M5-06). Arka plana geçişte GameManager kendisi duraklatır.
signal pause_requested
## Duraklatma ekranındaki Devam, 3-2-1 sayımı bitince (M5-06).
signal resume_requested

# --- Ekonomi ve ayarlar ---
signal glimmers_changed(total: int)
signal best_height_changed(meters: int)
signal upgrade_purchased(id: StringName, level: int)
signal trail_unlocked(id: StringName)
signal trail_equipped(id: StringName)
signal sector_unlocked(index: int)
signal start_sector_selected(index: int)
signal settings_changed

# --- Debug (yalnızca debug katmanı yayar; yayın sürümünde hiç yayılmaz) ---
signal debug_invincibility_changed(enabled: bool)
signal debug_shield_requested

@warning_ignore_restore("unused_signal")
