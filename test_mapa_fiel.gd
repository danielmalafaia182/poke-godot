extends SceneTree
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool, texto: String) -> void:
	checks+=1
	if not ok:
		falhas+=1
		push_error(texto)
func quadros() -> void:
	for i in range(7): await process_frame
func clicar(p: Vector2) -> void:
	var m: InputEventMouseMotion=InputEventMouseMotion.new()
	m.position=p
	m.global_position=p
	root.push_input(m,true)
	for pressionado in [true,false]:
		var b: InputEventMouseButton=InputEventMouseButton.new()
		b.position=p
		b.global_position=p
		b.button_index=MOUSE_BUTTON_LEFT
		b.pressed=pressionado
		root.push_input(b,true)
	await quadros()
func arrastar(origem: Vector2, delta: Vector2) -> void:
	var b: InputEventMouseButton=InputEventMouseButton.new()
	b.position=origem
	b.global_position=origem
	b.button_index=MOUSE_BUTTON_LEFT
	b.pressed=true
	root.push_input(b,true)
	var m: InputEventMouseMotion=InputEventMouseMotion.new()
	m.position=origem+delta
	m.global_position=m.position
	m.relative=delta
	m.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(m,true)
	b=b.duplicate()
	b.position=m.position
	b.global_position=m.position
	b.pressed=false
	root.push_input(b,true)
	await quadros()
func executar() -> void:
	root.size=Vector2i(1920,1080)
	var estado: Node=root.get_node("EstadoJogo")
	estado.auto_potion=false
	estado.auto_catch=false
	estado.auto_catch_ball_id=3
	var bolas: Dictionary=estado.estoque_bolas.duplicate()
	var pocoes: Dictionary=estado.estoque_pocoes.duplicate()
	var cidade: Control=load("res://cidade.tscn").instantiate()
	root.add_child(cidade)
	current_scene=cidade
	await quadros()
	cidade.set_process(false)
	cidade._on_botao_cacar_pressed()
	await quadros()
	var mapa: Control=cidade.mapa_mundi
	checar(mapa.visible and mapa.janela.size==Vector2(704,900),"modal desktop 704x900")
	checar(mapa.catalogo.size()==227 and mapa.marcadores.size()==227 and mapa.contador.text=="227 of 227","catálogo original completo de Kanto")
	checar(mapa.botoes_regioes.size()==4 and mapa.botoes_tipos.size()==18,"quatro banners e dezoito tipos")
	checar(is_equal_approx(mapa.navegacao.zoom,1.25) and mapa.imagem_mapa.position.x<0,"primeira abertura enquadra o destino após layout visível")
	var geodude: Button
	var outro: Button
	for m in mapa.marcadores:
		if mapa.marcadores[m]["slug"]=="geodude": geodude=m
		elif outro==null: outro=m
	checar(geodude!=null and geodude.get_global_rect().intersects(mapa.navegacao.get_global_rect()),"Geodude visível na posição original")
	# Digitação real: text_changed do LineEdit, sem depender de setters silenciosos.
	await clicar(mapa.buscas.get_global_rect().get_center())
	var texto: InputEventKey
	for letra in "geod":
		texto=InputEventKey.new()
		texto.unicode=letra.unicode_at(0)
		texto.pressed=true
		root.push_input(texto,true)
	await quadros()
	checar(mapa.contador.text=="1 of 227" and geodude.visible,"busca digitada encontra apenas Geodude")
	mapa.nivel_de.text="2"
	mapa._aplicar_filtros()
	checar(mapa.contador.text=="0 of 227","mínimo de nível filtra destino Lv1")
	mapa.nivel_de.text=""
	mapa.nivel_ate.text="1"
	mapa._aplicar_filtros()
	checar(mapa.contador.text=="1 of 227","máximo de nível inclui destino Lv1")
	await clicar(mapa.botoes_tipos["WATER"].get_global_rect().get_center())
	checar(mapa.contador.text=="0 of 227","água exclui Geodude")
	await clicar(mapa.botoes_tipos["GROUND"].get_global_rect().get_center())
	checar(mapa.contador.text=="1 of 227","tipo secundário Terra filtra Geodude")
	mapa.limpar_filtros()
	checar(mapa.contador.text=="227 of 227" and mapa.tipo_selecionado=="" and mapa.buscas.text=="" and mapa.nivel_ate.text=="","Clear limpa todos os filtros")
	checar(mapa._normalizar("Flabébé")=="flabebe","busca normaliza acentos")
	mapa.buscas.text="geod"
	mapa._aplicar_filtros()
	var ponto: Vector2=mapa.navegacao.size*0.5
	var mundo: Vector2=(ponto-mapa.imagem_mapa.position)/mapa.navegacao.zoom
	mapa.navegacao._aplicar_zoom(mapa.navegacao.zoom*1.2,ponto)
	checar(((ponto-mapa.imagem_mapa.position)/mapa.navegacao.zoom).distance_to(mundo)<0.01,"zoom preserva ponto sob o cursor")
	var antes: Vector2=mapa.imagem_mapa.position
	await arrastar(mapa.navegacao.get_global_rect().position+Vector2(620,50),Vector2(24,18))
	checar(mapa.imagem_mapa.position!=antes and not mapa.navegacao.arrastando,"mapa arrasta e libera o mouse")
	for i in range(20): mapa.navegacao.zoom_centro(0.5)
	checar(is_equal_approx(mapa.navegacao.zoom,mapa.navegacao._zoom_minimo()),"zoom mínimo preenche o viewport")
	checar(mapa.imagem_mapa.position.x<=0 and mapa.imagem_mapa.position.y<=0,"pan não revela espaço vazio fora da imagem")
	for i in range(20): mapa.navegacao.zoom_centro(2)
	checar(is_equal_approx(mapa.navegacao.zoom,maxf(2.5,mapa.navegacao._zoom_minimo()*5)),"limite superior do zoom")
	var pos: Vector2=mapa.janela.position
	await arrastar(pos+Vector2(290,22),Vector2(24,20))
	checar(mapa.janela.position!=pos,"cabeçalho arrasta janela")
	mapa._selecionar_registro(mapa.marcadores[outro])
	checar(current_scene==cidade and mapa.aviso.visible,"destino de referência não inicia outra caça")
	mapa.botoes_regioes[1].pressed.emit()
	checar(mapa.aviso.text.contains("não implementada") and current_scene==cidade,"outras regiões não simulam conteúdo disponível")
	for resolucao in [Vector2i(1920,1080),Vector2i(1152,648),Vector2i(800,450)]:
		root.size=resolucao
		await quadros()
		var rect: Rect2=mapa.janela.get_global_rect()
		checar(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=resolucao.x+1 and rect.end.y<=resolucao.y+1,"janela cabe em "+str(resolucao))
	root.size=Vector2i(1920,1080)
	await quadros()
	var tecla: InputEventKey=InputEventKey.new()
	tecla.keycode=KEY_ESCAPE
	tecla.pressed=true
	root.push_input(tecla,true)
	await quadros()
	checar(not mapa.visible,"Esc fecha o mapa")
	cidade._on_botao_cacar_pressed()
	await quadros()
	checar(mapa.visible and mapa.buscas.text=="geod","reabrir preserva filtro e navegação da instância")
	await clicar(Vector2(30,300))
	checar(not mapa.visible,"clique fora fecha")
	cidade._on_botao_cacar_pressed()
	await quadros()
	mapa.navegacao.centralizar(Vector2(761,409))
	await quadros()
	await clicar(geodude.get_global_rect().get_center())
	# Fase 2 (E): a hunt simulada abre a cena nova (caca_sim.tscn).
	checar(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://caca_sim.tscn" and estado.especie_caca.nome=="Geodude","clique real no marcador entra na caça implementada")
	checar(estado.auto_catch_ball_id==3 and estado.estoque_bolas==bolas and estado.estoque_pocoes==pocoes,"abrir mapa e viajar preserva configuração e estoque")
	print("MAPA FIEL: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
