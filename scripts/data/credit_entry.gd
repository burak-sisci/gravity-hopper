class_name CreditEntry
extends Resource
## Hakkında ekranında bir emeği geçen satırı (M5-09): CREDITS.md'deki oyuna giren bir tablo
## satırının karşılığı. title ve license çeviri anahtarı ya da özel ad olabilir (tr() özel adı
## olduğu gibi bırakır).

## CREDITS.md'deki satırın ilk hücresi (birebir). Test iki listeyi bununla eşler.
@export var credits_row: String = ""
## Ekranda görünen ad (özel ad ya da çeviri anahtarı).
@export var title: String = ""
## Yazar ya da sahip.
@export var author: String = ""
## Lisans adı (ör. "CC0 1.0") ya da çeviri anahtarı.
@export var license: String = ""
