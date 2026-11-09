extends Node
const PERFIL: String="PokeIdle_Lab_Combate_20261108"
static var caso_atual: String="cerco3"
static var ultimo_exportado: String=""
var caca: Node
var status: Label
var iniciado: bool=false
static func caminho_seguro(caminho: String) -> bool:
	var nome: String=caminho.replace("\\","/").trim_suffix("/").get_file()
	return nome==PERFIL or nome.begins_with("PokeIdle_QA_")
static func referencia(nome: String,nivel: int,ivs: Array[int]) -> DadosPokemon:
	var p: DadosPokemon=DadosPokemon.new();p.especie=preload("res://especies_importadas.gd").obter_especies()[nome]
	p.nivel=nivel;p.qualidade=1.8;p.versao_atributos=1
	var campos: Array[String]=["iv_hp","iv_atk","iv_def","iv_sp_atk","iv_sp_def","iv_spd"]
	for i in range(6):p.set(campos[i],ivs[i])
	p.id_persistente=Crypto.new().generate_random_bytes(16).hex_encode()
	p.sincronizar_experiencia();p.vida_atual=p.obter_vida_maxima()
	return p
func _ready() -> void:
	# Se os scripts forem copiados para o projeto real por engano, recusa as fixtures.
	if not caminho_seguro(OS.get_user_data_dir()):
		var aviso: Label=Label.new();aviso.text="Abra o project.godot da pasta laboratorio_validacao.\nEste perfil não é do laboratório; os Pokémon não foram substituídos.";aviso.position=Vector2(30,60);add_child(aviso);return
	var gya: DadosPokemon=referencia("Gyarados",214,[23,32,23,24,23,29])
	var exg: DadosPokemon=referencia("Exeggutor",406,[27,29,20,30,30,2])
	EstadoJogo.validador_troca_lider=Callable();EstadoJogo.prazo_troca_hunt_ms=0
	var inicial: DadosPokemon=(load("res://dados/pokemons/larvitar_inicial.tres") as DadosPokemon).duplicate(false)
	inicial.id_persistente=Crypto.new().generate_random_bytes(16).hex_encode();inicial.normalizar_atributos();inicial.vida_atual=inicial.obter_vida_maxima()
	EstadoJogo.time_pokemon.assign([gya,exg,inicial]);EstadoJogo.pokemons_capturados.clear()
	EstadoJogo.pokemon_inicial=inicial;EstadoJogo.pokemon_lider=gya
	EstadoJogo.nome_treinador="Laboratório"
	EstadoJogo.especie_caca=preload("res://especies_importadas.gd").obter_especies()["Blastoise"]
	EstadoJogo.auto_catch=false
	EstadoJogo.auto_potion=true;EstadoJogo.auto_potion_item_id=203;EstadoJogo.auto_potion_threshold=50
	for item in EstadoJogo.CATALOGO_POCOES:EstadoJogo.estoque_pocoes[int(item["id"])]=9999
	for item in EstadoJogo.CATALOGO_BOLAS:EstadoJogo.estoque_bolas[int(item["id"])]=9999
	caca=preload("res://caca_laboratorio.tscn").instantiate();caca.caso_laboratorio=caso_atual;add_child(caca)
	caca.botao_voltar_cidade.text="Reiniciar laboratório"
	criar_barra()
	caca.registro_combate.comecar()
	caca.registro_combate._adicionar("laboratorio",{"cenario":caso_atual,"perfil_dados_separado":true,"fixture_aliados":"Gyarados214_Exeggutor406","exemplos_selvagens_ajustados":caso_atual!="cerco","cerco_controlado":caso_atual=="cerco3","selvagens_posicionados":caca.selvagens.size(),"formula_original_comprovada":false})
	iniciado=true
func criar_barra() -> void:
	var camada: CanvasLayer=CanvasLayer.new();camada.layer=220;add_child(camada)
	var painel: PanelContainer=PanelContainer.new();painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	painel.offset_left=240;painel.offset_right=-16;painel.offset_top=-142;painel.offset_bottom=-12;camada.add_child(painel)
	var margem: MarginContainer=MarginContainer.new()
	for lado in ["left","top","right","bottom"]:margem.add_theme_constant_override("margin_"+lado,8)
	painel.add_child(margem)
	var coluna: VBoxContainer=VBoxContainer.new();margem.add_child(coluna)
	var titulo: Label=Label.new();titulo.text="LABORATÓRIO · time de referência pronto · dados separados do seu jogo";titulo.add_theme_font_size_override("font_size",14);coluna.add_child(titulo)
	var linha: HBoxContainer=HBoxContainer.new();coluna.add_child(linha)
	for par in [["Cerco · 3 juntos","cerco3"],["Duelo · 3780 HP","referencia3780"],["Duelo · 3815 HP","referencia3815"],["População · 15","cerco"]]:
		var b: Button=Button.new();b.text=par[0];b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.pressed.connect(reiniciar.bind(str(par[1])));linha.add_child(b)
	var acoes: HBoxContainer=HBoxContainer.new();coluna.add_child(acoes)
	var alvo: Button=Button.new();alvo.text="Trocar alvo";alvo.disabled=caso_atual!="cerco3";alvo.pressed.connect(caca.trocar_alvo_laboratorio);acoes.add_child(alvo)
	var exportar: Button=Button.new();exportar.text="Exportar JSONL";exportar.pressed.connect(exportar_registro);acoes.add_child(exportar)
	var pasta: Button=Button.new();pasta.text="Abrir pasta";pasta.pressed.connect(func() -> void:OS.shell_open(ProjectSettings.globalize_path("user://diagnosticos_combate")));acoes.add_child(pasta)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",12);coluna.add_child(status)
	status.text="Cerco: 3 Blastoise em alcance, cada um com agenda própria. Trocar alvo preserva os relógios." if caso_atual=="cerco3" else "Registro automático ativo. Troque de Pokémon nos retratos. Reiniciar restaura o time de teste."
func exportar_registro() -> void:
	if caca==null:return
	ultimo_exportado=caca.registro_combate.encerrar()
	status.text="Exportado: "+ultimo_exportado if not ultimo_exportado.is_empty() else "Falha ao exportar; tente novamente."
func reiniciar(caso: String="cerco3") -> void:
	if not caminho_seguro(OS.get_user_data_dir()):return
	if caca!=null and caca.registro_combate.ativo:exportar_registro()
	caso_atual=caso
	get_tree().reload_current_scene()
