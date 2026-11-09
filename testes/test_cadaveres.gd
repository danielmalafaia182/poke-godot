extends SceneTree
## Cadáveres: o desenho usa o corpses.json do snapshot (como loadCorpses, C) e as páginas disponíveis; a tabela
## espécie → cadáver vem das gravações (A); na simulação, shiny usa o cadáver shiny. Grava a cobertura em
## saida_testes/cadaveres_cobertura.json. Rodar: testes/rodar.sh res://testes/test_cadaveres.gd

const Fontes := preload("res://sim/fontes.gd")
const Vista := preload("res://render/vista_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _init() -> void:
	var v = Vista.new()
	get_root().add_child(v)
	await process_frame
	var n_assets: int = v._corpses_assets.size()
	var desenhaveis := 0
	var sem_pagina: Array = []
	for k in v._corpses_assets:
		var pg := int(v._corpses_assets[k]["frames"][0]["page"])
		if pg < v._corpses_paginas.size() and v._corpses_paginas[pg] != null:
			desenhaveis += 1
		else:
			sem_pagina.append(int(k))
	checar(n_assets == 503, "corpses.json do snapshot carregado", "%d assets" % n_assets)
	print("cadáveres desenháveis: %d de %d; páginas faltando: %s; assets sem página: %s" % [desenhaveis, n_assets, str(v.paginas_cadaver_faltando), str(sem_pagina)])
	var obs = Fontes.ler_json(Fontes.pasta_dados() + "/corpos_observados.json")
	var todos_ok := true
	for tab in ["normal", "shiny"]:
		for sid in obs[tab]:
			var c := str(int(obs[tab][sid]))
			var a: Dictionary = v._corpses_assets.get(c, {})
			if a.is_empty() or v._corpses_paginas[int(a["frames"][0]["page"])] == null:
				todos_ok = false
	checar(todos_ok, "todo cadáver observado nas gravações tem asset e página")
	# cobertura por espécie das hunts
	var dados = DadosJogo.carregar()
	var especies := {}
	for slug in dados.hunts:
		for s in Fontes.ler_hunt_config(String(slug)).get("spawns", []):
			especies[int(s["pokeId"])] = true
	var com := []
	for sid in especies:
		if obs["normal"].has(str(sid)):
			com.append(sid)
	print("espécies das hunts com cadáver conhecido: %d de %d" % [com.size(), especies.size()])
	var f := FileAccess.open(Fontes.raiz_projeto() + "/saida_testes/cadaveres_cobertura.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"assets": n_assets, "desenhaveis": desenhaveis, "paginas_faltando": v.paginas_cadaver_faltando,
		"especies_hunts": especies.size(), "especies_com_cadaver": com}, " "))
	# simulação: shiny → cadáver shiny
	var cfg := Cenario.de_estado(Fontes.raiz_projeto() + "/dados/testes/estado_rhydon_venusaur_1h.json", dados, 4)
	var mapa = MapaHunt.carregar("rhydon", Fontes.ler_mapa("rhydon"), Fontes.ler_colisao())
	var sim = Simulacao.new(cfg, dados, mapa)
	sim.iniciar()
	sim.mobs[0]["shiny"] = true
	sim._abate(sim.mobs[0])
	sim._abate(sim.mobs[1])
	var ids: Array = sim.cadaveres.map(func(c): return int(c["corpse"]))
	checar(ids == [31489, 2858], "Rhydon shiny deixa 31489, o normal 2858 (A)", str(ids))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
