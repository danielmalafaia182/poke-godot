extends Node2D
# Novo: cura independente dos ataques, com apresentação que não altera HP.
signal cura_aplicada(evento: Dictionary)
signal aliado_alterado(pokemon: DadosPokemon)
# Novo: trilha exata alimenta a apresentação do treinador na caça.
signal trecho_percorrido(origem: Vector2, destino_trecho: Vector2)
const EFEITO_CURA: Script = preload("res://efeito_cura.gd")
# PROVISÓRIO: frequência uniforme do protótipo, não cooldown original confirmado.
const INTERVALO_AUTO_POTION: float = 0.2
var timer_auto_potion: Timer

signal captura_resolvida(evento: Dictionary)
# Novo: recompensa aplicada uma vez por encontro, independente da captura.
signal derrota_recompensada(evento: Dictionary)
var rng_loot: RandomNumberGenerator = RandomNumberGenerator.new()
@export var bonus_vip_recompensa: bool = false
# Novo: opção desligada até integrar dano original; 120HP com dano fixo desequilibra o protótipo.
@export var usar_hp_selvagem_original: bool = false
@export var usar_atributos_combate: bool = true
# Calibração parcial LOCAL, reversível pelo Inspetor. Não altera saves/IVs.
@export var usar_calibracao_combate: bool = true
@export_range(0.05,10.0,0.05) var intervalo_selvagem_calibrado: float = 2.0
const DANO: Script=preload("res://regras_dano.gd")
const VIDA_SELVAGEM: Script=preload("res://regras_vida_selvagem.gd")
@export var usar_hp_selvagem_candidato: bool = true
# Evidência direta: HP do slot persiste nos retornos à vida de Blastoise.
# Estender a estabilidade ao perfil inteiro é uma candidata reversível.
@export var preservar_perfis_de_combate_na_hunt: bool = true
@export var preparar_primeiro_ataque_selvagem: bool = true
const DANO_CANDIDATO: Script=preload("res://regras_dano_candidato.gd")
# Reversível no Inspetor. A candidata só atua junto de atributos e calibração V2.
@export var usar_dano_candidato: bool = true
# Experimento: somente a parcela de nível do dano selvagem usa huntLevel do catálogo.
@export var usar_nivel_dano_catalogo_selvagem: bool = true
# Sequência exclusiva desta hunt; previews/loot/capturas não a consomem.
var rng_dano: RandomNumberGenerator = RandomNumberGenerator.new()
# Sorteio de substituto não consome a sequência de dano, loot ou movimento.
var rng_troca: RandomNumberGenerator = RandomNumberGenerator.new()
var _resolvendo_ko: bool = false
var _substituto_automatico: DadosPokemon
# O alvo é uma referência ao encontro da população, não uma cópia de seu HP.
var encontro_atual: EncontroSelvagem
var encontro_recompensado: bool:
	get: return encontro_atual != null and encontro_atual.recompensado
# Revisão: metadados validados compartilhados com o movimento, sem reabrir o JSON.
var parametros_navegacao_original: Dictionary = {}

# Evolução: dados originais do golpe com dano explicitamente provisório.
signal golpe_executado(evento: Dictionary)
signal ofensiva_aliado_alterada(diagnostico: Dictionary)
var diagnostico_ofensivo_aliado: Dictionary = {}
var _chave_diagnostico_ofensivo: String = ""
@export var usar_golpes_catalogados: bool = true
# Alteração: caça comum rápida; dados originais do catálogo são preservados.
@export var aplicar_cooldowns_catalogo: bool = false
# Alteração: intervalo padrão de 1.5 s escolhido para a caça; não é regra confirmada do original.
@export_range(0.05,2.0,0.05) var intervalo_ataques_caca: float = 1.5
# Alteração: relógio rápido transferido para agenda_golpes de cada combatente.
@export_range(0.05,2.0,0.05) var intervalo_ataques_selvagem: float = 1.5
var agenda_aliado: RefCounted = preload("res://agenda_golpes.gd").new()
var agendas_aliados: Dictionary[DadosPokemon,RefCounted] = {}
const COOLDOWN_TROCA_SEGUNDOS: float=5.0
# Relógio monotônico; injetável somente para testes sem esperas reais.
var relogio_troca: Callable=Time.get_ticks_msec
var registro_combate: Node
# A navegação e os serviços podem ficar prontos mesmo com o líder derrotado.
# A população só começa quando houver um líder saudável, uma única vez.
var _navegacao_preparada: bool = false
var _atividade_iniciada: bool = false
var _saida_solicitada: bool = false

signal dano_aplicado(
	posicao_global: Vector2,
	dano: int,
	tipo: String
)

const APRESENTACAO_CACA: Script = preload(
	"res://apresentacao_caca.gd"
)

@export var pokemon_aliado: DadosPokemon
@export var velocidade_movimento: float = 120.0
@export var alcance_combate: float = 60.0
@export var limitar_area_caca: bool = true
@export var area_caca: Rect2i = Rect2i(-28, -17, 57, 36)

# Alteração: navegação em células de 32 pixels, nas quatro direções.
const TAMANHO_TILE: float = 32.0
const DIRECOES: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1)
]


var pokemon_selvagem: DadosPokemon:
	get: return encontro_atual.pokemon if encontro_atual != null else null
var aproximando: bool = false
# HP do aliado pertence ao indivíduo persistente; combate e HUD leem o mesmo dado.
var vida_aliado: int:
	get: return pokemon_aliado.obter_vida_atual() if pokemon_aliado != null else 0
	set(valor): EstadoJogo.registrar_vida_pokemon(pokemon_aliado, valor)
var vida_selvagem: int:
	get: return encontro_atual.vida if encontro_atual != null else 0
	set(valor):
		if encontro_atual != null:
			encontro_atual.vida = valor

# Alteração: começa encerrada até concluir a inicialização.
var batalha_encerrada: bool = true

# Alteração: dados de navegação obtidos do cenário.
var celulas_existentes: Dictionary = {}
var celulas_bloqueadas: Dictionary = {}
var celulas_acessiveis: Array[Vector2i] = []

# Alteração: armazena o caminho que o aliado está percorrendo.
var caminho: Array[Vector2i] = []
var indice_caminho: int = 0

@onready var cenario_caca: Node2D = get_node("CenarioCaca")
@onready var timer_combate: Timer = get_node("TimerCombate")
@onready var timer_respawn: Timer = get_node("TimerRespawn")
@onready var imagem_aliado: Sprite2D = get_node("ImagemAliado")
@onready var _imagem_selvagem_base: Sprite2D = get_node("ImagemSelvagem")
var imagem_selvagem: Sprite2D:
	get: return encontro_atual.imagem if encontro_atual != null else _imagem_selvagem_base
@onready var titulo: Label = get_node("Interface/Titulo")
@onready var botao_voltar_cidade: Button = get_node(
	"Interface/BotaoVoltarCidade"
)


func _ready() -> void:
	rng_dano.randomize()
	rng_troca.randomize()
	preload("res://tela_jogo.gd").aplicar(get_window())
	EstadoJogo.iniciar_depot()
	# Alteração: usa o indivíduo selecionado, mantendo os IVs/Quality salvos.
	pokemon_aliado = EstadoJogo.obter_lider()
	agendas_aliados[pokemon_aliado]=agenda_aliado
	registro_combate=load("res://registro_combate.gd").new()
	registro_combate.name="RegistroCombate"
	add_child(registro_combate)
	registro_combate.iniciar(self)
	var apresentacao: Node2D = APRESENTACAO_CACA.new()
	apresentacao.name = "ApresentacaoCaca"
	apresentacao.usar_eventos_de_golpe=usar_golpes_catalogados or usar_atributos_combate
	add_child(apresentacao)

	dano_aplicado.connect(
		apresentacao.apresentar_dano
	)

	captura_resolvida.connect(
		apresentacao.apresentar_captura
	)
	golpe_executado.connect(apresentacao.apresentar_golpe)
	aliado_alterado.connect(apresentacao.apresentar_troca)
	# Alteração: garante que os timers não iniciem antes da preparação.
	timer_combate.stop()
	timer_respawn.stop()
	timer_combate.one_shot = false
	if usar_golpes_catalogados and not aplicar_cooldowns_catalogo:
		timer_combate.wait_time = maxf(0.05,intervalo_ataques_caca)
	timer_respawn.one_shot = true

	# Alteração: evita duplicar estas conexões caso já existam no editor.
	if not botao_voltar_cidade.pressed.is_connected(
		_on_botao_voltar_cidade_pressed
	):
		botao_voltar_cidade.pressed.connect(
			_on_botao_voltar_cidade_pressed
		)

	if not timer_combate.timeout.is_connected(
		_on_timer_combate_timeout
	):
		timer_combate.timeout.connect(_on_timer_combate_timeout)

	if not timer_respawn.timeout.is_connected(
		_on_timer_respawn_timeout
	):
		timer_respawn.timeout.connect(_on_timer_respawn_timeout)

	imagem_selvagem.hide()

	if (
		not especie_valida(EstadoJogo.especie_caca)
		or pokemon_aliado == null
	):
		titulo.text = "Não foi possível iniciar: confira o destino e o aliado."
		return

	if not especie_valida(pokemon_aliado.especie):
		titulo.text = "Não foi possível iniciar: espécie do aliado inválida."
		return

	if velocidade_movimento <= 0.0:
		titulo.text = "A velocidade de movimento precisa ser maior que zero."
		return

	# Alteração: lê os dicionários já preparados pelo cenário.
	var existentes: Variant = cenario_caca.get("celulas_existentes")
	var bloqueadas: Variant = cenario_caca.get("celulas_bloqueadas")

	if not existentes is Dictionary or not bloqueadas is Dictionary:
		titulo.text = "O cenário não disponibilizou as células de navegação."
		return

	celulas_existentes = existentes
	celulas_bloqueadas = bloqueadas

	if celulas_existentes.is_empty():
		titulo.text = "O cenário não carregou nenhuma célula."
		return

	if not _aplicar_navegacao_original():
		return
	if not preparar_navegacao():
		return

	imagem_aliado.texture = pokemon_aliado.especie.textura
	# Alteração: mantém HP entre caça e cidade. Cura ocorre por poção ou Nurse Joy.
	vida_aliado = pokemon_aliado.obter_vida_atual()
	EstadoJogo.registrar_vida_pokemon(pokemon_aliado,vida_aliado)
	_navegacao_preparada = true
	# Conectar antes de aguardar uma reserva: o HUD já pode solicitar a troca.
	timer_auto_potion = Timer.new()
	timer_auto_potion.name = "TimerAutoPotion"
	timer_auto_potion.wait_time = INTERVALO_AUTO_POTION
	timer_auto_potion.one_shot = false
	add_child(timer_auto_potion)
	timer_auto_potion.timeout.connect(_on_timer_auto_potion_timeout)
	cura_aplicada.connect(_apresentar_cura)
	EstadoJogo.lider_alterado.connect(_sincronizar_lider_caca)
	EstadoJogo.validador_troca_lider=_validar_troca_lider_hunt
	if vida_aliado <= 0:
		titulo.text = "Seu líder está sem HP. Escolha outro membro saudável ou volte à cidade e fale com Nurse Joy."
		return
	_tentar_iniciar_atividade()


func _tentar_iniciar_atividade() -> void:
	if _atividade_iniciada or not _navegacao_preparada or _saida_solicitada:
		return
	if not is_inside_tree() or is_queued_for_deletion() or vida_aliado <= 0:
		return
	# Reserva antes de gerar/emitir sinais, inclusive contra chamadas reentrantes.
	_atividade_iniciada = true
	gerar_selvagem()
	timer_auto_potion.start()
	_ao_iniciar_atividade()


# A população e a apresentação específica pertencem à subclasse da hunt.
func _ao_iniciar_atividade() -> void:
	pass


# Alteração: valida os dados necessários ao combate.
func especie_valida(especie: DadosEspecie) -> bool:
	return (
		especie != null
		and not especie.obter_base().is_empty()
		and especie.textura != null
	)


func celula_transitavel(celula: Vector2i) -> bool:
	if limitar_area_caca and not area_caca.has_point(celula):
		return false
	return (
		celulas_existentes.has(celula)
		and not celulas_bloqueadas.has(celula)
	)


# Alteração: converte posição global para célula local do cenário.
# floori também trata corretamente as coordenadas negativas do mapa.
func posicao_para_celula(posicao_global: Vector2) -> Vector2i:
	var posicao_local: Vector2 = cenario_caca.to_local(posicao_global)

	return Vector2i(
		floori(posicao_local.x / TAMANHO_TILE),
		floori(posicao_local.y / TAMANHO_TILE)
	)


# Alteração: usa o centro da célula como ponto de movimentação.
func celula_para_posicao(celula: Vector2i) -> Vector2:
	var centro_local: Vector2 = (
		Vector2(celula) * TAMANHO_TILE
		+ Vector2.ONE * (TAMANHO_TILE / 2.0)
	)

	return cenario_caca.to_global(centro_local)


func preparar_navegacao() -> bool:
	if limitar_area_caca:
		if area_caca.size.x <= 0 or area_caca.size.y <= 0:
			titulo.text = "A área da caça precisa ter tamanho positivo."
			return false
	var celula_inicial: Vector2i = posicao_para_celula(
		imagem_aliado.global_position
	)

	# Alteração: se o aliado foi colocado numa parede pelo editor,
	# procura uma célula livre próxima antes de iniciar a caça.
	if not celula_transitavel(celula_inicial):
		var encontrou: bool = false
		var menor_distancia: float = INF

		for chave in celulas_existentes:
			var candidata: Vector2i = chave

			if not celula_transitavel(candidata):
				continue

			var distancia: float = (
				imagem_aliado.global_position.distance_squared_to(
					celula_para_posicao(candidata)
				)
			)

			if distancia < menor_distancia:
				menor_distancia = distancia
				celula_inicial = candidata
				encontrou = true

		if not encontrou:
			titulo.text = "Não existe uma célula livre para posicionar o aliado."
			return false

	imagem_aliado.global_position = celula_para_posicao(celula_inicial)

	# Alteração: busca em largura para encontrar apenas a região conectada.
	celulas_acessiveis.clear()

	var fila: Array[Vector2i] = [celula_inicial]
	var visitadas: Dictionary[Vector2i, bool] = {}
	var indice: int = 0

	visitadas[celula_inicial] = true

	while indice < fila.size():
		var atual: Vector2i = fila[indice]
		indice += 1
		celulas_acessiveis.append(atual)

		for direcao in DIRECOES:
			var vizinha: Vector2i = atual + direcao

			if visitadas.has(vizinha):
				continue

			# Correção: usa a mesma regra do A*,
			# incluindo a proteção contra atravessar quinas.
			if not passagem_permitida(atual, vizinha):
				continue

			visitadas[vizinha] = true
			fila.append(vizinha)

	if celulas_acessiveis.size() < 2:
		titulo.text = "O aliado está numa região sem espaço para a caça."
		return false

	print("Células acessíveis ao aliado: ", celulas_acessiveis.size())
	return true


# Alteração: usa A* com custo 1 para passos retos
# e sqrt(2) para passos diagonais.
func calcular_caminho(
	origem: Vector2i,
	destino: Vector2i,
	# Alteração: obstáculos temporários opcionais; chamadas antigas mantêm navegação estática.
	ocupadas: Dictionary = {}
) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []

	if not celula_transitavel(origem):
		return resultado

	if not celula_transitavel(destino):
		return resultado

	var abertas: Array[Vector2i] = [origem]
	var em_abertas: Dictionary[Vector2i, bool] = {}
	var fechadas: Dictionary[Vector2i, bool] = {}
	var anteriores: Dictionary[Vector2i, Vector2i] = {}
	var custos: Dictionary[Vector2i, float] = {}
	var prioridades: Dictionary[Vector2i, float] = {}

	em_abertas[origem] = true
	custos[origem] = 0.0
	prioridades[origem] = estimar_distancia(origem, destino)

	while not abertas.is_empty():
		# Novo: escolhe a célula com menor custo estimado total.
		var melhor_indice: int = 0

		for indice in range(1, abertas.size()):
			if prioridades[abertas[indice]] < prioridades[
				abertas[melhor_indice]
			]:
				melhor_indice = indice

		var atual: Vector2i = abertas[melhor_indice]
		abertas.remove_at(melhor_indice)
		em_abertas.erase(atual)

		if atual == destino:
			var celula: Vector2i = destino
			resultado.append(celula)

			while celula != origem:
				celula = anteriores[celula]
				resultado.append(celula)

			resultado.reverse()
			return resultado

		fechadas[atual] = true

		for direcao in DIRECOES:
			var vizinha: Vector2i = atual + direcao

			if fechadas.has(vizinha):
				continue

			if not passagem_permitida(atual, vizinha):
				continue
			# Alteração: evita corpos e reservas, incluindo as laterais da diagonal.
			if ocupadas.has(vizinha):
				continue
			if direcao.x != 0 and direcao.y != 0:
				if ocupadas.has(atual+Vector2i(direcao.x,0)) or ocupadas.has(atual+Vector2i(0,direcao.y)):
					continue

			var custo_passo: float = 1.0

			if direcao.x != 0 and direcao.y != 0:
				custo_passo = sqrt(2.0)

			var novo_custo: float = custos[atual] + custo_passo
			var custo_anterior: float = float(
				custos.get(vizinha, INF)
			)

			if novo_custo >= custo_anterior:
				continue

			anteriores[vizinha] = atual
			custos[vizinha] = novo_custo
			prioridades[vizinha] = (
				novo_custo + estimar_distancia(vizinha, destino)
			)

			if not em_abertas.has(vizinha):
				abertas.append(vizinha)
				em_abertas[vizinha] = true

	# Mantido: caminho vazio significa destino inacessível.
	return resultado


func _on_botao_voltar_cidade_pressed() -> void:
	_saida_solicitada = true
	# Alteração: encerra a atividade antes de trocar de cena.
	aproximando = false
	batalha_encerrada = true
	timer_combate.stop()
	timer_respawn.stop()

	# Novo: impede novos consumos durante a saída da caça.
	if is_instance_valid(timer_auto_potion):
		timer_auto_potion.stop()
	get_tree().change_scene_to_file("res://cidade.tscn")


func _physics_process(delta: float) -> void:
	if not aproximando:
		return

	# Alteração: percorre os pontos do caminho, mantendo a velocidade
	# mesmo quando alcança mais de um ponto dentro do mesmo frame.
	var movimento_restante: float = velocidade_movimento * delta

	while aproximando and movimento_restante > 0.0:
		if indice_caminho >= caminho.size():
			_chegar_ao_selvagem()
			return

		# Alteração: revalida cada trecho antes de sair do centro da célula.
		var origem_celula: Vector2i = posicao_para_celula(imagem_aliado.global_position)
		if imagem_aliado.global_position.distance_to(celula_para_posicao(origem_celula)) < 0.001:
			if not _passo_aliado_livre(origem_celula,caminho[indice_caminho]):
				return
		var destino: Vector2 = celula_para_posicao(
			caminho[indice_caminho]
		)

		var distancia: float = imagem_aliado.global_position.distance_to(
			destino
		)

		var origem_trecho: Vector2 = imagem_aliado.global_position
		if distancia <= movimento_restante:
			imagem_aliado.global_position = destino
			movimento_restante -= distancia
			indice_caminho += 1
			_ao_alcancar_celula()
		else:
			imagem_aliado.global_position = (
				imagem_aliado.global_position.move_toward(
					destino,
					movimento_restante
				)
			)
			movimento_restante = 0.0
		if not origem_trecho.is_equal_approx(imagem_aliado.global_position):
			trecho_percorrido.emit(origem_trecho,imagem_aliado.global_position)

	if aproximando and indice_caminho >= caminho.size():
		_chegar_ao_selvagem()


func _chegar_ao_selvagem() -> void:
	aproximando = false

	# Mantido: o primeiro ataque acontece imediatamente.
	_on_timer_combate_timeout()

	if not batalha_encerrada:
		timer_combate.start()


func _on_timer_combate_timeout() -> void:
	if batalha_encerrada or pokemon_selvagem == null:
		return
	if usar_golpes_catalogados or usar_atributos_combate:
		_executar_golpes_catalogados()
		return
	vida_selvagem = maxi(
		0,
		vida_selvagem - pokemon_aliado.especie.dano_base
	)
	# Alteração: o número flutuante mostra o golpe completo, mesmo com HP restante menor.
	var dano_ao_selvagem: int = pokemon_aliado.especie.dano_base
	dano_aplicado.emit(
		imagem_selvagem.global_position,
		dano_ao_selvagem,
		"DARK"
	)
	if vida_selvagem == 0:
		encerrar_batalha(pokemon_aliado.especie.nome)
		return
	vida_aliado = maxi(
		0,
		vida_aliado - pokemon_selvagem.especie.dano_base
	)
	var dano_ao_aliado: int = pokemon_selvagem.especie.dano_base
	dano_aplicado.emit(
		imagem_aliado.global_position,
		dano_ao_aliado,
		"NORMAL"
	)
	if vida_aliado == 0:
		encerrar_batalha(pokemon_selvagem.especie.nome)
		return
	atualizar_interface()

# Alteração: também apresenta HP quando o alvo anterior já foi liberado.
func atualizar_interface() -> void:
	# Novo: HUD/ficha consultam o HP real do último estado da caça.
	EstadoJogo.registrar_vida_pokemon(pokemon_aliado,vida_aliado)
	titulo.text = (
		pokemon_aliado.especie.nome
		+ " — Vida: " + str(vida_aliado)
		+ "/" + str(pokemon_aliado.obter_vida_maxima())
	)
	if pokemon_selvagem != null:
		titulo.text += (
			"\n" + pokemon_selvagem.especie.nome
			+ " selvagem — Vida: " + str(vida_selvagem)
			+ "/" + str(obter_vida_maxima_selvagem())
		)


func encerrar_batalha(vencedor: String) -> void:
	if _saida_solicitada or _resolvendo_ko:
		return
	EstadoJogo.registrar_vida_pokemon(pokemon_aliado,vida_aliado)
	if vida_aliado <= 0:
		_resolvendo_ko = true
		var substituiu: bool = _substituir_aliado_derrotado()
		_resolvendo_ko = false
		if substituiu:
			# Mantém alvo, rota (inclusive passo em andamento) e agendas.
			# Os outros inimigos prontos ainda podem atingir o novo ativo.
			return
	batalha_encerrada = true
	aproximando = false
	timer_combate.stop()

	if vida_aliado <= 0:
		_on_botao_voltar_cidade_pressed()
		return

	atualizar_interface()
	titulo.text += "\n" + vencedor + " venceu!"
	_recompensar_derrota()
	capturar()


func _substituir_aliado_derrotado() -> bool:
	if vida_aliado > 0 or _saida_solicitada or not is_inside_tree() or is_queued_for_deletion():
		return false
	var candidatos: Array[DadosPokemon] = []
	for membro in EstadoJogo.time_pokemon:
		if membro == null or membro == pokemon_aliado or candidatos.has(membro):
			continue
		if not preload("res://contrato_pokemon.gd").validar(membro).is_empty():
			continue
		if not especie_valida(membro.especie) or membro.obter_vida_atual() <= 0:
			continue
		if preload("res://visual_pokemon.gd").obter(membro.especie.nome).is_empty():
			continue
		candidatos.append(membro)
	# Sem reposição: derrotados são excluídos em cada novo KO.
	while not candidatos.is_empty():
		var indice: int = rng_troca.randi_range(0,candidatos.size()-1)
		var novo: DadosPokemon = candidatos[indice]
		candidatos.remove_at(indice)
		# Exceção restrita a este substituto e a este KO. A seleção manual
		# continua passando pelo mesmo serviço e pelo cooldown normal.
		_substituto_automatico = novo
		var aceitou: bool = EstadoJogo.selecionar_lider(novo)
		_substituto_automatico = null
		if aceitou and pokemon_aliado == novo and vida_aliado > 0:
			return true
	return false


func pode_capturar() -> bool:
	return (
		pokemon_selvagem != null
		and batalha_encerrada
		and encontro_atual.estado == EncontroSelvagem.Estado.DERROTADO
		and not encontro_atual.captura_iniciada
		and vida_selvagem <= 0
		and vida_aliado > 0
		and not EstadoJogo.pokemons_capturados.has(pokemon_selvagem)
	)


func capturar() -> void:
	if not pode_capturar() or not encontro_atual.iniciar_captura():
		return

	EstadoJogo.registrar_captura(pokemon_selvagem)
	imagem_selvagem.hide()
	encontro_atual.resolver(0.0)

	titulo.text += "\n" + pokemon_selvagem.especie.nome + " capturado!"
	timer_respawn.start()


func gerar_selvagem() -> void:
	if vida_aliado <= 0 or celulas_acessiveis.size() < 2:
		return

	timer_respawn.stop()
	timer_combate.stop()

	var origem: Vector2i = posicao_para_celula(
		imagem_aliado.global_position
	)

	# Alteração: sorteia somente células conectadas e diferentes
	# daquela ocupada pelo aliado.
	var candidatas: Array[Vector2i] = []

	for celula in celulas_acessiveis:
		if celula != origem:
			candidatas.append(celula)

	if candidatas.is_empty():
		titulo.text = "Não existe um local acessível para o selvagem."
		return

	var destino: Vector2i = candidatas[
		randi_range(0, candidatas.size() - 1)
	]

	caminho = calcular_caminho(origem, destino)

	if caminho.is_empty():
		aproximando = false
		batalha_encerrada = true
		titulo.text = "Não foi possível encontrar um caminho até o selvagem."
		return

	# Alteração: quando o alcance permite, para na célula anterior
	# ao selvagem. Assim não inicia combate através de uma parede
	# apenas porque a distância em linha reta ficou pequena.
	if caminho.size() >= 2:
		var penultima: Vector2i = caminho[caminho.size() - 2]
		var distancia_final: float = (
			celula_para_posicao(penultima).distance_to(
				celula_para_posicao(destino)
			)
		)

		if distancia_final <= alcance_combate:
			caminho.pop_back()

	# O primeiro ponto é a célula que o aliado já ocupa.
	indice_caminho = 1

	var dados: DadosPokemon = DadosPokemon.new()
	dados.especie = EstadoJogo.especie_caca
	dados.sortear_ivs()
	dados.sortear_qualidade()
	encontro_atual = EncontroSelvagem.new(0, dados, imagem_selvagem, destino,
		_calcular_vida_maxima_selvagem(dados))
	_registrar_perfil_hp(encontro_atual)
	imagem_selvagem.texture = pokemon_selvagem.especie.textura

	# Alteração: substitui o sorteio de pixels pela célula acessível.
	imagem_selvagem.global_position = celula_para_posicao(destino)

	imagem_selvagem.show()
	batalha_encerrada = false
	aproximando = true
	atualizar_interface()


func _on_timer_respawn_timeout() -> void:
	gerar_selvagem()

# Novo: valida o movimento entre duas células vizinhas.
# Uma diagonal exige que as duas células laterais também estejam livres.
func passagem_permitida(
	origem: Vector2i,
	destino: Vector2i
) -> bool:
	if not celula_transitavel(origem):
		return false

	if not celula_transitavel(destino):
		return false

	var diferenca: Vector2i = destino - origem

	if diferenca == Vector2i.ZERO:
		return false

	if absi(diferenca.x) > 1 or absi(diferenca.y) > 1:
		return false

	if diferenca.x != 0 and diferenca.y != 0:
		var lateral_horizontal: Vector2i = (
			origem + Vector2i(diferenca.x, 0)
		)
		var lateral_vertical: Vector2i = (
			origem + Vector2i(0, diferenca.y)
		)

		if not celula_transitavel(lateral_horizontal):
			return false

		if not celula_transitavel(lateral_vertical):
			return false

	return true


# Novo: estima a distância restante com movimentos em oito direções.
func estimar_distancia(
	origem: Vector2i,
	destino: Vector2i
) -> float:
	var diferenca: Vector2i = destino - origem
	var horizontal: int = absi(diferenca.x)
	var vertical: int = absi(diferenca.y)

	var diagonais: int = mini(horizontal, vertical)
	var retos: int = maxi(horizontal, vertical) - diagonais

	return float(retos) + float(diagonais) * sqrt(2.0)
	
# Novo: calcula o comprimento do caminho em coordenadas globais.
func obter_comprimento_caminho(
	percurso: Array[Vector2i]
) -> float:
	var comprimento: float = 0.0
	for indice in range(1, percurso.size()):
		var anterior: Vector2 = celula_para_posicao(
			percurso[indice - 1]
		)
		var atual: Vector2 = celula_para_posicao(
			percurso[indice]
		)
		comprimento += anterior.distance_to(atual)
	return comprimento


# Novo: no máximo uma unidade por verificação, dentro ou fora do combate.
func _on_timer_auto_potion_timeout() -> void:
	if not EstadoJogo.auto_potion or vida_aliado <= 0:
		return
	if pokemon_aliado == null or pokemon_aliado.especie == null:
		return
	var vida_maxima: int = pokemon_aliado.obter_vida_maxima()
	if vida_maxima <= 0 or vida_aliado >= vida_maxima:
		return
	# Compara sem arredondar a porcentagem; inclui exatamente o limite.
	if vida_aliado * 100 > vida_maxima * EstadoJogo.auto_potion_threshold:
		return
	var id: int = EstadoJogo.escolher_pocao_auto_potion()
	if id == -1:
		return
	var dados: Dictionary = EstadoJogo.obter_dados_pocao(id)
	var cura: int = mini(int(dados["cura"]), vida_maxima - vida_aliado)
	if cura <= 0 or not EstadoJogo.consumir_pocao(id):
		return
	vida_aliado += cura
	atualizar_interface()
	var evento: Dictionary = {
		"item_id": id,
		"nome": str(dados["nome"]),
		"cura": cura,
		"vida": vida_aliado,
		"vida_maxima": vida_maxima,
		"posicao_global": imagem_aliado.global_position
	}
	evento.make_read_only()
	cura_aplicada.emit(evento)
	print("Auto-Potion | ", dados["nome"], " | +", cura,
		" HP | Vida: ", vida_aliado, "/", vida_maxima,
		" | Estoque: ", EstadoJogo.obter_quantidade_pocao(id))


# Novo: o efeito somente apresenta o resultado já aplicado.
func _apresentar_cura(evento: Dictionary) -> void:
	var efeito: Node2D = EFEITO_CURA.new()
	add_child(efeito)
	efeito.global_position = evento["posicao_global"]
	efeito.call("configurar", int(evento["cura"]))

# Novo: a grade do servidor substitui somente a navegação desta caça.
# minTx/minTy convertem col/row em coordenadas locais; não usa slots como coordenadas.
func _aplicar_navegacao_original() -> bool:
	if preload("res://catalogo_hunts.gd").obter(EstadoJogo.especie_caca.nome).is_empty():
		return true
	var arquivo: String = str(preload("res://catalogo_hunts.gd").obter(EstadoJogo.especie_caca.nome)["navegacao"])
	if not FileAccess.file_exists(arquivo):
		titulo.text = "Grade da caça não encontrada: " + arquivo
		return false
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(arquivo))
	var erro: String = preload("res://dados_navegacao.gd").validar(dados)
	if not erro.is_empty():
		# Revisão: interrompe a caça; não usa silenciosamente outra grade.
		titulo.text = "Não foi possível preparar a caça: " + erro
		return false
	parametros_navegacao_original = {"heroStepMs":int(dados["heroStepMs"]),"mobStepMs":int(dados["mobStepMs"])}
	var grid: Array = dados["grid"]
	var existentes: Dictionary = {}
	var bloqueadas: Dictionary = {}
	for row in range(int(dados["rows"])):
		for col in range(int(dados["cols"])):
			var celula: Vector2i = Vector2i(col + int(dados["minTx"]), row + int(dados["minTy"]))
			existentes[celula] = true
			if not bool(grid[row][col]):
				bloqueadas[celula] = true
	celulas_existentes = existentes
	celulas_bloqueadas = bloqueadas
	# Alteração: servidor já delimita a região; dispensa recorte retangular aproximado.
	limitar_area_caca = false
	# Alteração: passo reto de 500ms em tiles de 32px; diagonal mantém a regra local.
	velocidade_movimento = TAMANHO_TILE / (float(dados["heroStepMs"]) / 1000.0)
	print("Navegação original: ", existentes.size()-bloqueadas.size(), " células livres; passo ", dados["heroStepMs"], "ms")
	return true

func _recompensar_derrota() -> void:
	if encontro_recompensado or vida_selvagem > 0 or vida_aliado <= 0 or pokemon_selvagem == null:
		return
	if preload("res://catalogo_hunts.gd").obter(pokemon_selvagem.especie.nome).is_empty():
		return
	if not encontro_atual.reservar_recompensa():
		return
	var regras: Dictionary = preload("res://catalogo_hunts.gd").obter(pokemon_selvagem.especie.nome)
	var base: int = int(regras["xp"])
	var vip: int = int(regras["vip"]) if bonus_vip_recompensa else 0
	var total: int = base + vip
	EstadoJogo.conceder_experiencia(pokemon_aliado,total)
	EstadoJogo.registrar_recompensa_treinador(total)
	var loot: Array[Dictionary] = EstadoJogo.inventario.receber_loot(preload("res://regras_loot.gd").sortear(pokemon_selvagem.especie.nome,rng_loot))
	var evento: Dictionary = {"encontro_id":encontro_atual.id,"slot":encontro_atual.slot,"speciesName":pokemon_selvagem.especie.nome,"xpGained":total,
		"xpParts":{"base":base,"vip":vip},
		"pokeXp":{"xpGained":total,"parts":{"base":base,"vip":vip}},"loot":loot}
	derrota_recompensada.emit(evento.duplicate(true))

func obter_vida_maxima_selvagem() -> int:
	return encontro_atual.vida_maxima if encontro_atual != null else 0

func _calcular_vida_maxima_selvagem(pokemon: DadosPokemon) -> int:
	if usar_atributos_combate: return VIDA_SELVAGEM.calcular(pokemon,_hp_candidato_ativo())
	if usar_hp_selvagem_original and pokemon.especie.nome == "Geodude":
		return 120
	return pokemon.especie.vida_maxima

# HP é fixado ao criar/respawnar o encontro. Alternar no Inspetor não cura o vivo.
func _registrar_perfil_hp(encontro: EncontroSelvagem) -> void:
	var combate: DadosPokemon=encontro.obter_pokemon_combate()
	var r: Dictionary=VIDA_SELVAGEM.detalhar(combate,_hp_candidato_ativo()).duplicate()
	if not usar_atributos_combate:r={"regra":"hp_legado_especie","fidelidade_comprovada":false}
	var configuracao: Dictionary=preload("res://catalogo_hunts.gd").obter(combate.especie.nome)
	r["nivel_acesso_hunt"]=configuracao.get("nivel")
	r["regra_nivel_combate"]=configuracao.get("regra_nivel_combate","desconhecida")
	r["perfil_combate_id"]=encontro.perfil_combate_id
	r["perfil_combate_persistente"]=encontro.perfil_combate_persistente
	r["hp_maximo_aplicado"]=encontro.vida_maxima
	r.make_read_only()
	encontro.perfil_hp=r

func _preservar_perfil_combate(dados: DadosPokemon) -> bool:
	return preservar_perfis_de_combate_na_hunt and _calibracao_ativa() and dados.especie.nome=="Blastoise"

func _hp_candidato_ativo() -> bool:
	return usar_hp_selvagem_candidato and _calibracao_ativa()

# Novo: ponto seguro de extensão para atualizar caminhos sem cortar quinas.
func _ao_alcancar_celula() -> void:
	pass

# Evolução: permite avançar o relógio em testes sem depender do tempo real.
func _avancar_agendas_golpes(delta: float) -> void:
	if not usar_golpes_catalogados and not usar_atributos_combate:
		return
	agenda_aliado.configurar(pokemon_aliado.especie.nome,pokemon_aliado.nivel)
	# Cooldowns continuam transcorrendo para os membros já usados nesta instância.
	for agenda in agendas_aliados.values():
		if _calibracao_ativa(): agenda.avancar_calibrado(delta)
		else: agenda.avancar(delta)

func _executar_golpes_catalogados() -> void:
	agenda_aliado.configurar(pokemon_aliado.especie.nome,pokemon_aliado.nivel)
	var golpe: Dictionary
	if _calibracao_ativa():
		golpe=agenda_aliado.retirar_calibrado(intervalo_ataques_caca,_prever_dano_aliado,aplicar_cooldowns_catalogo,_efetividade_contra.bind(encontro_atual.obter_pokemon_combate()))
		_publicar_diagnostico_ofensivo(agenda_aliado.ultimo_diagnostico, encontro_atual)
	else:
		golpe=agenda_aliado.retirar_pronto(aplicar_cooldowns_catalogo,maxf(0.05,intervalo_ataques_caca))
	if not golpe.is_empty():
		var anterior: int = vida_selvagem
		# Usa os atributos do indivíduo; a curva de dano está isolada em regras_dano.
		var calculo: Dictionary=_resolver_dano_golpe(pokemon_aliado,encontro_atual.obter_pokemon_combate(),golpe,false)
		var dano: int=int(calculo["dano"])
		vida_selvagem = maxi(0,vida_selvagem-dano)
		_emitir_golpe(golpe,true,dano,anterior-vida_selvagem,null,calculo)
		if vida_selvagem==0:
			encerrar_batalha(pokemon_aliado.especie.nome)
			if vida_aliado>0: _processar_ataques_selvagens()
			return
	_processar_ataques_selvagens()
	if vida_aliado<=0 or batalha_encerrada: return
	# O timer do aliado não decide quando os selvagens podem atacar.
	if not aplicar_cooldowns_catalogo:
		var restante: float=agenda_aliado.proximo_ataque_rapido-agenda_aliado.tempo
		timer_combate.start(maxf(0.05,restante))
	atualizar_interface()

# A cena com população redefine a enumeração, sem trocar o alvo atual.
func _processar_ataques_selvagens() -> void:
	if encontro_atual!=null: _executar_ataque_selvagem(encontro_atual)

func _selvagem_em_alcance(registro: EncontroSelvagem) -> bool:
	if registro==null or registro.estado!=EncontroSelvagem.Estado.VIVO or registro.movendo or not is_instance_valid(registro.imagem): return false
	var origem: Vector2i=posicao_para_celula(imagem_aliado.global_position)
	return (origem==registro.celula or passagem_permitida(origem,registro.celula)) and imagem_aliado.global_position.distance_to(registro.imagem.global_position)<=alcance_combate+0.1

func _executar_ataque_selvagem(registro: EncontroSelvagem) -> void:
	if vida_aliado<=0 or not _selvagem_em_alcance(registro): return
	var agenda: RefCounted=registro.agenda_golpes
	var combate: DadosPokemon=registro.obter_pokemon_combate()
	agenda.configurar(combate.especie.nome,combate.nivel)
	var padrao: float=intervalo_selvagem_calibrado if _calibracao_ativa() else intervalo_ataques_selvagem
	var intervalo: float=registro.intervalo_ataque if registro.intervalo_ataque>0 else padrao
	if _preparo_inicial_ativo(registro) and not registro.primeiro_ataque_preparado:
		registro.primeiro_ataque_preparado=true
		registro.inicio_preparo_primeiro_ataque=agenda.tempo+(agenda.residuo_tick if registro.intervalo_ataque<=0 else 0.0)
		registro.prazo_primeiro_ataque=registro.inicio_preparo_primeiro_ataque+maxf(0.05,intervalo)
		agenda.proximo_ataque_rapido=maxf(agenda.proximo_ataque_rapido,registro.prazo_primeiro_ataque)
		return
	var golpe: Dictionary
	if _calibracao_ativa():
		golpe=agenda.retirar_calibrado(intervalo,_prever_dano_selvagem.bind(registro),aplicar_cooldowns_catalogo,_efetividade_contra.bind(pokemon_aliado))
		registro.diagnostico_ofensivo=agenda.ultimo_diagnostico.duplicate(true)
	else:
		golpe=agenda.retirar_pronto(aplicar_cooldowns_catalogo,maxf(0.05,intervalo),_prever_dano_selvagem.bind(registro))
	if golpe.is_empty(): return
	# A reserva da agenda precede a aplicação e a emissão: chamadas repetidas não duplicam o golpe.
	var anterior: int=vida_aliado
	var calculo: Dictionary=_resolver_dano_golpe(combate,pokemon_aliado,golpe,true)
	var dano: int=int(calculo["dano"])
	vida_aliado=maxi(0,anterior-dano)
	_emitir_golpe(golpe,false,dano,anterior-vida_aliado,registro,calculo)
	if vida_aliado<=0: encerrar_batalha(registro.pokemon.especie.nome)

# A evidência de entrada em combate disponível é de Blastoise. Nunca usa o alvo
# do aliado como autorização e nunca rearma o prazo ao sair/voltar ao alcance.
func _preparo_inicial_ativo(registro: EncontroSelvagem) -> bool:
	return preparar_primeiro_ataque_selvagem and _calibracao_ativa() and registro.obter_pokemon_combate().especie.nome=="Blastoise"

# Alteração: dano do golpe e HP removido são distintos em golpes fatais.
# O quarto parâmetro é opcional para preservar chamadas anteriores.
func _emitir_golpe(golpe: Dictionary, aliado: bool, dano: int, vida_removida: int = -1, encontro_origem: EncontroSelvagem = null, calculo_dano: Dictionary = {}) -> void:
	var registro: EncontroSelvagem=encontro_origem if encontro_origem!=null else encontro_atual
	if registro==null: return
	var origem: Vector2 = imagem_aliado.global_position if aliado else registro.imagem.global_position
	var destino: Vector2 = registro.imagem.global_position if aliado else imagem_aliado.global_position
	var defensor: DadosPokemon=registro.obter_pokemon_combate() if aliado else pokemon_aliado
	var base_defensor: Dictionary=defensor.especie.obter_base()
	var fator: float=DANO.efetividade(golpe,defensor) if usar_atributos_combate else preload("res://catalogo_golpes.gd").efetividade(str(golpe["type"]),str(base_defensor.get("type1","")),str(base_defensor.get("type2","")))
	var evento: Dictionary = {"encontro_id":registro.id,"slot":registro.slot,"perfil_combate_id":registro.perfil_combate_id,
		"primeiro_ataque_preparado":registro.primeiro_ataque_preparado if not aliado else false,
		"inicio_preparo_primeiro_ataque":registro.inicio_preparo_primeiro_ataque if not aliado else -1.0,
		"prazo_primeiro_ataque":registro.prazo_primeiro_ataque if not aliado else -1.0,
		"tempo_atacante":agenda_aliado.tempo+agenda_aliado.residuo_tick if aliado else registro.agenda_golpes.tempo+registro.agenda_golpes.residuo_tick,
		"efetividade":fator,"aliado":aliado,"nome":str(golpe["name"]),"tipo":str(golpe["type"]),
		"categoria":str(golpe["category"]),"power":int(golpe["power"]),
		"cooldown_ms":int(golpe["cooldownMs"]),"dano":dano,"dano_provisorio":true,"regra_dano":_versao_dano(),"via_combate":str(golpe.get("via_combate","legado")),"cooldown_aplicado_ms":int(golpe.get("cooldown_aplicado_ms",golpe["cooldownMs"] if aplicar_cooldowns_catalogo else 0)),"tick_combate_ms":200 if _calibracao_ativa() and (aliado or registro.intervalo_ataque<=0) else 0,
		"vida_removida":dano if vida_removida < 0 else vida_removida,
		"origem":origem,"destino":destino,"calculo_dano":calculo_dano}
	evento.make_read_only()
	golpe_executado.emit(evento)
	dano_aplicado.emit(destino,dano,str(golpe["type"]))

# Alteração: ponto de extensão para reservas dinâmicas da população.
func _passo_aliado_livre(origem: Vector2i, destino: Vector2i) -> bool:
	return passagem_permitida(origem,destino)

# Valor nominal determinístico para escolher o maior golpe antes da variação.
func _dano_golpe(atacante: DadosPokemon, defensor: DadosPokemon, golpe: Dictionary, selvagem: bool) -> int:
	if _candidata_ativa():return DANO_CANDIDATO.nominal(atacante,defensor,golpe,selvagem,_nivel_formula_selvagem(atacante) if selvagem else 0)
	return DANO.calcular(atacante,defensor,golpe,selvagem,_calibracao_ativa()) if usar_atributos_combate else atacante.especie.dano_base

# Único ponto que sorteia o dano de um golpe efetivamente executado.
func _resolver_dano_golpe(atacante: DadosPokemon, defensor: DadosPokemon, golpe: Dictionary, selvagem: bool) -> Dictionary:
	if _candidata_ativa():return DANO_CANDIDATO.resolver(atacante,defensor,golpe,selvagem,rng_dano,_nivel_formula_selvagem(atacante) if selvagem else 0)
	var r: Dictionary={"regra":_versao_dano(),"dano":_dano_golpe(atacante,defensor,golpe,selvagem),"variacao":1.0,"stab":1.0}
	r.make_read_only()
	return r

func _nivel_formula_selvagem(pokemon: DadosPokemon) -> int:
	if not usar_nivel_dano_catalogo_selvagem or not _candidata_ativa():return 0
	var dados: Dictionary=preload("res://catalogo_golpes.gd").obter(pokemon.especie.nome)
	var nivel: int=int(dados.get("huntLevel",0))
	return nivel if nivel>=1 and nivel<=100000 else 0

func _candidata_ativa() -> bool:
	return usar_dano_candidato and _calibracao_ativa()

# Política provisória: listar uma TM no catálogo não comprova que o selvagem a aprendeu.
func _prever_dano_selvagem(golpe: Dictionary, registro: EncontroSelvagem) -> float:
	if golpe.has("tm"): return 0.0
	return float(_dano_golpe(registro.obter_pokemon_combate(),pokemon_aliado,golpe,true))

func _calibracao_ativa() -> bool:
	return usar_calibracao_combate and usar_atributos_combate

func _versao_dano() -> String:
	if not usar_atributos_combate: return "legado_mock"
	if _candidata_ativa():return DANO_CANDIDATO.VERSAO
	return "atributos_local_v2_piso_2_1" if _calibracao_ativa() else "atributos_local_v1"

func _prever_dano_aliado(golpe: Dictionary) -> float:
	if pokemon_selvagem==null: return 0.0
	return float(_dano_golpe(pokemon_aliado,encontro_atual.obter_pokemon_combate(),golpe,false))

func _efetividade_contra(golpe: Dictionary, defensor: DadosPokemon) -> float:
	return DANO.efetividade(golpe,defensor)

func _prever_dano_contra(golpe: Dictionary, registro: EncontroSelvagem) -> float:
	return float(_dano_golpe(pokemon_aliado,registro.obter_pokemon_combate(),golpe,false))

# Consulta um defensor sem substituir encontro_atual ou consumir RNG/cooldown.
# Modos antigos não calibrados mantêm a seleção anterior, fora do perfil P04.
func diagnosticar_ofensiva_contra(registro: EncontroSelvagem) -> Dictionary:
	if not _calibracao_ativa(): return {"estado":"fora_do_perfil", "motivo":"", "detalhes":[]}
	if registro==null or registro.pokemon==null or registro.obter_pokemon_combate().especie==null:
		return {"estado":"bloqueado", "motivo":"dados_invalidos", "detalhes":[]}
	agenda_aliado.configurar(pokemon_aliado.especie.nome,pokemon_aliado.nivel)
	return agenda_aliado.diagnosticar_calibrado(_prever_dano_contra.bind(registro),aplicar_cooldowns_catalogo,_efetividade_contra.bind(registro.obter_pokemon_combate()))

func _pode_ferir(registro: EncontroSelvagem) -> bool:
	return diagnosticar_ofensiva_contra(registro)["estado"]!="bloqueado"

func _publicar_diagnostico_ofensivo(diagnostico: Dictionary, alvo: EncontroSelvagem=null, mensagem: String="") -> void:
	var novo: Dictionary=diagnostico.duplicate(true)
	novo["aliado"]=pokemon_aliado.especie.nome
	novo["aliado_id"]=pokemon_aliado.get_instance_id()
	novo["nivel"]=pokemon_aliado.nivel
	novo["alvo_id"]=alvo.id if alvo!=null else ""
	novo["alvo_nome"]=alvo.pokemon.especie.nome if alvo!=null and alvo.pokemon!=null else ""
	novo["politica"]="p04_sem_dano_sem_fallback_v1"
	if mensagem.is_empty() and novo.get("estado","")=="bloqueado":
		mensagem="%s não consegue causar dano. %s Troque o Pokémon do time ou escolha outra hunt." % [novo["aliado"],_motivo_ofensivo(str(novo.get("motivo","")))]
	novo["mensagem"]=mensagem
	novo.make_read_only()
	diagnostico_ofensivo_aliado=novo
	# A passagem do tempo não gera um aviso por frame nem rearma efeitos.
	var chave: String=JSON.stringify([novo.get("estado",""),novo.get("motivo",""),novo["aliado_id"],novo["nivel"],novo["alvo_id"],mensagem])
	if chave==_chave_diagnostico_ofensivo: return
	_chave_diagnostico_ofensivo=chave
	ofensiva_aliado_alterada.emit(novo)

func _motivo_ofensivo(motivo: String) -> String:
	match motivo:
		"todos_imunes": return "O alvo é imune a todos os golpes ofensivos disponíveis."
		"somente_status": return "Só há golpes de status, cujos efeitos ainda não estão implementados."
		"sem_golpe_catalogado": return "O catálogo não contém golpes para essa espécie."
		"sem_golpe_no_nivel": return "Não há golpe liberado neste nível."
		"habilidades_indisponiveis": return "As habilidades listadas não estão disponíveis; TM no catálogo não significa aprendida."
		"dados_invalidos", "avaliador_indisponivel": return "Há dados de golpe indisponíveis ou inválidos."
		_: return "Nenhum golpe disponível tem dano positivo pelas regras atuais."

# Troca só o aliado. População, HP inimigo, rota e contadores da hunt permanecem.
func _sincronizar_lider_caca() -> void:
	if _saida_solicitada or not is_inside_tree() or is_queued_for_deletion(): return
	var novo: DadosPokemon=EstadoJogo.obter_lider()
	if novo==pokemon_aliado: return
	if novo==null or not especie_valida(novo.especie) or novo.obter_vida_atual()<=0:
		# O clique no HUD também passa por aqui; não permite invocar um derrotado.
		EstadoJogo.selecionar_lider(pokemon_aliado)
		return
	var anterior: RefCounted=agenda_aliado
	if not agendas_aliados.has(novo):
		var agenda: RefCounted=preload("res://agenda_golpes.gd").new()
		agenda.tempo=anterior.tempo
		agenda.residuo_tick=anterior.residuo_tick
		agendas_aliados[novo]=agenda
	pokemon_aliado=novo
	EstadoJogo.prazo_troca_hunt_ms=int(relogio_troca.call())+roundi(COOLDOWN_TROCA_SEGUNDOS*1000.0)
	agenda_aliado=agendas_aliados[novo]
	agenda_aliado.configurar(novo.especie.nome,novo.nivel)
	# Trocar repetidamente não concede ataques extras nem apaga cooldowns próprios.
	agenda_aliado.proximo_ataque_rapido=maxf(agenda_aliado.proximo_ataque_rapido,anterior.proximo_ataque_rapido)
	agenda_aliado.proximo_ataque_catalogado=maxf(agenda_aliado.proximo_ataque_catalogado,anterior.proximo_ataque_catalogado)
	imagem_aliado.call("_iniciar_animacao")
	atualizar_interface()
	aliado_alterado.emit(novo)
	_tentar_iniciar_atividade()

func obter_troca_restante() -> float:
	return maxf(0.0,float(EstadoJogo.prazo_troca_hunt_ms-int(relogio_troca.call()))/1000.0)

func _validar_troca_lider_hunt(novo: DadosPokemon) -> bool:
	if _saida_solicitada or not is_inside_tree() or is_queued_for_deletion():
		return false
	if novo == null or not especie_valida(novo.especie) or novo.obter_vida_atual() <= 0:
		return false
	var substituicao_por_ko: bool = _resolvendo_ko and novo == _substituto_automatico and vida_aliado <= 0
	return substituicao_por_ko or obter_troca_restante() <= 0.0

func _exit_tree() -> void:
	_saida_solicitada = true
	if EstadoJogo.lider_alterado.is_connected(_sincronizar_lider_caca):
		EstadoJogo.lider_alterado.disconnect(_sincronizar_lider_caca)
	if is_instance_valid(timer_auto_potion):
		timer_auto_potion.stop()
	# Uma cena antiga nunca remove o validador de uma nova hunt já iniciada.
	if EstadoJogo.validador_troca_lider.is_valid() and EstadoJogo.validador_troca_lider.get_object()==self:
		EstadoJogo.validador_troca_lider=Callable()
