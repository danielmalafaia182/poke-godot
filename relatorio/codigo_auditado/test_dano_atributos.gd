extends SceneTree
const R: Script=preload("res://regras_dano.gd")
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func check(ok: bool, msg: String) -> void:
	checks+=1
	if not ok:
		falhas+=1
		push_error(msg)
func pokemon(nome: String) -> DadosPokemon:
	var p: DadosPokemon=DadosPokemon.new()
	p.especie=load("res://dados/especies/"+nome+".tres")
	p.nivel=50
	p.qualidade=1.5
	return p
func executar() -> void:
	var a: DadosPokemon=pokemon("larvitar")
	var d: DadosPokemon=pokemon("geodude")
	var fis: Dictionary={"name":"Bite","type":"DARK","category":"PHYSICAL","power":60}
	var esp: Dictionary={"type":"DARK","category":"SPECIAL","power":60}
	var base: int=R.calcular(a,d,fis)
	check(base==19,"caso de referência físico nível 50")
	a.iv_atk=32
	check(R.calcular(a,d,fis)>base,"Atk aumenta dano físico")
	var especial: int=R.calcular(a,d,esp)
	check(especial==R.calcular(pokemon("larvitar"),d,esp),"Atk não afeta especial")
	d.iv_def=32
	check(R.calcular(a,d,fis)<R.calcular(a,pokemon("geodude"),fis),"Def reduz dano físico")
	a.iv_sp_atk=32
	check(R.calcular(a,d,esp)>especial,"SpAtk aumenta dano especial")
	d.iv_sp_def=32
	check(R.calcular(a,d,esp)<R.calcular(a,pokemon("geodude"),esp),"SpDef reduz dano especial")
	var dano: int=R.calcular(a,d,fis)
	a.iv_spd=32
	check(R.calcular(a,d,fis)==dano,"Speed não afeta dano")
	check(R.calcular(a,d,fis,true,false)>R.calcular(a,d,fis,false,false),"reforço legado permanece disponível")
	check(R.calcular(a,d,fis,true)==dano,"v2 retira multiplicador selvagem não confirmado acima do piso")
	check(R.amplificar_elemento(4)==5.5 and is_equal_approx(R.amplificar_elemento(0.5),1.0/3.0),"amplificação elemental oficial")
	check(R.calcular(a,d,{"type":"ELECTRIC","category":"SPECIAL","power":100})==0,"imunidade numérica")
	check(R.calcular(a,d,{"category":"STATUS","power":0})==0,"status não vira dano")
	var inicial: DadosPokemon=load("res://dados/pokemons/larvitar_inicial.tres")
	check(inicial.obter_total_ivs()==137 and inicial.vida_atual==inicial.obter_vida_maxima(),"inicial com IVs e vida concretos")
	check(inicial.especie.base_hp==50 and inicial.especie.base_atk==64 and inicial.especie.base_speed==41,"base real Larvitar")
	var c: ColecaoPokemon=ColecaoPokemon.new()
	c.iniciar_depot()
	var p: DadosPokemon=c.pokemon_inicial
	for campo in ["iv_hp","iv_atk","iv_def","iv_sp_atk","iv_sp_def","iv_spd"]: p.set(campo,1)
	p.vida_atual=0
	check(c.corrigir_inicial_prototipo() and p.vida_atual==0,"migração não ressuscita")
	check(not c.corrigir_inicial_prototipo(),"migração uma única vez")
	var estado: Node=root.get_node("EstadoJogo")
	estado.especie_caca=load("res://dados/especies/geodude.tres")
	estado.auto_catch=false
	estado.curar_time()
	var caca: Node2D=load("res://Caca.tscn").instantiate()
	caca.usar_dano_candidato=false
	caca.usar_hp_selvagem_candidato=false
	root.add_child(caca)
	caca.set_physics_process(false)
	caca.timer_combate.stop()
	check(caca.encontro_atual.vida_maxima==caca.pokemon_selvagem.obter_vida_maxima()*5,"HP selvagem deriva dos atributos")
	var previsto: int=R.calcular(caca.pokemon_aliado,caca.pokemon_selvagem,fis)
	var hp: int=caca.vida_selvagem
	var eventos: Array[Dictionary]=[]
	caca.golpe_executado.connect(func(e: Dictionary) -> void: eventos.append(e))
	caca._executar_golpes_catalogados()
	check(not eventos.is_empty() and eventos[0]["dano"]==previsto and caca.vida_selvagem==maxi(0,hp-previsto),"dano aplicado ao HP e ao evento")
	check(estado.salvar_agora(),"estado permanece salvável")
	caca.queue_free()
	await process_frame
	print("DANO ATRIBUTOS: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
