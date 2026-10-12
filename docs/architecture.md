# GRAVITY HOPPER — Teknik Mimari

> Son güncelleme: 2026-10-11 (M1 Planlama Gözden Geçirmesi) · Durum: M0 altyapısı ve M1 çekirdek oynanışı doğrulandı. ⚠️ işaretli maddeler, yanlarında yazan görevde doğrulanacak.
> Bu belge *nasıl* inşa ettiğimizi anlatır. *Ne* inşa ettiğimiz → `GDD.md`. *Hangi sırayla* → `roadmap.md`.

---

## 1. Mimari hedefler

| Hedef | Anlamı | Nasıl sağlıyoruz |
| --- | --- | --- |
| **Adalet** | Ölüm her zaman oyuncunun hatası olmalı | Sabit ileri görüş, çözülebilir desenler, affedici çarpışma kutuları, dokunma tamponu |
| **Belirlenimcilik** | Aynı tohum = aynı harita, her cihazda | Tohumlu RNG, 60 Hz sabit fizik adımı |
| **Geniş cihaz desteği** | Ucuz telefondan tablete kadar | Compatibility renderer, nesne havuzu, efekt kalitesi ayarı |
| **Gevşek bağlılık** | Parçalar birbirini tanımaz | Sinyaller, `Events` veri yolu, ayrı UI sahneleri |
| **Ayarlanabilirlik** | His, kod değişmeden ayarlanır | `TuningConfig` kaynağı + canlı ayar paneli |

## 2. Temel teknik kararlar

| Konu | Karar | Neden |
| --- | --- | --- |
| Motor | Godot 4.7.x (standard) | Ücretsiz, telif yok, metin tabanlı sahneler |
| Dil | GDScript, **zorunlu statik tip** | Hataları erken yakalar, daha hızlı çalışır |
| Renderer | **Compatibility** (OpenGL ES 3 / WebGL 2) | En geniş Android desteği ve web çıktısı; bazı ucuz cihazlardaki Vulkan sürücü sorunlarından kaçınma |
| Ekran yönü | **Dikey (portrait)** | GDD kararı: tek elle oynanış, dikey video uyumu |
| Taban çözünürlük | **1080 × 1920** | Standart dikey tasarım boyutu |
| Esneme | `canvas_items` + `expand` | Siyah şerit yok; fazla alanın kullanımı §3'teki kurala göre |
| Fizik | 60 tick/sn + **physics interpolation** | 60/90/120/144 Hz ekranlarda aynı oyun, akıcı görüntü |
| Girdi | Tek eylem: çevirme (dokunma / fare sol tık / Space) | Tek dokunuş oyunu |
| Görsel | `Polygon2D` / `Line2D` + koddan renk + nesne başına sahte parlama | Harici görsele bağımlılık yok (bkz. §9, ADR-020) |

**project.godot ayarları** (M0-04'te uygulandı; Godot 4.7.2'de tanındıkları ve değerleri betikle doğrulandı. `orientation=1` = Portrait, `untyped_declaration=2` = Error):

```ini
display/window/size/viewport_width=1080
display/window/size/viewport_height=1920
display/window/size/window_width_override=450    ; PC test penceresi
display/window/size/window_height_override=800
display/window/stretch/mode="canvas_items"
display/window/stretch/aspect="expand"
display/window/handheld/orientation=1            ; portrait
rendering/renderer/rendering_method="gl_compatibility"
rendering/renderer/rendering_method.mobile="gl_compatibility"
physics/common/physics_ticks_per_second=60      ; varsayılan değer, bu yüzden project.godot'a yazılmaz
physics/common/physics_interpolation=true
debug/gdscript/warnings/untyped_declaration=2    ; Error
application/run/main_scene="res://scenes/main.tscn"                 ; M0-08
rendering/environment/defaults/default_clear_color=Color(0.039, 0.055, 0.122, 1)  ; koyu lacivert
rendering/textures/vram_compression/import_etc2_astc=true          ; Android dışa aktarma için zorunlu
```

## 3. Ekran, kamera ve görüş kuralı

`expand` modu sayesinde uzun telefonlarda (20:9) görünür alan **dikeyde**, tabletlerde (4:3) **yatayda** büyür. Bu, uzun ekranlı oyunculara haksız avantaj sağlayabilir. Bunu önlemek için:

- **Koridor genişliği sabittir** (dünya biriminde, başlangıç 900 px). Taban genişlik 1080 olduğundan her cihaza sığar.
- **Sabit ileri görüş kuralı:** Kamera, oyuncunun **üstünde** her cihazda aynı mesafeyi gösterir (`LOOKAHEAD`, başlangıç 1400 px). Fazla dikey alan oyuncunun **altına**, çöküş duvarı tarafına gider. Fazla yatay alan arka plan olarak kullanılır.
- Kamera ofseti pencere boyutu değiştiğinde yeniden hesaplanır (`get_viewport().size_changed`).
- **Uygulama (M1-03):**
  - `GameCamera.follow(hedef_y, lookahead_px)` kamerayı her fizik adımında konumlar; görünür alanın üst kenarı = hedef − ileri görüş. Koridorun ortası dünyada x = 0'dır, kamera yatayda hep onu ortalar.
  - Değerler her adımda `TuningConfig`'ten okunur.
  - Redmi'de 60 Hz fizik + 120 Hz ekranda kamera her karede tam 5 px ilerledi; fizik ara değerlemesi Camera2D ile çalışıyor, titreme yok.
- **Ekran oranı denemesi (M1-06):** PC'de `6` tuşu (debug katmanı) pencereyi 450×800 (16:9) → 450×1000 (20:9) → 600×800 (4:3) arasında döndürür; telefonda etkisizdir.
  - Ekranlı denemede üç oranda da oyuncunun üstü tam 1400 px (28 m) çıktı.
  - Ekran görüntülerinde elmas üçünde de y = 567–598 aralığındaydı.
  - 20:9'da fazla dikey alan (+200 px) oyuncunun altına, 4:3'te fazla yatay alan (görünür alan 1440 px) yanlara gitti.
- **Dünyada `Control` kullanılmaz.** `ColorRect` ya da `Label` gibi arayüz düğümleri dokunuşları yutar; o noktadaki dokunuş çevirme sayılmaz. Dünya görselleri `Polygon2D` / `Line2D` / `Sprite2D`'dir.
- **UI:** Control düğümleri anchor ile yerleşir. Güvenli alan (çentik, yuvarlak köşe) `DisplayServer.get_display_safe_area()` ile hesaplanıp kök UI'ye kenar boşluğu olarak uygulanır.
- **Birim:** 1 m = 50 px (`TuningConfig.PX_PER_M`). GDD'deki tüm metre değerleri bu ölçeğe göredir.

## 4. Klasör yapısı

```
gravity-hopper/
├── CLAUDE.md                 # Claude proje rehberi (planlama rutini)
├── .clauderules              # Katı kurallar (CLAUDE.md içinden yüklenir)
├── CREDITS.md                # Dış varlıklar ve lisanslar
├── project.godot             # Proje ayarları (§2)
├── export_presets.cfg        # Android dışa aktarma ön ayarı (§14); sır içermez
├── gdlintrc                  # gdlint kuralları (M0-12)
├── .claude/                  # Claude Code proje ayarı: settings.json (gdlint kancası), .gdignore
│
├── docs/                     # Planlama belgeleri
│   ├── architecture.md
│   ├── state.json
│   ├── GDD.md
│   └── roadmap.md
│
├── assets/                   # Görsel ve işitsel materyaller
│   ├── sprites/              # UI ikonları, parçacık dokuları, uygulama ikonu
│   ├── audio/
│   │   ├── sfx/              # Efektler (çevirme, toplama, ölüm, kıl payı)
│   │   └── music/            # Sektör müzikleri (BPM'i belli döngüler)
│   ├── fonts/                # Türkçe karakter destekli fontlar
│   └── shaders/              # Arka plan ağı, glitch (sahte parlama shader'sız: §9)
│
├── data/                     # İçerik ve ayar kaynakları (.tres)
│   ├── tuning/               # TuningConfig (hareket, kamera, adalet, basınç)
│   ├── chunks/               # ChunkLibrary: oyundaki desen parçalarının listesi (M2-04)
│   ├── sectors/              # SectorDef + paletler
│   ├── upgrades/             # UpgradeDef
│   └── trails/               # TrailDef (kozmetik izler)
│
├── localization/             # translations.csv (TR / EN)
│
├── scenes/                   # Godot sahneleri (.tscn)
│   ├── levels/               # run.tscn (oyun dünyası)
│   │   └── chunks/           # Elle tasarlanmış desen parçaları
│   ├── entities/             # Player, Hazard türleri, Glimmer, CollapseWall
│   ├── ui/                   # Ana menü, HUD, sonuç, mağaza, ayarlar
│   └── debug/                # debug_layer.tscn (M1-02), glow_bench.tscn (M0-09 parlama ölçümü) — yalnızca debug
│
├── scripts/                  # GDScript dosyaları (.gd)
│   ├── main.gd               # Kök sahne betiği: debug build'de debug katmanını yükler
│   ├── autoloads/            # Global servisler (bkz. §6)
│   ├── components/           # Bağımsız parçalar: Hurtbox, GrazeDetector, Magnet…
│   ├── entities/             # Varlık betikleri (sahnelerle aynı ad)
│   ├── levels/               # run.gd, corridor.gd, chunk_info.gd (M2-03)
│   ├── systems/              # ChunkSpawner, Conductor, PressureSystem, ObjectPool, RunRng
│   ├── data/                 # Resource sınıf tanımları (TuningConfig, SectorDef…)
│   ├── ui/                   # UI betikleri
│   └── debug/                # Debug araçları
│
├── tools/                    # Geliştirici araçları: check.ps1 + check_scripts.gd + warning_keys.gd (M0-06), deploy.ps1 (M0-08),
│                             #   scene_tool.gd + fixtures/ (M0-11), lint_hook.py (M0-12), web_build.ps1 (M1-13),
│                             #   chunk_validator.gd + validate_chunks.gd (M2-05), notify.ps1 (ntfy, ADR-033)
├── tests/                    # Otomatik testler (gdUnit4, M2-01); klasörler scripts/ ile aynı (tests/systems/run_rng_test.gd)
└── addons/                   # Sürümü sabit eklentiler (her biri CREDITS.md'de)
    ├── debug_menu/           # godot-debug-menu, commit ff12461 (M0-09); yalnızca debug
    ├── gdUnit4/              # gdUnit4 6.2.2 (M2-01); dışa aktarmada dışlanır
    └── …                     # Play Games ve AdMob (M7)
```

Kurallar:

- Bir sahnenin betiği, `scripts/` altında sahneyle aynı kategori ve adla durur (`scenes/entities/player.tscn` ↔ `scripts/entities/player.gd`).
- `tools/`, `tests/` ve test/editör eklentileri dışa aktarma ön ayarlarının dışlama filtresiyle yayın sürümünden çıkarılır.
- Dış repolar bu klasöre klonlanmaz; gerekli dosyalar proje dışında incelenip seçilerek alınır.

## 5. Sahne mimarisi

### 5.1 Kök sahne

```
Main (Node)                           scenes/main.tscn
├── World (Node2D)                    # aktif oyun dünyası buraya yüklenir (run.tscn)
├── UI (CanvasLayer, layer 10)        # aktif ekran: menü / HUD / sonuç / mağaza
└── Debug (CanvasLayer, layer 100)    # içeriği yalnızca debug build'de yüklenir: debug katmanı (§13)
```

`WorldEnvironment` yoktur: parlama nesne başına sahte parlamayla yapılır (§9, ADR-020).

> **Şu anki içerik (M1-09):** `World` boş başlar; `Main` her turda `scenes/levels/run.tscn`'den bir `Run` kurar. M0-10'un `TapTest` ve `TapHint` sahneleri ana sahneden çıkarıldı ama dosyaları duruyor:
> - `scenes/debug/tap_test.tscn`: girdi kurallarının başvuru örneği.
> - `scenes/ui/tap_hint.tscn`: FTUE'deki "dokun" eli ikonunun nabız davranışı için. FTUE metinsizdir (GDD §18).
>
> `UI`'de şimdilik yalnızca HUD (`UI/Hud`, M1-10) var; menüler M5'te gelir.

**Sahne geçişleri: `GameManager` karar verir, `Main` uygular (ADR-026).** Autoload'lar sahne düğümlerine erişmediği için (.clauderules §3) `World` ve `UI` kaplarının içeriğini kök sahne `Main` (`scripts/main.gd`) değiştirir. `GameManager` tohumu seçer, durumu tutar, sonucu (`RunResult`) oluşturur ve `Events` ile duyurur. Uygulama durumları: `BOOT → MENU → RUNNING ⇄ PAUSED → RESULTS → (RUNNING | MENU | SHOP)`.

**Tur döngüsü (M1-09):**

1. `Main._start_run()`: varsa eski `Run`'ı ağaçtan çıkarıp `queue_free()` eder. `GameManager.new_run_seed()` ile yeni bir `Run` kurar, `World`'e ekler ve `GameManager.begin_run(tohum, sektör)` çağırır.
2. `begin_run` durumu `RUNNING` yapar ve `Events.run_started` yayar.
3. `Player` ölünce `GameManager` `RunResult` oluşturur (yükseklik `Events.height_changed`'den), durumu `RESULTS` yapar ve `Events.run_ended` yayar.
4. M1 geçici akışı: `Main`, `run_ended`'den 0,35 sn sonra yeni tur kurar. M5'te sonuç ekranı gelir; "Tekrar" düğmesi `Events.retry_requested` yayar, `Main` bunu zaten dinliyor.
5. **Başlangıç sektörü (M2-08):** `Events.start_requested(sector)` gelince `Main` o sektörden yeni tur kurar (sektör seçimi M5, şimdilik debug `5`). `Run` katalog dışı numarayı sınırlar; `Main` sınırlanmış numarayı `begin_run`'a verir. Ölümden ve "Tekrar"dan sonraki turlar son seçilen sektörden başlar (kontrol noktası). `GameManager`, `sector_entered`'dan ulaşılan en yüksek sektörü `RunResult.sector_reached`'e yazar.

Ölçüm: ekransız denemede ölümden yeni tura 22 kare (0,37 sn); Redmi'de 7 turda 348–360 ms.

### 5.2 Oyun dünyası

```
Run (Node2D)                          scenes/levels/run.tscn
├── Background                        # veri ağı shader'ı, paralaks
├── Conductor (Node)                  # ritim saati (§8.3)
├── ChunkSpawner (Node2D)             # desen parçası üretimi + havuzlar (§8.2)
├── Player (CharacterBody2D)          # scenes/entities/player.tscn
│   ├── Visual (Polygon2D)
│   ├── Trail (Line2D)
│   ├── Hurtbox (Area2D)              # bileşen: çarpışma (görselden küçük)
│   ├── GrazeDetector (Area2D)        # bileşen: kıl payı algılama
│   ├── Magnet (Area2D)               # bileşen: Glimmer çekimi
│   └── Shield (Node)                 # bileşen: kalkan durumu
├── PressureSystem (Node)             # çöküş duvarı mantığı (§8.4)
├── CollapseWall (Node2D)             # çöküş duvarının görseli
└── GameCamera (Camera2D)             # görüş kuralı + sarsıntı
```

`Run` kendi çocuklarının sinyallerini bağlar (ör. `Player.shield_broken → PressureSystem.on_shield_broken`). Dışarıya yalnızca `Events` üzerinden seslenir.

**Şu anki hâli (M2-07):** `Run` → `%Conductor` (`scripts/systems/conductor.gd`, §8.3) + `%Corridor` (`scripts/levels/corridor.gd`, `Corridor`) + `%ChunkSpawner` (`scripts/systems/chunk_spawner.gd`, §8.2) + `%Player` (`scenes/entities/player.tscn`, `Player`; çocukları `Body`, `Hurtbox/Shape`, `Visual`) + `%GameCamera` (`scripts/components/game_camera.gd`, `GameCamera`). Yukarıdaki ağaç hedeftir; düğümler görevleriyle eklenir.

- **Corridor:**
  - **Duvar boşlukları (M2-11):** `Run` her adımda `ChunkSpawner.active_gaps()` (duvar, üst y, alt y) listesini `set_gaps()` ile bildirir. Liste değişince ya da bir parça taşınınca her duvar parçası, boşlukların dışında kalan katı aralıklara bölünür: parça başına en fazla 3 parçacık (`CollisionShape2D` + `Polygon2D`, tur başında oluşturulur; yalnızca boy ve yer değişir, kullanılmayan kapatılır). Sınırlar tam boşluk kenarındadır. Test: `tests/levels/corridor_test.gd`.
  - **Geçici palet tonu (M2-09):** `set_tint(renk)` duvarları sektörün `ambient_color`'una %35 oranında çeker; geçiş 0,6 sn'lik tween (yalnızca görsel). `Run` tur başında anında, sektöre girişte yumuşak çağırır. Kesin palet ve renk dalgası M3'te.
  - Sol ve sağ duvarlar 400 px'lik `StaticBody2D` parçalarından oluşur; her parça 60 px kalınlığında, gri ve sırayla açık/koyu.
  - Parça sayısı en uzun ekrana (21:9) göre tur başında sabittir (10 + 10).
  - Görünür alanın altında kalan parça bir halka boyu yukarı taşınır ve `reset_physics_interpolation()` çağrılır.
- **Kamera** M1-04'ten beri oyuncuyu izler (M1-03'te sabit hızla yükselen bir noktayı izliyordu).

**Fizik katmanları** (`project.godot` → `layer_names`, M1-07):

| Katman | Değer | Kimde | Neyi algılar (mask) |
| --- | --- | --- | --- |
| `collector` (M2-13) | 8 | Oyuncunun `Collector` alanı | — (yalnızca algılanır) |
| `collectible` (M2-13) | 16 | `Glimmer` | `collector` |
| 1 `world` | 1 | Duvar parçaları (`StaticBody2D`) | — |
| 2 `player` | 2 | Oyuncu gövdesi (`CharacterBody2D`) | `world` |
| 3 `hazard` | 4 | Tehlikeler (`Area2D`, `monitoring = false`, pasif) | — |
| — | 0 | Oyuncunun `Hurtbox`'ı (`Area2D`, `monitorable = false`) | `hazard` |

Toplanabilirler (Glimmer) ve kıl payı algılayıcısı katmanlarını kendi görevlerinde alır (M2-13, M2-14).

### 5.3 UI sahneleri (`scenes/ui/`)

`main_menu`, `hud`, `results`, `shop` (yükseltmeler + izler), `settings`, `pause`, `about` (lisanslar). **Hiçbiri `World`'e erişmez**: hepsi `Events`'i dinler, niyetlerini `Events` ile bildirir.

- **HUD (M1-10, `scenes/ui/hud.tscn`, `main.tscn`'de `UI/Hud`):**
  - Sol üstte anlık yükseklik (`HUD_HEIGHT` = "%d m"), altında oturum rekoru (`HUD_BEST`). Rekor satırı ilk turdan sonra görünür.
  - Dinlediği sinyaller: `run_started`, `height_changed`, `run_ended`.
  - Metinler kodda `tr()` ile kurulduğu için Label'larda `auto_translate_mode = DISABLED`. Dil değişince `NOTIFICATION_TRANSLATION_CHANGED` ile yeniden yazılır.
  - Kök `Control` `mouse_filter = IGNORE`'dur; HUD'un üstüne dokunuş çevirme yapar (denendi).
  - Üst pay sabit 110 px; güvenli alan M6-01'de gelir.
  - Oturum rekoru bellektedir; kalıcı rekor M4'te `Progression`'a taşınır.

## 6. Autoload'lar

| Autoload | Görevi | Not |
| --- | --- | --- |
| `Events` | Global sinyal veri yolu | Yalnızca sinyal tanımları, mantık yok |
| `GameManager` | Uygulama durum makinesi; tur tohumu, `run_started` / `run_ended` duyuruları, `RunResult` | Sahneye dokunmaz; sahne geçişlerini `Main` uygular (§5.1, ADR-026) |
| `SaveManager` | Kayıt dosyalarını okuma/yazma, şifreleme, sürüm geçişi | Yalnızca kalıcılık; oyun kuralı bilmez |
| `Progression` | Glimmer cüzdanı, yükseltme seviyeleri, izler, açılmış sektörler | Veriyi `SaveManager` ile saklar |
| `Settings` | Ses, müzik, titreşim, dil, efekt kalitesi | `user://settings.cfg` |
| `AudioManager` | Efekt havuzu, müzik çalma ve geçişleri, `pitch_scale` senkronu | Olayları `Events`'ten dinler |

İleride: `Ads`, `PlayGames` (M7). **Debug araçları autoload değildir:** Autoload'lar her derlemede yüklenir. Bu yüzden debug araçları `Main/Debug` katmanına yalnızca `OS.is_debug_build()` iken yüklenir (§13, ADR-020). **Yeni autoload eklemeden önce bu tablo güncellenir.**

## 7. İletişim: Sinyaller

### 7.1 Kurallar

1. **Aşağı çağır, yukarı sinyal ver.** Ebeveyn çocuğu çağırır; çocuk ebeveyne sinyal yayar.
2. **Sahne içi** bağlantıları o sahnenin kökü kurar. **Sahneler arası** (World ↔ UI ↔ autoload) iletişim yalnızca `Events` ile olur.
3. **Engeller pasiftir.** `Area2D` olarak dururlar; oyuncuyu tanımazlar.
4. **Karakter bir engele çarptığında engelin kodunu çağırmaz, yalnızca `player_died` yayar.** UI ve GameManager bu sinyali dinleyip kendi işlerini yapar.
5. Sinyal parametreleri tiplidir; adları geçmiş zaman kipindedir.

### 7.2 `Events` kataloğu (başlangıç)

| Sinyal | Parametreler | Yayan | Dinleyen |
| --- | --- | --- | --- |
| `run_started` | `run_seed: int, start_sector: int` | GameManager (`Main` turu kurduktan sonra `begin_run` ile) | HUD, AudioManager |
| `run_ended` | `result: RunResult` | GameManager | Sonuç ekranı |
| `pause_changed` | `paused: bool` | GameManager | HUD, AudioManager |
| `player_died` | `cause: GameTypes.DeathCause` (HAZARD, FELL, WALL) | Player (WALL: PressureSystem → Run → `Player.die`, M2-15) | GameManager, HUD, AudioManager |
| `player_revived` | — | GameManager | HUD, AudioManager |
| `player_flipped` | — | Player | AudioManager (ses, titreşim) |
| `shield_changed` | `active: bool` | Player | HUD, AudioManager |
| `height_changed` | `meters: int` | Run (yalnızca tam sayı değişince) | HUD, GameManager (`RunResult.height_m`) |
| `sector_entered` | `index: int` | Run (sınır geçilince, M2-08) | HUD (afiş, M2-09), GameManager (`sector_reached`), debug katmanı; AudioManager (müzik, M3) |
| `chunk_placed` | `chunk_id: StringName, difficulty: int, sector: int` | ChunkSpawner (her parça yerleştiğinde, M2-06) | Debug olay günlüğü (zorluk ve tekrar ölçümü, M2-10) |
| `glimmer_collected` | `value: int` | Run | HUD, AudioManager |
| `near_miss` | `combo: int` | Run | HUD, AudioManager |
| `combo_ended` | — | Run | HUD |
| `wall_proximity_changed` | `ratio: float` (0 uzak – 1 yakın) | PressureSystem | HUD (kenar vinyeti), AudioManager |
| `beat` | `index: int` | Conductor | Arka plan, HUD (nabız) |
| `start_requested` | `sector: int` | UI (M5), debug katmanı (`5`, M2-08) | Main (o sektörden yeni tur) |
| `retry_requested` / `revive_requested` / `menu_requested` | — | UI | GameManager |
| `pause_requested` / `resume_requested` | — | UI | GameManager |
| `glimmers_changed` | `total: int` | Progression | UI |
| `upgrade_purchased` | `id: StringName, level: int` | Progression | UI, AudioManager |
| `settings_changed` | — | Settings | AudioManager ve ilgililer |
| `debug_invincibility_changed` | `enabled: bool` | Debug katmanı (yalnızca debug build) | Player |
| `debug_shield_requested` | — | Debug katmanı (M2-16) | Player (kalkan takar) |

### 7.3 Örnek akış: Ölüm

1. Diken (`Area2D`, pasif) oyuncunun `Hurtbox`'ıyla örtüşür.
2. `Hurtbox` bileşeni yukarıya `hit` sinyali yayar → `Player`.
3. `Player`: kalkan varsa tüketir ve `shield_changed(false)` + yerel `shield_broken` yayar. Kalkan yoksa `Events.player_died.emit(DeathCause.HAZARD)`. **Dikenin koduna dokunmaz.**
   - **Uygulama (M2-16):** `Shield` bileşeni (`scripts/components/shield.gd`, oyuncunun çocuğu): `give()`, `consume(dokunulmazlık)`, `tick(delta)`, `is_in_grace()`; durum değişince yukarı `changed` → `Player` bunu `Events.shield_changed`'e bağlar. Darbe: dokunulmazlıktaysa yok sayılır; kalkan varsa tüketilir, `TuningConfig.shield_grace` (1 sn) dokunulmazlık başlar, `shield_broken` → `Run` → `PressureSystem.pull(shield_pull)` (8 m). Kalkan düşmeye ve çöküş duvarına karşı korumaz (`Player.die` ve düşme kalkana bakmaz). Görsel: oyuncunun çevresinde açık mavi halka (`Line2D`, yarıçap 56 px), dokunulmazlıkta yanıp söner. Şimdilik debug ile verilir: `8` tuşu ya da paneldeki "Kalkan" düğmesi → `Events.debug_shield_requested`; yükseltme M4'te. Redmi'de halka göründü, kalkan bir darbeyi emdi ve tur sürdü.
4. `GameManager` dinler: `Run.stop()` (aşağı çağrı), `RunResult` oluşturur, `Progression.add_glimmers()`, `SaveManager.save_game()`, ardından `Events.run_ended.emit(result)`.
5. Sonuç ekranı `run_ended`'i, `AudioManager` ise `player_died`'ı dinleyerek kendi işini yapar.
6. Oyuncu "Tekrar"a dokunur → UI `Events.retry_requested` yayar → `GameManager` yeni turu **yarım saniyenin altında** başlatır.

**Uygulama (M1-07):**

- Adım 1–3 hazır:
  - `scenes/entities/spike.tscn`: betiksiz `Area2D` (yalnızca şekil + görsel), en saf pasif tehlike.
  - `Hurtbox` (`scripts/components/hurtbox.gd`): tehlike katmanındaki bir alana girince `hit` yayar.
  - `Player._on_hurtbox_hit()`: oyuncu donar ve tek bir `player_died(HAZARD)` yayar.
- Çarpışma kutusu her adımda gövde × `hurtbox_scale` boyutuna ayarlanır.
- Ekransız deneme: karşı duvardaki diken öldürmedi, kendi duvarındaki diken bir kez öldürdü, oyuncu dondu, `GameManager` `RESULTS`'a geçti.
- Adım 4 ve 6 (tur döngüsü) M1-09'da geldi (§5.1). Adım 4'teki `Run.stop()` yerine `Main` eski turu kaldırır; kayıt (`SaveManager`) ve Glimmer M4'te eklenir.

## 8. Oynanış sistemleri

### 8.1 Hareket (Player)

- `CharacterBody2D`, `motion_mode = FLOATING`.
- **Dikey:** Sabit tırmanış hızı; değer bulunulan sektörden gelir (`SectorDef.climb_speed`, M2-08). `Run` atar: `Player.climb_speed` (m/sn). Diğer hareket değerleri `TuningConfig`'te metre birimindedir (§10).
- **Duvar boşluğu ve coyote (M2-11):** Boşlukta duvara değmeyen oyuncu dışarı doğru hızlanır. Duvardan ayrıldıktan sonra `TuningConfig.coyote_time` (0,1 sn) boyunca çevirme hâlâ kabul edilir; coyote çevirmesinde dışarı doğru birikmiş hız silinir. Süre dolduğunda oyuncu koridorun dışındaysa (duvar çizgisi + gövdenin yarısı) `Events.player_died(FELL)`. Normal çevirmede coyote sıfırlanır (havada ikinci çevirme yok). Debug ölümsüzlüğünde oyuncu duvar çizgisine geri konur.
  - `move_and_slide()` duvar parçalarının birleşim yerinde dikeyde ≈ 0,02 px itebiliyordu (M2-10'da testte görüldü). `Player` bu payı hemen geri alır; böylece her adım tam `hız × delta`'dır.
- **Yatay:** Yerçekimi aktif duvara doğru çeker (`gravity_accel`, `max_side_speed`). Duvar segmentleri `StaticBody2D`'dir; tutunma `is_on_wall()` ile algılanır.
- **Çevirme** yalnızca duvara tutunurken yapılabilir, ek olarak:
  - **Coyote süresi:** Duvardan ayrıldıktan (boşluğa girdikten) sonra kısa bir süre (başlangıç 0,08 sn) çevirmeye izin verilir. Yalnızca duvar boşluklarında anlamlı olduğu için boşluklarla birlikte M2-11'de gelir.
  - **Dokunma tamponu:** Havadayken yapılan dokunuş kısa bir süre (başlangıç 0,12 sn) saklanır ve duvara değince uygulanır.
- **Uygulama (M1-04, `scripts/entities/player.gd`, `Player`):**
  - **Eksenler ayrıdır.** Yatay hareket `move_and_slide()` ile yalnızca yatay hızla yapılır (duvar teması). Dikey tırmanış doğrudan konumla yapılır: `position.y -= climb × delta`.
  - Neden: Yüzen kipte ilk kaymada çarpan hareketin hız büyüklüğü korunuyor; yan hareket tırmanışa ekleniyor (%8 fazla ölçüldü). Tırmanış vuruş ızgarası için tam sabit olmalı (§8.2).
  - Duvara değince `velocity.x = 0`. Yoksa yan hız duvarın içine doğru birikir ve çevirmeden sonra karakter duvardan geç ayrılır.
  - Dokunuş `_unhandled_input`'ta yalnızca not edilir; çevirme kararı sonraki `_physics_process`'te verilir.
  - Başlangıç x = 0'dır; karakter sol duvara düşer. Gövde 60×80 px dikdörtgendir (1,2 × 1,6 m), görseli beyaz elmas.
  - `Run`, `process_physics_priority = 1` ile oyuncudan sonra çalışır; böylece kamera o adımın konumunu izler.
  - Ekransız denemede 9 durum geçti; Redmi'de art arda iki hızlı dokunuştan yalnızca biri çevirme yaptı (ikincisi havadaydı, tampon öncesi).
- **Dokunma tamponu (M1-05):**
  - Havadaki dokunuş `_buffer_left = input_buffer_time` olarak saklanır. Her adımda yatay hareketten sonra karakter duvara değmişse çevirme hemen uygulanır; değmemişse süre azalır.
  - Geçiş başlangıç değerleriyle 22 kare (0,37 sn) sürüyor.
  - Ekransız deneme:
    - İnişten 4 kare önceki dokunuş inişte uygulandı.
    - İnişten 0,2 sn önceki dokunuş yok sayıldı.
    - `input_buffer_time = 0` iken 4 kare önceki dokunuş da yok sayıldı; yani süre ayardan geliyor.
  - Redmi'de havadaki ikinci dokunuş dört denemede de inişte uygulandı; iki çevirmenin arası ≈ 350 ms, yani bir geçiş süresi.
- **Koridordan çıkış** (duvar boşluğundan düşme): `player_died(FELL)`.
- **Hurtbox** görselden küçüktür (başlangıç %70).
- **Girdi:** `_unhandled_input` içinde işlenir, böylece UI düğmelerine dokunmak çevirme yapmaz.
  - Mobilde her `InputEventScreenTouch` (basıldı, **her parmak**) kabul edilir. Böylece iki başparmakla hızlı dokunuşlar kaybolmaz.
  - PC'de fare sol tık ve Space kabul edilir.
  - Dokunmadan türetilmiş (emülasyon) fare olayları yok sayılır (`device == InputEvent.DEVICE_ID_EMULATION`), yoksa tek dokunuş iki çevirme sayılır.
  - M0-10'da doğrulandı:
    - Ekransız denemede 8 durumun hepsi beklendiği gibi: tık, bırakma, sahte fare, iki parmak, parmak kaldırma, boşluk, tuş tekrarı.
    - Redmi'de adb ile 3 dokunuş = 3 sayım.
    - Gerçek iki başparmak denemesi M2-18'de kullanıcı yapacak (S-07; adb ile taklit edilemiyor).
  - Kural tek yerde: `Player.is_tap(event)`; testi `tests/entities/player_test.gd` (M2-02).

### 8.2 Bölüm üretimi (desen parçaları)

- **Desen parçası (chunk)** = `scenes/levels/chunks/` altında bir sahne. Kökü `Node2D` + `ChunkInfo` betiği (`scripts/levels/chunk_info.gd`, M2-03):
  - `difficulty` (1–10), `min_sector`, `max_sector` (1–5), `length_beats` (1–64), `tags` (`Array[StringName]`).
  - Öğeler kökün doğrudan çocuklarıdır (tehlike sahneleri, ileride Glimmer). `items()` bunları verir.
- Parçalar **vuruş biriminde** tasarlanır: editörde 1 vuruş = 100 px dikey ızgara. Parça yerleştirilirken y konumları sektörün vuruş uzunluğuna göre ölçeklenir: `y_dünya = y_yerel / 100 × vuruş_px(sektör)`. Şekiller esnemez, yalnızca konumlar ölçeklenir.
- `vuruş_px(sektör) = tırmanış_hızı × 60 / BPM` → `ChunkInfo.beat_px(hız_m_sn, bpm)`. S1: 360 px (0,6 sn), S3: 400 px, S5: ≈ 429 px.
- **Parça tasarım kuralları** (`ChunkInfo.design_errors()` denetler; test `tests/levels/chunk_info_test.gd` klasördeki her parçaya uygular):
  1. Kök parçanın **alt kenarıdır** (oyuncunun ilk vardığı yer); parça yukarı uzanır: öğelerin y'si `0` ile `-length_beats × 100` arasında.
  2. Öğeler **yarım vuruşa** oturur (y, 50'nin katı) ve yatayda 1 m adımına (x, 50'nin katı). Editörde ızgara yaklaştırması 50 × 50 px yapılır.
  3. Koridor tasarımda 18 m çizilir: duvarlar x = ±450. Duvara yapışık öğe tam ±450'de durur ve **koridora bakar** (sol duvarda `scale.x = 1`, sağda `-1`).
  4. Dünyaya yerleşim `layout(vuruş_px, yarı_genişlik)`: konumlar tasarımdan yeniden hesaplanır (birikmez); x koridor genişliğiyle orantılı ölçeklenir, böylece duvar öğeleri genişlik ayarı değişse de duvarda kalır.
  5. `min_sector ≤ max_sector`. Tehlike türü etiketlenmez (çocuklardan okunur); etiketler seçim içindir (ör. `intro`, `breather`).
  6. Dosya adı: `<ana tehlike>_<desen>_<nn>.tscn` (örnek: `spike_zigzag_01.tscn`: 8 vuruş, 2. vuruşta sol, 4.'de sağ, 6.'da sol diken).
  7. Öğe adı taraf + vuruş: `SpikeLeft2`, `SpikeRight4_5` (doğrulayıcı iletilerinde bu adlar görünür).
  8. **Duvar boşluğu (M2-11):** `WallGap` öğesi (`scripts/levels/wall_gap.gd`, betikli `Node2D`): konumu boşluğun alt ucu, x = ±450 (hangi duvar), `length` yarım vuruş katı (100 = 1 vuruş); boy vuruşla ölçeklenir, parçanın içinde kalır. Ad: `GapLeft2`. `ChunkInfo.gaps()`, `gap_range()`.
  10. **Veri bloğu ve lazer (M2-12):**
      - `scenes/entities/block.tscn`: betiksiz pasif `Area2D`, 240 × 120 px, koridorda (x 1 m adımında). Geçiş yolunu keser: oyuncu bloğun hizasından geçerken duvarda olmalı.
      - `scenes/entities/laser.tscn` + `scripts/entities/laser.gd` (`Laser`): duvara bağlı yatay ışın, kökü duvarda, `length` (px) koridora uzanır, kalınlık 16 px; sağ duvarda `scale.x = −1`. **Açık penceresi vuruşa ortalı:** her vuruşun çeyrek öncesinden çeyrek sonrasına kadar açık (`on_phase` 0,5 → yarım vuruşa ortalı). Engeller yarım vuruş ızgarasında durduğu için oyuncu ışını ya tamamen açıkken ya tamamen kapalıyken geçer; `on_phase` 0,5'lik bir ışın tam vuruşta geçilirken kapalıdır (aldatıcı). Açıkken çarpışır; kapalıyken şekli kapalı, görüntüsü sönük.
      - **Neden vuruşa ortalı:** Tırmanış hızı sabit olduğu için bir yükseklikten geçiş anı oyuncunun elinde değildir. Açılıp kapanma tam vuruş/yarım vuruş anında olsaydı ızgaradaki her ışın, geçiş penceresi bir değişme anına denk geldiği için her evrede tehlikeli olurdu (M2-12'de testle görüldü). Koridoru baştan sona kesen ışın da ya hep ölümcül ya hep zararsız olurdu; bu yüzden ışınlar duvara bağlıdır. İki duvardan kısa ışınlar ortada bir açıklık bırakır (**lazer kapısı**): oyuncu oradan ancak geçişin ortasındayken, yani zamanlanmış bir çevirmeyle geçer.
      - **Vuruş zinciri:** `Run` her adımda `ChunkSpawner.set_beat(beat_time / vuruş)` → `ChunkInfo.set_beat` → `Laser.set_beat` (aşağı çağrı). Parçalar tam vuruşta başladığı için evre parçanın yerinden bağımsızdır. Test: gerçek turda her `Events.beat` adımında açık, yarım vuruşta kapalı.
  9. **İzinli tehlikeler:** `ChunkInfo.hazard_types()` (tehlike sahnesinin dosya adı, boşluk için `gap`) parçanın her sektöründe `SectorDef.allowed_hazards` içinde olmalı; doğrulayıcı denetler (boşluk S2'den itibaren).
- **İlk parça seti** (M2-06, yalnızca diken, 15 parça):

  | Zorluk | Parçalar | Sektör | Desen |
  | --- | --- | --- | --- |
  | 1 | `spike_single_01/02`, `spike_wall_01/02`, `spike_pair_01` | S1–S3 | Tek diken; bir duvar boyu 4 diken; aynı duvarda iki diken |
  | 2 | `spike_zigzag_01/02`, `spike_switch_01/02` | S1–S5 | 2 vuruşta bir taraf değiştiren; iki dikenlik blok sonra öbür duvar |
  | 3 | `spike_zigzag_03/04`, `spike_ladder_01`, `spike_long_01`, `spike_tease_01` | S1–S5 | 1,5 vuruşluk zikzak; ikişerli merdiven; uzun bloklar; karışık |
  | 4 | `spike_triple_01` | S1–S5 | 1,5 vuruş arayla dört zorunlu çevirme |

  - Doğrulama: 65 sektör denemesi, 0 hata. İlk diken en erken 2. vuruşta (birleşim yeri kuralı).
  - **Bloklu ve lazerli parçalar (M2-12):** `block_center_01` (2), `block_spike_01` (3), `block_double_01` (3) S2–S5; `laser_single_01` (3), `laser_zigzag_01` (4), `laser_gate_01` (4: iki duvardan 150 px'lik ışın, 600 px açıklık) S3–S5. Kütüphane 25 parça; doğrulama 62 deneme, 0 hata.
  - **Boşluklu parçalar (M2-11, S2–S5):** `gap_single_01/02` (zorluk 2: tek tarafta 1,5 vuruşluk boşluk), `gap_switch_01` (3: önce sol, sonra sağ boşluk), `gap_spike_01` (3: sol boşluk, ardından sağda diken). Kütüphane 19 parça; doğrulama 53 deneme, 0 hata.
  - **Ölçüm** (Redmi, ölümsüz mod, 2 dk): 1577 m, 28 parça yerleşti, 12'si farklı, art arda aynı parça yok; günlükte uyarı yok. Ölümden yeni tura 371–386 ms (15 parçanın havuzu tur başında kuruluyor: M2-04'e göre ≈ +25 ms).
- `ChunkSpawner` (`scripts/systems/chunk_spawner.gd`, M2-04):
  - **Kütüphane:** seçilebilecek parçalar `ChunkLibrary` kaynağında (`data/chunks/chunk_library.tres`) elle listelenir. Yayın sürümünde `res://` klasörü güvenle taranamaz; test, klasördeki her parçanın listede olduğunu denetler.
  - Görünür alanın üstünde **2 ekranlık** alanı dolu tutar. Önce üst kenarı ekranın 100 px altına inen parçaları havuza döndürür, sonra ekler.
  - Parçalar **boşluksuz** dizilir: her parçanın alt kenarı bir öncekinin üst kenarıdır. İlk parça oyuncunun başlangıcından `run_start_gap` (25 m) kadar yukarıda, **tam vuruşa yuvarlanarak** başlar (S1'de 4 vuruş = 28,8 m). Böylece vuruş ızgarası turun başından hizalıdır.
  - Sıradaki parçayı `RunRng.weighted_index` ile, sektöre izinli ve sığan parçalar arasından seçer.
  - **Zorluk eğrisi (M2-10):** Hedef zorluk sektör içindeki ilerlemeyle `SectorDef.min_difficulty`'den `max_difficulty`'ye doğrusal çıkar (son sektör boyunu aşınca en zorda kalır; `target_difficulty()`). Ağırlık `exp(−½ · ((zorluk − hedef) / difficulty_spread)²)` (çan eğrisi; `TuningConfig.difficulty_spread` = 0,5). Son `no_repeat_count` (3) parça yeniden seçilmez; sığan başka parça yoksa kural esner. Günlük: `placed_difficulties`, `placed_targets`; olay günlüğünde `chunk_placed … difficulty=… sector=…`.
    - **Ölçüm** (gerçek oyun, ekransız, ölümsüz, 5 tur, S1'in 13 parçası): ilk üçte bir ortalama zorluk 1,45, son üçte bir 2,40. Genişlik 1,0 iken fark 0,58 idi (hedef 1'de bile 2 zorluklu parçalar %60 ağırlık alıyordu), 0,7'de 0,65. Sektör başının 1'e inmemesinin nedeni içerik: S1'de yalnızca 5 kolay parça var ve tekrar yasağı 3'ünü dışlıyor; parça sayısı arttıkça (M2-12) eğri keskinleşir.
  - **Nefes alma (M2-09):** Yeni sektör, `TuningConfig.sector_breath` (2,5 sn, GDD §12) kadar engelsiz başlar. Süre yeni sektörün hızıyla px'e çevrilip tam vuruşa yukarı yuvarlanır (S2: 5 vuruş = 2,73 sn; S3: 5 vuruş = 2,5 sn); ızgara bozulmaz. Eski sektörün sonuna sığmayan kalan da bu boşluğa eklenir.
  - **Sektörler (M2-08):** Her sektör kendi vuruş boyuyla (`SectorDef.beat_px()`) dizilir; ızgarası sektörün başladığı yükseklikten başlar. Parça sektör sınırını aşmaz: sona sığan parçalar arasından seçilir, hiçbiri sığmazsa kalan boş bırakılır ve sıradaki sektör tam sınırdan başlar. Sınırlar dünyada `başlangıç_y − (sektör_sonu − başlangıç_sektörünün_başı)`. Havuzlar katalogdaki en kısa vuruşa göre kurulur.
  - Koridor genişliği ayarı değişirse etkin parçalar yeniden yerleşir (duvar öğeleri duvarda kalır).
  - **Havuzlar:** her parça sahnesi için bir `ObjectPool` (§8.7). Kopya sayısı en uzun ekrana göre (`Corridor.MAX_VIEW_HEIGHT` = 3200 px) hesaplanır, cihazdan bağımsızdır: `tavan((3200 × 3 + 100) / parça_boyu) + 1`. Aynı parça art arda seçilse de yeter.
  - **Yerleştirme günlüğü:** `placed_names`, `placed_bottoms` (testler, M2-17).
  - **Ölçüm** (Redmi, M2-04): ölümsüz modda 391 m kesintisiz akış, günlükte havuz uyarısı yok; ölümden yeni tura 346–360 ms (M1'deki 348–360 ms ile aynı, havuz kurulumu fark edilmiyor).
- **Çözülebilirlik:** İki zorunlu çevirme arası süre ≥ çevirme geçiş süresi + tepki payı; engel ≥ 1,2 sn önceden görünür (onaylı ileri görüş 28 m ile 22 m/sn tavanında 1,27 sn, GDD §13.1).
- **Parça doğrulama aracı** (M2-05): `tools/chunk_validator.gd` (`ChunkValidator`) + `tools/validate_chunks.gd`; tam kontrolün 4. adımı. Yeni parça tasarlarken tek başına da çalışır: `<godot> --headless --path . --script res://tools/validate_chunks.gd -- res://scenes/levels/chunks/x.tscn`.
  - **Model:** Parça izinli her sektör hızında kare kare (60 Hz) denenir. Duvardan duvara geçiş `Player` ile aynı fizikle hesaplanır (≈ 22 kare). Oyuncu kusursuz zamanlar ama insandır: yere indikten sonra en az **tepki payı (0,2 sn = 12 kare)** bekler.
  - **Durumlar:** Duvarda (taraf, inişten beri kare) ve geçişte (hedef, çevirmeden beri kare). Sondan başa "buradan parçanın sonuna sağ çıkılabilir mi?" tablosu kurulur.
  - **Birleşim yeri kuralı:** Parça **her giriş durumundan** geçilebilmeli: iki duvarda yeni inmiş olarak ve önceki parçadan kalan yarım geçişin her karesinden. Böylece parçalar hangi sırayla gelirse gelsin birleşim yeri de adildir. Sonuç: parçanın ilk ~1,5 vuruşuna duvar tehlikesi konamaz (S1'de 1. vuruştaki diken yakalanır).
  - **Ek denetimler:** Tehlike kutusu parçanın sınırından taşmaz. Her sektörün en az bir parçası vardır. Kamera kuralı her sektör hızında (`(ileri görüş − kutunun yarı boyu) / hız ≥ 1,2 sn`).
  - **Temkin:** Tehlikeler kutu (AABB) olarak alınır; dikenin üçgeni yerine kutusu, birkaç piksel (≈ 0,01 sn) temkinlidir.
  - **Hava geçişi sayılır:** İki duvarda aynı yükseklikteki diken çifti, geçişin ortasında aralarından süzülerek geçilebilir; araç bunu çözülebilir sayar (oyunda da öyle). Çözülemez örnek için iki duvar bir vuruş boyunca kapatılır (`tools/fixtures/chunk_unsolvable.tscn`).
  - **Lazer (M2-12):** Işın kutusu yalnızca açık olduğu karelerde tehlikedir. Açık olup olmadığı `Laser.is_on_at()` ile oyuncunun parça içindeki vuruş konumundan (`−y / vuruş_px`) hesaplanır; parça tam vuruşta başladığı için oyundaki vuruş saatiyle aynıdır. Işının kutusu `beam_rect()`'ten alınır (şekli `_ready`'de kurulduğu için ağaçta olmayan parçada sahnedeki şekle güvenilmez).
  - **Duvar boşluğu (M2-11):** Gövde tamamen boşluğun içindeyken (boşluk her iki uçtan gövdenin yarısı kadar daraltılır) o duvarda bulunmak ya da oraya inmek düşmektir. Coyote süresi tanınmaz: doğrulama oyundan biraz daha sıkıdır, parçalar coyote'a dayanmaz. İzinli tehlike türleri de sektör sektör denetlenir.
  - **Hata iletisi:** Hangi sektörde, hangi girişten, kaçıncı saniyede ve hangi tehlikelere çarpılarak geçilemediği: `S1: sol duvardan girişte 2,05 sn sonra geçilemiyor: SpikeRight35 (3,5. vuruş); SpikeLeft35 (3,5. vuruş)`.
  - Sektör hızları ve BPM `SectorCatalog`'dan okunur (M2-08); katalogda olmayan sektörler (S4–S5, M4-07) denenmez.
- **Belirlenimcilik:** Harita yalnızca `tohum + başlangıç sektörü`ne bağlıdır; oyuncunun hareketlerine ve ekran boyuna bağlı değildir.
  - `Run.rng`'yi yalnızca `ChunkSpawner` çeker. Rastgelelik isteyen başka bir sistem gelirse kendi `RunRng` akışını alır (tohumdan türetilmiş). Yoksa çekilişlerin sırası kare zamanlamasına ve ekran boyuna göre değişir, harita da değişir.
  - Seçim havuzun doluluğuna bakmaz. Havuz tükenirse (olmaması gerekir) `ObjectPool` uyarı yazıp yeni örnek oluşturur; harita bozulmaz, sorun testte görünür.
  - Test: aynı tohum 16:9 ve 20:9 ekranda aynı parça dizisini veriyor (`tests/systems/chunk_spawner_test.gd`).
- **`RunRng`** (`scripts/systems/run_rng.gd`): tur tohumuyla kurulan `RandomNumberGenerator` sarmalayıcısı; oynanıştaki tek rastgelelik kaynağı (.clauderules §5). M1-08'de yazıldı, M2-01'de gdUnit4 testleriyle sabitlenir.
  - Metotlar `next_float()`, `range_int()`, `range_float()`, `chance()`, `make_seed()`. `randf` ya da `seed` gibi adlar genel fonksiyonları gölgeler ve katı kontrolde hata verir.
  - `Run.rng`'nin sahibi `Run`'dır. `Run.run_seed` 0 ise `RunRng.make_seed()` kullanılır; M1-09'dan sonra tohumu `GameManager` verir.
- **Geçici engel yerleştirici** (`SpikeSpawner`, M1-08 – M2-04): düz aralıklı, tarafı rastgele dikenler. M2-04'te `ChunkSpawner` gelince kaldırıldı; "Geçici engeller (M1)" ayar grubu (`spike_spacing`, `spike_start_gap`) da kalktı, yerine `run_start_gap` geldi.

### 8.3 Ritim (Conductor)

- **Tek doğru zaman kaynağı, oyun zamanıdır** (`run_time`, ölçeklenmiş `delta` ile ilerler). Müzik ona hizalanır.
- Müzik konumu `get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()` ile okunur. Kayma eşiği aşılırsa (başlangıç 40 ms) müzik yeniden hizalanır. ⚠️ eşik M2–M3'te ayarlanacak.
- Müzik geçişleri ölçü (bar) sınırına denk getirilir.
- **Dokunuşlar müziğe göre yargılanmaz** (Android ses gecikmesi cihazdan cihaza değişir). Müzik yalnızca bölüm yerleşimini belirler.
- **Zaman ölçeği kuralı:** `Engine.time_scale` değiştiğinde (kıl payı yavaş çekimi, duraklatma) `AudioManager` müziğin `pitch_scale` değerini aynı orana çeker. Bu, bant yavaşlaması gibi bir efekt verir ve senkronu korur.
- Diriliş ve duraklatma sonrasında müzik `run_time`'a göre konumlanır.
- **Uygulama (M2-07):**
  - `Conductor` (`scripts/systems/conductor.gd`, Run'ın çocuğu): `run_time` ve `bpm` (`@export`, şimdilik 100; M2-08'de `SectorDef`). `Run._physics_process` her adımda önce `advance(delta)` çağırır; böylece `run_time` oyuncunun konumuyla aynı adımda ilerler. Geçilen her vuruşta `Events.beat(index)` (1'den başlar).
  - Tempo sektörden gelir (M2-08): `Run`, `Conductor.set_tempo(bpm, başlangıç_anı)` çağırır; vuruşlar o andan sayılır, ses `beat_time()`'a (ızgaranın başından beri geçen süre) hizalanır.
  - **Hız basamağı (M2-08):** Oyuncu sektör sınırını geçtiği adımda `Run` hızı ve tempoyu değiştirir ve `Events.sector_entered` yayar. Oyuncu o adımda sınırı biraz aşmıştır; yeni ızgaranın başlangıç anı `run_time − aşma / yeni_hız` alınır. Böylece yeni sektördeki engeller de tam vuruş anlarında geçer (test: kısa sektörlerle S1→S2→S3, her sektörde diken geçişi yarım vuruştan ≤ 1 kare uzak). Telefonda S2 → S3 geçişi 71,40 sn'de oldu (1000 m ÷ 14 m/sn = 71,43 sn); metronom kayması S2'de −18…−26 ms.
  - **Vuruşa hizalama:** Oyuncu turun başındaki yüksekliğinden vuruş ızgarasıyla tırmanır; parçalar tam vuruşta, öğeler yarım vuruşta durur. Bu yüzden her diken yarım vuruş anında geçer. Test: gerçek turda 1500 karede her diken geçişi yarım vuruştan ≤ 1 kare uzak (`tests/systems/conductor_test.gd`); ilk parçanın tam vuruşa yuvarlanması kaldırılınca test hata veriyor.
  - **Ses:** `Conductor` her adımda `AudioManager.sync_beat_clock(run_time, bpm)` çağırır (autoload servis çağrısı; ses düğümü autoload'un kendi çocuğudur). Müzik gelene kadar kodla üretilen bir ölçülük metronom çalar (`AudioStreamWAV`, 44,1 kHz, 4 vuruş, ilk vuruş vurgulu; dış dosya yok). `Music` ve `SFX` ses yolları `default_bus_layout.tres`'te.
  - **Hizalama:** Döngü, duyulan konumu `run_time`'a denk gelecek yerden çalar (`play(run_time + gecikme)`). Kayma 15 karelik ortalamayla ölçülür (konum karıştırma tamponu kadar titrer). 40 ms'yi aşarsa yeniden konumlanır. Çalmadan ya da konumlamadan sonra 0,5 sn ölçülmez. Turun ilk düzeltmesi hemen, sonrakiler ölçüde en fazla bir kez yapılır.
  - Tur başlayınca çalar, oyuncu ölünce durur. `pitch_scale` = `Engine.time_scale`.
  - **Ölçüm (S-03, Redmi):**
    - `AudioServer.get_output_latency()` Android'de **0 ms** dönüyor (PC'de 10 ms). Gerçek donanım gecikmesi koddan bilinemez; duyulan tık o kadar geç kalır. Telafi için ileride oyuncunun ayarlayacağı bir "ses kaydırma" ayarı gerekir (M5 ayarlar). Kulak testi M2-18'de.
    - 77 sn ölümsüz turda kayma ±20 ms içinde kaldı, yeniden konumlama gerekmedi. 40 ms sınırı uygun.
    - Tur başında, havuz kurulumu bir kare takılmasına yol açıyor; fizik kaçırdığı adımları art arda çalıştırınca oyun saati ileri atlıyor ve ses −50…−119 ms geride kalıyor (PC'de de). İlk düzeltme 0,6 sn içinde yapılıyor.
  - **Dersler (M2-07):**
    - **Döngülü `AudioStreamWAV` koddan üretilirken `loop_end`'den sonra sessiz bir pay bırakılır** (`LOOP_TAIL_SAMPLES` = 64). Pay yokken Redmi'de (karıştırma hızı = akış hızı = 44,1 kHz) her döngü sonunda ses iş parçacığı çöktü (SIGSEGV; çökme kaydında örnek sayısı 105840 görünüyordu). PC'de (48 kHz, örnek hızı dönüştürmeli yol) görülmedi.
    - Her karede `seek()` yapılmaz: `seek` = durdur + çal; ölçüm titremesine göre her karede konumlamak ses iş parçacığını yorar. Ortalama + bekleme + ölçü sınırı kullanılır.
    - `play()`'den hemen sonra `playing` hâlâ `false` olabilir; çalma durumu ayrı bir bayrakla tutulur.

### 8.4 Çöküş duvarı (PressureSystem)

- Durum: `distance_m` (oyuncunun altındaki mesafe).
- Her fizik adımında sektörün sürünme hızı kadar azalır.
- Olaylar mesafeyi değiştirir: Glimmer → iter, kıl payı → iter, kalkan kırılması → çeker. Değerler `TuningConfig`'te.
- `distance_m ≤ 0` → `Events.player_died(WALL)`. Yakınlık, `wall_proximity_changed` ile yayınlanır.
- Görsel (`CollapseWall`), oyuncunun `distance_m × 50 px` altında çizilir.
- **Uygulama (M2-15):**
  - `PressureSystem` (`scripts/systems/pressure_system.gd`, Run'ın çocuğu): `setup(başlangıç, en_fazla, sürünme)`, `advance(delta)` (Run, oyuncu canlıyken çağırır), `push()`, `pull()`; mesafe sıfıra inince yukarı `wall_reached`. Run bunu `Player.die(WALL)`'a bağlar: bütün ölümleri oyuncu duyurur ve oyuncu donar; debug ölümsüzlüğünde yok sayılır.
  - Değerler: başlangıç 20 m, en fazla 30 m, Glimmer +1 m, kıl payı +3 m, kalkan −8 m (M2-16) → `TuningConfig` "Baskı" grubu. Sürünme sektörden: `SectorDef.wall_creep` (S1 0,3; S2 0,425; S3 0,55 m/sn; GDD'deki S1 0,3 → S5 0,8 aralığının doğrusal ara değerleri).
  - Geçici görsel `scenes/entities/collapse_wall.tscn`: kırık üst kenarlı koyu kırmızı bant ve parlak kenar çizgisi; Run her adımda oyuncunun mesafe × 50 px altına koyar. Kesin görsel (glitch) M3'te.
  - Yakınlık: `1 − mesafe_px / (ekranın alt kenarı − oyuncu)`; 0 duvar ekranın altındayken, 1 oyuncuya değince. 0,01'den az değişim yayılmaz. HUD'da kenarlarda kırmızı vinyet (`%WallVignette`, radyal geçiş dokusu yalnızca dış %30'da kırmızı, saydamlık = oran × 0,6, dokunuşu yutmaz). İlk değerler (dış %45, × 0,85) Redmi'de duvar yaklaşınca ekranın çoğunu kızartıp engelleri okunmaz yapıyordu (M2-15 cihaz denemesi). Gerilim sesi M3'te.
  - **Redmi denemesi (2026-10-12, ölümsüz, S3):** sektör afişi, kehribar ton, duvar boşlukları, veri blokları, lazerler, Glimmer sayacı (1→3), çöküş duvarının ~36 sn'de oyuncuya yetişmesi ve vinyet görüldü. M2-11, M2-12 ve M2-13'ün bekleyen cihaz denemeleri de bununla tamamlandı.

### 8.5 Kıl payı (GrazeDetector)

- `Hurtbox`'tan biraz büyük bir `Area2D` kullanılır (başlangıç +40 px).
- Bir tehlike bu alandan, `Hurtbox`'a hiç değmeden çıkarsa → kıl payı. `Run` kombo sayacını yönetir ve `Events.near_miss(combo)` yayar.
- **Uygulama (M2-14):**
  - `GrazeDetector` (`scripts/components/graze_detector.gd`, oyuncunun çocuğu, maske `hazard`): çarpışma kutusu + her yanda `TuningConfig.graze_margin` (0,8 m = 40 px). İçeri giren tehlikeleri izler; çıkan tehlike çarpışma kutusuna değmediyse yukarı `grazed` yayar. `Hurtbox.hit(alan)` değen alanı taşır; `Player` onu `mark_hit()` ile işaretler (kalkan ya da ölümsüzlükle geçilse de kıl payı sayılmaz).
  - `Player.near_missed` (yalnızca canlıyken) → `Run`: son kıl payından bu yana `combo_window` (2,5 sn, oyun zamanı) geçmediyse kombo uzar, geçtiyse 1'den başlar. Çarpan `RunStats.multiplier`: kombo ≥ `combo_x2_at` (3) → ×2, ≥ `combo_x3_at` (6) → ×3 (ilk değerler). Her kıl payında `Events.near_miss(kombo)`; pencere dolunca `Events.combo_ended` ve çarpan 1. `GameManager` sayıyı `RunResult.near_misses`'a yazar.
  - Yavaş çekim, "KIL PAYI!" yazısı ve parlama (GDD §15) görsel geri bildirimdir: M3'te. Çöküş duvarını itme M2-15'te.
  - **Yanlış pozitif ölçümü:** Ölümsüz, dokunuşsuz oyuncu (sol duvarda kalır, sol duvardaki tehlikelere değer, sağdakilerden uzaktır) S1 ve S3'te 4000'er karede 0 kıl payı saydı.

### 8.6 Toplanabilirler ve mıknatıs

- Glimmer'lar desen parçalarının içinde yerleşiktir (belirlenimci).
- Mıknatıs alanındaki Glimmer'lar oyuncuya doğru çekilir (M4).
- Toplanan değer ve kombo çarpanı `RunStats` içinde hesaplanır. `RunStats` turun istatistiklerini tutan, `Run`'a ait bir `RefCounted` nesnedir.
- **Uygulama (M2-13):**
  - `scenes/entities/glimmer.tscn` + `Glimmer` (`Area2D`, katman `collectible` = 16, maske `collector` = 8): yuvarlak (yarıçap 18 px), yeşil. Oyuncunun toplama alanı değince kendini gizler, şeklini (ertelenmiş) kapatır ve yukarı `collected(value)` yayar; ikinci değme sayılmaz.
  - `Collector` (`scripts/components/collector.gd`): oyuncunun çocuğu, katman `collector`, yarıçap `TuningConfig.pickup_radius` (1,5 m = 75 px; gövdeden büyük, affedici). Oyuncu Glimmer'ın kodunu çağırmaz; Glimmer alanı algılar.
  - **Yukarı sinyal zinciri:** `Glimmer.collected` → `ChunkInfo.glimmer_collected` → `ChunkSpawner.glimmer_collected` → `Run` → `RunStats.add_glimmer()` (değer × `multiplier`; kombo M2-14) → `Events.glimmer_collected(kazanılan)`. `GameManager` toplamı `RunResult.glimmers`'a, HUD sağ üstteki sayaca (`HUD_GLIMMERS`) yazar.
  - **Havuz:** `ChunkSpawner` parçayı havuzdan alınca `ChunkInfo.reset()` çağırır; Glimmer'lar yeniden etkinleşir.
  - **Yerleşim kuralları** (doğrulayıcı): Glimmer adil bir yolda toplanabilir olmalı (güvenli tablo her kare için saklanır, girişten ileriye güvenli durumlarda gidilir; toplama yarıçapı + Glimmer yarıçapı) ve **riskli yolda** olmalı: bir tehlikeye ya da boşluğa dikeyde en fazla bir vuruş uzakta. Toplama yarıçapı geniş olduğu için tek dikenin yanındaki Glimmer, geçiş sırasında dikeni sıyırarak alınabilir (kıl payı).
  - Glimmer'lı parçalar: `spike_single_01/02` (dikenin önünde, aynı duvarda), `spike_zigzag_01/02` (geçişin ortasında), `spike_switch_01` (bloklar arasında), `gap_single_01` (boşluktan önce), `block_center_01` (bloktan önce, ortada), `laser_gate_01` (kapının açıklığında).

### 8.7 Nesne havuzu

- `ObjectPool` (`scripts/systems/object_pool.gd`, `RefCounted`, M2-04): sahne başına önceden oluşturulmuş örnekler.
  - `reserve(n)` tur kurulurken örnekleri oluşturur; `acquire()` / `release()` tur sırasında. `peek()` sahnenin verisini okumak için ilk örneği verir.
  - Boştaki örnek gizli ve `PROCESS_MODE_DISABLED`'dır. İçindeki `Area2D`'ler de fizik dünyasından çıkar (`disable_mode` = REMOVE); testle doğrulandı.
  - Havuz tükenirse uyarı yazar, yeni örnek oluşturur ve `grown` sayacını artırır. Testler `grown == 0` bekler.
- Desen parçaları **bütün olarak** havuzlanır: parçanın içindeki tehlikeler parçayla birlikte gelir (§8.2). Tur başında parça başına birkaç kopya oluşur; tur sırasında düğüm sayısı sabittir (test: 900 karelik turda düğüm sayısı değişmiyor).
- Ekran altından çıkan desen parçaları havuza döner ve sıfırlanır: hareketli engeller baştan başlar, Glimmer'lar yeniden etkinleşir.

## 9. Görsel mimari

- **Şekiller:** Tüm oyun şekilleri beyaz `Polygon2D` / `Line2D` olarak çizilir. Renkler koddan, aktif sektörün `SectorPalette` kaynağından atanır. Sektör geçişinde palet yumuşak bir geçişle (tween) değişir.
- **Parlama (glow): nesne başına sahte parlama (ADR-020).** Her neon nesne kendi parlamasını taşır. Parlama toplamsal karışımla (`CanvasItemMaterial.blend_mode = ADD`) çizilir ve yalnızca nesnenin çevresini boyar. Tam ekran efekt yoktur.
  - **Çizgiler** (duvar, iz) ve geniş açılı şekiller (blok): çizginin geniş kopyaları, enine yumuşak sönen bir dokuyla çizilir. İki katman var: 64 px / %35 ve 26 px / %70.
  - **Küçük, sivri köşeli şekiller** (diken, Glimmer, oyuncu): arkalarında dairesel bir ışık lekesi durur (`Sprite2D` + radyal `GradientTexture2D`). Çizgi kopyası bu şekillerde sivri köşelerde ve kapanma noktasında yay izi bırakıyor.
  - Teknik ve başlangıç değerleri `scripts/debug/glow_bench.gd` içinde. M3-01'de yeniden kullanılabilir bileşenlere dönüşür.
  - **Ölçüm** (M0-09, Redmi, 1080×2400, 120 Hz): parlama yok 8,4 ms · sahte parlama 8,4 ms (≈ +0,9 ms GPU) · WorldEnvironment glow 17,5 ms (57 FPS). Ayrıntı §16.1'de.
- **WorldEnvironment glow kullanılmıyor (S-01 ✅).** Compatibility'de çalışıyor: Canvas arka plan modu yeterli, 3B kamera gerekmiyor, görüntüsü güzel. Ama Redmi'de kare süresini iki katına çıkarıyor. İleride güçlü cihazlar için denenirse şu bulgular geçerli:
  - Compatibility, parlama seviyelerini, gücü ve karışım modunu yok sayar.
  - Eşik rengin parlaklığına bakar; bu yüzden kırmızı geç parlar.
  - `glow_hdr_scale` varsayılanı (2.0) 2B'de parlamayı neredeyse görünmez yapar. Eşik 0.3, ölçek 0.2, yoğunluk 2.0 ile çalıştı.
- **HUD ayrımı (S-02 ✅):** `background_canvas_max_layer` (0) üstündeki `CanvasLayer`'lar ortam efektlerinden etkilenmiyor. Bu, telefonda doğrulandı. Sahte parlamada bu sorun hiç yok, çünkü parlama yalnızca dünya nesnelerine eklenir.
- **İz:** Oyuncunun geçmiş konumlarından beslenen bir `Line2D` (genişlik eğrisi + renk geçişi). Kozmetik izler `TrailDef` ile tanımlanır.
- **Parçacıklar:** `CPUParticles2D`, düşük adetli.
- **Ekran sarsıntısı:** `Camera2D` ofseti, "travma" modeliyle (travma² × gürültü).
- **Shader'lar:** Arka plan veri ağı (vuruşta nabız), çöküş duvarı glitch'i, S5 için renk kayması. Hepsi kalite ayarına bağlıdır.
- **Efekt kalitesi:** Yüksek / Orta / Düşük. Düşük modda sahte parlama tek katmana iner ya da kapanır, parçacıklar azalır.

## 10. Veri modeli (Resource sınıfları)

| Sınıf (`scripts/data/`) | Dosyalar | İçerik |
| --- | --- | --- |
| `TuningConfig` | `data/tuning/default_tuning.tres` | His ayarları, `@export_group`'larla gruplu: Hareket (`gravity_accel`, `max_side_speed`; tırmanış hızı M2-08'de `SectorDef`'e taşındı), Adalet (`input_buffer_time`, `hurtbox_scale`, `coyote_time` M2-11, `shield_grace` M2-16), Baskı (`wall_start_distance`, `wall_max_distance`, `glimmer_push`, `near_miss_push`, `shield_pull`; M2-15), Kıl payı (`graze_margin`, `combo_window`, `combo_x2_at`, `combo_x3_at`; M2-14), Toplama (`pickup_radius`, M2-13), Kamera ve dünya (`lookahead`, `corridor_width`, `run_start_gap`, `sector_breath`), Zorluk (`difficulty_spread`, `no_repeat_count`; M2-10). Tam sayı alanları ayar paneli tam sayı olarak yazar. Basınç ve kıl payı alanları ilgili görevde eklenir (M2). Ayrıntı aşağıda |
| `SectorDef` | `data/sectors/sector_01.tres` … `sector_03.tres` (M2-08) | `name_key` (`SECTOR_N_NAME`), `bpm`, `climb_speed` (m/sn), `length` (m), `allowed_hazards`, `min_difficulty`–`max_difficulty`, geçici `ambient_color`; `beat_px()`, `climb_px()`. Müzik ve kesin palet M3'te |
| `SectorCatalog` | `data/sectors/sector_catalog.tres` (M2-08) | Sıralı sektör listesi; `def_at(n)`, `start_height(n)`, `end_height(n)` (son sektör: INF), `sector_at(m)`, `min_beat_px()`. S4–S5 M4-07'de eklenir; o zamana kadar S3 bitmez |
| `SectorPalette` | `data/sectors/` | Çevre, vurgu ve arka plan renkleri |
| `UpgradeDef` | `data/upgrades/*.tres` | `id`, isim anahtarı, seviye maliyetleri `Array[int]`, seviye değerleri `Array[float]` |
| `TrailDef` | `data/trails/*.tres` | `id`, fiyat ya da açılma koşulu, renk geçişi, genişlik |
| `ChunkInfo` | desen parçası sahnelerinin kökü | Zorluk, sektör aralığı, vuruş uzunluğu, etiketler |
| `ChunkLibrary` | `data/chunks/chunk_library.tres` | Oyunda kullanılan desen parçası sahnelerinin listesi (M2-04) |
| `RunResult` | (kod, `RefCounted`) | Yükseklik, Glimmer, kıl payı sayısı, ölüm nedeni, ulaşılan sektör, tohum |
| `GameTypes` | (kod, `RefCounted`) | Paylaşılan enum'lar: `DeathCause`, `Quality`. Autoload'ların iç enum'ları tip olarak kullanılamadığı için ortak türler burada durur |

**`TuningConfig` kuralları (M1-01, ADR-024):**

- **Birimler GDD ile aynıdır:** mesafe m, hız m/sn, ivme m/sn², süre sn. Kod piksele `TuningConfig.to_px()` ile çevirir (`PX_PER_M = 50`, §3).
- **Aralık ve birim:** Her alan `@export_range(en az, en çok, adım, "suffix:birim")` taşır. Canlı ayar paneli (M1-11) kaydırıcıları bu bilgiden kendiliğinden kurar. Yeni alan eklemek için tek satır yeterlidir.
- **Değerin kaynağı:** Geçerli değerler `.tres`'tedir. Betikteki varsayılanlar yalnızca yeni bir alanın başlangıç değeridir (M1-01'de dosyanın betiği geçersiz kıldığı sınandı). Onaylanan değerler M1-15'te `.tres`'e ve GDD'ye yazılır.
- **Erişim:** Kullanan sahne kaynağı `@export var tuning: TuningConfig` ile alır. Debug build'de `user://tuning_override.tres` varsa o kullanılır (M1-11).
- Başlangıç değerleriyle duvardan duvara geçiş ≈ 0,37 sn.

## 11. Kayıt sistemi

### 11.1 Dosyalar

| Dosya | İçerik | Biçim |
| --- | --- | --- |
| `user://savegame.dat` | İlerleme | Şifreli JSON (yayın sürümü) |
| `user://savegame.bak` | Bir önceki sağlam kayıt | Şifreli JSON |
| `user://savegame_debug.json` | Debug build kaydı | Düz JSON (incelenebilir) |
| `user://settings.cfg` | Ses, müzik, titreşim, dil, kalite | `ConfigFile`, şifresiz |
| `user://tuning_override.tres` | Ayar panelinden kaydedilen değerler | Yalnızca debug |

> Not: Dosya `.json` yerine `.dat` uzantılıdır, çünkü şifrelendikten sonra içeriği okunabilir JSON değildir.

### 11.2 Şema (sürüm 1)

```json
{
  "version": 1,
  "glimmers": 0,
  "best_height_m": 0,
  "highest_sector": 1,
  "great_storage_reached": false,
  "upgrades": { "magnet": 0, "shield": 0, "head_start": 0, "glimmer_boost": 0, "second_chance": 0 },
  "trails": { "owned": ["trail_default"], "equipped": "trail_default" },
  "stats": { "runs": 0, "total_height_m": 0, "near_misses": 0, "glimmers_earned": 0 },
  "daily": { "last_date": "", "best_height_m": 0 },
  "ftue_done": false
}
```

### 11.3 Kurallar

- **Şifreleme:** `FileAccess.open_encrypted_with_pass()`.
  - Dürüst not: Anahtar uygulamanın içinde durduğu için bu gerçek bir güvenlik değil, **caydırıcılıktır**. Amaç, sıradan kullanıcının Glimmer sayısını elle düzenlemesini engellemek.
  - Liderlik tabloları sunucu tarafında (Play Games) tutulduğu için bu seviye yeterli.
- **Atomik yazma:** Önce `savegame.tmp`'ye yazılır ve geri okunarak doğrulanır. Sonra eski `.dat` → `.bak`, `.tmp` → `.dat` yapılır.
- **Yükleme sırası:** `.dat` → bozuksa `.bak` → o da yoksa yeni kayıt.
- **Sürüm geçişi:** `version` alanı okunur; `migrate_v1_to_v2()` gibi fonksiyonlarla adım adım yükseltilir.
- **Ne zaman kaydedilir:** Tur sonunda, satın alma ve kuşanmada, ayar değişiminde, uygulama arka plana geçtiğinde (`NOTIFICATION_APPLICATION_PAUSED`) ve kapanırken.
- **Bulut kaydı** (Play Games Saved Games): M7'de değerlendirilecek.

## 12. Yerelleştirme

- **HUD Glimmer sayacı (M2-13):** sağ üstte `HUD_GLIMMERS` ("%d GLIMMER"), yeşil; `run_started`'da sıfırlanır, `glimmer_collected` değerlerini toplar.
- **HUD sektör afişi (M2-09):** `HUD_SECTOR` ("SECTOR %d · %s" / "SEKTÖR %d · %s") + sektör adı anahtarı; yazı rengi sektörün geçici rengi. Ekranın %30 yüksekliğinde, 2 sn görünür, 0,4 sn'de söner. HUD adları `SectorCatalog` kaynağından okur (veri; dünyaya erişmez).

- `localization/translations.csv`: `keys,en,tr` sütunları. Godot bunu içe aktarıp çeviri kaynağına dönüştürür.
  - Koddan atanan metinler `tr("KEY")` ile gösterilir.
  - Sahnede `Label` ya da `Button` metnine doğrudan anahtar yazılır (`text = "UI_TAP"`). Godot bunu otomatik çevirir (`auto_translate_mode` varsayılanı) ve dil değişince kendisi günceller.
- Varsayılan dil: cihaz dili Türkçe ise TR, değilse EN. Ayarlardan değiştirilebilir.
- Fontlar Türkçe karakterleri (ş ğ ı İ ö ü ç) içermek zorundadır (S-06, M3).
- Büyük harf metinler çeviri dosyasına büyük harfle yazılır; kodda dönüştürülmez (`i` → `İ` sorunu).
- **Anahtar adları** `BÜYÜK_YILAN` biçiminde ve alan önekli: `APP_` (uygulama adı ve mağaza metinleri), `UI_`, `HUD_`, `SECTOR_`, `UPGRADE_`, `TRAIL_`, `SETTINGS_` (ör. `APP_TITLE`, `UI_TAP`, `SECTOR_1_NAME`).
- **Dil seçimi** (`Settings.resolve_language`): oyuncunun seçtiği dil → yoksa cihaz dili → desteklenmiyorsa İngilizce. Seçim `user://settings.cfg`'de saklanır; boş değer "cihaz dili" demektir.
  - Godot, Android 13+'ın **uygulamaya özel dil** ayarını cihaz dili olarak görüyor (M0-10, Redmi).
  - Telefonun genel dilini değiştirmeden Türkçe denemek için: `adb shell cmd locale set-app-locales com.gravityhopper.dev --locales tr-TR`. Geri almak için `--locales '""'`.
  - Android ayarlarında oyuna özel dil seçeneğinin görünmesi için uygulamanın `localeConfig` bildirmesi gerekir (M5'te değerlendirilir). Oyun içi dil seçimi M5'teki ayarlar ekranında gelir; `Settings.set_language` hazır.
  - Test cihazının sistem dili İngilizcedir; oyun orada "cihaz dili" kuralıyla İngilizce açılır.
- Üretilen `translations.*.translation` dosyaları **depoya konur** (ADR-018). Konmazsa, depoyu yeni kopyalayan herkes ilk içe aktarmada "dosya bulunamadı" hatası görür: Godot çevirileri, dosyalar üretilmeden önce yüklemeye çalışır.

## 13. Debug araçları (yalnızca debug build)

- **Debug katmanı** (`scenes/debug/debug_layer.tscn` + `scripts/debug/debug_layer.gd`, M1-02): Tüm debug araçları bu sahnede toplanır. `Main` (`scripts/main.gd`), sahneyi `Debug` (`CanvasLayer` 100) altına yalnızca `OS.is_debug_build()` iken `load()` ile yükler; yayın sürümünde hiç yüklenmez.
  - Oyun dünyasını tanımaz. İsteklerini `Events` sinyalleriyle iletir (`debug_invincibility_changed`, `retry_requested`; §7.2).
  - Kök `Control` tam ekrandır ama `mouse_filter = IGNORE` taşır, yani dokunuşları yutmaz. `process_mode = ALWAYS` olduğu için oyun duraklatılınca da çalışır.
  - **Tuşlar:** `_key_actions` sözlüğü tuş kodunu bir işleve bağlar; yeni debug tuşu eklemek bu sözlüğe bir satırdır. `_unhandled_key_input` içinde işlenir.
  - **Debug düğmesi** ("DBG"): sol üstte, viewport'ta (16, 12)–(156, 84). `focus_mode = NONE`, böylece boşluk tuşu düğmeye gitmez, çevirmeye gider. Ayar panelini açıp kapatır (M1-11); FPS görünümü panelin içindeki düğmede ve `7` tuşunda.
  - M1-02'de sınandı: ekransız denemede `7` tuşu üç görünümü sırayla değiştirdi, düğmeye dokunuş çevirme sayılmadı, ekranın ortasına dokunuş ve boşluk sayıldı. Redmi'de de düğme FPS'yi açtı ve günlükte çevirme kaydı çıkmadı.
  - **Olay günlüğü:** Önemli `Events` sinyalleri `EVENT <ad> t=<ms>` satırı olarak yazılır (`_connect_event_log`). Telefondaki denemeler `adb logcat -s godot:*` ile bu satırlardan doğrulanır. Şimdilik `player_flipped` ve `player_died cause=<NEDEN>`; yeni olaylar ilgili görevde eklenir.
  - Ders: `Viewport.push_input()` ile dokunuş taklit edilirken koordinat viewport biriminde verilecekse ikinci parametre `true` olmalı. Aksi hâlde pencere ölçeği (PC'de 450/1080) uygulanır ve nokta hedefini ıskalar.
- **Canlı ayar paneli** (M1-11, `scripts/debug/tuning_panel.gd`, debug katmanında `%TuningPanel`): `TuningConfig`'in `@export` alanlarından **otomatik** üretilen kaydırıcılar. Yeni bir ayar eklendiğinde panele kendiliğinden gelir; aralık, adım ve birim `@export_range`'den okunur.
  - **Açma:** PC'de `1`, telefonda DBG düğmesi. Panel ekranın üstünden 270–1240 px arasındadır; oyuncu her zaman 1400 px'te olduğu için açıkken de oynanabilir.
  - Panelin üstüne dokunuş çevirme yapmaz, altına dokunuş yapar (denendi).
  - **Canlı etki:** Panel, `Run`'ın kullandığı `default_tuning.tres` örneğinin kendisini düzenler. Godot `res://` kaynağını bellekte tek örnek tutar; değişiklik anında etki eder, yeni turlarda da sürer ve panelin dünyaya erişmesi gerekmez.
  - **Düğmeler:**
    - Kaydet: `user://tuning_override.tres`'e yazar.
    - Sıfırla: varsayılanları dosyadan yeniden yükler ve kayıt dosyasını siler.
    - Duraklat / Devam: `get_tree().paused`; debug katmanı `ALWAYS` olduğu için çalışır.
    - FPS ve Kapat.
  - **Açılış:** Debug build'de kayıt dosyası varsa değerleri paylaşılan örneğe kopyalanır. Bu, ilk turdan önce olur, çünkü `Main` debug katmanını turdan önce yükler.
  - **Onaydan sonra kayıt silinir:** Onaylanan değerler `.tres`'e ve GDD'ye geçince telefondaki ve PC'deki kayıt dosyası silinir (`adb shell run-as com.gravityhopper.dev rm files/tuning_override.tres`). Yoksa ileride değişen varsayılanları sessizce ezer (M1-15'te yapıldı).
  - **Claude dosyayı okur:**
    - PC: `%APPDATA%\Godot\app_userdata\Gravity Hopper\tuning_override.tres`.
    - Telefon: `adb shell run-as com.gravityhopper.dev cat files/tuning_override.tres` (debug paketi `run-as`'a izin veriyor; M1-11'de denendi).
  - Ekransız deneme (13 durum): satırların kurulması, canlı etki (15 m/sn = 750 px/sn), kaydetme, yeni turda korunma, sıfırlama, açılışta kayıtlı dosyanın uygulanması. Redmi'de kaydırıcı → Kaydet → dosya okundu → Sıfırla → dosya silindi.
- **PC tuşları** (M1'de kesinleşti; `5` M2-08'de gelir):

  | Tuş | İşlev | Görev |
  | --- | --- | --- |
  | `1` | Ayar paneli | M1-11 |
  | `2` | Ölümsüzlük | M1-12 |
  | `3` | Çarpışma kutularını göster | M1-12 |
  | `4` | Yavaş çekim | M1-12 |
  | `8` | Kalkan ver (paneldeki "Kalkan" düğmesi de; `Events.debug_shield_requested`) | M2-16 |
  | `5` | Sonraki sektörün başından yeni tur (son sektörde aynı sektör); paneldeki "Sektör ›" düğmesi | M2-08 |
  | `5` | Sonraki sektöre atla | M2-08 |
  | `6` | Ekran oranı döngüsü (16:9 → 20:9 → 4:3) | M1-06 |
  | `7` | FPS / kare süresi | M1-02 |
  | `R` | Anında yeniden başla | M1-12 |

  F5–F8 kullanılmaz; Godot editör kısayollarıyla karışır.
- **Debug tuşlarının uygulanışı (M1-12):**
  - Tuşlar ayar panelinin ikinci sırasındaki düğmelerin basılı durumunu değiştirir; işi düğmenin `toggled` sinyali yapar. Böylece tuş ve düğme hep aynı durumu gösterir. Telefonda bu düğmeler kullanılır.
  - **Ölümsüzlük (`2`):** `Events.debug_invincibility_changed(enabled)` yayılır. `Player` darbeleri yok sayar ve yarı saydam olur (alfa 0,45). Yeni turdaki oyuncu bu durumu bilmediği için debug katmanı her `run_started`'da durumu yeniden duyurur.
  - **Çarpışma kutuları (`3`):** `SceneTree.debug_collisions_hint` açılır ve ağaca `queue_redraw` yayılır; dünyaya tek tek erişilmez.
  - **Yavaş çekim (`4`):** `Engine.time_scale = 0,3`. Müzik henüz yok; .clauderules §5 gereği müzik geldiğinde `AudioManager` `pitch_scale`'i `Engine.time_scale`'e uydurur.
  - **`R`:** `Events.retry_requested` yayar; `Main` turu yeniden kurar.
  - Ekransız denemede 10 durum geçti: ölümsüzken 400 karede ölüm yok, R sonrası ölümsüzlük sürüyor, kapatınca diken öldürüyor, çarpışma kutuları açılıp kapanıyor, yavaş çekimde 60 karede tam 180 px.
  - Redmi'de ölümsüzlük düğmesiyle 8 sn'de ölümsüz 143 m tırmanıldı.
  - **Başlatma argümanları (M2-07, M2-11):** `<godot> --path . -- --invincible` ölümsüzlüğü baştan açar (PC'de uzun denemeler); `--start-sector=2` ilk turu o sektörden başlatır (kare yakalama). Telefonda argüman verilemiyor (Godot'nun asıl etkinliği dışa açık değil); orada düğme kullanılır.
- **Telefonda:** Küçük, yarı saydam bir debug düğmesi paneli açar. Düğme yalnızca debug build'de görünür; yeri, HUD ile çakışmayacak şekilde M1-02'de seçilir.
  - Düğme bir `Control` olduğu için dokunuş arayüzde kalır ve çevirme yapmaz (§8.1, `_unhandled_input`).
  - Eski plandaki "köşeye üçlü dokunuş" bırakıldı: o dokunuşların her biri aynı zamanda yerçekimini çevirirdi.
- **Performans katmanı:** `godot-debug-menu` eklentisi (MIT): FPS, kare süresi grafikleri, CPU süresi. GPU süresi Android'de (GLES) ölçülemiyor (`-1`); onun yerine §16'daki GPU doluluk sayacı kullanılır.
  - Eklentinin yalnızca çalışma zamanı parçası alındı; editör eklentisi (`plugin.gd`) alınmadı, çünkü kendini autoload olarak ekliyor ve yayın sürümüne de girerdi.
  - Yükleme: Debug katmanı onu `load("res://addons/debug_menu/debug_menu.tscn")` ile örnekler (M1-02). Telefonda okunabilsin diye `CanvasLayer` 2× büyütülüp sola kaydırılır (örnek: `glow_bench.gd` → `_add_debug_menu`). Görünüm `style` özelliğiyle seçilir: 0 gizli, 1 kısa, 2 ayrıntılı.
  - `7` tuşu ve ayar panelindeki "FPS" düğmesi görünümü gizli → kısa → ayrıntılı sırasıyla değiştirir. Eklentinin kendi kısayolu F3'tür.
  - Bilinen kusur: Ayrıntılı görünümdeki uzun sürücü bilgisi satırı 2× büyütmede ekranın soluna taşar. Yalnızca debug ekranını etkiler.

### 13.1 Geliştirici araçları (oyunun dışında)

- **Sahne aracı** `tools/scene_tool.gd` (M0-11, ADR-021), `--headless --script` ile çalışır:
  - `-- tree res://sahne.tscn`: düğüm ağacını listeler. Her düğüm için ad, tür (`class_name` dahil), `%` benzersiz ad, betik, örneklenen alt sahne ve gruplar gösterilir; sahneden gelen sinyal bağlantıları sonda listelenir.
  - `-- check [--dir res://klasör]`: `tools/check.ps1`'in 3. adımıdır. Hata varsa çıkış kodu 1 döner. Denetlenenler:
    - Betiklerdeki `$Yol`, `%Ad` ve kendi üzerinde çağrılan `get_node("...")` / `get_node_or_null("...")` başvuruları.
    - Sahnelerdeki sinyal bağlantıları: kaynakta sinyal, hedefte metot var mı.
    - Sahnede kayıtlı `@export` düğüm yolları.
    - Kural ihlalleri (§3): `get_parent()` çağrısı ve `..` içeren yollar.
  - **Nasıl çalışır:** Sahneler ağaca eklenmeden örneklenir; yalnızca `_init` çalışır, `_ready` çalışmaz. Başvurular Godot'nun kendi `get_node_or_null()` çözümlemesiyle denenir. Böylece `%Ad`'ın sahiplik kuralı (bir sahne, alt sahnesinin benzersiz adlarını göremez) çalışma anındakiyle aynıdır.
  - Bulunamayan ad için en benzer adı önerir (`"%Labell"` → `"%Label"`).
  - Betik tarayıcısı yorumları ve metinleri atlar; `a % b` mod işlemini ve `"%d" % x` biçimlendirmesini benzersiz ad saymaz.
  - Varsayılan taramaya girmeyenler: `addons/`, `tools/`, `tests/`.
  - Hiçbir sahneye bağlı olmayan betiklerdeki yollar denetlenemez, `NOT` satırıyla sayılır; kural ihlalleri yine hatadır.
  - **Aracın kendi sınaması:** `tools/fixtures/scene_tool_broken.tscn` bilerek 7 hata ve birkaç tuzak içerir. `-- check --dir res://tools/fixtures` tam 7 hata ve çıkış kodu 1 vermelidir; araç değiştirildiğinde bununla sınanır.
  - S-08 çözüldü (M0-06): `--headless --script` modunda autoload'lar yükleniyor; araç GDScript ile yazılır.
- **Kod denetimi** (M0-12, ADR-022): `gdlint` (gdtoolkit 4.5.0, MIT) + kökteki `gdlintrc`.
  - **Kurulum** proje dışında, ayrı bir Python sanal ortamında: `%LOCALAPPDATA%\gravity-hopper\venv`. Yeniden kurmak için:
    - `python -m venv %LOCALAPPDATA%\gravity-hopper\venv`
    - `...\venv\Scripts\python.exe -m pip install gdtoolkit==4.5.0`
    - Kaldırmak için klasörü silmek yeterli.
  - **Kurallar:** gdtoolkit varsayılanları kullanılıyor; `.clauderules` §2 ve §8 ile örtüşüyorlar (adlandırma, sınıf içi sıra, sekme girinti, satır ≤ 100 karakter). Tek fark: `addons/` ve `.godot/` denetlenmez. gdtoolkit 4.5, Godot 4.7 sözdizimimizi sorunsuz okuyor (tipli sözlük, tipli döngü değişkeni, `@warning_ignore_start`).
  - **Claude Code kancası** (`.claude/settings.json`, depoda):
    - Tetiklenme: `PostToolUse` · `Edit|Write`.
    - Çalıştırma: exec biçimi (kabuksuz), `python ${CLAUDE_PROJECT_DIR}/tools/lint_hook.py`.
    - Betik, düzenlenen dosya `.gd` ise `gdlint` çalıştırır. Hata varsa çıktıyı Claude'a gösterir (çıkış 2); temizse ya da dosya `.gd` değilse sessiz kalır, yani bağlam yükü yok.
    - Süre: dosya başına yaklaşık 0,35 sn.
    - `.claude/.gdignore`, klasörün Godot'ya ve dışa aktarmaya girmesini engeller.
  - `tools/check.ps1`'in 4. adımı tüm projeyi `gdlint .` ile denetler. `gdlint` kurulu değilse kontrol başarısız olur.

## 14. Android ve dağıtım

- Dışa aktarma ön ayarı "Android" (`export_presets.cfg`, depoda), **Runnable** olarak işaretli: arm64-v8a + armeabi-v7a (eski 32-bit cihazlar için), immersive mod, dışlama filtresi `tools/*, tests/*, addons/gdUnit4/*`.
  - **Kullanıcı:** telefon bağlıyken editörün sağ üstündeki Android simgesine tek tık.
  - **Claude:** `tools/deploy.ps1`, yani dışa aktarma + `adb install` + başlatma + ekran görüntüsü + Godot günlüğündeki hatalar.
  - **adb sunucusu tuzağı (M1-05):** Sunucu kapalıyken bir adb komutu onu başlatır ve sunucu, o komutun çıktı borusunu miras alıp hiç kapatmaz. Komut PowerShell borusuna bağlıysa (`| Select-Object`) çağıran sonsuza kadar bekler.
    - Önlem 1: `deploy.ps1` önce sunucuyu `Start-Process ... -PassThru` + `WaitForExit()` ile borudan bağımsız başlatır. `-Wait` kullanılmaz; PowerShell 5.1'de alt süreçleri de bekler.
    - Önlem 2: `deploy.ps1`'in çıktısı boruya bağlanmaz. Sunucu dışa aktarma ya da yükleme sırasında yeniden doğarsa yalnızca boruya bağlı çağrı takılıyor; düz çağrı bitiyor (denendi).
- Dışa aktarma şablonları (4.7.2, SHA512 ile doğrulandı): `%APPDATA%\Godot\export_templates\4.7.2.stable\`. Godot sürümü yükseltilirse şablonlar da aynı sürüme yükseltilir.
- Geçici paket adı `com.gravityhopper.dev`; kalıcı ad Play'e ilk yüklemeden önce D-06'da seçilir. Paket adı değişirse telefondaki eski uygulama ayrı bir uygulama olarak kalır ve elle silinir.
- **Xiaomi / HyperOS notu:** Geliştirici seçeneklerinde hem "USB hata ayıklama" hem "USB üzerinden yükle" açık olmalı. İkincisi Xiaomi hesabı gerektirir; açılmıyorsa Wi-Fi kapatılıp mobil veriyle denenir. Her yüklemede telefonda birkaç saniyelik bir onay ekranı çıkabilir.
- **Kablosuz yükleme — ERTELENDİ (ADR-019, 2026-10-07).** Kablolu yükleme kullanılıyor; çok gerekirse aşağıdaki bulgulardan devam edilir. 2026-10-06 bulguları:
  - Eşleştirme (`adb pair`) bir kez yapılır ve ağdan bağımsızdır. Her yeni Wi-Fi ağında telefonda düğme yeniden açılır; bağlantı portu her açılışta değişir.
  - Telefon yalnızca Wi-Fi **istemcisi** iken çalışır; telefon paylaşım (hotspot) açtığında devre dışıdır.
  - Okul ağı (`sdu.edu.tr`): telefon ve bilgisayar farklı alt ağlarda, TCP erişimi yok → kablosuz çalışmaz.
  - Seçenekler: ev Wi-Fi'ı (önerilen) · bilgisayarın "Mobil etkin nokta"sı açılıp telefon ona bağlanır · kablo (her ağda yedek) · yalnızca mobil veri varsa telefon paylaşımı + eski yöntem (`adb tcpip 5555`, telefon her yeniden başladığında bir kez kablo gerekir).
  - Godot hata ayıklama bağlantısı için önce Remote Host = localhost (adb tüneli) denenecek; çalışırsa ağ değişince Godot ayarı gerekmez (kablosuza dönülürse).
- Debug anahtarı: Godot 4.7 kendisi oluşturur (`%APPDATA%\Godot\keystores\debug.keystore`). Java ve Android SDK yollarını da editör ayarlarına kendisi yazdı (S-04).
- **Yayın anahtarı** (upload keystore) M8'de oluşturulur:
  - **Depoya konmaz.**
  - İki ayrı yerde yedeklenir.
  - **Play App Signing** kullanılır.
- **Yayın ön ayarı** (M8-02): dışlama filtresine `addons/debug_menu/*`, `scenes/debug/*` ve `scripts/debug/*` da eklenir. Debug araçları yayın sürümünde zaten yüklenmez; dışlama, pakete hiç girmemelerini sağlar (§13). `main.gd` debug katmanını `ResourceLoader.exists()` ile denetlediği için dosyaların olmaması sorun çıkarmaz.
- **Gradle derlemesi** eklentiler için M7'de açılır: Play Games Services, AdMob (S-05: sürüm uyumluluğu).
- **Min / hedef SDK:** Godot 4.7 varsayılanları kullanılır. Play'in güncel hedef API şartı M8'de kontrol edilecek.
- **Paket adı** (`com.<yayıncı>.gravityhopper`) Play'e ilk yüklemeden sonra değiştirilemez. Karar D-06'da.
- **Web çıktısı** (arkadaşlara link için): tek iş parçacıklı (single-threaded, `web_nothreads_*` şablonları kurulu) dışa aktarma. Sunucuda özel başlık (COOP/COEP) gerektirmez.
  - **Barındırma: itch.io** (D-12, kullanıcı kararı, ADR-027). Sayfa "Restricted" ve şifreli olur; şifre linke gömülebilir (`?password=…`). Şifre depoya yazılmaz.
  - Elenen seçenekler: özel depodan GitHub Pages (ücretli plan), açık GitHub deposu (şifre yok), Cloudflare Pages / Netlify / GitLab Pages (ek hesap ve kurulum).
  - Yükleme: ilk sürümde kullanıcı tarayıcıdan zip yükler. İleride istenirse itch.io'nun `butler` aracıyla otomatikleşir (API anahtarı kullanıcıda kalır).
  - **Ön ayar** "Web" (`export_presets.cfg` → `preset.1`): `variant/thread_support=false`, masaüstü ve mobil doku sıkıştırması açık, dışlama filtresi Android ile aynı.
  - **Araç** `tools/web_build.ps1`:
    - Yayın çıktısını `builds/web/`'e alır ve itch.io zip'ini (`builds/gravity-hopper-web.zip`, `index.html` kökte) hazırlar.
    - `-Smoke` ile ayrıca debug çıktısını alır. Yerel `python -m http.server` sunar, görünmez Edge'i (yoksa Chrome) DevTools bağlantı noktasıyla açar.
    - Tarayıcı konsolundaki `EVENT run_started` satırlarından oyunun açıldığını doğrular; `-Shot` ile ekran görüntüsü alır.
  - **Boyut (M1-13):** `index.wasm` 37,7 MB (zip'te 9,8 MB), `index.pck` 0,12 MB.
  - **Tarayıcı denemesi:** WebGL 2.0, tek iş parçacığı; 15 sn'de 5 tur başladı ve bitti.
  - Ders: Görünmez tarayıcının `--virtual-time-budget` kipi WebAssembly derlemesini beklemez, açılış ekranında kalır. Bu yüzden gerçek zamanlı bekleme + DevTools ekran görüntüsü kullanılır.

## 15. Test ve doğrulama

| Katman | Nasıl | Ne zaman |
| --- | --- | --- |
| **Tam kontrol** | `tools/check.ps1`, altı adım: (1) içe aktarma, (2) tüm betikler "Warn" seviyesindeki kurallar geçici `override.cfg` ile "Error"a çekilerek derlenir (test betikleri dahil), (3) sahne denetimi (`scene_tool.gd check`), (4) desen parçası doğrulama (`validate_chunks.gd`, §8.2), (5) `gdlint` (§13.1), (6) gdUnit4 testleri. `TEMİZ` = sıfır hata, sıfır uyarı, başarısız test yok | Her görevde |
| Kod denetimi (anlık) | Claude Code kancası: düzenlenen `.gd` dosyasında `gdlint` | Her `.gd` düzenlemesinde, otomatik |
| Görsel kontrol | Movie Maker ile kare yakalayıp Claude'un incelemesi; asıl kanıt telefonun ekran görüntüsü | Görsel değişikliklerde |
| Davranış denemesi (geçici) | Ekransız `--script` deneme betikleri (scratchpad'de, aşağıdaki derse uygun). M2-02'de gdUnit4 testlerine taşındı; yalnızca tek seferlik ölçümler için | M1 boyunca |
| Telefon denemesi | `tools/deploy.ps1` + `adb logcat` (debug olay günlüğü `EVENT …`) + gerekirse `adb shell input tap` (önce ekran görüntüsüyle oyunun tam ekran olduğu doğrulanır) | Oynanış değişikliklerinde |
| Web denemesi | `tools/web_build.ps1 -Smoke` (görünmez tarayıcı, konsoldaki olay günlüğü) | Web sürümü hazırlanırken |
| Telefon bildirimi | `tools/notify.ps1` (ntfy.sh): `-Message` gönderir, `-Read` son okumadan beri kullanıcının yazdıklarını verir, `-Wait` kullanıcı yazana kadar 30 sn'de bir bakar. Konu adı ve son okunan kimlik `%LOCALAPPDATA%\gravity-hopper\` altında (depoda değil). Claude'un mesajları `Title: Claude - Gravity Hopper` ile işaretlenir, okurken atlanır. Türkçe karakterler UTF-8 gövdeyle bozulmadan gidiyor (denendi) | Otonom çalışma bitince, takılınca, durdurulunca (gönder); her görev bitiminde (oku) |
| Otomatik test | **gdUnit4 6.2.2** (MIT): RNG belirlenimciliği, desen üretimi, ekonomi, kayıt sürüm geçişi, oynanış davranışları. Ayrıntı aşağıda | M2'den itibaren, her görevde (tam kontrolün 6. adımı) |
| Ekonomi simülasyonu | "Kaç turda ne alınır?" betiği | M4 |
| Oyun testi | Kullanıcı: PC → Redmi → web linki | Her kilometre taşında |

**gdUnit4 testleri (M2-01):**

- **Yer:** Testler `tests/` altında, `scripts/` ile aynı klasör düzeninde durur (`tests/systems/run_rng_test.gd`); geliştirici araçlarının testleri `tests/tools/`'ta. Her dosya `extends GdUnitTestSuite`, test fonksiyonları `test_` ile başlar. Statik tip ve `gdlint` kuralları testlere de uygulanır.
- **Koşturma** (`check.ps1` 6. adım): `<godot> --headless --path . --fixed-fps 60 -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests -c --ignoreHeadlessMode -rd user://gdunit-reports`
  - `--remote-debug` kapalı bir bağlantı noktasına yönlenir; betik hatasında Godot etkileşimli hata ayıklayıcıda asılı kalmaz. Bunun ürettiği "remote port" hata satırları beklenendir ve filtrelenir.
  - `--fixed-fps 60`: her karede tam bir fizik adımı; kare sayan testler makinenin hızından bağımsızdır.
  - `-c`: ilk hatada durmaz. Raporlar proje dışına (`user://gdunit-reports`) yazılır.
  - Sıfırdan farklı her çıkış sorundur: başarısız test, hata ya da serbest bırakılmamış düğüm uyarısı.
- **Ekransız modda girdi:** gdUnit4 uyarır, ekransız modda Godot'nun girdi olayları sahneye taşınmaz. Dokunuş testleri bu yüzden `get_tree().root.push_input(olay, true)` ile yapılır (M1'deki denemelerde çalıştığı görüldü).
- **Dışa aktarma:** `addons/gdUnit4/*` ve `tests/*` her iki ön ayarda dışlanır; APK'da yok (M2-01'de denetlendi).
- **Kabul (M2-01):** Bilerek bozulan bir test tam kontrolü `SORUN VAR`'a çevirdi ve beklenen/gelen değeri satır numarasıyla gösterdi.
- **M1 davranış testleri (M2-02):**

  | Dosya | Neyi sabitler |
  | --- | --- |
  | `tests/entities/player_test.gd` | Sol duvara yerleşme, tırmanışın tam sabit olması (60 karede 600 px), yalnızca duvardayken çevirme, dokunma tamponu (ayardan okunur, pencere dışı dokunuş düşer), `Player.is_tap` kuralları (sahte fare, ikinci parmak, tuş tekrarı) |
  | `tests/entities/player_death_test.gd` | Kendi duvarındaki diken bir kez öldürür, öbür duvardaki öldürmez, ölü oyuncu donar, debug ölümsüzlüğü |
  | `tests/main_test.gd` | Tur kurulumu, ölümden yeni tura ≤ 30 kare (0,5 sn), sonuçta yükseklik/neden/tohum, sonuç ekranında ikinci ölümün yok sayılması, `retry_requested` |
  | `tests/debug/debug_layer_test.gd` | DBG'ye dokunuş çevirmez (oyun alanına dokunuş çevirir), DBG paneli açar/kapatır, her aralıklı ayar için bir kaydırıcı, tuşlar 1/2/3/4, ölümsüzlüğün yeni tura taşınması |
  | `tests/ui/hud_test.gd` | Yükseklik ve rekor metni, rekorun düşmemesi, dil değişince TR metni |
  | `tests/systems/object_pool_test.gd` (M2-04) | Örneklerin baştan oluşması, gizli/işlemsiz bekleme, aynı düğümlerin yeniden kullanımı, tükenince büyüme sayacı, boştaki tehlikenin fizikten çıkması |
  | `tests/systems/chunk_spawner_test.gd` (M2-04) | İlk parçanın tam vuruşta başlaması, 2 ekran önün boşluksuz dolu olması, 400 m kaydırmada düğüm sayısının sabit kalması, aynı tohumun iki ekran boyunda aynı haritayı vermesi, sektör süzgeci, koridor genişliği, gerçek turda 900 kare boyunca düğüm sayısı |
  | `tests/entities/shield_test.gd` (M2-16) | Kalkanla ilk diken emilir (ölüm yok, `shield_changed` [true, false], duvar 8 m yaklaşır), 1 sn içindeki ikinci diken dokunulmazlıkla geçilir, sonraki öldürür; kalkansız ilk diken öldürür |
  | `tests/systems/pressure_system_test.gd` (M2-15) | Sürünme, itmede üst sınır, çekme, tek seferlik `wall_reached`; hızlı sürünmeli turda 2 sn'de `WALL` ölümü, görsel oyuncunun mesafe × 50 px altında, yakınlık artarak 1'e varıyor; ölümsüzken ölüm yok; Glimmer +1 m, kıl payı +3 m |
  | `tests/entities/near_miss_test.gd` (M2-14) | 60 px yanından geçen tehlike kıl payı, 130 px'ten geçen değil, değen (ölümsüzken) değil; 0,5 sn arayla üç kıl payında kombo 1-2-3, çarpan ×2, 2,5 sn sonra `combo_ended` ve ×1; `RunResult.near_misses` |
  | `tests/entities/glimmer_test.gd` (M2-13) | Gerçek turda yoldaki Glimmer'lar toplanıyor, `Events` değeri, `RunStats` ve `RunResult.glimmers` tutuyor; ikinci değme sayılmıyor, `reset()` geri getiriyor; çarpan |
  | `tests/entities/laser_test.gd` (M2-12) | Açık pencere vuruşa ortalı (ve `on_phase` 0,5), `set_beat` şekli ve görüntüyü açıp kapatıyor, ışın boyu `length`'ten; gerçek turda her vuruş adımında açık, yarım vuruşta kapalı |
  | `tests/levels/corridor_test.gd` (M2-11) | Boşluksuz duvar tam katı; boşluk yalnızca kendi duvarını, tam kenarından keser; boşluk kalkınca duvar geri gelir; düğüm sayısı sabit |
  | `tests/entities/player_fall_test.gd` (M2-11) | Boşluktan `FELL` ile düşülür; duvar bittikten 2 kare sonraki dokunuş çevirir ve oyuncu öbür duvara varır; coyote dolduktan sonraki dokunuş kurtarmaz |
  | `tests/systems/chunk_spawner_test.gd` (M2-10 eki) | Beş tohumda S1'in son üçte birindeki ortalama zorluk ilk üçte birinkinden ≥ 1 yüksek, hedef zorluk hiç düşmüyor; sektör sonu dışında son 3 parça tekrar etmiyor |
  | `tests/ui/hud_test.gd` (M2-09 eki) | Sektör afişi: `sector_entered`'da ad (EN/TR), 2,4 sn'de sönme; sonraki sektörden başlayan turda görünür, S1'den başlayan turda gizli |
  | `tests/data/sector_catalog_test.gd` (M2-08) | S1–S3 değerleri GDD ile aynı, başlangıç/bitiş yükseklikleri, ad çevirileri, vuruş boyları |
  | `tests/levels/run_sector_test.gd` (M2-08, M2-09) | Kısa sektörlerle S1→S2→S3: her sektörde adım hızı doğru, `sector_entered` [2, 3], her sektörde diken yarım vuruşta geçiyor, yeni sektörün ilk 2,5 sn'sinde diken yok, koridor tonu S3 rengi, tempo; S2'den başlayan turda yükseklik ve hız |
  | `tests/systems/conductor_test.gd` (M2-07) | Vuruşlar BPM'e göre doğru karede, yavaş çekimde oyun zamanına göre; gerçek turda her diken yarım vuruş anında geçiyor |
  | `tests/autoloads/audio_manager_test.gd` (M2-07) | Metronom bir ölçü, vuruşlarda tık, döngü sonundan sonra sessiz pay |
  | `tests/tools/chunk_validator_test.gd` (M2-05; M2-13 eki: çevrili Glimmer toplanamaz, tehlikeden uzak Glimmer riskli değil; M2-11 eki: iki duvarda üst üste uzun boşluk yakalanıyor, tek boşluk S2'de adil, S1'de izinsiz; M2-12 eki: koridoru kapatan ışın vuruşta yanıyorsa geçilemez, yarım vuruşta yanıyorsa geçilir; lazer S2'de izinsiz) | Örnek parça her sektörde adil; iki duvarı kapatan parça, her vuruşta taraf değiştiren dikenler (S5), parça başındaki diken, sınırdan taşan diken yakalanıyor; havadan geçilebilen diken çifti geçiyor; kamera kuralı; sektör kapsamı |
  | `tests/levels/chunk_info_test.gd` (M2-03) | Örnek parçanın değerleri, klasördeki her parçanın ızgara kuralları, kural ihlallerinin yakalanması, vuruş boyu, tasarımdan dünyaya ölçekleme |

  - **Kabul (M2-02):** Kod bilerek bozuldu (sahte fare kuralı, çevirme, yeniden başlama süresi 0,8 sn, rekorun düşmesi); testler 12 hatayla yakaladı, geri alınınca 30/30 geçti.

> **Ders (M2-02), sahne testleri:**
> - `await get_tree().physics_frame` sinyali adım işlenmeden önce gelir. Dokunuşun etkisini görmek için iki kare beklenir.
> - Oyuncu testleri ayarı diskten taze yükler (`CACHE_MODE_IGNORE`). Paylaşılan örneği canlı panel ya da kayıtlı ayar dosyası değiştirmiş olabilir.
> - Genel durum (zaman ölçeği, çarpışma çizimi, ölümsüzlük, dil) `after_test`'te geri alınır.
> - `main.tscn` kuran test, ölüm sonrasındaki yeniden başlama zamanlayıcısı bitmeden sahneyi bırakmaz; askıdaki `await` silinmiş düğümde uyanırdı.
> - Testte sinyal yaymak için oluşturulan düğümler `auto_free()` ile sarılır; yoksa gdUnit4 "orphan" sayar (M2-13).
> - Test yerel değişkenlerine `before` / `after` gibi adlar verilmez: `GdUnitTestSuite`'in fonksiyonlarını gölgeler ve katı kontrol betiği derlemez (M2-04 ve M2-11'de iki kez yaşandı).
> - Telefondaki dokunuş, test içinde iki olayla taklit edilir: `InputEventScreenTouch` (çevirme) ve `DEVICE_ID_EMULATION` cihazlı fare tıklaması (düğmeye basma).

> **Ders (M1-04), ekransız deneme betikleri (gdUnit4 gelene kadar, M2-01):** `--script` ile verilen betik, autoload'lar kaydedilmeden derlenir.
> - Betik, `Events` kullanan bir sınıfa (ör. `Player`) adıyla başvurursa o sınıfın derlemesi bozulur ve sahnedeki düğüm betiksiz kalır.
> - Bu yüzden oyunun sınıflarına `call()` / `get()` ile, `Events`'e `root.get_node("Events")` ile erişilir.
> - Her denemede kare sınırı olur ve sınır aşılınca `quit()` çağrılır; yoksa hata alan deneme sonsuza kadar asılı kalır.
> - Kareleri sabitlemek için `--fixed-fps 60` kullanılır.

> **Ders (M0-06):** Godot'nun ekransız modu (`--import`, `--script`, `--check-only`) GDScript **uyarılarını yazdırmaz**, yalnızca hataları yazdırır. `--check-only` ayrıca autoload adlarını tanımaz. Bu yüzden "uyarısız" iddiası yalnızca `tools/check.ps1` ile doğrulanır.

## 16. Performans bütçesi

- **Referans cihaz:** Redmi Note 12 4G: Snapdragon 685 / **Adreno 610** (orta-alt segment GPU), 8 GB RAM, 1080×2400, 60/90/120 Hz, Android 15. GPU zayıf ve ekran yüksek çözünürlüklü olduğu için tam ekran efektler burada en çok zorlanıyor. M0-09 ölçümü bunu doğruladı (§16.1).
- Redmi Note 12'de 60 FPS'te **kare süresi ≤ 10 ms** (bütçenin yaklaşık %60'ı). Kalan pay daha zayıf cihazlar içindir.
- Tur sırasında bellek ayırma yok (havuzlama).
- İndirme boyutu hedefi < 40 MB (M6'da ölçülecek).
- Ayarlarda **60 FPS sınırı** seçeneği (pil için). Varsayılan: ekranın yenileme hızı.

### 16.1 Ölçüm (M0-09, Redmi Note 12)

Sahne: `scenes/debug/glow_bench.tscn`. Duvarlar, 14 diken, 8 blok, 20 Glimmer, oyuncu + iz, ızgara ve HUD, tam ekran 1080×2400. Her mod 4 sn ölçüldü, iki kez. Başka bir cihazda yeniden ölçmek için sahne geçici olarak ana sahne yapılıp yüklenir (gerekirse debug paneline bir düğme olarak bağlanır); PC'de `<godot> --path . res://scenes/debug/glow_bench.tscn`.

| Mod | Ort. kare süresi | p95 | FPS | GPU doluluğu |
| --- | --- | --- | --- | --- |
| Parlama yok | 8,4 ms | 9,3–10,6 ms | 119 | %77 |
| Sahte parlama | 8,4 ms | 9,3–9,4 ms | 119 | %88 |
| WorldEnvironment glow | 17,4–17,7 ms | 18,5–19,9 ms | 57 | %99,9 (tıkanmış) |

- Uygulama 120 Hz'de çalışıyor. Bu durumda bütçe 8,3 ms ve **en büyük yük GPU'da**: basit sahne bile 120 Hz'de GPU'nun %77'sini kullanıyor (≈ 6,4 ms).
  - M3-12 ve M6-03'te asıl ölçüt 60 FPS'te ≤ 10 ms'dir.
  - 120 Hz bir ek hedeftir; tutmazsa kalite seviyesi ya da 60 FPS sınırı devreye girer.
- **Ölçüm yöntemi:**
  - Android'de dikey eşitleme kapatılamıyor; FPS yenileme hızında takılı kalıyor.
  - Godot'nun GPU zamanlayıcısı GLES'te çalışmıyor (`-1`).
  - Bu yüzden GPU yükü, Qualcomm sayacıyla adb kabuğundan okunur: `adb shell cat /sys/class/kgsl/kgsl-3d0/gpubusy`. Çıktıdaki "meşgul toplam" çiftleri toplanıp oranlanır. Uygulama bu dosyayı okuyamıyor (SELinux), yalnızca kabuk okuyabiliyor.
  - GPU frekansı okunamadığı için doluluk karşılaştırması yaklaşıktır.

## 17. Karar kaydı (ADR)

| # | Tarih | Karar | Gerekçe |
| --- | --- | --- | --- |
| ADR-001 | 2026-09-28 | Godot 4.7 + GDScript, zorunlu statik tip | Ücretsiz, hafif, metin tabanlı; statik tip hataları erken yakalar |
| ADR-002 | 2026-09-28 | Compatibility renderer | En geniş Android desteği ve web çıktısı |
| ADR-003 | 2026-09-28 | Dikey 1080×1920, `canvas_items` + `expand`, sabit ileri görüş kuralı | Tek elle oynanış, dikey video; farklı ekranlarda adalet |
| ADR-004 | 2026-09-28 | `Polygon2D` / `Line2D` + koddan renk + WorldEnvironment glow (yedek: sahte parlama). *Parlama kısmı ADR-020 ile değişti.* | Sıfır varlık bütçesi, tutarlı neon stil |
| ADR-005 | 2026-09-28 | Sinyal tabanlı iletişim: `Events` veri yolu, "aşağı çağır, yukarı sinyal", `player_died` kuralı | Gevşek bağlılık, ajan hatalarının azalması |
| ADR-006 | 2026-09-28 | 60 Hz sabit fizik + interpolasyon; oynanış yalnızca `_physics_process`'te | Her ekran yenileme hızında aynı oyun |
| ADR-007 | 2026-09-28 | Tohumlu RNG; harita yalnızca tohuma bağlı | Günlük meydan okuma, adalet, hata yeniden üretimi |
| ADR-008 | 2026-09-28 | Oyun zamanı esas, müzik hizalanır; dokunuş sese göre yargılanmaz; zaman ölçeği müziğe de uygulanır | Android ses gecikmesi; senkronun korunması |
| ADR-009 | 2026-09-28 | Şifreli JSON kayıt, atomik yazma, yedek, sürüm alanı; ayarlar ayrı `ConfigFile` | Bozulmaya dayanıklılık, basit hileye karşı caydırıcılık |
| ADR-010 | 2026-09-28 | CSV + `tr()` ile TR/EN; varsayılan dil cihazdan | İki dilli yayın |
| ADR-011 | 2026-09-28 | Tur sırasında nesne havuzu | Zayıf cihazlarda takılmasız akış |
| ADR-012 | 2026-09-28 | Proje klasörü boşluksuz: `C:\Users\burak\Desktop\gravity-hopper` (D-01) | Boşluklu yollar bazı komut satırı ve Android derleme araçlarında sorun çıkarabiliyor |
| ADR-013 | 2026-09-29 | Coding-Solo/godot-mcp kullanılmıyor. Sahneler `.tscn` metni olarak okunur/yazılır; gerekirse proje içinde bağımlılıksız, headless çalışan kendi sahne aracımızı yazarız | Sahne ağacı okuma özelliği yok; sunduğu işler mevcut araçlarla yapılabiliyor; Node.js bağımlılığı, sabitlenmemiş `npx`, 2026'daki iki güvenlik açığı, yavaş bakım |
| ADR-014 | 2026-10-01 | Test çatısı **gdUnit4** (GUT değil) (D-07) | Sahne koşucusu dokunuş taklidi, kare ilerletme ve sinyal beklemeyi hazır sunuyor; 4.7 desteği listelenmiş |
| ADR-015 | 2026-10-01 | Kod denetimi `gdlint` (gdtoolkit) + kanca ile otomatik denetim; kendi sahne aracımız `tools/scene_tool.gd` (`tree`, `check`) M0'da yazılır (D-08, D-09) | Kural ihlalleri ve yanlış düğüm adları oyun çalıştırılmadan yakalanır |
| ADR-016 | 2026-10-01 | `godot-debug-menu` yalnızca debug build'de (D-10) | Parlama maliyeti (M0-09) ve performans (M6) ölçümü |
| ADR-017 | 2026-10-01 | Lisans politikası genişletildi (kod: MIT/BSD/Apache-2.0/zlib, font: OFL); eklentiler sürümü sabit ve depoda; dış repolar klonlanmaz, yalnızca gereken parça alınır; "bitti" için kanıt; açık sahne güvenliği; her oturumda yüklenen talimatlar ~200 satırı geçmez (D-11) | Kaliteli araçların çoğu MIT, fontların çoğu OFL; gereksiz bağlam ağırlığı ve Godot'nun yabancı dosyaları içe aktarması önlenir |
| ADR-018 | 2026-10-06 | Üretilen `.translation` dosyaları depoya konur; dil önceliği: seçilen → cihaz → İngilizce | Yeni kopyada ilk içe aktarma hatasız olsun; Türkçe olmayan cihazlarda İngilizce |
| ADR-019 | 2026-10-07 | Telefona yükleme kabloyla; kablosuz yükleme ertelendi (kullanıcı kararı) | Okul ağı cihazlar arası erişimi engelliyor; kablo her ağda çalışıyor. Gerekirse §14'teki bulgulardan devam edilir |
| ADR-020 | 2026-10-07 | Neon parlama **nesne başına sahte parlama** ile yapılır (toplamsal çizgi kopyaları + ışık lekeleri); `WorldEnvironment` glow kullanılmaz. `godot-debug-menu` commit `ff12461`'e sabitlendi; autoload değil, debug build'de koddan yüklenir | Redmi'de glow kare süresini 8,4 → 17,5 ms'ye çıkarıp 120 FPS'yi 57'ye düşürüyor; sahte parlama ölçülebilir kare kaybı yaratmıyor (≈ +0,9 ms GPU), her cihazda aynı görünüyor ve HUD'u etkilemiyor (§9, §16.1) |
| ADR-021 | 2026-10-07 | Sahne aracı başvuruları sahneyi ağaca eklemeden örnekleyip Godot'nun kendi çözümlemesiyle dener. `get_parent()` ve `..` yollarını da hata sayar. `tools/check.ps1`'in 3. adımıdır ve `tools/fixtures/` düzeneğiyle kendini sınar | Metin ayrıştırarak `%Ad` sahipliğini taklit etmek hataya açık; gerçek çözümleme çalışma anıyla birebir aynı. §3'teki kurallar oyun çalıştırılmadan zorlanır |
| ADR-022 | 2026-10-07 | gdtoolkit 4.5.0, proje dışındaki bir sanal ortamda (`%LOCALAPPDATA%\gravity-hopper\venv`). Varsayılan kurallar + satır ≤ 100 karakter. Kanca exec biçiminde (`python` + `tools/lint_hook.py`, yalnızca standart kütüphane). `check.ps1`'in 4. adımı tüm projeyi denetler | Sanal ortam sistem Python'una karışmaz ve tek klasörle silinir. Exec biçimi Git Bash / PowerShell tırnak farklarından etkilenmez, ayar dosyasında kullanıcıya özel yol gerekmez. Varsayılan kurallar zaten stil rehberimizle aynı |
| ADR-023 | 2026-10-07 | M0 gözden geçirmesi: (1) debug araçları autoload değil, `Main/Debug`'a yalnızca debug build'de yüklenen `debug_layer.tscn`. (2) Telefonda panel köşeye üçlü dokunuşla değil, debug düğmesiyle açılır. (3) `RunRng` M1-08'e alındı; M1'in geçici engelleri de geri dönüştürülür (havuz kuralı). (4) Coyote süresi duvar boşluklarıyla birlikte M2-08'e taşındı (M1 gözden geçirmesinden sonraki numarasıyla M2-11) | (1) Autoload'lar yayın sürümüne de girer. (2) Her dokunuş aynı zamanda çevirme yapar. (3) .clauderules §5 ve §6 M1'de de geçerli. (4) Boşluk olmadan coyote süresi denenemez |
| ADR-024 | 2026-10-07 | `TuningConfig` değerleri GDD birimlerinde (m, m/sn, sn) tutulur; kod `to_px()` ile çevirir. Her alan `@export_range` ile aralık ve birim taşır; geçerli değerler `.tres`'tedir | Kaydırıcılar tasarım belgesiyle aynı dili konuşur (ör. 12 m/sn = S1). Ayar paneli alanları elle tanımlamadan kurar |
| ADR-025 | 2026-10-07 | Çalışma modeli (kullanıcı kararı): 🤖 görevler arasında onay beklenmez. Claude 🤝/👤 göreve, bekleyen karara, kapıya ya da beklenmedik bir tasarım sorusuna kadar ilerler; her görev yine ayrı commit ve kanıtla kapanır. M1-04'teki gerçek iki başparmak denemesi M1-14'e taşındı | Hız. Kapılar ve görev başına kanıt korunduğu için kalite düşmez; geri alma görev düzeyinde kolay |
| ADR-026 | 2026-10-07 | Sahne geçişlerinde `GameManager` karar verir (tohum, durum, sonuç, `Events` duyuruları), kök sahne `Main` uygular (turu `World`'e kurar/kaldırır, sonra `begin_run` ile haber verir) | Eski metin geçişleri `GameManager`'a veriyordu; bu, autoload'ların sahne düğümlerine erişmemesi kuralıyla çelişiyordu. `Main` kapların sahibi olduğu için "aşağı çağır" kuralına uyar |
| ADR-027 | 2026-10-08 | Web sürümü itch.io'da, şifreli "Restricted" sayfada barındırılır (kullanıcı kararı, D-12). Çıktı tek iş parçacıklıdır | Ücretsiz, gizli, oyunlara özel ve tanıtımda da işe yarar. Özel depodan ücretsiz GitHub Pages olmuyor, diğer seçenekler ek kurulum istiyor |
| ADR-035 | 2026-10-12 | Lazer duvara bağlı bir ışındır (koridoru tamamen kesmez) ve açık penceresi vuruşa ortalıdır (çeyrek vuruş önce/sonra); iki duvardan kısa ışınlar "lazer kapısı" olur. Veri bloğu sabittir (süzülme görseli M3'te). Vuruş Run'dan aşağı çağrıyla gelir (M2-12) | Sabit tırmanış hızında geçiş anı oyuncunun elinde değil: tam koridorluk ışın ya hep ölümcül ya hep zararsız olurdu; tam vuruşta açılıp kapanan ışın da ızgarada her evrede tehlikeli çıkıyordu (test). Ortalı pencere geçişi ya tamamen açık ya tamamen kapalı yapar, aldatıcı ışın ve zamanlamalı kapı mümkün olur. GDD'deki "vuruşa göre açılıp kapanan yatay lazer" tanımının uygulanış biçimidir |
| ADR-034 | 2026-10-12 | Duvar boşluğu parça öğesidir (`WallGap`); koridor parçaları boşluk kenarlarında tam bölünür (parça başına en fazla 3 parçacık, tur başında oluşturulur). Coyote süresi oyunda var, doğrulamada yok; düşme coyote dolunca koridor dışında olmaktır (M2-11) | Boşluk yerleri vuruş ızgarasına bağlı ve rastgele uzunlukta; sabit küçük duvar parçaları kenarları ±50 px kaydırırdı. Doğrulamanın daha sıkı olması parçaların affedici süreye dayanmamasını sağlar |
| ADR-033 | 2026-10-12 | Kullanıcıyla telefon üzerinden iki yönlü iletişim ntfy.sh ile (kullanıcı kararı). Bildirim yalnızca üç durumda: otonom çalışma bitti, kullanıcı olmadan çözülemeyen sorun, kullanıcı durdurdu. Kullanıcının yazdıkları her görev bitiminde okunur; otonom çalışma bitince arka planda bir dinleyici (`-Wait`) cevabı bekler. Konuya yazılan her mesaj kullanıcınındır (kullanıcı kararı: konu adı tahmin edilemez) | Kullanıcı ekrandan uzakken de haberdar olur ve cevap verebilir; gürültü olmasın diye bildirim seyrek. Acil durumda kullanıcı ekrana geçer. Remote Control şimdilik gerekmiyor (kullanıcı kararı). Konu herkese açık olduğu için bildirimlerde gizli bilgi olmaz |
| ADR-032 | 2026-10-11 | Sektörler veri kaynağı (`SectorDef` + `SectorCatalog`); tırmanış hızı `TuningConfig`'ten sektöre taşındı. Sektör sınırları kesin yükseklikte; parça sınırı aşmaz, sığmayan kalan boş kalır. Başlangıç sektörü `Events.start_requested` ile seçilir, sonraki turlar aynı sektörden başlar (M2-08) | GDD'deki sektör tablosu tek yerde; doğrulayıcı ve oyun aynı değerleri okur. Kesin sınır yükseklikleri HUD'u, kontrol noktalarını ve testleri basit tutar; sınırdaki boşluk M2-09'daki "nefes alma" anının temelidir |
| ADR-031 | 2026-10-11 | Ritim saati `Conductor` Run'ın içinde, sesi `AudioManager` çalar; `Conductor` her adımda oyun zamanını servis çağrısıyla bildirir. Ses, ortalama kayma 40 ms'yi aşınca ve ölçüde en fazla bir kez yeniden konumlanır (M2-07) | Autoload sahne düğümüne erişmeden saate uyar; müzik (M3) aynı yolu kullanır. Her karede konumlamak Android'de ses iş parçacığını yordu; ölçüm titremesi ortalamayla süzülür |
| ADR-030 | 2026-10-11 | Parça doğrulama kare kare durum aramasıyla yapılır (geçiş fiziği Player'la aynı, tepki payı 0,2 sn); parça her giriş durumundan (yarım geçişler dahil) geçilebilmeli; tehlikeler kutu olarak alınır (M2-05) | Analitik "iki zorunlu çevirme arası" formülü havada geçişleri ve tehlike boylarını hesaba katamıyordu. Her giriş durumu kuralı birleşim yerlerini parça çiftlerini tek tek denemeden adil kılar. Tepki payı başlangıç değeridir; M2-18 oyun testinde gözden geçirilir |
| ADR-029 | 2026-10-11 | Desen parçaları bütün olarak havuzlanır (parça başına kopya, en uzun ekrana göre); parçalar boşluksuz ve vuruş ızgarasında dizilir; kütüphane elle tutulan bir `ChunkLibrary` kaynağıdır; `Run.rng`'yi yalnızca `ChunkSpawner` çeker (M2-04) | Tehlike başına havuz, parçanın iç düzenini her seferinde yeniden kurmayı gerektirirdi. Elle liste, yayın sürümünde klasör taramanın güvenilmezliğinden kaçınır; testle klasörle eşit tutulur. Tek tüketicili RNG, haritayı ekran boyundan ve kare zamanlamasından bağımsız kılar |
| ADR-028 | 2026-10-11 | Kilometre taşı kapısı istisnası (kullanıcı kararı, .clauderules §9): M1 kapısı beklenmeden M2'ye geçilir; M1 ve M2 birlikte M2-19'da kontrol edilir. M1 kapı soruları (iki başparmak sonucu S-07, ilk izlenim, P-04) oraya taşındı. Yalnızca M1→M2 için geçerlidir; sonraki kapılar aynen sürer | Kullanıcı hızlanmak ve iki aşamayı tek seferde denetlemek istedi. Risk: M1 hissiyle ilgili bir itiraz M2 işini etkileyebilir. Önlem: değerler TuningConfig'te; his değişikliği M2'yi bozmaz |

## 18. Açık teknik sorular

| # | Soru | Nerede çözülecek |
| --- | --- | --- |
| S-01 | ✅ Çözüldü (M0-09): Glow çalışıyor ve güzel ama Redmi'de kare süresi 8,4 → 17,5 ms (57 FPS). Sahte parlama seçildi (ADR-020) | — |
| S-02 | ✅ Çözüldü (M0-09): Evet. `background_canvas_max_layer` = 0 iken katman 10'daki HUD parlamıyor (telefonda doğrulandı) | — |
| S-03 | Android'de müzik kayma eşiği ve gecikme telafisi | M2-07 / M3 |
| S-04 | ✅ Çözüldü (M0-08): Godot 4.7 debug anahtarını kendisi oluşturuyor (`%APPDATA%\Godot\keystores\debug.keystore`); Java/SDK yollarını da kendisi buldu | — |
| S-05 | Play Games ve AdMob eklentilerinin Godot 4.7 uyumlu sürümleri | M7 |
| S-06 | Neon stile uygun, Türkçe karakter destekli, lisansı temiz font | M3 |
| S-07 | Emülasyon fare olaylarının `DEVICE_ID_EMULATION` ile ayırt edilmesi. 🟡 M0-10'da tek dokunuş için doğrulandı (§8.1); gerçek iki parmak denemesinin sonucunu kullanıcı M1-16 kapısında bildirir | M1-16 |
| S-08 | ✅ Çözüldü (M0-06): `--headless --script` modunda autoload'lar yükleniyor | — |

## 19. Araç ve kütüphane adayları (açık kaynak araştırması, 2026-09-29)

> Durum: ✅ benimsendi · 🟡 aday (kullanıcı kararı bekliyor) · 📖 yalnızca başvuru kaynağı · ❌ kullanılmıyor.
> Bir aday benimsenirse sürümü sabitlenir ve `CREDITS.md`'ye yazılır.

| Araç | Ne işe yarar | Lisans | Godot 4.7 | Durum |
| --- | --- | --- | --- | --- |
| **gdUnit4** (godot-gdunit-labs) | Birim testleri + sahne koşucusu: dokunma simülasyonu, kare ilerletme, sinyal bekleme; komut satırı, HTML/JUnit rapor | MIT | ✅ 6.2.x 4.7 / 4.7.1 için listelenmiş, 4.7.2'de çalışıyor | ✅ ADR-014 (6.2.2, M2-01) |
| GUT (bitwes) | Birim testleri, komut satırı | MIT | ✅ `godot_4_7` dalı (9.7.1) | ❌ ADR-014 (gdUnit4 seçildi) |
| **gdtoolkit** (Scony) | `gdlint` (adlandırma ve stil denetimi), `gdformat` | MIT | 4.5.0; projemizin 4.7 sözdizimini okuyor (M0-12) | ✅ ADR-015, ADR-022 (4.5.0, M0-12) |
| GDScript-formatter (GDQuest) | Rust ile hızlı biçimlendirici + linter, kod sıralaması | MIT | Belirtilmemiş | 📖 gdtoolkit takılırsa yedek |
| **godot-debug-menu** (godot-extended-libraries) | FPS, kare süresi grafikleri, CPU süresi (GPU süresi GLES'te yok); Compatibility ve Android'de çalışıyor | MIT | ✅ 4.7.2'de denendi | ✅ ADR-016, ADR-020 (commit `ff12461`, M0-09) |
| gdfxr (timothyqiu) | Godot editöründe sfxr: ses efekti üretme, `.sfxr` içe aktarma | MIT | Son commit Ağu 2024; 4.7'de denenmeli | 🟡 D-05 kapsamında (M3) |
| GodotPrompter (jame581) | Claude Code için 56 Godot becerisi (mobil, test, event bus…) | MIT | 4.3+ (4.5–4.7 notlarıyla) | 📖 Kurulmuyor; ilgili beceriler gerektiğinde okunur |
| godogen (htdt) | Otonom Godot oyun üretimi | MIT | — | 📖 Ders: "iddia değil kanıt", oyunu çalıştırarak doğrula |
| GDA (aigengame/godot-agent) | Headless sahne/betik doğrulama; canlı mod yalnızca macOS/Linux | MIT | 4.4+ | ❌ Python 3.13+, 1.0 öncesi, Windows'ta canlı mod yok |
| godot_parser (stevearc) | Python ile `.tscn` okuma/yazma | MIT | Godot 4 desteği belirsiz | ❌ |
| godot-agent-knowledge (flou-ainan) | Godot 4.7 kural tabanı | MIT | 4.7+ | ❌ Çok yeni (0 yıldız); fikirleri not alındı |
| Coding-Solo/godot-mcp | MCP ile Godot kontrolü | MIT | Belirtilmemiş | ❌ ADR-013 |
