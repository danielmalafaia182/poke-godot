extends SceneTree
const LOOT: Script=preload("res://regras_loot.gd")
var falhas: int=0
var checks: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool, texto: String) -> void:
	checks+=1
	if not ok:
		falhas+=1
		push_error(texto)
func executar() -> void:
	root.size=Vector2i(1920,1080)
	var rng: RandomNumberGenerator=RandomNumberGenerator.new()
	rng.seed=54321
	var contagens: Dictionary={}
	var limites_ok: bool=true
	for i in range(5000):
		for item in LOOT.sortear("Geodude",rng):
			var dados: Dictionary=LOOT.obter(item["itemId"])
			limites_ok=limites_ok and int(item["qty"])>=int(dados["minimo"]) and int(item["qty"])<=int(dados["maximo"])
			contagens[item["itemId"]]=int(contagens.get(item["itemId"],0))+1
	checar(limites_ok,"quantidades respeitam catálogo em 5000 sorteios")
	checar(not contagens.has(44417),"chance zero nunca dropa")
	for id in [39,120]: checar(absf(float(contagens.get(id,0))/5000.0-0.95)<0.03,"95% do catálogo: "+str(id))
	checar(LOOT.sortear("EspecieNaoImplementada",rng).is_empty(),"não inventa loot de espécie desconhecida")
	var estado: Node=root.get_node("EstadoJogo")
	var inv: InventarioJogo=estado.inventario
	inv.estoque_materiais.clear()
	var lote: Array[Dictionary]=[{"itemId":39,"qty":4,"name":"Earth Ball"},{"itemId":120,"qty":3,"name":"Small Stone"}]
	checar(inv.receber_loot(lote).size()==2 and inv.quantidade_item_bag(39)==4 and inv.quantidade_item_bag(120)==3,"lote concedido à BAG")
	var bolas: Dictionary=estado.estoque_bolas.duplicate()
	var pocoes: Dictionary=estado.estoque_pocoes.duplicate()
	checar(inv.mover_item_depot(39,true)=="" and inv.quantidade_item_bag(39)==0 and inv.itens_depot[39]==4,"material vai para depot")
	checar(inv.mover_item_depot(39,false)=="" and inv.quantidade_item_bag(39)==4 and not inv.itens_depot.has(39),"material volta à BAG")
	var antes: Dictionary=inv.estoque_materiais.duplicate()
	var invalido: Array[Dictionary]=[{"itemId":39,"qty":1},{"itemId":999999,"qty":1}]
	checar(inv.receber_loot(invalido).is_empty() and inv.estoque_materiais==antes,"lote inválido rejeitado sem concessão parcial")
	inv.estoque_materiais[39]=inv.MAX_ESTOQUE
	checar(inv.receber_loot(lote).is_empty() and inv.quantidade_item_bag(120)==3,"overflow rejeita lote inteiro")
	inv.estoque_materiais=antes
	var save: RefCounted=preload("res://salvamento_local.gd").new()
	var dados: Dictionary=save.construir_dados(estado)
	checar(save._validar(dados)=="" and dados["materiais"]["39"]==4,"materiais serializados em save válido")
	inv.estoque_materiais.clear()
	save._restaurar(estado,dados)
	checar(inv.quantidade_item_bag(39)==4 and inv.quantidade_item_bag(120)==3,"materiais restaurados sem perda")
	dados.erase("materiais")
	checar(save._validar(dados)=="","save antigo sem materiais continua aceito")
	checar(estado.estoque_bolas==bolas and estado.estoque_pocoes==pocoes,"materiais não colidem com bolas e poções")
	estado.especie_caca=load("res://dados/especies/geodude.tres")
	estado.auto_catch=false
	estado.curar_time()
	var caca: Node2D=load("res://Caca.tscn").instantiate()
	root.add_child(caca)
	caca.set_process(false)
	caca.set_physics_process(false)
	caca.timer_combate.stop()
	caca.rng_loot.seed=100
	await process_frame
	var hud: Control=caca.get_node("Interface/HudCaca")
	checar(hud.size==Vector2(1920,1080),"caça mantém HUD em pixels reais Full HD")
	var encontro: EncontroSelvagem=caca.encontro_atual
	var indicador: Node2D=encontro.imagem.get_node("IndicadorSelvagem")
	indicador.atualizar()
	checar(indicador.nome.texture==preload("res://fonte_mundo.gd").texto("Geodude",Color("00ff00")),"nome bitmap verde compartilhado")
	checar(indicador.barra.size==hud.vida_aliado.size and indicador.barra.COR_HP==hud.vida_aliado.COR_HP and indicador.barra.COR_HP==Color("00c000"),"barras têm tamanho e cor iguais")
	var xp: int=caca.pokemon_aliado.experiencia_total
	caca.vida_selvagem=0
	caca.encerrar_batalha("Larvitar")
	checar(caca.pokemon_aliado.experiencia_total==xp+8,"XP base aplicado no KO")
	var ganhos: Dictionary=inv.estoque_materiais.duplicate()
	checar(not ganhos.is_empty(),"KO gerou loot real")
	caca._recompensar_derrota()
	checar(inv.estoque_materiais==ganhos and caca.pokemon_aliado.experiencia_total==xp+8,"mesmo encontro não duplica loot nem XP")
	var snapshot: Dictionary=inv.estoque_materiais.duplicate()
	var evento: Dictionary=hud.recompensas.cartoes[0]["evento"].duplicate(true)
	hud.recompensas.apresentar(evento)
	checar(inv.estoque_materiais==snapshot,"reapresentar evento não concede itens")
	var somas: Dictionary={}
	for item in evento["loot"]: somas[item["itemId"]]=int(item["qty"])
	for item in hud.recompensas.cartoes[0]["evento"]["loot"]:
		checar(int(item["qty"])==int(somas[item["itemId"]]),"novo evento não altera chips em exibição")
	checar(estado.salvar_agora(),"salvamento físico após KO")
	caca.queue_free()
	await process_frame
	print("LOOT COMBATE FIEL: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
