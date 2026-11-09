extends SceneTree
const A=preload("res://agenda_golpes.gd")
var checks: int=0
var falhas: int=0
var c: Node2D
var estado: Node
var especies: Dictionary
var parceiros: Dictionary={}
var eventos: Array[Dictionary]=[]
var avisos: Array[Dictionary]=[]
var instante: int=100000

func _initialize() -> void: call_deferred("executar")
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: falhas+=1;push_error(msg)
func pokemon(nome: String, nivel: int=1) -> DadosPokemon:
	var p: DadosPokemon=DadosPokemon.new()
	p.especie=especies[nome];p.nivel=nivel;p.normalizar_atributos();p.vida_atual=p.obter_vida_maxima()
	return p
func preparar(aliado: String, inimigos: Array[String], celulas: Array[Vector2i]=[]) -> void:
	for p in parceiros.values(): p.nivel=1;p.vida_atual=p.obter_vida_maxima()
	c.pokemon_aliado=parceiros[aliado];estado.pokemon_lider=c.pokemon_aliado
	estado.prazo_troca_hunt_ms=0
	c.agenda_aliado=A.new();c.agenda_aliado.configurar(aliado,1)
	c.agendas_aliados.clear();c.agendas_aliados[c.pokemon_aliado]=c.agenda_aliado
	c.encontro_atual=null;c.aproximando=false;c.batalha_encerrada=true
	c.caminho.clear();c.indice_caminho=0;c.recalcular_alvo_pendente=false
	c._tempo_revisao_ofensiva=0;c.timer_combate.stop();c.timer_auto_potion.stop()
	c.movimento_selvagens_habilitado=false;c.reagir_ao_cerco=true
	c.celulas_existentes.clear();c.celulas_bloqueadas.clear();c.limitar_area_caca=false
	for x in range(-6,8):
		for y in range(-6,7): c.celulas_existentes[Vector2i(x,y)]=true
	c.imagem_aliado.global_position=c.celula_para_posicao(Vector2i.ZERO)
	for i in range(c.selvagens.size()):
		var celula: Vector2i=celulas[i] if i<celulas.size() else Vector2i(i+1,0)
		var sprite: Sprite2D=c.selvagens[i].imagem
		var p: DadosPokemon=pokemon(inimigos[i] if i<inimigos.size() else "Geodude")
		var r: EncontroSelvagem=EncontroSelvagem.new(i,p,sprite,celula,1000)
		sprite.global_position=c.celula_para_posicao(celula);c.selvagens[i]=r
		if i>=inimigos.size(): r.resolver(1000.0)
	eventos.clear();avisos.clear()

func executar() -> void:
	especies=preload("res://especies_importadas.gd").obter_especies()
	# Agenda: diagnóstico e execução compartilham os mesmos critérios.
	var ag: RefCounted=A.new()
	var um: Callable=func(_g: Dictionary) -> float: return 10.0
	var neutro: Callable=func(_g: Dictionary) -> float: return 1.0
	ag.configurar("Magikarp",1)
	check(ag.diagnosticar_calibrado(um)["motivo"]=="sem_golpe_catalogado","catalogo vazio não inventa Splash/Struggle")
	ag.configurar("Geodude",0)
	check(ag.diagnosticar_calibrado(um)["motivo"]=="sem_golpe_no_nivel","learnset existente mas indisponível no nível")
	var ataque: Dictionary={"name":"Teste","type":"NORMAL","category":"PHYSICAL","power":50,"cooldownMs":5000}
	var status: Dictionary={"name":"Hypnosis","type":"PSYCHIC","category":"STATUS","power":0,"cooldownMs":5000}
	ag=A.new();ag.golpes.assign([status])
	check(ag.diagnosticar_calibrado(um)["motivo"]=="somente_status","somente status tem motivo explícito")
	check(ag.retirar_calibrado(1.5,um).is_empty() and ag.proximo_ataque_rapido==0.0,"status não consome ataque nem causa dano")
	var tm: Dictionary=ataque.duplicate();tm["tm"]=42
	ag.golpes.assign([tm])
	check(ag.diagnosticar_calibrado(um)["motivo"]=="habilidades_indisponiveis","TM listada não equivale a aprendida")
	ag.golpes.assign([ataque,status])
	var imune: Callable=func(_g: Dictionary) -> float: return 0.0
	check(ag.diagnosticar_calibrado(um,false,imune)["motivo"]=="todos_imunes","imunidade diagnosticada mesmo havendo status")
	ag.proximo_ataque_rapido=50.0
	check(ag.diagnosticar_calibrado(um,false,imune)["motivo"]=="todos_imunes","cooldown não mascara bloqueio permanente")
	check(ag.diagnosticar_calibrado(um,false,neutro)["estado"]=="aguardando_cooldown","positivo futuro aguarda sem retarget")
	check(ag.diagnosticar_calibrado(um,false,neutro)["proxima_liberacao"]==50.0,"prazo de liberação consultável")
	check(ag.tempo==0.0 and ag.proximo_ataque_rapido==50.0 and ag.proximos_usos.is_empty(),"consultas não executam ou alteram relógios")
	ag.proximo_ataque_rapido=0.0;ag.proximos_usos["Teste"]=10.0
	check(ag.diagnosticar_calibrado(um,true,neutro)["estado"]=="aguardando_cooldown","habilidade temporariamente indisponível espera")
	check(ag.diagnosticar_calibrado(um,false,neutro)["estado"]=="pronto","cooldown de habilidade não bloqueia automático")
	ag.proximos_usos["Teste"]=INF
	check(ag.diagnosticar_calibrado(um,true,neutro)["motivo"]=="dados_invalidos","cooldown infinito não gera espera opaca")
	var invalido: Callable=func(_g: Dictionary) -> float:return NAN
	check(ag.diagnosticar_calibrado(invalido)["motivo"]=="dados_invalidos","NaN diagnosticado")
	check(ag.diagnosticar_calibrado(imune,false,neutro)["motivo"]=="sem_dano_positivo","zero não elemental é distinguido de imunidade")
	check(ag.diagnosticar_calibrado(Callable())["motivo"]=="avaliador_indisponivel","avaliador ausente é explícito")
	# Cena real e HUD: líder Gastly Lv1, alvo Rattata; nenhum dano inventado.
	estado=root.get_node("EstadoJogo")
	for i in range(5): await process_frame
	estado.especie_caca=load("res://dados/especies/geodude.tres")
	estado.auto_potion=false;estado.auto_catch=false;estado.curar_time()
	for nome in ["Gastly","Bulbasaur","Geodude"]:
		var p: DadosPokemon=pokemon(nome);parceiros[nome]=p;estado.time_pokemon.append(p)
	estado.pokemon_lider=parceiros["Gastly"]
	c=load("res://Caca.tscn").instantiate();root.add_child(c)
	c.set_process(false);c.set_physics_process(false)
	c.relogio_troca=func()->int:return instante
	c.golpe_executado.connect(func(e: Dictionary)->void:eventos.append(e))
	c.ofensiva_aliado_alterada.connect(func(e: Dictionary)->void:avisos.append(e))
	var hud: Control=c.get_node("Interface/HudCaca")
	preparar("Gastly",["Rattata"])
	var r: EncontroSelvagem=c.selvagens[0]
	var id: String=r.id;var hp: int=r.vida;var vida: int=c.vida_aliado
	var sorteio: int=c.rng_dano.state
	var xp: int=c.pokemon_aliado.experiencia_total
	var capturas: int=estado.pokemons_capturados.size()
	var bolas: int=estado.obter_quantidade_bola(1)
	c._selecionar_alvo()
	check(c.indice_alvo==-1 and c.diagnostico_ofensivo_aliado["motivo"]=="todos_imunes","Gastly Lv1 x Rattata sai da seleção impossível")
	check(hud.aviso_ofensivo.visible and not hud.texto_aviso_ofensivo.text.is_empty(),"jogador vê motivo sem abrir depurador")
	for i in range(50): c._process(0.2);c._physics_process(0.2)
	check(c.indice_alvo==-1 and c.pokemon_aliado==parceiros["Gastly"],"não força troca de aliado por incompatibilidade")
	check(r.id==id and r.vida==hp and c.vida_aliado==vida,"imunidade recíproca preserva HP e identidade")
	check(eventos.is_empty() and c.rng_dano.state==sorteio,"sem ataques falsos ou consumo de RNG")
	check(avisos.size()==1,"espera estável não emite aviso por frame")
	check(r.diagnostico_ofensivo.get("motivo")=="todos_imunes","selvagem também expõe razão de não atacar")
	check(c.pokemon_aliado.experiencia_total==xp and estado.pokemons_capturados.size()==capturas and estado.obter_quantidade_bola(1)==bolas,"bloqueio não concede XP/captura nem consome bola")
	# Logs exportados contêm estado agregado e motivo por selvagem.
	var foto: Dictionary=c.registro_combate._estado()
	check(foto["diagnostico_ofensivo_aliado"]["motivo"]=="todos_imunes" and foto["selvagens"][0]["diagnostico_ofensivo"]["motivo"]=="todos_imunes","snapshot diagnóstico identifica os dois lados")
	c.registro_combate.comecar()
	var arquivo: String=c.registro_combate.encerrar()
	check(not arquivo.is_empty() and FileAccess.get_file_as_string(arquivo).contains("diagnostico_ofensivo_aliado"),"exportação JSONL inclui diagnóstico real")
	# Alvo próximo imune não esconde outro mais distante que pode sofrer dano.
	preparar("Gastly",["Rattata","Geodude"],[Vector2i(1,0),Vector2i(4,0)])
	var compativel: EncontroSelvagem=c.selvagens[1]
	sorteio=c.rng_dano.state
	c._selecionar_alvo()
	check(c.encontro_atual==compativel,"seleciona alvo compatível alcançável, preservando distância como critério")
	c._retomar_combate_proximo()
	check(c.encontro_atual==compativel,"cerco não puxa de volta o alvo imune")
	check(c.rng_dano.state==sorteio,"comparar candidatos não sorteia dano")
	# Se a compatibilidade mudar durante combate, troca alvo sem reiniciar agenda.
	c.encontro_atual=c.selvagens[0];c.aproximando=false;c.batalha_encerrada=false
	c.agenda_aliado.proximo_ataque_rapido=37.0
	c._process(0.2)
	check(c.encontro_atual==compativel and c.agenda_aliado.proximo_ataque_rapido==37.0,"abandono do alvo inviável preserva cooldown")
	check(not hud.aviso_ofensivo.visible,"aviso some ao encontrar saída ofensiva")
	# Falta de rota para compatível não é diagnosticada como imunidade total.
	preparar("Gastly",["Rattata","Geodude"],[Vector2i(1,0),Vector2i(4,0)])
	c.celulas_existentes.clear()
	for x in range(5): c.celulas_existentes[Vector2i(x,0)]=true
	c._selecionar_alvo()
	check(c.indice_alvo==-1 and c.diagnostico_ofensivo_aliado["motivo"]=="sem_rota_para_alvo_compativel","compatível bloqueado tem espera específica")
	c.selvagens[0].celula=Vector2i(99,99)
	c._process(0.2)
	check(c.encontro_atual==c.selvagens[1],"saída de bloqueador permite retomar")
	# Mudança no meio do passo não cancela reserva nem teleporta.
	preparar("Gastly",["Rattata","Geodude"],[Vector2i(4,0),Vector2i(5,1)])
	c.encontro_atual=c.selvagens[0];c.aproximando=true;c.batalha_encerrada=false
	c.caminho.assign([Vector2i.ZERO,Vector2i(1,0),Vector2i(2,0)]);c.indice_caminho=1
	c.imagem_aliado.global_position=c.celula_para_posicao(Vector2i.ZERO)+Vector2(12,0)
	var pos: Vector2=c.imagem_aliado.global_position
	c._process(0.2)
	check(c.encontro_atual==c.selvagens[0] and c.aproximando and c.imagem_aliado.global_position==pos and c.indice_caminho==1,"não interrompe passo em andamento")
	c.imagem_aliado.global_position=c.celula_para_posicao(Vector2i(1,0));c.indice_caminho=2
	c._process(0.2)
	check(c.encontro_atual==c.selvagens[1],"retarget ocorre no centro seguro seguinte")
	# Cooldown temporário mantém alvo e agenda; não vira bloqueio de hunt.
	preparar("Bulbasaur",["Geodude"])
	c._selecionar_alvo();r=c.encontro_atual
	c.agenda_aliado.proximo_ataque_rapido=10.0
	for i in range(5): c._process(0.2)
	check(c.encontro_atual==r and c.diagnostico_ofensivo_aliado["estado"]=="aguardando_cooldown","espera temporária mantém alvo")
	check(c.agenda_aliado.proximo_ataque_rapido==10.0 and not hud.aviso_ofensivo.visible,"nenhum cooldown reiniciado por diagnóstico")
	c.encontro_atual=null;c.aproximando=false;c.batalha_encerrada=true;c._tempo_revisao_ofensiva=0.19
	c._process(0.001)
	check(c.encontro_atual==r,"seleção normal não ganha atraso de 200 ms após KO")
	# Troca manual recupera sem burlar bloqueio de cinco segundos.
	preparar("Gastly",["Rattata"]);c._selecionar_alvo()
	estado.prazo_troca_hunt_ms=instante+5000
	check(not estado.selecionar_lider(parceiros["Bulbasaur"]),"troca para sair de imunidade respeita cooldown")
	instante+=4999
	check(not estado.selecionar_lider(parceiros["Bulbasaur"]),"bloqueada aos 4,999 s")
	instante+=1
	check(estado.selecionar_lider(parceiros["Bulbasaur"]),"permitida aos cinco segundos")
	c._process(0.2)
	check(c.encontro_atual==c.selvagens[0] and not hud.aviso_ofensivo.visible,"novo aliado recupera caça sem recriar população")
	hp=c.selvagens[0].vida;c._physics_process(0.0)
	check(c.selvagens[0].vida<hp and eventos.any(func(e: Dictionary)->bool:return e["aliado"]),"combate produz dano real após troca")
	# Aprender golpe pelo nível recupera sem troca e sem zerar a agenda.
	preparar("Geodude",["Gastly"]);c._selecionar_alvo()
	check(c.diagnostico_ofensivo_aliado["motivo"]=="todos_imunes","Geodude Lv1 não fura Ghost com Tackle")
	c.agenda_aliado.proximo_ataque_rapido=12.0
	c.pokemon_aliado.nivel=16;c._process(0.2)
	check(c.encontro_atual==c.selvagens[0] and c.agenda_aliado.proximo_ataque_rapido==12.0,"nível libera Rock Throw sem apagar cooldown")
	# Learnset vazio na cena tem aviso, sem inserir fallback ofensivo.
	preparar("Gastly",["Geodude"]);c.agenda_aliado.golpes.clear();c._selecionar_alvo()
	check(c.diagnostico_ofensivo_aliado["motivo"]=="sem_golpe_no_nivel" and hud.aviso_ofensivo.visible,"catálogo vazio gera aviso na cena")
	# Inimigos continuam atacando enquanto o aliado não consegue causar dano.
	preparar("Gastly",["Bulbasaur"]);c.agenda_aliado.golpes.assign([status]);c._selecionar_alvo()
	check(c.diagnostico_ofensivo_aliado["motivo"]=="somente_status", "somente status também é diagnosticado na cena")
	vida=c.vida_aliado;var lider_sem_golpes: DadosPokemon=c.pokemon_aliado
	c._physics_process(0.0)
	check(lider_sem_golpes.obter_vida_atual()<vida and eventos.any(func(e: Dictionary)->bool:return not e["aliado"]),"bloqueio ofensivo não congela inimigo nem protege aliado")
	# Nenhum vivo aguarda respawn; depois reavalia a nova identidade.
	preparar("Gastly",[]);c._selecionar_alvo()
	check(c.diagnostico_ofensivo_aliado["estado"]=="aguardando_respawn","sem inimigos vivos não é erro de learnset")
	c.selvagens[0]=EncontroSelvagem.new(0,pokemon("Geodude"),c.selvagens[0].imagem,Vector2i(1,0),100)
	c.selvagens[0].imagem.global_position=c.celula_para_posicao(Vector2i(1,0));c._process(0.2)
	check(c.encontro_atual==c.selvagens[0],"novo encontro é reconsiderado, sem blacklist permanente")
	c.free()
	print("P04 SEM OFENSIVA: %d verificações; %d falhas" % [checks,falhas])
	quit(1 if falhas else 0)
