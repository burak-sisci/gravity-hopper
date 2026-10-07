# GRAVITY HOPPER — Yol Haritası ve Atomik Görev Listesi

> Son güncelleme: 2026-10-07 (M0 Planlama Gözden Geçirmesi: M1 atomik hale getirildi)
> Yayın tarihi yok; kalite odaklı ilerliyoruz. Görevlerin **durumu** için tek doğru kaynak `docs/state.json`'dur; buradaki kutular onun yansımasıdır.

## Nasıl okunur?

- **Görev kimliği:** `M1-03` = 1. kilometre taşının 3. görevi. Commit mesajları bu kimlikle başlar.
- **Atomik görev** = tek oturumda biten, tek commit'lik, test edilebilir iş.
- **Sahip:** 🤖 Claude · 👤 sen · 🤝 birlikte. 🤖 görevler arasında senin onayın beklenmez; Claude 🤝/👤 göreve, bekleyen karara ya da kapıya kadar ilerler (ADR-025).
- **Kabul:** görevin "bitti" sayılma şartı.
- **🚪 Kapı:** Kilometre taşı, sen oynayıp onaylamadan kapanmaz; sonraki aşamaya geçilmez.
- **Kademeli planlama:** M0–M2 ayrıntılı, M3–M8 daha kaba. Her kilometre taşının sonundaki Planlama Gözden Geçirmesi'nde sıradaki aşama atomik görevlere bölünür.

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
- [ ] **P-04** 👤 Planlama belgelerini oku; itiraz ve düzeltmelerini ilet → 🚪

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
- [ ] **M1-12** 🤖 Debug tuşları: ölümsüzlük (`2`), çarpışma kutuları (`3`), yavaş çekim (`4`), anında yeniden başlama (`R`); telefonda debug panelinde aynı düğmeler.
  *Kabul:* Tuşlar `architecture.md` §13 tablosuyla uyumlu.
- [ ] **M1-13** 🤝 Web dışa aktarma denemesi (arkadaşlara link). Barındırma yeri D-12'ye bağlı.
  *Kabul:* Tarayıcıda oynanabilir bir link var.
- [ ] **M1-14** 👤 His testi: PC + Redmi, ayar paneliyle "doğru his"i bul. Ayrıca iki başparmakla hızlı dokunuşlar: hiçbiri kaybolmamalı (S-07).
  *Kabul:* Beğendiğin değerler kaydedildi; iki başparmak denemesi geçti.
- [ ] **M1-15** 🤖 Onaylanan değerleri kalıcı yap (`default_tuning.tres`, `state.json` → `approved_tuning`, GDD).
- [ ] **M1-16** 🤝 Planlama Gözden Geçirmesi → 🚪 **Sen onaylamadan M2'ye geçilmez.**

## M2 — Sonsuz ve adil

**Hedef:** Bitmeyen, adil ve giderek zorlaşan bir tırmanış.

- [ ] **M2-01** 🤖 gdUnit4 test altyapısı (sürümü sabit) + `RunRng` testleri (`RunRng` M1-08'de yazıldı).
  *Kabul:* Aynı tohum aynı sayı dizisini veriyor (test).
- [ ] **M2-02** 🤖 Desen parçası biçimi: `ChunkInfo`, vuruş birimli ızgara, parça tasarım kuralları (belgeye).
  *Kabul:* Örnek bir parça editörde ızgaraya oturuyor.
- [ ] **M2-03** 🤖 `ObjectPool` + `ChunkSpawner`: parça seçimi, önden doldurma, havuza iade.
  *Kabul:* Tur sırasında `instantiate` / `queue_free` yok (profil ile).
- [ ] **M2-04** 🤖 İlk 12–15 desen parçası (S1–S2 zorluğu).
  *Kabul:* Her parça doğrulama betiğinden geçiyor.
- [ ] **M2-05** 🤖 `Conductor`: BPM, vuruş sinyali, metronom sesi, dünya-vuruş hizası (S-03 ilk ölçüm).
  *Kabul:* Engeller metronomla aynı anda geliyor.
- [ ] **M2-06** 🤖 `SectorDef` kaynakları + sektör ilerleyişi: hız basamağı (`climb_speed` `TuningConfig`'ten buraya taşınır), geçici palet, "nefes alma" geçişi, debug `5` tuşu (sonraki sektör).
  *Kabul:* S1→S2→S3 geçişleri çalışıyor.
- [ ] **M2-07** 🤖 Zorluk eğrisi: sektör içi hedef zorluk, parça ağırlıkları, hız tavanı.
  *Kabul:* Sektör sonu başından belirgin şekilde zor.
- [ ] **M2-08** 🤖 Yeni tehlikeler: duvar boşluğu (düşme) + coyote süresi, veri bloğu, lazer kapısı (vuruşa bağlı).
  *Kabul:* Her biri en az 3 parçada kullanılıyor; boşluğa girdikten hemen sonraki çevirme kaybolmuyor.
- [ ] **M2-09** 🤖 Glimmer (havuzlu) ve riskli yol yerleşimi; sayaç HUD'da.
  *Kabul:* Toplama sinyalle HUD'a yansıyor.
- [ ] **M2-10** 🤖 `GrazeDetector` + kombo sayacı.
  *Kabul:* Kıl payı güvenilir algılanıyor, yanlış pozitif yok.
- [ ] **M2-11** 🤖 `PressureSystem` + geçici çöküş duvarı görseli.
  *Kabul:* Sürünme, itme/çekme ve duvar ölümü çalışıyor.
- [ ] **M2-12** 🤖 Kalkan mekaniği (test için debug ile verilir).
  *Kabul:* Tek darbeyi emiyor, duvarı çekiyor.
- [ ] **M2-13** 🤖 Belirlenimcilik testi: aynı tohum → aynı parça dizisi (gdUnit4).
- [ ] **M2-14** 👤 Oyun testi: ilk 3 sektör. Zorluk adil mi, "bir tur daha" isteği doğuyor mu?
- [ ] **M2-15** 🤝 Planlama Gözden Geçirmesi → 🚪

## M3 — Görsel ve işitsel kimlik

**Hedef:** Oyunun profesyonel göründüğü ve duyulduğu an. *(Gözden geçirmede atomik hale getirilecek.)*

- [ ] **M3-01** 🤖 Neon altyapısı (sahte parlama, ADR-020): `SectorPalette`, yeniden kullanılabilir neon çizgi/şekil bileşenleri (`glow_bench.gd` tekniğinden), kalite seviyesine göre parlama katmanı sayısı
- [ ] **M3-02** 🤖 Çekirdek görseli + iz (`Line2D`)
- [ ] **M3-03** 🤖 Tehlike görselleri (şekil dili: sivri = tehlike)
- [ ] **M3-04** 🤖 Arka plan veri ağı shader'ı, vuruşta nabız
- [ ] **M3-05** 🤖 Çöküş duvarı glitch görseli + yaklaşma vinyeti
- [ ] **M3-06** 🤖 Oyun hissi: sarsıntı, ölümde donma, sıkışma-uzama, parçacıklar
- [ ] **M3-07** 🤖 Kıl payı yavaş çekimi (müzikle birlikte) + "KIL PAYI!" + kombo göstergesi
- [ ] **M3-08** 🤖 Hız hissi efektleri: paralaks, hız çizgileri
- [ ] **M3-09** 🤝 Ses efektleri (D-05'e göre üretim)
- [ ] **M3-10** 🤝 Sektör müzikleri (D-02'ye göre) + gerçek müzikle ritim senkronu
- [ ] **M3-11** 🤝 Font seçimi (S-06) + HUD stili; sektör renklerinin kesinleşmesi
- [ ] **M3-12** 🤖 Redmi'de performans kontrolü (kare süresi ≤ 10 ms)
- [ ] **M3-13** 🤝 Oyun testi (sesi açık) + Planlama Gözden Geçirmesi → 🚪

## M4 — Meta döngü

**Hedef:** Her turun sonunda elinde bir şey kalması.

- [ ] **M4-01** 🤖 `SaveManager`: şifreli, atomik, sürümlü kayıt + testleri
- [ ] **M4-02** 🤖 `Progression`: Glimmer cüzdanı, tur sonu kazanç hesabı
- [ ] **M4-03** 🤖 `UpgradeDef` kaynakları + satın alma mantığı
- [ ] **M4-04** 🤖 Yükseltme etkileri: Mıknatıs, Kalkan, Başlangıç Sıçraması, Glimmer Çarpanı, İkinci Şans
- [ ] **M4-05** 🤖 Kozmetik izler (`TrailDef`) + kuşanma
- [ ] **M4-06** 🤖 Sektör kontrol noktaları
- [ ] **M4-07** 🤖 S4–S5 içerikleri, Büyük Depolama Birimi finali, Taşma modu
- [ ] **M4-08** 🤖 Ekonomi simülasyon betiği + ilk dengeleme
- [ ] **M4-09** 🤝 Oyun testi + Planlama Gözden Geçirmesi → 🚪

## M5 — Arayüz ve akış

**Hedef:** Oyun baştan sona, menüleriyle birlikte oynanıyor.

- [ ] **M5-01** 🤖 `GameManager` durum makinesi ve sahne geçişleri
- [ ] **M5-02** 🤖 Ana menü (sektör seçimi dahil)
- [ ] **M5-03** 🤖 Sonuç ekranı (rekor, "rekora X m", tek dokunuşla tekrar)
- [ ] **M5-04** 🤖 Yükseltmeler ve izler ekranları
- [ ] **M5-05** 🤖 Ayarlar: ses, müzik, titreşim, dil, kalite, 60 FPS sınırı
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
- [ ] **M6-03** 🤖 Performans ölçümü + efekt kalitesi seviyeleri
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

---

## Sürekli işler (her aşamada)

- Her görev sonunda planlama rutini (`CLAUDE.md`) ve commit.
- **Pazarlama arşivi:** Güzel anları telefonun ekran kaydıyla kısa dikey videolar olarak sakla. Yayına geldiğimizde TikTok / Reels / Shorts içeriğin hazır olur.
- **12 test kullanıcısı:** Şimdiden isim topla (Android telefonu olan aile ve arkadaşlar).
