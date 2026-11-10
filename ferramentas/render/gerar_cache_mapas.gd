extends SceneTree
## Pré-monta o cache binário de desenho (render/cache_mapa.gd) e o atlas por mapa (render/atlas_mapa.gd) de todos os
## mapas das hunts (ou dos slugs dados), para que a 1ª entrada numa hunt já leia o cache (~1 s) em vez de montar
## (até ~8 s de cache + ~1 s de atlas no maior mapa).
## Uso: testes/rodar.sh res://ferramentas/render/gerar_cache_mapas.gd [slug ...]
const CacheMapa := preload("res://render/cache_mapa.gd")
const AtlasMapa := preload("res://render/atlas_mapa.gd")
const DadosDesenho := preload("res://render/dados_desenho.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Fontes := preload("res://sim/fontes.gd")

func _init() -> void:
	var slugs := Array(OS.get_cmdline_user_args())
	if slugs.is_empty():
		slugs = DadosJogo.carregar().hunts.keys()
	var d = DadosDesenho.carregar()
	var feitos := 0
	var ja := 0
	var atlas_feitos := 0
	var t0 := Time.get_ticks_msec()
	for s in slugs:
		if not FileAccess.file_exists(Fontes.pasta_snapshot() + "/game/maps/%s.json" % s):
			continue
		var c := CacheMapa.ler(String(s), d)
		if c.is_empty():
			c = CacheMapa.montar(String(s), d, Fontes.ler_mapa(String(s)))
			feitos += 1
		else:
			ja += 1
		if AtlasMapa.ler(String(s), d).is_empty():
			AtlasMapa.montar(String(s), d, c)
			atlas_feitos += 1
	print("cache de mapas: %d montados, %d já válidos; atlas: %d montados; %d s" % [feitos, ja, atlas_feitos, (Time.get_ticks_msec() - t0) / 1000])
	quit()
