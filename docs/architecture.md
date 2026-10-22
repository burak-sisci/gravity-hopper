# GRAVITY HOPPER — Teknik Mimari

> Son güncelleme: 2026-10-21 (M3 Planlama Gözden Geçirmesi, ADR-066; önceki: M3-21 özgün müzik) · Durum: M0 altyapısı, M1 çekirdek oynanışı, M2'nin sonsuz, adil tırmanışı (desen parçaları, sektörler, müzik) ve M3'ün görsel ve işitsel kimliği (neon, efektler, ses, özgün müzik) doğrulandı. ⚠️ işaretli maddeler, yanlarında yazan görevde doğrulanacak.
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
  - **Sarsıntı (M3-10, §9):** yalnızca yatay `offset`; `view_top()` / `view_bottom()` ve oyuncunun üstündeki ileri görüş sarsıntıda değişmez (test). Kamera fizik adımında işler (`CAMERA2D_PROCESS_PHYSICS`; ara değerleme bunu zaten zorluyordu, açıkça seçilince motor uyarısı kalktı).
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
│   ├── roadmap.md
│   └── music_research.md     # Müzik araştırması ve parça ölçümleri (D-02, ADR-039)
│
├── assets/                   # Görsel ve işitsel materyaller
│   ├── sprites/              # UI ikonları, parçacık dokuları, uygulama ikonu
│   ├── audio/
│   │   ├── sfx/              # Efektler: <olay>.ogg (Kenney CC0, değiştirilmeden; M3-15, §8.8)
│   │   └── music/            # Tur müzikleri (OGG; Claude'un özgün parçaları, tools/music/ üretir, M3-21)
│   ├── fonts/                # exo2.ttf + OFL lisansı, exo2_bold.tres (proje fontu, M3-17)
│   └── shaders/              # collapse_glitch.gdshader (M3-09: yalnızca duvarın kenar bandı). Arka plan ağı ve sahte parlama shader'sız (§9, ADR-050)
│
├── data/                     # İçerik ve ayar kaynakları (.tres)
│   ├── tuning/               # TuningConfig (hareket, kamera, adalet, basınç)
│   ├── chunks/               # ChunkLibrary: oyundaki desen parçalarının listesi (M2-04)
│   ├── music/                # MusicTrack (parça başına) + MusicCatalog (M2-20)
│   ├── audio/                # SfxBank: olay → ses eşlemesi (sfx_bank.tres; tools/sfx_prep.py yazar, M3-15); TensionMix: gerilim (tension_mix.tres, M3-16)
│   ├── sectors/              # SectorDef + paletler
│   ├── visual/               # NeonStyle: neon parlama değerleri, kaliteye göre katmanlar (M3-01); içinde üç BurstStyle (M3-11)
│   ├── upgrades/             # UpgradeDef (beş yükseltme) + upgrade_catalog.tres (M4-03)
│   └── trails/               # TrailDef (kozmetik izler)
│
├── localization/             # translations.csv (TR / EN)
│
├── scenes/                   # Godot sahneleri (.tscn)
│   ├── levels/               # run.tscn (oyun dünyası), background.tscn (arka plan veri ağı, M3-07)
│   │   └── chunks/           # Elle tasarlanmış desen parçaları
│   ├── entities/             # Player, Hazard türleri, Glimmer, CollapseWall
│   ├── ui/                   # Ana menü, HUD, sonuç, mağaza, ayarlar
│   └── debug/                # debug_layer.tscn (M1-02), glow_bench.tscn (M0-09 parlama ölçümü), entity_gallery.tscn (M3-05 varlık galerisi) — yalnızca debug
│
├── scripts/                  # GDScript dosyaları (.gd)
│   ├── main.gd               # Kök sahne betiği: debug build'de debug katmanını yükler
│   ├── autoloads/            # Global servisler (bkz. §6)
│   ├── components/           # Bağımsız parçalar: Hurtbox, GrazeDetector, Neon, NeonLine, NeonShape, NeonLabel (M3-18), SquashStretch (M3-11), SlowMotion (M3-12), Magnet (RefCounted, M4-04)…
│   ├── entities/             # Varlık betikleri (sahnelerle aynı ad); record_line.gd sahnesiz (Run'ın çocuğu, M3-14)
│   ├── levels/               # run.gd, corridor.gd, chunk_info.gd (M2-03), effects.gd (parçacık patlamaları, M3-11), speed_lines.gd (hız çizgileri, M3-13)
│   ├── systems/              # ChunkSpawner, ChunkPools (M3-10), Conductor, PressureSystem, ObjectPool, RunRng
│   ├── data/                 # Resource sınıf tanımları (TuningConfig, SectorDef…)
│   ├── ui/                   # UI betikleri
│   └── debug/                # Debug araçları
│
├── tools/                    # Geliştirici araçları: check.ps1 + check_scripts.gd + warning_keys.gd (M0-06), deploy.ps1 (M0-08),
│                             #   scene_tool.gd + fixtures/ (M0-11), lint_hook.py (M0-12), web_build.ps1 (M1-13),
│                             #   chunk_validator.gd + validate_chunks.gd (M2-05), notify.ps1 (ntfy, ADR-033),
│                             #   sfx_prep.py (efekt ses düzeyi, M3-15), phone_frames.py (telefondan kare dizisi, M4-04),
│                             #   music/ (özgün müzik üreteci: CC0 kayıtlarla örnekleyici, besteler, miks; M3-21, ADR-065)
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
├── ChunkPools (Node2D, z_index -1)   # turlar arasında korunan desen parçası havuzları (§8.7, M3-10)
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

1. `Main._start_run()`: varsa eski `Run`'ı ağaçtan çıkarıp `queue_free()` eder. `GameManager.new_run_seed()` ile yeni bir `Run` kurar, ona parça havuzlarını (`ChunkPools`, M3-10) verir, `World`'e ekler ve `GameManager.begin_run(tohum, sektör)` çağırır.
2. `begin_run` durumu `RUNNING` yapar ve `Events.run_started` yayar.
3. `Player` ölünce `GameManager` `RunResult` oluşturur (yükseklik `Events.height_changed`'den), durumu `RESULTS` yapar ve `Events.run_ended` yayar.
4. M1 geçici akışı: `Main`, `run_ended`'den 0,35 sn sonra yeni tur kurar. M5'te sonuç ekranı gelir; "Tekrar" düğmesi `Events.retry_requested` yayar, `Main` bunu zaten dinliyor.
5. **Başlangıç sektörü (M2-08):** `Events.start_requested(sector)` gelince `Main` o sektörden yeni tur kurar (sektör seçimi M5, şimdilik debug `5`). `Run` katalog dışı numarayı sınırlar; `Main` sınırlanmış numarayı `begin_run`'a verir. Ölümden ve "Tekrar"dan sonraki turlar son seçilen sektörden başlar (kontrol noktası). `GameManager`, `sector_entered`'dan ulaşılan en yüksek sektörü `RunResult.sector_reached`'e yazar.

Ölçüm: ekransız denemede ölümden yeni tura 22 kare (0,37 sn); Redmi'de 7 turda 348–360 ms.

M3-10: tehlike görselleri zenginleşince (M3-05, M3-06) Redmi'de **516–526 ms**'ye çıkmıştı. Sebep, her tur başında yeniden kurulan parça havuzuydu: 130 kopya, 3552 düğüm, PC'de ≈ 22 ms kurulum + 7 ms kaldırma + 9 ms silme. Havuzlar turlar arasında korununca (ADR-054) Redmi'de **370–381 ms** (6 tur), PC'de eski turu kaldırmak 7 → 1 ms. Debug sürümünde olay günlüğü her olayı `print` eder; PC konsolunda bu, tur başına ≈ 30 ms ekliyor (yayın sürümünde debug katmanı yok).

### 5.2 Oyun dünyası

```
Run (Node2D)                          scenes/levels/run.tscn
├── Background (CanvasLayer)          # arka plan veri ağı: çizgi katmanları, paralaks (M3-07)
├── Conductor (Node)                  # ritim saati (§8.3)
├── ChunkSpawner (Node2D)             # desen parçası üretimi + havuzlar (§8.2)
├── Player (CharacterBody2D)          # scenes/entities/player.tscn
│   ├── Trail (NeonLine)              # iz (M3-04), Visual'ın altında çizilir
│   ├── Visual (NeonShape)
│   ├── Hurtbox (Area2D)              # bileşen: çarpışma (görselden küçük)
│   ├── GrazeDetector (Area2D)        # bileşen: kıl payı algılama
│   └── Shield (Node)                 # bileşen: kalkan durumu
├── PressureSystem (Node)             # çöküş duvarı mantığı (§8.4)
├── CollapseWall (Node2D)             # çöküş duvarının görseli
└── GameCamera (Camera2D)             # görüş kuralı + sarsıntı
```

`Run` kendi çocuklarının sinyallerini bağlar (ör. `Player.shield_broken → PressureSystem.on_shield_broken`). Dışarıya yalnızca `Events` üzerinden seslenir.

**Şu anki hâli (M3 sonu):** `Run` → `%Background` (`scenes/levels/background.tscn`, `Background`, M3-07, §9) + `%Conductor` (`scripts/systems/conductor.gd`, §8.3) + `%Corridor` (`scripts/levels/corridor.gd`, `Corridor`) + `%ChunkSpawner` (`scripts/systems/chunk_spawner.gd`, §8.2) + `%PressureSystem` (§8.4) + `%CollapseWall` (`scenes/entities/collapse_wall.tscn`, `CollapseWall`, M3-09, §9) + `%Player` (`scenes/entities/player.tscn`, `Player`; çocukları `Body`, `Hurtbox`, `Collector`, `GrazeDetector`, `Trail`, `Visual`, `Shield`) + `%Effects` (`scripts/levels/effects.gd`, `Effects`, M3-11, §9; oyuncunun üstünde çizilir) + `%RecordLine` (`scripts/entities/record_line.gd`, `RecordLine`, M3-14, §9; `Corridor`'dan sonra, `z_index` −2) + `%GameCamera` (`scripts/components/game_camera.gd`, `GameCamera`). Yukarıdaki ağaç hedeftir. `Trail` M3-04'te, `Background` M3-07'de geldi. Mıknatıs (M4-04) düğüm değildir: `Run`'ın tur başında yükten kurduğu bir `Magnet` (`RefCounted`) nesnesidir (§8.6).

- **Corridor:**
  - **Duvar boşlukları (M2-11):** `Run` her adımda `ChunkSpawner.active_gaps()` (duvar, üst y, alt y) listesini `set_gaps()` ile bildirir. Liste değişince ya da bir parça taşınınca her duvar parçası, boşlukların dışında kalan katı aralıklara bölünür: parça başına en fazla 3 parçacık (`CollisionShape2D` + `Polygon2D` + `NeonLine`, tur başında oluşturulur; yalnızca boy ve yer değişir, kullanılmayan kapatılır). Sınırlar tam boşluk kenarındadır. Test: `tests/levels/corridor_test.gd`.
  - **Neon duvarlar (M3-03, ADR-046):** Her parçacık saydam bir dolgu (çevre renginde; parçalar sırayla `wall_fill_light` / `wall_fill_dark`, kayma gözle görülsün) ve iç kenarında bir `NeonLine`'dır (çekirdek beyaza yakın, parlama çevre renginde). Çizgi tam çarpışma kenarının üstündedir. Boşluğa bakan uçta çizgi duvar kalınlığı boyunca dış kenara döner (temiz kesik); parça sınırında, duvar sürerken dönmez. Test: kenar çizgileri etkin çarpışma kutularının iç kenarlarıyla aynı x'te ve aynı boyda; kesik yalnızca boşluk kenarlarında, parça sınırına denk gelen boşlukta da (`edge_lines(side)`).
  - **Renk ve nabız:** `set_colors(çevre, vurgu)`; geçişi `Run` yapar (§9). `set_beat(vuruş)` her fizik adımında `Run`'dan gelir (lazerlerle aynı vuruş zamanı) ve yalnızca koridorun `modulate`'ini değiştirir: vuruşta bütün duvarlar vurgu rengine doğru parlar, sonra söner (§9, Vuruş nabzı).
  - Sol ve sağ duvarlar 400 px'lik `StaticBody2D` parçalarından oluşur; her parça 60 px kalınlığında, gri ve sırayla açık/koyu.
  - Parça sayısı en uzun ekrana (21:9) göre tur başında sabittir (10 + 10).
  - Görünür alanın altında kalan parça bir halka boyu yukarı taşınır ve `reset_physics_interpolation()` çağrılır.
- **Kamera** M1-04'ten beri oyuncuyu izler (M1-03'te sabit hızla yükselen bir noktayı izliyordu).

**Fizik katmanları** (`project.godot` → `layer_names`, M1-07):

| Katman | Değer | Kimde | Neyi algılar (mask) |
| --- | --- | --- | --- |
| 1 `world` | 1 | Duvar parçaları (`StaticBody2D`) | — |
| 2 `player` | 2 | Oyuncu gövdesi (`CharacterBody2D`) | `world` |
| 3 `hazard` | 4 | Tehlikeler (`Area2D`, `monitoring = false`, pasif) | — |
| 4 `collector` (M2-13) | 8 | Oyuncunun `Collector` alanı | — (yalnızca algılanır) |
| 5 `collectible` (M2-13) | 16 | `Glimmer` | `collector` |
| — | 0 | Oyuncunun `Hurtbox`'ı ve `GrazeDetector`'ı (`Area2D`, `monitorable = false`, M2-14) | `hazard` |

### 5.3 UI sahneleri (`scenes/ui/`)

`main_menu`, `hud`, `results`, `shop` (yükseltmeler + izler), `settings`, `pause`, `about` (lisanslar). **Hiçbiri `World`'e erişmez**: hepsi `Events`'i dinler, niyetlerini `Events` ile bildirir.

- **HUD (M1-10, `scenes/ui/hud.tscn`, `main.tscn`'de `UI/Hud`):**
  - Sol üstte anlık yükseklik (`HUD_HEIGHT` = "%d m"), altında kalıcı rekor (`HUD_BEST`). Rekor satırı rekor varken görünür (ilk kez oynayanda ilk turdan sonra).
  - Dinlediği sinyaller: `run_started`, `height_changed`, `best_height_changed` (M4-02; `run_ended`'i artık dinlemiyor).
  - Metinler kodda `tr()` ile kurulduğu için Label'larda `auto_translate_mode = DISABLED`. Dil değişince `NOTIFICATION_TRANSLATION_CHANGED` ile yeniden yazılır.
  - Kök `Control` `mouse_filter = IGNORE`'dur; HUD'un üstüne dokunuş çevirme yapar (denendi). M3-18'den beri testle: HUD'daki her `Control` `IGNORE`; oyunun içinde görünür her yazının ortasına dokunuş oyuncuyu çeviriyor.
  - **Neon yazılar (M3-18, ADR-063):** bütün yazılar `NeonLabel` (§9). Yükseklik, kıl payı yazısı ve sektör afişi sektörün vurgu renginde parlar: tur başında başlangıç sektörünün, sektöre girişte dalga afişe varınca (afişle aynı anda) yeni sektörün rengi. Rekor satırı rekor çizgisinin sarısında (`tone = RECORD`), Glimmer sayacı ve kombo Glimmer yeşilinde (`tone = GLIMMER`). Yazı boyutları sahnede (`font_size`: yükseklik 72, rekor 36, afiş ve kıl payı 64, kombo 60, Glimmer 56). Gösterebilecekleri bütün harfler açılışta ve dil değişince önceden çizilir (M3-19, §9: ısıtma).
  - Üst pay sabit 110 px; güvenli alan M6-01'de gelir.
  - Rekor kalıcıdır (M4-02): `Progression` her tur başında (`GameManager.begin_run` → `Progression.announce()`) ve rekor kırılınca `best_height_changed` yayar; HUD değeri yalnızca oradan alır, autoload okumaz.
  - **Glimmer sayacı (M2-13):** sağ üstte `HUD_GLIMMERS` ("%d GLIMMER"), yeşil; `run_started`'da sıfırlanır, `glimmer_collected` değerlerini toplar.
  - **Sektör afişi (M2-09):** `HUD_SECTOR` ("SECTOR %d · %s" / "SEKTÖR %d · %s") + sektör adı anahtarı; yazı rengi sektörün geçici rengi. Ekranın %30 yüksekliğinde, 2 sn görünür, 0,4 sn'de söner. HUD adları `SectorCatalog` kaynağından okur (veri; dünyaya erişmez).
  - **Çöküş duvarı vinyeti (M2-15):** §8.4.
  - **Kıl payı yazısı ve kombo göstergesi (M3-12):** her `near_miss`'te `%NearMissLabel` (`HUD_NEAR_MISS`: "NEAR MISS!" / "KIL PAYI!") ortasından büyüyerek belirir (×1,4 → 1, 0,15 sn), 0,45 sn kalır, 0,3 sn'de söner. Altında `%ComboLabel` (`HUD_COMBO` = "×%d", Glimmer yeşili) çarpan ×2 / ×3 olunca büyüyerek gelir; `combo_ended` ve `run_started`'da kaybolur. İkisi de oyuncunun hemen altında (ileri görüş 28 m = 1400 px; üst kenardan 1450 ve 1530 px): geçilmiş bölge, gelen engelleri örtmez. Tween'ler zaman ölçeğini yok sayar (`set_ignore_time_scale`): yazı yavaş çekimde de aynı hızda oynar.

## 6. Autoload'lar

| Autoload | Görevi | Not |
| --- | --- | --- |
| `Events` | Global sinyal veri yolu | Yalnızca sinyal tanımları, mantık yok |
| `GameManager` | Uygulama durum makinesi; tur tohumu, `run_started` / `run_ended` duyuruları, `RunResult`; tur başında `Progression.announce()`, tur sonunda `Progression.finish_run(sonuç)` (M4-02) | Sahneye dokunmaz; sahne geçişlerini `Main` uygular (§5.1, ADR-026) |
| `SaveManager` | Kayıt dosyalarını okuma/yazma, şifreleme, sürüm geçişi (M4-01, §11): `load_game()` → şemaya uyan sözlük, `save_game(veri)` → başarı | Yalnızca kalıcılık; oyun kuralı bilmez, ne kaydedileceğine `Progression` karar verir |
| `Progression` | Glimmer cüzdanı, kalıcı rekor (`best_height_m`), en yüksek sektör (`highest_sector`), istatistikler (M4-02); yükseltme seviyeleri (M4-03), izler (M4-08). `finish_run(sonuç)`: kazanç = toplanan Glimmer + sektör bonusu, rekor, kayıt. `announce()`, `reload()`, `reset()`. Yükseltmeler (M4-03): `upgrade_level(id)`, `upgrade_value(id)`, `upgrade_cost(id)` (en üstte -1), `can_buy(id)`, `buy_upgrade(id)` (cüzdan yetmezse / en üstteyse false; alınınca hemen kaydeder, `glimmers_changed` + `upgrade_purchased`). Tur yükü (M4-04): `loadout()` → `RunLoadout` (seviyelerin etkisi ve kuşanılan iz); `finish_run` Glimmer Çarpanı'nı kazanca ekler (formüller `Earnings`'te, §10); `set_upgrade_level(id, seviye)` yalnızca debug içindir (sınırlanır). İzler (M4-08): `owns_trail(id)`, `equipped_trail()` (bilinmeyen ya da sahip olunmayan kayıt varsayılana düşer), `can_buy_trail(id)` / `buy_trail(id)` (yalnızca satılık iz; kaydeder, `glimmers_changed` + `trail_unlocked`; kuşandırmaz), `equip_trail(id)` (sahip olunmalı; kaydeder, `trail_equipped`), `mark_great_storage_reached()` (M4-13 çağırır; bayrak + iz + kayıt), `grant_trail(id)` debug ve testler içindir. Başarım izleri `finish_run`'da (toplam kıl payı) ve Büyük Depoda açılır | Veriyi `SaveManager` ile saklar; debug günlüğüne `PROGRESS …` satırları |
| `Settings` | Ses, müzik, titreşim, dil, efekt kalitesi | `user://settings.cfg` |
| `AudioManager` | Efekt havuzu (8 çalar, açılışta kurulur; §8.8), müzik çalma ve geçişleri, `pitch_scale` senkronu, gerilim (müziğin süzgeci + gerilim sesi; §8.8) | Olayları `Events`'ten dinler |

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
| `player_revived` | — | GameManager (İkinci Şans: hak varsa ölümden `AUTO_REVIVE_DELAY` sonra kendiliğinden, M4-07; M5-03'te sonuç ekranının düğmesine, `revive_requested`, bağlanır) | Run (oyuncuyu canlandırır), AudioManager (müzik kaldığı yerden), debug olay günlüğü; ileride HUD |
| `player_flipped` | — | Player | AudioManager (efekt, M3-15; titreşim M5) |
| `player_landed` | — | Player (`_land`: duvara her gerçek iniş, M3-15) | AudioManager (tutunma sesi) |
| `shield_changed` | `active: bool` | Player | HUD, AudioManager |
| `head_start_changed` | `active: bool` | Run (Başlangıç Sıçraması başladı / bitti, M4-06) | Debug olay günlüğü; ileride HUD ve AudioManager |
| `height_changed` | `meters: int` | Run (yalnızca tam sayı değişince) | HUD, GameManager (`RunResult.height_m`) |
| `sector_entered` | `index: int` | Run (sınır geçilince, M2-08) | HUD (afiş, M2-09), GameManager (`sector_reached`), debug katmanı, AudioManager (efekt, M3-15). Müzik sektörde değişmez (ADR-040) |
| `chunk_placed` | `chunk_id: StringName, difficulty: int, sector: int` | ChunkSpawner (her parça yerleştiğinde, M2-06) | Debug olay günlüğü (zorluk ve tekrar ölçümü, M2-10) |
| `glimmer_collected` | `value: int` | Run | HUD, AudioManager |
| `near_miss` | `combo: int, multiplier: int` (M3-12'de çarpan eklendi) | Run | HUD (kıl payı yazısı, kombo göstergesi), GameManager (`near_misses`), debug günlüğü, AudioManager (efekt, M3-15) |
| `combo_ended` | — | Run | HUD, AudioManager (kombo eşiği sayacı) |
| `record_broken` | — | Run (`RecordLine.passed`'i aktarır, turda bir kez; M3-15) | AudioManager (rekor sesi) |
| `wall_proximity_changed` | `ratio: float` (0 duvar ekranın altında – 1 oyuncuda) | Run (`_update_wall`, mesafeyi `PressureSystem`'den alır) | HUD (kenar vinyeti), AudioManager (gerilim, M3-16) |
| `beat` | `index: int` | Conductor | Arka plan, HUD (nabız) |
| `start_requested` | `sector: int` | UI (M5), debug katmanı (`5`, M2-08) | Main (o sektörden yeni tur) |
| `retry_requested` / `revive_requested` / `menu_requested` | — | UI | GameManager |
| `pause_requested` / `resume_requested` | — | UI | GameManager |
| `glimmers_changed` | `total: int` | Progression (cüzdan değişince; `announce()` ile her tur başında) | UI (M5: menü, mağaza) |
| `best_height_changed` | `meters: int` | Progression (rekor kırılınca, `run_ended`'den önce; `announce()` ile her tur başında; M4-02) | HUD (`HUD_BEST`) |
| `upgrade_purchased` | `id: StringName, level: int` | Progression (`buy_upgrade`, M4-03) | Debug İlerleme sayfası; mağaza (M5), AudioManager (M5) |
| `trail_unlocked` | `id: StringName` | Progression (iz satın alındı ya da başarımla açıldı; M4-08) | Debug İlerleme sayfası, olay günlüğü; mağaza ve başarım bildirimi (M5) |
| `trail_equipped` | `id: StringName` | Progression (`equip_trail`, M4-08) | Debug İlerleme sayfası, olay günlüğü; mağaza (M5) |
| `settings_changed` | — | Settings | AudioManager ve ilgililer |
| `debug_invincibility_changed` | `enabled: bool` | Debug katmanı (yalnızca debug build) | Player |
| `debug_shield_requested` | — | Debug katmanı (M2-16) | Player (kalkan takar) |

### 7.3 Örnek akış: Ölüm

1. Diken (`Area2D`, pasif) oyuncunun `Hurtbox`'ıyla örtüşür.
2. `Hurtbox` bileşeni yukarıya `hit` sinyali yayar → `Player`.
3. `Player`: kalkan varsa tüketir ve `shield_changed(false)` + yerel `shield_broken` yayar. Kalkan yoksa `Events.player_died.emit(DeathCause.HAZARD)`. **Dikenin koduna dokunmaz.**
   - **Uygulama (M2-16):** `Shield` bileşeni (`scripts/components/shield.gd`, oyuncunun çocuğu): `give()`, `consume(dokunulmazlık)`, `tick(delta)`, `is_in_grace()`; durum değişince yukarı `changed` → `Player` bunu `Events.shield_changed`'e bağlar. Darbe: dokunulmazlıktaysa yok sayılır; kalkan varsa tüketilir, `TuningConfig.shield_grace` (1 sn) dokunulmazlık başlar, `shield_broken` → `Run` → `PressureSystem.pull(shield_pull)` (8 m). Kalkan düşmeye ve çöküş duvarına karşı korumaz (`Player.die` ve düşme kalkana bakmaz). Görsel: oyuncunun çevresinde açık mavi neon halka (`NeonLine`, yarıçap 56 px, renk `NeonStyle.shield_color`; M3-04), dokunulmazlıkta yanıp söner. Debug ile de verilir: `8` tuşu ya da paneldeki "Kalkan" düğmesi → `Events.debug_shield_requested`. Redmi'de halka göründü, kalkan bir darbeyi emdi ve tur sürdü.
   - **Kalkan yükseltmesi (M4-05, ADR-071):** yükte `start_shield` varsa (Sv1 ve üstü) `Run._ready` oyuncuya kalkan takar (`Player.give_shield()`; `shield_changed(true)` tur başında). `shield_regen_m` > 0 ise (Sv2–5: 1500 / 1200 / 900 / 600 m) `Run._on_shield_broken` kalkanın kırıldığı yerden o kadar yukarıdaki y'yi not eder; oyuncu oraya varınca (yaşıyorsa) kalkan yeniden takılır. Yenilenme dokunulmazlıkta gelirse halka dokunulmazlık bitene dek yanıp söner. Bekleyen tek bir yenilenme vardır; araya debug kalkanı girerse `give()` bir şey yapmaz. Mesafe yalnızca tırmanışla ölçülür (konum), zamana bağlı değildir. PC'de `--upgrade=shield:2`: `PROGRESS loadout … shield=true regen=1500`, tur başında `EVENT shield_changed active=true`, ilk darbe emildi (`active=false`), sonraki tur yine kalkanla başladı; kareler halkayı ilk kareden gösteriyor.
4. `GameManager` dinler: `Run.stop()` (aşağı çağrı), `RunResult` oluşturur, `Progression.finish_run(result)` (M4-02: sektör bonusunu, kazancı ve rekor durumunu sonuca yazar; cüzdanı, rekoru, en yüksek sektörü ve istatistikleri günceller; `SaveManager.save_game(veri)` ile kaydeder), ardından `Events.run_ended.emit(result)`.
   - **İkinci Şans (M4-07, ADR-073):** karar `GameManager`'da, uygulama `Run`'da; ikisi `Events` ile konuşur.
     - `begin_run` hakkı yükten alır (`RunLoadout.revives`; İkinci Şans Sv1 = 1). `player_died` geldiğinde hak varsa tur bitmez: hak düşer, diriliş bekler ve `AUTO_REVIVE_DELAY` (0,8 sn) sonra `revive()` → `Events.player_revived`. Bu bekleyiş sonuç ekranı gelene dek geçicidir; M5-03'te `revive_requested` → `revive()` bağlanır. Bekleyişte gelen ölüm bildirimi yok sayılır. Zamanlayıcı tur sayacını (`_run_serial`) taşır: arada yeni tur başlarsa eski zamanlayıcı bir şey yapmaz. Hak bitince ölüm turu her zamanki gibi bitirir (`run_ended`; `Main` 0,35 sn sonra yeni tur).
     - `Run._on_player_revived`: ölüm donması ve tutma biter; `Player.revive(revive_grace)` (§8.1); `ChunkSpawner.clear_hazards` oyuncunun önünde `revive_clear_time` (2,5 sn'lik yol, sektörün tırmanışıyla; S1'de 30 m) ve altında `revive_clear_behind` (3 m) içindeki tehlikeleri temizler, öldüren de dahil (§8.7); `PressureSystem.revive(revive_wall_distance)` çöküş duvarını en az 20 m'ye iter (§8.4); arka planın hız hissi geri gelir; süren kombo biter (`combo_ended`). Kalkan dirilişle gelmez; bekleyen yenilenme sürer.
     - **Ölümde saat durur:** `Run` vuruş saatini (`Conductor.advance`), Başlangıç Sıçramasını ve duvarın sürünmesini yalnızca oyuncu canlıyken ilerletir. Böylece oyuncu ile vuruş ızgarası ölümde de dirilişten sonra da aynı yerdedir: dikenler yine yarım vuruşta geçilir, müzik kaldığı yerden sürer (§8.3). Düşme denetimi tırmanıştan önce yapılır, düşülen adımda tırmanış olmaz (§8.1).
     - PC'de `--upgrade=second_chance:1` (kare dizisi): `PROGRESS loadout … revives=1`, `EVENT player_died cause=HAZARD t=5403`, `EVENT player_revived t=6179`. 49 m'de ölüm ve patlama; bekleyişte çekirdek gizli, oyuncu yerinde; dirilişte öldüren diken yok, çekirdek tam 120 kare (2 sn) yanıp sönüyor; tur 132 m'yi geçti.
     - **Redmi'de (M4-07):** Sıçrama Sv5 + Kalkan Sv2 + İkinci Şans Sv1 ile yük `PROGRESS loadout … revives=1`. Beş dokunuşsuz turda `player_died` → ≈ 0,7–0,8 sn sonra `player_revived` → 3–4 sn sonra ikinci ölüm ve `run_ended` (dokunulmazlık bitince); turda bir diriliş; müzik yeniden başlamadı (`AUDIO music=` yalnızca tur başında). `tools/phone_frames.py` kare dizisinde ölüm, bekleyiş, dirilişte yanıp sönen çekirdek ve geri itilmiş duvar, ardından süren tur görülüyor.
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
  - **Coyote süresi:** Duvardan ayrıldıktan (boşluğa girdikten) sonra kısa bir süre (0,1 sn) çevirmeye izin verilir. Yalnızca duvar boşluklarında anlamlı olduğu için boşluklarla birlikte M2-11'de geldi (yukarıda).
  - **Dokunma tamponu:** Havadayken yapılan dokunuş saklanır ve duvara değince uygulanır. Süre 0,45 sn (ADR-036; M1'de 0,12 sn): geçişten uzun olduğu için havadaki her dokunuş inişte uygulanır.
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
    - Gerçek iki başparmak denemesi M2-18 oyun testinde geçti (S-07 ✅); testte bulunan hızlı çift dokunuş sorunu ADR-036 ile giderildi.
  - Kural tek yerde: `Player.is_tap(event)`; testi `tests/entities/player_test.gd` (M2-02).
- **İniş (M3-11):** Duvara yaslı olmayan oyuncu yaslandığı adımda `landed(değilen nokta, duvarın yönü)` yayar (yerel sinyal; `Run` iniş kıvılcımına bağlar). Değilen nokta konum + yön × gövdenin yarısı, yani duvarın iç kenarı. Tur başında ortadan sol duvara düşüş de bir iniştir. Duvarda kayarken (parça birleşim yerleri dahil) yeni iniş sayılmaz (test).
- **Başlangıç Sıçraması (M4-06, ADR-072):** yükte `head_start_m` > 0 ise (Sv1–5: 100–500 m) tur, oyuncunun normal tırmanışının üstüne ek bir yolla başlar.
  - **Ek yol tam vuruşa yuvarlanır:** `k = roundi(to_px(head_start_m) / vuruş_px)`, vuruş_px = sektörün tırmanışı × vuruş süresi. Bitişte oyuncu vuruş ızgarasında tam k vuruş öndedir; engeller yine yarım vuruşta geçilir, ritim senkronu bozulmaz. Yuvarlama hatası en çok yarım vuruştur (S1'de parçanın temposuna göre 3–4 m).
  - **Süre ve eğri:** `head_start_speedup` (×8) toplam hızı verir: süre = k vuruş / (çarpan − 1); 500 m ≈ 5,9 sn. Ek yol `smoothstep` ile verilir (yumuşak kalkış ve iniş). `Run._advance_dash()` her adımda `Conductor.advance`'tan hemen sonra çalışır, oranı turun saatinden (`run_time`) okur ve farkı oyuncunun y'sinden düşer; tırmanış altında sürer.
  - **Başlangıç sektöründe biter:** toplam yol = ek yol × çarpan / (çarpan − 1); sığmazsa k kısalır (bir vuruş pay). S1 750 m olduğu için Sv5 sığar; son sektörde sınır yoktur. k ≤ 0 ise sıçrama yok.
  - **Dokunulmazlık:** `Player.set_dashing(true)` sıçrama boyunca, bitişte `set_dashing(false, head_start_grace)` (1 sn) daha. `Player.is_protected()` iken darbe alınmaz, kıl payı sayılmaz, koridordan düşülmez (debug ölümsüzlüğündeki gibi duvar çizgisine geri konur). Dokunulmazlıkta çekirdek yanıp söner (`_process`, sn'de 8, sönük hâli %35 görünür). Kalkan ve çöküş duvarı değişmez.
  - **Glimmer süpürme:** hız yüksek olduğu için `Area2D` değmesi kaçabilir; sıçrama sürerken `Run`, her adım `ChunkSpawner.collect_passed(oyuncu y)` çağırır ve oyuncunun geçtiği (y'si oyuncunun altında kalan) Glimmer'lar toplanır, öbür duvarın yanındakiler de (§8.6).
  - **Görsel:** sıçrama boyunca arka planın hız hissi en üstte (`Neon.STYLE.speed_feel_max_speed`), bitişte sektörün hızına döner; iz ve hız çizgileri bunu izler.
  - **Sinyal:** `Events.head_start_changed(active)`: ilk adımda `true`, bitişte `false` (§7.2). Debug günlüğü bitişte yüksekliği de yazar.
  - **Harita değişmez:** sıçrama yalnızca oyuncunun yerini değiştirir; tohum aynıysa yerleşen parçalar sıçramalı ve sıçramasız turda aynı sırada gelir, tur sırasında düğüm oluşmaz, havuz büyümez (test).
  - PC'de `--upgrade=head_start:5`: `PROGRESS loadout … head_start=500`; `EVENT head_start_changed active=true`, sonra `active=false height=568` (500 m + 5,9 sn × 12 m/sn); kareler sıçramada uzun izi ve hız çizgilerini, dokunulmazlıkta zararsız geçilen bir dikeni ve çekirdeğin ≈ 1 sn yanıp söndüğünü gösteriyor.
  - **Redmi'de (M4-06):** Sıçrama Sv5 + Kalkan Sv2 ile yük `PROGRESS loadout … shield=true regen=1500 head_start=500`; dört turda `head_start_changed` true → false 5,8–6,3 sn, bitişte 567–576 m, sıçramada ölüm yok; kalkan sıçramadan sonraki ilk darbeyi emdi (M4-05'in telefon denemesi de bu). Dokunuşsuz turda kazanç 0–2 yerine 7–8 Glimmer (süpürme). `tools/phone_frames.py` kare dizisinde 0 → 34 → 107 → 206 → 315 → 421 m, kalkan halkası, uzun iz ve hız çizgileri görülüyor.
- **Diriliş (M4-07, ADR-073):** `Player.revive(dokunulmazlık)` oyuncuyu yerinde canlandırır: çekirdek ve (varsa) kalkan halkası yeniden görünür, yatay hız 0, x koridorun içine konur (boşluktan düşen oyuncu duvar çizgisine döner). Dokunulmazlık Başlangıç Sıçramasındakiyle aynı koruma ve yanıp sönmedir (`revive_grace`, 2 sn). **Düşme denetimi tırmanıştan önce** yapılır: oyuncu düştüğü adımda tırmanmaz, böylece ölümde oyuncu ile vuruş saati aynı yerde kalır (eski sıra geri alınınca 6 hata).

### 8.2 Bölüm üretimi (desen parçaları)

- **Desen parçası (chunk)** = `scenes/levels/chunks/` altında bir sahne. Kökü `Node2D` + `ChunkInfo` betiği (`scripts/levels/chunk_info.gd`, M2-03):
  - `difficulty` (1–10), `min_sector`, `max_sector` (1–5), `length_beats` (1–64), `tags` (`Array[StringName]`).
  - Öğeler kökün doğrudan çocuklarıdır (tehlike sahneleri, ileride Glimmer). `items()` bunları verir.
- Parçalar **vuruş biriminde** tasarlanır: editörde 1 vuruş = 100 px dikey ızgara. Parça yerleştirilirken y konumları sektörün vuruş uzunluğuna göre ölçeklenir: `y_dünya = y_yerel / 100 × vuruş_px(sektör)`. Şekiller esnemez, yalnızca konumlar ölçeklenir.
- `vuruş_px(sektör) = tırmanış_hızı × 60 / BPM` → `ChunkInfo.beat_px(hız_m_sn, bpm)`. BPM turun müzik parçasından gelir (M2-20): S1'de 100 BPM'de 360 px (0,6 sn), 90 BPM'de 400 px, 120 BPM'de 300 px; S3'te 100 BPM'de 480 px.
- **Parça tasarım kuralları** (`ChunkInfo.design_errors()` denetler; test `tests/levels/chunk_info_test.gd` klasördeki her parçaya uygular):
  1. Kök parçanın **alt kenarıdır** (oyuncunun ilk vardığı yer); parça yukarı uzanır: öğelerin y'si `0` ile `-length_beats × 100` arasında.
  2. Öğeler **yarım vuruşa** oturur (y, 50'nin katı) ve yatayda 1 m adımına (x, 50'nin katı). Editörde ızgara yaklaştırması 50 × 50 px yapılır.
  3. Koridor tasarımda 18 m çizilir: duvarlar x = ±450. Duvara yapışık öğe tam ±450'de durur ve **koridora bakar** (sol duvarda `scale.x = 1`, sağda `-1`).
  4. Dünyaya yerleşim `layout(vuruş_px, yarı_genişlik)`: konumlar tasarımdan yeniden hesaplanır (birikmez); x koridor genişliğiyle orantılı ölçeklenir, böylece duvar öğeleri genişlik ayarı değişse de duvarda kalır.
  5. `min_sector ≤ max_sector`. Tehlike türü etiketlenmez (çocuklardan okunur); etiketler seçim içindir (ör. `intro`, `breather`).
  6. Dosya adı: `<ana tehlike>_<desen>_<nn>.tscn` (örnek: `spike_zigzag_01.tscn`: 8 vuruş, 2. vuruşta sol, 4.'de sağ, 6.'da sol diken).
  7. Öğe adı taraf + vuruş: `SpikeLeft2`, `SpikeRight4_5` (doğrulayıcı iletilerinde bu adlar görünür).
  8. **Duvar boşluğu (M2-11):** `WallGap` öğesi (`scripts/levels/wall_gap.gd`, betikli `Node2D`): konumu boşluğun alt ucu, x = ±450 (hangi duvar), `length` yarım vuruş katı (100 = 1 vuruş); boy vuruşla ölçeklenir, parçanın içinde kalır. Ad: `GapLeft2`. `ChunkInfo.gaps()`, `gap_range()`.
  9. **Veri bloğu ve lazer (M2-12):**
      - `scenes/entities/block.tscn`: pasif `Area2D`, 240 × 120 px, koridorda (x 1 m adımında). Geçiş yolunu keser: oyuncu bloğun hizasından geçerken duvarda olmalı. M3-05'ten beri betikli (`Block`), yalnızca görüntüsü için (§9).
      - `scenes/entities/laser.tscn` + `scripts/entities/laser.gd` (`Laser`): duvara bağlı yatay ışın, kökü duvarda, `length` (px) koridora uzanır, kalınlık 16 px; sağ duvarda `scale.x = −1`. **Açık penceresi vuruşa ortalı:** her vuruşun çeyrek öncesinden çeyrek sonrasına kadar açık (`on_phase` 0,5 → yarım vuruşa ortalı). Engeller yarım vuruş ızgarasında durduğu için oyuncu ışını ya tamamen açıkken ya tamamen kapalıyken geçer; `on_phase` 0,5'lik bir ışın tam vuruşta geçilirken kapalıdır (aldatıcı). Açıkken çarpışır; kapalıyken şekli kapalı, görüntüsü sönük (görünüş §9, M3-06).
      - **Neden vuruşa ortalı:** Tırmanış hızı sabit olduğu için bir yükseklikten geçiş anı oyuncunun elinde değildir. Açılıp kapanma tam vuruş/yarım vuruş anında olsaydı ızgaradaki her ışın, geçiş penceresi bir değişme anına denk geldiği için her evrede tehlikeli olurdu (M2-12'de testle görüldü). Koridoru baştan sona kesen ışın da ya hep ölümcül ya hep zararsız olurdu; bu yüzden ışınlar duvara bağlıdır. İki duvardan kısa ışınlar ortada bir açıklık bırakır (**lazer kapısı**): oyuncu oradan ancak geçişin ortasındayken, yani zamanlanmış bir çevirmeyle geçer.
      - **Vuruş zinciri:** `Run` her adımda `ChunkSpawner.set_beat(beat_time / vuruş)` → `ChunkInfo.set_beat` → `Laser.set_beat` ve `Block.set_beat` (aşağı çağrı). Parçalar tam vuruşta başladığı için evre parçanın yerinden bağımsızdır. Test: gerçek turda her `Events.beat` adımında açık, yarım vuruşta kapalı.
  10. **İzinli tehlikeler:** `ChunkInfo.hazard_types()` (tehlike sahnesinin dosya adı, boşluk için `gap`) parçanın her sektöründe `SectorDef.allowed_hazards` içinde olmalı; doğrulayıcı denetler (boşluk S2'den itibaren).
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
  - Parçalar **boşluksuz** dizilir: her parçanın alt kenarı bir öncekinin üst kenarıdır. İlk parça oyuncunun başlangıcından `run_start_gap` (25 m) kadar yukarıda, **tam vuruşa yuvarlanarak** başlar (S1'de 100 BPM'lik parçayla 4 vuruş = 28,8 m). Böylece vuruş ızgarası turun başından hizalıdır.
  - Sıradaki parçayı `RunRng.weighted_index` ile, sektöre izinli ve sığan parçalar arasından seçer.
  - **Zorluk eğrisi (M2-10):** Hedef zorluk sektör içindeki ilerlemeyle `SectorDef.min_difficulty`'den `max_difficulty`'ye doğrusal çıkar (son sektör boyunu aşınca en zorda kalır; `target_difficulty()`). Ağırlık `exp(−½ · ((zorluk − hedef) / difficulty_spread)²)` (çan eğrisi; `TuningConfig.difficulty_spread` = 0,5). Son `no_repeat_count` (3) parça yeniden seçilmez; sığan başka parça yoksa kural esner. Günlük: `placed_difficulties`, `placed_targets`; olay günlüğünde `chunk_placed … difficulty=… sector=…`.
    - **Ölçüm** (gerçek oyun, ekransız, ölümsüz, 5 tur, S1'in 13 parçası): ilk üçte bir ortalama zorluk 1,45, son üçte bir 2,40. Genişlik 1,0 iken fark 0,58 idi (hedef 1'de bile 2 zorluklu parçalar %60 ağırlık alıyordu), 0,7'de 0,65. Sektör başının 1'e inmemesinin nedeni içerik: S1'de yalnızca 5 kolay parça var ve tekrar yasağı 3'ünü dışlıyor; parça sayısı arttıkça (M2-12) eğri keskinleşir.
  - **Nefes alma (M2-09, M2-20'de değişti):** Yeni sektör en az `TuningConfig.sector_breath` (2,5 sn, GDD §12) engelsiz başlar. İlk parçası bu süreden sonraki ilk müzik vuruşunda (turun başından sayılan ızgarada) oyuncunun bulunacağı yere konur (§8.3); boşluk 2,5 sn ile 2,5 sn + bir vuruş arasındadır. Eski sektörün sonuna sığmayan kalan da bu boşluğa eklenir.
  - **Sektörler (M2-08):** Her sektör kendi vuruş boyuyla (`SectorDef.beat_px(bpm)`) dizilir. Parça sektör sınırını aşmaz: sona sığan parçalar arasından seçilir, hiçbiri sığmazsa kalan boş bırakılır. Sınırlar dünyada `başlangıç_y − (sektör_sonu − başlangıç_sektörünün_başı)`. Havuzlar turun temposunda katalogdaki en kısa vuruşa göre kurulur (`SectorCatalog.min_beat_px(bpm)`).
  - Koridor genişliği ayarı değişirse etkin parçalar yeniden yerleşir (duvar öğeleri duvarda kalır).
  - **Havuzlar:** her parça sahnesi için bir `ObjectPool` (§8.7). Kopya sayısı en uzun ekrana göre (`Corridor.MAX_VIEW_HEIGHT` = 3200 px) hesaplanır, cihazdan bağımsızdır: `tavan((3200 × 3 + 100) / parça_boyu) + 1`. Aynı parça art arda seçilse de yeter. Oyunda havuzlar `Main`'in `ChunkPools`'unda turlar arasında korunur (M3-10, §8.7); tek başına kurulan `Run`'da (testler) yerleştiricinin altında kurulur.
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
  - Sektör hızları `SectorCatalog`'dan (M2-08), tempolar `MusicCatalog`'dan (M2-20) okunur; her parça izinli her sektörde her tempoda denenir. Katalogda olmayan sektörler (S4–S5, M4-11 / M4-12) denenmez.
- **Belirlenimcilik:** Harita yalnızca `tohum + başlangıç sektörü`ne bağlıdır; oyuncunun hareketlerine ve ekran boyuna bağlı değildir.
  - `Run.rng`'yi yalnızca `ChunkSpawner` çeker. Rastgelelik isteyen başka bir sistem gelirse kendi `RunRng` akışını alır (tohumdan türetilmiş). Yoksa çekilişlerin sırası kare zamanlamasına ve ekran boyuna göre değişir, harita da değişir.
  - Seçim havuzun doluluğuna bakmaz. Havuz tükenirse (olmaması gerekir) `ObjectPool` uyarı yazıp yeni örnek oluşturur; harita bozulmaz, sorun testte görünür.
  - Test: aynı tohum 16:9 ve 20:9 ekranda aynı parça dizisini veriyor (`tests/systems/chunk_spawner_test.gd`).
  - **Tur düzeyinde test (M2-17, `tests/levels/determinism_test.gd`):** Aynı tohum + başlangıç sektörüyle (S1, S2, S3) kurulan iki gerçek tur, oyuncu hiç dokunmasa da 23 karede bir dokunsa da (yol, Glimmer, kıl payı, çöküş duvarı değişir) aynı parça adlarını ve alt kenarlarını veriyor; sektör sınırları (150 m'lik kısa sektörler) aynı geçiliyor; farklı tohum farklı dizi veriyor. Oyuncu durumuna göre `Run.rng`'den fazladan sayı çeken geçici bir bozulma 5 hatayla yakalandı. M3-12'den beri turlar kare sayısıyla değil aynı oyun zamanıyla (M3-21'den beri 35 sn) oynanır, çünkü yavaş çekim aynı karede daha az yol aldırır; son adımın farkı bir parça ekleyebildiği için ortak baş karşılaştırılır.
- **`RunRng`** (`scripts/systems/run_rng.gd`): tur tohumuyla kurulan `RandomNumberGenerator` sarmalayıcısı; oynanıştaki tek rastgelelik kaynağı (.clauderules §5). M1-08'de yazıldı, M2-01'de gdUnit4 testleriyle sabitlenir.
  - Metotlar `next_float()`, `range_int()`, `range_float()`, `chance()`, `make_seed()`. `randf` ya da `seed` gibi adlar genel fonksiyonları gölgeler ve katı kontrolde hata verir.
  - `Run.rng`'nin sahibi `Run`'dır. `Run.run_seed` 0 ise `RunRng.make_seed()` kullanılır; M1-09'dan sonra tohumu `GameManager` verir.
- **Geçici engel yerleştirici** (`SpikeSpawner`, M1-08 – M2-04): düz aralıklı, tarafı rastgele dikenler. M2-04'te `ChunkSpawner` gelince kaldırıldı; "Geçici engeller (M1)" ayar grubu (`spike_spacing`, `spike_start_gap`) da kalktı, yerine `run_start_gap` geldi.

### 8.3 Ritim (Conductor)

- **Tek doğru zaman kaynağı, oyun zamanıdır** (`run_time`, ölçeklenmiş `delta` ile ilerler). Müzik ona hizalanır.
- Müzik konumu `get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()` ile okunur. Kayma eşiği aşılırsa (40 ms) müzik yeniden hizalanır. Eşik Redmi ölçümü ve kulak testleriyle (M2-18, M2-20) kesinleşti (S-03 ✅).
- Tur içinde müzik geçişi yoktur: parça turun başından sonuna çalar (ADR-040). Menü ile tur arasındaki geçişler (M5) ölçü sınırına denk getirilir.
- **Dokunuşlar müziğe göre yargılanmaz** (Android ses gecikmesi cihazdan cihaza değişir). Müzik yalnızca bölüm yerleşimini belirler.
- **Zaman ölçeği kuralı:** `Engine.time_scale` değiştiğinde (kıl payı yavaş çekimi, duraklatma) `AudioManager` müziğin `pitch_scale` değerini aynı orana çeker. Bu, bant yavaşlaması gibi bir efekt verir ve senkronu korur. Kıl payı yavaş çekiminde ölçüldü (M3-12, §8.5): kayma sınırın altında kaldı.
- Diriliş ve duraklatma sonrasında müzik `run_time`'a göre konumlanır.
- **Uygulama (M2-07):**
  - `Conductor` (`scripts/systems/conductor.gd`, Run'ın çocuğu): `run_time`, `bpm` ve `track` (turun müzik parçası; M2-20'den beri tempo parçadan gelir). `Run._physics_process` her adımda önce `advance(delta)` çağırır (M4-07'den beri yalnızca oyuncu canlıyken: ölümde saat durur, §7.3); böylece `run_time` oyuncunun konumuyla aynı adımda ilerler. Geçilen her vuruşta `Events.beat(index)` (1'den başlar).
  - Tempo **turun müzik parçasından** gelir ve tur boyunca değişmez (M2-20, ADR-040; M2-08'de sektördendi): `Run` turun başında `Conductor.track` ve `set_tempo(parça.bpm, 0)` verir. Vuruş ızgarası turun başından kesintisiz sürer; `beat_time()` = `run_time`.
  - **Hız basamağı (M2-08, M2-20'de değişti):** Oyuncu sektör sınırını geçtiği adımda `Run` hızı değiştirir ve `Events.sector_entered` yayar. Oyuncu o adımda sınırı eski hızla biraz aşmıştır; `Run` konumunu, sınırı geçtiği andan beri yeni hızla tırmanmış gibi düzeltir (en çok 1–2 px). Böylece oyuncu her an `ChunkSpawner`'ın hesapladığı yerdedir. (M2-08'de bunun yerine yeni ızgara aşma payı kadar geriden başlatılıyordu.)
  - **Yeni sektörün ilk parçası müziğin vuruşunda (M2-20):** Oyuncu sektörün sonuna `t_sınır = Σ boy / hız` (başlangıç sektöründen o sektöre kadar) sürede varır. İlk parça, nefes alma boşluğundan sonraki ilk tam vuruşta (`n = tavan((t_sınır + sector_breath) / vuruş)`) oyuncunun bulunacağı yere, sınırın `(n × vuruş − t_sınır) × yeni_hız` üstüne konur. Sonraki parçalar tam vuruş boyunda olduğu için hepsi müziğin vuruşundadır. Test: en hızlı ve en yavaş parçayla (M3-21'den beri 120 ve 90 BPM) kısa sektörlerde S1→S2→S3, her diken turun başından sayılan ızgarada yarım vuruştan ≤ 1 kare uzak.
  - **Vuruşa hizalama:** Oyuncu turun başındaki yüksekliğinden vuruş ızgarasıyla tırmanır; parçalar tam vuruşta, öğeler yarım vuruşta durur. Bu yüzden her diken yarım vuruş anında geçer. Test: gerçek turda 1500 karede her diken geçişi yarım vuruştan ≤ 1 kare uzak (`tests/systems/conductor_test.gd`); ilk parçanın tam vuruşa yuvarlanması kaldırılınca test hata veriyor.
  - **Ses:** `Conductor` her adımda `AudioManager.sync_beat_clock(beat_time, track)` çağırır (autoload servis çağrısı; ses düğümü autoload'un kendi çocuğudur). M2-07'den M2-20'ye kadar kodla üretilen bir ölçülük metronom çalıyordu; M2-20'de turun parçası yerini aldı. `Music` ve `SFX` ses yolları `default_bus_layout.tres`'te.
  - **Hizalama:** Parça, duyulan konumu `MusicTrack.position_at(beat_time)`'a denk gelecek yerden çalar (önce baştan sona, sonra `loop_start` ile son arasında). Döngü dikişinin iki yanındaki ölçüm bir döngü boyu farklı göründüğü için kayma döngü boyuna göre sarılır. Kayma 15 karelik ortalamayla ölçülür (konum karıştırma tamponu kadar titrer). 40 ms'yi aşarsa yeniden konumlanır. Çalmadan ya da konumlamadan sonra 0,5 sn ölçülmez. Turun ilk düzeltmesi hemen, sonrakiler ölçüde en fazla bir kez yapılır.
  - Tur başlayınca çalar, oyuncu ölünce durur. `pitch_scale` = `Engine.time_scale`. Dirilişte (M4-07) `AudioManager` saati yeniden açar ve parçayı durduğu vuruş saatinin yerinden çalar: müzik kaldığı yerden sürer (test).
  - **Ölçüm (S-03, Redmi):**
    - `AudioServer.get_output_latency()` Android'de **0 ms** dönüyor (PC'de 10 ms). Gerçek donanım gecikmesi koddan bilinemez; duyulan tık o kadar geç kalır. Kulak testlerinde (M2-18 metronom, M2-20 müzik; Redmi) kullanıcı geç kalan ses duymadı. Başka cihazlarda gerekirse oyuncunun ayarlayacağı bir "ses kaydırma" ayarı M5-05'te eklenir.
    - 77 sn ölümsüz turda kayma ±20 ms içinde kaldı, yeniden konumlama gerekmedi. 40 ms sınırı uygun.
    - Tur başında, havuz kurulumu bir kare takılmasına yol açıyor; fizik kaçırdığı adımları art arda çalıştırınca oyun saati ileri atlıyor ve ses −50…−119 ms geride kalıyor (PC'de de). İlk düzeltme 0,6 sn içinde yapılıyor.
  - **Müzik (M2-20, ADR-040; M3-21'de özgün parçalar, ADR-065):**
    - **Veri:** `MusicTrack` (`data/music/<id>.tres`: `stream` OGG, `bpm`, `loop_start`, `volume_db`, atıf alanları) ve `MusicCatalog` (`data/music/music_catalog.tres`). `MusicCatalog.pick(tohum)` parçayı yalnızca tohumdan seçer: ayrı bir `RunRng` dizisi (`tohum ^ PICK_SALT`), böylece desen parçalarının dizisi kaymaz ve aynı tohum (günlük meydan okuma) hep aynı parçayı verir.
    - **Üretim (M3-21, ADR-065):** `tools/music/` (proje dışındaki geliştirme ortamı; numpy 2.5.4, soundfile 0.14.0). Claude besteler, kod gerçek enstrüman kayıtlarıyla seslendirir:
      - `samples.py` CC0 kütüphaneleri (VCSL, VSCO 2 CE; commit sabit) gerektiği kadar indirir; önbellek proje dışında (`%LOCALAPPDATA%\gravity-hopper\music_src`), depoya girmez.
      - `instruments.py` örnekleyici çalgıları kurar: dosya adındaki nota ve ses gücü katmanı; perde her örnekte ölçülür (YIN, oktavdan bağımsız), adla ±0,6 yarım ses içinde uyuşursa ince ayar olarak uygulanır.
      - `score.py` bestenin yazımı (nota:süre dizileri, süsleme, legato, kayma, vurmalı desenler); `tracks/<id>.py` her parçanın bestesi ve miksi (çalgı düzeyi, panorama, eşitleme, yankı).
      - `engine.py` çalar ve mikse eder: legato, kayma, vibrato, şişme; yankı dairesel evrişimle yapılır (döngünün sonundan taşan yankı başa sarar, dikiş sessizlik içermez). Ana çıkış: hafif sıkıştırma, ortalama −18 dBFS, tepe −1,5 dBFS sınırlayıcı.
      - `build.py` döngüyü tam ölçü olarak yazar (0. saniye = 0. vuruş), dikişte sıçrama ölçer, OGG Vorbis (sıkıştırma 0,4, küçük bloklarla) ve `.tres` dosyalarını yazar. Oyundaki düzey dosyaya işlenmez: `volume_db`, parçanın telefon bandındaki ortanca kısa süreli düzeyini eski müzik düzeyine (−23,4 dB, efektler buna göre ayarlı) eşitler.
      - Parçalar: Kervan (Orta Doğu, D Hicaz, 100 BPM, 64 ölçü), Pagoda (Doğu Asya, G# minör pentatonik, 90 BPM, 56 ölçü), Kale (Orta Çağ Avrupa, D Dorian, 12/8 jig hissi, 120 BPM, 72 ölçü). Yapı: giriş → A → B → ara (yükselen davul) → doruk → çıkış; çıkış girişe bağlanır.
    - **Hazırlama (M2-20, M3-21'de kalktı):** Eski beş parça `tools/music_prep.py` ile hazırlanıyordu (başı ilk vuruşa kırpma, tam ölçülük döngü seçimi, dikiş yumuşatma). Araç git geçmişinde duruyor.
    - **Doğrulama:** Parça doğrulayıcısı her parçayı izinli her sektör hızında ve katalogdaki her tempoda (M3-21'den beri 90, 100, 120 BPM) dener: 25 parça, 186 deneme, 0 hata. Havuzlar turun temposuna göre kurulur (`SectorCatalog.min_beat_px(bpm)`).
    - **Dersler:**
      - libsndfile'in Vorbis kodlayıcısı uzun bir parçayı tek seferde yazarken çöküyor (çıkış kodu 127, 3 KB'lık dosya). Küçük bloklarla yazılır.
      - Ortalamaya dayalı faz (dairesel ortalama) bakışımsız ritimlerde (vurgulu ara sekizlikler) ilk vuruşu 50 ms'ye kadar yanlış buldu; tepe arayan tarak araması kullanılır.
      - `MusicTrack` `Conductor`'a başvuramaz: `Conductor` `Events` autoload'unu kullanır, ekransız araçlar (`validate_chunks.gd`) autoload tanımaz (M1-04 dersinin tekrarı).
    - **Telefon (Redmi, 2026-10-13, eski beş parça):** Beş parça farklı turlarda çaldı. Tur başındaki takılmadan sonra ses −52…−75 ms geride kalıyor ve ilk 0,7 sn içinde düzeltiliyor (metronomda da böyleydi). 100 BPM'lik parçayla 80 sn'lik ölümsüz turda kayma 17–25 ms (en çok 42 ms), başlangıçtaki dışında yeniden konumlama yok; S1→S2 geçişinde müzik kesilmedi, kayma değişmedi.
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
  - **Diriliş (M4-07):** `revive(m)` mesafeyi en az m'ye (en çok `wall_max_distance`) çıkarır ve `wall_reached`'i yeniden kurar: duvar ikinci kez yakalayabilir (test). Oyuncu ölüyken duvar sürünmez.
  - Değerler: başlangıç 20 m, en fazla 30 m, Glimmer +1 m, kıl payı +3 m, kalkan −8 m (M2-16) → `TuningConfig` "Baskı" grubu. Sürünme sektörden: `SectorDef.wall_creep` (S1 0,3; S2 0,425; S3 0,55 m/sn; GDD'deki S1 0,3 → S5 0,8 aralığının doğrusal ara değerleri).
  - Görsel `CollapseWall` (M3-09, §9): kırık kenarlı glitch bandı ve opak koyu kırmızı dolgu; Run her adımda oyuncunun mesafe × 50 px altına koyar ve müziğin vuruşunu verir.
  - Yakınlık: `1 − mesafe_px / (ekranın alt kenarı − oyuncu)`; 0 duvar ekranın altındayken, 1 oyuncuya değince. 0,01'den az değişim yayılmaz. HUD'da kenarlarda kırmızı vinyet (`%WallVignette`, dokunuşu yutmaz). M3-09'da inceltildi: yalnızca iki yan şerit (`Left`, `Right`: ekran genişliğinin dış %8'i, yüksekliğin %20'sinden aşağısı, kenardan içe sönen geçiş dokusu), yani koridorun dışında (koridor 900 px; 1080 px'lik ekranda kenar payı 90 px). Saydamlık = oran × 1,0. Önceki vinyet tam ekran bir radyal dokuydu (dış %30, × 0,6): yaklaşık 8 kat alan kaplıyor, koridorun kenarlarını da kızartıyordu. İlk değerler (dış %45, × 0,85) M2-15'te ekranın çoğunu kızartıp engelleri okunmaz yapmıştı. **Redmi denemesi (M3-09, ölümsüz, S3):** duvar oyuncuya yetişirken ve yetiştikten sonra dikenler net okunuyor, koridorun içinde kırmızılık yok. Gerilim sesi ve müziğin boğuklaşması: §8.8 (M3-16).
  - **Redmi denemesi (2026-10-12, ölümsüz, S3):** sektör afişi, kehribar ton, duvar boşlukları, veri blokları, lazerler, Glimmer sayacı (1→3), çöküş duvarının ~36 sn'de oyuncuya yetişmesi ve vinyet görüldü. M2-11, M2-12 ve M2-13'ün bekleyen cihaz denemeleri de bununla tamamlandı.

### 8.5 Kıl payı (GrazeDetector)

- `Hurtbox`'tan biraz büyük bir `Area2D` kullanılır (başlangıç +40 px).
- Bir tehlike bu alandan, `Hurtbox`'a hiç değmeden çıkarsa → kıl payı. `Run` kombo sayacını yönetir ve `Events.near_miss(combo, multiplier)` yayar.
- **Uygulama (M2-14):**
  - `GrazeDetector` (`scripts/components/graze_detector.gd`, oyuncunun çocuğu, maske `hazard`): çarpışma kutusu + her yanda `TuningConfig.graze_margin` (0,8 m = 40 px). İçeri giren tehlikeleri izler; çıkan tehlike çarpışma kutusuna değmediyse yukarı `grazed` yayar. `Hurtbox.hit(alan)` değen alanı taşır; `Player` onu `mark_hit()` ile işaretler (kalkan ya da ölümsüzlükle geçilse de kıl payı sayılmaz).
  - `Player.near_missed` (yalnızca canlıyken) → `Run`: son kıl payından bu yana `combo_window` (2,5 sn, oyun zamanı) geçmediyse kombo uzar, geçtiyse 1'den başlar. Çarpan `RunStats.multiplier`: kombo ≥ `combo_x2_at` (3) → ×2, ≥ `combo_x3_at` (6) → ×3 (ilk değerler). Her kıl payında `Events.near_miss(kombo, çarpan)`; pencere dolunca `Events.combo_ended` ve çarpan 1. `GameManager` sayıyı `RunResult.near_misses`'a yazar.
  - Çöküş duvarını itme M2-15'te. "KIL PAYI!" yazısı ve kombo göstergesi HUD'da (M3-12, §5.2).
- **Yavaş çekim (M3-12, ADR-056, GDD §15):** `SlowMotion` (`scripts/components/slow_motion.gd`, `RefCounted`), `Run`'ın içinde.
  - **Ne zaman:** zincirin ilk halkasında ve çarpanın büyüdüğü halkada (kombo 1, 3, 6); aradaki kıl paylarında yok (her seferinde yorucu olurdu). Sürerken yeniden tetiklenirse süre baştan başlar.
  - **Nasıl:** `Engine.time_scale` = taban × `slow_motion_scale` (0,5). Taban, yavaş çekimin başladığı andaki ölçektir (debug yavaş çekimi 0,3 ise 0,15; sonra 0,3'e döner). Bütün oyun yavaşlar: dünya, `Conductor.run_time`, parçacıklar; müzik `AudioManager`'da aynı orana çekilir (§8.3). HUD'un kıl payı canlandırmaları yavaşlamaz.
  - **Süre gerçek zamanla:** fizik adımları zaman ölçeğinden bağımsız olarak gerçek saniyede 60 kez çalışır, yalnızca `delta` küçülür. `Run` her adımda `advance(1 / physics_ticks_per_second)` çağırır: `slow_motion_time` (0,25 sn) ≈ 15 adım (test: 14–16 yavaş adım). Son `slow_motion_return` (0,08 sn) içinde ölçek `smoothstep` ile tabana döner (müzik birden sıçramaz).
  - **Ölüm ve yeniden başlama:** `Run` ölümü gördüğü adımda yavaş çekimi bitirir (ölüm donması ve yeniden başlama uzamaz); tur yarıda kaldırılırsa `_exit_tree` ölçeği geri verir (test).
  - **Belirlenimcilik:** oynanış `delta` ile ilerler, harita yalnızca tohuma bağlıdır. Belirlenimcilik testi iki turu aynı oyun zamanı (35 sn; M3-21'den beri, 90 BPM'lik parça az parça yerleştiriyordu) oynatır, yerleşen parçaların ortak başını karşılaştırır ve dokunan turda yavaş çekimin gerçekten olduğunu doğrular.
  - **Müzik kayması ölçümü (debug `AUDIO` satırları, ölümsüz oyuncu, düzensiz otomatik dokunuş):** PC'de 90 sn'de 12 yavaş çekim: en büyük kayma 11–26 ms, tur başındaki tek düzeltmeden sonra yeniden hizalama yok. Redmi'de 170 sn'de 25 yavaş çekim (2'si ×2 eşiği): en büyük kayma 14–35 ms, yeniden hizalama yok (sınır 40 ms). Not: deneme sahnesi telefonda ekran görüntüsü kaydedince (PNG) ≈ 100+ ms takılma oldu ve her seferinde yeniden hizalama görüldü; yavaş çekimle ilgisi yok (görüntüsüz denemede yok).
  - **Yanlış pozitif ölçümü:** Ölümsüz, dokunuşsuz oyuncu (sol duvarda kalır, sol duvardaki tehlikelere değer, sağdakilerden uzaktır) S1 ve S3'te 4000'er karede 0 kıl payı saydı.

### 8.6 Toplanabilirler ve mıknatıs

- Glimmer'lar desen parçalarının içinde yerleşiktir (belirlenimci).
- Mıknatıs alanındaki Glimmer'lar oyuncuya doğru çekilir (M4-04, aşağıda).
- Toplanan değer ve kombo çarpanı `RunStats` içinde hesaplanır. `RunStats` turun istatistiklerini tutan, `Run`'a ait bir `RefCounted` nesnedir.
- **Uygulama (M2-13):**
  - `scenes/entities/glimmer.tscn` + `Glimmer` (`Area2D`, katman `collectible` = 16, maske `collector` = 8): yuvarlak (yarıçap 18 px), yeşil. Oyuncunun toplama alanı değince kendini gizler, şeklini (ertelenmiş) kapatır ve yukarı `collected(value)` yayar; ikinci değme sayılmaz.
  - `Collector` (`scripts/components/collector.gd`): oyuncunun çocuğu, katman `collector`, yarıçap `TuningConfig.pickup_radius` (1,5 m = 75 px; gövdeden büyük, affedici). Oyuncu Glimmer'ın kodunu çağırmaz; Glimmer alanı algılar.
  - **Yukarı sinyal zinciri:** `Glimmer.collected` → `ChunkInfo.glimmer_collected` → `ChunkSpawner.glimmer_collected` → `Run` → `RunStats.add_glimmer()` (değer × `multiplier`; kombo M2-14) → `Events.glimmer_collected(kazanılan)`. `GameManager` toplamı `RunResult.glimmers`'a, HUD sağ üstteki sayaca (`HUD_GLIMMERS`) yazar.
  - **Havuz:** `ChunkSpawner` parçayı havuzdan alınca `ChunkInfo.reset()` çağırır; Glimmer'lar yeniden etkinleşir.
  - **Doğrudan toplama (M4-06):** `Glimmer.collect()` alan değmesiyle aynı yolu izler (gizle, şekli kapat, `collected` yay; ikinci kez sayılmaz). Başlangıç Sıçramasında `Run → ChunkSpawner.collect_passed(y) → ChunkInfo.collect_passed(y)` y'si oyuncunun altında kalan Glimmer'ları toplar (§8.1).
  - **Yerleşim kuralları** (doğrulayıcı): Glimmer adil bir yolda toplanabilir olmalı (güvenli tablo her kare için saklanır, girişten ileriye güvenli durumlarda gidilir; toplama yarıçapı + Glimmer yarıçapı) ve **riskli yolda** olmalı: bir tehlikeye ya da boşluğa dikeyde en fazla bir vuruş uzakta. Toplama yarıçapı geniş olduğu için tek dikenin yanındaki Glimmer, geçiş sırasında dikeni sıyırarak alınabilir (kıl payı).
  - Glimmer'lı parçalar: `spike_single_01/02` (dikenin önünde, aynı duvarda), `spike_zigzag_01/02` (geçişin ortasında), `spike_switch_01` (bloklar arasında), `gap_single_01` (boşluktan önce), `block_center_01` (bloktan önce, ortada), `laser_gate_01` (kapının açıklığında).
- **Mıknatıs (M4-04, ADR-070):**
  - **Tur yükü:** `Main` tur başında `Progression.loadout()` ile bir `RunLoadout` (`scripts/data/run_loadout.gd`; `magnet_m`, `glimmer_boost`) alır, `Run.loadout`'a ve `GameManager.begin_run(tohum, sektör, yük)`'e verir. Tur sırasında alınan seviye sonraki turda geçerli olur (ADR-066).
  - **`Magnet`** (`scripts/components/magnet.gd`, `RefCounted`): yükte menzil varsa `Run._ready`'de kurulur. Düğüm değildir; fizik alanı (`Area2D`) yerine uzaklık karşılaştırması kullanılır, böylece katman/maske ve havuz düzeni değişmez.
  - **Menzil, toplama alanının ötesine eklenir:** yakalama uzaklığı = `to_px(pickup_radius + magnet_m)` + Glimmer yarıçapı (18 px). Sv1 (1,8 m) → 183 px, Sv5 (5 m) → 343 px. GDD'deki "90–250 px" yalnız başına alınsaydı Sv1 (90 px) bugünkü toplama mesafesinden (75 + 18 = 93 px) kısa kalır, hiçbir şey yapmazdı.
  - **Akış:** `Run._physics_process`, oyuncu yaşıyorsa her adımda `ChunkSpawner.attract(oyuncu yeri, mıknatıs, delta)` çağırır → `ChunkInfo.attract` → `Glimmer.attract`. Menzile giren Glimmer yakalanır; ilk hızı `magnet_pull_speed` (15 m/sn), sonra `magnet_pull_accel` (120 m/sn²) ile hızlanarak `move_toward` ile oyuncuya akar. Menzilden çıksa da bırakılmaz; toplama alanına değince her zamanki gibi toplanır. Glimmer oyuncuyu tanımaz, yalnızca kendisine aşağı verilen hedefe gider.
  - **Harita değişmez:** mıknatıs yalnızca Glimmer'ın yerini değiştirir; parça havuzdan gelince `ChunkInfo` yerleşimi tasarım konumlarından yeniden kurar, `Glimmer.reset()` çekişi sıfırlar. Tohum aynıysa yerleşen parçalar mıknatıslı ve mıknatıssız turda aynıdır (test).
  - **Glimmer Çarpanı:** `GameManager` yükteki oranı `RunResult.glimmer_boost`'a yazar; `Progression.finish_run` tur sonu kazancına (toplanan Glimmer + sektör bonusu) `boost_bonus = roundi(taban × oran)` ekler (31,5 → 32). Günlük: `PROGRESS run earned=… bonus=… boost=…`.
  - **Debug:** `-- --upgrade=magnet:5` (tekrarlanabilir) açılışta seviye koyar (`Progression.set_upgrade_level`, kaydedilir); İlerleme sayfasından (`0`) satın almak da olur.
  - **Redmi'de (M4-04):** Mıknatıs Sv5 + Çarpan Sv1 ile yük `PROGRESS loadout magnet=5.0 boost=0.1`; `tools/phone_frames.py` kare dizisinde Glimmer'ın dikenlere göre ≈ 1,4 m oyuncuya kaydığı ve toplandığı görüldü; kazanç `run earned=32 bonus=25 boost=3` (4 Glimmer + 25 = 29'un %10'u → 3).

### 8.7 Nesne havuzu

- `ObjectPool` (`scripts/systems/object_pool.gd`, `RefCounted`, M2-04): sahne başına önceden oluşturulmuş örnekler.
  - `reserve(n)` tur kurulurken örnekleri oluşturur; `acquire()` / `release()` tur sırasında. `peek()` sahnenin verisini okumak için ilk örneği verir.
  - Boştaki örnek gizli ve `PROCESS_MODE_DISABLED`'dır. İçindeki `Area2D`'ler de fizik dünyasından çıkar (`disable_mode` = REMOVE); testle doğrulandı.
  - Havuz tükenirse uyarı yazar, yeni örnek oluşturur ve `grown` sayacını artırır. Testler `grown == 0` bekler.
- Desen parçaları **bütün olarak** havuzlanır: parçanın içindeki tehlikeler parçayla birlikte gelir (§8.2). İlk tur başında parça başına birkaç kopya oluşur (M3-10'dan beri sonraki turlar aynı kopyaları kullanır); tur sırasında düğüm sayısı sabittir (test: 900 karelik turda düğüm sayısı değişmiyor).
- Ekran altından çıkan desen parçaları havuza döner ve sıfırlanır: hareketli engeller baştan başlar, Glimmer'lar yeniden etkinleşir.
- **Tehlike temizleme (M4-07):** `ChunkSpawner.clear_hazards(üst_y, alt_y)` → `ChunkInfo.clear_hazards`: y'si aralıkta kalan tehlike alanları (`Area2D`, Glimmer hariç) gizlenir ve `monitorable` ertelenerek kapatılır; düğüm silinmez, sayı döner. Parça havuza dönüp `reset()` edilince temizlenenler geri gelir (test).
- **Turlar arasında korunan havuzlar (M3-10, ADR-054):** `ChunkPools` (`scripts/systems/chunk_pools.gd`, `Node2D`) `Main`'in çocuğudur (`World`'ün yanında). `pool_for(sahne)` sahnenin havuzunu ilk istenişte kurar; kopyaları `ChunkSpawner.setup` ayırır (`reserve` yalnızca eksik varsa oluşturur; daha hızlı bir tempo daha çok kopya isterse turlar arasında büyür).
  - `Main` her yeni `Run`'a `chunk_pools`'u verir, `Run` da yerleştiriciye (`ChunkSpawner.shared_pools`). Tur ağaçtan çıkarken yerleştirici etkin parçaları havuza döndürür (`_exit_tree`); Glimmer bağlantısı yerleştirmede kurulur, iadede çözülür. Böylece havuzdaki parça hiçbir tura bağlı kalmaz (test).
  - Parçalar dünya koordinatındadır (`Run` ve `ChunkPools` orijinde). Çizim sırası `z_index` ile korunur: `Corridor` −2 < parçalar −1 < çöküş duvarı ve oyuncu 0 (eskiden ağaç sırası: koridor → yerleştirici → duvar → oyuncu). Telefonda dikenler duvar çizgisinin üstünde (ekran görüntüsü).
  - Neden taşımak değil korumak: düğümü başka ebeveyne taşımak (ağaçtan çıkıp girmek) PC'de 125 kopyada ≈ 12 ms; yeniden kurmak (≈ 14 + 11 ms) kadar pahalı. Kopya sayısını tekrar yasağına göre kısmak da güvenli değil: kural sektör sonunda esniyor.
  - Silme sırası: tur, havuzdan önce silinmeli (yerleştirici çıkarken parçaları geri verir). `Main`'de `World` `ChunkPools`'tan önce gelir; testte tur elle silinir.

### 8.8 Ses efektleri ve gerilim (M3-15, M3-16; ADR-061, ADR-062)

- **Veri:** `SfxBank` (`data/audio/sfx_bank.tres`): `voices` (havuzdaki çalar sayısı, 8) ve `sounds` (`SfxSound` alt kaynakları). `SfxSound`: `event` (`GameTypes.Sfx`), `stream` (OGG, döngüsüz), `volume_db` (müzikle dengeleyen düzeltme), `pitch_jitter`, atıf alanları (`title`, `author`, `license`, `source_url`); `duration(perde)`. Bankayı `tools/sfx_prep.py` yazar.
- **Olay → ses** (hepsi Kenney, CC0; dosyalar `assets/audio/sfx/<olay>.ogg`, değiştirilmeden):

  | Olay (`GameTypes.Sfx`) | Ne zaman (`Events`) | Kenney dosyası | `volume_db` | Perde oynaması |
  | --- | --- | --- | --- | --- |
  | `FLIP` | `player_flipped` | `phaseJump2` (Digital Audio) | −14,4 | ±%6 |
  | `LAND` | `player_landed` (Player `_land`; tur başındaki ilk iniş dahil, oyuncu koridorun ortasından duvara iner) | `impactGeneric_light_000` (Impact Sounds) | −8,7 | ±%8 |
  | `GLIMMER` | `glimmer_collected` | `confirmation_003` (Interface Sounds) | −12,5 | ±%3 |
  | `NEAR_MISS` | `near_miss` | `phaserUp4` (Digital Audio) | −3,8 | ±%4 |
  | `COMBO_UP` | `near_miss`, çarpan büyüdüğünde (×2, ×3); `combo_ended` ve `run_started` sayacı sıfırlar | `highUp` (Digital Audio) | −15,6 | — |
  | `SHIELD_BREAK` | `shield_changed(false)` (kalkan yalnızca tükenince kapanır) | `glass_004` (Interface Sounds) | −9,4 | — |
  | `DEATH` | `player_died` | `explosionCrunch_000` (Sci-fi Sounds) | −1,4 | — |
  | `SECTOR` | `sector_entered` | `zapThreeToneUp` (Digital Audio) | −12,2 | — |
  | `RECORD` | `record_broken` (`RecordLine.passed` → `Run`, turda bir kez) | `jingles_PIZZI10` (Music Jingles) | −5,4 | — |

- **Havuz (`AudioManager`):** `SfxBank.voices` kadar `AudioStreamPlayer`, `SFX` yolunda, oyun açılırken kurulur; tur sırasında düğüm oluşmaz (.clauderules §6). `play_sfx(olay)` boş çaları kullanır; boş yoksa sesinin bitmesine en az kalanı keser.
  - Doluluk gerçek zamanla tutulur (`Time.get_ticks_usec` + `SfxSound.duration`): `play()`'den hemen sonra `playing` hâlâ `false` olabildiği için (§8.3 dersi) aynı karedeki iki efekt aynı çalara düşerdi.
  - Efektler `Engine.time_scale`'i **izlemez**: yavaş çekimde yalnızca müzik yavaşlar (kural vuruş senkronu için, .clauderules §5). Perde oynaması kozmetik `randf`'tir (oynanışı etkilemez).
  - Testler için: `last_sfx()`, `sfx_count(olay)`, `sfx_voices()`; `sfx_bank` değiştirilebilir.
- **Ses düzeyi (`tools/sfx_prep.py`):** Her efektin en yüksek kısa süreli düzeyi (50 ms RMS) müziğin ortanca kısa süreli düzeyine (eski beş parçada −23,4 dBFS; M3-21'in özgün parçaları oyunda `volume_db` ile aynı düzeye çekildi, §8.3) göre katmanına çekilir: sık çalanlar (çevirme, tutunma) −3 dB, ödüller (Glimmer, kıl payı, kombo) +3 dB, büyük anlar (kalkan, ölüm, sektör, rekor) +6 dB. Telefon hoparlörü alçak sesleri vermediği için iki ölçüm de 250 Hz altı atılarak yapılır. Kazanç tepe −1 dBFS'yi geçmeyecek kadarla ve −24…+6 dB ile sınırlı. Kenney paketleri proje dışında indirilir (`PACKS`); kaynaklar depoya girmez.
- **Seçim:** Kullanıcı Redmi'de dinledi ve onayladı ("sesler güzel", 2026-10-15).
- **Ders:** Kalkan için ilk aday `impactGlass_heavy_001` tepe sınırına takıldı (kazanç verilemedi, sessiz kaldı); yerine `glass_004` alındı.
- **Test:** `tests/autoloads/sfx_test.gd`; tutunma sesinin her inişte bir kez çalması `run_effects_test.gd`'de.
- **Gerilim (M3-16, ADR-062):** çöküş duvarı yaklaştıkça (`wall_proximity_changed`) müzik boğuklaşır ve döngülü bir gerilim sesi yükselir (GDD §14).
  - **Veri:** `TensionMix` (`data/audio/tension_mix.tres`): süzgeç `open_hz` 12 000 → `closed_hz` 700 Hz, `filter_curve` 1 (kesim frekansı logaritmik ölçekte iner: yakınlık 0,25'te ≈ 5,9 kHz, 0,5'te ≈ 2,9 kHz, 0,75'te ≈ 1,4 kHz); gerilim sesi `stream`, `volume_db` (en yakında; −18,6 dB), `volume_curve` 1,5 (genlik = yakınlık ^ üs), perde `pitch_far` 1,0 → `pitch_near` 1,2; `smoothing` 0,15 sn; atıf alanları. `cutoff_at`, `volume_at`, `pitch_at`.
  - **Süzgeç:** `Music` yolunda `AudioEffectLowPassFilter` (`default_bus_layout.tres`, kapalı başlar). `AudioManager` onu sırasına bakmadan türüyle bulur. Yakınlık 0 iken kapalıdır (işlemci harcanmaz). Müziğin enerjisi 250–600 Hz'de olduğu için en boğukta bile telefon bandındaki düzey yalnızca 2–3 dB düşer (beş parçada ölçüldü); duyulan fark tınıdadır, müzik kaybolmaz.
  - **Gerilim sesi:** kendi `AudioStreamPlayer`'ı (`SFX` yolu, açılışta kurulur). Kaynak Kenney `computerNoise_000` (Sci-fi Sounds, CC0): telefon bandında (%99 250 Hz üstü, merkez ≈ 1,1 kHz), düzgün (±1 dB), duvarın glitch kimliğine uygun. Motor sesleri (`spaceEngine*`, `forceField*`) enerjilerinin çoğu 250 Hz altında olduğu için telefonda duyulmazdı. `tools/sfx_prep.py` sonunu başına 0,5 sn'lik eşit güçlü çapraz geçişle bindirir (4,5 sn'lik dikişsiz döngü, dikişte −0,2 dB), yeniden kodlar (`assets/audio/sfx/tension.ogg`, içe aktarmada `loop=true`) ve düzeyini müziğin ortanca düzeyinin 3 dB altına çeker (`volume_db` satırını yazar). `Engine.time_scale`'i izlemez (efektler gibi).
  - **Akış:** ses, yakınlığa `_process`'te `smoothing` zaman sabitiyle yetişir (kalkan kırılınca duvar birden yaklaşır; süzgeç sıçramaz). Tur başında ve ölümde hemen sıfırlanır (ölüm sesinin altında gerilim kalmaz); ölümden sonra bildirilen yakınlık (kamera sarsılırken) yok sayılır. Debug günlüğü: `AUDIO tension on/off` ve senkron raporunda `tension`, `lowpass`, `cutoff`.
  - **Testler için:** `music_lowpass()`, `music_lowpass_enabled()`, `tension_player()`, `tension_playing()`, `heard_proximity()`; `tension_mix` değiştirilebilir.
  - **Deneme (PC, Movie Maker, ölümsüz S3, 50 sn; kaydın sesi ölçüldü):** gerilim tur başından sonraki ilk 24 sn içinde açıldı; 8. ölçüde (24 sn) yakınlık 0,33, kesim 4652 Hz; 16. ölçüde 0,99, 712 Hz. Müziğin 3 kHz üstü 51–57 dB'den 38–40 dB'ye indi (≈ −13…−15 dB, göreli), 250 Hz–3 kHz bandı yerinde kaldı (gerilim sesi dolduruyor). **Redmi (2026-10-20, teknik):** dokunuşsuz 25 turda gerilim her turda açılıp kapandı, süzgeç devreye girdi, Godot günlüğünde hata ve uyarı yok. Dokunuş olmadan oyuncu dikenlere çarptığı için yakınlık en çok 0,19 oldu (kesim ≈ 7,1 kHz). 20:9 ekranda duvarın kenarı tur başında ekranın altında görünür (yakınlık ≈ 0,05): gerilim baştan açılır ama −57 dB'de (duyulmaz), süzgeç ≈ 10,4 kHz'de (fark yok). **Kulak denemesi (kullanıcı, Redmi, 2026-10-20):** duvar yaklaşınca müzik boğuklaşıyor ve gerilim sesi geliyor; geçti. Önceki not: ölümsüz denemede yeni sürüm yüklenemedi (MIUI 'USB üzerinden yükle' onayı), telefona dokunuş gönderilmedi. Not: `adb shell am start --esa command_line_params` bu başlatıcıyla argüman geçirmiyor; telefonda argüman için dışa aktarma ayarı `command_line/extra_args` (ör. `"-- --invincible --start-sector=3"`) geçici olarak kullanılabilir (henüz denenmedi: yükleme onaya takıldı).
  - **Test:** `tests/autoloads/tension_test.gd`.

## 9. Görsel mimari

- **Şekiller:** Tüm oyun şekilleri beyaz `Polygon2D` / `Line2D` olarak çizilir. Renkler koddan, aktif sektörün `SectorPalette` kaynağından atanır. Sektör geçişinde yeni palet alttan üste bir renk dalgasıyla yayılır (M3-08).
- **Paletler (M3-02, ADR-044):** Her `SectorDef`'in `palette`'i var (`data/sectors/palette_NN.tres`): `ambient` (duvarlar, ağ, iz parlaması), `accent` (sektör afişi, vuruş nabzı, ağ parlaması, renk dalgasının cephesi), `background` (koyu).
  - Sektörden bağımsız sabit renkler `NeonStyle`'da: `hazard_color` (kırmızı), `glimmer_color` (yeşil), `player_color` (beyaz). Çevre ve vurgu rengi bunların tonuna 30°'den yakın olamaz; doygunluğu 0,2'nin altındaki renkler (beyaz, gri) serbest. Arka planın parlaklığı ≤ 0,2. Hepsi testle denetlenir (`sector_catalog_test.gd`).
  - `Run` paleti uygular: duvarlar `Corridor.set_colors(çevre, vurgu)`, arka plan ekranın temizleme rengi (`RenderingServer.set_default_clear_color`; tam ekran çizim yok, Adreno'da bedava). Tur başında anında, sektöre girişte renk dalgasıyla (aşağıda). HUD sektör afişini `palette.accent` ile boyar.
  - Kesin renkler M3-17'de seçildi ("elektrik" paleti, ADR-059; değerler GDD §12). Ekranın temizleme rengi (`project.godot`) ve `SectorPalette` varsayılanları S1'inkiler. Rekor çizgisinin sarısı paletten bağımsız (`NeonStyle.record_color`).
- **Vuruş nabzı (M3-03, ADR-046):** Sesi kapalı oynayan ritmi görsün diye (GDD §16) duvarlar (ve M3-07'de arka plan ağı) her vuruşta nabız atar. Güç `NeonStyle.beat_pulse(vuruş)`: vuruş anında 1, `beat_pulse_length` (0,35 vuruş) içinde karesel söner. Uygulama tek bir `modulate`: kanal kanal `vurgu / çevre × beat_pulse_boost` (1,4) oranına `beat_pulse_gain` (0,7) kadar çekilir; düğüm başına iş yok. Yalnızca görsel; zaman `Conductor`'dan, bu yüzden yavaş çekimde de müzikle aynı.
- **Parlama (glow): nesne başına sahte parlama (ADR-020).** Her neon nesne kendi parlamasını taşır. Parlama toplamsal karışımla (`CanvasItemMaterial.blend_mode = ADD`) çizilir ve yalnızca nesnenin çevresini boyar. Tam ekran efekt yoktur.
  - **Çizgiler** (duvar, iz) ve geniş açılı şekiller (blok): çizginin geniş kopyaları, enine yumuşak sönen bir dokuyla çizilir. İki katman var: 64 px / %35 ve 26 px / %70.
  - **Küçük, sivri köşeli şekiller** (diken, Glimmer, oyuncu): arkalarında dairesel bir ışık lekesi durur (`Sprite2D` + radyal `GradientTexture2D`). Çizgi kopyası bu şekillerde sivri köşelerde ve kapanma noktasında yay izi bırakıyor.
  - **Bileşenler (M3-01, ADR-043):** `NeonLine` (`scripts/components/neon_line.gd`; parlama kopyaları + çekirdek çizgi; `points`, `color`, `glow_color`, `width`, `closed`, `width_curve`, `gradient`, `glow_enabled`; M3-06'da `tone`) ve `NeonShape` (`neon_shape.gd`; parlama + dolgu + kenar çizgisi; `polygon`, `color`, `fill_alpha`, `line_width`, `glow` = `BLOB` ışık lekesi ya da `LINE` çizgi kopyaları; M3-05'te `tone` ve `sharp`). Ortak durum `Neon`'da (`neon.gd`): `quality`, paylaşılan dokular ve toplamsal malzeme, `GROUP` (`&"neon"`).
    - Değerler veride: `data/visual/neon_style.tres` (`NeonStyle`): kaliteye göre katmanlar, ışık lekesi büyüklüğü ve yoğunluğu, çizgi kalınlığı, dolgu saydamlığı.
    - Düğümler oluşturulurken bir kez kurulur (en çok katman sayısı kadar kopya). Kalite değişince yalnızca görünürlük ve kalınlık değişir; tur sırasında düğüm oluşmaz (.clauderules §6).
    - `NeonShape` parlama düğümlerini yalnızca seçilen tür için (`BLOB` → ışık lekesi, `LINE` → çizgi kopyaları) ve ağaca ilk girerken kurar, dolgunun altına (M3-10). Eskiden her şekil ikisini de kuruyordu; havuzdaki parçaların düğüm sayısı 3552 → 2833.
    - `Neon` autoload kullanmaz: ekransız araç betikleri (parça doğrulayıcı) bileşenleri adıyla derler (§15, M1-04 dersi). Kaliteyi `Main` aktarır: açılışta ve `Events.settings_changed`'de `Neon.set_quality(Settings.effect_quality)` → `call_group(Neon.GROUP, "apply_quality")`. Ağaca yeni giren bileşen geçerli kaliteyi kendisi alır.
    - Ölçüm sahnesi `glow_bench.tscn` bu bileşenlerle kurulu; görüntüsü eskisiyle piksel piksel aynı (M3-01).
    - **Ders (M3-04):** GDScript, alt sınıf `_init` tanımlayınca üst sınıfın `_init`'ini kendiliğinden çağırmaz. `NeonLine` / `NeonShape`'ten türeyen sınıf `_init`'in başında `super()` çağırmalı; yoksa çizgiler hiç kurulmaz (`Trail`'de yaşandı, `trail_test.gd` yakalıyor).
  - **Ölçüm** (M0-09, Redmi, 1080×2400, 120 Hz): parlama yok 8,4 ms · sahte parlama 8,4 ms (≈ +0,9 ms GPU) · WorldEnvironment glow 17,5 ms (57 FPS). Ayrıntı §16.1'de.
- **WorldEnvironment glow kullanılmıyor (S-01 ✅).** Compatibility'de çalışıyor: Canvas arka plan modu yeterli, 3B kamera gerekmiyor, görüntüsü güzel. Ama Redmi'de kare süresini iki katına çıkarıyor. İleride güçlü cihazlar için denenirse şu bulgular geçerli:
  - Compatibility, parlama seviyelerini, gücü ve karışım modunu yok sayar.
  - Eşik rengin parlaklığına bakar; bu yüzden kırmızı geç parlar.
  - `glow_hdr_scale` varsayılanı (2.0) 2B'de parlamayı neredeyse görünmez yapar. Eşik 0.3, ölçek 0.2, yoğunluk 2.0 ile çalıştı.
- **Neon yazı (M3-18, ADR-063):** `NeonLabel` (`scripts/components/neon_label.gd`, `Label`'dan türer; `color`, `tone`, `font_size`). Kendi `LabelSettings`'ini kurar: çekirdek `text_core(parlama)` (renk `text_core_mix` 0,45 oranında beyaza çekilir), kenar `outline` (`text_edge` = yazı boyutunun 0,09'u, parlama renginde), parlama üst üste dış çizgiler (`stacked_outline`, kaliteye göre `text_high_layers` 5 / `text_medium_layers` 2 / `text_low_layers` 0 katman; x = kalınlık oranı, y = yoğunluk, içten dışa).
  - Godot'da üst üste dış çizgilerin kalınlıkları birikir: her katman bir öncekinin dışına eklenir (denendi: kenar 10 + katman 10 = kenar 20). Saydam katmanlar içe doğru üst üste biner, böylece ince ve çok katman yumuşak bir sönüm verir.
  - `Neon.GROUP`'ta: kalite değişince yalnızca katmanlar yeniden yazılır (düğüm yok). `mouse_filter = IGNORE`. `NeonTone.RECORD` (M3-18) rekor sarısını `NeonStyle.tone_color`'dan verir.
  - **Isıtma (M3-19, ADR-064):** yeni bir harf ilk kez çizilince her dış çizgi (kenar + katmanlar) için ayrıca hazırlanır; Redmi'de sektör afişi yeni adıyla tek karede 28–35 ms tuttu (§16.1). `warm_glyphs` (her harften bir tane tutulur) iç çocuk bir `Label`'da (`INTERNAL_MODE_FRONT`, aynı `LabelSettings`, saydam, `IGNORE`) bir kez çizilir. Kopya `draw` sinyalinde (ertelenmiş) gizlenir: harfler hazırdır, ekrana bir şey çıkmaz.
    - Kalınlıklar (kalite, yazı boyutu) değişince yeniden çizilir, renk değişince çizilmez.
    - Harfler yazının kendi tuvalinde hazırlandığı için önbellek cihazın ölçeğiyle aynıdır.
    - HUD harfleri açılışta ve dil değişince verir: sayılara rakamlar, afişe bütün sektörlerin `HUD_SECTOR` metinleri.
  - **Görüntü (PC, üç oran: 16:9, 20:9, 4:3):** yazılar üç oranda okunuyor; yükseklik yazısının başı 16:9 ve 20:9'da koridor duvarının çizgisine biniyor (HUD'un yeri M1'den beri aynı; güvenli alanla birlikte M6-01'de gözden geçirilir). **Redmi** (dokunuşsuz turlar, 2026-10-20): yükseklik S1'in camgöbeğinde, rekor satırı sarı (rekor çizgisiyle aynı renk), Glimmer yeşil parlıyor; okunuyor, Godot günlüğü temiz. M3-19'da en yoğun sahnede yüksek kalite ölçütün içinde kaldı (§16.1); HUD ayrıca ölçülmedi.
- **HUD ayrımı (S-02 ✅):** `background_canvas_max_layer` (0) üstündeki `CanvasLayer`'lar ortam efektlerinden etkilenmiyor. Bu, telefonda doğrulandı. Sahte parlamada bu sorun hiç yok, çünkü parlama yalnızca dünya nesnelerine eklenir.
- **Sabit renkler bileşende (M3-05, ADR-048):** `NeonShape.tone` (`GameTypes.NeonTone`: `CUSTOM`, `HAZARD`, `GLIMMER`, `PLAYER`) rengi `NeonStyle.tone_color()`'dan alır; `CUSTOM`'da `color` geçerli. Böylece sahnede renk yazılmaz, kesin renkler (M3-17) yalnızca `neon_style.tres`'te değişir. `sharp` kenar çizgisinin köşelerini sivriltir (`LINE_JOINT_SHARP`, sınır `sharp_limit`).
- **Tehlikeler (M3-05, ADR-048):** Diken ve blok `tone = HAZARD`, dolgu 0,3, sivri köşeli. Diken ışık lekesiyle, blok çizgi parlamasıyla (geniş açılı şekil) parlar. Çarpışma şekilleri değişmedi (doğrulama aynı: 25 parça, 248 deneme, 0 hata).
  - **Veri bloğu** (`scripts/entities/block.gd`, `Block`): içinde sola yaslı, sönük veri satırları (`block_rows`: konum ve boy oranı, `block_row_inset`, `block_row_width`, `block_row_alpha`); satırlar `_ready`'de çarpışma kutusunun boyundan kurulur.
  - **Süzülme:** `set_beat(vuruş)` yalnızca `Visual`'ı kaydırır: `sin(vuruş × 2π / block_hover_beats) × block_hover_px` (4 px, 2 vuruşta bir tur). Çarpışma kutusu yerinde kalır; görsel sapma kutunun kenarından en çok 4 px (ADR-035). Vuruş lazerlerle aynı zincirden gelir (`ChunkInfo.set_beat`).
- **Lazer (M3-06, ADR-049):** Üç görünüş, hepsi `set_beat`'te çarpışmayla aynı adımda:
  - **Yanık:** `Blade` (`NeonLine`, `tone = HAZARD`, kalınlık = kutu kalınlığı 16 px) + ortasında beyaza çekilmiş çekirdek (`Core`, `laser_core_ratio` 0,4, `laser_core_whiten` 0,6) + ucunda parlamasız sivri üçgen (`Tip`, `laser_tip_px` 24 px kutudan taşar; görüntü kutudan büyük, oyuncunun aleyhine değil). Uç ayrı çokgendir: kalınlık eğrisi parlama kopyalarına da uygulandığı için sivrilen uçta tek yana kayık bir iz bırakıyordu (Redmi'de görüldü).
  - **Sönük:** yalnızca ince ray (`Rail`, `NeonLine`, `laser_off_width` 3 px, saydamlık `laser_off_alpha` 0,3): ışının nereden geçeceğini gösterir.
  - **Uyarı ışıması:** yanmadan `laser_warn_beats` (0,25 vuruş) önce ray kalınlaşıp parlar (`warning_at(vuruş)` 0 → 1; 8 px, 0,85). Bıçak yalnızca çarpışma açıkken görünür (`is_lit()` = `is_on()`; test her 120 Hz adımında).
- **Glimmer (M3-06, ADR-049):** `Visual` bir `NeonShape` (`tone = GLIMMER`, ışık lekesi, dolgu 0,5); daire `_ready`'de çarpışma yarıçapından `glimmer_segments` (20) köşeyle kurulur. Parıltı: `set_beat` ile vuruşta `glimmer_pulse_scale` (%25) büyür, vuruş nabzıyla söner (yalnızca görsel; toplama alanı değişmez). `ChunkInfo.set_beat` Glimmer'lara da iletir.
- **Şekil dili denetimi (M3-06):** Varlık galerisinin Redmi görüntüsü gri tona çevrildi: diken üçgen, blok köşeli kutu, lazer sivri uçlu çubuk, Glimmer daire, oyuncu elmas; renksiz de ayrılıyor (GDD §6).
- **Oyuncu (M3-04, ADR-047):** Çekirdek `Visual` bir `NeonShape` (elmas 60 × 80 px, ışık lekesi, dolgu 0,85, `tone = PLAYER`). Kalkan halkası `NeonLine`.
- **İz (M3-04, ADR-047):** `Trail` (`scripts/components/trail.gd`, `NeonLine`'dan türer), oyuncunun çocuğu, `Visual`'ın altında.
  - `Player` konumunu her fizik adımında `record()` ile verir; ölünce de verir, böylece iz çekirdeğe doğru toplanır. Kayıt halkası `tick_count() + 2` konum (`trail_duration` 0,4 sn × fizik hızı).
  - Çizim `_process`'te: baş önceki ve son adımın arasında, fizik ara değerleme kesrinde (`Engine.get_physics_interpolation_fraction()`), yani oyuncunun çizildiği yerde. Kuyruk da aynı kesirle kayar. Böylece iz hep aynı süreyi kaplar, boyu 120 Hz'de ara karede sıçramaz ve 60 / 120 Hz'de aynıdır (test). Noktalar oyuncunun yerel koordinatına çevrilir.
  - Görünüş: kalınlık `trail_width` (18 px) kuyruğa doğru sıfıra iner (`width_curve`); çekirdek oyuncunun beyazından çevre renginde saydama söner (`gradient`), parlama çevre renginde. `Run` palet rengini `Player.set_ambient` ile aktarır.
  - **Hızla uzar (M3-13, ADR-057):** `Trail.stretch` süre çarpanıdır (`tick_count()` = süre × fizik hızı × çarpan). `Run` sektörün tırmanış hızından `NeonStyle.trail_stretch(speed_feel(hız))` verir (`Player.set_trail_stretch`): S1'de 1, S3'te 1,3, tavanda (22 m/sn) 1,75. Çarpan değişince kayıt halkası sıfırlanmaz: eski kayıtlar korunur, eksik yer kuyruğun konumuyla doldurulur; iz düz tırmanışta yeni süresinin yolunu kaplayana dek yavaşça uzar (test).
  - **Kozmetik izler (M4-08, ADR-074):** `Trail.apply_def(TrailDef)` (`Player.set_trail`; `Run._ready` yükteki izi verir, `null` = varsayılan). Tanımın renkleri eşit aralıkla geçişe yazılır, son renk saydama söner; parlama `glow_color` (saydamsa çevre rengi). `width_scale` kalınlığı, `glow_scale` parlama katmanlarını (`NeonLine.glow_width_scale` → `Neon.apply_halos` genişlik çarpanı), `length_scale` süreyi (`tick_count`, hızla uzamanın üstüne) büyütür. Renksiz tanım (`trail_default`) eski davranıştır: beyazdan sektörün çevre rengine. Renkli iz sektör değişince renklerini korur; çekirdek her izde beyaz, düğüm sayısı izden bağımsız (test). Redmi'de altın ve plazma izleri turda görüldü.
- **Sıkışma-uzama (M3-11, ADR-055; yalnızca görsel):** `SquashStretch` (`scripts/components/squash_stretch.gd`, `RefCounted`) çekirdeğin `Visual`'ını esnetir; çarpışma şekilleri ve `Player`'ın ölçeği değişmez (test).
  - Çevirmede yana `stretch_on_flip` (%25) uzama, inişte `squash_on_landing` (%22) sıkışma; ölçek (1 + sapma, 1 / (1 + sapma)): alan korunur.
  - Sapma sönümlü bir yayla 1'e döner (`squash_frequency` 5 Hz, `squash_damping` 0,4; bir kez hafifçe geri yaylanır). Kapalı biçimde hesaplanır (başlangıç hızı sıfır olan sönümlü salınım): sonuç adım boyundan bağımsız, 60 ve 120 Hz'de aynı (test). Zarf 0,002'nin altına inince ölçek tam 1.
  - Görsel aktif duvara doğru sapma × yarı genişlik kadar kayar: sıkışırken duvardaki kenar, uzarken arkada kalan kenar yerinde durur. Böylece inişte çekirdek duvardan kopmuş görünmez, kalkışta duvarın içine taşmaz.
  - `Player` fizik adımında uygular (ara değerleme ölçeği de yumuşatır). Değerler `NeonStyle` → Sıkışma-uzama.
- **Parçacıklar (M3-11, ADR-055):** `Effects` (`scripts/levels/effects.gd`), `Run`'ın çocuğu, oyuncunun üstünde çizilir. Üç patlama: iniş kıvılcımı (`landing_spark(nokta, yön)`: duvardan koridorun içine ±60°, hareket yönünde uzamış çizgi gibi, sektörün çevre renginde), Glimmer patlaması (`glimmer_burst(nokta)`: her yöne, Glimmer yeşili), ölüm patlaması (`death_burst(nokta)`: her yöne, oyuncu beyazı).
  - **Havuz:** Her tür için `CPUParticles2D` halkası (kıvılcım 3, Glimmer 3, ölüm 1 yayıcı) tur kurulurken bir kez oluşturulur, sırayla yeniden kullanılır. Tek seferlik, hepsi aynı anda çıkan (`one_shot`, `explosiveness` 1), dünya koordinatlı (`local_coords` kapalı): yayıcı yeni yere taşınınca eski parçacıklar yerinde söner. Taşırken ara değerleme sıfırlanır. Tur sırasında düğüm oluşmaz (test: çevirme, iniş, Glimmer ve ölüm dolu turda düğüm sayısı sabit).
  - **Görünüş:** `Neon.blob_texture()` + toplamsal malzeme (parlamayla aynı). Her tür bir `BurstStyle` (`scripts/data/burst_style.gd`; `NeonStyle.landing_spark`, `glimmer_burst`, `death_burst`): sayı, ömür, hız aralığı, yayılma, sönüm, boy aralığı, uzama (`particle_flag_align_y` + ayrık x/y ölçek eğrisi), renk kaynağı (`tone`; CUSTOM = çevre rengi, `Effects.set_ambient`), başta beyaza çekilme (`whiten`). Parçacık ömrü boyunca küçülür ve söner.
  - **Kalite** (`Neon.GROUP`, `apply_quality`): parçacık sayısı ortada `particle_medium_ratio` (%75), düşükte `particle_low_ratio` (%40); en az 1. Sayı değişince yayıcı yeniden kurulur (yalnızca kalite değişiminde).
  - **Akış:** `Player.landed` → `Effects.landing_spark`. Glimmer toplanınca yeri yerel sinyal zinciriyle gelir (`Glimmer.collected(değer, yer)` → `ChunkInfo` → `ChunkSpawner` → `Run`; `Events.glimmer_collected` değişmedi). Ölüm donmasının sonunda (`Run._shatter`) `Player.hide_core()` çekirdeği ve kalkan halkasını gizler, yerinde ölüm patlaması çıkar, kamera sarsılır; iz çekirdeğin yerine toplanmayı sürdürür.
  - **Ölçüm** (Redmi, tezgâhın parçacık modu: oyundakinden çok sık, sürekli patlama; §16.1): yüksekte ≈ +0,1–1,3 ms, düşükte maliyet görülmedi.
- **Ekran sarsıntısı ve ölümde donma (M3-10, ADR-053):** `GameCamera` (`scripts/components/game_camera.gd`) "travma" modeliyle sarsılır.
  - `add_trauma(miktar)` travmayı artırır (en çok 1); travma `shake_decay` (1,5 /sn) hızıyla söner. Ofset = `shake_offset` (1 m = 50 px) × travma² × gürültü. **Yalnızca yatay:** oyuncunun üstünde görünen mesafe sarsıntıda da aynı kalır (görüş kuralı §3, test). Yalnızca görsel; `view_top()` / `view_bottom()` ve desen üretimi etkilenmez.
  - Gürültü: 64 düğümlü döngüsel dizi; düğümler sırayla sola ve sağa, genlikleri rastgele 0,5–1 (kozmetik, global `randf`); düğümler arası `smoothstep` geçiş, hız `shake_frequency` (20 Hz). `FastNoiseLite` elendi: tek boyutta ortalama |değer| ≈ 0,18 (sarsıntı sönük kalıyordu) ve t = 0'da hep 0.
  - Ofset fizik adımında hesaplanır (kamera da fizik adımında işler); ara değerleme konumla birlikte yumuşatır.
  - **Ölümde donma:** `Run._frozen(delta)`, ölümün görüldüğü adımdan `death_freeze` (0,1 sn = 6 adım) boyunca dünyayı durdurur: vuruş saati, lazerler, dalga, duvar, iz (`Player.set_held`: oyuncu ve izi yerinde, iz ara değerlemeyi de bırakır; yoksa kuyruğu iki adım arasında titrerdi). Ara değerlenen arka plan titremesin diye son değerleri yeniden verilir. Donma bitince `death_trauma` (0,8) eklenir. `death_freeze` = 0 ise sarsıntı hemen başlar. M4-07'den beri vuruş saati, sıçrama ve duvar donmadan sonra da oyuncu ölü kaldıkça durur (diriliş kaldığı yerden sürsün diye, §7.3); iz ve kamera sürer.
  - Donma `Run`'a yereldir: `Engine.time_scale` değişmez; müzik ve UI etkilenmez. Main'in 0,35 sn'lik yeniden başlama beklemesinin içindedir, turlar arası süre uzamaz. Kalkan kırılınca `shield_trauma` (0,5) eklenir (donma yok).
  - PC'de (kare dizisi): her ölümden sonra tam 6 donuk kare (kare farkı 0), ardından duvar ≈ ±12–19 dünya px'i yatayda sallanıyor, ≈ 14 karede yeni tur.
  - **Tur başı ilk kare (M3-10'da bulundu):** yeniden başlama zamanlayıcısıyla kurulan turun ilk karesi kamerasız çiziliyordu (çöküş duvarı ekranı bir kare kırmızıya boyuyordu); duvarlar ve çöküş duvarı da ilk karelerde varsayılan konumlarından kayarak geliyordu. `Run._ready` sonunda duvarı yerine koyar, `reset_physics_interpolation()` (çocuklara yayılır) ve `force_update_scroll()` çağırır.
- **Arka plan veri ağı (M3-07, ADR-050):** `Background` (`scripts/levels/background.gd`, `scenes/levels/background.tscn`), `Run`'ın çocuğu bir `CanvasLayer` (`layer = -1`): ekran koordinatında, dünyanın ardında. Altında ekranın temizleme rengi (sektörün arka planı) durur.
  - **Shader değil çizgi geometrisi.** İlk sürüm tam ekran bir shader'dı (her pikseli işleyen `ColorRect`); Redmi'de yüksek kalitede kareyi 8,4 ms'den 13,5–13,9 ms'ye (GPU %99,8) çıkardı (§16.1). Çizgiler ekranın yalnızca küçük bir kısmını boyar.
  - **Katmanlar:** `%Grid` altında `%Far` (uzak: hücre `grid_far_cell` 100 px, çizgi 1,5 px, saydamlık 0,06, paralaks `grid_far_parallax` 0,12) ve `%Near` (yakın: 300 px, 2,5 px, 0,1, paralaks 0,3; kesişimlerde `grid_node_radius` 6 px, 0,3 saydamlıkta düğüm). Dikey çizgiler ekranın ortasından (koridorun ortası) hizalı. Her katman ekran boyu değişince bir kez çizilir (`draw_multiline` + `draw_circle`, kenar yumuşatmalı), beyaz ve saydamlıkla; rengi `self_modulate` (sektörün çevre rengi).
  - **Paralaks:** `Run` her fizik adımında `set_scroll(kamera y)` verir; katmanın konumu `layer_offset` = kameranın paralaks yolunun bir hücre içindeki kalanı, `layer_row` satır sayacıdır (uzun turda sayılar büyümez, desen sarılmada sıçramaz; test). Kamera yukarı çıkınca ağ aşağı, dünyadan yavaş, uzak katman daha da yavaş kayar. Konum `_process`'te fizik ara değerleme kesriyle (kameranın çizildiği yer).
  - **Nabız:** `set_beat(vuruş)`: `%Grid`'in `modulate`'i `beat_pulse` gücüyle vurgu / çevre oranına (× `beat_pulse_boost`) ve saydamlık × (1 + `grid_pulse_alpha`) değerine `beat_pulse_gain` kadar çekilir (duvarların nabzıyla aynı model). Her vuruşta yakın katmanın düğümlerinin `grid_flash_density` (%12) kadarı vurgu renginde parlayıp söner (`%Flash`: nokta + ışık lekesi, saydamlık nabızla). Seçim `flash_nodes(vuruş sırası, satır…)`: vuruşa ve düğümün desendeki yerine bağlı tamsayı özeti (kozmetik, turun RNG'sine dokunmaz); katman kayınca aynı düğüm parlamayı sürdürür. Yeniden çizim yalnızca vuruşta ve satır değişince.
  - **Kalite** (`Neon.GROUP`, `apply_quality`): yüksekte iki katman, ortada yalnızca yakın katman (`grid_far_min_quality`), düşükte ağ yok (`grid_min_quality`): düz renk.
  - **Dokunuş:** ağaçta `Control` yok, dokunuşları yutamaz (test; ayrıca debug testi oyun alanına dokunuşun çevirdiğini sınıyor).
- **Hız çizgileri (M3-13, ADR-057; yalnızca görsel):** `SpeedLines` (`scripts/levels/speed_lines.gd`, `Node2D`), `Background`'ın `%SpeedLines` çocuğu (ağın ve parlayan düğümlerin üstünde, dünyanın ardında; ekran koordinatı). İnce dikey çizgiler ekranda aşağı, dünyadan hızlı akar (GDD §13).
  - **Hız hissi:** `NeonStyle.speed_feel(tırmanış hızı)`: `speed_feel_min_speed` (12 m/sn, S1) 0, `speed_feel_max_speed` (22 m/sn, tavan) 1, arası doğrusal (S2 0,2, S3 0,4). His arttıkça çizgi sayısı (`speed_line_count` 4 → 24; S3'te 12), boyu (160 → 480 px), başındaki saydamlık (0,15 → 0,4) ve düşüş hızı (tırmanış hızının 1,6 → 2,6 katı) artar; her çizginin boyu ve hızı ±%30 sapar (`speed_line_jitter`).
  - **Akış:** `Run._show_speed` tur başında (hemen, ekran çizgilerle dolu başlar) ve sektör girişinde (`Background.set_speed`) çağırır. Sektör girişinde gösterilen his yeni değere `speed_feel_rate` (1 /sn) hızıyla gider; yeni çizgiler ekranın üstünden, yarım ekran boyu içinde rastgele aralıklarla girer (birden belirmez; test). Ölümde `stop_speed`: çizgiler yeniden doğmaz, akarken `speed_line_fade` (0,25 sn) içinde söner.
  - **Bellek ve çizim:** Konumlar kurulurken en çok çizgi sayısı kadar ayrılan sabit dizilerde; ekranın altından çıkan çizgi üstten yeniden doğar (düğüm yok, tur sırasında ayırma yok). Hepsi tek bir dikey gradyan dokusuyla (kuyruk saydam, baş parlak) `draw_texture_rect` ve toplamsal malzemeyle; rengi sektörün çevre rengi (`set_color`, `Background.set_colors`). Konum ve sapmalar kozmetik rastgelelik (global `randf`), turun RNG'sine dokunmaz.
  - **Kalite:** sayı parçacık oranlarıyla azalır (`speed_line_amount` → `particle_amount`: ortada %75, düşükte %40).
  - **Ölçüm** (Redmi, tezgâhın hız modu: tavan his, 24 çizgi, yüksek kalite; §16.1): ≈ +0,7–1,1 ms. Oyunda S3'te 12 çizgi.
- **Rekor çizgisi (M3-14, ADR-058; yalnızca görsel):** `RecordLine` (`scripts/entities/record_line.gd`, `NeonLine`'dan türer; sahnesiz), `Run`'ın `%RecordLine` çocuğu. Rekorun yüksekliğinde koridoru duvardan duvara geçen yatay neon çizgi (GDD §8).
  - **Rekor nereden gelir:** `Progression.best_height_m` kalıcı rekordur (M4-02; ölümde `finish_run` günceller ve kaydeder; M3-14'te `GameManager`'daki oturum rekoruydu). `Main` her yeni tura `Run.record_height` olarak verir (tohum ve başlangıç sektörü gibi). `Run._place_record` çizgiyi HUD yüksekliğiyle aynı hesapla koyar: `_start_y − to_px(rekor − başlangıç sektörünün yüksekliği)`; oyuncu çizgiye vardığı adımda yükseklik tam rekordur (test). Rekor yoksa ya da tur rekorun üstünden başladıysa (kontrol noktası) çizgi yok. HUD'un `HUD_BEST` satırı da aynı rekoru `best_height_changed`'den alır.
  - **Görünüş** (`NeonStyle` → Rekor çizgisi): `record_color` sarı (tehlike kırmızısı, Glimmer yeşili, oyuncu beyazı ve sektör renklerinden ayrı). Oyuncu `record_heat_distance` (40 m) içine girdikçe kalınlık 3 → 7 px, saydamlık 0,45 → 1. Vuruşta `record_pulse_gain` (0,5) kadar beyaza çekilir (`beat_pulse`). Parlama katmanları kaliteye göre (`NeonLine`).
  - **Geçiş:** Oyuncu çizgiye vardığında çizgi beyaz ve `record_flash_width` (16 px) kalınlıkta parlar, `record_fade` (0,6 sn) içinde söner ve o turda bir daha görünmez. M3-15'in "rekor kırma" sesi buraya bağlanır (o zaman `Run`, `Events`'e bir sinyal ekler).
  - **Akış:** `Run` her fizik adımında `track(oyuncunun y'si, vuruş)` çağırır (donmada çağrılmaz); geçişten sonraki sönme `_process`'te. Çizim sırası: `z_index` −2, koridordan sonra; desen parçalarının (−1) ve oyuncunun altında: tehlikeler çizginin üstünde okunur. Çarpışması yok, oyuncuyu tanımaz.
  - **Katman kuralı** (kabul ölçütü "dünya HUD'a erişmiyor"): sahne denetimi artık dünya ile UI arasındaki başvuruları açıkça arıyor (§13.1).
  - **Kanıt:** PC kare dizisinde (`--record=12`) çizgi uzakta ince, yaklaştıkça kalın; tam 12 m'de beyaz parlayıp sönüyor. Redmi'de (dokunuşsuz, ikinci tur): çizgi HUD'un `BEST 92 m` satırıyla aynı yükseklikte, dikenler çizginin üstünde okunuyor, geçildikten sonra oyuncunun altında sönüyor; Godot günlüğü temiz. Tek `NeonLine` (en çok 4 `Line2D`); ayrı ölçülmedi, M3-19'un toplam ölçümüne girer.
- **Renk dalgası (M3-08, ADR-051):** Sektöre girişte yeni palet ekranın altından üstüne yayılır (GDD §12). Yalnızca görsel; oynanışı etkilemez.
  - **Zaman:** `Run` dalganın geçen süresini her fizik adımında ilerletir; ilerleme `NeonStyle.wave_progress(süre)` (0 → 1, `wave_time` 1,2 sn). Cephe ekran koordinatında `wave_front(ilerleme, üst, alt)`: alttan üste doğrusal. Ekranın temizleme rengi girişte hemen yeni arka plana geçer; cephenin üstünü eski arka plan rengi örter.
  - **Arka plan** (`Background.start_wave(eski arka plan, yeni çevre, yeni vurgu)`, `set_wave(ilerleme)`, `end_wave()`): `%Wash` cephenin üstünü eski arka plan rengiyle boyar. Her ağ katmanının bir eşi var (`%WaveGrid` → `%WaveFar`, `%WaveNear`; yeni paletin renginde): eski katman cephenin üstünü, eşi altını çizer (dikey çizgiler cephede bölünür, yatay çizgiler ve düğümler y'ye göre süzülür). Parlayan düğümler cephenin altında yeni vurgu renginde. `%Crest` cephede yeni vurgu renginde bir çizgi ve yüksek kalitede altında yeni çevre renginde sönen bir ışık bandı (`wave_crest_width` 5 px, `wave_glow_height` 220 px, `wave_glow_alpha` 0,6, `wave_glow_min_quality` orta). Düşük kalitede ağ yok: düz renk + çizgi. Dalga sürerken katmanlar her karede yeniden çizilir (yalnızca 1,2 sn).
  - **Duvarlar** (`Corridor.set_wave(dünya cephesi, yeni çevre, yeni vurgu)`): her duvar parçası cepheye uzaklığına göre `wave_weight(y, cephe)` (cephe çevresinde `wave_blend` 400 px'lik yumuşak geçiş) ağırlığıyla eski ve yeni çevre rengi arasında boyanır; renk değişmeyen parça yeniden boyanmaz. Dalga sürerken vuruş nabzı yeni paletin vurgusuna çeker. `segment_colors(yan)` testler için (y, r, g, b) listesi.
  - **Oyuncu:** iz rengi oyuncunun y'sindeki ağırlıkla (`Player.set_ambient`). Dalga bitince `Run` yeni paleti bir kez uygular; dalga sürerken yeni bir sektöre girilirse eski dalga hemen tamamlanır.
  - **Afiş dalgayla gelir:** HUD `sector_entered`'da afişi, dalganın afişin ekran yüksekliğine ulaştığı ana kadar bekletir (`wave_reach_time(y oranı)`; UI dünyaya dokunmaz, yalnızca aynı `NeonStyle` hesabını kullanır). Afiş %125'ten %100'e (`BANNER_POP_SCALE`, `BANNER_POP_TIME` 0,25 sn) belirerek gelir. Sonraki sektörden başlayan turda afiş hemen görünür.
  - **Ölçüm** (Redmi, tezgâhın dalga modu: sektör paletleri arasında art arda dalga, yani en kötü durum): dalga kareye ≈ 0,5–1 ms ekliyor (§16.1). Bir sektör girişinde yalnızca 1,2 sn sürüyor. M3-19'da oyunun içinde (S3, yüksek): dalga sürerken 9,8–10,8 ms, çöküş duvarı yakınken en pahalı (§16.1).
- **Çöküş duvarı (M3-09, ADR-052):** `CollapseWall` (`scripts/entities/collapse_wall.gd`, `scenes/entities/collapse_wall.tscn`; GDD §14). Yerel y = 0 öldürme çizgisidir, aşağısı duvarın içi. Yalnızca görsel; yakalama `PressureSystem`'de (§8.4). Run her fizik adımında konumunu ve müziğin vuruşunu verir (`set_beat`).
  - **Kırık kenar:** Kenar `collapse_column` (36 px) genişliğinde sütunlara bölünür; her sütunun üstü 0 ile −`collapse_jag` (36 px) arasında. Kenar hiç öldürme çizgisinin altına inmez: duvar olduğundan yakın görünebilir, uzak görünmez. `collapse_slice` (14 px) yüksekliğindeki satırların bir kısmı (`collapse_slice_chance` %20) ±`collapse_slice_shift` (40 px) yana kayar. Desen vuruş başına `collapse_steps_per_beat` (4) kez değişir. Sütun ve dilim değerleri adım başına bir kez CPU'da tamsayı özetiyle hesaplanır (kozmetik; turun RNG'sine dokunmaz) ve shader'a dizi olarak yazılır (`tops[96]`, `shifts[32]`; boyları `CollapseWall.MAX_COLUMNS` / `MAX_ROWS` ile aynı, test denetler). Adım 1024'te sarılır.
  - **Glitch bandı** (orta ve üstü, `collapse_glitch_min_quality`): `assets/shaders/collapse_glitch.gdshader`, yalnızca kenarın çevresindeki bantta (`collapse_rise` 70 px üstü + `collapse_depth` 100 px içi, ekran genişliği + taşma payı; tam ekran değil). Kenarın üstünde sönen ışık (`collapse_glow` 24 px, `collapse_glow_alpha` %50) ve yukarı doğru seyrelen veri kırıntıları (`collapse_block` 12 px bloklar, `collapse_dust_density` %12); içte bozuk bloklar ve tarama çizgileri, bandın altına doğru söner; kenar çizgisi (`collapse_edge_width` 6 px) ortası beyaza çekilmiş, vuruşta parlar (`collapse_pulse_gain`). Yüksek kalitede (`collapse_split_min_quality`) kenarın iki kaymış kopyası: kenar rengi ve tümleyeni (`collapse_split` 5 px renk kayması). Kenarın altındaki pikseller hızlı yoldan geçer (yalnızca dolgu + bloklar).
  - **Düşük kalite:** shader yok. Aynı kırık kenar bir `NeonLine` çizgisi (`tone` tehlike) ve sütun başına bir dolgu dikdörtgeni (`%Top`) olarak çizilir.
  - **Dolgu** (`%Body`): öldürme çizgisinden ekranın altına, opak `collapse_body_color`; altında kalan her şey silinmiş görünür. Ekran boyu değişince bant ve dolgu yeniden kurulur. Ağaçta `Control` yok (dokunuş yutmaz).
  - **Ölçüm** (Redmi, §16.1): duvar ekrandayken yüksekte ≈ +0,5–0,8 ms, ortada biraz daha az. Duvar ekranda değilken maliyeti yok.
- **Shader'lar:** Çöküş duvarının glitch bandı (M3-09, yukarıda), S5 için renk kayması. Hepsi kalite ayarına bağlıdır. **Tam ekran shader yok:** Adreno 610'da her pikseli işleyen tek bir katman ≈ 5 ms GPU (M3-07 ölçümü); shader yalnızca etkinin kapladığı alana çizilir. **Piksel başına özet (hash) pahalı:** piksel başına değişmeyen değerler CPU'da bir kez hesaplanıp uniform dizisiyle verilir (M3-09'da ≈ 0,9 ms kazandırdı).
- **Efekt kalitesi:** Yüksek / Orta / Düşük (`Settings.effect_quality`). Sahte parlama: yüksekte iki katman (64 px / %35 + 26 px / %70) ve ışık lekesi, ortada tek katman (40 px / %55) ve ışık lekesi, düşükte parlama yok (M3-01). Parçacık sayısı ortada %75'e, düşükte %40'a iner (M3-11). HUD yazılarının parlaması yüksekte 5, ortada 2 katman, düşükte yok (M3-18).

## 10. Veri modeli (Resource sınıfları)

| Sınıf (`scripts/data/`) | Dosyalar | İçerik |
| --- | --- | --- |
| `TuningConfig` | `data/tuning/default_tuning.tres` | His ayarları, `@export_group`'larla gruplu: Hareket (`gravity_accel`, `max_side_speed`; tırmanış hızı M2-08'de `SectorDef`'e taşındı), Adalet (`input_buffer_time`, `hurtbox_scale`, `coyote_time` M2-11, `shield_grace` M2-16), Baskı (`wall_start_distance`, `wall_max_distance`, `glimmer_push`, `near_miss_push`, `shield_pull`; M2-15), Kıl payı (`graze_margin`, `combo_window`, `combo_x2_at`, `combo_x3_at`; M2-14; yavaş çekim `slow_motion_scale`, `slow_motion_time`, `slow_motion_return`; M3-12), Toplama (`pickup_radius`, M2-13; mıknatıs çekişi `magnet_pull_speed`, `magnet_pull_accel`, M4-04), Kamera ve dünya (`lookahead`, `corridor_width`, `run_start_gap`, `sector_breath`), Zorluk (`difficulty_spread`, `no_repeat_count`; M2-10), Oyun hissi (`death_freeze`, `death_trauma`, `shield_trauma`, `shake_offset`, `shake_decay`, `shake_frequency`; M3-10), Başlangıç Sıçraması (`head_start_speedup` = 8: sıçramadaki toplam hız çarpanı, `head_start_grace` = 1 sn: bitişteki dokunulmazlık; M4-06), Diriliş (`revive_grace` = 2 sn dokunulmazlık, `revive_clear_time` = 2,5 sn: önünde temizlenen yol sektörün tırmanışıyla, `revive_clear_behind` = 3 m, `revive_wall_distance` = 20 m; M4-07), Ekonomi (`sector_bonus` = 25: geçilen her sektör için 25 × sektör numarası Glimmer; M4-02). Tam sayı alanları ayar paneli tam sayı olarak yazar. Ayrıntı aşağıda |
| `SectorDef` | `data/sectors/sector_01.tres` … `sector_03.tres` (M2-08) | `name_key` (`SECTOR_N_NAME`), `climb_speed` (m/sn), `length` (m), `allowed_hazards`, `min_difficulty`–`max_difficulty`, `palette` (M3-02); `beat_px(bpm)`, `climb_px()`. Tempo M2-20'de sektörden turun parçasına taşındı |
| `MusicTrack` | `data/music/<id>.tres` (M2-20) | `id`, `stream` (OGG), `bpm`, `loop_start`, `volume_db`, `title`, `author`, `license`, `source_url`; `beat_length()`, `length()`, `position_at(vuruş_saati)`. Parçaları `tools/music/build.py` üretir (M3-21) |
| `MusicCatalog` | `data/music/music_catalog.tres` (M2-20) | Tur müzikleri; `pick(tohum)`, `tempos()`, `max_bpm()` |
| `SfxBank` | `data/audio/sfx_bank.tres` (M3-15) | `voices` (havuz), `sounds: Array[SfxSound]`; `sound_for(olay)` (§8.8) |
| `SfxSound` | `sfx_bank.tres` içinde alt kaynak (M3-15) | `event` (`GameTypes.Sfx`), `stream`, `volume_db`, `pitch_jitter`, `title`, `author`, `license`, `source_url`; `duration(perde)` |
| `TensionMix` | `data/audio/tension_mix.tres` (M3-16) | `open_hz`, `closed_hz`, `filter_curve`, `stream`, `volume_db`, `volume_curve`, `pitch_far`, `pitch_near`, `smoothing`, atıf alanları; `cutoff_at`, `volume_at`, `pitch_at` (§8.8) |
| `SectorCatalog` | `data/sectors/sector_catalog.tres` (M2-08) | Sıralı sektör listesi; `def_at(n)`, `start_height(n)`, `end_height(n)` (son sektör: INF), `sector_at(m)`, `min_beat_px(bpm)`. S4–S5 M4-11 / M4-12'de eklenir; o zamana kadar S3 bitmez |
| `SectorPalette` | `data/sectors/palette_01.tres` … `palette_03.tres` (M3-02) | `ambient`, `accent`, `background` (§9). `SectorDef.palette` ile bağlı |
| `NeonStyle` | `data/visual/neon_style.tres` (M3-01) | Kaliteye göre çizgi parlama katmanları (`high_layers`, `medium_layers`, `low_layers`; x = genişlik px, y = yoğunluk), `blob_min_quality`, `blob_scale`, `blob_padding`, `blob_intensity`, `line_width`, `fill_alpha`; sabit renkler `hazard_color`, `glimmer_color`, `player_color` (M3-02); `shield_color`, iz `trail_duration`, `trail_width` (M3-04); duvar `wall_fill_light`, `wall_fill_dark`, `wall_core_whiten`, nabız `beat_pulse_length`, `beat_pulse_gain`, `beat_pulse_boost` (M3-03); arka plan ağı `grid_min_quality`, `grid_far_min_quality`, `grid_near_cell`, `grid_near_parallax`, `grid_near_width`, `grid_near_alpha`, `grid_node_radius`, `grid_node_alpha`, `grid_far_cell`, `grid_far_parallax`, `grid_far_width`, `grid_far_alpha`, `grid_pulse_alpha`, `grid_flash_density`, `grid_flash_alpha` (M3-07); renk dalgası `wave_time`, `wave_blend`, `wave_crest_width`, `wave_glow_height`, `wave_glow_alpha`, `wave_glow_min_quality` (M3-08); çöküş duvarı `collapse_body_color`, `collapse_glitch_min_quality`, `collapse_split_min_quality`, `collapse_steps_per_beat`, `collapse_rise`, `collapse_depth`, `collapse_column`, `collapse_jag`, `collapse_slice`, `collapse_slice_shift`, `collapse_slice_chance`, `collapse_block`, `collapse_dust_density`, `collapse_edge_width`, `collapse_glow`, `collapse_glow_alpha`, `collapse_split`, `collapse_pulse_gain` (M3-09); sıkışma-uzama `stretch_on_flip`, `squash_on_landing`, `squash_frequency`, `squash_damping`, parçacıklar `particle_medium_ratio`, `particle_low_ratio`, `landing_spark`, `glimmer_burst`, `death_burst` (M3-11); hız hissi `speed_feel_min_speed`, `speed_feel_max_speed`, `trail_speed_stretch`, `speed_line_count`, `speed_line_length`, `speed_line_width`, `speed_line_alpha`, `speed_line_speed`, `speed_line_jitter`, `speed_feel_rate`, `speed_line_fade` (M3-13); `layers_for(kalite)`, `max_layer_count()`, `shows_blob(kalite)`, `beat_pulse(vuruş)`, `wave_progress(süre)`, `wave_front(ilerleme, üst, alt)`, `wave_weight(y, cephe)`, `wave_reach_time(oran)`, `particle_amount(sayı, kalite)`, `speed_feel(tırmanış hızı)`, `trail_stretch(his)`, `speed_line_amount(his, kalite)` |
| `BurstStyle` | `data/visual/neon_style.tres` içinde alt kaynak (M3-11) | Bir parçacık patlaması: `amount`, `lifetime`, `speed` (x en az, y en çok), `spread`, `damping`, `size`, `stretch`, `tone`, `whiten` (§9) |
| `UpgradeDef` | `data/upgrades/*.tres` | `id` (kayıttaki anahtar), `name_key` / `desc_key` (`UPGRADE_*`), seviye fiyatları `costs: Array[int]` (uzunluğu en üst seviye), seviye etkileri `values: Array[float]`, `unit` (`m`, `ratio`, `count`); `cost_for(seviye)`, `value_at(seviye)` (seviye 0 = alınmamış → 0). Etkiler dünya biriminde: Mıknatıs 1,8–5 m (GDD'deki 90–250 px), Kalkan Sv1 = 0 (yenilenmez), Sv2–5 yenilenme mesafesi m; Glimmer Çarpanı ek oran 0,1–0,5 (M4-03) |
| `UpgradeCatalog` | `data/upgrades/upgrade_catalog.tres` | `upgrades: Array[UpgradeDef]` (mağaza sırası), `get_def(id)`, `ids()`; `Progression.UPGRADES` (M4-03) |
| `TrailDef` | `data/trails/*.tres` | `id` (kayıttaki anahtar), `name_key` / `desc_key` (`TRAIL_*`; açıklama yalnızca başarım izinde, `%d` = hedef), `unlock` (`GameTypes.TrailUnlock`: `FREE`, `PURCHASE`, `GREAT_STORAGE`, `NEAR_MISSES`), `cost`, `goal`, `colors` (boşsa çevre rengini izler, `follows_ambient()`), `glow_color` (saydamsa çevre rengi), `width_scale`, `glow_scale`, `length_scale` (0,5–2). Renkler tehlike ve Glimmer tonlarından en az 30° uzak (test; M4-08). İzler birbirinden (OKLab görünüş farkı ≥ 0,25) ve her sektörün Neon izinden (≥ 0,15) ayırt edilir; test sektör kataloğunu dolaştığı için S4/S5 paletleri de denetlenir (ADR-075) |
| `TrailCatalog` | `data/trails/trail_catalog.tres` | `trails: Array[TrailDef]` (mağaza sırası, ilki varsayılan), `get_def(id)`, `default_def()`, `ids()`; `Progression.TRAILS`. Sekiz iz: Neon (varsayılan), Ayaz 300, Ametist 600, Altın 1000, Plazma 1800, Kuyruklu Yıldız 3000; Kıl Payı (toplam 500) ve Büyük Depo başarımları (M4-08) |
| `Earnings` | (kod, statik, M4-08) | Tur sonu kazanç formülleri: `sector_bonus(başlangıç, ulaşılan)`, `boost_bonus(taban, oran)` (GDD §9.1). `Progression.finish_run` ve ekonomi benzetimi (M4-14) aynı formülü kullanır |
| `ChunkInfo` | desen parçası sahnelerinin kökü | Zorluk, sektör aralığı, vuruş uzunluğu, etiketler |
| `ChunkLibrary` | `data/chunks/chunk_library.tres` | Oyunda kullanılan desen parçası sahnelerinin listesi (M2-04) |
| `RunResult` | (kod, `RefCounted`) | Yükseklik, Glimmer, kıl payı sayısı, ölüm nedeni, ulaşılan sektör, tohum; kazanç (`sector_bonus`, `glimmer_boost`, `boost_bonus`, `earned`; M4-02, M4-04) |
| `RunLoadout` | (kod, `RefCounted`, M4-04) | Turun yükseltme yükü, tur başında `Progression.loadout()` verir: `magnet_m` (mıknatıs menzili, m), `glimmer_boost` (kazanç ek oranı); `start_shield`, `shield_regen_m` (0 = yenilenmez; M4-05); `head_start_m` (Başlangıç Sıçramasının ek yolu, m; M4-06). `revives` (ücretsiz diriliş hakkı; İkinci Şans Sv1 = 1; M4-07). `trail` (kuşanılan `TrailDef`, kozmetik; günlük meydan okumada da kalır; M4-08) |
| `GameTypes` | (kod, `RefCounted`) | Paylaşılan enum'lar: `DeathCause`, `Quality`, `Sfx` (M3-15). Autoload'ların iç enum'ları tip olarak kullanılamadığı için ortak türler burada durur |

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
| `user://savegame.tmp` | Yazılmakta olan kayıt (atomik yazma) | Şifreli JSON |
| `user://savegame_debug.json` (+ `.bak`, `.tmp`) | Debug build kaydı | Düz JSON (incelenebilir) |
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
- **Atomik yazma:** Önce `savegame.tmp`'ye yazılır ve geri okunarak doğrulanır (okunan metin yazılanla aynı olmalı). Sonra eski `.dat` → `.bak`, `.tmp` → `.dat` yapılır. **Yalnızca sağlam `.dat` yedeğe geçer:** ana kayıt bozuksa silinir, iyi yedeği ezmez (M4-01).
- **Yükleme sırası:** `.dat` → bozuksa `.bak` → o da yoksa yeni kayıt (`SaveManager.last_source`: `MAIN`, `BACKUP`, `NEW`; debug günlüğünde `SAVE loaded source=…`). Kayıt `.dat`'tan gelmediyse `Progression` açılışta hemen yeniden yazar (ilk açılışta dosya oluşur, yedekten açılınca ana kayıt onarılır).
- **Bozuk dosya:** şifreli dosyanın ilk dört baytı Godot'nun imzası (`GDEC`) değilse hiç açılmaz (motor açmaya çalışırken hata yazdırırdı); JSON `JSON.parse()` ile denenir, sözlük değilse bozuk sayılır.
- **Şemaya uydurma:** her yüklemede kayıt `SaveManager.default_data()` şablonuna uydurulur (`conform`): eksik ya da türü yanlış alan şablondan gelir, bilinmeyen alan düşer, JSON'un ondalık sayıları tam sayıya döner, dizilerde türü uymayan öğe atılır. Bu yüzden **alan eklemek sürüm gerektirmez**; şema yayına kadar sürüm 1'de kalır.
- **Sürüm geçişi:** `version` alanı okunur; kayıt `migrate(veri, eski, yeni, adımlar)` ile adım adım yükseltilir (`_migration_steps()`: `{1: _migrate_v1_to_v2}` gibi; şimdilik boş). Sürüm yalnızca bir alanın anlamı ya da yapısı değişince artar. Daha yeni sürümden gelen kayıt (eski uygulama) uyarıyla okunur, bilinen alanlar korunur.
- **Ne zaman kaydedilir:** Tur sonunda, satın alma ve kuşanmada, ayar değişiminde, uygulama arka plana geçtiğinde (`NOTIFICATION_APPLICATION_PAUSED`) ve kapanırken.
  - **Uygulama (M4-02):** `Progression.finish_run` her tur sonunda yazar. Arka plana geçişte, pencere kapanırken (`NOTIFICATION_WM_CLOSE_REQUEST`) ve Android geri tuşunda (`NOTIFICATION_WM_GO_BACK_REQUEST`) yalnızca kaydedilmemiş değişiklik varsa yazar (`_dirty`). Süren turun Glimmer'ı tur bitene kadar cüzdana girmez: uygulama tur ortasında öldürülürse o turun kazancı kaybolur (bilinçli; M5'te duraklatma gelince yeniden bakılır).
  - `stats.total_height_m` turların skorlarının (mutlak yükseklik) toplamıdır.
  - **İzler (M4-08):** `trails.owned` sahip olunan iz kimlikleri (varsayılan iz her zaman sahiplidir; katalogda olmayan kimlik sayılmaz), `trails.equipped` kuşanılan. Satın alma ve kuşanma hemen kaydeder. `great_storage_reached` bayrağını `Progression.mark_great_storage_reached()` koyar (M4-13).
  - **Testler gerçek kayda dokunmaz:** debug yapısında gdUnit komut aracıyla (`GdUnitCmdTool.gd`, `tools/check.ps1`) çalışılıyorsa `SaveManager` açılışta `user://test_runs/`'a geçer ve oradaki kaydı siler; her test oturumu boş kayıtla başlar. Kayıt kullanan testler `Progression.reset()` ile başlar.
- **Bulut kaydı** (Play Games Saved Games): M7'de değerlendirilecek.

## 12. Yerelleştirme

- `localization/translations.csv`: `keys,en,tr` sütunları. Godot bunu içe aktarıp çeviri kaynağına dönüştürür.
  - Koddan atanan metinler `tr("KEY")` ile gösterilir.
  - Sahnede `Label` ya da `Button` metnine doğrudan anahtar yazılır (`text = "UI_TAP"`). Godot bunu otomatik çevirir (`auto_translate_mode` varsayılanı) ve dil değişince kendisi günceller.
- Varsayılan dil: cihaz dili Türkçe ise TR, değilse EN. Ayarlardan değiştirilebilir.
- **Font (M3-17, ADR-059):** Exo 2 (SIL OFL 1.1), değişken ağırlıklı tek dosya `assets/fonts/exo2.ttf`; kalın (700) kesimi `assets/fonts/exo2_bold.tres` (`FontVariation`). Proje ayarı `gui/theme/custom_font` onu gösterir: her `Control` kendiliğinden bu fontu kullanır, sahnelerde font ataması yoktur.
  - Fontlar Türkçe karakterleri (ş ğ ı İ ö ü ç) ve HUD işaretlerini (× ·) içermek zorundadır (S-06); `tests/ui/font_test.gd` denetler.
  - **Ders:** `variation_opentype`'ta eksen metin anahtarıyla (`"wght"`) yazılırsa Godot etkisiz bırakıyor, font ince kalıyor. Sayı etiketi (`TextServer.name_to_tag("wght")` = 2003265652) ya da `"weight"` gerekir.
  - Bir `Theme`'in `default_font`'u, varsayılan temada tanımlı tür fontunu (Label) ezmiyor; tema ile font denenecekse `set_font("font", "Label", ...)` kullanılır (M3-17 önizlemesinde yaşandı).
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
  - **Olay günlüğü:** Önemli `Events` sinyalleri `EVENT <ad> t=<ms>` satırı olarak yazılır (`_connect_event_log`). Telefondaki denemeler `adb logcat -s godot:*` ile bu satırlardan doğrulanır. Kayıtlı olaylar: `run_started`, `run_ended`, `player_flipped`, `player_died cause=<NEDEN>`, `sector_entered`, `chunk_placed`, `near_miss`, `combo_ended`, `shield_changed`, `head_start_changed active=… height=…` (M4-06; son duyurulan yükseklik), `player_revived` (M4-07), `trail_unlocked id=…`, `trail_equipped id=…` (M4-08); yeni olaylar ilgili görevde eklenir. `AudioManager` ayrıca `AUDIO …` satırları yazar (çalan parça, kayma, yeniden konumlama; M2-20); `SaveManager` `SAVE loaded source=<MAIN|BACKUP|NEW>` ve `SAVE saved bytes=<n>` satırlarını (M4-01); `Progression` `PROGRESS loaded glimmers=… best=… sector=…` ve `PROGRESS run earned=… bonus=… wallet=… best=…` satırlarını (M4-02). `run_ended` satırı M4-02'den beri kazancı, bonusu ve rekor durumunu da yazar.
  - **Varlık galerisi** (`scenes/debug/entity_gallery.tscn`, M3-05): oyunun diken, blok, lazer ve Glimmer sahneleri S1 renkleriyle yan yana, vuruşla canlı (128 BPM). Görsel işleri rastgele parça beklemeden incelemek ve ekran görüntüsü almak için. PC'de `<godot> --path . res://scenes/debug/entity_gallery.tscn`; telefonda sahne geçici olarak ana sahne yapılıp yüklenir, sonra geri alınır.
  - Ders: `Viewport.push_input()` ile dokunuş taklit edilirken koordinat viewport biriminde verilecekse ikinci parametre `true` olmalı. Aksi hâlde pencere ölçeği (PC'de 450/1080) uygulanır ve nokta hedefini ıskalar.
- **İlerleme sayfası** (M4-03, `scripts/debug/progress_panel.gd`, `ProgressPanel`, debug katmanında `%ProgressPanel`; ayar paneliyle aynı yerde, ikisi aynı anda açık kalmaz): cüzdan, rekor, en yüksek sektör; her yükseltme için "AD sv/en üst" ve "Al <fiyat>" düğmesi (cüzdan yetmezse kapalı, en üstte "En üst"); "+1000 Glimmer" (hemen kaydeder), "Kaydı sıfırla" (`Progression.reset()`), "Kapat". İçeriği kodla kurulur (yükseltme sayısı veriden). `Progression`'ı servis olarak çağırır, `glimmers_changed` / `best_height_changed` / `upgrade_purchased` ile yenilenir. Mağaza ekranı (M5) gelene dek yükseltmeler buradan denenir.
  - **İzler sayfası (M4-08):** "İzler ›" / "Yükseltmeler ›" düğmesi iki sayfa arasında geçer. Her iz için "AD · kuşanılı / sahip / <fiyat> Glimmer / başarım: …" ve düğme: "Al <fiyat>" (cüzdan yetmezse kapalı), "Kuşan", "Kuşanılı" (kapalı), başarım izinde "Aç (debug)" (bedelsiz açar, kaydeder). `trail_unlocked` / `trail_equipped` ile yenilenir. Kuşanılan iz sonraki turda görünür. Açılış argümanı `-- --trail=trail_gold` izi verir ve kuşandırır.
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
- **PC tuşları:**

  | Tuş | İşlev | Görev |
  | --- | --- | --- |
  | `1` | Ayar paneli | M1-11 |
  | `2` | Ölümsüzlük | M1-12 |
  | `3` | Çarpışma kutularını göster | M1-12 |
  | `4` | Yavaş çekim | M1-12 |
  | `5` | Sonraki sektörün başından yeni tur (son sektörde aynı sektör); paneldeki "Sektör ›" düğmesi | M2-08 |
  | `6` | Ekran oranı döngüsü (16:9 → 20:9 → 4:3) | M1-06 |
  | `7` | FPS / kare süresi | M1-02 |
  | `8` | Kalkan ver (paneldeki "Kalkan" düğmesi de; `Events.debug_shield_requested`) | M2-16 |
  | `0` | İlerleme sayfası (ayar panelindeki "İlerleme ›" düğmesi de) | M4-03 |
  | `9` | Efekt kalitesi: yüksek → orta → düşük (paneldeki "Kalite" düğmesi de; yalnızca bu oturum, kaydedilmez; `Events.settings_changed`) | M3-07 |
  | `R` | Anında yeniden başla | M1-12 |

  F5–F8 kullanılmaz; Godot editör kısayollarıyla karışır.
- **Debug tuşlarının uygulanışı (M1-12):**
  - Tuşlar ayar panelinin ikinci sırasındaki düğmelerin basılı durumunu değiştirir; işi düğmenin `toggled` sinyali yapar. Böylece tuş ve düğme hep aynı durumu gösterir. Telefonda bu düğmeler kullanılır.
  - **Ölümsüzlük (`2`):** `Events.debug_invincibility_changed(enabled)` yayılır. `Player` darbeleri yok sayar ve yarı saydam olur (alfa 0,45). Yeni turdaki oyuncu bu durumu bilmediği için debug katmanı her `run_started`'da durumu yeniden duyurur.
  - **Çarpışma kutuları (`3`):** `SceneTree.debug_collisions_hint` açılır ve ağaca `queue_redraw` yayılır; dünyaya tek tek erişilmez.
  - **Yavaş çekim (`4`):** `Engine.time_scale = 0,3`. .clauderules §5 gereği `AudioManager` müziğin `pitch_scale`'ini `Engine.time_scale`'e uydurur (M2-20'den beri gerçek parçayla).
  - **`R`:** `Events.retry_requested` yayar; `Main` turu yeniden kurar.
  - Ekransız denemede 10 durum geçti: ölümsüzken 400 karede ölüm yok, R sonrası ölümsüzlük sürüyor, kapatınca diken öldürüyor, çarpışma kutuları açılıp kapanıyor, yavaş çekimde 60 karede tam 180 px.
  - Redmi'de ölümsüzlük düğmesiyle 8 sn'de ölümsüz 143 m tırmanıldı.
  - **Başlatma argümanları (M2-07, M2-11):** `<godot> --path . -- --invincible` ölümsüzlüğü baştan açar (PC'de uzun denemeler); `--start-sector=2` ilk turu o sektörden başlatır (kare yakalama); `--quality=low|medium|high` efekt kalitesini bu oturum için seçer (M3-07); `--record=40` rekoru baştan verir, ilk turda rekor çizgisi görünür (M3-14; M4-02'den beri kalıcı rekordur, tur sonunda debug kaydına da yazılır); `--perf=6` oyunun içinde performans ölçer, `--auto-tap=0.5` ölçüm sırasında dokunuş gönderir (M3-19, aşağıda); `--upgrade=magnet:5` yükseltme seviyesi koyar, tekrarlanabilir (M4-04; kayda yazılır). Telefonda `am start` ile argüman verilemiyor (Godot'nun asıl etkinliği dışa açık değil); orada düğme kullanılır. **Telefonda argüman (M3-19'da denendi):** `export_presets.cfg` → `[preset.0.options]`'a geçici `command_line/extra_args="-- --invincible --start-sector=2 --perf=6 --auto-tap=0.5"` eklenip yüklenir; ölçümden sonra satır geri alınır ve normal yapı yeniden yüklenir (yoksa telefondaki oyun ölümsüz açılır).
  - **Oyunun içinde ölçüm (M3-19, `PerfProbe`, `scripts/debug/perf_probe.gd`):** debug katmanı `--perf=<sn>` ile kurar. Efekt kalitesi her evrede yüksek → orta → düşük döner (`Settings.effect_quality` + `settings_changed`, kaydedilmez); evrenin ilk 1 sn'si ölçülmez. Her evrenin sonunda `PERF phase=… q=… sector=… frames=… avg_ms=… p95_ms=… max_ms=… wall_frames=… wall_avg_ms=… wall_peak=… wave_frames=… wave_avg_ms=… flips=… near=… spikes=…`: çöküş duvarı ekrandayken (`wall_proximity_changed` > 0) ve renk dalgası sürerken (`sector_entered`'dan `wave_time` boyunca) geçen kareler ayrıca. Takılmalar (25 ms üstü kare, `SPIKE_MS`) olduğu anda `PERF spike ms=… draw_ms=… after_draw_ms=… texture_mb=… phase=… sector=… t=…` satırıyla: önceki karenin çizimi (`frame_pre_draw` → `frame_post_draw`), çizimin bitişinden ölçüme kalan süre (ekran takası, fizik, işlem) ve doku belleğinin değişimi. Dünyayı tanımaz, yalnızca `Events`'i dinler. `--auto-tap` dokunuşu `Input.parse_input_event` ile oyun alanına gönderir. GPU doluluğu aynı anda adb kabuğundan `date +%s.%N` damgasıyla okunur, `logcat -v epoch` ile evrelere bölünür (§16.1). Test: `tests/debug/perf_probe_test.gd`. Telefonda kaliteyi dokunuşsuz seçmek için debug sürümünde ayar dosyası yazılabilir: `adb exec-in run-as com.gravityhopper.dev sh -c 'cat > files/settings.cfg' < dosya` (`[video]` / `effect_quality=0…2`; sonra dosya silinir, M3-07).
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
    - **Katman kuralı (M3-14):** dünya katmanının (`scripts/levels`, `entities`, `systems`, `components`; `scenes/levels`, `entities`) betik ve sahneleri UI'ya (`scripts/ui`, `scenes/ui`), UI'nınkiler dünyaya (bileşenler hariç: `Neon` iki katmanın da yapı taşı) başvuramaz. Aranan: öteki katmanın `class_name`'leri (tam sözcük, proje sınıf listesinden), dosya yolları ve ağaç dışı `/root/…` düğüm yolları; sahnelerde dış kaynak yolları. Yorumlar sayılmaz. Özet satırı taranan dosya sayısını yazar (`katman kuralı 68 dosyada`). Denendi: `run.gd`'ye HUD sahnesinin yolu, `hud.gd`'ye `Run` tipi, `player.tscn`'ye HUD sahnesi eklenince üçü de `KURAL` olarak yakalandı.
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
  - **Barındırma: itch.io** (D-12, kullanıcı kararı, ADR-027): https://burak-sisci.itch.io/gravity-hopper (M1-13, 2026-10-15). Sayfa **herkese açık, şifresiz** (kullanıcı kararı, ADR-060; ADR-027'deki şifreli "Restricted" sayfanın yerine). Tür Action; gömme 450 × 800, mobilde dikey, tam ekran düğmesi açık, SharedArrayBuffer kapalı. Yüklenen zip yayın çıktısıdır: debug paneli ve debug argümanları içinde yok (`OS.is_debug_build()`, .clauderules §6). Görünürlük itch.io'da istenince Restricted / Draft'a geri alınabilir.
  - **Güncelleme:** `tools/web_build.ps1 -Smoke` → kullanıcı itch.io'da eski zip'i yenisiyle değiştirir.
  - Elenen seçenekler: özel depodan GitHub Pages (ücretli plan), açık GitHub deposu (şifre yok), Cloudflare Pages / Netlify / GitLab Pages (ek hesap ve kurulum).
  - Yükleme: ilk sürümde kullanıcı tarayıcıdan zip yükler. İleride istenirse itch.io'nun `butler` aracıyla otomatikleşir (API anahtarı kullanıcıda kalır).
  - **Ön ayar** "Web" (`export_presets.cfg` → `preset.1`): `variant/thread_support=false`, masaüstü ve mobil doku sıkıştırması açık, dışlama filtresi Android ile aynı.
  - **Araç** `tools/web_build.ps1`:
    - Yayın çıktısını `builds/web/`'e alır ve itch.io zip'ini (`builds/gravity-hopper-web.zip`, `index.html` kökte) hazırlar.
    - `-Smoke` ile ayrıca debug çıktısını alır. Yerel `python -m http.server` sunar, görünmez Edge'i (yoksa Chrome) DevTools bağlantı noktasıyla açar.
    - Tarayıcı konsolundaki `EVENT run_started` satırlarından oyunun açıldığını doğrular; `-Shot` ile ekran görüntüsü alır.
  - **Boyut:** M1-13'ün ilk denemesinde `index.wasm` 37,7 MB (zip'te 9,8 MB), `index.pck` 0,12 MB. 2026-10-15 yüklemesinde (M3-17 sonrası) `index.wasm` 39,5 MB, `index.pck` 14,2 MB (müzik ve efektler), zip 24,1 MB.
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
| Telefon kare dizisi | `python tools/phone_frames.py <klasör> --seconds 10 --step 4 --sheet` (M4-04): `adb exec-out screenrecord --output-format=frames` ham RGB kareleri 270×600'de borudan okunur, her `step`'inci kare PNG, `--sheet` küçültülmüş tablo (6 sütun). Yalnızca standart kütüphane (ffmpeg yok). Oyun ön planda değilse ya da kilit ekranı açıksa kaydetmez (çıkış 2; kullanıcının ekranı kaydedilmesin), telefona dokunmaz. Kare aralıkları düzensiz: hareketin görüldüğü kanıttır, süre ölçümü değildir | Telefonda hareketin görülmesi gerektiğinde (mıknatıs, ön başlangıç) |
| Web denemesi | `tools/web_build.ps1 -Smoke` (görünmez tarayıcı, konsoldaki olay günlüğü) | Web sürümü hazırlanırken |
| Telefon bildirimi | `tools/notify.ps1` (ntfy.sh): `-Message` gönderir, `-Read` son okumadan beri kullanıcının yazdıklarını verir, `-Wait` kullanıcı yazana kadar 30 sn'de bir bakar. Konu adı ve son okunan kimlik `%LOCALAPPDATA%\gravity-hopper\` altında (depoda değil). Claude'un mesajları `Title: Claude - Gravity Hopper` ile işaretlenir, okurken atlanır. Türkçe karakterler UTF-8 gövdeyle bozulmadan gidiyor (denendi) | Otonom çalışma bitince, takılınca, durdurulunca (gönder); her görev bitiminde (oku) |
| Otomatik test | **gdUnit4 6.2.2** (MIT): RNG belirlenimciliği, desen üretimi, ekonomi, kayıt sürüm geçişi, oynanış davranışları. Ayrıntı aşağıda | M2'den itibaren, her görevde (tam kontrolün 6. adımı) |
| Ekonomi simülasyonu | "Kaç turda ne alınır?" betiği | M4-14 |
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
  | `tests/main_test.gd` | Tur kurulumu, ölümden yeni tura ≤ 30 kare (0,5 sn), sonuçta yükseklik/neden/tohum, sonuç ekranında ikinci ölümün yok sayılması, `retry_requested`; M3-14 eki: rekor sonraki tura geçiyor, daha alçak tur rekoru düşürmüyor; M4-02 eki: rekor kayda iniyor (`new_record`), tur sonucu başlangıç sektörünü, sektör bonusunu (S3'e varan tur 75) ve kazancı taşıyor, kazanç cüzdana ve kayda giriyor |
  | `tests/debug/debug_layer_test.gd` | DBG'ye dokunuş çevirmez (oyun alanına dokunuş çevirir), DBG paneli açar/kapatır, her aralıklı ayar için bir kaydırıcı, tuşlar 1/2/3/4, ölümsüzlüğün yeni tura taşınması; 9 tuşu kaliteyi yüksek → orta → düşük döndürüyor, arka plan ağı düşükte gizleniyor (M3-07); İlerleme sayfası paneldeki düğmeyle ve 0 tuşuyla açılıyor, ayar paneliyle aynı anda açık kalmıyor (M4-03) |
  | `tests/debug/progress_panel_test.gd` (M4-03) | İlerleme sayfası cüzdanı, seviyeleri ve fiyatları gösteriyor; cüzdan yetmezken satın alma düğmesi kapalı; +1000 Glimmer ve satın alma sayfayı ve kaydı güncelliyor; en üst seviyede "En üst"; kaydı sıfırlama. M4-08 eki: izler sayfasına geçiş; cüzdan yetmezken "Al" kapalı; alınan iz "Kuşan", kuşanılan "Kuşanılı"; başarım izi "Aç (debug)" bedelsiz açılıp kaydediliyor |
  | `tests/debug/perf_probe_test.gd` (M3-19) | Kare süresi özeti (ortalama, p95, en kötü); kalite her evrede yüksek → orta → düşük → yüksek; ısınma ölçülmüyor; duvar ekrandayken ve renk dalgası sürerken geçen kareler ayrı sayılıyor, dalga `wave_time` sonra bitiyor; uzun kare (`SPIKE_MS` üstü) ısınmadan sonra takılma sayılıyor |
  | `tests/ui/hud_test.gd` | Yükseklik ve rekor metni (M4-02'den beri `best_height_changed`'den: rekor 0 iken gizli, yeni turda kalıyor), dil değişince TR metni |
  | `tests/systems/object_pool_test.gd` (M2-04) | Örneklerin baştan oluşması, gizli/işlemsiz bekleme, aynı düğümlerin yeniden kullanımı, tükenince büyüme sayacı, boştaki tehlikenin fizikten çıkması |
  | `tests/systems/chunk_spawner_test.gd` (M2-04) | İlk parçanın tam vuruşta başlaması, 2 ekran önün boşluksuz dolu olması, 400 m kaydırmada düğüm sayısının sabit kalması, aynı tohumun iki ekran boyunda aynı haritayı vermesi, sektör süzgeci, koridor genişliği, gerçek turda 900 kare boyunca düğüm sayısı |
  | `tests/levels/determinism_test.gd` (M2-17) | Aynı tohum + başlangıç sektörü → oyuncunun ne yaptığından bağımsız aynı parça dizisi ve konumları (S1–S3), sektör sınırları aynı, farklı tohum farklı. M3-12 eki: turlar aynı oyun zamanı oynanır; dokunan turlarda yavaş çekim oluyor, harita yine aynı |
  | `tests/entities/shield_test.gd` (M2-16) | Kalkanla ilk diken emilir (ölüm yok, `shield_changed` [true, false], duvar 8 m yaklaşır), 1 sn içindeki ikinci diken dokunulmazlıkla geçilir, sonraki öldürür; kalkansız ilk diken öldürür. M4-05 eki: kalkan yükü tur başında kalkan takıyor (`shield_changed` [true]), Sv1'de kırılan kalkan uzun tırmanışta gelmiyor; yenilenme mesafesi (4 m) tırmanılınca kalkan tam o mesafede (bir adım payıyla) geri geliyor ve sonraki darbeyi emiyor. `progression_test.gd` eki: yükteki kalkan seviyeyi izliyor (Sv0 yok; Sv1 başlangıç, yenilenme yok; Sv2–5 1500 / 1200 / 900 / 600 m). Yenilenme yarı mesafeye, başlangıç kalkanı Sv2'ye kaydırılınca 3 + 1 hata |
  | `tests/systems/pressure_system_test.gd` (M2-15) | Sürünme, itmede üst sınır, çekme, tek seferlik `wall_reached`; hızlı sürünmeli turda 2 sn'de `WALL` ölümü, görsel oyuncunun mesafe × 50 px altında, yakınlık artarak 1'e varıyor; ölümsüzken ölüm yok; Glimmer +1 m, kıl payı +3 m; gerçek turda duvarın glitch adımı vuruşla değişiyor (M3-09); M3-10 eki: duvar tur kurulur kurulmaz yerinde |
  | `tests/entities/collapse_wall_test.gd` (M3-09) | `Control` yok; glitch bandı yalnızca kenarın çevresinde (ekran boyunun < %15'i), dolgu opak ve ekranın altına kadar; kalite: yüksekte bant + renk kayması, ortada bant, düşükte kırık kenar çizgisi + dolgu; düşük kalitenin kenarı hiç öldürme çizgisinin altına inmiyor ve gerçekten kırık; shader dizilerinin boyu sabitlerle aynı, değerler sınırda, dilimlerin bir kısmı kayıyor; desen adım adım değişiyor, vuruşta nabız, adım sarılıyor |
  | `tests/entities/near_miss_test.gd` (M2-14) | 60 px yanından geçen tehlike kıl payı, 130 px'ten geçen değil, değen (ölümsüzken) değil; 0,5 sn arayla üç kıl payında kombo 1-2-3, çarpan ×2, 2,5 sn sonra `combo_ended` ve ×1; `RunResult.near_misses`. M3-12 eki: yavaş çekim yalnızca ilk halkada ve ×2 eşiğinde (0,5 / 1 / 0,5), gerçek zamanla 14–16 adım; ölümde ve tur yarıda kaldırılınca zaman ölçeği 1'e dönüyor |
  | `tests/entities/glimmer_test.gd` (M2-13) | Gerçek turda yoldaki Glimmer'lar toplanıyor, `Events` değeri, `RunStats` ve `RunResult.glimmers` tutuyor; ikinci değme sayılmıyor, `reset()` geri getiriyor; çarpan; görünüş çarpışma yarıçapında yeşil daire, vuruşta büyüyüp sönüyor (M3-06) |
  | `tests/entities/block_test.gd` (M3-05) | Diken ve blok tehlike kırmızısında ve sivri köşeli; süzülme yalnızca `Visual`'ı oynatıyor (genlik tam `block_hover_px`, çarpışma şekli ve boyu aynı); veri satırları kutunun içinde, sayısı `block_rows` kadar; gerçek parçada (`block_center_01`) vuruş bloğa ulaşıyor |
  | `tests/entities/laser_test.gd` (M2-12) | Açık pencere vuruşa ortalı (ve `on_phase` 0,5), `set_beat` şekli ve görüntüyü açıp kapatıyor, ışın boyu `length`'ten; gerçek turda her vuruş adımında açık, yarım vuruşta kapalı. M3-06: görüntü her 120 Hz adımında çarpışmayla aynı (iki evrede; gerçek turda her karede), uyarı ışıması yanmadan önce 0'dan artıyor, bıçak kırmızı, kutuyu kaplıyor, ucu kutudan taşıyor |
  | `tests/levels/background_test.gd` (M3-07) | Ağ dünyanın ardında, `Control` yok (dokunuş yutmaz); kalite: yüksekte iki katman, ortada yakın, düşükte gizli; katmanlar dünyayla aynı yönde, ondan yavaş, uzak en yavaş; satır sarılması uzun turda deseni yerinde tutuyor; tur başında konum anında; vuruşta nabız ve parlama, yarım vuruşta sönük; parlayan düğümler her vuruş başka, oranı yaklaşık `grid_flash_density`; gerçek turda ağ sektörün çevre renginde. Renk dalgası (M3-08): afiş zamanlaması dalgayla aynı hesap; cephe alttan üste yürüyor, üstte eski katmanlar, altta eşleri; düşük kalitede düz renk + çizgi, ışık bandı yok |
  | `tests/levels/corridor_test.gd` (M2-11, M3-03, M3-08) | Boşluksuz duvar tam katı; boşluk yalnızca kendi duvarını, tam kenarından keser; boşluk kalkınca duvar geri gelir; düğüm sayısı sabit; kenar çizgileri çarpışma kutularının iç kenarıyla aynı yerde; kesik yalnızca boşluk kenarlarında ve duvar kalınlığında; nabız vuruşta vurguya doğru parlatıp sönüyor; renk dalgası cephenin altını yeni, üstünü eski renkte boyuyor |
  | `tests/entities/player_fall_test.gd` (M2-11) | Boşluktan `FELL` ile düşülür; duvar bittikten 2 kare sonraki dokunuş çevirir ve oyuncu öbür duvara varır; coyote dolduktan sonraki dokunuş kurtarmaz |
  | `tests/systems/chunk_spawner_test.gd` (M2-10 eki) | Beş tohumda S1'in son üçte birindeki ortalama zorluk ilk üçte birinkinden ≥ 1 yüksek, hedef zorluk hiç düşmüyor; sektör sonu dışında son 3 parça tekrar etmiyor |
  | `tests/ui/hud_test.gd` (M2-09 eki, M3-08, M3-09) | Sektör afişi: `sector_entered`'da ad (EN/TR), renk dalgası afişe ulaşınca beliriyor (`wave_time` içinde), 2,4 sn sonra sönme; sonraki sektörden başlayan turda görünür, S1'den başlayan turda gizli. Duvar vinyeti yakınlıkla parlıyor ve iki şeridi koridorun dışında kalıyor (M3-09). Kıl payı yazısı (EN/TR) beliriyor ve 1 sn içinde sönüyor; kombo göstergesi ×2 / ×3, zincir bitince ve yeni turda gizli (M3-12). Dokunuş yutmuyor (M3-18): HUD'daki her `Control` `IGNORE`; oyunun içinde (ölümsüz) altı neon yazının her birinin ortasına dokunuş oyuncuyu çeviriyor (yazılar `STOP` yapılınca iki test de düşüyor). Harf ısıtma (M3-19): her yazı geçerli dilde (EN, TR) gösterebileceği bütün harfleri önceden çiziyor, afiş bütün sektör adlarını (dil değişince yeniden ısıtma kaldırılınca test düşüyor) |
  | `tests/data/sector_catalog_test.gd` (M2-08; M3-02 eki) | S1–S3 değerleri GDD ile aynı, başlangıç/bitiş yükseklikleri, ad çevirileri, vuruş boyları; her sektörün paleti var, çevre ve vurgu rengi tehlike kırmızısına ve Glimmer yeşiline tonca ≥ 30° uzak, arka plan koyu, çevre renkleri farklı; ton kuralı kırmızıyı ve yeşili yakalıyor |
  | `tests/levels/run_sector_test.gd` (M2-08, M2-09, M3-02, M3-08) | Kısa sektörlerle S1→S2→S3: her sektörde adım hızı doğru, `sector_entered` [2, 3], her sektörde diken yarım vuruşta geçiyor, yeni sektörün ilk 2,5 sn'sinde diken yok, renkler paletten (tur başında anında; S2'ye girişte renk dalgası başlıyor ve temizleme rengi S2'ninki, dalga `wave_time` sürüyor, ortasında üst duvar S1, alt duvar S2 renginde; S3'te duvarlar ve arka plan S3 paletinde; M3-02, M3-08), tempo; S2'den başlayan turda yükseklik ve hız |
  | `tests/systems/conductor_test.gd` (M2-07) | Vuruşlar BPM'e göre doğru karede, yavaş çekimde oyun zamanına göre; gerçek turda her diken yarım vuruş anında geçiyor |
  | `tests/autoloads/audio_manager_test.gd` (M2-07; M2-20'de yeniden yazıldı) | Tur başlayınca bildirilen parça çalara konur, döngüsü `loop_start`'tan kurulur; ölümden sonra bildirilen saat yok sayılır, yeni turda parça yeniden kurulur; müziğin hızı `Engine.time_scale`'i izliyor (M3-12). M4-07 eki: dirilişte müzik durduğu vuruş saatinin yerinden yeniden çalıyor |
  | `tests/autoloads/sfx_test.gd` (M3-15) | Her olayın atıflı, döngüsüz bir sesi var; `Events`'teki olay doğru sesi çalıyor, kalkan takılınca ses yok; kombo eşiği yalnızca çarpan büyüyünce; aynı karedeki efektler ayrı çalarlarda, havuz dolunca bitmesine en az kalan kesiliyor, düğüm sayısı sabit; yavaş çekimde efektin perdesi 1 |
  | `tests/data/trail_catalog_test.gd` (M4-08) | İlki varsayılan iz (tek `FREE`, kayıt şablonuyla aynı); 4–6 satılık iz 300–3000 arasında artan fiyatla; başarım izleri (500 kıl payı, Büyük Depo) satılmıyor; kimlikler tek, görünüşler farklı, çarpanlar 0,5–2; renk geçişinin ara tonları ve parlama tehlike / Glimmer tonlarından 30° uzak (kural kırmızı ve yeşili yakalıyor); ad ve koşul metinleri EN/TR. ADR-075 eki: izler birbirinden ve her sektördeki Neon izden OKLab görünüş farkıyla ayırt ediliyor (gerçek `Trail` renk geçişi + parlama); ölçü eski Ayaz ~ Kuyruklu Yıldız ve Altın ~ Kıl Payı çiftlerini yakalıyor |
  | `tests/autoloads/progression_trail_test.gd` (M4-08) | Yeni kayıtta varsayılan iz sahipli ve kuşanılı; satın alma cüzdanı düşürüp kaydediyor, kuşandırmıyor, ikinci kez alınmıyor; başarım / varsayılan / bilinmeyen iz satılmıyor; kuşanma sahiplik istiyor, yeniden açılışta ve tur yükünde duruyor; bozuk kuşanılı kayıt varsayılana düşüyor; 500. kıl payı `finish_run`'da izi bir kez açıyor; Büyük Depo izi açıyor. Bilerek bozunca: `finish_run`'daki açma kaldırılınca 6, kuşanmadaki sahiplik denetimi kaldırılınca 4 hata |
  | `tests/levels/run_trail_test.gd` (M4-08) | Gerçek turda altın iz S1 ve S2'de kendi renklerinde, çekirdek beyaz, düğüm sayısı aynı; varsayılan iz sektörün çevre rengini izliyor; `Main` kuşanılan izi turun yüküne koyuyor. İzin renkleri yok sayılınca 2 hata (`trail_test` 7) |
  | `tests/data/upgrade_catalog_test.gd` (M4-03) | Katalog kayıt şemasının yükseltme anahtarlarıyla aynı; fiyatlar GDD tablosu ve taban × 2^(seviye − 1); etkiler GDD değerleri (Mıknatıs 90 px = 1,8 m); ad ve açıklama EN/TR çevrili. Mıknatıs Sv2 fiyatı 250 yapılınca 2 hata |
  | `tests/autoloads/progression_test.gd` (M4-02) | Sektör bonusu (25 × geçilen sektör numarası; kontrol noktasından başlayan tur yalnızca kendi geçtiklerini alır); tur sonu kazancı cüzdana, rekor, en yüksek sektör ve istatistikler kayda; kısa tur rekoru düşürmüyor, cüzdan birikiyor; yeniden açılışta (`reload`) değerler ve ilk duyurular geri geliyor; kaydedilmemiş değişiklik arka plana geçişte ve kapanışta yazılıyor; `reset` boş kayıt. Bonus bir sektör fazla sayılıp arka plan kaydı kapatılınca 19 hata. M4-03 eki: satın alma cüzdan yetmezse olmuyor, alınınca cüzdan düşüyor, seviye kayda iniyor ve duyuruluyor; en üst seviye ve bilinmeyen yükseltme alınamıyor; seviyeler yeniden açılışta duruyor (cüzdan denetimi kaldırılınca 11 hata). M4-04 eki: Glimmer Çarpanı kazancın tamamına (30 + 75 bonus, %30 → 32) yuvarlanarak ekleniyor, kayda iniyor; tur yükü seviyeleri izliyor ve tur sırasında alınan seviye o turun kazancını değiştirmiyor; debug seviye koyma sınırlanıyor (çarpan kaldırılınca 4 hata). M4-06 eki: yükteki sıçrama yolu seviyeyi izliyor (100 × seviye m). M4-07 eki: yükteki diriliş hakkı İkinci Şans seviyesini izliyor |
  | `tests/autoloads/game_manager_test.gd` (M4-07) | Hak varsa ölüm turu bitirmiyor, bekleyişte gelen ölüm bildirimi hakkı ya da turu etkilemiyor, diriliş `AUTO_REVIVE_DELAY` sonra geliyor, ikinci ölüm turu bitiriyor; önceki turun zamanlayıcısı yeni turdaki dirilişi erken getirmiyor (tur sayacı kaldırılınca 1 hata); yükseltme yokken ölüm turu bitiriyor |
  | `tests/autoloads/save_manager_test.gd` (M4-01) | Düz ve şifreli kayıtta yazıp okuma (sayılar tam sayı); kayıt yoksa boş kayıt; bozuk `.dat`'ta `.bak`'tan açılış ve bozuk ana kaydın yedeği ezmemesi; ikisi de bozuksa yeni kayıt; yarım kalan `.tmp` eski kaydı bozmuyor, sonraki yazma temizliyor; şifreli dosyada alan adı ve değer düz metin olarak yok, debug kaydı okunur JSON; şemaya uydurma (eksik, yanlış türde, bilinmeyen alanlar); sürüm geçişi adım adım. Yedekleme ve doğrulama bilerek kaldırılınca 4 test 14 hatayla düştü |
  | `tests/autoloads/tension_test.gd` (M3-16) | Süzgeç uzakta açık, yakında boğuk; kesim frekansı yakınlıkla iniyor, gerilim sesinin düzeyi ve perdesi yükseliyor; döngü açık ve atıflı; olaydan sonra süzgeç ve ses yakınlığa yetişiyor, duvar ekrandan çıkınca süzgeç kapanıp ses duruyor; birden yaklaşan duvarda ses sıçramıyor; ölüm ve tur başı hemen sıfırlıyor, ölümden sonraki yakınlık yok sayılıyor |
  | `tests/ui/font_test.gd` (M3-17) | Proje fontu Exo 2, ağırlık 700 (sayı etiketiyle); Türkçe harfler ve HUD işaretleri (× ·) fontta var |
  | `tests/data/music_catalog_test.gd` (M2-20; M3-21'de yeniden yazıldı) | Üç özgün parça (Kervan, Pagoda, Kale) ve üç tempo (90 / 100 / 120); her parçanın süresi tam vuruş, döngüsü tam ölçü, ses düzeltmesi sınırda; atıf ve lisans (`Original`, CC0 / CC-BY) tam, bestesi `tools/music/tracks/`'ta; seçim tohuma bağlı ve 300 tohumda her parça seçiliyor; döngü içinde konum sarılıyor |
  | `tests/tools/chunk_validator_test.gd` (M2-05; M2-13 eki: çevrili Glimmer toplanamaz, tehlikeden uzak Glimmer riskli değil; M2-11 eki: iki duvarda üst üste uzun boşluk yakalanıyor, tek boşluk S2'de adil, S1'de izinsiz; M2-12 eki: koridoru kapatan ışın vuruşta yanıyorsa geçilemez, yarım vuruşta yanıyorsa geçilir; lazer S2'de izinsiz) | Örnek parça her sektörde adil; iki duvarı kapatan parça, her vuruşta taraf değiştiren dikenler (S5), parça başındaki diken, sınırdan taşan diken yakalanıyor; havadan geçilebilen diken çifti geçiyor; kamera kuralı; sektör kapsamı |
  | `tests/components/trail_test.gd` (M3-04; M3-13 eki: süre çarpanı değişince kayıtlar korunuyor, iz yeni süresinin yolunu kaplayana dek uzuyor) | İz 60 ve 120 Hz'de aynı (adım başına bir ve iki kare); düz tırmanışta süresi kadar yolu kaplıyor, ara kesirde boyu değişmiyor; baş oyuncunun üstünde; çizgileri kurulu; oyuncu durunca iz sıfıra iniyor; renk beyazdan çevre rengine sönüyor. M4-08 eki: `TrailDef` renkleri, kalınlığı, parlamayı ve boyu koyuyor; renkli iz sektör değişince renklerini koruyor |
  | `tests/components/neon_test.gd` (M3-01, M3-18 ve M3-19 ekleri) | Çizgi ve blok parlaması yüksekte 2, ortada 1, düşükte 0 katman; diken ışık lekesi yüksek ve ortada var, düşükte yok; kalite değişince düğüm sayısı sabit; ağaca yeni giren bileşen geçerli kaliteyi alıyor; kapalı parlama gizli kalıyor; renk çizgiye ve parlamaya ulaşıyor; doku ve malzeme paylaşılıyor; vuruş nabzı vuruşta 1, sönüm süresinde azalıyor, sonra 0 (M3-03); `tone` sabit rengi kenar çizgisine ve parlamaya veriyor, `sharp` köşeleri sivriltiyor (M3-05). `main_test.gd` eki: `settings_changed` kaliteyi `Neon`'a aktarıyor; neon yazı: parlama katmanları kaliteye göre (5 / 2 / 0), kenar ve katman kalınlıkları yazı boyutuna göre, renk `tone`'dan (`RECORD`), dokunuş yutmuyor, düğüm eklemiyor; ısıtma (M3-19): harfler saydam iç kopyada bir kez çizilip gizleniyor, kalite ve boyut değişince yeniden, renk değişince değil |
  | `tests/components/game_camera_test.gd` (M3-10) | Travma en çok 1, söner; sarsıntı yalnızca yatayda ve travma² ile sınırlı; gürültü düğümleri sırayla sola / sağa, sönük değil; gerçek turda ölümden sonra `death_freeze` boyunca vuruş saati ve iz duruyor, ardından iz sürüyor ve kamera sarsılıyor (vuruş saati ölü oyuncunun turunda durmayı sürdürüyor, M4-07) ve oyuncunun üstündeki mesafe değişmiyor; donma 0 iken sarsıntı hemen; kalkan kırılınca hafif sarsıntı |
  | `tests/systems/chunk_pools_test.gd` (M3-10) | Sonraki tur aynı parça düğümlerini ödünç alıyor (yeni düğüm yok, havuz büyümüyor); tur bitince parçalar gizli ve bağlantısız; Glimmer bağlantısı yalnızca etkin parçalarda; Main havuzu tura veriyor, yerleştiricinin çocuğu yok, çizim sırası koridor < parçalar < duvar, oyuncu |
  | `tests/components/squash_stretch_test.gd` (M3-11) | Vuruşta tam sapma ve ölçek (1,25 × 0,8), sonra tam 1'e dönüş; alan korunuyor, sıkışmadan sonra küçük bir geri yaylanma; 60 ve 120 Hz'de aynı sonuç; kayma sıkışmada duvardaki, uzamada arkadaki kenarı yerinde tutuyor |
  | `tests/components/slow_motion_test.gd` (M3-12) | 0,5'e düşüp dönüşte tekdüze artarak 1'e varıyor (15 adım); sürerken yeniden başlatma süreyi uzatıyor ve debug tabanını (0,3) koruyor; durdurma ve kapalı değerler (ölçek 1, süre 0) |
  | `tests/components/magnet_test.gd` (M4-04) | Yakalama uzaklığı toplama alanı + menzil + Glimmer yarıçapı, seviyeyle büyüyor (Sv1 183 px, Sv5 343 px); çekiş ilk adımda başlangıç hızı, sonra ivmeyle artıyor; menzildeki Glimmer yakalanıp hızlanarak hedefe varıyor, yakalanmış kalıyor; toplanmış Glimmer çekilmiyor; havuzdan dönen parçada Glimmer tasarım yerine dönüyor ve çekişi sıfırlanıyor (menzil yarıya indirilince 7 hata) |
  | `tests/levels/effects_test.gd` (M3-11) | Yayıcılar baştan kurulu, halkayla yeniden kullanılıyor (çocuk sayısı sabit, son patlama ilk yayıcıda), hepsi dünya koordinatlı; kıvılcım koridorun içine; düşük kalitede her türde daha az parçacık (en az 1), düğüm sayısı sabit; çevre rengi yalnızca kıvılcımı boyuyor |
  | `tests/levels/speed_lines_test.gd` (M3-13) | Hız verilmeden çizgi yok; hızlı sektörde daha çok, daha uzun çizgi, düşüş tırmanış hızının katı (sapma içinde); sektör geçişinde his yavaşça yükseliyor, yeni çizgiler ekranın üstünden giriyor; ölümde yeniden doğmuyor; düşük kalitede daha az; hız → his eşlemesi |
  | `tests/entities/record_line_test.gd` (M3-14) | Yerleşene dek görünmez; koridoru boydan boya geçer; yaklaştıkça kalınlaşıp parlar, vuruşta beyaza çekilir; çizgiye varınca beyaz parlar, söner, o turda geri gelmez |
  | `tests/levels/run_record_test.gd` (M3-14) | Gerçek turda çizgi rekorun yüksekliğinde: oyuncu çizgiye vardığı adımda yükseklik tam rekor, daha önce değil (çizgi 1 m yukarı konunca test 8 hatayla kırıldı, denendi); rekor yokken ve tur rekorun üstünden başlayınca çizgi yok; sonraki sektörden başlayan turda başlangıç yüksekliğinden sayılıyor |
  | `tests/levels/run_head_start_test.gd` (M4-06) | Gerçek turda Sv1 / 3 / 5: sıçramada ölüm ve kıl payı yok, olaylar [true, false], ek yol hedefin yarım vuruş yakınında ve tam vuruş sayısı, seviyeyle büyüyor; her adımda oyuncunun geçtiği her Glimmer toplanmış; dokunulmazlık bitişten `head_start_grace` sonra kalkıyor. Sıçramadan sonra 900 karede dikenler yarım vuruştan en çok bir kare uzakta geçiliyor. Aynı tohumla yerleşen parçalar sıçramalı turda aynı sırada, düğüm sayısı sabit, havuz büyümüyor. Vuruşa yuvarlama kaldırılınca 15, darbe koruması kaldırılınca 12, süpürme kaldırılınca 12 hata |
  | `tests/levels/run_revive_test.gd` (M4-07) | Gerçek turda (dokunuşsuz, `GameManager` gerçek): diken ölümünde tur bitmiyor; bekleyişte saat ve oyuncu yerinde, diriliş `AUTO_REVIVE_DELAY` sonra; oyuncu ızgaradaki yerinde (tırmanış = tırmanış hızı × `run_time`); önündeki ve altındaki tehlikeler temizlenmiş (gizli, çarpışmaya kapalı), ötekiler yerinde; dokunulmazlıkta ölüm yok; ikinci ölüm turu bitiriyor, yeni diriliş yok, düğüm sayısı sabit. Boşluktan düşüşte oyuncu koridora dönüyor ve ızgarada; duvara yakalanınca duvar 20 m'ye itiliyor, ikinci yakalanma turu bitiriyor; hak yokken ilk ölüm turu bitiriyor. Bilerek bozunca: saat ölümde durmayınca 124, düşme denetimi tırmanıştan sonra yapılınca 6, temizleme kaldırılınca 3, duvarın yeniden kurulması kaldırılınca 2 hata |
  | `tests/levels/run_magnet_test.gd` (M4-04) | Gerçek turda oyuncunun yolundan 4 m ve 6,5 m uzaktaki Glimmer'lar: seviye 0 / 1 / 3 / 5'te yakalananlar [yok, yok], [yok, yok], [4 m], [ikisi]; yakalanan oyuncuya akıp toplanıyor. Aynı tohumla 900 karede yerleşen parçalar mıknatıslı ve mıknatıssız turda aynı, düğüm sayısı sabit, havuz büyümüyor, mıknatıslı turda daha çok Glimmer toplanıyor (menzil yarıya indirilince 2 hata) |
  | `tests/tools/scene_tool_test.gd` (M3-14) | Katman kuralı: UI yolları, sınıf adları ve `/root/` yolları bulunuyor; yorumlar, benzer adlar ve önekle başlamayan metinler sayılmıyor; sahnedeki UI kaynağı bulunuyor |
  | `tests/levels/run_effects_test.gd` (M3-11; M3-13 eki: S3'ten başlayan turda iz S1'dekinden uzun, hız çizgisi daha çok) | Gerçek turda iniş bir kez bildiriliyor ve tutunma sesi bir kez çalıyor (M3-15; duvarın iç kenarında, yönüyle; duvarda kayarken yeni iniş yok), kıvılcım değilen noktada; çevirmede görsel uzuyor, inişten sonra tam 1'e dönüyor, çarpışma şekilleri ve oyuncunun ölçeği değişmiyor; Glimmer toplandığı yerde patlıyor; ölüm donmasının sonunda çekirdek gizleniyor ve patlıyor; çevirme, iniş, Glimmer ve ölüm dolu turda düğüm sayısı sabit (`Performance.OBJECT_NODE_COUNT`; bir düğüm eklenince test kırılıyor, denendi) ve havuz büyümüyor |
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
- Redmi Note 12'de 60 FPS'te **kare süresi ≤ 10 ms** (bütçenin yaklaşık %60'ı). Kalan pay daha zayıf cihazlar içindir. **M3-19:** en yoğun gerçek sahnede (S3, bütün efektler) yüksek kalitede 9,1–9,7 ms, ölçüt tutuyor. Yalnızca sektör girişindeki 1,2 sn'lik renk dalgası, çöküş duvarı yakınken 10,8 ms'ye çıkıyor (§16.1).
- Tur sırasında bellek ayırma yok (havuzlama).
- İndirme boyutu hedefi < 40 MB (M6-03'te ölçülür). M2-20'den sonra debug APK 68 MB: iki işlemci mimarisinin motor kitaplıkları + 13,4 MB müzik. Play'e yüklenen AAB'den her cihaz yalnızca kendi mimarisini indirir; gerekirse müzik sıkıştırması artırılır.
- Ayarlarda **60 FPS sınırı** seçeneği (pil için). Varsayılan: ekranın yenileme hızı.

### 16.1 Ölçüm (M0-09, Redmi Note 12)

Sahne: `scenes/debug/glow_bench.tscn`. Duvarlar, 14 diken, 8 blok, 20 Glimmer, oyuncu + iz, ızgara ve HUD, tam ekran 1080×2400. Her mod 4 sn ölçüldü, iki kez. Modlar: parlama yok, WorldEnvironment glow, sahte parlama (yüksek / orta), renk dalgası (M3-08), çöküş duvarı (yüksek / orta; M3-09: duvar ekranın %75 yüksekliğinde, oyunun HUD'u ve vinyeti yakınlık 0,6'da), parçacıklar (yüksek / düşük; M3-11: oyunun `Effects`'i, iki duvarda 0,35 sn'de bir kıvılcım, 0,2 sn'de bir Glimmer patlaması, 1 sn'de bir ölüm patlaması; ölçüm bitince tezgâh yüksek kaliteli parçacık modunda kalır). Başka bir cihazda yeniden ölçmek için sahne geçici olarak ana sahne yapılıp yüklenir (gerekirse debug paneline bir düğme olarak bağlanır); PC'de `<godot> --path . res://scenes/debug/glow_bench.tscn`.

| Mod | Ort. kare süresi | p95 | FPS | GPU doluluğu |
| --- | --- | --- | --- | --- |
| Parlama yok | 8,4 ms | 9,3–10,6 ms | 119 | %77 |
| Sahte parlama | 8,4 ms | 9,3–9,4 ms | 119 | %88 |
| WorldEnvironment glow | 17,4–17,7 ms | 18,5–19,9 ms | 57 | %99,9 (tıkanmış) |

**Yeniden ölçüm (M3-01, neon bileşenleriyle, aynı sahne):** parlama yok (düşük kalite) 8,35 ms · yüksek kalite 8,35 ms (p95 9,1–9,2) · orta kalite 8,35–8,37 ms (p95 9,1) · WorldEnvironment glow 16,9–17,9 ms (56–59 FPS). Bileşenler maliyet eklemedi.

**Arka plan veri ağı (M3-07, aynı sahne; tezgâhın düz ızgarası yerine oyunun `Background`'ı, kaliteyle değişir; GPU doluluğu ölçüm sırasında adb kabuğundan 0,1 sn'de bir okundu, iki tur):**

| Mod | Tam ekran shader (ilk sürüm) | Çizgi geometrisi (sonuç) |
| --- | --- | --- |
| Düşük (ağ yok) | 8,35 ms | 8,35 ms (p95 9,2–9,4) · GPU %67–72 |
| Orta (yakın katman) | 12,3–12,7 ms · GPU %99,8 | 8,36–8,64 ms (p95 9,2–9,6) · GPU %99 |
| Yüksek (iki katman) | 13,5–13,9 ms (72–74 FPS) · GPU %99,8 | 8,80–9,27 ms (p95 9,6–10,5; 108–114 FPS) · GPU %99,8 |

- Asıl ölçüt (60 FPS'te ≤ 10 ms) tutuyor. 120 Hz'de yüksek kalite 120 FPS'in biraz altında: ağ GPU'ya ≈ 1–1,5 ms ekliyor. M3-19'da (en yoğun sahne) gerekirse uzak katman seyreltilir ya da çizgilerin kenar yumuşatması kapatılır.
- Ders: Adreno 610'da 1080×2400'ü baştan sona işleyen tek bir shader katmanı ≈ 5 ms GPU. Tam ekran efekt yerine etkinin kapladığı alan çizilir.

**Renk dalgası (M3-08, aynı sahne, yüksek kalite; tezgâhın dalga modu sektör paletleri arasında art arda dalga yürütür, yani oyundakinden çok daha sık: en kötü durum):**

| Ölçüm | Sahte parlama (dalgasız) | Art arda dalga |
| --- | --- | --- |
| 1. tur (iki ölçüm) | 8,45 / 9,20 ms | 9,69 / 11,59 ms (p95 11,05 / 13,75) · GPU ≈ %99 |
| 2. tur (iki ölçüm) | 9,15 / 8,67 ms | 9,29 / 9,67 ms |

- Parçalar (2. tur, geçici deney kodu, commit edilmedi): örtü (`%Wash`) yok 8,97 / 9,11 · katman bölme yok 9,21 / 9,46 · yalnızca cephe çizgisi 8,78 / 9,05 ms. Örtü ≈ 0,3–0,5 ms, her karede yeniden çizim ≈ 0,1–0,4 ms.
- Dalga ≈ 0,5–1 ms ekliyor; 11,59 ms'lik ölçüm büyük olasılıkla ısınmaya bağlı bir sapma (aynı turda dalgasız ölçüm de 9,20 ms). Dalga sektör başına 1,2 sn sürdüğü için tasarım korundu; M3-19'da en yoğun sahneyle yeniden ölçülür (gerekirse örtü kaldırılıp eski katmanlar saydamlıkla söndürülür).

**Çöküş duvarı (M3-09, aynı sahne; duvar ekranın %75 yüksekliğinde, oyunun HUD'u ve vinyeti açık; iki ölçüm):**

| Mod | İlk sürüm (piksel başına özet, 240 px bant) | Sonuç (CPU'da dizi, 170 px bant, hızlı yol) |
| --- | --- | --- |
| Sahte parlama (duvarsız, tezgâhın kendi HUD'u) | 8,93 / 9,58 ms | 9,01 / 8,96 ms |
| Çöküş duvarı, orta kalite | 10,84 / 11,04 ms | 10,16 / 10,58 ms |
| Çöküş duvarı, yüksek kalite | 11,91 / 12,06 ms | 10,85 / 11,30 ms · GPU ≈ %99,7 |

- Parçalar (geçici deney kodu, commit edilmedi; taban: duvarsız, oyunun HUD'u yok, 8,63 / 8,97 ms): oyunun HUD'u (vinyetsiz) 9,89 / 9,75 → **HUD ≈ +1 ms** (M3-09'dan önce de oyunda vardı); + vinyet 10,53 / 10,26 → vinyet ≈ +0,5 ms; + duvar (yüksek) 10,94 / 11,05 → **duvar ≈ +0,5–0,8 ms**. Eski tam ekran vinyetin maliyeti ölçülmedi (≈ 8 kat alan).
- Ders: Adreno 610'da piksel başına özet (hash) pahalı. Sütun ve dilim değerlerini CPU'ya taşımak ve kenarın altını hızlı yoldan geçirmek ≈ 0,9 ms kazandırdı.
- **Tezgâhta duvar ekrandayken yüksek kalitede kare süresi 10,9–11,3 ms: 10 ms ölçütünün üstünde.** Bunun ≈ 1 ms'i HUD'dan, ≈ 0,5 ms'i vinyetten. Tezgâh oyundan yoğun (her yerde parlayan 14 diken, 8 blok, 20 Glimmer) ve duvar yalnızca ekrandayken maliyetli. M3-19 en yoğun gerçek sahneyi ölçer; ölçüt tutmazsa ilk bakılacak yer HUD'un ≈ 1 ms'i (M3-18), sonra duvarın varsayılan kalitesi.

**Parçacıklar (M3-11, aynı sahne; iki tur; GPU doluluğu adb kabuğundan):**

| Mod | 1. tur | 2. tur |
| --- | --- | --- |
| Parlama yok (düşük kalite, taban) | 8,36 ms (p95 9,30) · GPU %55 | 8,35 ms (p95 9,37) · GPU %75 |
| Parçacıklar, düşük kalite | 8,36 ms (p95 9,45) · GPU %78 | 8,35 ms (p95 9,29) · GPU %75 |
| Sahte parlama (yüksek kalite, taban) | 9,69 ms (p95 11,20) · GPU %99,8 | 9,28 ms (p95 10,25) · GPU %99,7 |
| Parçacıklar, yüksek kalite | 9,83 ms (p95 11,00) · GPU %99,8 | 10,56 ms (p95 12,71) · GPU %99,7 |

- Tezgâh patlamaları oyundakinden çok sık çıkarır (yedi yayıcı neredeyse sürekli dolu): en kötü durum. Yüksekte ≈ +0,1–1,3 ms; düşükte kare süresi tabanla aynı, GPU doluluğu birkaç puan üstünde. Oyunda iniş en çok ≈ 0,4 sn'de bir, Glimmer ve ölüm seyrek.
- Bu ölçümde tabanlar da önceki ölçümlerden biraz yüksek (sahte parlama 9,3–9,7 ms; M3-07'de 8,8–9,3): telefonun ısısı ya da arka plan yükü. Çöküş duvarı yüksekte 11,5–11,9 ms çıktı (M3-09'da 10,9–11,3). M3-19 en yoğun gerçek sahneyi ölçer.
- Ölümden yeni tura Redmi'de 369–380 ms (7 tur; M3-10'da 370–381): tur başında kurulan 7 yayıcı süreyi değiştirmedi.
- Redmi ekran görüntülerinde kıvılcım, Glimmer ve ölüm patlaması görünüyor; oyunda adb dokunuşundan 0,3 sn sonra alınan altı görüntünün altısında da iniş kıvılcımı var.

**Hız çizgileri (M3-13, aynı sahne; tezgâhın hız modu tavan hızda (22 m/sn) 24 çizgi akıtır, yüksek kalite: en kötü durum; iki tur):**

| Mod | 1. tur | 2. tur |
| --- | --- | --- |
| Parlama yok (düşük kalite, taban) | 8,36 ms | 8,35 ms |
| Sahte parlama (yüksek kalite, taban) | 8,50 ms | 9,31 ms |
| Hız çizgileri, yüksek kalite | 9,21 ms · GPU %99,5 | 10,39 ms |
| Parçacıklar, yüksek kalite (karşılaştırma) | 9,48 ms | 10,14 ms |

- Hız çizgileri yüksekte ≈ +0,7–1,1 ms (parçacıklarla aynı düzeyde). Oyunda S3'te yarısı kadar çizgi (12) var; düşükte %40'ı. M3-19 en yoğun gerçek sahneyi ölçer; ölçüt tutmazsa çizgi sayısının tavanı düşürülür.

**Oyunun içinde, en yoğun sahne (M3-19, 2026-10-20; ADR-064):** gerçek tur (`main.tscn`, debug yapısı), ölümsüz, S2'den başlayıp ≈ 72 sn'de S3'e geçiyor (S3: en hızlı sektör, en sık engel, 12 hız çizgisi). `--auto-tap=0.5` oyuncuyu 0,5 sn'de bir zıplatıyor: iniş kıvılcımı, kıl payı yazısı ve kombo, Glimmer. Kalite her evrede yüksek → orta → düşük (`PerfProbe`, §13). İlk ölçüm 6 sn'lik evrelerle ≈ 9 dk; sonrakiler 11 sn'lik evrelerle ≈ 100 sn (sektör girişindeki dalga yüksek kaliteli evreye düşsün diye). 120 Hz, dikey eşitleme açık. 20:9 ekranda çöküş duvarı S3'te hep ekranda, çoğunlukla yakın (yakınlık 0,4–1,0): en kötü durum. GPU doluluğu adb kabuğundan 0,1 sn'de bir. Telefon kabloda, pil %51–58, 32–34 °C.

| S3, kalite | Ort. kare süresi (evre aralığı) | En kötü p95 | ≈ FPS | GPU doluluğu |
| --- | --- | --- | --- | --- |
| Yüksek | 9,29 ms (9,12–9,70; 18 evre) | 13,1 ms | 108 | %98–99,4 |
| Orta | 8,47 ms (8,36–8,86; 17 evre) | 11,5 ms | 118 | %94–99,7 |
| Düşük | 8,36 ms (8,35–8,46; 16 evre) | 11,7 ms | 120 | %92–96 |
| Sektör girişi, yüksek (renk dalgası sürerken, 1,2 sn) | 9,8–10,8 ms (8 ölçüm) | — | 93–102 | — |

- **Ölçüt tutuyor:** yüksek kalitede en kötü evre 9,7 ms ≤ 10 ms. Yük GPU'da (düşükte GPU %92–96 ve tam 120 FPS). 120 Hz ek hedefinde yüksek ≈ 108 FPS, orta ≈ 118, düşük 120. Tezgâh notlarındaki önlemler (ağın uzak katmanını seyreltmek, HUD, duvarın varsayılan kalitesi, hız çizgisi tavanı) gerekmedi; HUD'un neon yazıları ayrıca ölçülmedi. p95'ler (11–13 ms) çoğunlukla tek tük kaçan dikey eşitleme: 120 Hz'de geciken kare 16,7 ms sürer.
- **Renk dalgası:** sürerken yüksekte 9,8–10,8 ms. Çöküş duvarı ne kadar yakınsa o kadar pahalı: duvar ekranda değilken 9,8, yakınlık 0,6–1,0'da 10,8 ms. En kötü durumda ölçütün ≈ 0,8 ms üstünde ama geçici (sektör başına bir kez 1,2 sn) ve 60 FPS'te kare kaçırmaz. Tasarım korundu; zayıf cihaz ölçümünde (M6-03) yeniden bakılır, önce örtü (`%Wash`, ≈ 0,3–0,5 ms, M3-08).
- **Afiş takılması (bulundu, düzeltildi):** beş ölçümün beşinde sektör girişinden ≈ 0,85 sn sonra, afişin belirdiği karede 28–35 ms'lik tek kare (120 Hz'de ≈ 3 kare). Takılma kaydı (`PERF spike`) zamanı verdi; önceki karenin çizimi normaldi (≈ 4,5 ms), süre işlem adımındaydı.
  - Neden: yeni sektör adının harfleri ilk kez çiziliyor ve her harf, her dış çizgi katmanı için ayrıca hazırlanıyor. PC denemesi (18 harflik afiş yeni bir boyutta, ilk kare): katmansız +1,6 ms, yalnızca kenar +2,5 ms, beş katman +6,2 ms.
  - Düzeltme: `NeonLabel.warm_glyphs` (§9). Sonra iki ölçümde sektör girişinde takılma yok. Açılıştan ilk tura geçen süre aynı aralıkta (önce 3,2–4,5 sn, sonra 3,2 sn).
- **Kalan takılmalar (açık, S-09):** ≈ 100 sn'de 0–2 kez, rastgele anlarda ve her kalitede 25–43 ms'lik tek kare. Süre çoğunlukla çizimin bitişiyle sonraki kare arasında (ekran takası, fizik); tekrarlanan bir oyun olayıyla çakışmadı, günlük okunmazken de oluyor. Uzun ilk ölçümün kayıtta kalan 44 evresinde (S3, ≈ 4,5 dk) hiç yoktu. M6-03'te zayıf cihazla ve profil aracıyla yeniden bakılır.
- **Yöntem notları:**
  - PERF satırları `logcat -v epoch` ile, GPU okumaları `date +%s.%N` damgasıyla zamanlanıp evrelere bölündü (birleştirme betiği proje dışında).
  - GPU okuyucusu iki kez koptu: adb sunucusu yeniden başladı. Biri yükleme sırasında, öbürü ölçümle aynı anda `check.ps1` çalışırken (ikisi de Godot'nun ekransız düzenleyicisini açar). Okuyucu yüklemeden sonra başlatılır; ölçüm sırasında `check.ps1` çalıştırılmaz.
  - Logcat arabelleği uzun ölçümde ilk evreleri siler; uzun ölçümde günlük ara ara alınır.
  - `command_line/extra_args`'lı yapıda açılışta bir kez `WARNING: Property not found: 'xr/shaders/enabled'` çıkıyor; normal yapıda çıkmıyor.

- Uygulama 120 Hz'de çalışıyor. Bu durumda bütçe 8,3 ms ve **en büyük yük GPU'da**: basit sahne bile 120 Hz'de GPU'nun %77'sini kullanıyor (≈ 6,4 ms).
  - M3-19 ve M6-03'te asıl ölçüt 60 FPS'te ≤ 10 ms'dir.
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
| ADR-028 | 2026-10-11 | Kilometre taşı kapısı istisnası (kullanıcı kararı, .clauderules §9): M1 kapısı beklenmeden M2'ye geçilir; M1 ve M2 birlikte M2-19'da kontrol edilir. M1 kapı soruları (iki başparmak sonucu S-07, ilk izlenim, P-04) oraya taşındı. Yalnızca M1→M2 için geçerlidir; sonraki kapılar aynen sürer | Kullanıcı hızlanmak ve iki aşamayı tek seferde denetlemek istedi. Risk: M1 hissiyle ilgili bir itiraz M2 işini etkileyebilir. Önlem: değerler TuningConfig'te; his değişikliği M2'yi bozmaz |
| ADR-029 | 2026-10-11 | Desen parçaları bütün olarak havuzlanır (parça başına kopya, en uzun ekrana göre); parçalar boşluksuz ve vuruş ızgarasında dizilir; kütüphane elle tutulan bir `ChunkLibrary` kaynağıdır; `Run.rng`'yi yalnızca `ChunkSpawner` çeker (M2-04) | Tehlike başına havuz, parçanın iç düzenini her seferinde yeniden kurmayı gerektirirdi. Elle liste, yayın sürümünde klasör taramanın güvenilmezliğinden kaçınır; testle klasörle eşit tutulur. Tek tüketicili RNG, haritayı ekran boyundan ve kare zamanlamasından bağımsız kılar |
| ADR-030 | 2026-10-11 | Parça doğrulama kare kare durum aramasıyla yapılır (geçiş fiziği Player'la aynı, tepki payı 0,2 sn); parça her giriş durumundan (yarım geçişler dahil) geçilebilmeli; tehlikeler kutu olarak alınır (M2-05) | Analitik "iki zorunlu çevirme arası" formülü havada geçişleri ve tehlike boylarını hesaba katamıyordu. Her giriş durumu kuralı birleşim yerlerini parça çiftlerini tek tek denemeden adil kılar. Tepki payı başlangıç değeridir; M2-18 oyun testinde gözden geçirilir |
| ADR-031 | 2026-10-11 | Ritim saati `Conductor` Run'ın içinde, sesi `AudioManager` çalar; `Conductor` her adımda oyun zamanını servis çağrısıyla bildirir. Ses, ortalama kayma 40 ms'yi aşınca ve ölçüde en fazla bir kez yeniden konumlanır (M2-07) | Autoload sahne düğümüne erişmeden saate uyar; müzik (M3) aynı yolu kullanır. Her karede konumlamak Android'de ses iş parçacığını yordu; ölçüm titremesi ortalamayla süzülür |
| ADR-032 | 2026-10-11 | Sektörler veri kaynağı (`SectorDef` + `SectorCatalog`); tırmanış hızı `TuningConfig`'ten sektöre taşındı. Sektör sınırları kesin yükseklikte; parça sınırı aşmaz, sığmayan kalan boş kalır. Başlangıç sektörü `Events.start_requested` ile seçilir, sonraki turlar aynı sektörden başlar (M2-08) | GDD'deki sektör tablosu tek yerde; doğrulayıcı ve oyun aynı değerleri okur. Kesin sınır yükseklikleri HUD'u, kontrol noktalarını ve testleri basit tutar; sınırdaki boşluk M2-09'daki "nefes alma" anının temelidir |
| ADR-033 | 2026-10-12 | Kullanıcıyla telefon üzerinden iki yönlü iletişim ntfy.sh ile (kullanıcı kararı). Bildirim yalnızca üç durumda: otonom çalışma bitti, kullanıcı olmadan çözülemeyen sorun, kullanıcı durdurdu. Kullanıcının yazdıkları her görev bitiminde okunur; otonom çalışma bitince arka planda bir dinleyici (`-Wait`) cevabı bekler. Konuya yazılan her mesaj kullanıcınındır (kullanıcı kararı: konu adı tahmin edilemez) | Kullanıcı ekrandan uzakken de haberdar olur ve cevap verebilir; gürültü olmasın diye bildirim seyrek. Acil durumda kullanıcı ekrana geçer. Remote Control şimdilik gerekmiyor (kullanıcı kararı). Konu herkese açık olduğu için bildirimlerde gizli bilgi olmaz |
| ADR-034 | 2026-10-12 | Duvar boşluğu parça öğesidir (`WallGap`); koridor parçaları boşluk kenarlarında tam bölünür (parça başına en fazla 3 parçacık, tur başında oluşturulur). Coyote süresi oyunda var, doğrulamada yok; düşme coyote dolunca koridor dışında olmaktır (M2-11) | Boşluk yerleri vuruş ızgarasına bağlı ve rastgele uzunlukta; sabit küçük duvar parçaları kenarları ±50 px kaydırırdı. Doğrulamanın daha sıkı olması parçaların affedici süreye dayanmamasını sağlar |
| ADR-035 | 2026-10-12 | Lazer duvara bağlı bir ışındır (koridoru tamamen kesmez) ve açık penceresi vuruşa ortalıdır (çeyrek vuruş önce/sonra); iki duvardan kısa ışınlar "lazer kapısı" olur. Veri bloğu sabittir (süzülme görseli M3'te). Vuruş Run'dan aşağı çağrıyla gelir (M2-12) | Sabit tırmanış hızında geçiş anı oyuncunun elinde değil: tam koridorluk ışın ya hep ölümcül ya hep zararsız olurdu; tam vuruşta açılıp kapanan ışın da ızgarada her evrede tehlikeli çıkıyordu (test). Ortalı pencere geçişi ya tamamen açık ya tamamen kapalı yapar, aldatıcı ışın ve zamanlamalı kapı mümkün olur. GDD'deki "vuruşa göre açılıp kapanan yatay lazer" tanımının uygulanış biçimidir |
| ADR-036 | 2026-10-13 | Dokunma tamponu 0,12 sn'den 0,45 sn'ye çıktı: geçişten (≈ 0,37 sn) uzun olduğu için havadaki her dokunuş inişte uygulanır (kullanıcı geri bildirimi: hızlı çift dokunuş algılanmıyordu; karar kullanıcının inisiyatifiyle Claude'a bırakıldı) | İkinci dokunuş geçişin başında geldiğinde atılıyordu. Saklanan çevirme oyunu yalnızca daha affedici yapar; doğrulayıcının insan modeli (iniş + 0,2 sn tepki payı) değişmez, parçalar yine onunla denetlenir |
| ADR-037 | 2026-10-13 | Lisans kuralına (`.clauderules` §7) **sözleşmeli ısmarlama eser** eklendi (kullanıcı onayı, D-02): bir besteciye ya da sanatçıya özel yaptırılan iş, hakları ya da süresiz, dünya çapında; oyunu, fragmanları ve müzik albümünü kapsayan kullanım iznini yazılı sözleşmeyle veriyorsa kullanılır. `CREDITS.md`'ye sözleşme tarihiyle yazılır | Bütçesiz yolda gönüllü ya da gelir ortaklığıyla çalışan besteci seçeneğini açık tutar (D-02, `docs/music_research.md` §9). Sözleşmesiz ya da lisansı belirsiz iş yine yasak |
| ADR-038 | 2026-10-13 | Müzik kaynağı **ücretsiz kütüphaneler**: yalnızca CC0 ve CC-BY parçalar (kullanıcı kararı, D-02). Oyunla özdeşleşecek bir **ana tema** parçası menüde ve S1'de çalar; sonraki sektörler aynı tarzda, tercihen aynı besteciden parçalar çalar. Sektör BPM'leri (`SectorDef.bpm`) seçilen parçalara göre ayarlanır; parça doğrulayıcısı yeni BPM'lerle yeniden dener. Adaylar M3-10'da listelenir, kullanıcı dinleyip seçer | Bütçe yok. Ödün bilerek kabul edildi: kütüphane parçası başka oyunlarda da çalabilir (müzik bize özel olmaz). Bu yüzden çok yaygın parçalar yerine az bilinenler tercih edilir. Kodla üretilen ana tema denemesi (`tools/theme_demo.py`) kaldırıldı. **Aynı gün inceltildi:** ADR-039 (insan yapımı hibrit orkestral, yapay zekâ yedek) |
| ADR-039 | 2026-10-13 | D-02 kesinleşti (kullanıcı kararı): müzik **insan yapımı**, ücretsiz kütüphanelerden (yalnızca CC0 / CC-BY), **hibrit orkestral** (orkestra + net davul ritmi). Yapay zekâ (Stable Audio 3) yalnızca uygun parça bulunamazsa yedek; lisans kuralı değişmedi. Adaylar ölçülerek seçilir: tempo kesinliği ve 8 sn pencerelerin vuruş ızgarasından sapması (`docs/music_research.md` §12) | Kullanıcı akıcı, gerçek orkestral bir his istiyor. İnsan elinden çıkan orkestral parçanın kalitesi belli, hukuku oturmuş ve yapay zekâya karşı oyuncu tepkisi riski taşımıyor. Engeller vuruşa oturduğu için sabit tempolu, davullu parçalar şart; serbest tempolu klasik orkestral parçalar elenir |
| ADR-040 | 2026-10-13 | **Müzik her turda rastgele, tempo parçanın** (kullanıcı kararı): beş parçanın (ADR-039) hepsi oyunda; tur, tohumundan seçilen parçayı çalar (`MusicCatalog.pick`). Turun temposu parçanın temposudur ve tur boyunca değişmez; `SectorDef.bpm` kaldırıldı, hız sektörde kaldı. Vuruş ızgarası turun başından kesintisiz sürer, müzik sektör geçişinde kesilmez; yeni sektörün ilk parçası müziğin vuruşuna hizalanır, `Run` sınırda oyuncunun konumunu düzeltir. Parçalar `tools/music_prep.py` ile ilk vuruşa kırpılır, döngü tam ölçüye kesilir. Doğrulayıcı her parçayı her tempoda dener. Metronom kaldırıldı | Kullanıcı "her oyunda rastgele çalsın" dedi ve üç seçenekten (tempo parçadan / müzik serbest / sektöre uyanlar) "dünya müzikle akar"ı koruyanı seçti. Bedeli bilerek kabul edildi: tur zorluğu parçaya göre değişir (80 BPM'de engeller seyrek, 120'de sık) ve sektörlerde tempo artmaz. Seçim tohumdan geldiği için günlük meydan okumada herkes aynı parçayı çalar |
| ADR-041 | 2026-10-13 | M2 Planlama Gözden Geçirmesi: M3 20 atomik göreve bölündü (neon altyapısı → varlık görselleri → dünya ve geçişler → oyun hissi → ses → font ve renk → performans → kapı). Görünüş veriyle kurulur (palet, bileşen, shader değerleri). Kullanıcı kararı isteyen işler sona toplandı (M3-17 font ve kesin renkler, M3-20 oyun testi); 🤖 görevler arada durmadan ilerler. Eski "müzik inceltmesi" görevi kalktı: kulak testi geçti (S-03 ✅), geriye duvar yaklaşınca müziğin boğuklaşması kaldı (M3-16) | Kullanıcı görünüş ve hikâye yeniden yapılandırmasını plan sonuna bıraktı; veriyle kurulan görünüş o işte kodun yeniden yazılmasını önler. Renkler veri olduğu için sonradan seçilmeleri yeniden iş çıkarmaz, kullanıcı da seçimi bitmiş görsellerin üstünde yapar |
| ADR-042 | 2026-10-13 | D-05 kararı (kullanıcı): ses efektleri insan yapımı, ücretsiz kütüphanelerden gelir: Kenney ses paketleri (CC0), gerekirse Freesound (yalnızca CC0 / CC-BY filtresiyle). Claude adayları seçip ölçer (süre, ses düzeyi), kullanıcı oyunda dinler. gdfxr ve kodla sentez kullanılmaz. Aynı kapıda M1 + M2 onaylandı, P-04 kapandı (M2-19) | Müzikle aynı yol (ADR-039): orkestral müzikle uyumlu, profesyonel ses. Kenney'in CC0 lisansı en temiz seçenek. sfxr'ın 8-bit sesleri orkestral müzikle çatışabilir; kodla sentez müzik denemesinde yapay duyulmuştu |
| ADR-043 | 2026-10-13 | Neon görseller ortak bileşenlerle çizilir: `NeonLine` ve `NeonShape` (`scripts/components/`), ortak durum `Neon` (autoload değil, statik `quality`), değerler `data/visual/neon_style.tres` (`NeonStyle`, yeni klasör `data/visual/`). Efekt kalitesi katman sayısını belirler: yüksek 2, orta 1, düşük 0 (ışık lekesi yalnızca düşükte yok). Kaliteyi `Main` ayardan aktarır | Her varlık (duvar, oyuncu, tehlike, Glimmer) aynı tekniği kullanacak (M3-03…M3-06); tek yerde durması görünüşü veriyle değiştirilebilir kılar (ADR-041). Autoload'a bağlı olmaması parça doğrulayıcının ekransız derlemesini korur. Redmi'de kare süresi değişmedi (§16.1) |
| ADR-044 | 2026-10-13 | Sektör renkleri `SectorPalette` kaynağında (`ambient`, `accent`, `background`; `data/sectors/palette_NN.tres`), `SectorDef.ambient_color` ve `Corridor.set_tint` kalktı. Tehlike, Glimmer ve oyuncu renkleri sektörden bağımsız, `NeonStyle`'da. Arka plan ekranın temizleme rengiyle boyanır; geçişi `Run` yapar (0,6 sn) | Renkler veri olunca M3-17'deki kesin seçim kod değiştirmez (ADR-041). Renk kuralı (kırmızı ve yeşil çevre rengi olamaz, GDD §12) testle korunur. Temizleme rengi tam ekran bir çizimden ucuzdur; arka plan ağı (M3-07) bunun üstüne çizilir |
| ADR-045 | 2026-10-13 | Çalışma modeli (kullanıcı kararı): iki mesai türü. **Standart mesai:** kullanıcı ekran başında ya da yakınında, birlikte çalışılır; Claude 🤝/👤 görevde, bekleyen kararda, kapıda ve beklenmedik tasarım sorusunda durur (ADR-025 gibi). **Otonom mesai:** Claude baştan sona tek başına çalışır; yalnızca 🤖 görevleri yapar, 🤝/👤 görevleri ve karar bekleyenleri atlayıp `state.json` → `standard_queue`'ya yazar. Küçük, geri alınabilir tasarım sorularında varsayım seçilip kuyruğa "gözden geçir" notu düşülür; büyükler `pending_user_decisions`'a yazılır. Kilometre taşı kapısı geçilmez. Tür `state.json` → `session`'da; kullanıcı söylemezse standart. Telefon bildirimi (ADR-033) otonom mesainin sonunda gönderilir. `current.deferred` kuyruğa katıldı | Kullanıcı otonom mesailerde başka projelerle ilgileniyor; Claude'un bir 🤝 görevde saatlerce beklemesi yerine yapılabilecek işi sürdürmesi zaman kazandırır. Kapı ve görev başına kanıt korunduğu için kalite düşmez; ortak işler biriktirilip standart mesaide topluca yapılır |
| ADR-046 | 2026-10-13 | Neon koridor (M3-03): duvar parçacığı başına bir `NeonLine` (iç kenar; boşluk kenarında duvar kalınlığı boyunca dönen kesik) + saydam dolgu. Vuruş nabzı koridorun tek `modulate`'i ile, vurgu rengine doğru; güç eğrisi `NeonStyle.beat_pulse` (arka plan ağı da kullanacak). `Corridor.set_ambient` yerine `set_colors(çevre, vurgu)` | Düğümler tur başında kurulu kalır (.clauderules §6); nabız her adımda yalnızca bir özellik yazar, yüzlerce çizgiye dokunmaz. Kesik ve çizgi çarpışma kutusuyla aynı veriden üretilir, testle aynı yerde olduğu denetlenir. Nabız gücü veride; oyun testinde (M3-20) ayarlanabilir |
| ADR-047 | 2026-10-13 | Oyuncu görseli (M3-04): çekirdek `NeonShape`, kalkan halkası `NeonLine`, iz `Trail` (`NeonLine`'dan türer, oyuncunun çocuğu). İz konumları fizik adımında kaydedilir; baş ve kuyruk fizik ara değerleme kesriyle kaydırılarak `_process`'te çizilir. Süre ve kalınlık `NeonStyle`'da (kozmetik `TrailDef` M4'te) | Konum fizik adımında (60 Hz sabit) kaydedildiği için iz yenileme hızından bağımsız; kesirle kayan baş, iz başını ara değerlenen oyuncunun tam üstünde tutar, kayan kuyruk 120 Hz'de boy sıçramasını önler. Ayrı bir düğüm ya da `top_level` gerekmez; çizim sırası sahnede kalır |
| ADR-048 | 2026-10-13 | Sabit renkli neon şekiller rengi `NeonShape.tone` ile `NeonStyle`'dan alır (`GameTypes.NeonTone`); tehlikeler sivri köşeli (`sharp`). Veri bloğu betikli (`Block`): veri satırları ve vuruşla süzülme yalnızca `Visual`'da, çarpışma kutusu sabit. Vuruş `ChunkInfo.set_beat` zincirinden. Görsel inceleme için debug varlık galerisi | Renk tek yerde (M3-17'de yalnızca `neon_style.tres` değişir) ve sahnede kod gerekmez. Süzülme görsel kaldığı için doğrulayıcı ve çarpışma aynı (ADR-035); 4 px'lik sapma okunuşu bozmaz. Galeri, nadir çıkan parçaları beklemeden telefonda kanıt almayı sağlar |
| ADR-049 | 2026-10-13 | Lazerin üç görünüşü (yanık bıçak + beyaz çekirdek + sivri uç, sönük ray, yanmadan 0,25 vuruş önce rayın kalınlaşıp parladığı uyarı) `Laser.set_beat`'te çarpışmayla aynı adımda değişir; sivri uç parlamasız ayrı üçgen. Glimmer yeşil `NeonShape` daire, vuruşta büyür. `NeonLine` de `tone` alır. Değerler `NeonStyle`'da | Oyuncu ışının ne zaman yanacağını görmeli (GDD §6); uyarı sönük hâlde kaldığı için tehlikeli görünmez, görüntü çarpışmadan ayrılmaz (test). Kutudan taşan uç görüntüyü kutudan büyük tutar (adil yön). Gri ton denetimi şekil dilini doğruladı |
| ADR-050 | 2026-10-14 | Arka plan veri ağı shader değil çizgi geometrisi: `Background` (`CanvasLayer -1`) iki katman (uzak 100 px / paralaks 0,12, yakın 300 px / 0,3 + düğümler) bir kez çizilir; renk `self_modulate`, nabız `modulate`, kayma konumla (bir hücrelik sarılma + satır sayacı); her vuruşta düğümlerin %12'si parlar. Yüksek iki katman, orta yakın katman, düşük düz renk. Debug: 9 tuşu / "Kalite" düğmesi ve `--quality=` | Tam ekran shader Redmi'de kareyi 8,4 → 13,5–13,9 ms çıkardı (GPU %99,8); çizgiler 8,8–9,3 ms (≤ 10 ms). Görünüş aynı, yalnızca yöntem değişti (görev "shader" diyordu). Ders: tam ekran shader yok (§9) |
| ADR-051 | 2026-10-14 | Sektör geçişinde renk dalgası: cephe 1,2 sn'de ekranın altından üstüne yürür (`NeonStyle.wave_*`). Arka plan: cephenin üstünü eski arka plan rengi örter, her ağ katmanının yeni paletli eşi cephenin altını çizer, cephede vurgu çizgisi + (orta ve üstü) çevre renginde ışık bandı. Duvarlar parça parça 400 px'lik yumuşak geçişle, iz oyuncunun y'sine göre. Afiş dalga kendi yüksekliğine gelince %125'ten belirir. 0,6 sn'lik tween kaldırıldı | GDD §12'deki "dalga" hissi. Tek palet geçişi tüm ekranı birden değiştiriyordu. Shader yok (ADR-050 dersi): örtü + çizgi eşleri. Redmi'de en kötü durumda (art arda dalga) ≈ 0,5–1 ms; oyunda sektör başına 1,2 sn, ölçüt (60 FPS'te ≤ 10 ms) tutuyor; M3-19'da yeniden ölçülür |
| ADR-052 | 2026-10-14 | Çöküş duvarının kesin görseli: kenarın çevresindeki 170 px'lik bantta glitch shader'ı (orta ve üstü; yüksekte renk kayması), düşük kalitede aynı kırık kenarın çizgisi; dolgu opak. Sütun yükseklikleri ve kayan dilimler vuruş başına 4 adımda CPU'da hesaplanıp uniform dizisiyle verilir. Kırık kenar öldürme çizgisinin altına inmez. Vinyet tam ekrandan koridorun dışındaki iki yan şeride indirildi (dış %8, × 1,0) | GDD §14'teki glitch'li yok oluş; M3-07 dersi: tam ekran shader yok. Piksel başına özet Adreno 610'da ≈ 0,9 ms pahalıydı. Kenar yalnızca öldürme çizgisinin üstüne çıkar: duvar olduğundan yakın görünebilir, uzak görünmez (adalet). Eski vinyet koridorun kenarlarını kızartıyordu. Redmi tezgâhında duvar ekrandayken ≈ +0,5–0,8 ms; tezgâh toplamı 10 ms'nin üstünde (HUD ≈ 1 ms), M3-19'da gerçek sahnede ölçülür |
| ADR-053 | 2026-10-14 | Ekran sarsıntısı `GameCamera`'da travma modeliyle (travma² × döngüsel düğüm gürültüsü), **yalnızca yatay**; ölümde dünya `death_freeze` (0,1 sn) boyunca `Run` içinde donar (`Engine.time_scale` değil), ardından `death_trauma` (0,8) sarsıntı; kalkan kırılınca 0,5. Değerler `TuningConfig` → Oyun hissi | Dikey sarsıntı oyuncunun üstündeki görüş mesafesini oynatırdı (kabul ölçütü, §3). Yerel donma müziği ve UI'yi durdurmaz, saat oranı (müzik `pitch_scale`) değişmez; Main'in yeniden başlama beklemesinin içinde kaldığı için turu uzatmaz. `FastNoiseLite` tek boyutta sönük ve t = 0'da sıfırdı |
| ADR-054 | 2026-10-14 | Desen parçası havuzları turlar arasında korunur: `Main`'in çocuğu `ChunkPools` (`z_index` −1; `Corridor` −2), her `Run` havuzları ödünç alır, tur bitince etkin parçalar geri döner. `NeonShape` yalnızca seçilen parlama türünün düğümlerini kurar. ADR-029'un "tur başında kopya" kısmının yerini alır | Tur başında 130 kopya / 3552 düğüm kurmak Redmi'de ölümden yeni tura süreyi 516–526 ms'ye çıkarmıştı (ölçüt < 500 ms); korununca 370–381 ms. Taşımak yeniden kurmak kadar pahalı, kopyaları tekrar yasağına göre kısmak güvensiz (§8.7). İçerik büyüdükçe tur başı maliyeti artık büyümez |
| ADR-055 | 2026-10-14 | Oyun hissi efektleri yalnızca görseldir: sıkışma-uzama `Visual`'ın ölçeğinde (kapalı biçimli sönümlü yay, `SquashStretch`); parçacıklar `Run` içindeki `Effects`'te, tür başına tur başında kurulan `CPUParticles2D` halkasıyla (dünya koordinatlı, tek seferlik). Glimmer'ın yeri yerel sinyalle gelir (`Events` imzası değişmez). Ölüm patlaması donmanın sonunda, çekirdek o anda gizlenir. Görünüş `NeonStyle` → `BurstStyle` | Çarpışma şekline dokunmamak adaleti korur. Kapalı biçim 60 / 120 Hz'de aynı sonucu verir. Halka tur sırasında düğüm oluşturmaz (ölçüt), dünya koordinatı patlamayı sahnede bırakır. Tur başında 7 yayıcı kurmak ucuz (Redmi'de ölümden yeni tura 369–380 ms, M3-10'da 370–381); turlar arası havuz (ADR-054) gerekmedi. Redmi'de sürekli patlamada yüksekte ≈ +0,1–1,3 ms, düşükte maliyet görülmedi |
| ADR-056 | 2026-10-14 | Kıl payı yavaş çekimi `Engine.time_scale` ile bütün oyunu yavaşlatır (`SlowMotion`, `Run` içinde); süre gerçek zamanla (fizik adımı sayısıyla) sayılır, sonunda yumuşak dönüş. Yalnızca zincirin ilk halkasında ve çarpanın büyüdüğü halkada. Taban, başladığı andaki ölçektir. Ölümde ve tur kaldırılınca hemen geri verilir. `Events.near_miss`'e çarpan eklendi; HUD canlandırmaları zaman ölçeğini yok sayar | Tek ölçek, müziğin aynı oranda yavaşlaması kuralını (ADR-008) bedavaya sağlar; oynanış `delta` ile ilerlediği için harita değişmez (test). Gerçek zamanlı süre, 0,5× ölçekte de 0,25 sn'yi korur. Her kıl payında yavaşlamak yorucu olurdu (GDD §15). HUD eşikleri bilmesin diye çarpanı sinyalden alır. Redmi'de 25 yavaş çekimde yeniden hizalama yok, kayma ≤ 35 ms |
| ADR-057 | 2026-10-14 | Hız hissi yalnızca görseldir ve sektörün tırmanış hızından türetilir (`NeonStyle.speed_feel`: 12 m/sn 0, 22 m/sn 1): hız çizgileri (`SpeedLines`, `Background`'ın çocuğu, sabit dizilerde tek doku ile `_draw`) ve iz süresinin çarpanı (`Trail.stretch`, kayıtlar korunarak). Sektör geçişinde his yavaşça değişir, yeni çizgiler üstten girer | Hız tavanı ve tepki süreleri (GDD §13) oyunu gerçekte hızlandırmaya izin vermiyor; his görselden gelmeli. `CPUParticles2D` yerine çizim: tek düğüm, en çok 24 doku çizimi, tur sırasında ayırma yok; kalite oranı parçacıklarınkiyle aynı. Ani geçişte yeni çizgiler ekranın ortasında belirir, iz sıfırlanıp yeniden uzardı. Redmi'de en kötü durumda ≈ +0,7–1,1 ms |
| ADR-058 | 2026-10-14 | Rekor çizgisi dünyada bir `NeonLine` (`RecordLine`, `Run`'ın çocuğu, koridorun hemen üstünde, tehlikelerin altında); oturum rekoru `GameManager.best_height_m`, `Main` her tura `Run.record_height` olarak verir; çizginin yeri HUD yüksekliğiyle aynı hesap. Sahne denetimine dünya ↔ UI katman kuralı eklendi | Dünya UI'yı tanımaz (§3); rekoru tur dışından almak tohum ve başlangıç sektörüyle aynı yol, `Run` testte tek başına kurulabiliyor. Çizgi tehlikeyi örtmemeli (adalet). Kabul ölçütü "dünya HUD'a erişmiyor" önceden yalnızca dolaylı denetleniyordu (sahne dışı ad bulunamaz); `/root/` yolu ve dosya yükleme gözden kaçabiliyordu |
| ADR-059 | 2026-10-15 | Oyunun fontu Exo 2 kalın (kullanıcı kararı; adaylar Chakra Petch, Audiowide ve Godot'nun varsayılanı, Redmi ekran görüntüleriyle). Değişken font tek dosyada, kalın kesim bir `FontVariation`; proje ayarı `gui/theme/custom_font` onu gösterir. Kesin sektör renkleri "elektrik" paleti (kullanıcı kararı; şimdiki / elektrik / gece arasından): daha doygun çevre, daha koyu zemin, S3 turuncuya kaydı. Ekranın temizleme rengi S1 zemini | Okunaklı, küçük boyutta net; Audiowide'ın rakamları süslü. Proje fontu her ekranı (ileride menüler) kendiliğinden kapsar, sahnelerde atama gerekmez. Değişken font HUD stili (M3-18) başka ağırlık isterse yeni dosya gerektirmez. S3'ün eski kehribarı sarı rekor çizgisiyle karışıyordu |
| ADR-060 | 2026-10-15 | itch.io sayfası herkese açık ve şifresiz (kullanıcı kararı, M1-13; ADR-027'deki şifreli "Restricted" sayfanın yerine): https://burak-sisci.itch.io/gravity-hopper. Yüklenen zip yayın çıktısı | Kullanıcı kararı (yükleme sırasında). Link şifresiz paylaşılıyor; yayın çıktısında debug özellikleri yok. Görünürlük itch.io'da istenince geri alınabilir |
| ADR-061 | 2026-10-15 | Ses efektleri: olay → ses eşlemesi veride (`SfxBank` + `SfxSound`, `data/audio/sfx_bank.tres`), Kenney CC0 dosyaları değiştirilmeden; ses düzeyi `volume_db`'de, `tools/sfx_prep.py` müziğe göre ölçer (telefon bandı, kademeler). `AudioManager`'da açılışta kurulan 8 çalarlık havuz; boş yoksa bitmesine en az kalan kesilir; doluluk gerçek zamanla. Efektler `Engine.time_scale`'i izlemez. Yeni sinyaller `player_landed`, `record_broken` | Ses seçimi kod değiştirmeden yenilenir; dosyayı yeniden kodlamamak kaliteyi korur. Telefon hoparlörü 250 Hz altını vermediği için tam bant ölçüm alçak sesli efektleri yanıltıcı biçimde yüksek gösterirdi. Tur sırasında düğüm yok (.clauderules §6); `playing` bayrağı `play()`'den hemen sonra güvenilmez (M2-07 dersi). Yavaşlayan efekt sesi kıl payı anını boğuk yapardı; kural yalnızca müziğin senkronu içindir |
| ADR-062 | 2026-10-20 | Gerilim: çöküş duvarı yaklaştıkça `Music` yolundaki alçak geçiren süzgeç kapanır (12 000 → 700 Hz, logaritmik) ve döngülü gerilim sesi (Kenney `computerNoise_000`, dikişsiz döngüye çevrildi) yükselir; değerler `TensionMix`'te (`data/audio/tension_mix.tres`). `AudioManager` yakınlığı `Events`'ten dinler ve `_process`'te yumuşakça yetişir; yakınlık 0'da süzgeç kapalı, ses durmuş. Tur başı ve ölüm hemen sıfırlar | Süzgeç müziği kaybetmeden "tehlike yaklaşıyor" hissi verir; müziğin enerjisi alçak orta bantta olduğu için telefonda düzey yalnızca 2–3 dB düşer. Gerilim sesi telefon bandında seçildi (motor sesleri 250 Hz altında kalıyordu). Tek döngü dosyası ve bir süzgeç: tur sırasında düğüm yok, işlemci yükü yalnızca duvar ekrandayken. Yumuşak geçiş, kalkan kırılmasındaki ani yaklaşmada tıkırtıyı önler |
| ADR-063 | 2026-10-20 | HUD yazıları neon: `NeonLabel` (`scripts/components/`, `Label`'dan türer) tek bir `LabelSettings` kurar: parlama renginin beyaza çekilmiş çekirdeği, renkli kenar ve kaliteye göre üst üste sönen dış çizgiler (yüksekte 5, ortada 2, düşükte yok). Kalınlıklar yazı boyutunun oranı, değerler `NeonStyle` → HUD yazıları. Renkler: yükseklik, kıl payı ve afiş sektörün vurgusu; rekor satırı `record_color` (`NeonTone.RECORD`); Glimmer ve kombo Glimmer yeşili | Harf biçimli parlama ek düğüm, doku ya da shader istemez; yalnızca glif geçişleri artar (HUD'da birkaç düzine glif). İnce ve çok katman, sert kenarlı dış çizgilerle yumuşak bir sönüm verir. Koyu ayırıcı (parlamanın altında gölge) denendi: parlamayı çamurlu kahverengiye çeviriyordu; kenar ve parlama parlak duvar çizgisinin üstünde de yazıyı okutuyor |
| ADR-064 | 2026-10-20 | Performans oyunun içinde ölçülür: `PerfProbe` (debug, `-- --perf=<sn>`, `--auto-tap`) gerçek turda efekt kalitesini evre evre döndürür; kare süresini (ortalama, p95, en kötü), duvar ve dalga karelerini ve takılmaları (25 ms üstü kare, zamanıyla) günlüğe yazar. Telefonda argüman geçici `command_line/extra_args` ile verilir. M3-19 sonucu: S3'te yüksek kalite 9,1–9,7 ms, ölçüt tutuyor; varsayılan kalite yüksek kalır. Neon yazılar gösterebilecekleri harfleri önceden çizer (`NeonLabel.warm_glyphs`: saydam iç kopya bir kez çizilip gizlenir, kalınlıklar değişince yeniden) | Tezgâh efektleri oyundakinden farklı sıklıkta yürütür; en yoğun gerçek sahneyi yalnızca gerçek tur verir. Yeni bir harf her dış çizgi katmanı için ayrıca hazırlanıyor: sektör afişi yeni sektör adıyla Redmi'de 28–35 ms takıldı (beş ölçümün beşinde). Isıtmadan sonra sektör girişinde takılma yok, açılış süresi değişmedi. Harfler yazının kendi tuvalinde hazırlandığı için önbellek her cihazın ölçeğine uyar; içe aktarmada önceden hazırlamak ölçeği farklı cihazda boşa giderdi |
| ADR-065 | 2026-10-20 | **Müzik özgün** (kullanıcı isteği, 2026-10-20: "arka plan müziği yeterince akıcı değil… sen kendin Age of Empires'takine benzer bir müzik üret… onay istemene gerek yok"): eski beş parça (ADR-039, ADR-040) kalktı; Claude üç parça besteledi (Kervan, Pagoda, Kale: üç uygarlık rengi) ve `tools/music/` ile gerçek enstrüman kayıtlarından (VCSL, VSCO 2 CE; CC0) seslendirdi. ADR-039'un "insan yapımı" koşulunun yerini alır; "kodla yazılmış tekdüze müzik olmasın" isteği gerçek kayıtlar ve elle yazılmış beste ile karşılanır. Stable Audio 3 seçilmedi: model erişimi kullanıcının hesabıyla lisans onayı istiyor. Tur yine parçayı tohumdan seçer ve tempo parçanın (ADR-040 sürüyor). |
| ADR-066 | 2026-10-21 | **M4 15 atomik göreve bölündü** (M3 Planlama Gözden Geçirmesi; roadmap). Menüler M5'te kalır; M4'teki ilerleme debug panelinin **İlerleme** sayfasıyla denenir (yalnızca debug yapısı). Oynanış yükseltmelerinin etkileri tur başında `Run`'a tek bir yükleme olarak verilir ve haritayı değiştirmez. İkinci Şans dirilişi sonuç ekranı gelene kadar kendiliğinden olur (M5-03'te düğmeye bağlanır). M3'ün "gözden geçir" notları (M3-04 … M3-14) kullanıcının M3-20 onayıyla ("denemeler başarılı") kabul sayıldı | Ekranlar M5'in işi: mantık önce testle ve panelle doğrulanır, ekranlar sonra hazır mantığın üstüne kurulur. Tek yükleme günlük meydan okumayı (M7-03, yükseltmesiz) ve belirlenimciliği korur. Kendiliğinden diriliş, düğme gelene kadar M4-15 oyun testinde denenebilsin diye |
| ADR-067 | 2026-10-21 | Kayıt (M4-01): `SaveManager` atomik yazar (`.tmp` → geri okuma → sağlam `.dat` → `.bak` → `.tmp` → `.dat`), bozuk ana kaydı yedeğe geçirmez; her yüklemede kaydı şablona uydurur (eksik / yanlış türde alan varsayılandan, bilinmeyen alan düşer), bu yüzden alan eklemek sürüm gerektirmez; sürüm geçişi adım adım (`migrate`). Şifreli dosya imzasıyla (`GDEC`) önceden denetlenir. Debug yapısında düz JSON (`savegame_debug.json`) | Yazma yarıda kesilse de bozuk bir kayıt iyi yedeği ezse de oyuncu ilerlemesini kaybetmesin. Şablona uydurma, şema yayına kadar değişirken sürüm sayısını büyütmeden eski kayıtları açar. İmza denetimi, motorun bozuk dosyada yazdırdığı hatayı önler |
| ADR-068 | 2026-10-21 | Kalıcı ilerleme (M4-02): `GameManager` tur sonunda `Progression.finish_run(sonuç)`'u `run_ended`'den önce çağırır; kazanç = toplanan Glimmer + sektör bonusu (`TuningConfig.sector_bonus` × geçilen her sektörün numarası, başlangıç sektöründen ulaşılanın bir öncesine), sonuç `RunResult`'a yazılır (`start_sector`, `sector_bonus`, `earned`, `new_record`, `best_height_m`). Oturum rekoru (`GameManager.best_height_m`) kalktı; rekor `Progression`'da kalıcı. UI kalıcı değerleri autoload'dan okumaz: `GameManager.begin_run` → `Progression.announce()` (`glimmers_changed`, yeni `best_height_changed`). Arka plan / kapanış / geri tuşunda yalnızca kaydedilmemiş değişiklik yazılır. Testler `SaveManager`'ın test klasörüne geçmesiyle gerçek kayda dokunmaz | Kayıt `run_ended` dinleyicilerinden önce diskte olsun ve sonuç ekranı (M5) kazancı hazır bulsun; sinyal dinleyicilerinin sırasına bağlı kalınmasın. Arayüzün ilk değeri her tur başında duyurulduğu için yeni açılan bir ekran da (M5) aynı yolla değer alır. Test klasörü geçişi, her test dosyasının kendi korumasını unutmasına karşı tek yerde çözüm |
| ADR-069 | 2026-10-21 | Yükseltme verisi (M4-03): beş `UpgradeDef` + `UpgradeCatalog` (`data/upgrades/`); fiyatlar açık dizi (GDD formülü testle denetlenir), etkiler dünya biriminde (Mıknatıs m, Kalkan Sv1 = 0 yenilenmez). `Progression.buy_upgrade` alınca hemen kaydeder. Satın alma M5'e kadar debug İlerleme sayfasından (`ProgressPanel`, kodla kurulan ayrı panel, `0` tuşu; `8` Kalkan ver'de kaldı) | Fiyatlar M4-14 ekonomi benzetiminde tek tek ayarlanabilsin, formülden sapma testte görünür olsun. Etkiyi tüketen kod (M4-04 – M4-07) birim çevirmeden kullansın. Satın alma, uygulama kapanmadan önce kayıtlı olsun. Ayrı panel, ayar panelinin otomatik kaydırıcı düzenini bozmaz |
| ADR-070 | 2026-10-21 | Mıknatıs ve Glimmer Çarpanı (M4-04): tur başında `Progression.loadout()` → `RunLoadout`, tur boyunca sabit. `Magnet` düğüm değil `RefCounted`; uzaklık karşılaştırması, menzil toplama alanının **ötesine** eklenir (Sv1 183 px, Sv5 343 px), yakalanan Glimmer hızlanarak oyuncuya akar ve bırakılmaz; oyuncunun yeri `Run → ChunkSpawner → ChunkInfo → Glimmer` zinciriyle aşağı verilir. Çarpan, kazancın tamamına (Glimmer + sektör bonusu) `roundi` ile. `tools/phone_frames.py` telefondan kare dizisi | GDD'nin 90 px'i bugünkü toplama mesafesinden (93 px) kısa, Sv1 boşa giderdi. Düğümsüz çözüm havuzu, katman/maskeleri ve düğüm sayısını değiştirmez; harita aynı tohumda aynı kalır. "Glimmer kazancı" oyuncu gözünde tur sonu ekranındaki toplamdır. Hareketin telefonda görülmesi için ekran görüntüsü yetmiyordu; ffmpeg kurmadan ham kareler okunur. Kullanıcı gözden geçirecek (`standard_queue`) |
| ADR-071 | 2026-10-21 | Kalkan yükseltmesi (M4-05): her seviye turu kalkanla başlatır (`RunLoadout.start_shield`); Sv2–5'te kırılan kalkan, **kırıldığı yerden** yenilenme mesafesi tırmanılınca geri gelir (`Run` y'yi not eder, `Player.give_shield()` aşağı çağrı). Yeni sinyal ya da düğüm yok; günlükte mevcut `shield_changed` | GDD'nin "kırılan kalkan … m sonra yenilenir" tanımına en yakın okuma. Mesafe konumla ölçüldüğü için tırmanış hızından ve yavaş çekimden bağımsızdır; Başlangıç Sıçraması (M4-06) gibi tırmanışı hızlandıran şeyler de aynı kuralla sayılır. Kalkanın sahibi `Player`, tur kuralının sahibi `Run`: yenilenme tur kuralıdır |
| ADR-072 | 2026-10-21 | Başlangıç Sıçraması (M4-06): ek yol **tam vuruş sayısına yuvarlanır** ve `smoothstep` eğrisiyle, toplam hız `head_start_speedup` (×8) olacak sürede verilir; sıçrama başlangıç sektöründe biter (sığmazsa kısalır). Sıçramada ve bitişten sonra `head_start_grace` (1 sn) dokunulmazlık; çekirdek yanıp söner. Geçilen Glimmer'lar konumla süpürülür (`collect_passed`). Yeni sinyal `Events.head_start_changed(active)` | Vuruşa yuvarlama ızgarayı ve müzikle senkronu korur: sıçramadan sonra dikenler yine vuruşta gelir, harita (tohum) değişmez; sapma en çok yarım vuruş (S1'de 3–4 m). Bitişteki dokunulmazlık, oyuncunun hızla bir tehlikenin dibine inmesini adil kılar. Yüksek hızda alan değmesi kaçabildiği için toplama konumla yapılır. Sektör sınırını aşmamak, sektör geçişini (afiş, renk dalgası) sıçramanın dışında tutar. HUD ve ses tepkisi M5/M6 cilasına kalır |
| ADR-073 | 2026-10-21 | İkinci Şans (M4-07): ölümde hak varsa turu `GameManager` bitirmez; `AUTO_REVIVE_DELAY` (0,8 sn) sonra `Events.player_revived` (M5-03'e dek kendiliğinden; zamanlayıcı tur sayacıyla korunur), `Run` canlandırır: önündeki 2,5 sn'lik yol ve altındaki 3 m içindeki tehlikeler temizlenir (gizle + `monitorable` kapalı, havuz sıfırlamasında geri gelir), duvar en az 20 m'ye itilir, 2 sn dokunulmazlık. **Ölümde vuruş saati durur**; düşme denetimi tırmanıştan önce. Değerler `TuningConfig` → Diriliş | Karar (hak, tur sonu) GameManager'ın, dünya Run'ın: sahne ağaçları yalnızca `Events` ile konuşur (§3) ve M5-03'teki düğme aynı `revive()`'a bağlanır. Saat dursun ki oyuncu, vuruş ızgarası ve müzik dirilişten sonra da aynı yerde olsun: dikenler yarım vuruşta gelir, müzik kaldığı yerden sürer (GDD §7). Temizleme konumla, düğüm silmeden: tur sırasında `queue_free` yok (`.clauderules` §6), harita tohumla aynı kalır. Temizleme süreyle ölçülür ki her sektörde aynı tepki payını versin. HUD ve ses tepkisi M5/M6'ya kalır |
| ADR-074 | 2026-10-21 | Kozmetik izler (M4-08): sekiz `TrailDef` + `TrailCatalog` (`data/trails/`): varsayılan Neon (sektör rengini izler), beş satılık (300 / 600 / 1000 / 1800 / 3000) ve iki başarım izi (toplam 500 kıl payı, Büyük Depo; 7 günlük seri M7-03'te). Kuşanılan iz `RunLoadout.trail` ile tura gider. Satın almak kuşandırmaz. Başarımlar `finish_run`'da ve `mark_great_storage_reached`'te denetlenir, açılışta değil. Renkler tehlike ve Glimmer tonlarından ≥ 30° uzak (test). Kazanç formülleri `Progression`'dan statik `Earnings`'e taşındı | İz kozmetiktir, günlük meydan okumada da kalabilir; tek yük nesnesi Main → Run yolunu değiştirmez. Satın alma ile kuşanmanın ayrı olması mağazada (M5) önizleme ve geri dönmeye yer bırakır. Başarım koşulu yalnızca değiştiği anda değişir, açılışta taramaya gerek yok. Okunabilirlik: iz hiçbir zaman tehlike ya da toplanabilir gibi görünmesin (GDD §11). `Progression` 20 genel metot sınırını (gdlint) aşıyordu; saf formüller benzetimde (M4-14) de gerekecek. Kullanıcı gözden geçirecek (`standard_queue`) |
| ADR-075 | 2026-10-22 | İz renkleri ayrıştırıldı (M4-08 eki, kullanıcı geri bildirimi): her izin başı ayrı renk ailesinde (Ayaz buz beyazı, Ametist koyu mor, Altın limon sarısı, Plazma pembe → mor, Kuyruklu Yıldız mavi, Kıl Payı koyu turuncu, Büyük Depo camgöbeği → mor → pembe); Neon pastel, ötekiler doygun. Ayrım testi: OKLab'de renk geçişinin aynı yerlerindeki farkların saydamlıkla ağırlıklı ortalaması + parlama farkı; izler arası ≥ 0,25, her sektörde Neon'la ≥ 0,15. Fiyat, kalınlık ve boy değişmedi | Kullanıcı Ayaz ~ Kuyruklu Yıldız ve Altın ~ Kıl Payı'nı çok yakın buldu (ölçüyle 0,13 / 0,17); Ametist ~ S2 Neon 0,05 idi. Göz izin başını görür, parlama zayıftır: aynı aileden iki açık ton ayırt edilmiyordu. OKLab'de uzaklık algılanan farka yakındır (gözün seçtiği en küçük fark ~0,02); eşikler yeni setin en yakın çiftlerinin (0,31 / 0,19) biraz altında. Test sektör kataloğunu dolaşır, S4/S5 eklenince renkler yine çakışmaz |

## 18. Açık teknik sorular

| # | Soru | Nerede çözülecek |
| --- | --- | --- |
| S-01 | ✅ Çözüldü (M0-09): Glow çalışıyor ve güzel ama Redmi'de kare süresi 8,4 → 17,5 ms (57 FPS). Sahte parlama seçildi (ADR-020) | — |
| S-02 | ✅ Çözüldü (M0-09): Evet. `background_canvas_max_layer` = 0 iken katman 10'daki HUD parlamıyor (telefonda doğrulandı) | — |
| S-03 | ✅ Çözüldü (M2-07, M2-18, M2-20): Redmi'de kayma 17–25 ms, 40 ms eşiği uygun; çıkış gecikmesi API'si Android'de 0 ms dönüyor ama kulak testlerinde geç kalan ses duyulmadı. Başka cihazlar için gerekirse "ses kaydırma" ayarı (M5-05) | — |
| S-04 | ✅ Çözüldü (M0-08): Godot 4.7 debug anahtarını kendisi oluşturuyor (`%APPDATA%\Godot\keystores\debug.keystore`); Java/SDK yollarını da kendisi buldu | — |
| S-05 | Play Games ve AdMob eklentilerinin Godot 4.7 uyumlu sürümleri | M7 |
| S-06 | ✅ Çözüldü (M3-17): Exo 2 (OFL), Türkçe harfleri tam (§12). Orbitron'da Ğ İ Ş ğ ş · eksikti, elendi | — |
| S-07 | ✅ Çözüldü (M0-10, M2-18): Emülasyon fare olayları `DEVICE_ID_EMULATION` ile ayrılıyor; gerçek iki başparmak denemesi M2-18 oyun testinde geçti (§8.1) | — |
| S-08 | ✅ Çözüldü (M0-06): `--headless --script` modunda autoload'lar yükleniyor | — |
| S-09 | Redmi'de rastgele tek kare takılmaları (25–43 ms, ≈ 100 sn'de 0–2, her kalitede; oyun olayıyla çakışmıyor) ve sektör girişinde dalga + yakın duvarla yüksek kalitede 10,8 ms (M3-19, §16.1) | M6-03 |

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
| gdfxr (timothyqiu) | Godot editöründe sfxr: ses efekti üretme, `.sfxr` içe aktarma | MIT | Son commit Ağu 2024; 4.7'de denenmeli | ❌ ADR-042 (efektler kütüphaneden) |
| GodotPrompter (jame581) | Claude Code için 56 Godot becerisi (mobil, test, event bus…) | MIT | 4.3+ (4.5–4.7 notlarıyla) | 📖 Kurulmuyor; ilgili beceriler gerektiğinde okunur |
| godogen (htdt) | Otonom Godot oyun üretimi | MIT | — | 📖 Ders: "iddia değil kanıt", oyunu çalıştırarak doğrula |
| GDA (aigengame/godot-agent) | Headless sahne/betik doğrulama; canlı mod yalnızca macOS/Linux | MIT | 4.4+ | ❌ Python 3.13+, 1.0 öncesi, Windows'ta canlı mod yok |
| godot_parser (stevearc) | Python ile `.tscn` okuma/yazma | MIT | Godot 4 desteği belirsiz | ❌ |
| godot-agent-knowledge (flou-ainan) | Godot 4.7 kural tabanı | MIT | 4.7+ | ❌ Çok yeni (0 yıldız); fikirleri not alındı |
| Coding-Solo/godot-mcp | MCP ile Godot kontrolü | MIT | Belirtilmemiş | ❌ ADR-013 |
