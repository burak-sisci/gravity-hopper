# Müzik ve ses araştırması (D-02)

> 2026-10-13 · Kullanıcı isteği: "Ses ve müzik oyuncuyu oyuna bağlayan önemli etkenlerden biri. Olacak en güzel şekilde, profesyonel olanı yapalım." Bu belge seçenekleri, riskleri ve önerimi toplar. **Karar kullanıcınındır** (`state.json` → D-02). Kaynaklar en altta; çoğu ikincil kaynak olduğu için lisans ve fiyat bilgileri karar öncesinde ilgili tarafın güncel şartlarıyla doğrulanmalıdır.

> **Karar (2026-10-13, ADR-038):** Müzik **ücretsiz kütüphanelerden** (CC0 / CC-BY) gelir. Bir ana tema parçası menüde ve S1'de çalar; sonraki sektörler aynı tarzda kendi parçalarını çalar. Uygulama planı §10'da. §1–§7 araştırma kaydı olarak duruyor; §5'teki tür ve his tablosu ile §6'daki teknik plan hâlâ geçerli.

## 1. Kısa sonuç

- **Popüler (ticari) şarkılar uygun değil.**
  - Her şarkı için iki ayrı lisans gerekir: beste için "sync", kayıt için "master".
  - Bağımsız işlerde şarkı başına yüzlerce ile birkaç bin dolar, bilinen şarkılarda on binlerce dolar tutar.
  - Şarkıların temposu sektörlerimizin sabit BPM'lerine uymaz.
  - Proje kuralımız (`.clauderules` §7: ses için yalnızca CC0 / CC-BY) bunu dışarıda bırakır.
- **Önerim: oyuna özel, katmanlı (adaptif) bir müzik.** Her sektörün kendi temasını o sektörün BPM'inde yazdırmak (S1 100 … S5 140). Parçalar katmanlar (stem) hâlinde teslim edilir; kombo, çöküş duvarı ve sektör geçişi müziği canlı olarak değiştirir. Ritim oyunlarında profesyonel yaklaşım budur: Geometry Dash, Rayman Legends ve Thumper'da müzik ile bölüm birlikte tasarlanır.
- **Nasıl yapılır:** İki yol var; aşağıda "üretim yolu" bölümünde.
  - Bütçe varsa bağımsız bir besteciyle sözleşmeli iş.
  - Bütçe yoksa CC-BY kütüphanelerden sektör BPM'ine uyan parçalar. BPM'ler veri dosyasında durduğu için parçaya göre ayarlanabilir.
- Altyapımız hazır:
  - Vuruş saati, ses senkronu ve tempo değişimi yazıldı (M2-07, M2-08).
  - Godot 4.7'de katmanlı müzik için hazır sınıflar var: `AudioStreamSynchronized` ve `AudioStreamInteractive`.

## 2. Neden bu kadar önemli

- **Oyunun kimliği müzik:** GDD'nin üçüncü ilkesi "Dünya müzikle akar". Engeller vuruşa oturuyor (M2-03, M2-07); müzik oyun alanını tasarlıyor.
- **Oyuncuların bir kısmı sesi kapalı oynar.** Kaynaklar çelişkili: bir ankette yalnızca %8 sesi açık oynuyor, eski bir ölçümde %73'ün sesi %10'un üstünde. Bu yüzden ritim görsel olarak da verilir (GDD §16: arka plan ve duvarlar vuruşta nabız atar). Sesi açık oynayan için ise müzik bağlılığın ana kaynağıdır.
- **Tekrar yorgunluğu döngülü müziğin bilinen sorunudur.** Bir tur birkaç dakika sürer, oyuncu da günde onlarca tur atar. Tek parça döngü kısa sürede bıktırır. Katmanlar ve sektör değişimi bunu kırar.

## 3. Bizim sistemden gelen teknik gereksinimler

| Gereksinim | Neden |
| --- | --- |
| Her sektör parçası **tam o sektörün BPM'inde**, 4/4 ölçü | Engeller vuruş ızgarasında; tempo sapması dikenlerin vuruşta geçmesini bozar (M2-07 testi) |
| Sektör içinde tempo değişmez | Tırmanış hızı sektörde sabit; hız basamağı yalnızca sektör geçişinde |
| Döngü noktası ölçü sınırında, tıkırtısız | Godot `AudioStreamOggVorbis.loop` + `beat_count` döngüyü ölçüye bağlar |
| Katmanlar (stem) aynı uzunlukta ve aynı tempoda | `AudioStreamSynchronized` hepsini birlikte çalar, ses düzeyleri ayrı ayrı kısılıp açılır |
| Sektör geçişi ölçü sınırında, kısa bir geçiş parçasıyla | GDD §12: "müzik ölçü sınırında yeni parçaya geçer"; `AudioStreamInteractive` geçişi bir sonraki vuruşa ya da ölçüye bekletebilir |
| OGG Vorbis, yaklaşık 96–128 kbps | Mobil boyut: dakikası yaklaşık 1 MB. MP3 döngü başına sessizlik ekler, kullanılmaz |
| Android gecikmesi telafisi | Android gecikmeyi 0 bildiriyor (S-03); oyuncu için "ses kaydırma" ayarı gerekebilir (M5) |

## 4. Seçenekler

### A. Popüler / ticari şarkılar

- **Lisans:** Beste için yayıncıdan sync, kayıt için plak şirketinden master lisansı alınır. Fragman ve yayıncı (streamer) kullanımı genellikle ayrıca ödenir.
- **Maliyet:** Bağımsız oyunlarda şarkı başına 500–5.000 $; bilinen şarkılarda on binlerce dolar ve üstü. Fiyat şarkıya ve oyunun erişimine göre değişir.
- **Teknik:** Tempolar sektör BPM'lerimize uymaz. Uydurmak için müziği hızlandırıp yavaşlatmak (time-stretch) kaliteyi bozar.
- **Risk:** Lisanssız kullanımda Google Play uygulamayı kaldırabilir. Yayıncıların videoları da telif uyarısı alabilir; bu, pazarlamamızın (kısa dikey videolar) önünü keser.
- **Sonuç:** Önerilmez.

### B. NoCopyrightSounds (Geometry Dash modeli)

- 2024'te NCS 1.500'den fazla parçasını Geometry Dash'e verdi. Bu, iki şirket arasında **özel bir ortaklık**.
- NCS'nin ücretsiz şartları videolar içindir. Satılan oyunlar gibi ticari işler için ayrı lisans gerekir (lisans e-postası üzerinden).
- **Sonuç:** Mümkün, ama pazarlık ve ücret gerektirir. Yine BPM uyumu ve özgün kimlik sorunu kalır.

### C. CC-BY / CC0 kütüphaneler (Incompetech, OpenGameArt, Free Music Archive…)

- **Lisans:** Kurallarımıza uygun ve ücretsiz. CC-BY'de kredi zorunlu; örneğin Kevin MacLeod için tam kredi satırı. Lisans her parçanın sayfasından tek tek okunmalı.
- **Pixabay:** Kendi lisansı var; CC0 ya da CC-BY değil, kural listemizde yok.
- **Artısı:** Bedava, hemen kullanılabilir. Sektör BPM'leri veri dosyasında durduğu için parçanın BPM'ine göre ayarlanabilir.
- **Eksisi:**
  - Kalite ve üslup değişken.
  - Bazı parçalar binlerce videoda duyulduğu için "tanıdık" gelir; özgün bir kimlik oluşturmaz.
  - Katman (stem) dosyası nadiren bulunur, adaptif müzik zorlaşır.
- **Sonuç:** Düşük bütçeli ve sağlam bir yol. Oyun "iyi" olur ama "akılda kalan" olmaz.

### D. Bağımsız besteciyle oyuna özel müzik (önerilen)

- **Maliyet:**
  - Bağımsız besteciler dakika başına yaklaşık 100–1.000 $ alır.
  - Yeni ya da hobi düzeyindekiler 30–300 $/dk; deneyimli olanlar 200–1.000 $/dk.
  - Bağımsız oyunlarda toplam müzik bütçesi çoğunlukla 1.000–10.000 $.
- **Bizim kapsamımız:** 5 sektör × ~2 dk döngü + katmanlar + Taşma remiksi + menü + kısa parçalar (stinger), yani ≈ 12–16 dk müzik. Tahmini toplam ≈ 1.500–10.000 $ (bestecinin deneyimine göre); teklif alınmadan kesin değil.
- **Artısı:**
  - Tam bizim BPM'lerimizde, katmanlı ve döngüye uygun yazılır.
  - Özgün kimlik ve "bu oyunun müziği" hissi oluşur.
  - Fragman ve yayıncı kullanımı sözleşmeye yazılabilir.
- **Lisans:** "Tam devir (buyout)" ya da "münhasır olmayan, süresiz, dünya çapında, oyun ve tanıtım için" lisans; ikisinde de kredi. Bu, kural listemizde (CC0/CC-BY) olmadığı için kabul edilirse `.clauderules` §7'ye "sözleşmeli ısmarlama eser" eklenir (ADR).
- **Bulma:** itch.io, bağımsız oyun bestecisi toplulukları, Fiverr/Upwork. Önce birkaç bestecinin portföyü dinlenir, kısa bir deneme parçası istenir.

### E. Yapay zekâ müzik üreticileri

- **Suno:**
  - Ücretli planlarda ticari kullanım var; üst planda katman (stem) indirilebiliyor.
  - Sonradan abone olmak, ücretsiz planda üretilmiş parçaları geriye dönük kapsamıyor.
  - Telif sahipliği belirsiz: tamamen yapay zekâ üretimi eser telif korumasına girmeyebilir.
  - Sony'nin davaları sürüyor.
- **Udio:** Plak şirketi uzlaşmasından sonra indirme ve katmanları kapattı; oyun için kullanılamaz.
- **ElevenLabs Music:**
  - Lisanslı veriyle eğitildiğini söylüyor (Merlin, Kobalt).
  - Ancak kendi kendine abone olunan planlarda "studio games" kapsam dışı; oyun için kurumsal (Enterprise) plan gerekebilir.
- **Sonuç:** Hukuki zemin 2026'da hâlâ oynak. Yayındaki oyunda ana müzik olarak riskli. **Yön bulmak için geçici müzik** (tür ve his denemesi, besteciye örnek göstermek) olarak çok değerli.

### F. Kodla üretilen (prosedürel) müzik

- Bizim metronomumuz gibi koddan üretilir. Senkron mükemmel, boyut sıfır, sonsuz çeşitlilik var.
- Duygu ve üretim kalitesi el yapımı müziğin gerisinde kalır; iyi sonuç ciddi ses tasarımı ustalığı ister.
- **Sonuç:** Ana müzik olarak önerilmez. **Tamamlayıcı olarak çok iyi:**
  - Glimmer toplama notaları sektörün tonunda ve kombo büyüdükçe yükselen perdeyle çalınabilir (Two Dots'taki gibi müzikle uyumlu).
  - Vuruş vurguları da koddan üretilebilir.

## 5. Önerilen müzik tasarımı (seçenek D ya da C ile)

- **Tür:** Oyunun neon / veri dünyasına uygun elektronik müzik (synthwave, electro, drum & bass). Sektörlerle birlikte yoğunlaşır:

  | Sektör | BPM | His önerisi |
  | --- | --- | --- |
  | S1 Önyükleme | 100 | Sakin, sıcak synth arpejleri; açılış, öğrenme |
  | S2 Veri akışı | 110 | Nabız gibi atan bas, akan arpejler |
  | S3 Güvenlik duvarı | 120 | Sert, endüstriyel bas, uyarı sesleri |
  | S4 Çekirdek | 128 | Kulüp temposu, sürükleyici |
  | S5 Bozulma | 140 | Glitch, drum & bass, kaos |
  | ★ / ∞ Taşma | 140+ | Final teması; ardından önceki temaların remiksleri |

- **Katmanlar (dikey):** Her parça 3–4 katman.
  1. Davul + bas: hep çalar.
  2. Ana melodi.
  3. Yoğunluk katmanı: kombo ×2/×3'te ya da uzun hayatta kalışta açılır.
  4. Gerilim katmanı: çöküş duvarı yaklaşınca (`wall_proximity_changed`) açılır ya da müziğin tizleri kısılır (filtre).
- **Geçişler (yatay):** Sektör geçişinde "nefes alma" boşluğunda bir ölçülük geçiş parçası, ardından yeni tema tam ölçü sınırında başlar.
- **Olay sesleri ve müziğe dokunan anlar:**
  - **Ölüm:** Müzik "bant durması" gibi perdesi düşerek kesilir.
  - **Kıl payı:** Yavaş çekimde müzik de yavaşlar; bu zaten kurulu (`pitch_scale`).
  - **Rekor kırma:** Kısa bir zafer parçası (stinger).
- **Ses efektleri (D-05):**
  - Müzikle aynı tonda tasarlanır.
  - Çevirme efekti dokunuş anında çalar; ritme bekletilmez, çünkü dokunuşlar müziğe göre yargılanmaz (GDD §16).

## 6. Teknik uygulama planı (M3-10'da)

1. `AudioManager`: metronomun yerine `AudioStreamSynchronized` (sektörün katmanları) çalar.
   - Hizalama kodu (M2-07) aynen kullanılır: duyulan konum = vuruş saati.
   - Katman ses düzeyleri `Events.near_miss`, `combo_ended` ve `wall_proximity_changed` olaylarıyla değişir.
2. Sektör geçişi: `AudioStreamInteractive` ya da mevcut tempo değişimi (M2-08). Yeni parça, ızgaranın başladığı anda başlar.
3. OGG içe aktarma ayarları: `bpm`, `beat_count`, `bar_beats` = 4, `loop`.
4. Android'de "ses kaydırma" ayarı (M5-05), kulak testine göre (S-03).
5. Testler: her parçanın uzunluğu tam ölçü katı, BPM'i sektörle aynı.

## 7. Üretim yolu (aşamalı)

| Aşama | Ne | Ne zaman |
| --- | --- | --- |
| 1 | Kullanıcı 3–5 referans parça seçer ("böyle hissettirsin") ve bütçeyi belirler | Şimdi (D-02) |
| 2a | Bütçe varsa besteci: kısa brief (BPM'ler, 4/4, ölçü sayısı, katman listesi, OGG, lisans), 2–3 bestecinin deneme parçası, sözleşme | M3 başlamadan |
| 2b | Bütçe yoksa: CC-BY kütüphanelerden sektör başına aday parçalar, sektör BPM'leri onlara göre ayarlanır, katmansız sürüm | M3-10 |
| 3 | İsteğe bağlı: yapay zekâyla geçici müzik, yalnızca deneme ve besteciye örnek; yayına girmez | Aşama 2 sürerken |
| 4 | Entegrasyon ve kulak testi (S-03) | M3-10 |

## 8. Kullanıcıya sorular ve cevaplar (2026-10-13)

1. **Bütçe:** Müzik için para ayırabilir misin? → **Hayır.**
2. **Referanslar:** Sevdiğin 3–5 oyun müziği ya da şarkı. → **Subway Surfers gibi, oyunla özdeşleşen bir tema müziği.**
3. **Yapay zekâ:** Yalnızca deneme amacıyla kullanılmasına onay veriyor musun? → **Evet.**
4. **Lisans kuralı:** Besteci seçilirse `.clauderules` §7'ye "sözleşmeli ısmarlama eser" eklenmesine onay veriyor musun? → **Evet**, eklendi (ADR-037).

## 9. Bütçesiz imza tema planı (2026-10-13)

- **Model: Subway Surfers.** Oyunda 2012'den beri aynı ana tema çalar; her şehir güncellemesinin müziği bu temanın o şehrin tarzında bir remiksidir ([Subway Surfers hayran wikisi](https://subwaysurf.fandom.com/wiki/File:BoomboxChangeMusic1.jpg), ikincil kaynak).
- **Bizde:** Her sektör, ana temanın o sektörün BPM'inde ve tarzında yeniden düzenlenmiş hâlini çalar. Oyuncu melodiyi tanır; sektör değişince tanıdık melodi yeni bir kılıkta gelir. Teknik plan (§6) aynen geçerli: katmanlar, ölçü sınırında geçiş.
- **Tema taslağı:**
  - **İmza motifi:** 3+3+2 ritimde oktav sıçraması (A4 A4 E5 → A5). Duvardan duvara geçişin müzikteki karşılığıdır. Kısa, ıslıkla çalınabilir ve ilk iki saniyede tanınır.
  - **Akorlar:** Am – F – C – G, her ölçüde bir akor. Tema 8 ölçüdür; ikinci yarıda melodi yukarı tırmanır.
  - **Sektör düzenlemeleri:**
    - S1: yumuşak "pluck" melodi ve pad; davul ikinci yarıda girer.
    - S2: kare dalga melodi, arpej, dört vuruşlu davul.
    - S3: kalın synth melodi, 16'lık bas, açık zil.
    - S4–S5 ve menü sürümü ileride.
  - **Geçiş:** Son ölçüde süpürme sesi ve trampet dolgusu; yeni sektör ölçü başında zil vuruşuyla başlar.
- **Temayı kim üretir?** Açık soru (D-02):

  | Seçenek | Artı | Eksi |
  | --- | --- | --- |
  | **A. Claude kodla besteler** (`tools/theme_demo.py`) | Ücretsiz. BPM tam tutar, katmanlar istendiği gibi ayrılır, değişiklik dakikalar sürer. Örnek ses ya da başkasının kaydı kullanılmaz | Ses kalitesi synthwave / chiptune düzeyinde kalır. Yapay zekâ üretimi olduğu için telif koruması zayıf olabilir: başkası kopyalarsa engellemek zorlaşır. Yayına girmesi için kullanıcının yapay zekâ onayının yayını da kapsaması gerekir |
  | **B. Gönüllü ya da gelir ortaklığıyla çalışan besteci** | İnsan eli ve gerçek kalite; telif tam korunur | Besteciyi bulmak ve süreci yürütmek kullanıcının işidir. Zamanlama belirsizdir. Yazılı sözleşme şarttır (ADR-037) |
  | **C. CC-BY kütüphane** | Hızlı ve iyi kalite | Başka oyunlar da aynı parçayı kullanabilir; imza tema olamaz |

- Önerim A idi. Kodla üretilen 56 saniyelik deneme kaydının üreteci (`tools/theme_demo.py`) ilk commit'te (28a0c58) duruyor; karar C olunca depodan kaldırıldı.
- **Kullanıcı kararı: C, ücretsiz müzik kütüphanesi** (ADR-038).

## 10. Kütüphane planı (M3-10)

- **Lisans:**
  - Yalnızca CC0 ve CC-BY.
  - CC-BY-NC ve CC-BY-SA yasak (`.clauderules` §7). CC-BY-ND de alınmaz: döngü için kesmek bir uyarlama sayılabilir.
  - "YouTube'da ücretsiz" gibi CC olmayan özel lisanslar da alınmaz. Pixabay'in kendi lisansı bunlara bir örnek.
  - Her parçanın lisans sayfası bağlantısıyla birlikte `CREDITS.md`'ye ve oyun içindeki Hakkında ekranına yazılır.
- **Kaynaklar:**
  - OpenGameArt: lisans her parçada ayrı, filtre gerekir.
  - Free Music Archive: lisans parça başına değişir.
  - FreePD: CC0.
  - Incompetech: CC-BY 4.0, ama çok yaygın.
- **Seçim ölçütleri:**
  - Tür ve his: elektronik (synthwave, electro, drum & bass); §5'teki tablo geçerli.
  - Tempo: 4/4, sabit, sektör sırasıyla yükselen BPM'ler (≈ 95–145).
  - Döngü: temiz döngüye uygun ya da ölçü sınırında kesilebilir, en az 1,5 dakika.
  - Ses: telefon hoparlöründe melodi net duyulmalı.
  - Varsa katmanlar (stem).
  - Ana tema parçası kısa, akılda kalan bir melodiyle başlamalı.
  - Çok yaygın parçalar yerine az bilinenler tercih edilir.
- **Süreç:**
  1. Claude ana tema için ve sektör başına 3–4 aday listeler: bağlantı, lisans, BPM, süre.
  2. Kullanıcı dinleyip seçer (🤝).
  3. Seçime göre `SectorDef.bpm` ayarlanır. Parça doğrulayıcısı ve testler yeni tempolarla yeniden çalışır.
  4. OGG içe aktarma ayarları yapılır: BPM, vuruş sayısı, döngü.
  5. Kulak testi yapılır (S-03).
- **Adaptif his:**
  - Parçanın katmanları varsa §6'daki plan uygulanır.
  - Yoksa tek parça çalar, müzik veriyolundaki filtre çöküş duvarı yaklaştıkça tizleri kısar. Kıl payı yavaş çekimi zaten `pitch_scale` ile müziğe bağlı.

## Kaynaklar

- Lisans ve maliyet: [Foxi Music – Music Licensing for Game Developers (2026)](https://www.foximusic.com/blog/music-licensing-for-game-developers-guide/), [Bridge Legal – How Much Does It Cost to License a Song for a Game](https://bridgelegal.org/?p=11159)
- Geometry Dash ve NCS: [Music Business Worldwide](https://musicbusinessworldwide.com/nocopyrightsounds-and-geometry-dash-team-up-to-provide-free-music-for-gamers), [Game Developer basın bülteni](https://www.gamedeveloper.com/press-release/nocopyrightsounds-partners-with-music-game-geometry-dash-providing-free-to-use-music-for-gamers), [RobTop SSS – müzik](https://www.robtopgames.com/faq/en/answers/music), [Gwern wiki – NCS lisans iletişimi](https://www.gwern.net/wiki/Talk:NoCopyrightSounds), [clip.dor.gg – NCS kredi şartı](https://clip.dor.gg/en/blog/royalty-free-music-game-videos)
- Besteci ücretleri: [Ninichi Music](https://ninichimusic.com/blog/understanding-how-much-an-indie-game-music-composer-costs), [Orphiq](https://orphiq.com/resources/video-game-music-composers), [GamesBeat – 2 Mello](https://gamesbeat.com/the-indiebeat-composer-2-mellos-notes-for-starting-a-game-music-career/), [itch.io besteci profili](https://itch.io/profile/antonispat)
- Yapay zekâ müziği: [terms.law – Suno ticari haklar](https://terms.law/ai-output-rights/suno/), [Dubspot – AI music licensing 2026](https://blog.dubspot.com/ai-music-licensing-explained-2026), [Cinevva – AI music generators for games](https://app.cinevva.com/guides/ai-music-generators-games), [NisAI – Suno, Udio ve haklar](https://nisai.dev/guides/ai-music-generation-2026/), [Gradually – ElevenLabs Music](https://www.gradually.ai/en/elevenlabs-music/), [Music.ai – ElevenLabs lisans anlaşmaları](https://music.ai/news/music-tech/elevenlabs-launches-text-to-music-generator-with-licensing-deals/)
- Ücretsiz kaynaklar: [Cinevva – Free sound effects and music for games](https://app.cinevva.com/guides/free-sound-effects-music), [GTSTU – Free royalty-free music for indie games](https://gtstu.com/free-royalty-free-music-indie-games/)
- Adaptif müzik: [IRPR – vertical layering](https://sounddesign.irpr.agency/glossary/vertical-layering/), [IRPR – horizontal resequencing](https://sounddesign.irpr.agency/glossary/horizontal-resequencing/), [SBGames 2021 – ritim oyunu vaka çalışması](https://www.sbgames.org/proceedings2021/ComputacaoFull/218081.pdf), [Game Developer – Rayman Legends müzik ve bölüm tasarımı](https://www.gamedeveloper.com/audio/the-musical-box-27-game-music-level-design), [GDC – Soundfall](https://gdcvault.com/play/1028792/Independent-Games-Summit-Hitting-the), [Game Developer – rethinking the audio loop](https://www.gamedeveloper.com/audio/rethinking-the-audio-loop-in-games)
- Godot: [AudioStreamInteractive](https://docs.godotengine.org/en/4.3/classes/class_audiostreaminteractive.html), [AudioStreamOggVorbis](https://docs.godotengine.org/en/latest/classes/class_audiostreamoggvorbis.html), [uhiyama-lab – adaptive music in Godot](https://uhiyama-lab.com/en/notes/godot/adaptive-music-system/), [Godot PR #64488](https://github.com/godotengine/godot/pull/64488)
- Ses açık/kapalı oynama: [TapResearch](https://blog.tapresearch.com/how-sound-preferences-impact-player-engagement), [TouchArcade – %73](https://toucharcade.com/2013/11/05/73-of-mobile-gamers-play-with-the-sound-on/)
- Biçim ve döngü: [Bugnet – audio formats](https://bugnet.io/blog/which-audio-file-formats-should-your-game-use)
- Prosedürel müzik: [arXiv 2512.12834 – Procedural Music Generation Systems in Games](https://arxiv.org/pdf/2512.12834)
