extends SceneTree
const C=preload("res://regras_dano_candidato.gd")
const D=preload("res://regras_dano.gd")
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func pokemon(nome: String,lv: int=30) -> DadosPokemon:
	var p: DadosPokemon=DadosPokemon.new()
	p.especie=preload("res://especies_importadas.gd").obter_especies()[nome.capitalize()]
	p.nivel=lv;p.qualidade=1.0
	p.iv_hp=16;p.iv_atk=16;p.iv_def=16;p.iv_sp_atk=16;p.iv_sp_def=16;p.iv_spd=16
	return p
func executar() -> void:
	var golpe: Dictionary={"name":"Teste","type":"GRASS","category":"PHYSICAL","power":120,"cooldownMs":1000}
	var a: Dictionary={"atk":994,"spAtk":1202}
	var d: Dictionary={"def":110,"spDef":110}
	var tipos: Array[String]=["GRASS","PSYCHIC"]
	var alto: Dictionary=C.detalhar_atributos(406,a,d,tipos,golpe,2.5,1.0)
	var baixo: Dictionary=C.detalhar_atributos(406,a,d,tipos,golpe,2.5,0.85)
	check(alto["stab"]==1.5 and is_equal_approx(alto["nominal_bruto"],alto["bruto_sem_stab"]*1.5),"STAB uma vez antes do arredondamento")
	check(baixo["dano"]==D.finalizar_dano(alto["nominal_bruto"]*0.85),"variação antes do arredondamento final")
	check(alto["dano_v2_mesmos_atributos"]==D.calcular_atributos(406,a,d,golpe,2.5),"comparação V2 preservada")
	check(alto.is_read_only(),"componentes imutáveis no evento")
	check(C.detalhar_atributos(406,a,d,["WATER","FLYING"],golpe,2.5,1.0)["stab"]==1.0,"sem STAB para tipo diferente")
	check(C.detalhar_atributos(406,a,d,["GRASS","GRASS"],golpe,2.5,1.0)["stab"]==1.5,"tipo duplicado não acumula STAB")
	check(C.detalhar_atributos(406,a,d,tipos,golpe,0.0,0.85)["dano"]==0,"imunidade preservada acima do piso")
	var status: Dictionary={"name":"Status","type":"GRASS","category":"STATUS","power":0}
	check(C.detalhar_atributos(406,a,d,tipos,status,1.0,0.85)["dano"]==0,"status não causa dano")
	var a2: Dictionary=a.duplicate();a2["atk"]*=2
	check(C.detalhar_atributos(406,a2,d,tipos,golpe,2.5,1.0)["dano"]>alto["dano"],"Atk afeta físico")
	var d2: Dictionary=d.duplicate();d2["def"]*=2
	check(C.detalhar_atributos(406,a,d2,tipos,golpe,2.5,1.0)["dano"]<alto["dano"],"Def reduz físico")
	var esp: Dictionary=golpe.duplicate();esp["category"]="SPECIAL"
	var esp_base: int=C.detalhar_atributos(406,a,d,tipos,esp,2.5,1.0)["dano"]
	check(C.detalhar_atributos(406,a2,d2,tipos,esp,2.5,1.0)["dano"]==esp_base,"Atk/Def não interferem no especial")
	a2=a.duplicate();a2["spAtk"]*=2;d2=d.duplicate();d2["spDef"]*=2
	check(C.detalhar_atributos(406,a2,d,tipos,esp,2.5,1.0)["dano"]>esp_base,"SpAtk afeta especial")
	check(C.detalhar_atributos(406,a,d2,tipos,esp,2.5,1.0)["dano"]<esp_base,"SpDef reduz especial")
	# Limites das previsões congeladas na nova amostra; sem ajustar com Wood Hammer.
	check(C.detalhar_atributos(406,a,{"def":121},tipos,golpe,2.5,0.85)["dano"]==10338,"slot10 limite inferior previsto")
	check(C.detalhar_atributos(406,a,{"def":106},tipos,golpe,2.5,1.0)["dano"]==13882,"slot10 limite superior previsto")
	check(C.detalhar_atributos(406,a,{"def":111},tipos,golpe,2.5,0.85)["dano"]==11269,"slot14 limite inferior previsto")
	check(C.detalhar_atributos(406,a,{"def":108},tipos,golpe,2.5,1.0)["dano"]==13625,"slot14 limite superior previsto")
	var geo: DadosPokemon=pokemon("geodude",1)
	var tackle: Dictionary={"name":"Tackle","power":50,"type":"NORMAL","category":"PHYSICAL","cooldownMs":15000}
	var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=7331
	var antes: int=rng.state
	C.nominal(geo,geo,tackle);C.resolver(geo,geo,status,false,rng)
	check(rng.state==antes,"preview/status não consomem RNG")
	var primeiro: Dictionary=C.resolver(geo,geo,tackle,false,rng)
	check(rng.state!=antes,"execução de golpe consome RNG")
	rng.state=antes
	check(C.resolver(geo,geo,tackle,false,rng)==primeiro,"seed/estado reproduz resolução")
	check(primeiro["dano"]==2 and C.resolver(geo,geo,tackle,true,rng)["dano"]==1,"pisos2/1 preservados")
	var grass: DadosPokemon=pokemon("bulbasaur")
	var water: DadosPokemon=pokemon("blastoise")
	for i in range(200):
		var r: Dictionary=C.resolver(grass,water,golpe,false,rng)
		check(r["variacao"]>=0.85 and r["variacao"]<=1.0,"variação dentro do suporte")
		check(r["dano"]==D.finalizar_dano(r["bruto_sem_stab"]*r["stab"]*r["variacao"]),"evento recompõe exatamente dano")
	# Integração real: nominal escolhe; sorteio ocorre só ao executar, nos dois lados.
	var estado: Node=root.get_node("EstadoJogo")
	estado.especie_caca=geo.especie;estado.auto_catch=false;estado.curar_time()
	var caca: Node2D=load("res://Caca.tscn").instantiate();root.add_child(caca)
	caca.set_process(false);caca.set_physics_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
	caca.movimento_selvagens_habilitado=false;caca.reagir_ao_cerco=false
	caca.pokemon_aliado=geo;geo.vida_atual=24
	var alvo: EncontroSelvagem=caca.encontro_atual;alvo.pokemon=pokemon("geodude",1);alvo.vida_maxima=120;alvo.vida=120
	for outro in caca.selvagens:
		if outro!=alvo:outro.resolver(100)
	for dir: Vector2i in caca.DIRECOES:
		if caca.passagem_permitida(alvo.celula,alvo.celula+dir):
			caca.imagem_aliado.global_position=caca.celula_para_posicao(alvo.celula+dir);break
	caca.aproximando=false;caca.batalha_encerrada=false;caca.rng_dano.seed=7331
	var salvo: int=caca.rng_dano.state
	for i in range(20):caca._prever_dano_aliado(tackle);caca._prever_dano_selvagem(tackle,alvo)
	check(caca.rng_dano.state==salvo,"seleção de ambos os lados não sorteia")
	check(caca._candidata_ativa(),"hunt ativa candidata por padrão")
	var eventos: Array[Dictionary]=[]
	caca.golpe_executado.connect(func(e: Dictionary) -> void:eventos.append(e))
	var registro: Node=caca.registro_combate;registro.comecar()
	caca._executar_golpes_catalogados()
	check(eventos.size()==2,"um golpe aliado e um selvagem executados")
	for e in eventos:
		check(e["regra_dano"]==C.VERSAO and e["dano"]==e["calculo_dano"]["dano"],"evento identifica versão e dano exato")
		check(e["calculo_dano"].is_read_only(),"componentes do golpe publicados como leitura")
	check(caca.vida_selvagem==118 and caca.vida_aliado==23,"HP real fecha com dano dos eventos")
	var log: String=registro.encerrar()
	var conteudo: String=FileAccess.get_file_as_string(log)
	check(conteudo.contains('"calculo_dano"') and conteudo.contains('"rng_dano_seed"') and conteudo.contains(C.VERSAO),"JSONL exporta componentes e seed")
	caca.usar_dano_candidato=false
	check(caca._versao_dano()=="atributos_local_v2_piso_2_1" and caca._dano_golpe(geo,alvo.pokemon,tackle,false)==D.calcular(geo,alvo.pokemon,tackle),"rollbackV2 sem mudar atributos")
	caca.usar_dano_candidato=true;caca.usar_calibracao_combate=false
	check(not caca._candidata_ativa() and caca._versao_dano()=="atributos_local_v1","rollbackV1 preservado")
	caca.queue_free();await process_frame
	print("DANO CANDIDATO: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
