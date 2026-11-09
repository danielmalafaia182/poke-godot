extends "res://caca.gd"
# Fixture de cenário: usa todo o combate de caca.gd; só prepara os participantes.
var caso_laboratorio: String="cerco"
var perfis_referencia_ids: Dictionary[int,String]={}
func _iniciar_populacao() -> void:
	if caso_laboratorio=="cerco3":
		if not _posicionar_cerco_controlado():return
	elif caso_laboratorio!="cerco":
		movimento_selvagens_habilitado=false
		var pontos: Array[Vector2i]=[]
		for dir in DIRECOES:
			var destino: Vector2i=CELULA_INICIAL+dir
			if passagem_permitida(CELULA_INICIAL,destino):pontos.append(destino);break
		PONTOS_RESPAWN=pontos
	super._iniciar_populacao()
func _criar_individuo(indice: int,celula: Vector2i) -> void:
	super._criar_individuo(indice,celula)
	if caso_laboratorio=="cerco" or indice>=selvagens.size():return
	var p: DadosPokemon=DadosPokemon.new();p.especie=EstadoJogo.especie_caca;p.nivel=80;p.versao_atributos=1
	p.iv_sp_atk=16;p.iv_sp_def=16;p.iv_spd=16
	if caso_laboratorio in ["referencia3780","cerco3"]:
		p.qualidade=1.247;p.iv_hp=15;p.iv_def=18;p.iv_atk=32
	else:
		p.qualidade=0.946;p.iv_hp=32;p.iv_def=23;p.iv_atk=7
	if not perfis_referencia_ids.has(indice):
		perfis_referencia_ids[indice]=Crypto.new().generate_random_bytes(16).hex_encode()
	var perfil_referencia_id: String=perfis_referencia_ids[indice]
	var e: EncontroSelvagem=selvagens[indice]
	e.pokemon=p.duplicate(false)
	e.definir_perfil_combate(p,perfil_referencia_id)
	perfis_combate_slots[indice]={"pokemon":p.duplicate(false),"id":perfil_referencia_id}
	e.vida_maxima=_calcular_vida_maxima_selvagem(p);e.vida=e.vida_maxima
	_registrar_perfil_hp(e)
	var indicador: Node=e.imagem.get_node_or_null("IndicadorSelvagem")
	if indicador!=null:indicador.configurar(self,e)
func _on_botao_voltar_cidade_pressed() -> void:
	get_parent().call_deferred("reiniciar",caso_laboratorio)

# Apenas montagem do cenário: sem override de ataque, relógio ou fórmula.
func _posicionar_cerco_controlado() -> bool:
	movimento_selvagens_habilitado=false
	var centros: Array[Vector2i]=[CELULA_INICIAL]
	centros.append_array(celulas_acessiveis)
	for centro in centros:
		var pontos: Array[Vector2i]=[]
		for direcao in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var vizinha: Vector2i=centro+direcao
			if passagem_permitida(centro,vizinha) and celula_para_posicao(centro).distance_to(celula_para_posicao(vizinha))<=alcance_combate:
				pontos.append(vizinha)
		if pontos.size()<3:continue
		CELULA_INICIAL=centro
		imagem_aliado.global_position=celula_para_posicao(centro)
		PONTOS_RESPAWN.assign(pontos.slice(0,3))
		return true
	push_error("O laboratório não encontrou três posições transitáveis em alcance.")
	return false

func trocar_alvo_laboratorio() -> void:
	if caso_laboratorio!="cerco3" or vida_aliado<=0:return
	var anterior: int=indice_alvo
	for passo in range(1,selvagens.size()+1):
		var indice: int=(anterior+passo)%selvagens.size()
		if not _selvagem_em_alcance(selvagens[indice]):continue
		encontro_atual=selvagens[indice]
		aproximando=false
		batalha_encerrada=false
		recalcular_alvo_pendente=false
		caminho.clear()
		indice_caminho=0
		atualizar_interface()
		return
