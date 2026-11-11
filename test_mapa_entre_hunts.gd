extends SceneTree
var falhas: int=0
var checks: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool, texto: String) -> void:
 checks+=1
 if not ok: falhas+=1;push_error(texto)
func quadros() -> void:
 for i in range(4): await process_frame
func parar(caca: Node) -> void:
 caca.set_process(false);caca.set_physics_process(false)
 if "timer_combate" in caca: caca.timer_combate.stop();caca.timer_auto_potion.stop()
func hud_de(caca: Node) -> Control:
 # cena antiga: Interface/HudCaca; cena nova (caca_sim, fase 2): a mesma HUD em hud_caca
 return caca.hud_caca if "hud_caca" in caca and caca.hud_caca!=null else caca.get_node("Interface/HudCaca")
func executar() -> void:
 var estado: Node=root.get_node("EstadoJogo")
 estado.especie_caca=load("res://dados/especies/geodude.tres")
 estado.curar_time();estado.auto_catch=false;estado.auto_potion=false
 var lider: DadosPokemon=estado.obter_lider()
 var estoque: Dictionary=estado.estoque_bolas.duplicate()
 var caca: Node=load("res://Caca.tscn").instantiate();root.add_child(caca);current_scene=caca
 parar(caca);await quadros()
 var hud: Control=caca.get_node("Interface/HudCaca")
 var id: String=caca.selvagens[0].id
 var hp: int=lider.obter_vida_atual()
 hud.capturados_hunt=7
 hud.menu.mapa_solicitado.emit();await quadros()
 checar(hud.mapa_mundi.visible and current_scene==caca,"Botão abre popup sem voltar à cidade")
 checar(caca.selvagens[0].id==id and hud.capturados_hunt==7,"Abrir preserva encontro e contagem")
 hud.mapa_mundi._on_fechar_pressed()
 checar(not hud.mapa_mundi.visible and current_scene==caca,"Fechar volta à mesma caça")
 hud.menu.mapa_solicitado.emit();await quadros()
 for registro in hud.mapa_mundi.catalogo:
  if registro["name"]=="Togepi": hud.mapa_mundi._selecionar_registro(registro);break
 await quadros()
 # Fase 2 (E): a hunt simulada abre a cena nova (caca_sim.tscn).
 checar(current_scene!=null and current_scene.scene_file_path=="res://caca_sim.tscn" and estado.especie_caca.nome=="Togepi","Viaja diretamente para Togepi")
 caca=current_scene;parar(caca)
 hud=hud_de(caca)
 checar(hud.capturados_hunt==0,"Nova caça zera contador de capturas")
 checar(estado.obter_lider()==lider and lider.obter_vida_atual()==hp,"Preserva líder e HP, sem cura na viagem")
 checar(estado.estoque_bolas==estoque and not estado.auto_potion and not estado.auto_catch,"Preserva estoque e configurações")
 var instancia: int=caca.get_instance_id()
 var chave: String=String(caca.sim.cfg["hunt_key"])
 hud.menu.mapa_solicitado.emit();await quadros()
 for registro in hud.mapa_mundi.catalogo:
  if registro["name"]=="Togepi": hud.mapa_mundi._selecionar_registro(registro);break
 await quadros()
 checar(current_scene.get_instance_id()!=instancia and String(current_scene.sim.cfg["hunt_key"])!=chave,"Selecionar mesma hunt cria nova instância")
 print("MAPA ENTRE HUNTS: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
