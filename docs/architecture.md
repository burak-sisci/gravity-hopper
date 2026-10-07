# GRAVITY HOPPER — Teknik Mimari

> Son güncelleme: 2026-10-07 (M0 Planlama Gözden Geçirmesi) · Durum: M0 altyapısı doğrulandı. ⚠️ işaretli maddeler, yanlarında yazan görevde doğrulanacak.
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
│   ├── levels/               # run.gd, chunk_info.gd
│   ├── systems/              # ChunkSpawner, Conductor, PressureSystem, ObjectPool, RunRng
│   ├── data/                 # Resource sınıf tanımları (TuningConfig, SectorDef…)
│   ├── ui/                   # UI betikleri
│   └── debug/                # Debug araçları
│
├── tools/                    # Geliştirici araçları: check.ps1 + check_scripts.gd + warning_keys.gd (M0-06), deploy.ps1 (M0-08),
│                             #   scene_tool.gd + fixtures/ (M0-11), lint_hook.py (M0-12)
├── tests/                    # (M2) Otomatik testler (gdUnit4)
└── addons/                   # Sürümü sabit eklentiler (her biri CREDITS.md'de)
    ├── debug_menu/           # godot-debug-menu, commit ff12461 (M0-09); yalnızca debug
    └── …                     # gdUnit4 (M2), Play Games ve AdMob (M7)
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

> **Şu anki içerik (M1-03):** `World/Run` (`scenes/levels/run.tscn`). M0-10'un `TapTest` ve `TapHint` sahneleri ana sahneden çıkarıldı ama dosyaları duruyor:
> - `scenes/debug/tap_test.tscn`: girdi kurallarının başvuru örneği.
> - `scenes/ui/tap_hint.tscn`: FTUE'deki "dokun" eli ikonunun nabız davranışı için. FTUE metinsizdir (GDD §18).
>
> Şimdilik `UI` boş; HUD M1-10'da gelir.

Sahne geçişlerini `GameManager` yönetir: `World` ve `UI` kaplarının içeriğini değiştirir. Uygulama durumları: `BOOT → MENU → RUNNING ⇄ PAUSED → RESULTS → (RUNNING | MENU | SHOP)`.

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

**Şu anki hâli (M1-07):** `Run` → `%Corridor` (`scripts/levels/corridor.gd`, `Corridor`) + `%Player` (`scenes/entities/player.tscn`, `Player`; çocukları `Body`, `Hurtbox/Shape`, `Visual`) + `%GameCamera` (`scripts/components/game_camera.gd`, `GameCamera`). Yukarıdaki ağaç hedeftir; düğümler görevleriyle eklenir.

- **Corridor:**
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
| — | 0 | Oyuncunun `Hurtbox`'ı (`Area2D`, `monitorable = false`) | `hazard` |

Toplanabilirler (Glimmer) ve kıl payı algılayıcısı katmanlarını kendi görevlerinde alır (M2-09, M2-10).

### 5.3 UI sahneleri (`scenes/ui/`)

`main_menu`, `hud`, `results`, `shop` (yükseltmeler + izler), `settings`, `pause`, `about` (lisanslar). **Hiçbiri `World`'e erişmez**: hepsi `Events`'i dinler, niyetlerini `Events` ile bildirir.

## 6. Autoload'lar

| Autoload | Görevi | Not |
| --- | --- | --- |
| `Events` | Global sinyal veri yolu | Yalnızca sinyal tanımları, mantık yok |
| `GameManager` | Uygulama durum makinesi, tur başlatma/bitirme, sahne geçişleri | Turu `Run`'a aşağı çağrıyla başlatır |
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
| `run_started` | `run_seed: int, start_sector: int` | GameManager | HUD, AudioManager |
| `run_ended` | `result: RunResult` | GameManager | Sonuç ekranı |
| `pause_changed` | `paused: bool` | GameManager | HUD, AudioManager |
| `player_died` | `cause: GameTypes.DeathCause` (HAZARD, FELL, WALL) | Player, PressureSystem | GameManager, HUD, AudioManager |
| `player_revived` | — | GameManager | HUD, AudioManager |
| `player_flipped` | — | Player | AudioManager (ses, titreşim) |
| `shield_changed` | `active: bool` | Player | HUD, AudioManager |
| `height_changed` | `meters: int` | Run (yalnızca tam sayı değişince) | HUD |
| `sector_entered` | `index: int` | Run | HUD (afiş), AudioManager (müzik) |
| `glimmer_collected` | `value: int` | Run | HUD, AudioManager |
| `near_miss` | `combo: int` | Run | HUD, AudioManager |
| `combo_ended` | — | Run | HUD |
| `wall_proximity_changed` | `ratio: float` (0 uzak – 1 yakın) | PressureSystem | HUD (kenar vinyeti), AudioManager |
| `beat` | `index: int` | Conductor | Arka plan, HUD (nabız) |
| `start_requested` | `sector: int` | UI | GameManager |
| `retry_requested` / `revive_requested` / `menu_requested` | — | UI | GameManager |
| `pause_requested` / `resume_requested` | — | UI | GameManager |
| `glimmers_changed` | `total: int` | Progression | UI |
| `upgrade_purchased` | `id: StringName, level: int` | Progression | UI, AudioManager |
| `settings_changed` | — | Settings | AudioManager ve ilgililer |

### 7.3 Örnek akış: Ölüm

1. Diken (`Area2D`, pasif) oyuncunun `Hurtbox`'ıyla örtüşür.
2. `Hurtbox` bileşeni yukarıya `hit` sinyali yayar → `Player`.
3. `Player`: kalkan varsa tüketir ve `shield_changed(false)` + yerel `shield_broken` yayar. Kalkan yoksa `Events.player_died.emit(DeathCause.HAZARD)`. **Dikenin koduna dokunmaz.**
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
- Adım 4 ve 6 (tur döngüsü) M1-09'da gelir.

## 8. Oynanış sistemleri

### 8.1 Hareket (Player)

- `CharacterBody2D`, `motion_mode = FLOATING`.
- **Dikey:** Sabit tırmanış hızı (`velocity.y = -climb_speed`); değer aktif sektörden gelir. M1'de sektör yoktur; hız `TuningConfig`'teki geçici `climb_speed` alanından gelir (S1: 12 m/sn = 600 px/sn). M2-06'da `SectorDef`'e taşınır. Bütün hareket değerleri `TuningConfig`'te metre birimindedir (§10).
- **Yatay:** Yerçekimi aktif duvara doğru çeker (`gravity_accel`, `max_side_speed`). Duvar segmentleri `StaticBody2D`'dir; tutunma `is_on_wall()` ile algılanır.
- **Çevirme** yalnızca duvara tutunurken yapılabilir, ek olarak:
  - **Coyote süresi:** Duvardan ayrıldıktan (boşluğa girdikten) sonra kısa bir süre (başlangıç 0,08 sn) çevirmeye izin verilir. Yalnızca duvar boşluklarında anlamlı olduğu için boşluklarla birlikte M2-08'de gelir.
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
    - Gerçek iki başparmak denemesi M1-14'te kullanıcı yapacak (adb ile taklit edilemiyor). Girdi kodunun örneği: `scripts/debug/tap_test.gd` → `_is_tap`.

### 8.2 Bölüm üretimi (desen parçaları)

- **Desen parçası (chunk)** = `scenes/levels/chunks/` altında bir sahne. Kökünde `ChunkInfo` betiği bulunur:
  - `difficulty` (1–10), `min_sector`, `max_sector`, `length_beats`, `tags`.
- Parçalar **vuruş biriminde** tasarlanır: editörde 1 vuruş = 100 px dikey ızgara. Parça yerleştirilirken y konumları sektörün vuruş uzunluğuna göre ölçeklenir: `y_dünya = y_yerel / 100 × vuruş_px(sektör)`. Şekiller esnemez, yalnızca konumlar ölçeklenir.
- `vuruş_px(sektör) = tırmanış_hızı × 60 / BPM`.
- `ChunkSpawner`:
  - Kameranın 2 ekran önünü dolu tutar.
  - Sıradaki parçayı `RunRng` ile, sektör içi ilerlemeye göre hedef zorluk eğrisinden ağırlıklı seçer.
  - Son N parçayı tekrar etmez.
  - Sektör geçişlerine "nefes alma" parçası koyar.
- **Çözülebilirlik:** İki zorunlu çevirme arası süre ≥ çevirme geçiş süresi + tepki payı. M2'de parçaları sektör hızlarında denetleyen bir doğrulama betiği yazılacak.
- **Belirlenimcilik:** Harita yalnızca `tohum + başlangıç sektörü`ne bağlıdır; oyuncunun hareketlerine bağlı değildir.
- **`RunRng`** (`scripts/systems/run_rng.gd`): tur tohumuyla kurulan `RandomNumberGenerator` sarmalayıcısı; oynanıştaki tek rastgelelik kaynağı (.clauderules §5). M1-08'de geçici engel yerleştirici için yazılır, M2-01'de gdUnit4 testleriyle sabitlenir.

### 8.3 Ritim (Conductor)

- **Tek doğru zaman kaynağı, oyun zamanıdır** (`run_time`, ölçeklenmiş `delta` ile ilerler). Müzik ona hizalanır.
- Müzik konumu `get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()` ile okunur. Kayma eşiği aşılırsa (başlangıç 40 ms) müzik yeniden hizalanır. ⚠️ eşik M2–M3'te ayarlanacak.
- Müzik geçişleri ölçü (bar) sınırına denk getirilir.
- **Dokunuşlar müziğe göre yargılanmaz** (Android ses gecikmesi cihazdan cihaza değişir). Müzik yalnızca bölüm yerleşimini belirler.
- **Zaman ölçeği kuralı:** `Engine.time_scale` değiştiğinde (kıl payı yavaş çekimi, duraklatma) `AudioManager` müziğin `pitch_scale` değerini aynı orana çeker. Bu, bant yavaşlaması gibi bir efekt verir ve senkronu korur.
- Diriliş ve duraklatma sonrasında müzik `run_time`'a göre konumlanır.

### 8.4 Çöküş duvarı (PressureSystem)

- Durum: `distance_m` (oyuncunun altındaki mesafe).
- Her fizik adımında sektörün sürünme hızı kadar azalır.
- Olaylar mesafeyi değiştirir: Glimmer → iter, kıl payı → iter, kalkan kırılması → çeker. Değerler `TuningConfig`'te.
- `distance_m ≤ 0` → `Events.player_died(WALL)`. Yakınlık, `wall_proximity_changed` ile yayınlanır.
- Görsel (`CollapseWall`), oyuncunun `distance_m × 50 px` altında çizilir.

### 8.5 Kıl payı (GrazeDetector)

- `Hurtbox`'tan biraz büyük bir `Area2D` kullanılır (başlangıç +40 px).
- Bir tehlike bu alandan, `Hurtbox`'a hiç değmeden çıkarsa → kıl payı. `Run` kombo sayacını yönetir ve `Events.near_miss(combo)` yayar.

### 8.6 Toplanabilirler ve mıknatıs

- Glimmer'lar desen parçalarının içinde yerleşiktir (belirlenimci).
- Mıknatıs alanındaki Glimmer'lar oyuncuya doğru çekilir.
- Toplanan değer ve kombo çarpanı `RunStats` içinde hesaplanır. `RunStats` turun istatistiklerini tutan, `Run`'a ait bir `RefCounted` nesnedir.

### 8.7 Nesne havuzu

- `ObjectPool`: sahne başına önceden oluşturulmuş örnekler; `acquire()` / `release()` (M2-03).
- M1'deki geçici engel yerleştirici de bu kurala uyar. Tur başında sabit sayıda diken oluşturulur; ekranın altından çıkan diken yeniden yukarı taşınır.
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
| `TuningConfig` | `data/tuning/default_tuning.tres` | His ayarları, `@export_group`'larla gruplu: Hareket (`climb_speed`, `gravity_accel`, `max_side_speed`), Adalet (`input_buffer_time`, `hurtbox_scale`), Kamera ve dünya (`lookahead`, `corridor_width`). Basınç ve kıl payı alanları ilgili görevde eklenir (M2). Ayrıntı aşağıda |
| `SectorDef` | `data/sectors/sector_01.tres` … | İsim anahtarı, palet, BPM, tırmanış hızı, uzunluk, izinli tehlikeler, zorluk aralığı, müzik |
| `SectorPalette` | `data/sectors/` | Çevre, vurgu ve arka plan renkleri |
| `UpgradeDef` | `data/upgrades/*.tres` | `id`, isim anahtarı, seviye maliyetleri `Array[int]`, seviye değerleri `Array[float]` |
| `TrailDef` | `data/trails/*.tres` | `id`, fiyat ya da açılma koşulu, renk geçişi, genişlik |
| `ChunkInfo` | desen parçası sahnelerinin kökü | Zorluk, sektör aralığı, vuruş uzunluğu, etiketler |
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
  - Oyun dünyasını tanımaz. İsteklerini `Events` sinyalleriyle iletir; bunlar M1'de eklenir ve kataloğa yazılır.
  - Kök `Control` tam ekrandır ama `mouse_filter = IGNORE` taşır, yani dokunuşları yutmaz. `process_mode = ALWAYS` olduğu için oyun duraklatılınca da çalışır.
  - **Tuşlar:** `_key_actions` sözlüğü tuş kodunu bir işleve bağlar; yeni debug tuşu eklemek bu sözlüğe bir satırdır. `_unhandled_key_input` içinde işlenir.
  - **Debug düğmesi** ("DBG"): sol üstte, viewport'ta (16, 12)–(156, 84). `focus_mode = NONE`, böylece boşluk tuşu düğmeye gitmez, çevirmeye gider. Şimdilik FPS görünümünü değiştirir; M1-11'de debug panelini açar.
  - M1-02'de sınandı: ekransız denemede `7` tuşu üç görünümü sırayla değiştirdi, düğmeye dokunuş çevirme sayılmadı, ekranın ortasına dokunuş ve boşluk sayıldı. Redmi'de de düğme FPS'yi açtı ve günlükte çevirme kaydı çıkmadı.
  - **Olay günlüğü:** Önemli `Events` sinyalleri `EVENT <ad> t=<ms>` satırı olarak yazılır (`_connect_event_log`). Telefondaki denemeler `adb logcat -s godot:*` ile bu satırlardan doğrulanır. Şimdilik `player_flipped` ve `player_died cause=<NEDEN>`; yeni olaylar ilgili görevde eklenir.
  - Ders: `Viewport.push_input()` ile dokunuş taklit edilirken koordinat viewport biriminde verilecekse ikinci parametre `true` olmalı. Aksi hâlde pencere ölçeği (PC'de 450/1080) uygulanır ve nokta hedefini ıskalar.
- **Canlı ayar paneli:** `TuningConfig`'in `@export` alanlarından **otomatik** üretilen kaydırıcılar (yeni bir ayar eklendiğinde panele kendiliğinden gelir).
  - "Kaydet" düğmesi değerleri `user://tuning_override.tres`'e yazar.
  - PC'de Claude bu dosyayı doğrudan okuyup onaylanan değerleri kalıcı hale getirebilir.
- **PC tuşları** (M1'de kesinleşecek):

  | Tuş | İşlev | Görev |
  | --- | --- | --- |
  | `1` | Ayar paneli | M1-11 |
  | `2` | Ölümsüzlük | M1-12 |
  | `3` | Çarpışma kutularını göster | M1-12 |
  | `4` | Yavaş çekim | M1-12 |
  | `5` | Sonraki sektöre atla | M2-06 |
  | `6` | Ekran oranı döngüsü (16:9 → 20:9 → 4:3) | M1-06 |
  | `7` | FPS / kare süresi | M1-02 |
  | `R` | Anında yeniden başla | M1-12 |

  F5–F8 kullanılmaz; Godot editör kısayollarıyla karışır.
- **Telefonda:** Küçük, yarı saydam bir debug düğmesi paneli açar. Düğme yalnızca debug build'de görünür; yeri, HUD ile çakışmayacak şekilde M1-02'de seçilir.
  - Düğme bir `Control` olduğu için dokunuş arayüzde kalır ve çevirme yapmaz (§8.1, `_unhandled_input`).
  - Eski plandaki "köşeye üçlü dokunuş" bırakıldı: o dokunuşların her biri aynı zamanda yerçekimini çevirirdi.
- **Performans katmanı:** `godot-debug-menu` eklentisi (MIT): FPS, kare süresi grafikleri, CPU süresi. GPU süresi Android'de (GLES) ölçülemiyor (`-1`); onun yerine §16'daki GPU doluluk sayacı kullanılır.
  - Eklentinin yalnızca çalışma zamanı parçası alındı; editör eklentisi (`plugin.gd`) alınmadı, çünkü kendini autoload olarak ekliyor ve yayın sürümüne de girerdi.
  - Yükleme: Debug katmanı onu `load("res://addons/debug_menu/debug_menu.tscn")` ile örnekler (M1-02). Telefonda okunabilsin diye `CanvasLayer` 2× büyütülüp sola kaydırılır (örnek: `glow_bench.gd` → `_add_debug_menu`). Görünüm `style` özelliğiyle seçilir: 0 gizli, 1 kısa, 2 ayrıntılı.
  - `7` tuşu ve telefondaki debug düğmesi görünümü gizli → kısa → ayrıntılı sırasıyla değiştirir (M1-02). Eklentinin kendi kısayolu F3'tür.
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

- Dışa aktarma ön ayarı "Android" (`export_presets.cfg`, depoda), **Runnable** olarak işaretli: arm64-v8a + armeabi-v7a (eski 32-bit cihazlar için), immersive mod, dışlama filtresi `tools/*, tests/*`.
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
- **Web çıktısı** (arkadaşlara link için): tek iş parçacıklı (single-threaded, `web_nothreads_*` şablonları kurulu) dışa aktarma.
  - Barındırma kullanıcı kararıdır (D-12, M1-13).
  - Depo **özel** olduğu için GitHub Pages ücretsiz planda kullanılamaz; Pages ücretsiz planda yalnızca açık depolarda çalışır.
  - Seçenekler: itch.io (ücretsiz, gizli bağlantılı taslak sayfa) ya da yalnızca web çıktısını içeren ayrı bir açık depo.

## 15. Test ve doğrulama

| Katman | Nasıl | Ne zaman |
| --- | --- | --- |
| **Tam kontrol** | `tools/check.ps1`, dört adım: (1) içe aktarma, (2) tüm betikler "Warn" seviyesindeki kurallar geçici `override.cfg` ile "Error"a çekilerek derlenir, (3) sahne denetimi (`scene_tool.gd check`), (4) `gdlint` (§13.1). `TEMİZ` = sıfır hata, sıfır uyarı | Her görevde |
| Kod denetimi (anlık) | Claude Code kancası: düzenlenen `.gd` dosyasında `gdlint` | Her `.gd` düzenlemesinde, otomatik |
| Görsel kontrol | Movie Maker ile kare yakalayıp Claude'un incelemesi | Görsel değişikliklerde |
| Otomatik test | **gdUnit4** (MIT): RNG belirlenimciliği, desen üretimi, ekonomi, kayıt sürüm geçişi; sahne koşucusuyla dokunuş taklidi yapan oynanış testleri | M2'den itibaren |
| Ekonomi simülasyonu | "Kaç turda ne alınır?" betiği | M4 |
| Oyun testi | Kullanıcı: PC → Redmi → web linki | Her kilometre taşında |

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

Sahne: `scenes/debug/glow_bench.tscn`. Duvarlar, 14 diken, 8 blok, 20 Glimmer, oyuncu + iz, ızgara ve HUD, tam ekran 1080×2400. Her mod 4 sn ölçüldü, iki kez. Başka bir cihazda yeniden ölçmek için sahne geçici olarak ana sahne yapılıp yüklenir (M1-12'de debug paneline bir düğme olarak bağlanabilir); PC'de `<godot> --path . res://scenes/debug/glow_bench.tscn`.

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
| ADR-023 | 2026-10-07 | M0 gözden geçirmesi: (1) debug araçları autoload değil, `Main/Debug`'a yalnızca debug build'de yüklenen `debug_layer.tscn`. (2) Telefonda panel köşeye üçlü dokunuşla değil, debug düğmesiyle açılır. (3) `RunRng` M1-08'e alındı; M1'in geçici engelleri de geri dönüştürülür (havuz kuralı). (4) Coyote süresi duvar boşluklarıyla birlikte M2-08'e taşındı | (1) Autoload'lar yayın sürümüne de girer. (2) Her dokunuş aynı zamanda çevirme yapar. (3) .clauderules §5 ve §6 M1'de de geçerli. (4) Boşluk olmadan coyote süresi denenemez |
| ADR-024 | 2026-10-07 | `TuningConfig` değerleri GDD birimlerinde (m, m/sn, sn) tutulur; kod `to_px()` ile çevirir. Her alan `@export_range` ile aralık ve birim taşır; geçerli değerler `.tres`'tedir | Kaydırıcılar tasarım belgesiyle aynı dili konuşur (ör. 12 m/sn = S1). Ayar paneli alanları elle tanımlamadan kurar |
| ADR-025 | 2026-10-07 | Çalışma modeli (kullanıcı kararı): 🤖 görevler arasında onay beklenmez. Claude 🤝/👤 göreve, bekleyen karara, kapıya ya da beklenmedik bir tasarım sorusuna kadar ilerler; her görev yine ayrı commit ve kanıtla kapanır. M1-04'teki gerçek iki başparmak denemesi M1-14'e taşındı | Hız. Kapılar ve görev başına kanıt korunduğu için kalite düşmez; geri alma görev düzeyinde kolay |

## 18. Açık teknik sorular

| # | Soru | Nerede çözülecek |
| --- | --- | --- |
| S-01 | ✅ Çözüldü (M0-09): Glow çalışıyor ve güzel ama Redmi'de kare süresi 8,4 → 17,5 ms (57 FPS). Sahte parlama seçildi (ADR-020) | — |
| S-02 | ✅ Çözüldü (M0-09): Evet. `background_canvas_max_layer` = 0 iken katman 10'daki HUD parlamıyor (telefonda doğrulandı) | — |
| S-03 | Android'de müzik kayma eşiği ve gecikme telafisi | M2-05 / M3 |
| S-04 | ✅ Çözüldü (M0-08): Godot 4.7 debug anahtarını kendisi oluşturuyor (`%APPDATA%\Godot\keystores\debug.keystore`); Java/SDK yollarını da kendisi buldu | — |
| S-05 | Play Games ve AdMob eklentilerinin Godot 4.7 uyumlu sürümleri | M7 |
| S-06 | Neon stile uygun, Türkçe karakter destekli, lisansı temiz font | M3 |
| S-07 | Emülasyon fare olaylarının `DEVICE_ID_EMULATION` ile ayırt edilmesi. 🟡 M0-10'da tek dokunuş için doğrulandı (§8.1); gerçek iki parmak denemesi kaldı | M1-14 |
| S-08 | ✅ Çözüldü (M0-06): `--headless --script` modunda autoload'lar yükleniyor | — |

## 19. Araç ve kütüphane adayları (açık kaynak araştırması, 2026-09-29)

> Durum: ✅ benimsendi · 🟡 aday (kullanıcı kararı bekliyor) · 📖 yalnızca başvuru kaynağı · ❌ kullanılmıyor.
> Bir aday benimsenirse sürümü sabitlenir ve `CREDITS.md`'ye yazılır.

| Araç | Ne işe yarar | Lisans | Godot 4.7 | Durum |
| --- | --- | --- | --- | --- |
| **gdUnit4** (godot-gdunit-labs) | Birim testleri + sahne koşucusu: dokunma simülasyonu, kare ilerletme, sinyal bekleme; komut satırı, HTML/JUnit rapor | MIT | ✅ 4.7 ve 4.7.1 listelenmiş | ✅ ADR-014 (M2-01) |
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
