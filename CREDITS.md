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

| Varlık | Kaynak | Yazar | Lisans | Kullanıldığı yer |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

## Fontlar

| Font | Kaynak | Lisans | Kullanıldığı yer |
| --- | --- | --- | --- |
| — | — | — | — |

## Geliştirme araçları ve eklentileri (yayın sürümüne girmez)

| Araç | Sürüm | Lisans | Kullanım | Durum |
| --- | --- | --- | --- | --- |
| gdtoolkit (`gdlint`) ([Scony/godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit)) | 4.5.0 (bağımlılıklar: lark 1.2.2, docopt-ng 0.9.0, radon 6.0.1, PyYAML 6.0.3) | MIT | Kod denetimi. Python paketi; proje dışındaki sanal ortamda (`%LOCALAPPDATA%\gravity-hopper\venv`), depoda değil | ✅ M0-12'de kuruldu |
| godot-debug-menu ([godot-extended-libraries/godot-debug-menu](https://github.com/godot-extended-libraries/godot-debug-menu)), © 2023-present Hugo Locurcio and contributors | commit `ff12461` (2025-11-19; v1.2.0 + 7 düzeltme) | MIT (`addons/debug_menu/LICENSE.md`) | FPS ve kare süresi ölçümü, yalnızca debug build. Yalnızca `debug_menu.gd`, `.tscn`, `.uid` ve lisans alındı; editör eklentisi alınmadı | ✅ M0-09'da eklendi |
| gdUnit4 | (kurulumda sabitlenecek) | MIT | Otomatik testler, sahne koşucusu | M2-01'de eklenecek |
