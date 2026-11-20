extends "res://cenario_caca.gd"
## Cerulean desenhada como o cliente original (ciclo 4, item 2). Antes a cidade desenhava um recorte antigo do mapa
## (dados/mapas/cerulean_cidade.json: 4.615 casas no chão) com um Sprite2D por peça, sem animação. Agora:
##   - mapa: o `cerulean_novo` do servidor (C: alias cerulean → cerulean_novo; 28.224 casas no chão, igual ao
##     /game/maps/cerulean_novo.json de 20/11, A) desenhado pelo render/mapa_renderizador.gd das hunts: mesma ordem e
##     posição do cliente, andares e telhados (computeFirstVisibleFloor), sombras e **decorações animadas** pelo relógio
##     do original (tickAnimations, C);
##   - colisão: walkable() do cliente (C): casa existente no andar groundZ, sem peça de /game/collision.json no chão nem
##     nos itens, e dentro de `_meta.walk`. A casa à direita da porta do Pokémon Center (−2,−4) tem a peça invisível 8274,
##     que está em `blocking` no collision.json do servidor (A, conferido em 20/11): o original também bloqueia;
##   - NPCs: /api/game/city-npcs (A: nurse, market, pokedepot, shop, fishing) com os ícones e looktypes do catálogo do
##     cliente (`c5`: /assets/npc/*.png; Pescador looktype 21019) e styleNpc/applyNpcs (C: âncora (0,5; 1 − 11,52/h),
##     zIndex 1e7 + sx(x, floor(y + 1,5 − 0,64)) + 0,4, animação pelo `dur` de cada quadro, sombra);
##   - entidades do jogo (treinador, seguidores): Node2D cujo canvas item vai para o andar do chão do renderizador, com o
##     draw_index do zIndex de criatura (C) — ficam atrás das paredes e na frente do chão como no original.
## API mantida para cidade.gd, treinador_cidade.gd e seguidor_cidade.gd: celula_transitavel, celulas_existentes,
## adicionar_treinador, atualizar_cobertura, carregar_json, motivos_bloqueio, indice_tiles.

const Renderizador := preload("res://render/mapa_renderizador.gd")
const Regras := preload("res://render/regras_desenho.gd")
const Sombras := preload("res://render/sombras.gd")
const Outfits := preload("res://render/outfits.gd")
const Fontes := preload("res://sim/fontes.gd")
const SLUG := "cerulean_novo"
const NPCS := {   # C: catálogo `c5` do cliente (ícone; looktype quando é outfit)
	"nurse": {"nome": "Nurse Joy", "icone": "nurse.png"},
	"shop": {"nome": "Mark", "icone": "mark.png"},
	"pokedepot": {"nome": "Depot", "icone": "depot.png"},
	"market": {"nome": "Mercado", "icone": "market.png"},
	"fishing": {"nome": "Pescador", "icone": "pescador.png", "looktype": 21019},
}

var piso_chao: int = 7
var indice_tiles: Dictionary = {}
var motivos_bloqueio: Dictionary = {}
var walk: Array = []
var mapa: Node2D
var npcs: Array = []          # {kind, nome, x, y, rid, sombra, looktype, quadro, t}
var _entidades: Array = []    # Node2D no andar do chão
var _outfits = null
var vista_tiles := Vector2(50, 26)


func _ready() -> void:
	var dados: Dictionary = Fontes.ler_mapa(SLUG)
	var colisao: Dictionary = Fontes.ler_colisao()
	if dados.is_empty() or colisao.is_empty():
		push_error("Cerulean: mapa ou colisão ausentes no snapshot/pacote")
		return
	piso_chao = int(dados["_meta"]["groundZ"])
	for v in dados["_meta"].get("walk", []):
		walk.append(int(v))
	for id in colisao.get("blocking", []):
		pecas_bloqueadoras[int(id)] = true
	for registro in dados["tiles"]:
		if int(registro[2]) != piso_chao:
			continue
		var celula := Vector2i(int(registro[0]), int(registro[1]))
		indice_tiles[Vector3i(celula.x, celula.y, piso_chao)] = registro
		if walk.size() == 4 and (celula.x < walk[0] or celula.x > walk[2] or celula.y < walk[1] or celula.y > walk[3]):
			continue
		celulas_existentes[celula] = true
		var bloq: Array[int] = []
		if pecas_bloqueadoras.has(int(registro[3])):
			bloq.append(int(registro[3]))
		for objeto in registro[4]:
			if pecas_bloqueadoras.has(int(objeto[0])):
				bloq.append(int(objeto[0]))
		if not bloq.is_empty():
			celulas_bloqueadas[celula] = true
			motivos_bloqueio[celula] = bloq
	mapa = Renderizador.new()
	mapa.name = "Mapa"
	add_child(mapa)
	move_child(mapa, 0)
	mapa.tiles_visiveis = vista_tiles
	mapa.carregar(SLUG, Vector2(-1, 2))
	_outfits = Outfits.padrao()
	for n in Fontes.ler_json(Fontes.pasta_snapshot() + "/api/city-npcs/cerulean.json") if Fontes.ler_json(Fontes.pasta_snapshot() + "/api/city-npcs/cerulean.json") is Array else []:
		_criar_npc(n)
	print("Cerulean: células=", celulas_existentes.size(), "; bloqueadas=", celulas_bloqueadas.size(), "; carga ", mapa.tempos_carga.get("total_ms", 0), " ms (", mapa.origem_cache, ")")


func _criar_npc(n: Dictionary) -> void:
	var kind := String(n.get("kind", ""))
	if not NPCS.has(kind):
		return
	var c: Dictionary = NPCS[kind]
	var rid := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(rid, mapa.rid_andar())
	RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	var rs := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(rs, mapa.rid_sombra())
	RenderingServer.canvas_item_set_default_texture_filter(rs, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	var e := {"kind": kind, "nome": String(c["nome"]), "x": int(n["x"]), "y": int(n["y"]), "rid": rid, "sombra": rs,
		"looktype": int(c.get("looktype", 0)), "quadro": 0, "t": 0.0, "tex": null}
	if int(e["looktype"]) > 0 and _outfits.obter(int(e["looktype"])).get("looktype", -1) != int(e["looktype"]):
		e["looktype"] = 0    # sem o outfit no pacote: o ícone (styleNpc sem looktype, C)
	if int(e["looktype"]) == 0:
		e["tex"] = load("res://assets/original/npc/" + String(c["icone"])) as Texture2D
	npcs.append(e)
	RenderingServer.canvas_item_set_draw_index(rid, mapa.posto_entidade(1.0e7 + Regras.sx(int(e["x"]), floori(float(e["y"]) + 1.5 - 0.64)) + 0.4))
	_desenhar_npc(e)


func _desenhar_npc(e: Dictionary) -> void:
	var tex: Texture2D
	var reg := Rect2()
	if int(e["looktype"]) > 0:
		var q: Dictionary = _outfits.quadro(_outfits.obter(int(e["looktype"])), 3, int(e["quadro"]))
		if q.is_empty():
			return
		tex = q["tex"]
		reg = q["rect"]
	else:
		tex = e["tex"]
		if tex == null:
			return
		reg = Rect2(Vector2.ZERO, tex.get_size())
	var w := reg.size.x
	var h := reg.size.y
	var pes := Vector2(32.0 * int(e["x"]) + 16.0, 32.0 * int(e["y"]) + 16.0)
	RenderingServer.canvas_item_clear(e["rid"])
	RenderingServer.canvas_item_add_texture_rect_region(e["rid"], Rect2(pes.x - w * 0.5, pes.y - (h - Sombras.PES_CRIATURA), w, h), tex.get_rid(), reg)
	RenderingServer.canvas_item_clear(e["sombra"])
	var r := Sombras.retangulo(mapa.m_sombra_inv(), pes + Vector2(0, Sombras.PES_CRIATURA), w, h, 0.5)
	RenderingServer.canvas_item_add_texture_rect_region(e["sombra"], r, tex.get_rid(), reg, mapa.cor_sombra)


func npc(kind: String) -> Dictionary:
	for e in npcs:
		if String(e["kind"]) == kind:
			return e
	return {}


func celula_transitavel(celula: Vector2i) -> bool:
	return celulas_existentes.has(celula) and not celulas_bloqueadas.has(celula)


func adicionar_treinador(treinador: Node2D) -> void:
	## O Node2D entra na árvore (processa, anima, recebe posição) e o canvas item dele passa para o andar do chão do
	## renderizador, onde o draw_index do zIndex de criatura o põe entre as peças do mapa (C).
	add_child(treinador)
	if mapa != null:
		RenderingServer.canvas_item_set_parent(treinador.get_canvas_item(), mapa.rid_andar())
	_entidades.append(treinador)


func atualizar_cobertura(posicao_local: Vector2, _imediato: bool = false) -> void:
	## O andar de cima some quando há chão sobre o herói (computeFirstVisibleFloor, C) e os chunks seguem a câmera.
	if mapa != null:
		mapa.definir_centro((posicao_local - Vector2(16, 16)) / 32.0)


func definir_vista(tiles: Vector2) -> void:
	vista_tiles = tiles
	if mapa != null and mapa.tiles_visiveis != tiles:
		mapa.tiles_visiveis = tiles
		mapa.definir_centro(mapa.centro_tile)


func _process(delta: float) -> void:
	if mapa == null:
		return
	_entidades = _entidades.filter(func(n): return is_instance_valid(n))
	for n in _entidades:
		var t: Vector2 = ((n as Node2D).position - Vector2(16, 16)) / 32.0
		RenderingServer.canvas_item_set_draw_index(n.get_canvas_item(), mapa.posto_entidade(1.0e7 + Regras.sx(roundi(t.x), floori(t.y + 1.5 - 0.64)) + 0.4))
	for e in npcs:   # tickNpcs (C): só os de looktype com mais de um quadro, pelo dur de cada quadro
		if int(e["looktype"]) <= 0:
			continue
		var o: Dictionary = _outfits.obter(int(e["looktype"]))
		var nq: int = _outfits.quadros(o, 3)
		if nq <= 1:
			continue
		e["t"] = float(e["t"]) + delta * 1000.0
		var dur := float(_outfits.quadro(o, 3, int(e["quadro"])).get("dur", 150))
		if float(e["t"]) >= dur:
			e["t"] = 0.0
			e["quadro"] = (int(e["quadro"]) + 1) % nq
			_desenhar_npc(e)


func _exit_tree() -> void:
	for e in npcs:
		RenderingServer.free_rid(e["rid"])
		RenderingServer.free_rid(e["sombra"])
	npcs.clear()
