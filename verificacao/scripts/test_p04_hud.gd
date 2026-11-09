extends SceneTree
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: falhas+=1;push_error(msg)
func executar() -> void:
	var estado: Node=root.get_node("EstadoJogo")
	for i in range(5): await process_frame
	estado.especie_caca=load("res://dados/especies/geodude.tres");estado.curar_time()
	estado.auto_potion=false;estado.auto_catch=false
	while estado.time_pokemon.size()<6:
		var p: DadosPokemon=DadosPokemon.new();p.especie=estado.especie_caca;p.normalizar_atributos();estado.time_pokemon.append(p)
	var c: Node2D=load("res://Caca.tscn").instantiate();root.add_child(c)
	c.set_process(false);c.set_physics_process(false);c.timer_combate.stop();c.timer_auto_potion.stop()
	var hud: Control=c.get_node("Interface/HudCaca")
	for tamanho in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=tamanho
		c._publicar_diagnostico_ofensivo({"estado":"bloqueado","motivo":"habilidades_indisponiveis"})
		for i in range(4): await process_frame
		var aviso: Rect2=hud.aviso_ofensivo.get_global_rect()
		var time_rect: Rect2=hud.painel_time.get_global_rect()
		check(hud.aviso_ofensivo.visible,"aviso visível "+str(tamanho))
		check(not aviso.intersects(time_rect),"aviso não sobrepõe time completo "+str(tamanho))
		check(Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(aviso),"aviso dentro da janela "+str(tamanho))
		check(hud.texto_aviso_ofensivo.size.y>=hud.texto_aviso_ofensivo.get_minimum_size().y,"texto com altura suficiente "+str(tamanho))
		# Os botões abrem os painéis existentes, sem selecionar líder ou viajar.
		var grupo: HBoxContainer=hud.aviso_ofensivo.get_child(0).get_child(1)
		grupo.get_child(0).pressed.emit()
		check(hud.my_pokes.visible,"atalho de time abre painel "+str(tamanho))
		hud.my_pokes.hide()
		grupo.get_child(1).pressed.emit()
		check(hud.mapa_mundi.visible,"atalho de mapa abre popup na hunt "+str(tamanho))
		hud.mapa_mundi.hide()
		c._publicar_diagnostico_ofensivo({"estado":"pronto","motivo":""})
		check(not hud.aviso_ofensivo.visible,"aviso some na recuperação "+str(tamanho))
	c.free()
	print("P04 HUD: %d verificações; %d falhas" % [checks,falhas])
	quit(1 if falhas else 0)
