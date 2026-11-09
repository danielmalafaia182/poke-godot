extends SceneTree
const C=preload("res://regras_dano_candidato.gd")
const V=preload("res://regras_vida_selvagem.gd")
var checks: int=0
var falhas: int=0
var skull: Dictionary={"name":"Skull Bash","power":130,"type":"NORMAL","category":"PHYSICAL","cooldownMs":50000}
var thrash: Dictionary={"name":"Thrash","power":120,"type":"NORMAL","category":"PHYSICAL","cooldownMs":50000}
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func selvagem(ex: Dictionary) -> DadosPokemon:
	var p: DadosPokemon=DadosPokemon.new();p.especie=preload("res://especies_importadas.gd").obter_especies()["Blastoise"]
	p.nivel=ex["nivel_atributos"];p.qualidade=ex["qualidade"];p.iv_hp=ex["iv_hp"];p.iv_def=ex["iv_def"];p.iv_atk=ex["iv_atk"]
	return p
func executar() -> void:
	var dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/cenarios_nivel_formula.json"))
	var gya: DadosPokemon=DadosPokemon.new();gya.especie=preload("res://especies_importadas.gd").obter_especies()["Gyarados"]
	gya.nivel=214;gya.qualidade=1.8
	gya.iv_hp=23;gya.iv_atk=32;gya.iv_def=23;gya.iv_sp_atk=24;gya.iv_sp_def=23;gya.iv_spd=29
	check(gya.obter_atributos()["atk"]==647 and gya.obter_atributos()["def"]==428,"perfil confirmado do Gyarados")
	# O novo nível de fórmula não deve ser usado para alterar a defesa/HP histórico.
	var historico: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/historico_atributos80.json"))
	var E: Script=preload("res://analise_encontros_pareados.gd")
	var familia: Dictionary={}
	for item in E.familias():
		if item["id"]=="085_100_stab15":familia=item
	var engines: Dictionary={};var encontros: Dictionary={}
	for f in historico["fontes"]:
		var a: RefCounted=E.new();a.iniciar(f);engines[f["fonte"]["arquivo"]]=a
		for e in f["encontros"]:encontros[f["fonte"]["arquivo"]+"|"+e["id_local"]]=e
	check(historico["exemplos"].size()==24,"histórico com24 encontros")
	for row in historico["exemplos"]:
		var ex: Dictionary=row["exemplo"]
		var p: DadosPokemon=selvagem({"nivel_atributos":80,"qualidade":ex["qualidade"],"iv_hp":ex["iv_hp"],"iv_def":ex["iv_def"],"iv_atk":1})
		p.iv_sp_def=ex["iv_sp_def"]
		var e: Dictionary=encontros[row["fonte"]+"|"+row["encontro"]]
		check(V.calcular(p)==int(e["hp_maximo"]),"atributos80 fecham HP histórico")
		var attrs: Dictionary=p.obter_atributos()
		var h: Dictionary=engines[row["fonte"]].hipotese(e,int(attrs["def"]),int(attrs["spDef"]),familia)
		check(h["danos_compativeis"] and h["escolhas_nominais_compativeis"],"atributos80 fecham dano e seleção histórica")
	var primeiro: DadosPokemon
	for caso in dados["casos"]:
		var p: DadosPokemon=selvagem(caso["exemplo_candidato"])
		if primeiro==null:primeiro=p
		check(V.calcular(p)==int(caso["hp_maximo"]),"mesmo perfil fecha HP do slot"+str(caso["slot"]))
		var lo: Dictionary=C._detalhar_pokemon(p,gya,skull,0.85,true,150)
		var hi: Dictionary=C._detalhar_pokemon(p,gya,skull,1.0,true,150)
		for n in caso["recebidos"]:check(int(n)>=lo["dano"] and int(n)<=hi["dano"],"Skull Bash original dentro do suporte do mesmo perfil")
		var al: Dictionary=C._detalhar_pokemon(gya,p,thrash,0.85,false,0)
		var ah: Dictionary=C._detalhar_pokemon(gya,p,thrash,1.0,false,0)
		for n in caso["causados"]:check(int(n)>=al["dano"] and int(n)<=ah["dano"],"Thrash original dentro do suporte do mesmo perfil")
		check(hi["nivel_atributos"]==80 and hi["nivel_formula"]==150 and p.nivel==80,"nível de fórmula não altera Resource")
		check(C.nominal(gya,p,thrash,false,150)==C.nominal(gya,p,thrash),"override nunca afeta o aliado")
		check(C.nominal(p,gya,skull,true,150)>C.nominal(p,gya,skull,true),"parcela de nível aumenta ofensiva selvagem")
	var fraco: DadosPokemon=primeiro.duplicate(true);fraco.qualidade=0.8
	var forte: DadosPokemon=primeiro.duplicate(true);forte.qualidade=1.8
	check(V.calcular(forte)>V.calcular(fraco) and C.nominal(forte,gya,skull,true,150)>C.nominal(fraco,gya,skull,true,150),"mesmo nível pode ter HP e força distintos pela qualidade")
	fraco=primeiro.duplicate(true);forte=primeiro.duplicate(true);fraco.iv_atk=1;forte.iv_atk=32
	check(C.nominal(forte,gya,skull,true,150)>C.nominal(fraco,gya,skull,true,150),"IV ofensivo altera dano no mesmo nível")
	var estado: Node=root.get_node("EstadoJogo");estado.especie_caca=primeiro.especie;estado.auto_catch=false;estado.curar_time()
	var caca: Node2D=load("res://Caca.tscn").instantiate();caca.preparar_primeiro_ataque_selvagem=false;root.add_child(caca)
	caca.set_process(false);caca.set_physics_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
	caca.movimento_selvagens_habilitado=false;caca.reagir_ao_cerco=false
	caca.pokemon_aliado=gya;gya.vida_atual=6324
	var alvo: EncontroSelvagem=caca.encontro_atual;alvo.pokemon=primeiro;alvo.vida_maxima=3780;alvo.vida=3780
	for outro in caca.selvagens:
		if outro!=alvo:outro.resolver(100)
	for dir: Vector2i in caca.DIRECOES:
		if caca.passagem_permitida(alvo.celula,alvo.celula+dir):caca.imagem_aliado.global_position=caca.celula_para_posicao(alvo.celula+dir);break
	check(caca._nivel_formula_selvagem(primeiro)==150,"catálogo determina entrada candidata150")
	caca.rng_dano.seed=9191;var antes: int=caca.rng_dano.state
	for i in range(10):caca._prever_dano_selvagem(skull,alvo)
	check(caca.rng_dano.state==antes,"seleção nominal continua sem RNG")
	var eventos: Array[Dictionary]=[];caca.golpe_executado.connect(func(e: Dictionary) -> void:eventos.append(e))
	caca.registro_combate.comecar();caca._executar_ataque_selvagem(alvo)
	check(eventos.size()==1 and eventos[0]["nome"]=="Skull Bash","execução real escolhe Skull Bash")
	if not eventos.is_empty():
		var r: Dictionary=eventos[0]["calculo_dano"]
		check(r["nivel_atributos"]==80 and r["nivel_formula"]==150 and r["nivel_formula_substituido"],"evento distingue níveis")
		check(caca.vida_aliado==6324-int(r["dano"]),"dano aplicado fecha HP do aliado")
		check(r["dano"]>r["dano_v3_nivel_pokemon_mesma_variacao"],"registro oferece comparação com política anterior")
		check(r.is_read_only(),"metadados publicados imutáveis")
	var caminho: String=caca.registro_combate.encerrar();var texto: String=FileAccess.get_file_as_string(caminho)
	check(texto.contains('"nivel_formula"') and texto.contains("catalogo_huntLevel_candidato_v1"),"exportação identifica candidata")
	check(primeiro.nivel==80 and V.calcular(primeiro)==3780,"perfil capturável e HP não foram reescritos")
	caca.usar_nivel_dano_catalogo_selvagem=false
	check(caca._nivel_formula_selvagem(primeiro)==0 and caca._dano_golpe(primeiro,gya,skull,true)==C.nominal(primeiro,gya,skull,true),"rollback da política de nível")
	caca.usar_nivel_dano_catalogo_selvagem=true;caca.usar_dano_candidato=false
	check(caca._nivel_formula_selvagem(primeiro)==0,"V2 não recebe nível substituído")
	caca.queue_free();await process_frame
	print("NIVEL FORMULA SELVAGEM: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
