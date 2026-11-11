extends Node

# Fachada de compatibilidade. Os módulos são donos dos dados e das regras.
# Propriedades abaixo encaminham leituras/escritas, sem cópias de estado.
var inventario: InventarioJogo = InventarioJogo.new()
var colecao: ColecaoPokemon = ColecaoPokemon.new()
var configuracao: ConfiguracaoAutoHelper = ConfiguracaoAutoHelper.new()
var perfil: PerfilTreinador = PerfilTreinador.new()
var salvamento: CoordenadorSalvamento = CoordenadorSalvamento.new()

signal perfil_alterado
signal pokemon_alterado
signal estoque_bolas_alterado
signal auto_catch_alterado
signal estoque_pocoes_alterado
signal auto_potion_alterado
signal depot_alterado
signal lider_alterado
signal estado_salvamento_alterado
signal individuo_alterado(pokemon: DadosPokemon)
signal ouro_alterado
signal vip_alterado
signal streak_alterado

const CATALOGO_POCOES = InventarioJogo.CATALOGO_POCOES
const CATALOGO_BOLAS = InventarioJogo.CATALOGO_BOLAS
const CAPACIDADE_DEPOT = InventarioJogo.CAPACIDADE_DEPOT
const LIMITES_AUTO_POTION = ConfiguracaoAutoHelper.LIMITES_AUTO_POTION
const LIMITE_TIME = ColecaoPokemon.LIMITE_TIME

var estoque_pocoes: Dictionary[int, int]:
	get: return inventario.estoque_pocoes
	set(valor): inventario.estoque_pocoes = valor
var estoque_bolas: Dictionary[int, int]:
	get: return inventario.estoque_bolas
	set(valor): inventario.estoque_bolas = valor
var itens_depot: Dictionary:
	get: return inventario.itens_depot
	set(valor): inventario.itens_depot = valor
var bola_selecionada: int:
	get: return inventario.bola_selecionada
	set(valor): inventario.bola_selecionada = valor
var time_pokemon: Array[DadosPokemon]:
	get: return colecao.time_pokemon
	set(valor): colecao.time_pokemon = valor
var pokemons_capturados: Array[DadosPokemon]:
	get: return colecao.pokemons_capturados
	set(valor): colecao.pokemons_capturados = valor
var pokemon_inicial: DadosPokemon:
	get: return colecao.pokemon_inicial
	set(valor): colecao.pokemon_inicial = valor
var pokemon_lider: DadosPokemon:
	get: return colecao.pokemon_lider
	set(valor): colecao.pokemon_lider = valor
var auto_potion: bool:
	get: return configuracao.auto_potion
	set(valor): configuracao.auto_potion = valor
var auto_potion_threshold: int:
	get: return configuracao.auto_potion_threshold
	set(valor): configuracao.auto_potion_threshold = valor
var auto_potion_item_id: int:
	get: return configuracao.auto_potion_item_id
	set(valor): configuracao.auto_potion_item_id = valor
var auto_catch: bool:
	get: return configuracao.auto_catch
	set(valor): configuracao.auto_catch = valor
var auto_catch_ball_id: int:
	get: return configuracao.auto_catch_ball_id
	set(valor): configuracao.auto_catch_ball_id = valor
var auto_catch_names: String:
	get: return configuracao.auto_catch_names
	set(valor): configuracao.auto_catch_names = valor
var nome_treinador: String:
	get: return perfil.nome_treinador
	set(valor): perfil.nome_treinador = valor
var nivel_treinador: int:
	get: return perfil.nivel_treinador
	set(valor): perfil.nivel_treinador = valor
var experiencia_treinador_acumulada: int:
	get: return perfil.experiencia_treinador_acumulada
	set(valor): perfil.experiencia_treinador_acumulada = valor

var especie_caca: DadosEspecie
# Fase 4: ouro do treinador (A: balls.gold / currency; vai no save, campo opcional "ouro"). Começa em 0 (E: o saldo
# inicial do original não foi gravado; o original dá 100 Small Potions e 100 Poké Balls ao jogador novo, C).
var ouro: int = 0
# Fase 4: VIP (E: opção do jogador, desligada por padrão). Ligado, a simulação soma a parcela vip = 50% da XP base (A).
var vip: bool = false:
	set(valor):
		if vip != valor:
			vip = valor
			vip_alterado.emit()
const PONTE_CIDADE := preload("res://ponte_cidade.gd")
# Fase 4, lote 2: Streak Points e Modo Soneca (regras em sim/servico_jogador.gd; vão no save).
const SERVICO_JOGADOR := preload("res://sim/servico_jogador.gd")
static var _servico_jogador = null
var streak: Dictionary = {"totalKills": 0, "spent": {}}
var soneca: Dictionary = {}
# Boosts ativos ({key, until(ms), pct}, A: formato). E: o jogo offline ainda não tem fonte de boosts (no original vêm
# da loja de diamantes, do Daily Gift e de itens); o campo existe para a simulação e para sistemas futuros.
var boosts: Array = []
# Fase 2b: hunt escolhida pelo slug (dados/gerados/hunts.json); vazio = pela espécie. Não faz parte do save.
var slug_caca: String = ""
# Fase 3: medidor de captura por espécie (C: /api/game/used-balls) — speciesId (str, "s" no fim = shiny) →
# {investido, tentativas, total, gasto}. Vai no save (campo opcional "captura_medidor").
var medidor_captura: Dictionary = {}
# Fase 3: penalidade de entrada (boost shinylock). Relato do usuário (B-relatado): vale ao entrar numa hunt diferente
# da última ou depois que a sessão expira (15 min com o jogo fechado; E: o jogo local não tem modo soneca). Voltar à
# mesma hunt pela cidade não penaliza. `ultima_hunt_slug` vai no save; `sessao_expirada` é decidida ao carregar.
var ultima_hunt_slug: String = ""
var sessao_expirada: bool = true
const SESSAO_EXPIRA_S := 900
var celula_cidade_salva: Vector2i = Vector2i(-1, 3)
var direcao_cidade_salva: int = 2
var posicao_cidade_definida: bool = false
var aviso_salvamento: String:
	get: return salvamento.aviso_salvamento
var erro_salvamento: bool:
	get: return salvamento.erro_salvamento

func _ready() -> void:
	configuracao.inventario = inventario
	inventario.estoque_bolas_alterado.connect(estoque_bolas_alterado.emit)
	inventario.estoque_pocoes_alterado.connect(estoque_pocoes_alterado.emit)
	inventario.depot_alterado.connect(depot_alterado.emit)
	colecao.depot_alterado.connect(depot_alterado.emit)
	colecao.lider_alterado.connect(lider_alterado.emit)
	colecao.pokemon_alterado.connect(pokemon_alterado.emit)
	configuracao.auto_catch_alterado.connect(auto_catch_alterado.emit)
	configuracao.auto_potion_alterado.connect(auto_potion_alterado.emit)
	perfil.perfil_alterado.connect(perfil_alterado.emit)
	salvamento.estado_salvamento_alterado.connect(estado_salvamento_alterado.emit)
	colecao.individuo_alterado.connect(individuo_alterado.emit)
	for evento in [estoque_bolas_alterado, estoque_pocoes_alterado, depot_alterado, lider_alterado, auto_catch_alterado, auto_potion_alterado, perfil_alterado, inventario.alterado, colecao.alterado, ouro_alterado, vip_alterado]:
		evento.connect(solicitar_salvamento)
	add_child(salvamento)
	salvamento.iniciar(self)

func obter_dados_bola(id: int) -> Dictionary:
	return inventario.obter_dados_bola(id)

func obter_quantidade_bola(id: int) -> int:
	return inventario.obter_quantidade_bola(id)

func selecionar_bola(id: int) -> bool:
	return inventario.selecionar_bola(id)

func consumir_bola(id: int) -> bool:
	return inventario.consumir_bola(id)

func obter_dados_pocao(id: int) -> Dictionary:
	return inventario.obter_dados_pocao(id)

func obter_quantidade_pocao(id: int) -> int:
	return inventario.obter_quantidade_pocao(id)

func consumir_pocao(id: int) -> bool:
	return inventario.consumir_pocao(id)

func catalogo_itens_depot() -> Array[Dictionary]:
	return inventario.catalogo_itens_depot()

func quantidade_item_bag(id: int) -> int:
	return inventario.quantidade_item_bag(id)

func mover_item_depot(id: int, guardar: bool) -> String:
	# Fase 4: o depot é decidido pela simulação (sim/servico_cidade.gd); o id interno vira ballId/itemId do original.
	var cmd := {"type": "depot-move", "dir": "store" if guardar else "withdraw"}
	if not preload("res://regras_loot.gd").obter(id).is_empty():
		cmd["itemId"] = preload("res://regras_loot.gd").id_original(id)
	elif id >= 200:
		cmd["itemId"] = id
	else:
		cmd["ballId"] = id
	return PONTE_CIDADE.primeiro_erro(PONTE_CIDADE.enviar(self, cidade_atual(), cmd))

func guardar_todos_itens_depot() -> String:
	var erro := PONTE_CIDADE.primeiro_erro(PONTE_CIDADE.enviar(self, cidade_atual(), {"type": "depot-move", "all": true}))
	return erro if not erro.is_empty() else "Itens guardados."

func obter_lider() -> DadosPokemon:
	return colecao.obter_lider()

# Política transitória registrada pela hunt; não faz parte do save.
var validador_troca_lider: Callable
var prazo_troca_hunt_ms: int=0
func selecionar_lider(pokemon: DadosPokemon) -> bool:
	if pokemon==null or not time_pokemon.has(pokemon):return false
	if pokemon==obter_lider():return true
	# Valida antes de mudar o EstadoJogo ou emitir sinais: sem troca e reversão visível.
	if validador_troca_lider.is_valid() and not bool(validador_troca_lider.call(pokemon)):return false
	return colecao.selecionar_lider(pokemon)

func iniciar_depot() -> void:
	colecao.iniciar_depot()

func mover_pokemon_depot(pokemon: DadosPokemon, guardar: bool) -> String:
	var erro: String = preload("res://contrato_pokemon.gd").validar(pokemon)
	if not erro.is_empty():
		return erro
	return PONTE_CIDADE.primeiro_erro(PONTE_CIDADE.enviar(self, cidade_atual(), {"type": "poke-store" if guardar else "poke-withdraw", "id": pokemon.id_persistente}))

func registrar_captura(pokemon: DadosPokemon) -> bool:
	return colecao.registrar_captura(pokemon)

func registrar_vida_pokemon(pokemon: DadosPokemon, vida: int) -> void:
	colecao.registrar_vida_pokemon(pokemon, vida)

func conceder_experiencia(pokemon: DadosPokemon, quantidade: int) -> bool:
	return colecao.conceder_experiencia(pokemon, quantidade)

func curar_time() -> Dictionary:
	# Fase 4: Nurse Joy pela simulação (C: cura o time inteiro de graça; joy-heal).
	# A (G4): a resposta é só {type: "joy-healed"}; quantos foram curados e quanto HP é calculado aqui, para a tela.
	var antes := {}
	for p in time_pokemon:
		antes[p] = p.obter_vida_atual()
	var msgs: Array = PONTE_CIDADE.enviar(self, cidade_atual(), {"type": "joy-heal"})
	var erro := PONTE_CIDADE.primeiro_erro(msgs)
	if not erro.is_empty():
		return {"quantidade": 0, "hp": 0, "erro": erro}
	var quantidade := 0
	var hp := 0
	for p in time_pokemon:
		var ganho: int = p.obter_vida_atual() - int(antes.get(p, p.obter_vida_atual()))
		if ganho > 0:
			quantidade += 1
			hp += ganho
	return {"quantidade": quantidade, "hp": hp}

func definir_auto_catch(ativo: bool) -> void:
	configuracao.definir_auto_catch(ativo)

func selecionar_bola_auto_catch(id: int) -> bool:
	return configuracao.selecionar_bola_auto_catch(id)

func definir_nomes_auto_catch(nomes: String) -> void:
	configuracao.definir_nomes_auto_catch(nomes)

func nome_permitido_auto_catch(nome: String) -> bool:
	return configuracao.nome_permitido_auto_catch(nome)

func definir_auto_potion(ativo: bool) -> void:
	configuracao.definir_auto_potion(ativo)

func definir_limite_auto_potion(percentual: int) -> bool:
	return configuracao.definir_limite_auto_potion(percentual)

func selecionar_pocao_auto_potion(id: int) -> bool:
	return configuracao.selecionar_pocao_auto_potion(id)

func escolher_pocao_auto_potion() -> int:
	return configuracao.escolher_pocao_auto_potion()

func definir_perfil_treinador(nome: String, nivel: int) -> bool:
	return perfil.definir_perfil_treinador(nome, nivel)

func registrar_recompensa_treinador(quantidade: int) -> void:
	perfil.registrar_recompensa_treinador(quantidade)

func solicitar_salvamento() -> void:
	salvamento.solicitar_salvamento()

func salvar_agora() -> bool:
	return salvamento.salvar_agora()

func registrar_posicao_cidade(celula: Vector2i, direcao: int) -> void:
	direcao = clampi(direcao, 0, 3)
	if posicao_cidade_definida and celula_cidade_salva == celula and direcao_cidade_salva == direcao:
		return
	celula_cidade_salva = celula
	direcao_cidade_salva = direcao
	posicao_cidade_definida = true
	# Caminhada é agrupada pelo timer; eventos de inventário são gravados
	# no fim do frame. O fechamento normal também confirma a última célula.
	salvamento.marcar_posicao_pendente()

# Evolução: preserva a fachada também para a validação anterior ao consumo.
func validar_nova_captura(pokemon: DadosPokemon) -> String:
	return colecao.validar_nova_captura(pokemon)

# Cidade onde o jogador está (E: o P04 tem só Cerulean; na hunt não há cidade e os serviços recusam, como no original).
func cidade_atual() -> String:
	if not is_inside_tree():
		return forcar_cidade
	var cena := get_tree().current_scene
	if cena != null and cena.scene_file_path == "res://cidade.tscn":
		return "cerulean"
	for filho in get_tree().root.get_children():
		if filho.scene_file_path == "res://cidade.tscn":
			return "cerulean"
	return forcar_cidade

# Testes headless sem a cena da cidade usam esta cidade (vazio = nenhuma).
var forcar_cidade: String = ""

# ---------------------------------------------------------------- evolução (sim/servico_cidade.gd)
func info_evolucao(pokemon: DadosPokemon, destino: int = -1) -> Dictionary:
	if pokemon == null:
		return {"type": "error", "message": "Selecione um Pokémon."}
	var cmd := {"type": "evolve-info", "capturedId": pokemon.id_persistente}
	if destino >= 0:
		cmd["destId"] = destino
	return PONTE_CIDADE.servico().tratar(PONTE_CIDADE.estado_de(self, cidade_atual()), cmd)[0]

func validar_evolucao(pokemon: DadosPokemon) -> String:
	if pokemon==null or pokemon.especie==null or not time_pokemon.has(pokemon): return "Selecione um Pokémon do time."
	if cidade_atual() != "cerulean": return "Evolua em Cerulean."
	var info := info_evolucao(pokemon)
	if info.get("type") == "error": return String(info["message"])
	if info.has("reason"): return String(info["reason"])
	if not bool(info.get("canEvolve", false)): return "Requer nível %d." % int(info.get("needLevel", 0))
	return ""

# usar_pedra: true = mantém o nível e gasta as pedras; false = grátis e volta ao Lv.1 (C). null = com pedra se houver,
# senão devolve o aviso para a UI perguntar (nunca reseta o nível sem escolha explícita).
func evoluir_pokemon(pokemon: DadosPokemon, usar_pedra: Variant = null, destino: int = -1) -> String:
	var erro: String=validar_evolucao(pokemon)
	if not erro.is_empty(): return erro
	var info := info_evolucao(pokemon, destino)
	if info.get("destId") == null: return "Escolha a evolução."
	if usar_pedra == null:
		if not bool(info.get("hasStones", false)): return "Faltam pedras. Sem pedras, a evolução volta ao Lv.1."
		usar_pedra = true
	var cmd := {"type": "evolve", "capturedId": pokemon.id_persistente, "useStone": bool(usar_pedra)}
	if destino >= 0:
		cmd["destId"] = destino
	return PONTE_CIDADE.primeiro_erro(PONTE_CIDADE.enviar(self, cidade_atual(), cmd))

# ---------------------------------------------------------------- lote 2: Streak, soneca, eventos
func servico_jogador():
	if _servico_jogador == null:
		_servico_jogador = SERVICO_JOGADOR.new()
	return _servico_jogador

func _estado_jogador() -> Dictionary:
	return {"gold": ouro, "streak": streak, "soneca": soneca}

func _voltar_estado_jogador(e: Dictionary) -> void:
	if int(e["gold"]) != ouro:
		ouro = int(e["gold"])
		ouro_alterado.emit()
	streak = e["streak"]
	soneca = e["soneca"]

func registrar_abates(n: int = 1) -> void:
	## C: "1 point every 1000 total kills" — a hunt chama a cada field-kill.
	SERVICO_JOGADOR.somar_abates(_estado_jogador(), n)

func streak_info() -> Dictionary:
	return servico_jogador().tratar(_estado_jogador(), {"type": "streak-get"})[0]

func gastar_streak(trilha: String) -> String:
	var e := _estado_jogador()
	var msgs: Array = servico_jogador().tratar(e, {"type": "streak-spend", "track": trilha})
	_voltar_estado_jogador(e)
	var erro := PONTE_CIDADE.primeiro_erro(msgs)
	if erro.is_empty():
		streak_alterado.emit()
		solicitar_salvamento()
	return erro

func efeitos_streak() -> Dictionary:
	return servico_jogador().efeitos_streak(_estado_jogador())

func eventos_do_dia(agora_unix: int) -> Array:
	return servico_jogador().tratar({}, {"type": "eventos", "agora": agora_unix})[0]["events"]

func boosts_ativos(agora_ms: int) -> Array:
	return boosts.filter(func(b): return int(b.get("until", 0)) > agora_ms)

# Modo Soneca (C): a hunt atual roda 5 min (amostra) e o jogo fecha; ao voltar, o tempo fora rende 50% da taxa de XP.
func dormir(sim, agora_unix: int) -> String:
	var amostra: Dictionary = SERVICO_JOGADOR.amostra_soneca(sim, int(servico_jogador().p.soneca_amostra_s))
	var e := _estado_jogador()
	var msgs: Array = servico_jogador().tratar(e, {"type": "sleep-mode", "agora": agora_unix, "amostra": amostra})
	_voltar_estado_jogador(e)
	solicitar_salvamento()
	return "" if bool(msgs[0].get("ghost", false)) else "Sem hunt para a soneca."

func relatorio_offline(agora_unix: int) -> Dictionary:
	var e := _estado_jogador()
	var r: Dictionary = servico_jogador().tratar(e, {"type": "offline-get", "agora": agora_unix})[0]
	_voltar_estado_jogador(e)   # voltar antes de 5 min cancela (o serviço zera a soneca)
	return r

func coletar_offline(agora_unix: int) -> Dictionary:
	var e := _estado_jogador()
	var msgs: Array = servico_jogador().tratar(e, {"type": "offline-claim", "agora": agora_unix, "boost": false})
	_voltar_estado_jogador(e)
	var c: Dictionary = {}
	for m in msgs:
		if m.get("type") == "offline-claimed":
			c = m
	if c.is_empty():
		return {"erro": PONTE_CIDADE.primeiro_erro(msgs)}
	registrar_recompensa_treinador(int(c["xpTrainer"]))
	registrar_abates(int(c.get("sampleKills", 0)))
	for pk in time_pokemon:
		if pk.id_persistente == String(c["pokemonId"]):
			conceder_experiencia(pk, int(c["xpPokemon"]))
	var loot: Array[Dictionary] = []
	for k in c.get("loot", {}):
		var interno: int = preload("res://regras_loot.gd").id_interno(int(k))
		if not preload("res://regras_loot.gd").obter(interno).is_empty():
			loot.append({"itemId": interno, "qty": int(c["loot"][k])})
	inventario.receber_loot(loot)
	for k in c.get("itemsUsed", {}):
		for i in int(c["itemsUsed"][k]):
			inventario.consumir_pocao(int(k))
	solicitar_salvamento()
	return c

# ---------------------------------------------------------------- loja do Mark
func loja() -> Dictionary:
	return PONTE_CIDADE.servico().tratar(PONTE_CIDADE.estado_de(self, cidade_atual()), {"type": "shop"})[0]

func comprar_bola(id: int, quantidade: int) -> String:
	return PONTE_CIDADE.primeiro_erro(PONTE_CIDADE.enviar(self, cidade_atual(), {"type": "shop-buy", "ballId": id, "qty": quantidade}))

func comprar_item(id_original: int, quantidade: int) -> String:
	return PONTE_CIDADE.primeiro_erro(PONTE_CIDADE.enviar(self, cidade_atual(), {"type": "shop-buy", "itemId": id_original, "qty": quantidade}))

# itens: [{itemId (original), qty}]
func vender_itens(itens: Array) -> Dictionary:
	var msgs: Array = PONTE_CIDADE.enviar(self, cidade_atual(), {"type": "shop-sell", "items": itens})
	for m in msgs:
		if m.get("type") == "shop-sold": return m
	return {"erro": PONTE_CIDADE.primeiro_erro(msgs)}

func vender_pokemon(lista: Array[DadosPokemon]) -> Dictionary:
	var ids: Array = []
	for p in lista: ids.append(p.id_persistente)
	var msgs: Array = PONTE_CIDADE.enviar(self, cidade_atual(), {"type": "pokemon-sell", "pokeIds": ids})
	for m in msgs:
		if m.get("type") == "pokemon-sold": return m
	return {"erro": PONTE_CIDADE.primeiro_erro(msgs)}
