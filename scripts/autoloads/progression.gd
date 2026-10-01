extends Node
## Kalıcı ilerleme: Glimmer cüzdanı, yükseltme seviyeleri, izler, açılmış sektörler.
##
## Veriyi SaveManager ile saklar. M0-06 iskeleti: yalnızca Glimmer cüzdanı.
## Yükseltmeler ve kayıt bağlantısı M4'te eklenecek.

## Oyuncunun sahip olduğu Glimmer.
var glimmers: int = 0


## Cüzdana Glimmer ekler ve yeni toplamı duyurur.
func add_glimmers(amount: int) -> void:
	glimmers += amount
	Events.glimmers_changed.emit(glimmers)
