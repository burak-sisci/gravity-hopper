extends Node
## Kalıcı ilerleme: Glimmer cüzdanı, yükseltme seviyeleri, izler, açılmış sektörler.
##
## Veriyi SaveManager ile saklar (architecture.md §11). M4-01: açılışta kaydı yükler; ilk açılışta
## (ya da yalnızca yedek sağlamsa) kaydı hemen yazar. Tur sonu kazancı ve rekor M4-02'de.

## Oyuncunun sahip olduğu Glimmer.
var glimmers: int = 0

var _data: Dictionary[String, Variant] = {}


func _ready() -> void:
	_data = SaveManager.load_game()
	glimmers = int(_data["glimmers"])
	if SaveManager.last_source != SaveManager.Source.MAIN:
		SaveManager.save_game(_data)


## Cüzdana Glimmer ekler ve yeni toplamı duyurur.
func add_glimmers(amount: int) -> void:
	glimmers += amount
	Events.glimmers_changed.emit(glimmers)
