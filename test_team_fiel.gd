extends SceneTree
const VISUAL: Script = preload("res://visual_pokemon.gd")
const TIPOS: Script = preload("res://tipos_pokemon.gd")
const ESTILO: Script = preload("res://estilo_team.gd")
var falhas: int = 0
var verificacoes: int = 0
func _initialize() -> void:
	call_deferred("executar")
func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		push_error(texto)
func quadros() -> void:
	for i in range(5):
		await process_frame
func clicar(p: Vector2) -> void:
	var movimento: InputEventMouseMotion = InputEventMouseMotion.new()
	movimento.position = p
	movimento.global_position = p
	root.push_input(movimento,true)
	for pressionado in [true,false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressionado
		root.push_input(e,true)
	await quadros()
func executar() -> void:
	root.size = Vector2i(1920,1080)
	var estado: Node = root.get_node("EstadoJogo")
	var inicial: DadosPokemon = estado.pokemon_inicial
	var extra: DadosPokemon = DadosPokemon.new()
	extra.especie = load("res://dados/especies/geodude.tres")
	estado.registrar_captura(extra)
	estado.forcar_cidade="cerulean" # fase 4: o depot é da cidade
	estado.mover_pokemon_depot(extra,false)
	# Verifica os recortes reais dos spritesheets, não apenas a enumeração da direção.
	for nome: String in ["Larvitar","Geodude"]:
		var dados: Dictionary = VISUAL.obter(nome)
		var n: int = int(dados["quadros"])
		var frente: Array[Texture2D] = VISUAL.quadros_frente(nome)
		checar(frente.size()==n,"todos os quadros frontais de "+nome)
		for i in range(n):
			var atlas: AtlasTexture = frente[i] as AtlasTexture
			var inicio: float = 2+(n*2+i)*int(dados["passo"])
			checar(atlas!=null and atlas.region.position.x>=inicio and atlas.region.end.x<=inicio+int(dados["tamanho"]),"região sul correta "+nome+str(i))
			checar(atlas.get_image().get_used_rect().has_area(),"quadro frontal não vazio")
		checar(VISUAL.retrato_frente(nome)==frente[0] and VISUAL.retrato_frente(nome)==VISUAL.retrato_frente(nome),"retrato frontal em cache")
	checar(TIPOS.cor("WATER")==Color("4d90d5") and TIPOS.cor("water")==Color("4d90d5"),"água azul da paleta original")
	checar(TIPOS.cor("GROUND")==Color("d97845") and TIPOS.cor("ROCK")==Color("c7b78b"),"Terra e Pedra separadas")
	var cores: Dictionary = {}
	for tipo in TIPOS.CORES:
		cores[TIPOS.cor(tipo).to_html()] = true
		checar(TIPOS.icone(tipo)!=null and TIPOS.icone(tipo).get_image().get_used_rect().has_area(),"ícone real "+tipo)
		if FileAccess.file_exists("res://assets/interface/elementos/"+str(tipo).to_lower()+".png"):
			checar(TIPOS.elemento(tipo)!=null and TIPOS.elemento(tipo).get_image().get_used_rect().has_area(),"elemento real "+tipo)
		else:
			checar(TIPOS.elemento(tipo)==null,"marca ausente não troca o tipo "+tipo)
	checar(cores.size()==18,"18 tipos com cores distintas")
	checar(TIPOS.icone("WATER")!=TIPOS.icone("GROUND") and TIPOS.icone("GROUND")!=TIPOS.icone("ROCK"),"símbolos distintos")
	var cidade: Control = load("res://cidade.tscn").instantiate()
	root.add_child(cidade)
	await quadros()
	cidade.set_process(false)
	var painel: Control = cidade.painel_my_pokes
	var hud: PanelContainer = cidade.painel_time
	checar(hud.cartoes[inicial].retrato.texture==VISUAL.retrato_frente("Larvitar"),"HUD frontal Larvitar")
	checar(hud.cartoes[extra].retrato.texture==VISUAL.retrato_frente("Geodude"),"HUD frontal Geodude")
	checar(hud.cartoes[inicial].icone_tipo.texture==TIPOS.icone("ROCK"),"HUD usa ícone do tipo primário real")
	var menu: Control = cidade.get_node("Interface/MenuSuperior")
	var snapshot_bolas: Dictionary = estado.estoque_bolas.duplicate()
	var snapshot_pocoes: Dictionary = estado.estoque_pocoes.duplicate()
	var xp: int = inicial.experiencia_total
	await clicar(menu.botoes["pokemon"].get_global_rect().get_center())
	checar(painel.visible and painel.slots.size()==6,"menu abre TEAM com seis slots")
	checar(painel.janela.size==Vector2(533,620),"medidas da janela desktop")
	checar(not painel._rolagem.get_v_scroll_bar().visible,"desktop sem rolagem desnecessária")
	checar(painel.selecionado==inicial and painel.invocar.disabled,"abre no líder ativo")
	checar(painel.slots[2].disabled and painel.slots[5].disabled,"slots vazios desativados")
	checar(painel._retratos_slots[0].texture==VISUAL.retrato_frente("Larvitar"),"slot frontal")
	checar(painel.retrato_grande.size.y<84,"ficha mantém escala do outfit")
	checar(painel.textos_tipos[0].text=="ROCK" and painel.textos_tipos[1].text=="GROUND","selos correspondem ao indivíduo")
	checar(painel._elemento.texture==TIPOS.elemento("ROCK"),"marca d'água do tipo correto")
	checar(painel.evoluir.disabled,"evolução indisponível continua bloqueada")
	var id_barra: int = painel.barra_hp.get_instance_id()
	var id_retrato: int = painel.retrato_grande.get_instance_id()
	var id_slot: int = painel.slots[0].get_instance_id()
	for i in range(20):
		estado.registrar_vida_pokemon(inicial,1+i%10)
		estado.conceder_experiencia(inicial,1)
	checar(painel.barra_hp.get_instance_id()==id_barra and painel.retrato_grande.get_instance_id()==id_retrato and painel.slots[0].get_instance_id()==id_slot,"HP/XP não reconstroem a ficha")
	checar(painel.barra_hp.value==inicial.obter_vida_atual() and painel.barra_xp.value==inicial.experiencia_percentual,"barras leem o estado verdadeiro")
	checar(inicial.experiencia_total==xp+20,"visual não concede XP extra")
	var maximo: float = maxf(1,float(inicial.obter_atributos().values().max()))
	for i in range(6):
		var valor: int = int(inicial.obter_atributos()[painel.CHAVES[i]])
		checar(painel.valores_atributos[i].text==str(valor) and painel.barras_atributos[i].max_value==maximo,"atributo individual "+str(i))
	checar(ESTILO.cor_atributo(30.0/32.0)==Color("23cd5e") and ESTILO.cor_atributo(31.0/32.0)==Color("00c2b8"),"cores HP/Vel conforme exemplo original")
	await clicar(painel.slots[1].get_global_rect().get_center())
	checar(painel.selecionado==extra and estado.obter_lider()==inicial,"consultar outro slot preserva líder")
	checar(painel.nome_pokemon.text=="Geodude" and not painel.invocar.disabled,"ficha do segundo membro")
	painel.permitir_troca_lider = false
	painel.atualizar()
	checar(painel.invocar.disabled,"caça mantém bloqueio de troca")
	await clicar(painel.invocar.get_global_rect().get_center())
	checar(estado.obter_lider()==inicial,"botão bloqueado não invoca")
	painel.permitir_troca_lider = true
	painel.atualizar()
	await clicar(painel.invocar.get_global_rect().get_center())
	checar(estado.obter_lider()==extra and painel.invocar.disabled,"invocação explícita funciona na cidade")
	checar(estado.estoque_bolas==snapshot_bolas and estado.estoque_pocoes==snapshot_pocoes,"consultar e invocar não consomem itens")
	checar(painel.slots[0].get_instance_id()==id_slot,"troca de líder preserva slots")
	# Selecionado saiu do TEAM pelo depot: a ficha deve retornar ao líder válido.
	estado.mover_pokemon_depot(extra,true)
	checar(painel.selecionado==inicial and painel.slots[1].disabled,"remoção do selecionado não deixa ficha antiga")
	for resolucao: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1152,648),Vector2i(800,450)]:
		root.size = resolucao
		await quadros()
		var r: Rect2 = painel.janela.get_global_rect()
		checar(r.position.x>=0 and r.position.y>=0 and r.end.x<=resolucao.x and r.end.y<=resolucao.y,"TEAM cabe em "+str(resolucao))
	checar(painel._rolagem.get_v_scroll_bar().visible,"janela baixa permite rolar o corpo")
	root.size = Vector2i(1920,1080)
	await quadros()
	var tecla: InputEventKey = InputEventKey.new()
	tecla.keycode = KEY_ESCAPE
	tecla.pressed = true
	root.push_input(tecla,true)
	await quadros()
	checar(not painel.visible,"Esc fecha TEAM")
	painel.abrir()
	await quadros()
	await clicar(Vector2(30,30))
	checar(not painel.visible and not hud.perfil.visible,"clique fora fecha sem atravessar para perfil")
	painel.abrir()
	await quadros()
	var fechar: Button = painel.find_child("FecharTeam",true,false) as Button
	await clicar(fechar.get_global_rect().get_center())
	checar(not painel.visible,"X fecha TEAM")
	checar(estado.salvar_agora(),"estado permanece salvável")
	cidade.queue_free()
	await process_frame
	print("TEAM FIEL: ",verificacoes," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
