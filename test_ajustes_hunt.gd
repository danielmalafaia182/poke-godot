extends SceneTree
var falhas: int=0
var checks: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool, texto: String) -> void:
	checks+=1
	if not ok:
		falhas+=1
		push_error(texto)
func executar() -> void:
	root.size=Vector2i(1152,648)
	var evento: Dictionary={"speciesName":"Geodude","xpGained":8,"xpParts":{"base":8},"pokeXp":{"xpGained":8,"parts":{"base":8}},"loot":[]}
	var painel: Control=preload("res://cartoes_derrota.gd").new()
	root.add_child(painel)
	for i in range(30):
		painel.apresentar(evento)
		checar(painel.cartoes.size()==1 and painel.total_exibidos==i+1,"uma apresentação "+str(i))
		painel.apresentar(evento)
		checar(painel.cartoes.size()==1 and painel.total_exibidos==i+1 and painel.cartoes[0]["evento"]["xpGained"]==8,"abates posteriores não substituem, somam ou enfileiram")
		painel.cartoes[0]["ultimo"]=Time.get_ticks_msec()-5000
		painel._process(0)
		painel.apresentar(evento)
		checar(painel.cartoes.size()==1 and painel.cartoes[0].has("saida"),"bloqueado durante fade")
		painel.cartoes[0]["saida"]=Time.get_ticks_msec()-221
		painel._process(0)
		checar(painel.cartoes.is_empty(),"cartão desapareceu completamente")
	painel.apresentar(evento)
	checar(painel.cartoes.is_empty() and painel.total_exibidos==30,"limite 30 por instância")
	painel.queue_free()
	var cores: Script=preload("res://apresentacao_caca.gd")
	var catalogo: Script=preload("res://catalogo_golpes.gd")
	checar(cores.cor_efetividade(catalogo.efetividade("GRASS","ROCK","GROUND"))==Color("ffe65a"),"Planta contra Pedra/Terra amarelo")
	checar(cores.cor_efetividade(catalogo.efetividade("NORMAL","ROCK","GROUND"))==Color("ff6666"),"Normal contra Pedra/Terra vermelho")
	checar(cores.cor_efetividade(1)==Color.WHITE,"neutro branco")
	var mini: Texture2D=preload("res://visual_pokemon.gd").icone_reduzido("Geodude",24)
	var imagem: Image=mini.get_image()
	var claros: int=0
	for y in range(imagem.get_height()):
		for x in range(imagem.get_width()):
			var pixel: Color=imagem.get_pixel(x,y)
			if pixel.a>0.8 and pixel.r>0.6 and pixel.g>0.6 and pixel.b>0.6: claros+=1
	checar(claros>0,"redução conserva contribuição dos pixels claros dos olhos")
	var estado: Node=root.get_node("EstadoJogo")
	estado.especie_caca=load("res://dados/especies/geodude.tres")
	estado.auto_catch=false
	estado.curar_time()
	var caca: Node2D=load("res://Caca.tscn").instantiate()
	root.add_child(caca)
	caca.set_physics_process(false)
	caca.timer_combate.stop()
	for i in range(5): await process_frame
	var hud: Control=caca.get_node("Interface/HudCaca")
	checar(hud.capturados_hunt==0 and hud.contador_wilds.text=="0 wilds","contador inicia zerado")
	hud._captura_resolvida({"id":1,"sucesso":false})
	checar(hud.capturados_hunt==0,"falha não conta captura")
	hud._captura_resolvida({"id":2,"sucesso":true})
	hud._captura_resolvida({"id":2,"sucesso":true})
	checar(hud.capturados_hunt==1 and hud.contador_wilds.text=="1 wilds","sucesso conta uma vez")
	checar(not hud.resumo_captura.visible and not hud.painel_golpes.visible,"mensagens e painel de depuração ocultos")
	print("CAPTURA TESTE ",hud.captura.get_global_rect()," VIEW ",root.get_visible_rect())
	checar(hud.captura.position.x+hud.captura.size.x<=root.get_visible_rect().size.x,"captura cabe à direita")
	var apresentacao: Node2D=caca.get_node("ApresentacaoCaca")
	apresentacao.apresentar_golpe({"tipo":"GRASS","nome":"Seed Bomb","dano":2103,"destino":Vector2.ZERO,"efetividade":4.0})
	var texto: Node2D=apresentacao.get_node("TextoGolpe")
	checar(texto.get_node("Dano").text=="2103" and texto.get_node("Dano").get_theme_color("font_color")==Color("ffe65a"),"dano sem prefixo e com cor de efetividade")
	var antes: int=apresentacao.get_child_count()
	apresentacao.apresentar_dano(Vector2.ZERO,2103,"GRASS")
	checar(apresentacao.get_child_count()==antes,"sinal legado não duplica texto")
	caca.queue_free()
	await process_frame
	caca=load("res://Caca.tscn").instantiate()
	root.add_child(caca)
	caca.set_physics_process(false)
	caca.timer_combate.stop()
	for i in range(5): await process_frame
	hud=caca.get_node("Interface/HudCaca")
	checar(hud.capturados_hunt==0 and hud.recompensas.total_exibidos==0,"nova entrada na mesma hunt reseta ambos os contadores")
	caca.queue_free()
	await process_frame
	print("AJUSTES HUNT: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
