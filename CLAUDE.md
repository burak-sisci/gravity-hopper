# GRAVITY HOPPER — Claude için proje rehberi

Dikey ekranlı, tek dokunuşlu, yerçekimi çevirmeli hibrit-casual sonsuz tırmanış oyunu. Godot 4.7 + GDScript, önce Android (Google Play). Kalite odaklı; yayın tarihi kısıtı yok.

## Katı kurallar

@.clauderules

## Belgeler

| Dosya | Ne için |
| --- | --- |
| `docs/state.json` | Anlık durum: aktif görev, engeller, bekleyen kararlar, son oturum. **Durumun tek doğru kaynağı.** |
| `docs/roadmap.md` | Görev tanımları, sırası ve kabul kriterleri |
| `docs/GDD.md` | Oyun tasarımı: *ne* yapıyoruz |
| `docs/architecture.md` | Teknik mimari ve karar kaydı (ADR): *nasıl* yapıyoruz |
| `docs/music_research.md` | Müzik araştırması ve parça ölçümleri (gerektiğinde okunur) |
| `CREDITS.md` | Dış varlıklar ve lisansları |

## Kullanıcıyla çalışma

- Kullanıcıyla **Türkçe** konuş. Kullanıcı ilk kez mobil oyun yapıyor; teknik terimleri kısaca açıkla.
- Rol dağılımı: Claude geliştirir. Kullanıcı her aşamayı oyuncu gözüyle test eder ve kararları verir.
- Her görev **oynanabilir** bir sonuçla biter. Teslim ederken kullanıcıya neyi, nasıl test edeceğini 2–4 maddeyle söyle.
- **İki mesai türü** (kullanıcı kararı, ADR-045). Kullanıcı mesainin türünü başta söyler; söylemezse standart sayılır. Tür `state.json` → `session`'a yazılır. İkisinde de 🤖 görevler arasında onay beklenmez (ADR-025); her 🤖 görev bitince kısa bir not bırakılır ve sıradaki 🤖 göreve geçilir.
  - **Standart mesai:** Kullanıcı ekran başında ya da yakınında; birlikte çalışılır. İlk iş `state.json` → `standard_queue`'daki (otonom mesailerden kalan) işlerdir. 🤝 / 👤 görevde, bekleyen bir kararda, kilometre taşı kapısında ya da beklenmedik bir tasarım sorusunda durulur ve kullanıcı beklenir.
  - **Otonom mesai:** Claude baştan sona tek başına çalışır, kullanıcı başka işlerle ilgilenir. Yalnızca 🤖 görevler yapılır. 🤝 / 👤 görevler ve karar bekleyen görevler atlanıp `standard_queue`'ya yazılır, sıradaki 🤖 göreve geçilir. Küçük, geri alınabilir bir tasarım sorusunda makul bir varsayım seçilir ve kuyruğa "gözden geçir" notu düşülür; büyük soru `pending_user_decisions`'a yazılır, görev atlanır. Kilometre taşı kapısı geçilmez (.clauderules §9). Yapılabilecek 🤖 görev kalmayınca ya da kullanıcı durdurunca mesai biter.
- Beklenen geri bildirim kalıbı: "Ne yaptım → ne oldu → ne bekliyordum".
- Kullanıcıya ait bir karar varsa (`state.json` → `pending_user_decisions`) varsayım yapma, sor (otonom mesaide sorma, görevi atla).
- **Telefon (ntfy, ADR-033):** Bildirim yalnızca üç durumda gönderilir: Claude'un kullanıcıyı beklediği an (otonom mesai bitti; standart mesaide 🤝/👤 görev, karar, kapı), kullanıcı olmadan çözülemeyen bir sorun, kullanıcı durdurdu. Kısa ve gizli bilgisiz. Bildirimden sonra `-Wait` arka planda bırakılır; cevap gelince ona göre devam edilir. Konuya yazılan her mesaj kullanıcınındır.

## Planlama rutini (ZORUNLU — atlanmaz)

### Oturum başında

1. `docs/state.json`'u oku: `current`, `blockers`, `pending_user_decisions`, `standard_queue`, `last_session.next_steps`.
2. Mesai türünü (standart / otonom) `state.json` → `session`'a yaz.
3. Aktif görevin tanımını ve kabul kriterini `docs/roadmap.md`'den oku.
4. Kullanıcıya 1–2 cümlelik bir "kaldığımız yer" özeti ver.

### Otonom mesai sonunda

1. Bildirim gönder: kaç görev bitti, kuyrukta ne bekliyor (kısa).
2. `last_session`'a mesaiyi özetle: biten görevler, atlananlar (`standard_queue`), seçilen varsayımlar.
3. Kullanıcı dönünce: biten işlerin birleşik test listesi (2–4 madde) ve kuyruktaki işler.

### Her görev bittiğinde (commit'ten önce)

1. `state.json`: görevi `completed_tasks`'a ekle, `current`'ı sıradaki göreve taşı, `updated` ve `last_session` alanlarını güncelle.
2. `roadmap.md`: görevin kutusunu işaretle (`[x]`).
3. Tasarım değiştiyse `GDD.md`'yi, teknik karar değiştiyse `architecture.md`'yi güncelle ve karar kaydına yeni bir ADR satırı ekle.
4. Dış varlık eklendiyse `CREDITS.md`'yi güncelle.
5. Commit mesajı: `[M1-03] Kısa açıklama`.
6. Commit'ten sonra `tools/notify.ps1 -Read`: kullanıcı telefondan yazdıysa ona göre davran.

### Kullanıcı bir karar verdiğinde

- Kararı aynı oturumda ilgili belgeye işle, `pending_user_decisions`'tan çıkar, gerekiyorsa ADR ekle.

### Planlama Gözden Geçirmesi

Her kilometre taşının sonunda ve kullanıcı "planlama gözden geçir" dediğinde:

1. Tüm planlama belgelerini birlikte oku; çelişkileri ve eskimiş bilgileri düzelt.
2. Sıradaki aşamanın kaba görevlerini atomik görevlere böl (her biri tek oturumda biten, tek commit'lik, test edilebilir iş).
3. `state.json` → `docs_reviewed` tarihlerini güncelle.
4. Kullanıcıya değişikliklerin kısa bir özetini sun.

### Tutarlılık kuralı

- Kod ile belgeler çelişirse sessizce devam etme: düzelt ya da kullanıcıya sor.
- `roadmap.md`'deki kutular `state.json`'ın yansımasıdır; ikisi her zaman birlikte güncellenir.

## Ortam ve komutlar

> Yollar 2026-10-01'de doğrulandı (M0-02); tam kontrol M0-06'da, telefona yükleme M0-08'de, kare yakalama M0-09'da doğrulandı. Ayrıntılı ortam bilgisi: `state.json` → `environment`.

- İşletim sistemi: Windows 11. Proje yolu: `C:\Users\burak\Desktop\gravity-hopper` (boşluksuz; bkz. ADR-012)
- `<godot>` (Claude'un kullandığı konsol sürümü): `C:\Users\burak\Godot\Godot_v4.7.2-stable_win64_console.exe` — kullanıcının editörü aynı klasörde
- **Tam kontrol (her görevde):** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1` → `TEMİZ` / `SORUN VAR` (içe aktarma + uyarılar hata sayılarak tüm betikler + sahne denetimi + parça doğrulama + gdlint + gdUnit4 testleri). `.gd` düzenlemelerini ayrıca bir kanca anında `gdlint`'ten geçirir (`.claude/settings.json`)
- **Sahne ağacı** (bir `.tscn`'e dokunmadan önce düğüm adlarını tahmin etme, buna bak): `<godot> --headless --path . --script res://tools/scene_tool.gd -- tree res://scenes/x.tscn`
- **Telefona yükleme:** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/deploy.ps1 -Screenshot <scratchpad>/x.png` (dışa aktar + kabloyla yükle + başlat + ekran görüntüsü + Godot günlüğü). Çıktısı PowerShell borusuna bağlanmaz (`| Select-Object` gibi): adb sunucusu yeniden başlarsa boruyu açık tutar ve komut asılı kalır.
- **Telefona adb dokunuşu** (`adb shell input tap`): göndermeden hemen önce ekran görüntüsüyle oyunun tam ekran açık olduğu doğrulanır. Kullanıcı telefonu kullanıyor olabilir; dokunuş onun uygulamalarına gidebilir (M1-12'de yaşandı).
- **Telefon bildirimi:** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/notify.ps1 -Message "..."` · `-Read` (yeni mesajlar) · `-Wait` (cevap gelene kadar bekler; arka planda). Konu adı depoda değil: `%LOCALAPPDATA%\gravity-hopper\ntfy_topic.txt`
- **Web sürümü:** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/web_build.ps1 -Smoke -Shot <scratchpad>/w.png` (yayın çıktısı + `builds/gravity-hopper-web.zip` + görünmez tarayıcıda oyunun açıldığı denemesi)
- Oyunu çalıştırma: `<godot> --path .`
- Kare yakalama (Movie Maker): `<godot> --path . [res://scenes/x.tscn] --write-movie <scratchpad>/f.png --fixed-fps 60 --quit-after 40 [-- <kullanıcı argümanları>]`. Kareler pencere boyutunda (450×800) çıkar; asıl görüntü kanıtı telefonun ekran görüntüsüdür.
- JDK 17: `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot` · Android SDK: `%LOCALAPPDATA%\Android\Sdk`
- ADB: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` · GitHub CLI: `gh` (hesap `burak-sisci`)
- Oyunun PC'deki kullanıcı verisi (ayar paneli kayıtları dahil): `%APPDATA%\Godot\app_userdata\Gravity Hopper\`
- Test cihazı: Redmi Note 12 4G (adb seri no `ecde8b60`, Android 15, Adreno 610, 1080×2400, 120 Hz). Bu cihaz **referanstır, hedef değildir**; oyun geniş bir cihaz yelpazesi için tasarlanır.
