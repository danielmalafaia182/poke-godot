extends RefCounted
## Sombras e iluminação do cliente original (fonte C, chunk 0gx72gz9qjk5j.js), portadas para o desenho em lote:
##   - luz (sf/sg/sb/sj): longitude 45°, latitude 45°, ambient 0,55, diffuse 0,45, soft 1; "rock-tunnel" e "mt-moon" com
##     latitude 20, diffuse 0,3, ambient 0,7. Projeção: tanLat = tan(latitude limitada a 0..85°), lonRad, opacidade =
##     diffuse / (ambient + diffuse), soft = força do blur.
##   - quem tem sombra (placeSprite): sprite do mapa com zIndex > 7,5e6 (banda dos itens) e altura do asset > 32; toda
##     criatura e NPC (syncCreatures, applyNpcs).
##   - geometria (makeShadow/syncShadow): cópia do sprite com tint 0 (preta), âncora (anchor.x do sprite, 1), escala
##     (sx, sy × tanLat), skew.x = −lonRad, posição (x do sprite, pés), alpha do sprite. Pés: sprite do mapa = y + altura;
##     criatura/NPC = feetBaseY = y + (1 − anchor.y) × altura × escala.
##   - camada (buildWorld/applyShadowFilters): uma por andar, zIndex 7,5e6, com BlurFilter(strength = soft, quality 1) e
##     AlphaFilter(opacidade) no grupo inteiro (sombras que se cruzam não escurecem duas vezes).
## No Pixi, skew.x = −L faz o eixo y local virar (−sen L, cos L) × sy: o topo da sombra fica deslocado (+sen L, −cos L)
## × altura × tanLat a partir dos pés.
## Porte: a camada é um canvas item em modo canvas group (shader render/sombra_grupo.gdshader: blur de 5 pontos e
## alpha do grupo — aproximação F do BlurFilter do Pixi) com a transformação linear M desta luz; cada sombra é
## desenhada em M⁻¹·pés + retângulo local, sem transformação própria.

const Z_CAMADA := 7.5e6
const LUZ_PADRAO := {"longitude": 45.0, "latitude": 45.0, "ambient": 0.55, "diffuse": 0.45, "soft": 1.0}
const LUZ_MAPA := {"rock-tunnel": {"latitude": 20.0, "diffuse": 0.3, "ambient": 0.7},
	"mt-moon": {"latitude": 20.0, "diffuse": 0.3, "ambient": 0.7}}
const PES_CRIATURA := 11.52   # syncCreatures (C): anchor y = 1 − 11,52 / altura


static func luz(mapa: String) -> Dictionary:
	## sb + sj (C).
	var e: Dictionary = LUZ_PADRAO.duplicate()
	for k in LUZ_MAPA.get(mapa, {}):
		e[k] = LUZ_MAPA[mapa][k]
	var lat := clampf(float(e["latitude"]), 0.0, 85.0) * PI / 180.0
	var lon := float(e["longitude"]) * PI / 180.0
	var n := float(e["ambient"]) + float(e["diffuse"])
	return {"lonRad": lon, "tanLat": tan(lat), "opacity": clampf(float(e["diffuse"]) / n, 0.0, 1.0) if n > 0.0 else 0.0,
		"soft": maxf(0.0, float(e["soft"]))}


static func transformacao(l: Dictionary) -> Transform2D:
	## Matriz linear da sombra (escala y × tanLat e skew.x = −lon, como o Pixi monta): eixo x (1, 0), eixo y
	## (−sen L × tanLat, cos L × tanLat).
	var t := float(l["tanLat"])
	var lo := float(l["lonRad"])
	return Transform2D(Vector2(1.0, 0.0), Vector2(-sin(lo) * t, cos(lo) * t), Vector2.ZERO)


static func tem_sombra(z_index: float, altura: int) -> bool:
	return z_index > Z_CAMADA and altura > 32


static func geometria_mapa(x: float, y: float, w: float, h: float, fw: float, fh: float, l: Dictionary) -> Array:
	## [x, y, anchor x, anchor y, scale x, scale y, skew x] da sombra de um sprite do mapa (anchor 0, posição no canto,
	## largura/altura do asset sobre o quadro fw × fh), como syncShadow(h, h.y + altura).
	return [x, y + h, 0.0, 1.0, w / fw, h / fh * float(l["tanLat"]), -float(l["lonRad"])]


static func geometria_criatura(cx: float, cy: float, h: float, l: Dictionary) -> Array:
	## Criatura com anchor (0,5; 1 − 11,52/h) no centro do tile (cx, cy) e escala 1: syncShadow(e, feetBaseY(e)).
	var ay := 1.0 - PES_CRIATURA / h
	return [cx, cy + (1.0 - ay) * h, 0.5, 1.0, 1.0, float(l["tanLat"]), -float(l["lonRad"])]


static func retangulo(m_inv: Transform2D, pes: Vector2, w: float, h: float, ancora_x: float) -> Rect2:
	## Onde desenhar a sombra dentro da camada (que já tem a transformação M): M⁻¹·pés + (−ancora_x·w, −h), tamanho w × h.
	var u := m_inv * pes
	return Rect2(u.x - ancora_x * w, u.y - h, w, h)
