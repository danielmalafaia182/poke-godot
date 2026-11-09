extends Node2D
## Cena de hunt sobre a simulação (fase 2). A simulação (sim/) decide tudo, em processo e sem rede; esta cena só:
##   1. monta a configuração a partir do save (EstadoJogo) → sim/cenario_jogo.gd;
##   2. dá o relógio real à simulação (um passo() a cada tick_ms) e repassa as mensagens à vista (render/vista_hunt.gd);
##   3. aplica no save o que as mensagens dizem: XP do treinador e do Pokémon, loot, poções e bolas gastas, capturas
##      e o HP do time ao sair;
##   4. HUD mínima: time (com troca manual por clique), contador Capture, cartões de derrota e "Voltar para a cidade".
## Cidade, mapa-múndi, painéis, inventário e save continuam os de antes. A cena antiga (Caca.tscn) segue no projeto.

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Apresentacao := preload("res://sim/regras_apresentacao.gd")
const Vista := preload("res://render/vista_hunt.gd")
const ESPECIES: Script = preload("res://especies_importadas.gd")
const LOOT: Script = preload("res://regras_loot.gd")
const CARTOES: Script = preload("res://cartoes_derrota.gd")
const CENA_CIDADE := "res://cidade.tscn"

signal hunt_encerrada(motivo: String)

@export var velocidade := 1.0          # ticks por tick real (testes aceleram; o jogo usa 1)
@export var semente := 0               # 0 = aleatória por entrada
@export var trocar_de_cena_ao_sair := true

var dados: RefCounted
var sim: RefCounted
var vista: Node2D
var apresentacao = Apresentacao.new()
var membros: Array = []                # DadosPokemon do time, na ordem da simulação
var _proximo_tick_ms := 0.0
var _encerrada := false
var registro := {"xp_treinador": 0, "xp_pokemon": 0, "loot": {}, "loot_fora_do_catalogo": {}, "pocoes": {},
	"bolas": {}, "capturas": 0, "abates": 0, "cartoes": 0}
var hud: CanvasLayer
var _rotulo_captura: Label
var _cartoes: Control
var _linhas_time: Array = []
var _aviso: Label
var _hp_time: Array = []


func _ready() -> void:
	dados = DadosJogo.carregar()
	var especie = EstadoJogo.especie_caca
	var nome := String(especie.nome) if especie != null else "Rhydon"
	if not CenarioJogo.disponivel(dados, nome):
		push_error("hunt de %s indisponível na simulação (sem mapa/hunt-config no snapshot)" % nome)
		_sair("indisponivel")
		return
	var agora := int(Time.get_unix_time_from_system() * 1000.0)
	var cfg := CenarioJogo.configurar(_extrair_save(nome), dados, semente if semente != 0 else agora % 2147483647, agora)
	var mapa = MapaHunt.carregar(cfg["slug"], Fontes.ler_mapa(cfg["slug"]), Fontes.ler_colisao())
	sim = Simulacao.new(cfg, dados, mapa)
	vista = Vista.new()
	add_child(vista)
	vista.nome_treinador = String(EstadoJogo.nome_treinador)
	_montar_hud()
	for m in sim.iniciar():
		_tratar(m["msg"])
	_proximo_tick_ms = Time.get_ticks_msec() + float(sim.p.tick_ms)


func _extrair_save(nome_hunt: String) -> Dictionary:
	membros = []
	var equipe: Array = []
	for pk in EstadoJogo.time_pokemon:
		if pk == null or pk.especie == null:
			continue
		pk.normalizar_atributos()
		membros.append(pk)
		equipe.append({"id": pk.id_persistente, "nome": String(pk.especie.nome), "xp": pk.experiencia_total,
			"ivs": {"hp": pk.iv_hp, "atk": pk.iv_atk, "def": pk.iv_def, "spAtk": pk.iv_sp_atk, "spDef": pk.iv_sp_def, "speed": pk.iv_spd},
			"quality": pk.qualidade, "hp": pk.obter_vida_atual()})
	var inventario: Array = []
	for id in EstadoJogo.estoque_pocoes:
		inventario.append({"itemId": int(id), "quantity": int(EstadoJogo.estoque_pocoes[id])})
	var nomes_bolas := {}
	for id in EstadoJogo.estoque_bolas:
		nomes_bolas[id] = String(EstadoJogo.obter_dados_bola(int(id)).get("nome", "Ball"))
	return {"hunt": nome_hunt, "equipe": equipe, "treinador_xp": EstadoJogo.experiencia_treinador_acumulada,
		"inventario": inventario, "bolas": EstadoJogo.estoque_bolas.duplicate(), "nomes_bolas": nomes_bolas,
		"auto_catch": EstadoJogo.auto_catch, "bola_auto_catch": EstadoJogo.auto_catch_ball_id,
		"auto_potion": EstadoJogo.auto_potion, "pocao_id": EstadoJogo.auto_potion_item_id,
		"limite_pocao": EstadoJogo.auto_potion_threshold}


func _process(_delta: float) -> void:
	if sim == null or _encerrada:
		return
	var agora := float(Time.get_ticks_msec())
	var passo := float(sim.p.tick_ms) / maxf(0.001, velocidade)
	var n := 0
	while agora >= _proximo_tick_ms and n < 50:
		for m in sim.passo():
			_tratar(m["msg"])
			if _encerrada:
				return
		_proximo_tick_ms += passo
		n += 1
	if n >= 50:
		_proximo_tick_ms = agora + passo      # parou (ex.: janela minimizada): não despeja minutos de ticks
	_atualizar_hud()


func _tratar(msg: Dictionary) -> void:
	vista.receber(msg)
	match String(msg.get("type", "")):
		"field-init":
			apresentacao.nova_instancia(String(msg["huntKey"]))
			_rotulo_captura.text = "Capture: %d" % apresentacao.capturas
		"field":
			_hp_time = msg.get("bossTeam", [])
		"field-kill":
			registro["abates"] += 1
			EstadoJogo.registrar_recompensa_treinador(int(msg["xpGained"]))
			registro["xp_treinador"] += int(msg["xpGained"])
			_receber_loot(msg.get("loot", []))
			if apresentacao.mostrar_cartao(msg, Time.get_ticks_msec()):
				registro["cartoes"] += 1
				_cartoes.apresentar(_evento_cartao(msg))
		"poke-xp":
			var pk = _membro_por_id(String(msg.get("id", "")))
			if pk != null:
				EstadoJogo.conceder_experiencia(pk, int(msg["xpGained"]))
				registro["xp_pokemon"] += int(msg["xpGained"])
		"auto-heal":
			var pid := _id_pocao(String(msg.get("name", "")))
			if pid > 0 and EstadoJogo.consumir_pocao(pid):
				registro["pocoes"][pid] = int(registro["pocoes"].get(pid, 0)) + 1
		"catch-result":
			var bola := int(msg.get("ballId", 0))
			if EstadoJogo.consumir_bola(bola):
				registro["bolas"][bola] = int(registro["bolas"].get(bola, 0)) + 1
			_rotulo_captura.text = "Capture: %d" % apresentacao.ao_resultado_captura(msg)
			if bool(msg.get("success", false)):
				_registrar_captura(String(msg.get("speciesName", "")))
		"field-none":
			_sair(String(msg.get("motivo", "saida")))
		"error":
			_avisar(String(msg.get("message", "")))


func _membro_por_id(id: String):
	## poke-xp vem do ativo; o id é o id_persistente do save (Pokémon antigo pode não ter: usa o ativo)
	if id != "":
		for pk in membros:
			if pk.id_persistente == id:
				return pk
	return membros[sim.ativo] if sim != null and sim.ativo < membros.size() else null


func _id_pocao(nome: String) -> int:
	for id in EstadoJogo.estoque_pocoes:
		if String(EstadoJogo.obter_dados_pocao(int(id)).get("nome", "")) == nome:
			return int(id)
	return -1


func _receber_loot(loot: Array) -> void:
	## O catálogo de itens do jogo (regras_loot.gd) é o gerado do snapshot (670): todo item do loot existe. O que ainda
	## assim faltar (não deveria) fica em registro.loot_fora_do_catalogo, porque receber_loot recusa o lote inteiro.
	var aceitos: Array[Dictionary] = []
	for it in loot:
		var interno: int = LOOT.id_interno(int(it["itemId"]))   # ids 1..7 do servidor → 1000000 + id (convenção do save)
		if LOOT.obter(interno).is_empty():
			registro["loot_fora_do_catalogo"][int(it["itemId"])] = int(registro["loot_fora_do_catalogo"].get(int(it["itemId"]), 0)) + int(it["qty"])
			continue
		aceitos.append({"itemId": interno, "qty": int(it["qty"])})
	if aceitos.is_empty():
		return
	for it in EstadoJogo.inventario.receber_loot(aceitos):
		registro["loot"][int(it["itemId"])] = int(registro["loot"].get(int(it["itemId"]), 0)) + int(it["qty"])


func _registrar_captura(nome: String) -> void:
	## A: o Pokémon capturado chega como poke-delta de nível 1 (5/5 capturas da rhydon-1h); IVs e Quality pelo sorteio
	## do próprio jogo (DadosPokemon), como nas capturas do P04.
	var especie = ESPECIES.obter_especies().get(nome)
	if especie == null:
		return
	var novo := DadosPokemon.new()
	novo.especie = especie
	novo.nivel = 1
	novo.sortear_ivs()
	novo.sortear_qualidade()
	novo.normalizar_atributos()
	novo.vida_atual = novo.obter_vida_maxima()
	if EstadoJogo.registrar_captura(novo):
		registro["capturas"] += 1


func _evento_cartao(msg: Dictionary) -> Dictionary:
	var ev := msg.duplicate(true)
	var loot: Array = []
	for it in msg.get("loot", []):
		var c: Dictionary = LOOT.obter(LOOT.id_interno(int(it["itemId"])))
		loot.append({"itemId": LOOT.id_interno(int(it["itemId"])), "name": String(it["name"]), "qty": int(it["qty"]),
			"icon": c.get("icone", ""), "rare": bool(c.get("raro", false))})
	ev["loot"] = loot
	return ev


func trocar(indice: int) -> void:
	## Troca manual: a simulação aplica (ou recusa) a regra dos 5 s depois de um KO (E).
	if sim != null and not _encerrada:
		for m in sim.passo([{"type": "switch", "teamIndex": indice}]):
			_tratar(m["msg"])


func voltar_cidade() -> void:
	if sim != null and not _encerrada:
		for m in sim.passo([{"type": "leave-hunt"}]):
			_tratar(m["msg"])
	elif not _encerrada:
		_sair("saida")


func _sair(motivo: String) -> void:
	if _encerrada:
		return
	_encerrada = true
	# HP do time como a simulação deixou (sem curar; desmaiado fica com 0)
	if sim != null:
		for i in mini(membros.size(), sim.equipe.size()):
			EstadoJogo.registrar_vida_pokemon(membros[i], int(sim.equipe[i]["hp"]))
	EstadoJogo.solicitar_salvamento()
	hunt_encerrada.emit(motivo)
	if trocar_de_cena_ao_sair and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(CENA_CIDADE)


# ------------------------------------------------------------------- HUD mínima

func _montar_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var painel := PanelContainer.new()
	painel.position = Vector2(16, 16)
	hud.add_child(painel)
	var coluna := VBoxContainer.new()
	painel.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "%s — Nv %d" % [String(EstadoJogo.nome_treinador), int(EstadoJogo.nivel_treinador)]
	coluna.add_child(titulo)
	for i in membros.size():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(260, 30)
		b.pressed.connect(trocar.bind(i))
		coluna.add_child(b)
		_linhas_time.append(b)
	_rotulo_captura = Label.new()
	_rotulo_captura.text = "Capture: 0"
	coluna.add_child(_rotulo_captura)
	var voltar := Button.new()
	voltar.text = "Voltar para a cidade"
	voltar.pressed.connect(voltar_cidade)
	coluna.add_child(voltar)
	_aviso = Label.new()
	_aviso.add_theme_color_override("font_color", Color(1, 0.7, 0.4))
	coluna.add_child(_aviso)
	_cartoes = CARTOES.new()
	_cartoes.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_cartoes.position = Vector2(get_viewport().get_visible_rect().size.x - 360, 16)
	_cartoes.size = Vector2(340, 600)
	hud.add_child(_cartoes)


func _atualizar_hud() -> void:
	for i in _linhas_time.size():
		var pk = membros[i]
		var hp := int(_hp_time[i]["hp"]) if i < _hp_time.size() else 0
		var mx := int(_hp_time[i]["maxHp"]) if i < _hp_time.size() else 1
		var b: Button = _linhas_time[i]
		var ativo: bool = sim != null and sim.ativo == i
		b.text = "%s %s  Nv %d   %d/%d" % ["▶" if ativo else "  ", String(pk.especie.nome), int(sim.equipe[i]["nivel"]) if sim != null and i < sim.equipe.size() else pk.nivel, hp, mx]
		b.modulate = Color(1, 1, 1) if hp > 0 else Color(0.55, 0.55, 0.55)


func _avisar(texto: String) -> void:
	if _aviso != null:
		_aviso.text = texto
