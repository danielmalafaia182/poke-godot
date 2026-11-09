extends "res://caca_base.gd"

const ANIMACAO_GEODUDE: Script = preload(
	"res://animacao_selvagem.gd"
)

@export var spritesheet_geodude: Texture2D
@export var intervalo_respawn: float = 2.0
# Novo: passo1000ms confirmado. As regras de decisão abaixo são locais.
@export var movimento_selvagens_habilitado: bool = true
@export_range(1,20,1) var raio_passeio_selvagens: int = 4
@export_range(0,30,1) var raio_perseguicao_selvagens: int = 8
@export_range(0.0,1.0,0.05) var chance_pausa_selvagens: float = 0.35
@export var mostrar_indicadores_todos_selvagens: bool = true
var movimento_selvagens: RefCounted = preload("res://movimento_selvagens.gd").new()
var recalcular_alvo_pendente: bool = false
@export var reagir_ao_cerco: bool = true

@export_range(0.0, 1.0, 0.01)
var chance_captura: float = 1.0
# Alteração: o seletor isolado foi substituído pelo painel Auto-Helper.
const PAINEL_AUTO_HELPER: Script = preload("res://painel_auto_helper.gd")
var painel_auto_helper: Control

var CELULA_INICIAL: Vector2i = Vector2i(-2,3)
var PONTOS_RESPAWN: Array[Vector2i] = []
var configuracao_hunt: Dictionary = {}

var selvagens: Array[EncontroSelvagem] = []
var populacao_iniciada: bool = false
const INTERVALO_REVISAO_OFENSIVA: float = 0.2
var _tempo_revisao_ofensiva: float = 0.0
var quantidade_populacao: int = 0
# Índice derivado do encontro: não existe uma segunda identidade de alvo.
var indice_alvo: int:
	get: return encontro_atual.slot if encontro_atual != null else -1
	set(valor):
		encontro_atual = selvagens[valor] if valor >= 0 and valor < selvagens.size() else null
var imagem_modelo: Sprite2D

var sequencia_captura: int = 0


func preparar_navegacao() -> bool:
	if not celula_transitavel(CELULA_INICIAL):
		titulo.text = (
			"A posição inicial original está bloqueada ou fora da área."
		)

		push_error(
			"Posição inicial da hunt indisponível: "
			+ str(CELULA_INICIAL)
		)
		return false

	imagem_aliado.global_position = celula_para_posicao(
		CELULA_INICIAL
	)

	return super.preparar_navegacao()


func gerar_selvagem() -> void:
	if vida_aliado <= 0:
		return

	if not populacao_iniciada:
		_iniciar_populacao()
		return

	_selecionar_alvo()


func _iniciar_populacao() -> void:
	if preload("res://catalogo_hunts.gd").obter(EstadoJogo.especie_caca.nome).is_empty():
		titulo.text = "Caça não cadastrada."
		return

	if intervalo_respawn <= 0.0:
		titulo.text = (
			"O intervalo de respawn precisa ser maior que zero."
		)
		return

	var acessiveis: Dictionary[Vector2i, bool] = {}

	for celula in celulas_acessiveis:
		acessiveis[celula] = true

	var pontos_invalidos: Array[Vector2i] = []

	for celula in PONTOS_RESPAWN:
		if not celula_transitavel(celula):
			pontos_invalidos.append(celula)
			continue

		if not acessiveis.has(celula):
			pontos_invalidos.append(celula)

	if not pontos_invalidos.is_empty():
		titulo.text = (
			"Existem pontos originais bloqueados ou inacessíveis. "
			+ "Confira a saída do depurador."
		)

		push_error(
			"Pontos originais de respawn indisponíveis: "
			+ str(pontos_invalidos)
		)
		return

	imagem_modelo = imagem_selvagem
	imagem_modelo.hide()
	timer_respawn.stop()

	quantidade_populacao = PONTOS_RESPAWN.size()

	for indice in range(quantidade_populacao):
		var nova_imagem: Sprite2D = Sprite2D.new()
		nova_imagem.set_script(ANIMACAO_GEODUDE)
		nova_imagem.name = "Selvagem_" + str(indice + 1)

		nova_imagem.centered = imagem_modelo.centered
		nova_imagem.offset = imagem_modelo.offset
		nova_imagem.scale = imagem_modelo.scale
		nova_imagem.z_index = imagem_modelo.z_index
		nova_imagem.texture_filter = (
			CanvasItem.TEXTURE_FILTER_NEAREST
		)

		add_child(nova_imagem)

		var celula: Vector2i = PONTOS_RESPAWN[indice]

		selvagens.append(EncontroSelvagem.new(indice, null, nova_imagem, celula))

		_criar_individuo(indice, celula)

	populacao_iniciada = true

	print("Posição inicial da caça: ", CELULA_INICIAL)
	print("População configurada: ", quantidade_populacao)
	print("Pontos originais validados: ", PONTOS_RESPAWN.size())

	_selecionar_alvo()


func _criar_individuo(indice: int, celula: Vector2i) -> void:
	var dados: DadosPokemon = DadosPokemon.new()
	dados.especie = EstadoJogo.especie_caca
	dados.nivel = int(preload("res://catalogo_hunts.gd").obter(dados.especie.nome)["nivel_combate"])
	dados.sortear_ivs()
	dados.sortear_qualidade()

	var imagem: Sprite2D = selvagens[indice].imagem

	imagem.global_position = celula_para_posicao(celula)

	# Troca a instância inteira: nenhuma flag do encontro anterior sobrevive.
	selvagens[indice] = EncontroSelvagem.new(indice, dados, imagem, celula,
		_calcular_vida_maxima_selvagem(dados))
	_registrar_perfil_hp(selvagens[indice])
	movimento_selvagens.preparar_individuo(selvagens[indice],celula)

	imagem.call(
		"configurar",
		dados.especie.nome,
		self,
		imagem_aliado
	)

	# Alteração: um indicador por sprite; respawn recebe a nova identidade do encontro.
	var indicador: Node2D = imagem.get_node_or_null("IndicadorSelvagem")
	if indicador == null:
		indicador = preload("res://indicador_selvagem.gd").new()
		indicador.name = "IndicadorSelvagem"
		imagem.add_child(indicador)
	indicador.configurar(self,selvagens[indice])
	imagem.show()


func _process(delta: float) -> void:
	if not populacao_iniciada or vida_aliado <= 0:
		return

	for indice in range(selvagens.size()):
		if bool(selvagens[indice].ativo):
			continue

		var tempo: float = (
			float(selvagens[indice].tempo_respawn) - delta
		)

		selvagens[indice].tempo_respawn = maxf(0.0, tempo)

		if tempo <= 0.0:
			_tentar_respawn(indice)

	# P04: reconsulta limitada, também permite recuperar após nível/troca/respawn.
	_tempo_revisao_ofensiva-=maxf(0.0,delta)
	# O intervalo só limita a reavaliação da espera problemática. Após um KO
	# normal, selecionar o próximo alvo continua acontecendo no frame seguinte.
	if indice_alvo==-1 and str(diagnostico_ofensivo_aliado.get("estado","")) not in ["bloqueado","aguardando_alvo"]:
		_selecionar_alvo()
		return
	if _tempo_revisao_ofensiva<=0.0:
		_tempo_revisao_ofensiva=INTERVALO_REVISAO_OFENSIVA
		_revisar_viabilidade_ofensiva()

func _revisar_viabilidade_ofensiva() -> void:
	if _saida_solicitada: return
	if encontro_atual!=null and encontro_atual.estado==EncontroSelvagem.Estado.VIVO:
		var diagnostico: Dictionary=diagnosticar_ofensiva_contra(encontro_atual)
		_publicar_diagnostico_ofensivo(diagnostico,encontro_atual)
		if diagnostico["estado"]!="bloqueado": return
		# Não cancela a reserva nem teleporta no meio do passo do aliado.
		var celula: Vector2i=posicao_para_celula(imagem_aliado.global_position)
		if imagem_aliado.global_position.distance_to(celula_para_posicao(celula))>0.001: return
		encontro_atual=null
		aproximando=false
		batalha_encerrada=true
		caminho.clear()
		indice_caminho=0
		recalcular_alvo_pendente=false
		timer_combate.stop()
	if indice_alvo==-1: _selecionar_alvo()


func _tentar_respawn(indice: int) -> void:
	var destino: Vector2i = PONTOS_RESPAWN[indice]

	var celula_aliado: Vector2i = posicao_para_celula(
		imagem_aliado.global_position
	)

	# Aguarda se o aliado estiver ocupando o ponto.
	# Alteração: respawn também respeita o trecho já reservado pelo aliado.
	if destino == celula_aliado or obter_reservas_aliado().has(destino):
		selvagens[indice].tempo_respawn = 0.5
		return

	for outro_indice in range(selvagens.size()):
		if outro_indice == indice:
			continue

		if not bool(selvagens[outro_indice].ativo):
			continue

		var celula_ocupada: Vector2i = (
			selvagens[outro_indice].celula
		)

		if celula_ocupada == destino or (bool(selvagens[outro_indice].movendo) and selvagens[outro_indice].origem_movimento == destino):
			selvagens[indice].tempo_respawn = 0.5
			return

	_criar_individuo(indice, destino)


func _selecionar_alvo() -> void:
	if vida_aliado <= 0 or indice_alvo != -1:
		return

	var origem: Vector2i = posicao_para_celula(
		imagem_aliado.global_position
	)

	var melhor_indice: int = -1
	var melhor_caminho: Array[Vector2i] = []
	var melhor_comprimento: float = INF
	var vivos: int=0
	var compativeis: int=0
	var ultimo_bloqueio: Dictionary={}
	var bloqueios: Array[Dictionary]=[]
	var motivos_bloqueio: Dictionary={}

	for indice in range(selvagens.size()):
		if selvagens[indice].estado != EncontroSelvagem.Estado.VIVO:
			continue
		vivos+=1
		var diagnostico: Dictionary=diagnosticar_ofensiva_contra(selvagens[indice])
		if diagnostico["estado"]=="bloqueado":
			ultimo_bloqueio=diagnostico
			bloqueios.append({"encontro_id":selvagens[indice].id,"nome":selvagens[indice].pokemon.especie.nome,"motivo":diagnostico["motivo"]})
			motivos_bloqueio[diagnostico["motivo"]]=true
			continue
		compativeis+=1

		var destino: Vector2i = selvagens[indice].celula

		var candidato: Array[Vector2i] = _calcular_caminho_aliado(
			origem,
			destino
		)

		if candidato.is_empty():
			continue

		var comprimento: float = obter_comprimento_caminho(
			candidato
		)

		if comprimento < melhor_comprimento:
			melhor_indice = indice
			melhor_caminho = candidato
			melhor_comprimento = comprimento

	if melhor_indice == -1:
		aproximando = false
		batalha_encerrada = true
		titulo.text = "Aguardando um selvagem acessível..."
		if vivos==0:
			_publicar_diagnostico_ofensivo({"estado":"aguardando_respawn", "motivo":"sem_selvagens_vivos"})
		elif compativeis==0:
			ultimo_bloqueio=ultimo_bloqueio.duplicate(true)
			ultimo_bloqueio["alvos_bloqueados"]=bloqueios
			var explicacao: String=""
			for motivo in motivos_bloqueio:
				explicacao+=_motivo_ofensivo(str(motivo))+" "
			if motivos_bloqueio.size()>1: ultimo_bloqueio["motivo"]="multiplos_bloqueios"
			var mensagem: String="%s não consegue causar dano nos selvagens vivos desta hunt. %sTroque o Pokémon do time ou escolha outra hunt." % [pokemon_aliado.especie.nome,explicacao]
			_publicar_diagnostico_ofensivo(ultimo_bloqueio,null,mensagem)
		else:
			_publicar_diagnostico_ofensivo({"estado":"aguardando_alvo", "motivo":"sem_rota_para_alvo_compativel"},null,"Há selvagem que este Pokémon consegue ferir, mas ainda sem rota livre. Aguardando passagem; você pode trocar o Pokémon ou a hunt.")
		return

	encontro_atual = selvagens[melhor_indice]
	_publicar_diagnostico_ofensivo(diagnosticar_ofensiva_contra(encontro_atual),encontro_atual)
	# Seleção e recálculo consultam HP/flags já existentes; não os reiniciam.
	recalcular_alvo_pendente = false

	caminho = melhor_caminho

	if caminho.size() >= 2:
		var penultima: Vector2i = caminho[caminho.size() - 2]
		var ultima: Vector2i = caminho[caminho.size() - 1]

		var distancia_final: float = (
			celula_para_posicao(penultima).distance_to(
				celula_para_posicao(ultima)
			)
		)

		if distancia_final <= alcance_combate:
			caminho.pop_back()

	indice_caminho = 1
	batalha_encerrada = false
	aproximando = true

	atualizar_interface()


func capturar() -> void:
	if indice_alvo < 0 or indice_alvo >= selvagens.size():
		return

	if not pode_capturar():
		return

	var indice: int = indice_alvo

	if not bool(selvagens[indice].ativo):
		return

	var encontro: EncontroSelvagem = selvagens[indice]
	if encontro != encontro_atual or not encontro.iniciar_captura():
		return
	var pokemon: DadosPokemon = encontro.pokemon
	# Evolução: falha técnica não consome bola nem anuncia uma captura.
	var erro_entrada: String = EstadoJogo.validar_nova_captura(pokemon)
	if not erro_entrada.is_empty():
		_liberar_selvagem_derrotado(indice)
		titulo.text += "\nCaptura não iniciada: " + erro_entrada
		return
	var imagem: Sprite2D = selvagens[indice].imagem

	var origem: Vector2 = imagem_aliado.global_position
	var destino: Vector2 = imagem.global_position
	var nome_pokemon: String = pokemon.especie.nome

	# Novo: captura desligada ou filtro incompatível não gastam bola.
	# Regra do protótipo: o derrotado sai e a vaga entra em respawn.
	if not EstadoJogo.auto_catch:
		_liberar_selvagem_derrotado(indice)
		titulo.text += "\nAuto-Catch desligado."
		return
	if not EstadoJogo.nome_permitido_auto_catch(nome_pokemon):
		_liberar_selvagem_derrotado(indice)
		titulo.text += "\nCaptura ignorada pelo filtro de nomes."
		return

	# Novo: fixa a bola utilizada nesta tentativa.
	# Alterar a seleção depois não muda o evento já emitido.
	# Alteração: a bola automática não depende da seleção manual.
	var bola_id: int = EstadoJogo.auto_catch_ball_id
	var dados_bola: Dictionary = EstadoJogo.obter_dados_bola(bola_id)

	if dados_bola.is_empty() or bola_id == 5:
		_liberar_selvagem_derrotado(indice)
		titulo.text += "\nBola selecionada inválida."
		return

	var nome_bola: String = str(dados_bola["nome"])

	# Alteração: consumo individual, respeitando bolas infinitas.
	if not EstadoJogo.consumir_bola(bola_id):
		_liberar_selvagem_derrotado(indice)

		titulo.text += "\nSem estoque de " + nome_bola + "."

		print(
			"Captura não tentada: sem estoque de ",
			nome_bola
		)
		return

	# Mantido: chance provisória.
	# catch_rate ainda não participa do cálculo.
	var chance: float = clampf(chance_captura, 0.0, 1.0)
	var sucesso: bool = false

	if chance >= 1.0:
		sucesso = true
	elif chance > 0.0:
		sucesso = randf() < chance

	sequencia_captura += 1

	# Evolução: não anuncia sucesso se a coleção rejeitar os dados.
	var erro_registro: bool = false
	if sucesso:
		erro_registro = not EstadoJogo.registrar_captura(pokemon)
		sucesso = not erro_registro

	_liberar_selvagem_derrotado(indice)

	if sucesso:
		titulo.text += "\n" + nome_pokemon + " capturado!"
	elif erro_registro:
		titulo.text += "\nNão foi possível registrar o Pokémon na coleção."
	else:
		titulo.text += "\nA captura de " + nome_pokemon + " falhou!"

	# Alteração: acrescenta a identidade da bola ao evento.
	var evento: Dictionary = {
		"id": sequencia_captura,
		"encontro_id": encontro.id,
		"slot": encontro.slot,
		"nome": nome_pokemon,
		"origem": origem,
		"destino": destino,
		"sucesso": sucesso,
		"bola_id": bola_id,
		"bola_nome": nome_bola,
		"erro_registro": erro_registro
	}

	evento.make_read_only()
	captura_resolvida.emit(evento)

	print(
		"Tentativa: ", sequencia_captura,
		" | Bola: ", nome_bola,
		" | Sucesso: ", sucesso,
		" | Estoque: ", EstadoJogo.obter_quantidade_bola(bola_id),
		" | Coleção: ", EstadoJogo.pokemons_capturados.size()
	)
func _on_timer_respawn_timeout() -> void:
	timer_respawn.stop()

func _liberar_selvagem_derrotado(indice: int) -> void:
	var imagem: Sprite2D = selvagens[indice].imagem
	imagem.hide()
	selvagens[indice].resolver(intervalo_respawn)
	recalcular_alvo_pendente = false
	encontro_atual = null
	aproximando = false
	batalha_encerrada = true
	timer_combate.stop()

# Alteração: preserva a inicialização da caça e cria o painel por código.
func _ready() -> void:
	if EstadoJogo.especie_caca == null: return
	configuracao_hunt = preload("res://catalogo_hunts.gd").obter(EstadoJogo.especie_caca.nome)
	if configuracao_hunt.is_empty():
		titulo.text="Configuração da caça inválida."
		return
	CELULA_INICIAL=Vector2i(int(configuracao_hunt["inicio"][0]),int(configuracao_hunt["inicio"][1]))
	PONTOS_RESPAWN.clear()
	for i in range(int(configuracao_hunt["populacao"])):
		var ponto: Array=configuracao_hunt["pontos"][i]
		PONTOS_RESPAWN.append(Vector2i(int(ponto[0]),int(ponto[1])))
	intervalo_respawn=float(configuracao_hunt["respawn"])
	var caminho_cenario: String=str(configuracao_hunt["cenario"])
	if cenario_caca.scene_file_path!=caminho_cenario:
		remove_child(cenario_caca)
		cenario_caca.queue_free()
		cenario_caca=load(caminho_cenario).instantiate()
		cenario_caca.name="CenarioCaca"
		add_child(cenario_caca)
	movimento_selvagens.iniciar(self)
	super._ready()
	if not parametros_navegacao_original.is_empty():
		movimento_selvagens.duracao_passo = float(parametros_navegacao_original["mobStepMs"])/1000.0
	painel_auto_helper = PAINEL_AUTO_HELPER.new()
	painel_auto_helper.mostrar_botao_abrir = false
	painel_auto_helper.name = "PainelAutoHelper"
	get_node("Interface").add_child(painel_auto_helper)

	# Novo: interface permanente e modais separados, como no original.
	var hud: Control = load("res://hud_caca.gd").new()
	hud.name = "HudCaca"
	hud.controlador = self
	get_node("Interface").add_child(hud)

func _ao_iniciar_atividade() -> void:
	if not populacao_iniciada:
		return
	# Também executa na recuperação tardia, depois que o HUD já existe.
	titulo.hide()
	if get_node_or_null("TreinadorCaca") == null:
		var treinador: Node2D = load("res://treinador_caca.gd").new()
		treinador.name = "TreinadorCaca"
		add_child(treinador)
		treinador.iniciar(self)

# Alteração: interpola selvagens antes de mover o aliado.
func _physics_process(delta: float) -> void:
	if not populacao_iniciada or vida_aliado <= 0:
		return
	_avancar_agendas_golpes(delta)
	if usar_golpes_catalogados or usar_atributos_combate:
		for encontro in selvagens:
			if encontro.estado == EncontroSelvagem.Estado.VIVO:
				# Overrides individuais mantêm precisão abaixo de 200 ms.
				if _calibracao_ativa() and encontro.intervalo_ataque<=0:
					encontro.agenda_golpes.avancar_calibrado(delta)
				else:
					encontro.agenda_golpes.avancar(delta)
	movimento_selvagens.atualizar(delta)
	_retomar_combate_proximo()
	# Revisão: esperando o alvo terminar um passo, aguarda o término em vez
	# de executar A* e reiniciar a aproximação a cada frame.
	var esperando_alvo: bool = not aproximando and indice_alvo >= 0 and indice_alvo < selvagens.size() and bool(selvagens[indice_alvo].movendo)
	if recalcular_alvo_pendente and not esperando_alvo:
		var celula: Vector2i = posicao_para_celula(imagem_aliado.global_position)
		if imagem_aliado.global_position.distance_to(celula_para_posicao(celula)) < 0.001:
			_recalcular_percurso_alvo()
	super._physics_process(delta)
	if vida_aliado<=0 or is_queued_for_deletion(): return
	if usar_golpes_catalogados or usar_atributos_combate:
		# Ordem estável em empates: aliado primeiro, depois todos os selvagens elegíveis.
		if not batalha_encerrada and not aproximando and _alvo_em_alcance():
			_executar_golpes_catalogados()
		else:
			_processar_ataques_selvagens()

func _ao_alcancar_celula() -> void:
	if recalcular_alvo_pendente:
		_recalcular_percurso_alvo()

# Novo: recalcular não troca indivíduo, HP, XP nem a identidade do encontro.
func _recalcular_percurso_alvo() -> void:
	recalcular_alvo_pendente = false
	if indice_alvo < 0 or indice_alvo >= selvagens.size() or not bool(selvagens[indice_alvo].ativo):
		return
	timer_combate.stop()
	var origem: Vector2i = posicao_para_celula(imagem_aliado.global_position)
	var destino: Vector2i = selvagens[indice_alvo].celula
	var novo_caminho: Array[Vector2i] = _calcular_caminho_aliado(origem,destino)
	if novo_caminho.is_empty():
		aproximando = false
		encontro_atual = null
		batalha_encerrada = true
		return
	if novo_caminho.size() >= 2:
		var penultima: Vector2i = novo_caminho[novo_caminho.size()-2]
		if celula_para_posicao(penultima).distance_to(celula_para_posicao(destino)) <= alcance_combate:
			novo_caminho.pop_back()
	caminho = novo_caminho
	indice_caminho = 1
	aproximando = true

func _alvo_em_alcance() -> bool:
	if indice_alvo < 0 or indice_alvo >= selvagens.size() or not bool(selvagens[indice_alvo].ativo) or bool(selvagens[indice_alvo].movendo):
		return false
	var origem: Vector2i = posicao_para_celula(imagem_aliado.global_position)
	var destino: Vector2i = selvagens[indice_alvo].celula
	# Checa passagem, não só distância: impede ataques através da parede/quina.
	return (origem == destino or passagem_permitida(origem,destino)) and imagem_aliado.global_position.distance_to(imagem_selvagem.global_position) <= alcance_combate+0.1

func _chegar_ao_selvagem() -> void:
	if not _alvo_em_alcance():
		aproximando = false
		timer_combate.stop()
		recalcular_alvo_pendente = true
		return
	super._chegar_ao_selvagem()

func _on_timer_combate_timeout() -> void:
	if batalha_encerrada or pokemon_selvagem == null:
		return
	if not _alvo_em_alcance():
		timer_combate.stop()
		recalcular_alvo_pendente = true
		return
	super._on_timer_combate_timeout()

# Alteração: reserva origem/destino do passo inteiro, não apenas a célula arredondada.
func obter_reservas_aliado() -> Array[Vector2i]:
	var reservas: Array[Vector2i] = [posicao_para_celula(imagem_aliado.global_position)]
	if aproximando and indice_caminho > 0 and indice_caminho < caminho.size():
		var origem: Vector2i = caminho[indice_caminho-1]
		var destino: Vector2i = caminho[indice_caminho]
		for celula in [origem,destino]:
			if not reservas.has(celula):
				reservas.append(celula)
		var diferenca: Vector2i = destino-origem
		if diferenca.x != 0 and diferenca.y != 0:
			reservas.append(origem+Vector2i(diferenca.x,0))
			reservas.append(origem+Vector2i(0,diferenca.y))
	return reservas

# Alteração: a rota do aliado contorna selvagens e os dois extremos dos passos deles.
func _calcular_caminho_aliado(origem: Vector2i, destino: Vector2i) -> Array[Vector2i]:
	var ocupadas: Dictionary = movimento_selvagens.obter_ocupacao_selvagens()
	# O destino é o alvo; a aproximação termina na célula anterior.
	ocupadas.erase(destino)
	return calcular_caminho(origem,destino,ocupadas)

func _passo_aliado_livre(origem: Vector2i, destino: Vector2i) -> bool:
	if not passagem_permitida(origem,destino):
		return false
	var ocupadas: Dictionary = movimento_selvagens.obter_ocupacao_selvagens()
	var diferenca: Vector2i = destino-origem
	var bloqueado: bool = ocupadas.has(destino)
	if diferenca.x != 0 and diferenca.y != 0:
		bloqueado = bloqueado or ocupadas.has(origem+Vector2i(diferenca.x,0)) or ocupadas.has(origem+Vector2i(0,diferenca.y))
	if bloqueado:
		timer_combate.stop()
		recalcular_alvo_pendente = true
	return not bloqueado

# O alvo do aliado não é uma autorização para o ataque dos inimigos.
func _processar_ataques_selvagens() -> void:
	for registro in selvagens:
		if vida_aliado<=0 or is_queued_for_deletion(): break
		_executar_ataque_selvagem(registro)

# Reage no centro da célula; nunca interrompe um passo na metade.
# A seleção não reinicia HP, identidade ou agendas de nenhum combatente.
func _retomar_combate_proximo() -> void:
	if not reagir_ao_cerco: return
	if vida_aliado<=0: return
	if encontro_atual==null and diagnostico_ofensivo_aliado.get("estado","")=="bloqueado": return
	if encontro_atual!=null and encontro_atual.estado!=EncontroSelvagem.Estado.VIVO: return
	var origem: Vector2i=posicao_para_celula(imagem_aliado.global_position)
	if imagem_aliado.global_position.distance_to(celula_para_posicao(origem))>0.001: return
	# Já está lutando em alcance: a revisão periódica cuida de incompatibilidade.
	# Evita recalcular a força de todos os golpes em cada frame de combate.
	if _selvagem_em_alcance(encontro_atual) and not aproximando and not batalha_encerrada: return
	var candidato: EncontroSelvagem=encontro_atual if _selvagem_em_alcance(encontro_atual) and _pode_ferir(encontro_atual) else null
	if candidato==null:
		for registro in selvagens:
			if _selvagem_em_alcance(registro) and _pode_ferir(registro):
				candidato=registro
				break
	if candidato==null: return
	var retomar: bool=candidato!=encontro_atual or aproximando or batalha_encerrada
	if not retomar: return
	encontro_atual=candidato
	recalcular_alvo_pendente=false
	aproximando=false
	batalha_encerrada=false
	caminho.clear()
	indice_caminho=0
	timer_combate.stop()
	_chegar_ao_selvagem()
