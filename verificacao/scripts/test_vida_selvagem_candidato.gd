extends SceneTree
const V=preload("res://regras_vida_selvagem.gd")
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func executar() -> void:
	var p: DadosPokemon=DadosPokemon.new();p.especie=preload("res://especies_importadas.gd").obter_especies()["Blastoise"]
	p.nivel=80;p.qualidade=1.0;p.iv_hp=16
	var atributos: Dictionary=p.obter_atributos()
	var hp_aliado: int=p.obter_vida_maxima()
	check(V.calcular(p)==int(atributos["hp"])*35,"atributo HP recebe fator35")
	check(V.calcular(p,false)==hp_aliado*5,"regra anterior preservada")
	check(p.obter_atributos()==atributos and p.obter_vida_maxima()==hp_aliado,"HP selvagem não muda atributos/HP aliado")
	var baixo: int=V.calcular(p);p.iv_hp=32
	check(V.calcular(p)>baixo,"IV HP aumenta a vida de combate")
	var alto: int=V.calcular(p);p.iv_atk=32
	check(V.calcular(p)==alto,"IV Atk não altera HP")
	p.nivel=1;p.especie=load("res://dados/especies/geodude.tres")
	check(V.calcular(p)==120,"piso120 preserva Geodude1")
	check(p.obter_vida_maxima()==24,"Geodude aliado continua24HP")
	# Exemplos do enumerador Python conferidos no cálculo real de atributos Godot.
	var auditoria: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://verificacao/dados/auditoria_hp_selvagens.json"))
	check(auditoria["resultados"][0]["compativeis"]==1 and auditoria["resultados"][1]["compativeis"]==24,"auditoria24 encontros e regra anterior")
	p.especie=preload("res://especies_importadas.gd").obter_especies()["Blastoise"];p.nivel=80
	for caso in auditoria["resultados"][1]["casos"]:
		p.iv_hp=int(caso["exemplo"]["iv_hp_exemplo"]);p.qualidade=float(caso["exemplo"]["qualidade_exemplo"])
		check(V.calcular(p)==int(caso["hp_maximo"]),"exemplo condicional reproduz HP original no Godot")
	var estado: Node=root.get_node("EstadoJogo")
	estado.especie_caca=preload("res://especies_importadas.gd").obter_especies()["Blastoise"]
	estado.auto_catch=false;estado.curar_time()
	var caca: Node2D=load("res://Caca.tscn").instantiate();root.add_child(caca)
	caca.set_process(false);caca.set_physics_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
	check(caca._hp_candidato_ativo(),"candidata HP ativa por padrão")
	for r in caca.selvagens:
		check(r.vida_maxima==V.calcular(r.pokemon),"população usa regra candidata")
		check(r.vida==r.vida_maxima and r.perfil_hp.is_read_only(),"início cheio e procedência imutável")
		check(r.perfil_hp["hp_maximo_aplicado"]==r.vida_maxima,"procedência fecha com encontro")
	var alvo: EncontroSelvagem=caca.encontro_atual
	alvo.vida-=11
	var hp_antes: int=alvo.vida
	caca.usar_hp_selvagem_candidato=false
	check(alvo.vida==hp_antes and alvo.perfil_hp["regra"]=="hp_selvagem_candidato_35_min120","alternar opção não cura/redefine encontro existente")
	var slot: int=alvo.slot;var antigo_id: String=alvo.id
	caca._criar_individuo(slot,alvo.celula)
	var novo: EncontroSelvagem=caca.selvagens[slot]
	check(novo.id!=antigo_id and novo.vida_maxima==V.calcular(novo.pokemon,false),"respawn aplica rollback ao novo encontro")
	check(novo.perfil_hp["regra"]=="hp_aliado_x5","procedência do respawn atualizada")
	var registro: Node=caca.registro_combate
	registro.comecar();var caminho: String=registro.encerrar()
	var texto: String=FileAccess.get_file_as_string(caminho)
	check(texto.contains('"perfil_hp"') and texto.contains('"hp_maximo_aplicado"'),"exportação inclui perfil de HP de cada encontro")
	caca.usar_hp_selvagem_candidato=true;caca.usar_calibracao_combate=false
	check(not caca._hp_candidato_ativo() and caca._calcular_vida_maxima_selvagem(p)==V.calcular(p,false),"V1 mantém HP antigo")
	caca.queue_free();await process_frame
	print("VIDA SELVAGEM CANDIDATO: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
