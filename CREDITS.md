# GRAVITY HOPPER — Emeği Geçenler ve Lisanslar

> Oyunda kullanılan her dış varlık ve eklenti, **eklendiği commit'te** buraya (sürümüyle) yazılır.
> İzinli lisanslar: görsel/ses **CC0, CC-BY** · kod/eklenti **MIT, BSD, Apache-2.0, zlib** · font **SIL OFL 1.1** (hepsi atıfla).
> **Yasak:** CC-BY-NC (ticari kullanım yasak), CC-BY-SA, GPL/LGPL/AGPL ve lisansı belirsiz her şey.

## Motor ve oyuna dahil edilen yazılımlar

| Bileşen | Sürüm | Lisans | Not |
| --- | --- | --- | --- |
| Godot Engine | 4.7.2 | MIT | Godot ve içerdiği üçüncü taraf bileşenlerin lisans metni oyun içindeki "Hakkında" ekranında gösterilmeli (M5-09) |

## Görseller

| Varlık | Kaynak | Yazar | Lisans | Kullanıldığı yer |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

## Sesler ve müzik

Müzik parçaları özgündür (M3-21, ADR-065): Claude (Anthropic) Gravity Hopper için besteledi ve gerçek enstrüman kayıtlarıyla seslendirdi. Besteler ve miks `tools/music/` altında; kayıtlar aşağıdaki iki CC0 kütüphaneden gelir, depoya girmez (proje dışında önbellekte durur), yalnızca parçaların içinde çalar. 2026-10-20'de indirildi.

| Varlık | Kaynak | Yazar | Lisans | Kullanıldığı yer |
| --- | --- | --- | --- | --- |
| Kervan (`caravan`, 100 BPM, Orta Doğu) | `tools/music/tracks/caravan.py` | Claude (Anthropic), Gravity Hopper için | Özgün (projenin) | Tur müziği (`assets/audio/music/caravan.ogg`) |
| Pagoda (`pagoda`, 90 BPM, Doğu Asya) | `tools/music/tracks/pagoda.py` | Claude (Anthropic), Gravity Hopper için | Özgün (projenin) | Tur müziği (`pagoda.ogg`) |
| Kale (`castle`, 120 BPM, Orta Çağ Avrupa) | `tools/music/tracks/castle.py` | Claude (Anthropic), Gravity Hopper için | Özgün (projenin) | Tur müziği (`castle.ogg`) |
| Versilian Community Sample Library (VCSL) | [github.com/sgossner/VCSL](https://github.com/sgossner/VCSL), commit `c1ea7bc` | Versilian Studios (Sam Gossner) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Parçalardaki darbuka, def, tef, çıngırak, zil, rüzgâr çanı, büyük davul, trampet, timpani, telli (strumstick), đàn tranh, halk arpı ve blok flüt kayıtları |
| Versilian Studios Chamber Orchestra 2 Community Edition (VSCO 2 CE) | [github.com/sgossner/VSCO-2-CE](https://github.com/sgossner/VSCO-2-CE), commit `4403009` | Versilian Studios (Sam Gossner) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Parçalardaki flüt, obua, keman, viyola, viyolonsel, kontrbas, korno ve arp kayıtları |

### Ses efektleri (M3-15)

Kenney ses paketlerinden (CC0; atıf zorunlu değil ama veriliyor). Dosyalar değiştirilmedi, yalnızca olay adıyla yeniden adlandırıldı; ses düzeyi `data/audio/sfx_bank.tres`'teki `volume_db` ile ayarlanır (`tools/sfx_prep.py`). Paketler 2026-10-14'te indirildi. Tek istisna gerilim sesi (M3-16): sonu başına çapraz geçişle bindirilerek dikişsiz döngüye çevrildi ve yeniden kodlandı (CC0 değiştirmeye izin verir).

| Varlık | Kaynak | Yazar | Lisans | Kullanıldığı yer |
| --- | --- | --- | --- | --- |
| phaseJump2.ogg (Digital Audio) | [kenney.nl/assets/digital-audio](https://kenney.nl/assets/digital-audio) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Çevirme (`assets/audio/sfx/flip.ogg`) |
| impactGeneric_light_000.ogg (Impact Sounds) | [kenney.nl/assets/impact-sounds](https://kenney.nl/assets/impact-sounds) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Duvara tutunma (`assets/audio/sfx/land.ogg`) |
| confirmation_003.ogg (Interface Sounds) | [kenney.nl/assets/interface-sounds](https://kenney.nl/assets/interface-sounds) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Glimmer toplama (`assets/audio/sfx/glimmer.ogg`) |
| phaserUp4.ogg (Digital Audio) | [kenney.nl/assets/digital-audio](https://kenney.nl/assets/digital-audio) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Kıl payı (`assets/audio/sfx/near_miss.ogg`) |
| highUp.ogg (Digital Audio) | [kenney.nl/assets/digital-audio](https://kenney.nl/assets/digital-audio) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Kombo eşiği (×2 / ×3) (`assets/audio/sfx/combo_up.ogg`) |
| glass_004.ogg (Interface Sounds) | [kenney.nl/assets/interface-sounds](https://kenney.nl/assets/interface-sounds) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Kalkan kırılması (`assets/audio/sfx/shield_break.ogg`) |
| explosionCrunch_000.ogg (Sci-fi Sounds) | [kenney.nl/assets/sci-fi-sounds](https://kenney.nl/assets/sci-fi-sounds) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Ölüm (`assets/audio/sfx/death.ogg`) |
| zapThreeToneUp.ogg (Digital Audio) | [kenney.nl/assets/digital-audio](https://kenney.nl/assets/digital-audio) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Sektör geçişi (`assets/audio/sfx/sector.ogg`) |
| jingles_PIZZI10.ogg (Music Jingles) | [kenney.nl/assets/music-jingles](https://kenney.nl/assets/music-jingles) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Rekor kırma (`assets/audio/sfx/record.ogg`) |
| computerNoise_000.ogg (Sci-fi Sounds), dikişsiz döngüye çevrildi | [kenney.nl/assets/sci-fi-sounds](https://kenney.nl/assets/sci-fi-sounds) | Kenney (kenney.nl) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Çöküş duvarı gerilim sesi (`assets/audio/sfx/tension.ogg`, M3-16) |
| Büyük Depolama Birimi finali (M4-13): kodla üretildi, örnek ses yok | `tools/sfx_synth.py` | Claude (Anthropic), Gravity Hopper için | Özgün (projenin) | Final sesi (`assets/audio/sfx/finale.ogg`) |

## Fontlar

| Font | Kaynak | Lisans | Kullanıldığı yer |
| --- | --- | --- | --- |
| Exo 2, Version 2.010 (`Exo2[wght].ttf`, değişken ağırlık; google/fonts `ofl/exo2`, blob `9cb2018`, 2026-10-15'te indirildi, değiştirilmedi). Copyright 2013 The Exo 2 Project Authors | [github.com/googlefonts/Exo-2.0](https://github.com/googlefonts/Exo-2.0) · [fonts.google.com/specimen/Exo+2](https://fonts.google.com/specimen/Exo+2) | [SIL OFL 1.1](https://openfontlicense.org) (`assets/fonts/exo2_OFL.txt`) | Oyunun tüm yazıları (`assets/fonts/exo2.ttf`; kalın kesim `exo2_bold.tres`, M3-17) |

## Geliştirme araçları ve eklentileri (yayın sürümüne girmez)

| Araç | Sürüm | Lisans | Kullanım | Durum |
| --- | --- | --- | --- | --- |
| numpy ([numpy.org](https://numpy.org)) + soundfile ([bastibe/python-soundfile](https://github.com/bastibe/python-soundfile)) | numpy 2.5.4, soundfile 0.14.0 (libsndfile 1.2.2 içinde) | BSD-3-Clause (numpy, soundfile); libsndfile LGPL-2.1 | `tools/music/` (müzik üreteci, M3-21; M2-20'de `tools/music_prep.py`) ve `tools/sfx_prep.py` (efekt ses düzeyi ölçümü, M3-15), `tools/sfx_synth.py` (özgün efekt sesi üretimi, M4-13). Yalnızca geliştirme ortamında (`%LOCALAPPDATA%\gravity-hopper\venv`); oyuna ve depoya girmez, ürettiği ses dosyaları bu lisanslara bağlı değil | ✅ M2-20'de kuruldu |
| gdtoolkit (`gdlint`) ([Scony/godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit)) | 4.5.0 (bağımlılıklar: lark 1.2.2, docopt-ng 0.9.0, radon 6.0.1, PyYAML 6.0.3) | MIT | Kod denetimi. Python paketi; proje dışındaki sanal ortamda (`%LOCALAPPDATA%\gravity-hopper\venv`), depoda değil | ✅ M0-12'de kuruldu |
| godot-debug-menu ([godot-extended-libraries/godot-debug-menu](https://github.com/godot-extended-libraries/godot-debug-menu)), © 2023-present Hugo Locurcio and contributors | commit `ff12461` (2025-11-19; v1.2.0 + 7 düzeltme) | MIT (`addons/debug_menu/LICENSE.md`) | FPS ve kare süresi ölçümü, yalnızca debug build. Yalnızca `debug_menu.gd`, `.tscn`, `.uid` ve lisans alındı; editör eklentisi alınmadı | ✅ M0-09'da eklendi |
| gdUnit4 ([godot-gdunit-labs/gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4)), © 2023 Mike Schulze | 6.2.2 (Godot 4.5–4.7.1 için listelenmiş, 4.7.2'de denendi) | MIT (`addons/gdUnit4/LICENSE`) | Otomatik testler (`tests/`), `tools/check.ps1` 6. adım. Dışa aktarmada dışlanır (`addons/gdUnit4/*`) | ✅ M2-01'de eklendi |
