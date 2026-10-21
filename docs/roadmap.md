# GRAVITY HOPPER — Yol Haritası ve Atomik Görev Listesi

> Son güncelleme: 2026-10-21 (M3 Planlama Gözden Geçirmesi: M3 onaylandı, M4 atomik hale getirildi, 15 görev; ADR-066)
> Yayın tarihi yok; kalite odaklı ilerliyoruz. Görevlerin **durumu** için tek doğru kaynak `docs/state.json`'dur; buradaki kutular onun yansımasıdır.

## Nasıl okunur?

- **Görev kimliği:** `M1-03` = 1. kilometre taşının 3. görevi. Commit mesajları bu kimlikle başlar.
- **Atomik görev** = tek oturumda biten, tek commit'lik, test edilebilir iş.
- **Sahip:** 🤖 Claude · 👤 sen · 🤝 birlikte. 🤖 görevler arasında senin onayın beklenmez (ADR-025).
- **Mesai türü (ADR-045):** *Standart mesaide* sen ekran başındasın; Claude 🤝/👤 göreve, bekleyen karara ya da kapıya kadar ilerler ve seni bekler. *Otonom mesaide* Claude tek başına çalışır: yalnızca 🤖 görevleri yapar, 🤝/👤 görevleri ve karar bekleyenleri atlayıp `state.json` → `standard_queue`'ya yazar; bunlar sonraki standart mesaide yapılır. Kapı otonom mesaide de geçilmez.
- **Kabul:** görevin "bitti" sayılma şartı.
- **🚪 Kapı:** Kilometre taşı, sen oynayıp onaylamadan kapanmaz; sonraki aşamaya geçilmez.
- **Kademeli planlama:** M0–M4 atomik, M5–M8 daha kaba. Her kilometre taşının sonundaki Planlama Gözden Geçirmesi'nde sıradaki aşama atomik görevlere bölünür.

## Genel bakış

| # | Kilometre taşı | Senin göreceğin |
| --- | --- | --- |
| P | Ön planlama | Planlama belgeleri |
| M0 | Temel ve kurulum | Telefonunda açılan ilk ekran |
| M1 | Çekirdek his (gri kutular) | "30 saniyede eğlenceli mi?" |
| M2 | Sonsuz ve adil | Giderek zorlaşan, adil tırmanış; ilk 3 sektör |
| M3 | Görsel ve işitsel kimlik | Oyunun profesyonel göründüğü an |
| M4 | Meta döngü | "Bir tur daha" döngüsü |
| M5 | Arayüz ve akış | Baştan sona tam oyun |
| M6 | Cihaz uyumu ve performans | Farklı telefonlarda aynı kalite |
| M7 | Sosyal katman ve gelir | Liderlik, günlük meydan okuma, ödüllü reklam |
| M8 | Kapalı test ve yayın | Play Store'da 🚀 |

---

## P — Ön planlama

- [x] **P-01** 🤝 Oyun fikri, kancalar ve temel kararlar
- [x] **P-02** 🤖 Kurulum rehberi (`KURULUM.md`)
- [x] **P-03** 🤖 Planlama belgeleri (`CLAUDE.md`, `.clauderules`, `architecture.md`, `state.json`, `GDD.md`, `roadmap.md`, `CREDITS.md`) ve klasör yapısı
- [x] **P-05** 🤖 Açık kaynak araştırması: araçlar, kütüphaneler, ajan kuralları (`architecture.md` §19, ADR-013)
- [x] **P-04** 👤 Planlama belgelerini oku; itiraz ve düzeltmelerini ilet → 🚪 *(M2-19 kapısında kapandı, 2026-10-13: itiraz yok.)*

## M0 — Temel ve kurulum

**Hedef:** Geliştirme ortamı hazır, oyun telefona tek tıkla yükleniyor, denetim araçları çalışıyor.

- [x] **M0-01** 👤 `KURULUM.md` adımları.
  *Kabul:* Tüm kutular işaretli.
- [x] **M0-02** 🤖 Kurulum doğrulama: Godot, Git kimliği, `gh auth`, JDK 17, Android SDK bileşenleri, `adb devices` ile Redmi. `CLAUDE.md` ortam bölümünün güncellenmesi.
  *Kabul:* Her kontrol geçti. `KURULUM.md` senin onayınla silindi.
- [x] **M0-03** 🤝 (D-01'e bağlı) Proje klasörünü boşluksuz `gravity-hopper` adına taşı.
  *Kabul:* Claude Code yeni klasörde açılıyor, belgeler yerinde.
- [x] **M0-04** 🤖 Godot projesini oluştur: `project.godot` ayarları (`architecture.md` §2), `.gitignore`, `.gitattributes`, geçici ikon.
  *Kabul:* Proje editörde uyarısız açılıyor.
- [x] **M0-05** 🤖 Git deposu + GitHub'da özel depo, ilk commit ve push.
  *Kabul:* Depo GitHub'da görünüyor.
- [x] **M0-06** 🤖 Autoload iskeletleri: `Events` (sinyal kataloğu), `GameManager`, `SaveManager`, `Progression`, `Settings`, `AudioManager`, hepsi minimal. *(Ek: `GameTypes`, `RunResult`, tam kontrol aracı `tools/check.ps1`.)*
  *Kabul:* Headless kontrol sıfır hata ve sıfır uyarı verir.
- [x] **M0-07** 🤖 Yerelleştirme altyapısı: `translations.csv` (TR/EN), cihaz diline göre varsayılan.
  *Kabul:* Test metni cihaz diline göre değişiyor.
- [x] **M0-08** 🤝 Android dışa aktarma: editörde Java ve SDK yolları, "Runnable" ön ayar, debug anahtarı (S-04), dışlama filtreleri (`tools/`, `tests/`), dışa aktarma şablonları, boş ana sahne iskeleti, Redmi'ye kabloyla tek tıkla yükleme. *(Kablosuz yükleme ertelendi, ADR-019.)*
  *Kabul:* Oyun Redmi'de açılıyor (telefonun ekran görüntüsüyle kanıtlı).
- [x] **M0-09** 🤖 Parlama teknik denemesi (S-01, S-02): `godot-debug-menu` eklentisi (sürümü sabit), Compatibility'de `WorldEnvironment` glow + `Polygon2D`, HUD katmanı ayrımı, yedek plan olarak sahte parlama. *(Sonuç: sahte parlama, ADR-020. Ölçüm sahnesi `scenes/debug/glow_bench.tscn`.)*
  *Kabul:* İki yöntemin Redmi'deki görüntüsü ve kare süresi ölçüldü; karar ADR olarak yazıldı.
- [x] **M0-10** 🤖 Test sahnesi: dokununca renk değiştiren neon bir şekil (sahte parlamalı) ve "Dokun / Tap" yazısı. Ana sahne `glow_bench.tscn`'den yeniden `main.tscn`'e döner. *(Ek: girdi kuralları erkenden sınandı, S-07 kısmen doğrulandı.)*
  *Kabul:* PC'de ve Redmi'de dokunma algılanıyor, yazı iki dilde doğru.
- [x] **M0-11** 🤖 Sahne aracı `tools/scene_tool.gd`: `tree` ve `check` komutları (`architecture.md` §13.1); `check`, `tools/check.ps1`'e bağlanır. *(Ek: sinyal bağlantıları, `@export` yolları, `get_parent()` / `..` kural ihlalleri, ad önerisi, `tools/fixtures/` ile kendini sınama; ADR-021.)*
  *Kabul:* `tree` test sahnesinin ağacını doğru listeliyor; bilerek yanlış yazılmış bir düğüm adını `check` yakalıyor ve hata koduyla çıkıyor.
- [x] **M0-12** 🤖 Kod denetimi: gdtoolkit kurulumu (sürümü sabit), kurallarımıza göre `gdlintrc`, düzenlenen `.gd` dosyalarını otomatik denetleyen Claude Code kancası. *(gdtoolkit 4.5.0 sanal ortamda; `check.ps1` 4. adım; ADR-022.)*
  *Kabul:* Kural dışı bir adı `gdlint` yakalıyor; mevcut tüm kod temiz geçiyor.
- [x] **M0-13** 🤝 Planlama Gözden Geçirmesi → 🚪 **Sen test edersin:** oyun PC'de ve telefonda açılıyor. *(Gözden geçirme 2026-10-07, ADR-023. ✅ M0 senin tarafından onaylandı, 2026-10-07.)*

## M1 — Çekirdek his (gri kutular)

**Hedef:** Görsel süs yok, sadece his. *"30 saniyede eğlenceli mi?"*
*(M0 gözden geçirmesinde atomik hale getirildi, 2026-10-07; ADR-023. Şekiller düz renkli gri kutular; neon görünüm M3'te.)*

- [x] **M1-01** 🤖 `TuningConfig` kaynağı (`scripts/data/tuning_config.gd`) ve `data/tuning/default_tuning.tres`. Hareket, kamera ve adalet değerleri `@export_group`'larla gruplanır, her alanın Türkçe `##` açıklaması olur. Başlangıç değerleri GDD ve `architecture.md`'den gelir (M1'de geçici `climb_speed` = 12 m/sn). *(Değerler GDD birimlerinde: m, m/sn, sn; ADR-024.)*
  *Kabul:* Tüm hareket ve kamera değerleri tek `.tres` dosyasında; editörde Inspector'da açıklamalarıyla görünüyor.
- [x] **M1-02** 🤖 Debug katmanı: `scenes/debug/debug_layer.tscn`, `Main/Debug`'a yalnızca debug build'de yüklenir. `godot-debug-menu` buraya taşınır (`7` tuşu ile aç/kapa). Telefonda küçük debug düğmesi FPS'yi açıp kapatır. Tuş altyapısı burada kurulur; diğer tuşlar sonraki görevlerde dolar.
  *Kabul:* PC'de `7`, telefonda düğme FPS'yi açıp kapatıyor; düğmeye dokunmak oyunda dokunuş sayılmıyor (girdi denemesi).
- [x] **M1-03** 🤖 `run.tscn` iskeleti: düz koridor duvarları (sabit sayıda parça, aşağıda kalan parça yukarı taşınır), `GameCamera` ile sabit ileri görüş kuralı (`architecture.md` §3). `main.tscn`'de `TapTest` ve `TapHint` yerine `World/Run` gelir.
  *Kabul:* Kamera sabit hızla yukarı kayıyor, duvarlar kesintisiz; PC ve Redmi ekran görüntüsü.
- [x] **M1-04** 🤖 Player hareketi: sabit tırmanış, aktif duvara yerçekimi, yalnızca duvara tutunurken çevirme, girdi kuralları (her parmak, sahte fare yok sayılır; S-07), `Events.player_flipped`. Kamera artık oyuncuyu izler.
  *Kabul:* Çevirme PC'de ve Redmi'de güvenilir (ekransız deneme + adb dokunuşları). Gerçek iki başparmak denemesi adb ile taklit edilemediği için M1-14'te sen yaparsın (S-07 orada kapanır).
- [x] **M1-05** 🤖 Dokunma tamponu (havadayken yapılan dokunuş duvara değince uygulanır) + çevirme hissi parametreleri (`gravity_accel`, `max_side_speed`).
  *Kabul:* Duvara varmadan hemen önce yapılan dokunuş kaybolmuyor; süre `TuningConfig`'ten değişiyor.
- [x] **M1-06** 🤖 Ekran oranı testi: PC'de `6` tuşu pencereyi 16:9 → 20:9 → 4:3 arasında döndürür.
  *Kabul:* Her oranda oyuncunun üstündeki görüş mesafesi aynı (üç ekran görüntüsüyle ölçülü).
- [x] **M1-07** 🤖 Diken tehlikesi (pasif `Area2D`) + `Hurtbox` bileşeni → `Events.player_died(HAZARD)`.
  *Kabul:* Diken oyuncuyu tanımıyor; ölüm yalnızca sinyalle işleniyor; sahne denetimi temiz.
- [x] **M1-08** 🤖 `RunRng` (tohumlu RNG, `architecture.md` §8.2) + geçici engel yerleştirici: düz aralıklı dikenler, taraf `RunRng` ile seçilir. Dikenler tur başında oluşturulur ve geri dönüştürülür (tur sırasında `instantiate` yok). M2'de desen sistemiyle değişir.
  *Kabul:* Sonsuz ama basit bir engel akışı; aynı tohum aynı diziyi veriyor (günlükle).
- [x] **M1-09** 🤖 `GameManager` tur döngüsü: başla → öl → anında yeniden başla (`run_started`, `player_died`, `run_ended`).
  *Kabul:* Ölümden yeni tura < 0,5 sn (günlük zamanlarıyla ölçülü).
- [x] **M1-10** 🤖 Minimal HUD (`scenes/ui/hud.tscn`, ayrı sahne, yalnızca sinyal dinler): yükseklik ve oturum rekoru; metinler TR/EN anahtarlarla.
  *Kabul:* HUD dünyadaki hiçbir düğüme erişmiyor; sahne denetimi temiz.
- [x] **M1-11** 🤖 Canlı ayar paneli: `TuningConfig`'in `@export` alanlarından otomatik kaydırıcılar, "Kaydet" → `user://tuning_override.tres`. PC'de `1`, telefonda debug düğmesiyle açılır.
  *Kabul:* Oynarken değer değişiyor; kaydedilen dosyayı Claude okuyabiliyor.
- [x] **M1-12** 🤖 Debug tuşları: ölümsüzlük (`2`), çarpışma kutuları (`3`), yavaş çekim (`4`), anında yeniden başlama (`R`); telefonda debug panelinde aynı düğmeler.
  *Kabul:* Tuşlar `architecture.md` §13 tablosuyla uyumlu.
- [x] **M1-13** 🤝 Web dışa aktarma denemesi (arkadaşlara link). Barındırma: itch.io (D-12, ADR-027); sayfa herkese açık, şifresiz (kullanıcı kararı 2026-10-15, ADR-060): https://burak-sisci.itch.io/gravity-hopper. *(Claude'un kısmı tamam: Web ön ayarı, `tools/web_build.ps1`, zip, tarayıcı denemesi. Kalan: senin itch.io sayfasını açıp zip'i yüklemen. ⏸ Ertelendi, kullanıcı kararı 2026-10-08; istediğin zaman kaldığı yerden sürer, M1 kapısını beklemez.)*
  *Kabul:* Tarayıcıda oynanabilir bir link var.
- [x] **M1-14** 👤 His testi: PC + Redmi, ayar paneliyle "doğru his"i bul. Ayrıca iki başparmakla hızlı dokunuşlar: hiçbiri kaybolmamalı (S-07).
  *Kabul:* Beğendiğin değerler kaydedildi; iki başparmak denemesi geçti. *(2026-10-11: başlangıç değerleri değiştirilmeden kaydedildi. İki başparmak denemesi M2-18 oyun testinde geçti.)*
- [x] **M1-15** 🤖 Onaylanan değerleri kalıcı yap (`default_tuning.tres`, `state.json` → `approved_tuning`, GDD). *(Değerler zaten `.tres`'teydi; GDD §13.1 ve `approved_tuning` yazıldı, telefondaki kayıt dosyası silindi.)*
- [x] **M1-16** 🤝 Planlama Gözden Geçirmesi → 🚪 **Sen onaylamadan M2'ye geçilmez.** *(Gözden geçirme yapıldı 2026-10-11: M2 19 atomik göreve bölündü. Kapı, senin kararınla M2-19'daki birleşik kapıya taşındı (ADR-028); M1 orada M2 ile birlikte kontrol edilir. Ertelenen M1-13 kapıyı engellemez.)*

## M2 — Sonsuz ve adil

**Hedef:** Bitmeyen, adil ve giderek zorlaşan bir tırmanış.
*(M1 gözden geçirmesinde atomik hale getirildi, 2026-10-11. Şekiller hâlâ gri kutular; neon görünüm M3'te.)*

**Test altyapısı**

- [x] **M2-01** 🤖 gdUnit4 (sürümü sabit, CREDITS) + `tests/` yapısı + komut satırı koşucusu; `tools/check.ps1`'e 5. adım "testler". İlk testler `RunRng` için (aynı tohum aynı dizi, farklı tohum farklı dizi, `make_seed` 0 vermez).
  *Kabul:* Tam kontrol testleri çalıştırıyor; bilerek bozulan bir test `SORUN VAR` veriyor.
- [x] **M2-02** 🤖 M1 davranışlarının kalıcı testleri: M1'deki geçici deneme betikleri gdUnit4'e taşınır. Kapsam: tırmanışın tam sabit olması, yalnızca duvardayken çevirme, dokunma tamponu, girdi kuralları (sahte fare, iki parmak), debug düğmesine dokunuşun çevirme sayılmaması, ölümden yeni tura < 0,5 sn.
  *Kabul:* Testler geçiyor ve tam kontrolde çalışıyor.

**Desen sistemi**

- [x] **M2-03** 🤖 Desen parçası biçimi: `ChunkInfo` (zorluk, sektör aralığı, vuruş uzunluğu, etiketler), vuruş ızgarası (1 vuruş = 100 px), parça tasarım kuralları (`architecture.md` §8.2), bir örnek parça.
  *Kabul:* Örnek parça ızgaraya oturuyor; `ChunkInfo` değerleri testle okunuyor.
- [x] **M2-04** 🤖 `ObjectPool` + `ChunkSpawner`:
  - Parça havuzları, `RunRng` ile ağırlıklı seçim, kameranın 2 ekran önünü dolu tutma, havuza iade ve sıfırlama.
  - `SpikeSpawner` ve "Geçici engeller (M1)" ayarları kaldırılır.
  *Kabul:* Tur sırasında düğüm oluşturulmuyor (test: düğüm sayısı sabit); Redmi'de kesintisiz akış.
- [x] **M2-05** 🤖 Parça doğrulama aracı (`tools/`, `check.ps1`'e bağlı): Her parça, izinli her sektör hızında çözülebilir mi? Ölçütler: iki zorunlu çevirme arası ≥ geçiş süresi + tepki payı; engel ≥ 1,2 sn önceden görünür.
  *Kabul:* Bilerek çözülemez yapılan bir parçayı yakalıyor.
- [x] **M2-06** 🤖 İlk 12–15 desen parçası (yalnızca diken; S1–S2 zorluğu).
  *Kabul:* Doğrulama temiz; Redmi'de 2 dakikalık akış tekrar etmeden oynanıyor.

**Ritim ve sektörler**

- [x] **M2-07** 🤖 `Conductor`: BPM'den vuruş zamanı, `Events.beat`, kodla üretilen metronom sesi (dış varlık yok), parçaların vuruşa hizalanması. S-03 için ilk gecikme ölçümü.
  *Kabul:* Dikenler metronomla aynı anda geçiyor (günlük + kulak testi).
- [x] **M2-08** 🤖 `SectorDef` + S1–S3 kaynakları: ad anahtarları TR/EN, BPM, hız, uzunluk, izinli tehlikeler, zorluk aralığı, geçici palet. Sektör ilerleyişi ve hız basamağı (`climb_speed` `TuningConfig`'ten buraya taşınır). Debug `5` tuşu (sonraki sektör).
  *Kabul:* Her sektörde tırmanış hızı doğru (test); S1 → S2 → S3 geçiliyor.
- [x] **M2-09** 🤖 Sektör geçişi: "nefes alma" boşluğu, `Events.sector_entered`, HUD'da sektör afişi (TR/EN), geçici palet tonu.
  *Kabul:* Geçişte engel yok, afiş görünüyor (Redmi ekran görüntüsü).
- [x] **M2-10** 🤖 Zorluk eğrisi: sektör içi hedef zorluk, parça ağırlıkları, son N parçayı tekrar etmeme.
  *Kabul:* Sektör sonunda seçilen parçaların zorluk ortalaması başından belirgin yüksek (günlükle ölçülü).

**Yeni tehlikeler ve sistemler**

- [x] **M2-11** 🤖 Duvar boşluğu: parçalar boşluk aralıkları tanımlar, koridor o aralıkta duvarsız kalır. Koridordan düşme → `player_died(FELL)`. Coyote süresi (`TuningConfig`).
  *Kabul:* Boşluktan düşülüyor; boşluğa girdikten hemen sonraki çevirme kaybolmuyor (test).
- [x] **M2-12** 🤖 Veri bloğu ve vuruşa bağlı lazer kapısı + her biriyle en az 3 parça.
  *Kabul:* Doğrulama temiz; lazer vuruşla aynı anda açılıp kapanıyor.
- [x] **M2-13** 🤖 Glimmer: havuzlu toplanabilir (parça içinde), toplama alanı, `glimmer_collected`, `RunStats`, HUD sayacı, riskli yola yerleşim kuralı.
  *Kabul:* Toplama sinyalle HUD'a yansıyor; tur sonunda `RunResult.glimmers` doğru.
- [x] **M2-14** 🤖 `GrazeDetector` + kombo (2,5 sn zincir, ×2 / ×3), `near_miss` / `combo_ended`.
  *Kabul:* Kıl payı güvenilir algılanıyor, yanlış pozitif yok (test).
- [x] **M2-15** 🤖 `PressureSystem` + geçici çöküş duvarı görseli, `player_died(WALL)`, `wall_proximity_changed`; Glimmer ve kıl payı duvarı iter.
  *Kabul:* Sürünme, itme/çekme ve duvar ölümü çalışıyor (test + Redmi).
- [x] **M2-16** 🤖 Kalkan (test için debug ile verilir): tek darbeyi emer, 1 sn dokunulmazlık, duvarı çeker, `shield_changed`.
  *Kabul:* Tek darbeyi emiyor, duvarı çekiyor (test).
- [x] **M2-17** 🤖 Belirlenimcilik testi: aynı tohum + başlangıç sektörü → aynı parça dizisi ve konumları (gdUnit4).

**Kapanış**

- [x] **M2-18** 👤 Oyun testi: ilk 3 sektör. Zorluk adil mi, "bir tur daha" isteği doğuyor mu? Ayrıca M1'den kalanlar (ADR-028): iki başparmak denemesi (S-07) ve ilk his izlenimi. M2-07'den: metronom kulak testi (dikenler tıkla aynı anda mı geçiyor, tık geç mi kalıyor? S-03). *(2026-10-13: kullanıcı "her şey güzel görünüyor" dedi. Testte bulunan hızlı çift dokunuş sorunu düzeltildi, ADR-036.)*
- [x] **M2-20** 🤖 Müzik (kullanıcı isteği, 2026-10-13; M2-19'dan önce yapıldı): beş parça her turda rastgele, turun temposu parçanın (ADR-040). `MusicTrack` / `MusicCatalog`, `tools/music_prep.py` (ilk vuruşa kırpma, tam ölçü döngü), metronomun yerine parça, sektör geçişinde ızgara kesintisiz, doğrulayıcı her tempoda. *(Kulak testi geçti, 2026-10-13: "her şey güzel".)*
- [x] **M2-19** 🤝 Planlama Gözden Geçirmesi → 🚪 **Birleşik kapı: M1 + M2** (ADR-028). P-04 (planlama belgeleri) de burada kapanır. *(Gözden geçirme yapıldı 2026-10-13: belgeler düzeltildi, M3 20 atomik göreve bölündü, ADR-041. ✅ M1 + M2 senin tarafından onaylandı, 2026-10-13; P-04 kapandı; D-05 kararı ADR-042.)*

## M3 — Görsel ve işitsel kimlik

**Hedef:** Oyunun profesyonel göründüğü ve duyulduğu an.
*(M2 gözden geçirmesinde atomik hale getirildi, 2026-10-13; ADR-041.)*

- Görünüş veriyle kurulur: palet, bileşen ve shader değerleri. Sonradan istenen görünüş yeniden yapılandırması (bkz. "Sonra") kodu değil veriyi değiştirsin.
- Yeni her efekt Redmi'de denenmeden bitmiş sayılmaz (.clauderules §6). Ölçüt: 60 FPS'te kare süresi ≤ 10 ms.
- Görsel değişiklikler çarpışma kutularına dokunmaz; parça doğrulaması aynı sonucu verir.

**Neon altyapısı**

- [x] **M3-01** 🤖 Neon bileşenleri: `glow_bench.gd` tekniğinden yeniden kullanılabilir `NeonLine` (çizgi + parlama kopyaları) ve `NeonShape` (şekil + ışık lekesi). Parlama katman sayısı efekt kalitesine göre değişir (`Settings.effect_quality`). Ölçüm sahnesi `glow_bench.tscn` bu bileşenlerle yeniden kurulur.
  *Kabul:* Ölçüm sahnesi aynı görünüyor; Redmi'de kare süresi M0-09 ölçümüyle aynı; kalite seviyesi katman sayısını değiştiriyor (test).
- [x] **M3-02** 🤖 `SectorPalette` kaynağı: çevre, vurgu, arka plan. Tehlike kırmızısı, Glimmer yeşili ve oyuncu beyazı sabittir. S1–S3 için geçici paletler (GDD §12 tonları). `SectorDef.ambient_color` ve `Corridor.set_tint` bunun yerine geçer; sektöre girişte yumuşak geçiş.
  *Kabul:* S1→S2→S3'te renkler paletten geliyor; hiçbir çevre rengi kırmızı ya da yeşil değil (test).
- [x] **M3-03** 🤖 Neon koridor duvarları: kenar çizgileri `NeonLine`, boşluk kenarlarında temiz kesik, vuruşta hafif nabız. Sesi kapalı oynayan da ritmi görsün (GDD §16).
  *Kabul:* Boşluk kenarı görselde ve çarpışmada aynı yerde (test); S1 ve boşluklu S2'nin Redmi ekran görüntüsü.

**Varlık görselleri**

- [x] **M3-04** 🤖 Çekirdek: beyaz neon elmas + ışık lekesi; iz (`Line2D`: geçmiş konumlar, genişlik eğrisi, renk geçişi); neon kalkan halkası.
  *Kabul:* İzin uzunluğu ekran yenileme hızından bağımsız (60 ve 120 Hz'de aynı, test); Redmi ekran görüntüsü.
- [x] **M3-05** 🤖 Diken ve veri bloğu: sivri kırmızı neon diken; köşeli blok ve süzülme hissi (yalnızca görsel, ADR-035).
  *Kabul:* Çarpışma kutuları değişmedi (doğrulama aynı); Redmi ekran görüntüsü.
- [x] **M3-06** 🤖 Lazer ve Glimmer: lazerin yanık ve sönük hâli, yanmadan hemen önce bir uyarı ışıması (oyuncu ne zaman yanacağını görebilmeli); yuvarlak, yeşil, parıldayan Glimmer. Şekil dili denetimi (GDD §6).
  *Kabul:* Lazer görüntüsü çarpışmayla aynı karelerde yanıyor (test); gri tonlu kare yakalamada tehlike, Glimmer ve oyuncu yalnızca şekilden ayırt ediliyor.

**Dünya ve geçişler**

- [x] **M3-07** 🤖 Arka plan: veri ağı shader'ı (ızgara + yavaş paralaks), vuruşta nabız; düşük kalitede düz renk.
  *Kabul:* Redmi'de kare süresi ve GPU doluluğu ölçüldü (≤ 10 ms); üç kalite seviyesinin ekran görüntüsü.
- [x] **M3-08** 🤖 Sektör geçişinde renk dalgası: yeni palet aşağıdan yukarıya yayılır, afiş dalgayla gelir (GDD §12).
  *Kabul:* Kare dizisinde dalga aşağıdan yukarıya ilerliyor; geçişte engel yok (mevcut test).
- [x] **M3-09** 🤖 Çöküş duvarı: glitch görseli (shader, kaliteye bağlı; yalnızca duvarın alanında, tam ekran değil: M3-07 ölçümü) + yaklaşma vinyetinin inceltilmesi.
  *Kabul:* Duvar yakınken engeller okunuyor (Redmi ekran görüntüsü); kare süresi ölçüldü.

**Oyun hissi**

- [x] **M3-10** 🤖 Kamera sarsıntısı (travma² × gürültü, yalnızca görsel) + ölümde kısa donma.
  *Kabul:* Ölümden yeni tura hâlâ < 0,5 sn; sarsıntı oyuncunun üstündeki görüş mesafesini değiştirmiyor (testler).
- [x] **M3-11** 🤖 Sıkışma-uzama (çevirme ve iniş, yalnızca görsel) + havuzlu parçacıklar (`CPUParticles2D`): iniş kıvılcımı, Glimmer patlaması, ölüm patlaması.
  *Kabul:* Tur sırasında düğüm sayısı sabit (test); Redmi'de kare süresi ölçüldü.
- [x] **M3-12** 🤖 Kıl payı geri bildirimi: yavaş çekim (0,5×, 0,25 sn), zincirin ilk halkasında ve kombo eşiklerinde; müzik de aynı oranda yavaşlar. "KIL PAYI!" yazısı (TR/EN) ve kombo göstergesi (×2 / ×3).
  *Kabul:* Yavaş çekimde müzik kaymıyor (günlük); harita değişmiyor (belirlenimcilik testi); yazı iki dilde.
- [x] **M3-13** 🤖 Hız hissi: hız çizgileri ve uzayan iz, sektör hızıyla yoğunlaşır (GDD §13).
  *Kabul:* S1 ile S3'ün kare yakalamasında fark görünüyor; Redmi'de kare süresi ölçüldü.
- [x] **M3-14** 🤖 Rekor çizgisi: dünyada, rekor yüksekliğinde parlayan yatay çizgi (GDD §8). Şimdilik oturum rekoru; kalıcı rekor M4'te.
  *Kabul:* Çizgi rekor yüksekliğinde (test); dünya HUD'a erişmiyor (sahne denetimi).

**Ses**

- [x] **M3-15** 🤖 Ses efektleri (insan yapımı, ücretsiz kütüphanelerden: Kenney CC0, gerekirse Freesound yalnızca CC0 / CC-BY; ADR-042): `AudioManager` efekt havuzu (sabit sayıda çalar, tur sırasında düğüm oluşturulmaz), olay → ses eşlemesi bir veri kaynağında. İlk set: çevirme, tutunma, Glimmer, kıl payı, kombo eşiği, kalkan kırılması, ölüm, sektör geçişi, rekor kırma. `CREDITS.md`.
  *Kabul:* Her olay doğru sesi çalıyor (test); ses düzeyleri müzikle dengeli (ölçüm); Redmi günlüğünde hata yok.
- [x] **M3-16** 🤖 Gerilim: çöküş duvarı yaklaştıkça müziğe alçak geçiren süzgeç (boğuklaşma) ve gerilim sesi (GDD §14).
  *Kabul:* Süzgeç duvarın yakınlığıyla değişiyor (test); Redmi'de sesli deneme.
- [x] **M3-21** 🤖 Özgün müzik (kullanıcı isteği, 2026-10-20: "yeterince akıcı değil; sen kendin Age of Empires'takine benzer bir müzik üret"): Claude besteler, CC0 gerçek enstrüman kayıtlarıyla (VCSL, VSCO 2 CE) kodla seslendirir ve mikse eder; eski beş parçanın yerine.
  *Kabul:* Parçalar tam ölçülük, dikişsiz döngü ve vuruş ızgarasında (test); tempolar doğrulayıcıdan geçiyor; ses düzeyi efektlerle dengeli (ölçüm); `CREDITS.md` güncel; Redmi'de çalıyor, günlük temiz.

**Kimlik ve kapanış**

- [x] **M3-17** 🤝 Font (S-06) ve kesin sektör renkleri: Claude 2–3 font adayı (SIL OFL, Türkçe karakterli) ve palet seçeneklerini telefon ekran görüntüleriyle sunar, sen seçersin.
  *Kabul:* Seçilen font `assets/fonts/`'ta ve `CREDITS.md`'de; paletler kesin, GDD §12 güncel.
- [x] **M3-18** 🤖 HUD stili: seçilen font, neon yazılar (yükseklik, rekor, Glimmer, sektör afişi, kombo).
  *Kabul:* Üç ekran oranında ekran görüntüsü (`6` tuşu); HUD dokunuşu yutmuyor (test).
- [x] **M3-19** 🤖 Redmi'de performans kontrolü: en yoğun sahne (S3, bütün efektler), üç kalite seviyesi.
  *Kabul:* Yüksek kalitede 60 FPS'te kare süresi ≤ 10 ms; ölçüm tablosu `architecture.md` §16'da. Sektör geçişindeki renk dalgası da ölçülür (M3-08'de en kötü durumda ≈ +0,5–1 ms). Çöküş duvarı ekrandayken de ölçülür (M3-09 tezgâhında ≈ +0,5–0,8 ms; tezgâhın toplamı 10,9–11,3 ms). Oyunun HUD'u tek başına ≈ 1 ms GPU (M3-09 ölçümü): ölçüt tutmazsa ilk bakılacak yer (M3-18).
- [x] **M3-20** 🤝 Oyun testi (sesi açık ve kapalı: ritim görüntüden de hissediliyor mu?) + Planlama Gözden Geçirmesi → 🚪
  ✅ M3 senin tarafından onaylandı, 2026-10-21 ("denemeler başarılı").

## M4 — Meta döngü

**Hedef:** Her turun sonunda elinde bir şey kalması.
*(M3 gözden geçirmesinde atomik hale getirildi, 2026-10-21; ADR-066.)*

- Menüler ve ekranlar M5'te gelir. M4'teki ilerleme, debug panelinin **İlerleme** sayfasıyla denenir (M4-03'ten itibaren; cüzdan, yükseltme satın alma, iz kuşanma, başlangıç sektörü, kaydı sıfırlama). Bu sayfa yalnızca debug yapısında var.
- Oynanış yükseltmeleri haritayı değiştirmez: aynı tohum aynı parça dizisini verir (belirlenimcilik testi). Etkiler tur başında `Run`'a tek bir yükleme olarak verilir; günlük meydan okumada (M7-03) bu yükleme boş verilir.
- Ekonomi değerleri veride durur (`data/upgrades/`, `data/trails/`); sayılar M4-14'teki simülasyonla dengelenir.

**Kayıt ve cüzdan**

- [x] **M4-01** 🤖 `SaveManager`: şema 1 (`architecture.md` §11.2), yayın yapısında şifreli, debug yapısında düz JSON; atomik yazma (`.tmp` → geri okuma → `.bak` → `.dat`), yükleme sırası (`.dat` → `.bak` → yeni kayıt), sürüm geçişi zinciri, eksik alanların varsayılanla tamamlanması.
  *Kabul:* Testler: yazıp okuma; bozuk `.dat`'ta `.bak`'tan, ikisi de bozuksa yeni kayıtla açılış; yarıda kalan `.tmp` eski kaydı bozmuyor; şifreli dosya düz metin değil; eski sürümlü kayıt yükseltiliyor. Redmi'de kayıt dosyası oluşuyor.
- [x] **M4-02** 🤖 `Progression` ve kalıcı rekor: cüzdan, rekor, en yüksek sektör ve istatistikler kayıttan yüklenir. Tur sonunda kazanç hesaplanır (toplanan Glimmer + sektör tamamlama bonusu 25 × sektör numarası) ve kaydedilir; uygulama arka plana geçince ve kapanırken de kaydedilir. Oturum rekoru (`GameManager.best_height_m`) kalkar: rekor çizgisi ve HUD'un rekor satırı kalıcı rekordan gelir.
  *Kabul:* Kazanç hesabı ve kayıt testte. Redmi'de oyun kapatılıp açılınca rekor çizgisi ilk turda yerinde, cüzdan korunuyor (günlük).
- [x] **M4-03** 🤖 Yükseltme verisi ve satın alma: `UpgradeDef` (`data/upgrades/*.tres`; GDD §10'daki seviye maliyetleri ve etkileri) + katalog, `Progression.buy_upgrade(id)` (cüzdan yetmezse ya da en üst seviyedeyse olmaz), `Events.upgrade_purchased`. Debug paneline **İlerleme** sayfası: cüzdan, seviyeler, satın alma, +1000 Glimmer, kaydı sıfırlama.
  *Kabul:* Satın alma kuralları ve maliyetlerin GDD ile aynı olduğu testte. Redmi'de panelden alınan seviye uygulama yeniden açılınca duruyor.

**Yükseltme etkileri**

- [x] **M4-04** 🤖 Mıknatıs ve Glimmer Çarpanı: mıknatıs yarıçapına (90–250 px) giren Glimmer'lar oyuncuya doğru akar; Glimmer Çarpanı tur sonu kazancını artırır (+%10 / seviye).
  *Kabul:* Seviye arttıkça daha uzaktaki Glimmer toplanıyor, harita değişmiyor, tur sırasında düğüm oluşmuyor (test); çarpan testte; Redmi'de çekim görünüyor.
- [x] **M4-05** 🤖 Kalkan yükseltmesi: 1. seviyede tur kalkanla başlar; 2.–5. seviyede kırılan kalkan 1500 / 1200 / 900 / 600 m sonra yenilenir.
  *Kabul:* Başlangıç kalkanı ve yenilenme mesafesi testte; günlükte `shield_changed`.
- [ ] **M4-06** 🤖 Başlangıç Sıçraması: tur başında dokunulmaz, hızlı bir sıçrama (100–500 m), yoldaki Glimmer'ları toplar. Bitince oyuncu bir duvara iner ve müziğin vuruşuyla hizalı devam eder.
  *Kabul:* Sıçrama boyu seviyeyle değişiyor, sıçramada ölüm yok, sonrasında dikenler yine vuruşta geçiliyor, harita aynı (testler); Redmi'de deneme.
- [ ] **M4-07** 🤖 İkinci Şans ve diriliş (GDD §7): ölümde, hak varsa, yakındaki tehlikeler temizlenir, çöküş duvarı geri itilir, 2 sn dokunulmazlık verilir, müzik sürer; tur başına en çok 1 ücretsiz diriliş. Sonuç ekranı gelene kadar diriliş kendiliğinden olur (M5-03'te düğmeye bağlanır).
  *Kabul:* Dirilişten sonra tur sürüyor, ikinci ölüm turu bitiriyor, tur sırasında düğüm oluşmuyor (test); günlükte `player_revived`.

**Kozmetik ve ilerleme**

- [ ] **M4-08** 🤖 Kozmetik izler: `TrailDef` (`data/trails/`; renk geçişi, kalınlık, parlama). 4–6 satın alınan iz (300–3000 Glimmer) ve başarım izleri (Büyük Depolama Birimi, toplam 500 kıl payı; 7 günlük seri M7-03'te). Satın alma ve kuşanma; çekirdek beyaz kalır.
  *Kabul:* Satın alma, kuşanma ve başarımla açılma testte; kuşanılan iz turda görünüyor (Redmi ekran görüntüsü, iki iz).
- [ ] **M4-09** 🤖 Sektör kontrol noktaları: ulaşılan her sektörün başı açılır ve kaydedilir. Tur seçilen açık sektörden başlar (seçim şimdilik İlerleme sayfasında, menüde M5-02); skor mutlak yükseklikten sayılır.
  *Kabul:* S2'ye varınca S2 açılıyor, kilitli sektör seçilemiyor, seçim uygulama yeniden açılınca duruyor (test).

**İçerik: S4, S5 ve final**

- [ ] **M4-10** 🤖 Yeni tehlikeler: dönen şekil (vuruş temposunda dönen köşeli engel) ve hareketli blok (duvarlar arasında ritimle gidip gelen). Görüntü çarpışmayla aynı adımda; parça doğrulayıcısı hareketli tehlikeleri vuruş vuruş dener.
  *Kabul:* Görüntü ve çarpışma her 120 Hz adımında aynı (test); doğrulayıcı geçilemeyen hareketli deseni yakalıyor (test); varlık galerisinde Redmi ekran görüntüsü.
- [ ] **M4-11** 🤖 S4 ÇEKİRDEK: `SectorDef` (18 m/sn, 1750 m, duvar sürünmesi 0,675 m/sn), eflatun palet (renk kuralına uygun, rekor sarısından ayrı), yeni tehlikeli desen parçaları, zorluk aralığı.
  *Kabul:* Doğrulayıcı her tempoda geçiyor; S3 → S4 geçişi testte; Redmi'de S4 ekran görüntüsü ve kare süresi.
- [ ] **M4-12** 🤖 S5 BOZULMA: `SectorDef` (20 m/sn, 2500 m, 0,8 m/sn), beyaz + glitch paleti (renk kayması yalnızca kendi alanında, kaliteye bağlı), bütün tehlikeleri karıştıran yoğun desenler.
  *Kabul:* Doğrulayıcı geçiyor; Redmi'de S5'te yüksek kalitede kare süresi ≤ 10 ms.
- [ ] **M4-13** 🤖 Büyük Depolama Birimi ve Taşma: 7500 m'de final anı (afiş, renk patlaması, ses; başarım izi açılır), ardından sonsuz Taşma modu (22 m/sn tavan, döngüsel palet, önceki sektörlerin desenlerinden remiks).
  *Kabul:* Final 7500 m'de bir kez oynuyor ve başarım izi açılıyor; Taşma'da hız tavanı ve ≥ 1,2 sn görüş kuralı tutuyor (test); Redmi'de ölümsüz turla final anının görüntüsü.

**Denge ve kapanış**

- [ ] **M4-14** 🤖 Ekonomi simülasyonu (`tools/`): beceri profillerine göre tur kazançları → "kaç turda ne alınır?". Değerler GDD §9.3 hedeflerine çekilir: ilk yükseltme 2.–3. turda, hepsi yaklaşık 2 haftada (≈ 22.000 Glimmer).
  *Kabul:* Simülasyon tablosu `architecture.md`'de, hedefler tutuyor; değişen değerler GDD'de.
- [ ] **M4-15** 🤝 Oyun testi ("bir tur daha" döngüsü, İlerleme sayfası, S4–S5, final) + Planlama Gözden Geçirmesi → 🚪

## M5 — Arayüz ve akış

**Hedef:** Oyun baştan sona, menüleriyle birlikte oynanıyor.

- [ ] **M5-01** 🤖 `GameManager` durum makinesi ve sahne geçişleri
- [ ] **M5-02** 🤖 Ana menü (sektör seçimi dahil; kontrol noktaları M4-09'da hazır)
- [ ] **M5-03** 🤖 Sonuç ekranı (rekor, "rekora X m", kazanılan Glimmer, tek dokunuşla tekrar; İkinci Şans dirilişi düğmeye bağlanır, M4-07)
- [ ] **M5-04** 🤖 Yükseltmeler ve izler ekranları (mantık M4-03 / M4-08'de; debug İlerleme sayfasının yerine)
- [ ] **M5-05** 🤖 Ayarlar: ses, müzik, titreşim, dil, kalite, 60 FPS sınırı; başka cihazlarda gerekirse ses kaydırma (S-03)
- [ ] **M5-06** 🤖 Duraklatma + arka plana geçince otomatik duraklatma ve kayıt
- [ ] **M5-07** 🤖 İlk açılış deneyimi (FTUE)
- [ ] **M5-08** 🤖 Titreşim
- [ ] **M5-09** 🤖 Hakkında / lisanslar ekranı (Godot MIT lisans metni zorunlu)
- [ ] **M5-10** 👤 Türkçe ve İngilizce metinlerin gözden geçirilmesi
- [ ] **M5-11** 🤝 İlk kez açan biri gibi test + Planlama Gözden Geçirmesi → 🚪

## M6 — Cihaz uyumu ve performans

**Hedef:** Farklı telefonlarda aynı kalite.

- [ ] **M6-01** 🤖 Güvenli alan (çentik, yuvarlak köşe)
- [ ] **M6-02** 🤖 Ekran oranı matrisi: 16:9, 18:9, 20:9, 21:9, 4:3, katlanabilir
- [ ] **M6-03** 🤖 Performans ölçümü + efekt kalitesi seviyeleri + indirme boyutu (hedef < 40 MB; debug APK şu an 68 MB, `architecture.md` §16)
- [ ] **M6-04** 🤖 Android emülatöründe düşük seviyeli cihaz profili testi
- [ ] **M6-05** 🤖 Pil ve ısınma kontrolü
- [ ] **M6-06** 🤖 Uygulama ikonu ve açılış ekranı
- [ ] **M6-07** 👤 🔔 **Google Play Console hesabını aç** (25 $; kimlik doğrulaması günler sürebilir)
- [ ] **M6-08** 👤 Tanıdıkların telefonlarında test (APK / web linki)
- [ ] **M6-09** 🤝 Planlama Gözden Geçirmesi → 🚪

## M7 — Sosyal katman ve gelir

**Hedef:** Oyuncuların yarışması ve oyunun gelir getirmesi.

- [ ] **M7-01** 🤖 Gradle derlemesi + Android derleme şablonu
- [ ] **M7-02** 🤖 Play Games Services: giriş, liderlik tablosu, başarımlar (S-05)
- [ ] **M7-03** 🤖 Günlük meydan okuma (D-04)
- [ ] **M7-04** 🤖 Paylaşım kartı (görüntü üretimi + Android paylaşım)
- [ ] **M7-05** 🤖 AdMob ödüllü reklamlar: diriliş, 2× Glimmer (D-03)
- [ ] **M7-06** 🤖 KVKK / GDPR onay akışı (UMP)
- [ ] **M7-07** 🤝 Gizlilik politikası sayfası (GitHub Pages)
- [ ] **M7-08** 🤝 Bulut kaydı ve analitik kararı (isteğe bağlı)
- [ ] **M7-09** 🤝 Oyun testi + Planlama Gözden Geçirmesi → 🚪

## M8 — Kapalı test ve yayın

**Hedef:** Play Store'da.

- [ ] **M8-01** 🤝 Paket adının kesinleşmesi (D-06) + yayın anahtarı + yedekleme + Play App Signing
- [ ] **M8-02** 🤖 AAB derlemesi, hedef API şartının kontrolü, yayın ön ayarında debug dosyalarının dışlanması (`addons/debug_menu/*`, `scenes/debug/*`, `scripts/debug/*`)
- [ ] **M8-03** 🤝 Mağaza sayfası: ikon, ekran görüntüleri, dikey tanıtım videosu, TR/EN açıklamalar
- [ ] **M8-04** 🤝 İsim ve marka son kontrolü
- [ ] **M8-05** 👤 Dahili test
- [ ] **M8-06** 👤 Kapalı test: **en az 12 kişi, 14 gün kesintisiz** (Google'ın zorunlu kuralı)
- [ ] **M8-07** 🤖 Test geri bildirimleriyle düzeltmeler
- [ ] **M8-08** 🤝 Üretime yayın 🚀

## Sonra (kullanıcı isteği, 2026-10-13)

- [ ] 🤝 **Görünüş ve hikâye yeniden yapılandırması:** güncel plandaki adımlar bitince ele alınır. Yayından önce mi sonra mı olacağı M7 sonunda konuşulur.

---

## Sürekli işler (her aşamada)

- Her görev sonunda planlama rutini (`CLAUDE.md`) ve commit.
- **Pazarlama arşivi:** Güzel anları telefonun ekran kaydıyla kısa dikey videolar olarak sakla. Yayına geldiğimizde TikTok / Reels / Shorts içeriğin hazır olur.
- **12 test kullanıcısı:** Şimdiden isim topla (Android telefonu olan aile ve arkadaşlar).
