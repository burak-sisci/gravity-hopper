extends Node
## Kayıt dosyalarını okur ve yazar: şifreleme, atomik yazma, yedek, sürüm geçişi.
##
## Yalnızca kalıcılıktan sorumludur, oyun kuralı bilmez.
## M0-06 iskeleti: uygulama M4-01'de (bkz. docs/architecture.md §11).

const SAVE_PATH: String = "user://savegame.dat"
const BACKUP_PATH: String = "user://savegame.bak"
const TEMP_PATH: String = "user://savegame.tmp"
const DEBUG_SAVE_PATH: String = "user://savegame_debug.json"
const SCHEMA_VERSION: int = 1
