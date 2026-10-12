# GRAVITY HOPPER — Oyun Tasarım Belgesi (GDD)

> Son güncelleme: 2026-10-11 (M1-15: onaylanan his değerleri §13.1'e işlendi) · Sürüm 0.1 (ön prodüksiyon)
> Bu belge *ne* yaptığımızı anlatır. **Sayısal değerlerin hepsi başlangıç değeridir**; ayar paneliyle oynanarak kesinleşir ve buraya işlenir.
> Teknik karşılıklar → `architecture.md`. Sıra → `roadmap.md`.

---

## 1. Künye

| | |
| --- | --- |
| **Ad** | GRAVITY HOPPER |
| **Tür** | Hibrit-casual refleks kaçış (sonsuz tırmanış + kalıcı ilerleme) |
| **Platform** | Android (Google Play), ileride web |
| **Ekran** | Dikey, tek elle |
| **Kontrol** | Tek dokunuş |
| **Diller** | Türkçe, İngilizce |
| **Hedef kitle** | Kısa oturumlarda refleks oyunu oynayan geniş kitle (13+) |
| **Tur süresi hedefi** | Ortanca 45–90 sn |
| **Fiyat modeli** | Ücretsiz; oyuncunun isteğiyle izlenen ödüllü reklam (M7) |

**Tek cümlelik vaat:** *Çöken bir dijital dünyada müziğin ritmiyle duvardan duvara yerçekimini çevir, kıl payı kaç ve Büyük Depolama Birimi'ne tırman.*

## 2. Tasarım sütunları

Her tasarım kararı bu dört sütuna göre tartılır:

1. **Tek dokunuş, sonsuz ustalık.** 10 saniyede öğrenilir, haftalarca ustalaşılır.
2. **Her ölüm benim hatam.** Adaletsiz hissettiren her şey hatadır.
3. **Dünya müzikle akar.** Engeller, renk ve hız müziğin parçasıdır.
4. **Her tur bir şey kazandırır.** Ölüm bile ilerlemedir (Glimmer, rekor, açılan sektör).

## 3. Hikâye ve ortam

- **Sen:** Çökmekte olan dijital bir dünyada kalan son **Enerji Çekirdeği**'sin (Core).
- **Tehdit:** Veriler aşağıdan yukarıya doğru yok oluyor: **Çöküş**.
- **Hedef:** Yukarıdaki **Büyük Depolama Birimi**'ne (The Great Storage) ulaşmak.
- **Anlatım:** Hikâye metinle değil, dünyayla anlatılır: sektör adları, renkler, peşindeki glitch duvarı ve finaldeki varış anı.

## 4. Kontroller

- **Ekrana herhangi bir yere dokun → yerçekimi diğer duvara döner.** Başka kontrol yok.
- Çevirme yalnızca bir duvara tutunurken yapılabilir. Oyuncuyu kollayan iki kural var:
  - Havadayken yapılan dokunuş kaybolmaz; duvara değince uygulanır (dokunma tamponu).
  - Duvar boşluğuna girdikten hemen sonra da çevirme yapılabilir (coyote süresi, 0,1 sn; M2-11).
- Duraklatma düğmesi sağ üstte. Ona dokunmak çevirme sayılmaz.

## 5. Çekirdek döngü

```
  ┌────────────── TUR (45–90 sn) ──────────────┐
  │ Başla → Tırman → Engellerden kaç           │
  │        → Glimmer topla → Kıl payı kombo    │
  │        → Sektör geç → … → Öl               │
  └───────────────────────┬────────────────────┘
                          ▼
  Sonuç ekranı: yükseklik · rekor · "rekora X m" · kazanılan Glimmer
                          │
         ┌────────────────┴────────────────┐
         ▼                                 ▼
  Tekrar (tek dokunuş, < 0,5 sn)    Yükseltmeler / İzler
         │                                 │
         └──────────────◄──────────────────┘
```

**Meta döngü:** Glimmer → yükseltmeler → daha uzağa tırmanma → yeni sektörler (renk, müzik, engel) → kontrol noktaları → Büyük Depolama Birimi → Taşma (sonsuz).

## 6. Dünya ve tehlikeler

Karakter iki dikey duvar arasındaki bir koridorda **yukarı** tırmanır ve her zaman bir duvara doğru çekilir.

| Tehlike | Davranış | İlk sektör |
| --- | --- | --- |
| **Diken** | Duvara yapışık, sabit. Olduğun duvarda diken varsa diğer duvara geç. | S1 |
| **Duvar boşluğu** | Duvarda açıklık; tutunduğun duvar biterse koridordan düşersin. | S2 |
| **Veri bloğu** | Koridorun ortasında süzülen blok; geçiş yolunu keser. | S2 |
| **Lazer kapısı** | Vuruşa göre açılıp kapanan yatay lazer. | S3 |
| **Dönen şekil** | Vuruş temposunda dönen köşeli engel. | S4 |
| **Hareketli blok** | Duvarlar arasında ritimle gidip gelen blok. | S4 |

**Şekil dili (erişilebilirlik):**

- Tehlike = sivri ve köşeli.
- Toplanabilir = yuvarlak.
- Oyuncu = elmas.

Renk körü bir oyuncu da **yalnızca şekle bakarak** oynayabilmelidir.

## 7. Ölüm, kalkan ve diriliş

- **Tek çarpmada ölüm.** Can ya da kalp sistemi yok.
- **Ölüm nedenleri:** tehlikeye çarpma, duvar boşluğundan düşme, çöküş duvarına yakalanma.
- **Kalkan:** Tek bir darbeyi emer. Ardından 1 sn dokunulmazlık gelir ve çöküş duvarı biraz yaklaşır.
- **Diriliş** (tur başına en fazla 1 ücretsiz + 1 reklamlı):
  - Yakındaki tehlikeler temizlenir.
  - Çöküş duvarı geri itilir.
  - 2 sn dokunulmazlık verilir.
  - Müzik kaldığı yerden devam eder.

## 8. Puanlama

- **Skor = tırmanılan yükseklik (metre).** Tek, anlaşılır, karşılaştırılabilir bir sayı. Arayüzdeki gösterim: `1045 m`.
- **Rekor çizgisi:** Oyun dünyasında, kişisel rekorun yüksekliğinde parlayan yatay bir çizgi. Oyuncu yaklaştıkça heyecan artar.
- **Sonuç ekranı:** "YENİ REKOR!" ya da "Rekora 120 m kaldı!"
- Kıl payı ve kombolar **skoru değil Glimmer'ı** artırır (skor sade kalsın).
- Kontrol noktasından başlanan turlarda skor mutlak yükseklikten sayılır (Sektör 3'ten başlayan oyuncu 1750 m'den başlar).

## 9. Glimmer ekonomisi

### 9.1 Kaynaklar

| Kaynak | Değer (başlangıç) |
| --- | --- |
| Glimmer parçacığı | 1 (kombo çarpanıyla artar) |
| Kombo çarpanı | Zincirde 3 kıl payı → ×2, 6 kıl payı → ×3 |
| Sektör tamamlama bonusu | 25 × sektör numarası |
| Glimmer Çarpanı yükseltmesi | +%10 / seviye |
| Ödüllü reklam (M7) | Tur sonu kazancı ×2 |

Glimmer yoğunluğu üst sektörlerde artar ve **riskli yollara** yerleştirilir: cesaret ödüllendirilir.

### 9.2 Harcama yerleri

Yükseltmeler (§10) ve kozmetik izler (§11).

### 9.3 Tempo hedefleri

- İlk yükseltme **2.–3. turda** alınabilmeli.
- Tüm yükseltmeleri tamamlamak düzenli oynayan biri için **yaklaşık 2 hafta** sürmeli (toplam ≈ 22.000 Glimmer).
- Tur başına ortalama kazanç başta 30–60, orta aşamada 100–200 Glimmer.

## 10. Kalıcı yükseltmeler

Maliyet formülü: `taban × 2^(seviye-1)`

| Yükseltme | Etki | Seviye | Maliyetler (başlangıç) |
| --- | --- | --- | --- |
| **Mıknatıs** | Glimmer çekim yarıçapı: 90 / 130 / 170 / 210 / 250 px | 5 | 100 · 200 · 400 · 800 · 1600 |
| **Kalkan** | Sv1: tura kalkanla başla. Sv2–5: kırılan kalkan 1500 / 1200 / 900 / 600 m sonra yenilenir | 5 | 150 · 300 · 600 · 1200 · 2400 |
| **Başlangıç Sıçraması** | Tur başında dokunulmaz sıçrama, yoldaki Glimmer'ları toplar: 100 / 200 / 300 / 400 / 500 m | 5 | 120 · 240 · 480 · 960 · 1920 |
| **Glimmer Çarpanı** | Kazanılan Glimmer +%10 / +%20 / … / +%50 | 5 | 200 · 400 · 800 · 1600 · 3200 |
| **İkinci Şans** | Her turda bir kez ücretsiz diriliş | 1 | 5000 |

**Bilerek olmayan yükseltme: Maksimum Hız.** Hız oyunun zorluk eğrisinin ve müziğin parçasıdır; satın alınamaz (bkz. §13).

**Günlük meydan okumada** oynanışı etkileyen tüm yükseltmeler kapalıdır; yalnızca kozmetik izler geçerlidir.

## 11. Kozmetik izler

- Çekirdeğin arkasında bıraktığı neon iz. Görsel tatmin ve paylaşılabilirlik için.
- **Satın alınanlar** (300–3000 Glimmer): renk geçişleri, kalınlık, parıltı desenleri.
- **Başarımla açılanlar** (satın alınamaz, statü göstergesi):
  - "Büyük Depolama Birimi'ne ulaş"
  - "Toplam 500 kıl payı"
  - "7 gün üst üste günlük meydan okuma"
- Oyuncunun kendi rengi (**beyaz çekirdek**) değişmez. Kozmetik olan yalnızca izdir; böylece okunabilirlik bozulmaz.

## 12. Sektörler ve ilerleme hissi

| # | Ad (TR / EN) | Çevre rengi | BPM | Tırmanış hızı | Uzunluk | Bitiş yüksekliği | Yeni öğe |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S1 | ÖNYÜKLEME / BOOT SEQUENCE | Camgöbeği | 100 | 12 m/sn | 750 m | 750 m | Diken |
| S2 | VERİ AKIŞI / DATA STREAM | Mor | 110 | 14 m/sn | 1000 m | 1750 m | Boşluk, veri bloğu |
| S3 | GÜVENLİK DUVARI / FIREWALL | Kehribar | 120 | 16 m/sn | 1500 m | 3250 m | Lazer kapısı |
| S4 | ÇEKİRDEK / KERNEL | Eflatun | 128 | 18 m/sn | 1750 m | 5000 m | Dönen şekil, hareketli blok |
| S5 | BOZULMA / CORRUPTION | Beyaz + glitch | 140 | 20 m/sn | 2500 m | 7500 m | Hepsi, yoğun |
| ★ | **BÜYÜK DEPOLAMA BİRİMİ / THE GREAT STORAGE** | — | — | — | — | 7500 m | Final anı + başarım izi |
| ∞ | TAŞMA / OVERFLOW | Döngüsel | 140+ | 22 m/sn (tavan) | Sonsuz | — | Remiks desenler |

**Renk kuralı:** **Kırmızı** (tehlike) ve **yeşil** (Glimmer) hiçbir sektörde çevre rengi olarak kullanılmaz. Oyuncu çekirdeği her zaman beyazdır. Kesin renkler M3'te birlikte seçilecek.

**Sektör geçişi ("nefes alma" anı, 2–3 sn):**

1. Engeller durur; kısa bir boş koridor gelir.
2. Ekranda sektör afişi belirir ("SEKTÖR 2 · VERİ AKIŞI").
3. Renk dalgası aşağıdan yukarıya yayılır; müzik ölçü sınırında yeni parçaya geçer.
4. Hız bir basamak artar; küçük bir Glimmer bonusu verilir.

**Kontrol noktaları:**

- Ulaşılan her sektörün başlangıcı açılır. Tur başlarken hangi sektörden başlanacağı seçilebilir.
- Bu sayede Sektör 4'e ulaşmak için her seferinde 5000 m tırmanmak gerekmez.

**Final ve sonrası:** Büyük Depolama Birimi'ne varış, oyunun "hikâye sonu"dur: kısa bir varış anı ve özel bir iz. Ardından Taşma modu sonsuza kadar devam eder.

## 13. Hız ve zorluk

- **Hız, sektörle ve müzikle birlikte artar.** Sektörün içinde sabittir; zorluk sektör içinde **desenlerle** artar.
- **Sektör içi eğri (M2-10):** Her sektörün bir zorluk aralığı vardır (S1: 1→3, S2: 2→4, S3: 2→5; ilk değerler). Sektör boyunca seçilen desenler bu aralığın başından sonuna doğru zorlaşır; aynı desen art arda (son 3 desen içinde) tekrar gelmez.
- **Zorluğun kolları:**
  1. Hız (yalnızca sektör geçişinde)
  2. Engel sıklığı
  3. Desen karmaşıklığı (art arda çevirmeler)
  4. Hareketli engeller
  5. Güvenli boşluğun genişliği
- **Hız tavanı:**
  - Engelin ekranda belirmesiyle oyuncuya ulaşması arasındaki süre ~1,2 sn'nin altına inmez.
  - İki zorunlu çevirme arasındaki süre, çevirme süresi + tepki payının altına inmez. Tepki payı başlangıçta **0,2 sn** (iki çevirme arası en az ≈ 0,57 sn); M2-18 oyun testinde gözden geçirilir.
  - Tavandan sonra zorluk yalnızca desenlerle artar.
- **Hız hissi, gerçek hızdan ucuzdur:** paralaks katmanları, hız çizgileri, uzayan iz ve yoğunlaşan müzik oyunu gerçekte hızlandırmadan daha hızlı hissettirir.
- **Oyuncu hızı değil baskıyı etkiler** (bkz. §14).

### 13.1 Onaylanan his değerleri (M1-14, 2026-10-11)

Telefonda ayar paneliyle oynandı; başlangıç değerleri değiştirilmeden onaylandı. Geçerli kaynak: `data/tuning/default_tuning.tres`.

| Değer | Onaylı | Not |
| --- | --- | --- |
| Tırmanış hızı (S1) | 12 m/sn | Diğer sektörlerin hızları §12'deki tabloda; M2-08'den beri `data/sectors/` kaynaklarında |
| Duvara çekim ivmesi | 300 m/sn² | Bu ikisiyle duvardan duvara geçiş ≈ 0,37 sn |
| En yüksek yan hız | 64 m/sn | |
| Dokunma tamponu | 0,12 sn | Duvara varmadan hemen önceki dokunuş affedilir |
| Çarpışma kutusu | görselin %70'i | |
| İleri görüş (oyuncunun üstünde) | 28 m | S1'de engel 2,3 sn önce görünür; 22 m/sn tavanında 1,27 sn (≥ 1,2 sn kuralı tutuyor) |
| Koridor genişliği | 18 m | |

Tur başında ilk desen parçasına kadar boşluk: 25 m, tam vuruşa yuvarlanır (S1'de 28,8 m). M1'in geçici diken aralığı (10 m) M2-04'te desen parçalarıyla kalktı.

## 14. Çöküş duvarı (baskı)

- Aşağıdan gelen, glitch'li bir veri yok oluşu. Oyuncunun tırmanış hızından biraz daha hızlı ilerler; aradaki fark aşağıdaki tablodaki "sürünme" hızıdır.

| Olay | Etki (başlangıç) |
| --- | --- |
| Zamanla sürünme | S1: 0,3 m/sn → S5: 0,8 m/sn |
| Glimmer toplamak | +1 m (duvarı iter) |
| Kıl payı geçiş | +3 m |
| Kalkanla darbe almak | −8 m (duvarı çeker) |
| Başlangıç mesafesi / en fazla | 20 m / 30 m |

- Duvar ekrana girdiğinde kenarlarda kırmızı bir vinyet belirir ve gerilim sesi yükselir.
- **Amaç öldürmek değil, gerilim yaratmaktır.** S1'de duvar çok yavaştır. Pasif ve aşırı temkinli oynayan oyuncu er geç yakalanır; cesur oynayan rahat nefes alır.

## 15. Kıl payı ve kombo

- Bir tehlikenin dibinden çarpmadan geçmek = **kıl payı**.
- **Anında geri bildirim:**
  - Kısa bir yavaş çekim (0,5×, 0,25 sn). Müzik de aynı oranda yavaşlar, bant yavaşlaması gibi.
  - "KIL PAYI!" yazısı ve parlama.
  - Çöküş duvarı geri itilir.
- **Kombo:** 2,5 sn içinde gelen her yeni kıl payı zinciri uzatır. Zincir büyüdükçe Glimmer çarpanı ×2, ×3'e çıkar.
- Yavaş çekim her kıl payında tekrarlanırsa yorucu olabilir: zincirin ilk halkasında ve kombo eşiklerinde tetiklenir (ayarla kesinleşecek).

## 16. Ritim

- Her sektörün BPM'i bellidir. Engeller vuruşlara ve yarım vuruşlara yerleşir; dünya "müziğe göre akar".
- **Dokunuşlar müziğe göre yargılanmaz.** Çarpışma konuma göre belirlenir; Android ses gecikmesi oyuncuyu cezalandırmaz.
- **Sessiz oynayanlar için:** Oyuncuların büyük kısmı mobilde sesi kapalı oynar. Ritim görsel olarak da hissedilmeli: arka plan ağı ve duvar kenarları vuruşta nabız atar.

## 17. Günlük meydan okuma

- Her gün herkes **aynı haritayı** oynar (tohum = UTC tarihi).
- Oynanışı etkileyen yükseltmeler kapalı; herkes S1'den başlar.
- Sonuç, tek dokunuşla paylaşılabilen bir **skor kartına** dönüşür (yükseklik, tarih, kıl payı sayısı, küçük harita izi).
- Deneme hakkı: açık karar D-04 (önerim: sınırsız deneme, en iyi sonuç sayılır).

## 18. İlk açılış deneyimi (FTUE)

- Menü yok, metin yok: uygulama açılınca **doğrudan** oyun başlar.
- İlk parça: uzun, boş bir duvar ve tek bir diken. Ekranda dil gerektirmeyen, nabız atan bir "dokun" eli ikonu belirir.
- Tehlikeler tek tek tanıtılır; ilk sektör 3–5 turda geçilebilir olmalı.
- İlk ölümden sonra sonuç ekranı ve ilk Glimmer'lar → "Yükseltmeler" düğmesi parlar.

## 19. Ses ve his

- **Efektler:** çevirme, duvara tutunma, Glimmer, kıl payı, kombo eşiği, kalkan kırılması, ölüm, sektör geçişi, rekor kırma, UI tıklamaları.
- **Müzik:** Her sektöre bir döngü. Menüde sakin bir tema.
- **Titreşim:** çevirmede çok hafif, kıl payında kısa, ölümde belirgin. Ayarlardan kapatılabilir.
- **Oyun hissi (juice):** ölümde kısa donma ve sarsıntı, çevirmede sıkışma-uzama, Glimmer'da parçacık patlaması.

## 20. Arayüz ekranları

| Ekran | İçerik |
| --- | --- |
| **HUD** | Sol üst: yükseklik (m). Üst orta: sektör adı (geçişte büyür). Sağ üst: duraklat, altında Glimmer sayısı. Oyuncunun yanında kombo. Kenarlarda duvar vinyeti. |
| **Sonuç** | Yükseklik, rekor durumu, kazanılan Glimmer. Büyük "Tekrar" düğmesi; "Diriliş (reklam)", "Yükseltmeler". |
| **Ana menü** | Başla (sektör seçimi), Günlük, Yükseltmeler, İzler, Ayarlar |
| **Yükseltmeler / İzler** | Kartlar: mevcut seviye, sonraki etki, maliyet |
| **Ayarlar** | Müzik, efekt, titreşim, dil, efekt kalitesi, 60 FPS sınırı, Hakkında (lisanslar) |

## 21. Gelir modeli (M7)

- **Ödüllü reklam, yalnızca oyuncu isterse:** diriliş (tur başına 1) ve tur sonu Glimmer ×2.
- **Zorunlu geçiş reklamı:** açık karar D-03 (önerim: yok ya da çok seyrek).
- **Kazanmak için ödeme (pay-to-win) yok.** Olası ileri adım: kozmetik iz paketleri.

## 22. Viral özellikler (özet)

- Kıl payı anları: kısa, klip çekilmeye uygun, tatmin edici.
- Dikey ekran: oyun videoları TikTok / Reels / Shorts'a doğrudan uyar.
- Günlük meydan okuma ve paylaşım kartı: arkadaşlar arası rekabet.
- Rekor çizgisi ve "rekora X m kaldı": "bir kez daha dene" tetikleyicisi.
- Güçlü ilk 5 saniye: menüsüz, anında oyun.

## 23. Açık tasarım soruları

| # | Soru | Ne zaman |
| --- | --- | --- |
| D-02 | Müzik kaynağı: CC0 paketler mi, BeepBox ile kendi bestemiz mi? | M3 |
| D-03 | Zorunlu geçiş reklamı olacak mı? | M7 |
| D-04 | Günlük meydan okumada deneme hakkı | M7 |
| — | Sektör renklerinin kesin tonları | M3 |
| — | Tüm sayısal değerler (hız, uzunluk, maliyet, basınç) | M1–M4, ayar paneliyle |
