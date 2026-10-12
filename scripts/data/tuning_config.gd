class_name TuningConfig
extends Resource
## Oyun hissinin ayar değerleri (architecture.md §10). Geçerli değerler
## data/tuning/default_tuning.tres dosyasındadır; buradaki varsayılanlar yalnızca başlangıçtır.
##
## Birimler tasarım belgesiyle aynıdır: mesafe metre, hız m/sn, süre saniye. Kod piksele
## to_px() ile çevirir. Her alanın aralığı ve birimi, canlı ayar panelinin (M1-11)
## kaydırıcılarını kendiliğinden kurmak için kullanılır.

## Dünya birimi: 1 m = 50 px (architecture.md §3). Ayarlanan bir değer değildir.
const PX_PER_M: float = 50.0

@export_group("Hareket")
# Tırmanış hızı burada değil: sektörün içinde sabittir ve SectorDef'ten gelir (M2-08).
## Oyuncuyu aktif duvara çeken yan ivme. Yüksek değer, çevirmeden sonra daha çabuk hızlanır.
@export_range(50.0, 600.0, 5.0, "suffix:m/sn²") var gravity_accel: float = 300.0
## Duvardan duvara geçişteki en yüksek yan hız. Geçiş süresini bu ve ivme birlikte belirler.
@export_range(10.0, 120.0, 1.0, "suffix:m/sn") var max_side_speed: float = 64.0

@export_group("Adalet")
## Havadayken yapılan dokunuşun saklanma süresi. Oyuncu bu süre içinde duvara değerse
## çevirme kaybolmaz, uygulanır (dokunma tamponu).
@export_range(0.0, 0.3, 0.01, "suffix:sn") var input_buffer_time: float = 0.12
## Çarpışma kutusunun görsele oranı. Küçük değer daha affedicidir.
@export_range(0.4, 1.0, 0.05) var hurtbox_scale: float = 0.7
## Duvar biter bitmez (boşluk) çevirme bu süre daha yapılabilir; süre dolunca koridorun dışındaki
## oyuncu düşmüş sayılır (coyote süresi, GDD §4).
@export_range(0.0, 0.25, 0.01, "suffix:sn") var coyote_time: float = 0.1

@export_group("Toplama")
## Oyuncunun Glimmer toplama alanının yarıçapı (gövdeden büyük: affedici toplama, M2-13).
@export_range(0.5, 4.0, 0.1, "suffix:m") var pickup_radius: float = 1.5

@export_group("Kamera ve dünya")
## Kameranın oyuncunun üstünde gösterdiği mesafe; her cihazda aynıdır (sabit ileri görüş kuralı).
## Üst sınır, en kısa ekranda (16:9, 38,4 m) oyuncunun altında pay kalacak şekilde seçildi.
@export_range(10.0, 34.0, 0.5, "suffix:m") var lookahead: float = 28.0
## İki duvar arasındaki mesafe. Taban genişliğe (1080 px = 21,6 m) sığmalıdır.
@export_range(12.0, 21.6, 0.2, "suffix:m") var corridor_width: float = 18.0
## Tur başında ilk desen parçasına kadar boş mesafe. Vuruş ızgarası bozulmasın diye yukarı,
## tam vuruşa yuvarlanır (S1'de 25 m → 4 vuruş = 28,8 m).
@export_range(5.0, 60.0, 1.0, "suffix:m") var run_start_gap: float = 25.0
## Yeni sektörün başındaki engelsiz "nefes alma" süresi (GDD §12: 2–3 sn). Yeni sektörün hızıyla
## ölçülür ve tam vuruşa yukarı yuvarlanır.
@export_range(0.0, 5.0, 0.1, "suffix:sn") var sector_breath: float = 2.5

@export_group("Zorluk")
## Sektör içi hedef zorluğun çevresinde seçim genişliği (zorluk birimi). Küçük değer hedefe yakın
## parçaları seçer; büyük değer daha karışık bir akış verir (M2-10).
@export_range(0.3, 3.0, 0.1) var difficulty_spread: float = 0.5
## Son kaç parça yeniden seçilmez. Sektör sonunda sığan başka parça yoksa kural esner.
@export_range(0, 6, 1) var no_repeat_count: int = 3


## Metreyi (ya da m/sn, m/sn²) piksele çevirir.
static func to_px(meters: float) -> float:
	return meters * PX_PER_M
