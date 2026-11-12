class_name CreditsCatalog
extends Resource
## Oyuna giren dış varlıkların ve özgün eserlerin listesi (M5-09, data/credits/credits.tres).
## CREDITS.md yayın paketine girmez; Hakkında ekranı bu kaynaktan okur. Test, CREDITS.md'nin
## oyuna giren bölümlerindeki her satırın burada olduğunu denetler.

@export var entries: Array[CreditEntry] = []
