extends Control

var vida_aliado: int
var vida_selvagem: int
var pokemon_selvagem: DadosPokemon
var batalha_encerrada: bool = false
var seletor_bolas: OptionButton

@onready var dados_aliado: Label = get_node("VBoxContainer/DadosAliado")
@onready var dados_selvagem: Label = get_node("VBoxContainer/DadosSelvagem")
@onready var resultado_batalha: Label = get_node("VBoxContainer/ResultadoBatalha")
@onready var dados_colecao: Label = get_node("VBoxContainer/DadosPokemon")

@onready var timer_combate: Timer = get_node("TimerCombate")	
@onready var imagem_selvagem: TextureRect = get_node("VBoxContainer/ImagemSelvagem")
@onready var imagem_aliado: TextureRect = get_node("VBoxContainer/ImagemAliado")
@onready var barra_vida_aliado: ProgressBar = get_node("VBoxContainer/BarraVidaAliado")
@onready var barra_vida_selvagem: ProgressBar = get_node("VBoxContainer/BarraVidaSelvagem")
@onready var botao_capturar: Button = get_node("VBoxContainer/BotaoCapturar")	

var especie_selvagem: DadosEspecie
@export var pokemon_aliado: DadosPokemon

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EstadoJogo.iniciar_depot()
	pokemon_aliado = EstadoJogo.pokemon_inicial
	especie_selvagem = EstadoJogo.especie_caca
	iniciar_batalha()
	atualizar_colecao()

func atualizar_interface() -> void:
	botao_capturar.disabled = not pode_capturar()
	dados_aliado.text = pokemon_aliado.especie.nome + " — Vida: " + str(vida_aliado) + "/" + str(pokemon_aliado.especie.vida_maxima)
	dados_selvagem.text = pokemon_selvagem.especie.nome + " — Vida: " + str(vida_selvagem) + "/" + str(pokemon_selvagem.especie.vida_maxima)
	
	barra_vida_aliado.max_value = pokemon_aliado.especie.vida_maxima
	barra_vida_selvagem.max_value = pokemon_selvagem.especie.vida_maxima
	barra_vida_aliado.value = vida_aliado
	barra_vida_selvagem.value = vida_selvagem
	

func _on_botao_atacar_pressed() -> void:
	atacar()

func atacar() -> void:
	if batalha_encerrada:
		return
	vida_selvagem = vida_selvagem - pokemon_aliado.especie.dano_base
	if vida_selvagem <= 0:	
		vida_selvagem = 0
		encerrar_batalha(pokemon_aliado.especie.nome)
	else:
		vida_aliado = vida_aliado - pokemon_selvagem.especie.dano_base
		if vida_aliado <= 0:
			vida_aliado = 0
			encerrar_batalha(pokemon_selvagem.especie.nome)
	atualizar_interface()

func _on_timer_combate_timeout() -> void:
	atacar()

func encerrar_batalha(vencedor: String) -> void:
	batalha_encerrada = true
	timer_combate.stop()
	resultado_batalha.text = vencedor + " Venceu!"

func _on_botao_reiniciar_pressed() -> void:
	reiniciar_batalha()

func reiniciar_batalha() -> void:
	iniciar_batalha()

func capturar() -> void:
	if not pode_capturar():
		return
	resultado_batalha.text = pokemon_selvagem.especie.nome + " capturado!"
	EstadoJogo.registrar_captura(pokemon_selvagem)
	atualizar_colecao()
	atualizar_interface()

func pode_capturar() -> bool:
	return (
		pokemon_selvagem != null 
		and batalha_encerrada 
		and vida_selvagem <= 0 
		and vida_aliado > 0 
		and not EstadoJogo.pokemons_capturados.has(pokemon_selvagem)
	)

func especie_valida(especie: DadosEspecie) -> bool:
	if especie == null:
		return false
	return (
		not especie.nome.is_empty()
		and especie.vida_maxima > 0
		and especie.dano_base > 0
		and especie.textura != null
	)

func iniciar_batalha() -> void:
	print("=== INICIAR BATALHA ===")
	print("Espécie selecionada no mapa: ", EstadoJogo.especie_caca)
	print("Espécie recebida pela batalha: ", especie_selvagem)
	print("Espécie selvagem válida: ", especie_valida(especie_selvagem))
	print("Aliado atribuído: ", pokemon_aliado != null)

	if pokemon_aliado != null:
		print("Espécie do aliado válida: ", especie_valida(pokemon_aliado.especie))
	timer_combate.stop()
	if (
		especie_valida(especie_selvagem)
		and pokemon_aliado != null
		and especie_valida(pokemon_aliado.especie)
	):
		pokemon_selvagem = DadosPokemon.new()
		pokemon_selvagem.especie = especie_selvagem
		pokemon_selvagem.sortear_ivs()
		pokemon_selvagem.sortear_qualidade()
		
		vida_selvagem = pokemon_selvagem.especie.vida_maxima
		imagem_selvagem.texture = pokemon_selvagem.especie.textura
		
		vida_aliado = pokemon_aliado.especie.vida_maxima
		imagem_aliado.texture = pokemon_aliado.especie.textura
		
		batalha_encerrada = false	
		resultado_batalha.text = ""
		atualizar_interface()
		timer_combate.start()
	else:
		batalha_encerrada = true
		pokemon_selvagem = null
		botao_capturar.disabled = true
		resultado_batalha.text = "Não foi possível iniciar: ficha de espécie inválida"

func atualizar_colecao() -> void:
	dados_colecao.text = "Pokemons Capturados: " + str(EstadoJogo.pokemons_capturados.size()) 
	for pokemons_capturado in EstadoJogo.pokemons_capturados:
		dados_colecao.text += (
			"\n" + pokemons_capturado.especie.nome
			+ " — Nível: " + str(pokemons_capturado.nivel)
			+ " — IVs: " + str(pokemons_capturado.obter_total_ivs()) + "/192"
			+ " — Quality: " + str(pokemons_capturado.qualidade)
			+ " — " + pokemons_capturado.obter_classificacao()
		)
	


func _on_botao_voltar_cidade_pressed() -> void:
	get_tree().change_scene_to_file("res://cidade.tscn")
