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
# interface que hud_caca.gd espera do controlador (a mesma da cena antiga)
signal derrota_recompensada(evento: Dictionary)
signal captura_resolvida(evento: Dictionary)
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


const INTERVALO_SAVE_HUNT_MS := 10000   # E (2b.6): na hunt, no máximo um save a cada 10 s; ao sair, save imediato


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	EstadoJogo.salvamento.intervalo_minimo_ms = INTERVALO_SAVE_HUNT_MS
	dados = DadosJogo.carregar()
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
	# Penalidade de entrada (B-relatado): hunt diferente da última ou sessão expirada; a mesma hunt de novo não.
	cfg["entrada_nova"] = CenarioJogo.penalizar_entrada(EstadoJogo.sessao_expirada, EstadoJogo.ultima_hunt_slug, String(cfg["slug"]))
	EstadoJogo.ultima_hunt_slug = String(cfg["slug"])
	EstadoJogo.sessao_expirada = false
	var t1 := Time.get_ticks_msec()
	var mapa = MapaHunt.carregar(cfg["slug"], Fontes.ler_mapa(cfg["slug"]), Fontes.ler_colisao())
	sim = Simulacao.new(cfg, dados, mapa)
	tempos_carga["sim_ms"] = Time.get_ticks_msec() - t1
	var t2 := Time.get_ticks_msec()
	vista = Vista.new()
	add_child(vista)
	vista.nome_treinador = String(EstadoJogo.nome_treinador)
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
	var lider = EstadoJogo.obter_lider()
	return {"hunt": nome_hunt, "equipe": equipe, "lider": maxi(0, membros.find(lider)), "treinador_xp": EstadoJogo.experiencia_treinador_acumulada,
		"inventario": inventario, "bolas": EstadoJogo.estoque_bolas.duplicate(), "nomes_bolas": nomes_bolas,
		"auto_catch": EstadoJogo.auto_catch, "bola_auto_catch": EstadoJogo.auto_catch_ball_id,
		"auto_potion": EstadoJogo.auto_potion, "pocao_id": EstadoJogo.auto_potion_item_id,
		"limite_pocao": EstadoJogo.auto_potion_threshold, "medidor_captura": EstadoJogo.medidor_captura, "vip": EstadoJogo.vip}


var tipos_no_quadro: Array = []   # diagnóstico (varredura): mensagens tratadas no último quadro


func _process(_delta: float) -> void:
	if sim == null or _encerrada:
		return
	var _t0 := Time.get_ticks_usec()
	var agora := float(Time.get_ticks_msec())
	var passo := float(sim.p.tick_ms) / maxf(0.001, velocidade)
	var n := 0
	tipos_no_quadro.clear()
	while agora >= _proximo_tick_ms and n < 50:
		for m in sim.passo():
			var _tm := Time.get_ticks_usec()
			_tratar(m["msg"])
			tipos_no_quadro.append("%s:%d" % [String(m["msg"].get("type", "")), Time.get_ticks_usec() - _tm])
			if _encerrada:
				return
		_proximo_tick_ms += passo
		n += 1
		_conferir_troca_por_ko()
	if n >= 50:
		_proximo_tick_ms = agora + passo      # parou (ex.: janela minimizada): não despeja minutos de ticks
	perfil_sim_us += Time.get_ticks_usec() - _t0
	perfil_sim_max_us = maxi(perfil_sim_max_us, Time.get_ticks_usec() - _t0)


func _tratar(msg: Dictionary) -> void:
	vista.receber(msg)
	match String(msg.get("type", "")):
		"field-init":
			apresentacao.nova_instancia(String(msg["huntKey"]))
		"field":
			_sincronizar_hp(msg.get("bossTeam", []))
		"field-kill":
			registro["abates"] += 1
			EstadoJogo.registrar_recompensa_treinador(int(msg["xpGained"]))
			registro["xp_treinador"] += int(msg["xpGained"])
			_receber_loot(msg.get("loot", []))
			if apresentacao.mostrar_cartao(msg, Time.get_ticks_msec()):
				registro["cartoes"] += 1
				derrota_recompensada.emit(_evento_cartao(msg))
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
			apresentacao.ao_resultado_captura(msg)
			EstadoJogo.medidor_captura = sim.medidor.duplicate(true)   # medidor por espécie (vai no próximo save)
			_sequencia_captura += 1
			if bool(msg.get("success", false)):
				_registrar_captura(String(msg.get("speciesName", "")))
			# hud_caca conta as capturas da instância pelo id (o contador "N wilds" do painel Capture)
			captura_resolvida.emit({"sucesso": bool(msg.get("success", false)), "id": "%s#%d" % [String(sim.hunt_key), _sequencia_captura]})
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
	var especie = ESPECIES.obter_todas().get(nome)
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
