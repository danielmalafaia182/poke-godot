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
	for evento in [estoque_bolas_alterado, estoque_pocoes_alterado, depot_alterado, lider_alterado, auto_catch_alterado, auto_potion_alterado, perfil_alterado, inventario.alterado, colecao.alterado]:
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
	return inventario.mover_item_depot(id, guardar)

func guardar_todos_itens_depot() -> String:
	return inventario.guardar_todos_itens_depot()

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
	return colecao.mover_pokemon_depot(pokemon, guardar)

func registrar_captura(pokemon: DadosPokemon) -> bool:
	return colecao.registrar_captura(pokemon)

func registrar_vida_pokemon(pokemon: DadosPokemon, vida: int) -> void:
	colecao.registrar_vida_pokemon(pokemon, vida)

func conceder_experiencia(pokemon: DadosPokemon, quantidade: int) -> bool:
	return colecao.conceder_experiencia(pokemon, quantidade)

func curar_time() -> Dictionary:
	return colecao.curar_time()

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

func validar_evolucao(pokemon: DadosPokemon) -> String:
	if pokemon==null or pokemon.especie==null or not time_pokemon.has(pokemon): return "Selecione um Pokémon do time."
	if get_tree().current_scene==null or get_tree().current_scene.scene_file_path!="res://cidade.tscn": return "Evolua em Cerulean."
	var regra: Dictionary=preload("res://regras_evolucao.gd").obter(pokemon.especie.nome)
	if regra.is_empty(): return "Evolução ainda indisponível."
	if pokemon.nivel<int(regra["nivel"]): return "Requer nível %d." % int(regra["nivel"])
	if pokemon.obter_vida_atual()<=0: return "Cure o Pokémon antes de evoluir."
	if not preload("res://especies_importadas.gd").obter_especies().has(regra["nome"]): return "Espécie de destino indisponível."
	return ""
func evoluir_pokemon(pokemon: DadosPokemon) -> String:
	var erro: String=validar_evolucao(pokemon)
	if not erro.is_empty(): return erro
	var regra: Dictionary=preload("res://regras_evolucao.gd").obter(pokemon.especie.nome)
	var hp: int=pokemon.obter_vida_atual()
	pokemon.especie=preload("res://especies_importadas.gd").obter_especies()[regra["nome"]]
	pokemon.vida_atual=mini(hp,pokemon.obter_vida_maxima())
	colecao.depot_alterado.emit()
	colecao.individuo_alterado.emit(pokemon)
	colecao.pokemon_alterado.emit()
	colecao.alterado.emit()
	return ""
