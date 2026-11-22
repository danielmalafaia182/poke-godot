extends Node2D
## Cena de hunt sobre a simulação (fase 2). A simulação (sim/) decide tudo, em processo e sem rede; esta cena só:
##   1. monta a configuração a partir do save (EstadoJogo) → sim/cenario_jogo.gd;
##   2. dá o relógio real à simulação (um passo() a cada tick_ms) e repassa as mensagens à vista (render/vista_hunt.gd);
##   3. aplica no save o que as mensagens dizem: XP do treinador e do Pokémon, loot, poções e bolas gastas, capturas
##      e o HP do time ao sair;
##   4. HUD: a mesma da cena antiga (hud_caca.gd + painel_auto_helper.gd, sem mudar esses arquivos). Esta cena oferece
##      a interface de "controlador" que eles usam (sinais derrota_recompensada/captura_resolvida/aliado_alterado,
##      obter_troca_restante, painel_auto_helper, _on_botao_voltar_cidade_pressed...). A troca de líder pelo painel passa
##      pelo EstadoJogo.validador_troca_lider (regra dos 5 s da simulação, E); a troca por KO vira o líder no save; o HP
##      do time vai para o save a cada field (o painel de time lê de lá); mudar o Auto-Helper durante a hunt vale na hora.
## Cidade, mapa-múndi, painéis, inventário e save continuam os de antes. A cena antiga (Caca.tscn) foi removida no ciclo 3.

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

const PONTE_DADOS := preload("res://ponte_cidade.gd")
signal hunt_encerrada(motivo: String)
# interface que hud_caca.gd espera do controlador (a mesma da cena antiga)
signal derrota_recompensada(evento: Dictionary)
signal captura_resolvida(evento: Dictionary)
signal capturado(nome: String, shiny: bool)
signal pendentes_alterados(lista: Array)   # ciclo 4: selvagens capturáveis (lista pending da sim)
signal resultado_captura(msg: Dictionary)
signal bola_lancada
signal pocao_usada
signal subiu_nivel(nome: String, nivel: int, treinador: bool)   # ciclo 2: avisos da HUD
signal boosts_alterados(lista: Array)
signal shiny_apareceu(nome: String)
var _shinies_vistos := {}
var _boosts_msg: Array = []
var _eventos_msg: Array = []
signal aliado_alterado(pokemon: DadosPokemon)
signal ofensiva_aliado_alterada(diagnostico: Dictionary)

@export var velocidade := 1.0          # ticks por tick real (testes aceleram; o jogo usa 1)
@export var semente := 0               # 0 = aleatória por entrada
@export var trocar_de_cena_ao_sair := true
static var sem_trocar_cena_global := false    # testes de varredura: a cena não volta sozinha para a cidade

var dados: RefCounted
var sim: RefCounted
var vista: Node2D
var apresentacao = Apresentacao.new()
var membros: Array = []                # DadosPokemon do time, na ordem da simulação
var _proximo_tick_ms := 0.0
const ATRASO_MAX_MS := 3600000.0
var _encerrada := false
var registro := {"xp_treinador": 0, "xp_pokemon": 0, "loot": {}, "loot_fora_do_catalogo": {}, "pocoes": {},
	"bolas": {}, "capturas": 0, "abates": 0, "cartoes": 0}
var hud: CanvasLayer
var hud_caca: Control
var painel_auto_helper: Control
var titulo := Label.new()
var botao_voltar_cidade := Button.new()
var populacao_iniciada := true
var pokemon_aliado: DadosPokemon = null      # a placa do aliado é desenhada pela vista (render/vista_hunt.gd)
var imagem_aliado := Node2D.new()
var vida_aliado := 1
var diagnostico_ofensivo_aliado: Dictionary = {}
var usar_golpes_catalogados := false
var aplicar_cooldowns_catalogo := false
var _troca_por_ko := false
var _ativo_visto := -1
var _hp_visto: Array = []
var _sequencia_captura := 0


var tempos_carga := {}
var perfil_sim_us := 0      # tempo da simulação + mensagens + save (por quadro, acumulado)
var perfil_sim_max_us := 0


var _primeiro_quadro := false
const INTERVALO_SAVE_HUNT_MS := 10000   # E (2b.6): na hunt, no máximo um save a cada 10 s; ao sair, save imediato


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	# Ciclo 4: a HUD em pixels da janela, como na cidade (antes a hunt esticava a base de 1152 px: HUD 1,63× maior que o
	# original e que a cidade).
	preload("res://tela_jogo.gd").aplicar(get_window())
	EstadoJogo.salvamento.intervalo_minimo_ms = INTERVALO_SAVE_HUNT_MS
	dados = preload("res://ponte_cidade.gd").dados()   # ciclo 4: só leitura; a mesma carga da cidade (~85 ms a menos)
	tempos_carga["dados_ms"] = Time.get_ticks_msec() - t0
	var especie = EstadoJogo.especie_caca
	var slug_pedido := String(EstadoJogo.slug_caca)
	var nome := String(especie.nome) if especie != null else "Rhydon"
	if slug_pedido != "":
		nome = String(dados.hunts.get(slug_pedido, {}).get("nome", nome))
	if not CenarioJogo.disponivel(dados, nome, slug_pedido):
		push_error("hunt de %s indisponível na simulação (sem mapa/hunt-config no snapshot)" % nome)
		_sair("indisponivel")
		return
	var agora := int(Time.get_unix_time_from_system() * 1000.0)
	var jogo := _extrair_save(nome)
	jogo["slug"] = slug_pedido
	var cfg := CenarioJogo.configurar(jogo, dados, semente if semente != 0 else agora % 2147483647, agora)
	# Fase 4, lote 2: Streak Points (C), Tipo do Dia (A: evento; E: rotação offline) e boosts ativos (A: formato).
	cfg["streak"] = EstadoJogo.efeitos_streak()
	cfg["eventos"] = EstadoJogo.eventos_do_dia(agora / 1000)
	cfg["boosts"] = EstadoJogo.boosts_ativos(agora)
	cfg["berries"] = EstadoJogo.berries_ativas(agora / 1000)   # lote 3: berries do time (30 min, C)
	cfg["insignias"] = EstadoJogo.insignias_ativas(agora / 1000)   # lote 4: +1% XP e de rolagem extra por insígnia (C)
	# Penalidade de entrada (B-relatado): hunt diferente da última ou sessão expirada; a mesma hunt de novo não.
	cfg["entrada_nova"] = CenarioJogo.penalizar_entrada(EstadoJogo.sessao_expirada, EstadoJogo.ultima_hunt_slug, String(cfg["slug"]))
	EstadoJogo.ultima_hunt_slug = String(cfg["slug"])
	EstadoJogo.hunt_ao_fechar = String(cfg["slug"])   # se o jogo fechar aqui, a caça continua até 15 min (B-relatado)
	EstadoJogo.sessao_expirada = false
	var t1 := Time.get_ticks_msec()
	# ciclo 4: a grade da sim vem do cache (mesma chave do cache de desenho), sem reler o JSON do mapa
	var mapa = preload("res://render/cache_mapa.gd").mapa_hunt(String(cfg["slug"]), preload("res://render/dados_desenho.gd").carregar())
	sim = Simulacao.new(cfg, dados, mapa)
	tempos_carga["sim_ms"] = Time.get_ticks_msec() - t1
	var t2 := Time.get_ticks_msec()
	EstadoJogo.esperar_atlas(String(cfg["slug"]))   # ciclo 4: se o atlas desta hunt está sendo montado em segundo plano
	vista = Vista.new()
	add_child(vista)
	vista.nome_treinador = String(EstadoJogo.nome_treinador)
	if not (EstadoJogo.visual as Dictionary).is_empty():   # ciclo 3: o visual escolhido na criação ou no Perfil
		vista.looktype_treinador = int(EstadoJogo.visual.get("looktype", vista.looktype_treinador))
		vista.cores_treinador = (EstadoJogo.visual.get("cores", vista.cores_treinador) as Dictionary).duplicate()
	_ativo_visto = sim.ativo
	tempos_carga["vista_ms"] = Time.get_ticks_msec() - t2
	var t3 := Time.get_ticks_msec()
	_montar_hud()
	tempos_carga["hud_ms"] = Time.get_ticks_msec() - t3
	EstadoJogo.validador_troca_lider = _validar_troca_lider
	EstadoJogo.lider_alterado.connect(_sincronizar_lider)
	EstadoJogo.auto_potion_alterado.connect(_aplicar_auto_helper)
	EstadoJogo.auto_catch_alterado.connect(_aplicar_auto_helper)
	var t4 := Time.get_ticks_msec()
	for m in sim.iniciar():
		_tratar(m["msg"])
	tempos_carga["inicio_e_mapa_ms"] = Time.get_ticks_msec() - t4
	tempos_carga["total_ready_ms"] = Time.get_ticks_msec() - t0
	_proximo_tick_ms = Time.get_ticks_msec() + float(sim.p.tick_ms)


func _extrair_save(nome_hunt: String) -> Dictionary:
	var r: Dictionary = EstadoJogo.extrair_jogo_hunt(nome_hunt)
	membros = r["membros"]
	return r["jogo"]


var tipos_no_quadro: Array = []   # diagnóstico (varredura): mensagens tratadas no último quadro


func _process(_delta: float) -> void:
	if not _primeiro_quadro:
		_primeiro_quadro = true
		preload("res://tela_carregando.gd").esconder(get_tree())   # ciclo 4: a tela de carregamento sai no 1º quadro
	if sim == null or _encerrada:
		return
	var _t0 := Time.get_ticks_usec()
	var agora := float(Time.get_ticks_msec())
	var passo := float(sim.p.tick_ms) / maxf(0.001, velocidade)
	var n := 0
	tipos_no_quadro.clear()
	# Jogo idle (E, 15/11): atraso não se perde. Os ticks atrasados (quadro lento, janela em segundo plano ou minimizada)
	# são recuperados com um orçamento de tempo por quadro; o atraso passa ao quadro seguinte. Teto de 1 h de atraso (E:
	# depois de o PC dormir, não recalcula horas — isso é papel da soneca).
	if agora - _proximo_tick_ms > ATRASO_MAX_MS:
		_proximo_tick_ms = agora - ATRASO_MAX_MS
	var limite_us := _t0 + int(EstadoJogo.orcamento_sim_ms() * 1000.0)
	while agora >= _proximo_tick_ms and (n == 0 or Time.get_ticks_usec() < limite_us):
		for m in sim.passo():
			var _tm := Time.get_ticks_usec()
			_tratar(m["msg"])
			tipos_no_quadro.append("%s:%d" % [String(m["msg"].get("type", "")), Time.get_ticks_usec() - _tm])
			if _encerrada:
				return
		_proximo_tick_ms += passo
		n += 1
		EstadoJogo.somar_tempo_caca(int(sim.p.tick_ms))
		_conferir_troca_por_ko()
	perfil_sim_us += Time.get_ticks_usec() - _t0
	perfil_sim_max_us = maxi(perfil_sim_max_us, Time.get_ticks_usec() - _t0)


func _tratar(msg: Dictionary) -> void:
	vista.receber(msg)
	match String(msg.get("type", "")):
		"field-init":
			apresentacao.nova_instancia(String(msg["huntKey"]))
		"field":
			_sincronizar_hp(msg.get("bossTeam", []))
			for mb in msg.get("mobs", []):
				if bool(mb.get("shiny", false)) and not bool(mb.get("dead", false)):
					var chave := "%d:%d" % [int(mb["slot"]), int(mb.get("speciesId", 0))]
					if not _shinies_vistos.has(chave):
						_shinies_vistos[chave] = true
						shiny_apareceu.emit(String(PONTE_DADOS.dados().especie(int(mb.get("speciesId", 0))).get("nome", "")))
				elif _shinies_vistos.has("%d:%d" % [int(mb["slot"]), int(mb.get("speciesId", 0))]) and bool(mb.get("dead", false)):
					_shinies_vistos.erase("%d:%d" % [int(mb["slot"]), int(mb.get("speciesId", 0))])
		"pending":
			pendentes_alterados.emit(msg.get("list", []))
		"boosts":
			_boosts_msg = (msg.get("boosts", []) as Array).duplicate(true)
			_emitir_boosts()
		"events":
			_eventos_msg = []
			for ev in msg.get("events", []):
				_eventos_msg.append({"key": String(ev.get("key", "")), "until": int(ev.get("until", 0)), "nome": String(ev.get("name", "")), "desc": String(ev.get("desc", "")),
					"tipo": String(ev.get("tipo", "")), "evento": true})
			_emitir_boosts()
		"profession-herb":
			if String(msg.get("kind", "fresh")) == "wild":
				EstadoJogo.prof_registrar(-1, 0, 0, int(msg.get("qty", 1)))
			else:
				EstadoJogo.prof_registrar(-1, int(msg.get("qty", 1)), 0)
		"profession-photo":
			if bool(msg.get("ok", false)):
				EstadoJogo.prof_registrar(-1, 0, 1)
		"field-kill":
			registro["abates"] += 1
			EstadoJogo.registrar_abates(1, int(msg.get("speciesId", -1)))
			EstadoJogo.diaria_abate(int(msg.get("speciesId", -1)))   # tarefas e Daily Kill
			EstadoJogo.prof_registrar(int(msg.get("speciesId", -1)), 0, 0)   # ciclo 6: abates por tipagem (rank da profissão)
			EstadoJogo.breeding_abates(1)   # ciclo 6: os ovos chocam com derrotas nas hunts (C)
			EstadoJogo.registrar_recompensa_treinador(int(msg["xpGained"]))
			registro["xp_treinador"] += int(msg["xpGained"])
			if bool(msg.get("leveledUp", false)):
				subiu_nivel.emit("", int(msg.get("level", 0)), true)
			_receber_loot(msg.get("loot", []))
			if apresentacao.mostrar_cartao(msg, Time.get_ticks_msec()):
				registro["cartoes"] += 1
				derrota_recompensada.emit(_evento_cartao(msg))
		"poke-xp":
			var pk = _membro_por_id(String(msg.get("id", "")))
			if pk != null:
				var nv0: int = pk.nivel
				EstadoJogo.conceder_experiencia(pk, int(msg["xpGained"]))
				if pk.nivel > nv0:
					subiu_nivel.emit(String(pk.especie.nome) if pk.especie != null else "", pk.nivel, false)
				registro["xp_pokemon"] += int(msg["xpGained"])
		"auto-heal":
			var pid := _id_pocao(String(msg.get("name", "")))
			if pid > 0 and EstadoJogo.consumir_pocao(pid):
				registro["pocoes"][pid] = int(registro["pocoes"].get(pid, 0)) + 1
		"catch-result":
			var bola := int(msg.get("ballId", 0))
			if EstadoJogo.consumir_bola(bola):
				registro["bolas"][bola] = int(registro["bolas"].get(bola, 0)) + 1
			apresentacao.ao_resultado_captura(msg)
			resultado_captura.emit(msg)
			EstadoJogo.medidor_captura = sim.medidor.duplicate(true)   # medidor por espécie (vai no próximo save)
			EstadoJogo.garantia_pedras = sim.garantia_pedras.duplicate(true)   # garantia de pedra (classe 3)
			_sequencia_captura += 1
			if bool(msg.get("success", false)):
				_registrar_captura(String(msg.get("speciesName", "")), _shiny_em(int(msg.get("col", -1)), int(msg.get("row", -1))), String(msg.get("ballName", "")))
				EstadoJogo.diaria_captura(preload("res://ponte_cidade.gd").id_especie(String(msg.get("speciesName", ""))))   # tarefas e Daily Catch
			# hud_caca conta as capturas da instância pelo id (o contador "N wilds" do painel Capture)
			captura_resolvida.emit({"sucesso": bool(msg.get("success", false)), "id": "%s#%d" % [String(sim.hunt_key), _sequencia_captura]})
		"field-none":
			_sair(String(msg.get("motivo", "saida")))
		"error":
			_avisar(String(msg.get("message", "")))


func _emitir_boosts() -> void:
	boosts_alterados.emit(_boosts_msg + _eventos_msg)


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


func _registrar_captura(nome: String, shiny: bool = false, bola: String = "") -> void:
	## A: o Pokémon capturado chega como poke-delta de nível 1 (5/5 capturas da rhydon-1h); IVs e Quality pelo sorteio
	## do próprio jogo (DadosPokemon), como nas capturas do P04. Shiny: o do selvagem capturado (o field marca, A).
	if EstadoJogo.registrar_captura_especie(nome, shiny, bola):
		registro["capturas"] += 1
		if shiny:
			registro["shiny_capturados"] = int(registro.get("shiny_capturados", 0)) + 1
		capturado.emit(nome, shiny)


func _shiny_em(col: int, row: int) -> bool:
	## catch-result traz a posição do selvagem (A), não o shiny: o estado da sim diz qual era.
	if sim == null:
		return false
	for mb in sim.mobs:
		if mb["pos"] == Vector2i(col, row) and bool(mb.get("shiny", false)):
			return true
	return false


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


func lancar_bola(pending_id: int, ball_id: int) -> void:
	## Ciclo 4 (C: catch {pendingId, ballId}): lançamento manual pelo painel de captura.
	if sim != null and not _encerrada:
		for m in sim.passo([{"type": "catch", "pendingId": pending_id, "ballId": ball_id}]):
			_tratar(m["msg"])
		bola_lancada.emit()


func usar_pocao(item_id: int) -> void:
	## Ciclo 4 (C: tutorial "Use uma potion", comando use-heal): cura o ativo com a poção da mochila.
	if sim != null and not _encerrada:
		for m in sim.passo([{"type": "use-heal", "itemId": item_id}]):
			_tratar(m["msg"])
		pocao_usada.emit()


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
	EstadoJogo.hunt_ao_fechar = ""
	# HP do time como a simulação deixou (sem curar; desmaiado fica com 0)
	if sim != null:
		for i in mini(membros.size(), sim.equipe.size()):
			EstadoJogo.registrar_vida_pokemon(membros[i], int(sim.equipe[i]["hp"]))
	EstadoJogo.salvamento.intervalo_minimo_ms = 0
	EstadoJogo.solicitar_salvamento()
	hunt_encerrada.emit(motivo)
	if trocar_de_cena_ao_sair and not sem_trocar_cena_global and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(CENA_CIDADE)


# ------------------------------------------------------------------- HUD da cena antiga

func _montar_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "Interface"
	hud.layer = 10
	add_child(hud)
	titulo.hide()
	hud.add_child(titulo)
	botao_voltar_cidade.hide()
	hud.add_child(botao_voltar_cidade)
	add_child(imagem_aliado)
	painel_auto_helper = preload("res://painel_auto_helper.gd").new()
	painel_auto_helper.mostrar_botao_abrir = false
	painel_auto_helper.name = "PainelAutoHelper"
	hud.add_child(painel_auto_helper)
	hud_caca = preload("res://hud_caca.gd").new()
	hud_caca.name = "HudCaca"
	hud_caca.controlador = self
	hud.add_child(hud_caca)
	# Modo Soneca: só pelo ícone zᶻ da barra de menu (C; ciclo 5, pedido do usuário: o botão Zzz flutuante saiu do canto
	# inferior direito, onde cobria o painel de captura). O ícone abre a janela do original e chama soneca().


func soneca() -> String:
	## Roda a amostra de 5 min a partir do estado atual da hunt e grava a soneca (sem fechar o jogo; o botão fecha).
	if sim == null or _encerrada:
		return "Sem hunt para a soneca."
	var erro: String = EstadoJogo.dormir(sim, int(Time.get_unix_time_from_system()))
	_encerrada = true
	return erro


func _on_botao_voltar_cidade_pressed() -> void:
	voltar_cidade()


func obter_troca_restante() -> float:
	## Segundos até a troca manual ser aceita (regra E da simulação: 5 s depois de uma troca por KO).
	if sim == null:
		return 0.0
	return maxf(0.0, float(int(sim.troca_manual_liberada_tick) - int(sim.tick)) * float(sim.p.tick_ms) / 1000.0)


func _validar_troca_lider(novo: DadosPokemon) -> bool:
	if sim == null or _encerrada or not is_inside_tree():
		return false
	if _troca_por_ko:
		return true
	var i := membros.find(novo)
	if i < 0 or int(sim.equipe[i]["hp"]) <= 0:
		return false
	return obter_troca_restante() <= 0.0


func _sincronizar_lider() -> void:
	## Líder trocado pelo painel → a simulação troca o ativo (ela confere a regra de novo).
	if _troca_por_ko or sim == null or _encerrada:
		return
	var i := membros.find(EstadoJogo.obter_lider())
	if i >= 0 and i != sim.ativo:
		trocar(i)
		_conferir_troca_por_ko()


func _conferir_troca_por_ko() -> void:
	## O ativo mudou na simulação (KO ou troca aceita) → o líder do save acompanha.
	if sim == null or sim.ativo == _ativo_visto:
		return
	_ativo_visto = sim.ativo
	var pk = membros[sim.ativo] if sim.ativo < membros.size() else null
	if pk != null and EstadoJogo.obter_lider() != pk:
		_troca_por_ko = true
		EstadoJogo.selecionar_lider(pk)
		_troca_por_ko = false
	aliado_alterado.emit(pk)


func _sincronizar_hp(time: Array) -> void:
	## HP do time no save a cada field em que mudou (o painel de time e o My Pokes leem do DadosPokemon).
	for i in mini(time.size(), membros.size()):
		var hp := int(time[i]["hp"])
		if i >= _hp_visto.size():
			_hp_visto.append(-1)
		if hp != int(_hp_visto[i]):
			_hp_visto[i] = hp
			# só a UI (painel de time, My Pokes): registrar_vida_pokemon pediria um save a cada field; o HP vai para o
			# save ao sair (_sair/_exit_tree) e junto com os saves que XP e loot já pedem
			var pk: DadosPokemon = membros[i]
			var novo := clampi(hp, 0, pk.obter_vida_maxima())
			if pk.vida_atual != novo:
				pk.vida_atual = novo
				EstadoJogo.colecao.individuo_alterado.emit(pk)
	vida_aliado = int(time[sim.ativo]["hp"]) if sim != null and sim.ativo < time.size() else 0


func _aplicar_auto_helper() -> void:
	## Mudança no Auto-Helper durante a hunt vale na hora (mesmo save, mesmas regras).
	if sim == null:
		return
	sim.cfg["auto_potion"] = EstadoJogo.auto_potion
	sim.cfg["pocao_fixa"] = EstadoJogo.auto_potion_item_id
	sim.p["pocao_limiar"] = float(EstadoJogo.auto_potion_threshold) / 100.0
	sim.cfg["auto_catch"] = EstadoJogo.auto_catch
	sim.cfg["bola_auto_catch"] = EstadoJogo.auto_catch_ball_id


func _avisar(texto: String) -> void:
	push_warning(texto)


func _exit_tree() -> void:
	# saída por outro caminho (ex.: mapa-múndi dentro da hunt troca a cena): grava o HP e o save mesmo assim
	if sim != null and not _encerrada:
		_encerrada = true
		for i in mini(membros.size(), sim.equipe.size()):
			EstadoJogo.registrar_vida_pokemon(membros[i], int(sim.equipe[i]["hp"]))
		EstadoJogo.salvamento.intervalo_minimo_ms = 0
		EstadoJogo.solicitar_salvamento()
	if EstadoJogo.salvamento.intervalo_minimo_ms != 0:   # nunca deixa a cidade com o save espaçado
		EstadoJogo.salvamento.intervalo_minimo_ms = 0
		EstadoJogo.solicitar_salvamento()
	if EstadoJogo.validador_troca_lider.is_valid() and EstadoJogo.validador_troca_lider.get_object() == self:
		EstadoJogo.validador_troca_lider = Callable()
