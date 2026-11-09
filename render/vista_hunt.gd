extends Node2D
## Vista da hunt: desenha o que a simulação manda, como o cliente original (fonte C), sem decidir nada de jogo.
##   - mapa: render/mapa_renderizador.gd (andares, ordem, streaming);
##   - entidades: herói, treinador, selvagens e cadáveres como canvas items no andar do chão, com o draw_index do
##     zIndex original (criatura: 1e7 + sx(round(x), floor(y + 1,5 − 0,64)) + 0,4; cadáver: 5e6 + sx(x, y) + 0,35);
##   - interpolação e laço por quadro: render/estado_vista.gd (walkFrom/stepStartAt/serverNow);
##   - placas (nome + barra de HP) e números de dano: camada de HUD, 46 px lógicos acima do tile; dano dura 950 ms,
##     sobe 60 px, entra em 16% do tempo (C); com dmgDelayMs no hit, aparece depois desse atraso (C).
## Entrada: `receber(msg)` com cada mensagem da simulação (field-init, field e as demais, que só a HUD da cena usa).

signal hit_mostrado(hit: Dictionary)

const Renderizador := preload("res://render/mapa_renderizador.gd")
const EstadoVista := preload("res://render/estado_vista.gd")
const Outfits := preload("res://render/outfits.gd")
const Regras := preload("res://render/regras_desenho.gd")
const Fontes := preload("res://sim/fontes.gd")

const LARGURA_LOGICA := 1600.0     # o original desenha numa tela lógica de 1600×832
const ALTURA_LOGICA := 832.0
const TILES_LARGURA := 25.0        # "25×13" em zoom 1 (C)
const DANO_MS := 950.0
const FONTE := "res://assets/interface/fiel/barlow_bold.ttf"

var mapa: Node2D
var estado = EstadoVista.new()
var outfits: RefCounted
var nomes_especie: Dictionary = {}     # speciesId -> nome
var looktype_especie: Dictionary = {}  # speciesId -> looktype
var nome_treinador := "Treinador"
var looktype_treinador := 5759
# E: o save não guarda as cores do outfit do treinador; padrão = as do personagem do poke-local (head 94, body 95)
var cores_treinador := {"head": 94, "body": 95, "legs": 0, "feet": 0}
var _ents: Dictionary = {}             # chave -> {rid, looktype}
var _cadaveres: Dictionary = {}        # "row,col" -> rid
var _corpses_assets: Dictionary = {}
var _corpses_paginas: Array = []
var paginas_cadaver_faltando: Array = []
var hud: CanvasLayer
var _placas: Dictionary = {}           # chave -> Control
var _danos: Array = []                 # {no, t, x, y}
var _atrasados: Array = []             # hits com dmgDelayMs: {ate, hit}
var _fonte: Font
var escala := 2.4
var ultimo_quadro: Dictionary = {}
var _slug_carregado := ""


func _ready() -> void:
	outfits = Outfits.padrao()
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	_fonte = load(FONTE) if ResourceLoader.exists(FONTE) else ThemeDB.fallback_font
	for e in _ler_especies():
		nomes_especie[int(e["id"])] = String(e["nome"])
		looktype_especie[int(e["id"])] = int(e.get("looktype", 0))
	_carregar_cadaveres()


static func _ler_especies() -> Array:
	var d = Fontes.ler_json(Fontes.pasta_dados() + "/gerados/especies.json")
	return d if d is Array else d.get("especies", [])


func _carregar_cadaveres() -> void:
	## loadCorpses (C): game/corpses/corpses.json do snapshot (503 assets) e as páginas que ele lista. As páginas vêm do
	## snapshot se estiverem lá, senão do poke-local (o atlas é o mesmo: os 501 assets em comum têm frames idênticos).
	## Página que não existe em lugar nenhum fica nula e o cadáver dela não é desenhado (ver paginas_cadaver_faltando).
	var snap := Fontes.pasta_snapshot()
	var d = Fontes.ler_json(snap + "/game/corpses/corpses.json")
	if not d is Dictionary:
		return
	_corpses_assets = d["assets"]
	for p in d["pages"]:
		var tex = null
		for base in [snap, Fontes.raiz_projeto() + "/poke-local/public"]:
			var caminho: String = String(base) + String(p)
			var img := Image.new()
			if FileAccess.file_exists(caminho) and img.load_webp_from_buffer(FileAccess.get_file_as_bytes(caminho)) == OK:
				tex = ImageTexture.create_from_image(img)
				break
		_corpses_paginas.append(tex)
		if tex == null:
			paginas_cadaver_faltando.append(String(p))


func receber(msg: Dictionary) -> void:
	var tipo := String(msg.get("type", ""))
	var agora := _agora()
	if tipo == "field-init":
		estado.receber_init(msg)
		if String(msg["slug"]) != _slug_carregado:
			_carregar_mapa(String(msg["slug"]))
	elif tipo == "field":
		estado.receber_field(msg, agora)
		_hits(msg.get("hits", []), msg)
		_sincronizar_cadaveres(msg.get("corpses", []))


func _carregar_mapa(slug: String) -> void:
	if mapa != null:
		mapa.queue_free()
		for k in _ents.keys():
			RenderingServer.free_rid(_ents[k]["rid"])
		_ents.clear()
		for k in _cadaveres.keys():
			RenderingServer.free_rid(_cadaveres[k])
		_cadaveres.clear()
	mapa = Renderizador.new()
	add_child(mapa)
	move_child(mapa, 0)
	mapa.carregar(slug)
	_slug_carregado = slug


static func _agora() -> float:
	return Time.get_unix_time_from_system() * 1000.0


func _process(_delta: float) -> void:
	if mapa == null or estado.field.is_empty():
		return
	var agora := _agora()
	var tela := get_viewport_rect().size
	escala = tela.x / (TILES_LARGURA * 32.0)
	mapa.tiles_visiveis = tela / (32.0 * escala)
	var v: Dictionary = estado.quadro(agora)
	ultimo_quadro = v
	if v.is_empty():
		return
	var ox := float(estado.init.get("minTx", 0))
	var oy := float(estado.init.get("minTy", 0))
	var heroi := Vector2(ox + float(v["hero"]["col"]), oy + float(v["hero"]["row"]))
	mapa.definir_centro(heroi)
	mapa.scale = Vector2(escala, escala)
	mapa.position = tela / 2.0 - (heroi * 32.0 + Vector2(16, 16)) * escala
	var f: Dictionary = estado.field
	_entidade("treinador", looktype_treinador, v["trainer"], ox, oy, true)
	_entidade("heroi", int(f.get("heroLooktype", 0)), v["hero"], ox, oy, true)
	var vivos := {}
	for slot in v["mobs"]:
		var m: Dictionary = v["mobs"][slot]
		var lt := int(looktype_especie.get(int(m["speciesId"]), 0))
		_entidade("mob%d" % int(slot), lt, m, ox, oy, not bool(m["dead"]))
		vivos["mob%d" % int(slot)] = true
	for k in _ents.keys():
		if k.begins_with("mob") and not vivos.has(k):
			RenderingServer.free_rid(_ents[k]["rid"])
			_ents.erase(k)
	_placas_quadro(v, f, ox, oy, tela)
	_danos_quadro(agora, tela)


func _entidade(chave: String, looktype: int, vista: Dictionary, ox: float, oy: float, visivel: bool) -> void:
	var e: Dictionary = _ents.get(chave, {})
	if e.is_empty():
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, mapa.rid_andar())
		RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		e = {"rid": rid, "chave_quadro": "", "posto": -1}
		_ents[chave] = e
	var rid: RID = e["rid"]
	RenderingServer.canvas_item_set_visible(rid, visivel)
	if not visivel:
		return
	var o: Dictionary = outfits.obter(looktype, cores_treinador if chave == "treinador" else {})
	if o.is_empty():
		return
	var dir := int(Outfits.DIRECAO.get(String(vista["dir"]), 3))
	# syncCreatures (C): quadro 0 parado; andando, 1 + min(n − 1, floor(fase × n)) com n = quadros − 1
	var n := maxi(0, maxi(1, outfits.quadros(o, dir)) - 1)
	var l := 0
	if bool(vista.get("walking", false)) and n >= 1:
		l = 1 + mini(n - 1, floori(float(vista.get("walkPhase", 0.0)) * n))
	var q: Dictionary = outfits.quadro(o, dir, l)
	if q.is_empty():
		return
	var tx := ox + float(vista["col"])
	var ty := oy + float(vista["row"])
	var w: float = (q["rect"] as Rect2).size.x
	var h: float = (q["rect"] as Rect2).size.y
	var px := 32.0 * tx + 16.0 - w * 0.5
	var py := 32.0 * ty + 16.0 - (h - 11.52)
	var chave_q := "%d|%d|%d|%.2f|%.2f" % [looktype, dir, l, px, py]
	if chave_q != String(e["chave_quadro"]):
		e["chave_quadro"] = chave_q
		RenderingServer.canvas_item_clear(rid)
		RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(px, py, w, h), (q["tex"] as Texture2D).get_rid(), q["rect"])
	var z := 1.0e7 + Regras.sx(roundi(tx), floori(ty + 1.5 - 0.64)) + 0.4
	var posto: int = mapa.posto_entidade(z)
	if posto != int(e["posto"]):
		e["posto"] = posto
		RenderingServer.canvas_item_set_draw_index(rid, posto)


func _sincronizar_cadaveres(lista: Array) -> void:
	if mapa == null:
		return
	var ox := int(estado.init.get("minTx", 0))
	var oy := int(estado.init.get("minTy", 0))
	var ver := {}
	for c in lista:
		var k := "%d,%d,%d" % [int(c["row"]), int(c["col"]), int(c["corpse"])]
		ver[k] = true
		if _cadaveres.has(k):
			continue
		var a: Dictionary = _corpses_assets.get(str(int(c["corpse"])), {})
		if a.is_empty():
			continue
		var f: Dictionary = a["frames"][0]
		var tex = _corpses_paginas[int(f["page"])] if int(f["page"]) < _corpses_paginas.size() else null
		if tex == null:
			continue
		var tx := ox + int(c["col"])
		var ty := oy + int(c["row"])
		var w := float(a["width"])
		var h := float(a["height"])
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, mapa.rid_andar())
		RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(32.0 * tx - (w - 32.0), 32.0 * ty - (h - 32.0), w, h),
			(tex as Texture2D).get_rid(), Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"])))
		RenderingServer.canvas_item_set_draw_index(rid, mapa.posto_entidade(5.0e6 + Regras.sx(tx, ty) + 0.35))
		_cadaveres[k] = rid
	for k in _cadaveres.keys():
		if not ver.has(k):
			RenderingServer.free_rid(_cadaveres[k])
			_cadaveres.erase(k)


func tile_para_tela(tx: float, ty: float) -> Vector2:
	## tileToView: centro do tile em pixels de tela.
	return mapa.position + (Vector2(tx, ty) * 32.0 + Vector2(16, 16)) * escala


func _px_logico() -> float:
	return get_viewport_rect().size.x / LARGURA_LOGICA


func _placas_quadro(v: Dictionary, f: Dictionary, ox: float, oy: float, tela: Vector2) -> void:
	var ver := {}
	var dy := 46.0 * _px_logico()
	for slot in v["mobs"]:
		var m: Dictionary = v["mobs"][slot]
		var k := "mob%d" % int(slot)
		if bool(m["dead"]):
			continue
		var nome := ("✨ " if bool(m.get("shiny", false)) else "") + String(nomes_especie.get(int(m["speciesId"]), "?"))
		var pct := 100.0 * float(m["hp"]) / maxf(1.0, float(m["maxHp"]))
		_placa(k, nome, pct, tile_para_tela(ox + float(m["col"]), oy + float(m["row"])) - Vector2(0, dy))
		ver[k] = true
	var hero: Dictionary = v["hero"]
	_placa("heroi", String(f.get("heroName", "")), 100.0 * float(f.get("heroHp", 0)) / maxf(1.0, float(f.get("heroMaxHp", 1))),
		tile_para_tela(ox + float(hero["col"]), oy + float(hero["row"])) - Vector2(0, dy))
	ver["heroi"] = true
	var tr: Dictionary = v["trainer"]
	_placa("treinador", nome_treinador, -1.0, tile_para_tela(ox + float(tr["col"]), oy + float(tr["row"])) - Vector2(0, dy))
	ver["treinador"] = true
	for k in _placas.keys():
		if not ver.has(k):
			_placas[k].queue_free()
			_placas.erase(k)


func _placa(chave: String, nome: String, pct: float, pos: Vector2) -> void:
	var p: Control = _placas.get(chave)
	var esc := _px_logico()
	if p == null:
		p = Control.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rotulo := Label.new()
		rotulo.name = "Nome"
		rotulo.add_theme_font_override("font", _fonte)
		rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
		rotulo.add_theme_constant_override("outline_size", 4)
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(rotulo)
		var fundo := ColorRect.new()
		fundo.name = "Fundo"
		fundo.color = Color(0, 0, 0, 0.85)
		p.add_child(fundo)
		var barra := ColorRect.new()
		barra.name = "Barra"
		p.add_child(barra)
		hud.add_child(p)
		_placas[chave] = p
	var rot: Label = p.get_node("Nome")
	rot.add_theme_font_size_override("font_size", roundi(11.0 * esc))
	if rot.text != nome:
		rot.text = nome
	rot.size = Vector2(200, 16) * esc
	rot.position = Vector2(-100 * esc, -21 * esc)
	var tem_barra := pct >= 0.0
	var fundo: ColorRect = p.get_node("Fundo")
	var barra: ColorRect = p.get_node("Barra")
	fundo.visible = tem_barra
	barra.visible = tem_barra
	if tem_barra:
		# setPlate (C): fundo 31×4, preenchimento 29 × pct, 2 px de altura
		fundo.size = Vector2(31, 4) * esc
		fundo.position = Vector2(-15.5, -4) * esc
		barra.size = Vector2(maxf(0.001, 29.0 * clampf(pct, 0, 100) / 100.0), 2) * esc
		barra.position = Vector2(-14.5, -3) * esc
		barra.color = Color.from_hsv(0.33 * clampf(pct, 0, 100) / 100.0, 0.85, 0.9)
	p.position = pos


func _hits(hits: Array, f: Dictionary) -> void:
	var agora := _agora()
	for h in hits:
		var atraso := float(h.get("dmgDelayMs", 0))
		if atraso > 0.0 and int(h["slot"]) >= 0:
			_atrasados.append({"ate": agora + atraso, "hit": h})
		else:
			_mostrar_dano(h)


func _mostrar_dano(h: Dictionary) -> void:
	var v := ultimo_quadro
	if v.is_empty():
		v = estado.quadro(_agora())
	if v.is_empty():
		return
	var ox := float(estado.init.get("minTx", 0))
	var oy := float(estado.init.get("minTy", 0))
	var alvo: Dictionary = v["hero"] if int(h["slot"]) < 0 else v["mobs"].get(int(h["slot"]), {})
	if alvo.is_empty():
		return
	var pos := tile_para_tela(ox + float(alvo["col"]), oy + float(alvo["row"])) - Vector2(0, 46.0 * _px_logico())
	var r := Label.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("font", _fonte)
	r.add_theme_font_size_override("font_size", roundi(15.0 * _px_logico()))
	r.add_theme_color_override("font_outline_color", Color.BLACK)
	r.add_theme_constant_override("outline_size", roundi(6.0 * _px_logico()))
	var para_heroi := int(h["slot"]) < 0
	var eff := float(h.get("eff", 1))
	# F: as cores das classes CSS (to-hero, super, weak) não estão no snapshot; vermelho no herói, amarelo super, cinza fraco
	r.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if para_heroi else (Color(1, 0.85, 0.2) if eff > 1.0 else (Color(0.8, 0.8, 0.8) if eff > 0.0 and eff < 1.0 else Color.WHITE)))
	r.text = ("-" if para_heroi else "") + str(int(h["amount"]))
	hud.add_child(r)
	r.reset_size()
	_danos.append({"no": r, "t": 0.0, "x": pos.x - r.size.x / 2.0, "y": pos.y - r.size.y})
	if _danos.size() > 24:
		var velho: Dictionary = _danos.pop_front()
		velho["no"].queue_free()
	hit_mostrado.emit(h)


func _danos_quadro(agora: float, _tela: Vector2) -> void:
	for i in range(_atrasados.size() - 1, -1, -1):
		if float(_atrasados[i]["ate"]) <= agora:
			_mostrar_dano(_atrasados[i]["hit"])
			_atrasados.remove_at(i)
	var dt := get_process_delta_time() * 1000.0
	for i in range(_danos.size() - 1, -1, -1):
		var d: Dictionary = _danos[i]
		d["t"] = float(d["t"]) + dt
		var a := minf(1.0, float(d["t"]) / DANO_MS)
		var no: Label = d["no"]
		no.position = Vector2(float(d["x"]), float(d["y"]) - 60.0 * _px_logico() * a)
		no.modulate.a = a / 0.16 if a < 0.16 else 1.0 - (a - 0.16) / 0.84
		if a >= 1.0:
			no.queue_free()
			_danos.remove_at(i)


func _exit_tree() -> void:
	for k in _ents.keys():
		RenderingServer.free_rid(_ents[k]["rid"])
	_ents.clear()
	for k in _cadaveres.keys():
		RenderingServer.free_rid(_cadaveres[k])
	_cadaveres.clear()
