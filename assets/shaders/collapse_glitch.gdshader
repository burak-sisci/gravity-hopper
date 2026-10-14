shader_type canvas_item;
render_mode unshaded;

// Çöküş duvarının glitch bandı (M3-09, architecture.md §9). CollapseWall bu malzemeyi yalnızca
// duvarın kenarı çevresindeki banda çizer (tam ekran değil: M3-07 ölçümü). Konum duvarın yerel
// koordinatında: kenar (öldürme çizgisi) y = 0, aşağısı duvarın içi. Kırık kenar (sütun
// yükseklikleri), kayan dilimler ve veri kırıntıları her glitch adımında değişir; sütun ve dilim
// değerlerini CollapseWall adım başına bir kez hesaplayıp yazar (piksel başına özet yok: Redmi'de
// ölçüldü). Değerler NeonStyle'dan (Çöküş duvarı grubu).

// CollapseWall.MAX_COLUMNS ve MAX_ROWS ile aynı olmalı (test denetler).
const int MAX_COLUMNS = 96;
const int MAX_ROWS = 32;

uniform float glitch_step = 0.0;
uniform float pulse = 0.0;
uniform vec4 edge_color = vec4(1.0, 0.22, 0.32, 1.0);
uniform vec4 body_color = vec4(0.14, 0.015, 0.04, 1.0);
uniform float rise = 70.0;
uniform float depth = 100.0;
uniform float column_px = 36.0;
uniform float slice_px = 14.0;
uniform float block_px = 12.0;
uniform float dust_density = 0.12;
uniform float edge_px = 6.0;
uniform float glow_px = 24.0;
uniform float glow_alpha = 0.5;
uniform float pulse_gain = 0.6;
// Kenarın renk kayması (RGB); 0 ise yok (orta kalite).
uniform float split_px = 0.0;
// Sütunların kırık kenarı (0 ile -jag arası; kenar hiç öldürme çizgisinin altına inmez) ve
// dilimlerin yana kayması; ilk elemanın sütun ve satır sırası.
uniform float tops[MAX_COLUMNS];
uniform float first_column = 0.0;
uniform float shifts[MAX_ROWS];
uniform float first_row = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

// 0–1 arası özet. Girdiler küçük sayılar (adım sarılır); mobilde de kararlı.
float hash(vec2 p) {
	vec3 q = fract(p.xyx * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float column_top(float column) {
	return tops[clamp(int(column - first_column), 0, MAX_COLUMNS - 1)];
}

// Kenara uzaklık (px): dışarıda eksi (kenarın ne kadar üstünde), içeride artı (üst yüzeye ya da
// boşluğa bakan yan yüzeye en yakın uzaklık).
float edge_distance(vec2 p) {
	float column = floor(p.x / column_px);
	float d = p.y - column_top(column);
	if (d < 0.0) {
		return d;
	}
	float inside_x = p.x - column * column_px;
	if (p.y < column_top(column - 1.0)) {
		d = min(d, inside_x);
	}
	if (p.y < column_top(column + 1.0)) {
		d = min(d, column_px - inside_x);
	}
	return d;
}

// Kenar çizgisinin örtüsü (0–1): duvarın içinde, kenardan edge_px kalınlığında.
float edge_line(float d) {
	return smoothstep(-1.0, 0.0, d) * (1.0 - smoothstep(edge_px - 1.0, edge_px + 1.0, d));
}

void fragment() {
	vec2 p = local;
	// Kayan dilimler: bazı satırlar adımdan adıma yana kayar (kenar ve kırıntılar birlikte).
	p.x += shifts[clamp(int(floor(p.y / slice_px) - first_row), 0, MAX_ROWS - 1)];
	vec2 block = floor(p / block_px);
	float noise = hash(vec2(block.x + block.y * 97.0, glitch_step));
	vec3 rgb;
	float alpha;
	if (p.y > edge_px + 1.0) {
		// Kenarın altı (kırık kenar hep y ≤ 0): yalnızca opak dolgu. Bozuk bloklar ve tarama
		// çizgileri bandın altına doğru söner; orada dolgu duvarın gövdesiyle aynı renkte.
		float fade = 1.0 - clamp(p.y / depth, 0.0, 1.0);
		rgb = body_color.rgb;
		if (noise < 0.18 * fade) {
			rgb = mix(rgb, edge_color.rgb, 0.35 * fade);
		}
		rgb *= 1.0 - 0.25 * fade * step(0.5, fract(p.y / 4.0));
		COLOR = vec4(rgb, body_color.a);
	} else {
		float d = edge_distance(p);
		float boost = 1.0 + pulse_gain * pulse;
		if (d >= 0.0) {
			rgb = body_color.rgb;
			if (noise < 0.18) {
				rgb = mix(rgb, edge_color.rgb, 0.35);
			}
			alpha = body_color.a;
		} else {
			// Dış: kenarın üstünde sönen ışık ve yukarı doğru seyrelen veri kırıntıları.
			float height = clamp(-d / rise, 0.0, 1.0);
			rgb = edge_color.rgb;
			alpha = glow_alpha * boost * exp(d / glow_px);
			if (noise < dust_density * (1.0 - height)) {
				alpha = max(alpha, 0.7 * (1.0 - height));
			}
		}
		// Kenar çizgisi: ortası beyaza çekilmiş, vuruşta parlar.
		float line = edge_line(d);
		rgb = mix(rgb, mix(edge_color.rgb, vec3(1.0), 0.35 + 0.25 * pulse), line);
		alpha = max(alpha, line);
		if (split_px > 0.0) {
			// Renk kayması: kenarın iki kaymış kopyası (kenar rengi ve tümleyeni), çizginin
			// dışında.
			float first = edge_line(edge_distance(p + vec2(split_px, 0.0))) * (1.0 - line);
			float second = edge_line(edge_distance(p - vec2(split_px, -0.5 * split_px)))
					* (1.0 - line) * (1.0 - first);
			rgb = mix(rgb, edge_color.rgb, first);
			rgb = mix(rgb, vec3(1.0) - edge_color.rgb, second);
			alpha = max(alpha, 0.85 * max(first, second));
		}
		COLOR = vec4(rgb, clamp(alpha, 0.0, 1.0));
	}
}
