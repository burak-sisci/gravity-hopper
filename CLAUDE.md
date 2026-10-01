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
| `CREDITS.md` | Dış varlıklar ve lisansları |

## Kullanıcıyla çalışma

- Kullanıcıyla **Türkçe** konuş. Kullanıcı ilk kez mobil oyun yapıyor; teknik terimleri kısaca açıkla.
- Rol dağılımı: Claude geliştirir. Kullanıcı her aşamayı oyuncu gözüyle test eder ve kararları verir.
- Her görev **oynanabilir** bir sonuçla biter. Teslim ederken kullanıcıya neyi, nasıl test edeceğini 2–4 maddeyle söyle.
- Beklenen geri bildirim kalıbı: "Ne yaptım → ne oldu → ne bekliyordum".
- Kullanıcıya ait bir karar varsa (`state.json` → `pending_user_decisions`) varsayım yapma, sor.

## Planlama rutini (ZORUNLU — atlanmaz)

### Oturum başında

1. `docs/state.json`'u oku: `current`, `blockers`, `pending_user_decisions`, `last_session.next_steps`.
2. Aktif görevin tanımını ve kabul kriterini `docs/roadmap.md`'den oku.
3. Kullanıcıya 1–2 cümlelik bir "kaldığımız yer" özeti ver.

### Her görev bittiğinde (commit'ten önce)

1. `state.json`: görevi `completed_tasks`'a ekle, `current`'ı sıradaki göreve taşı, `updated` ve `last_session` alanlarını güncelle.
2. `roadmap.md`: görevin kutusunu işaretle (`[x]`).
3. Tasarım değiştiyse `GDD.md`'yi, teknik karar değiştiyse `architecture.md`'yi güncelle ve karar kaydına yeni bir ADR satırı ekle.
4. Dış varlık eklendiyse `CREDITS.md`'yi güncelle.
5. Commit mesajı: `[M1-03] Kısa açıklama`.

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

> Yollar 2026-10-01'de doğrulandı (M0-02); içe aktarma komutu M0-04'te doğrulandı. Çalıştırma ve kare yakalama ⚠️ ana sahne olunca (M0-10) doğrulanacak. Ayrıntılı ortam bilgisi: `state.json` → `environment`.

- İşletim sistemi: Windows 11. Proje yolu: `C:\Users\burak\Desktop\gravity-hopper` (boşluksuz; bkz. ADR-012)
- `<godot>` (Claude'un kullandığı konsol sürümü): `C:\Users\burak\Godot\Godot_v4.7.2-stable_win64_console.exe` — kullanıcının editörü aynı klasörde
- İçe aktarma ve hata kontrolü: `<godot> --headless --path . --import`
- Oyunu çalıştırma: `<godot> --path .`
- Kare yakalama (Movie Maker): `<godot> --path . --write-movie <scratchpad>/frame.png --fixed-fps 60 --quit-after 120`
- JDK 17: `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot` · Android SDK: `%LOCALAPPDATA%\Android\Sdk`
- ADB: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` · GitHub CLI: `gh` (hesap `burak-sisci`)
- Oyunun PC'deki kullanıcı verisi (ayar paneli kayıtları dahil): `%APPDATA%\Godot\app_userdata\Gravity Hopper\`
- Test cihazı: Redmi Note 12 4G (adb seri no `ecde8b60`, Android 15, Adreno 610, 1080×2400, 120 Hz). Bu cihaz **referanstır, hedef değildir**; oyun geniş bir cihaz yelpazesi için tasarlanır.
