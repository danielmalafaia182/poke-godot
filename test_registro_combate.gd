extends SceneTree
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool,t: String) -> void:
 checks+=1
 if not ok:falhas+=1;push_error(t)
func executar() -> void:
 var estado: Node=root.get_node("EstadoJogo")
 estado.especie_caca=load("res://dados/especies/geodude.tres");estado.curar_time()
 var caca: Node=load("res://Caca.tscn").instantiate();root.add_child(caca)
 caca.set_process(false);caca.set_physics_process(false)
 await process_frame
 var logger: Node=caca.registro_combate
 var hp: int=caca.vida_aliado
 var rng: int=caca.rng_loot.state
 var alvo: String=caca.encontro_atual.id
 var prazo: float=caca.agenda_aliado.proximo_ataque_rapido
 logger.comecar()
 checar(logger.ativo and logger.registros.size()==2,"Início e estado registrados")
 logger._process(0.2)
 checar(caca.vida_aliado==hp and caca.rng_loot.state==rng and caca.encontro_atual.id==alvo and caca.agenda_aliado.proximo_ataque_rapido==prazo,"Observador não altera combate ou RNG")
 var r: EncontroSelvagem=caca.encontro_atual
 var golpe: Dictionary=preload("res://catalogo_golpes.gd").listar(caca.pokemon_aliado.especie.nome,caca.pokemon_aliado.nivel,true)[0]
 caca._emitir_golpe(golpe,true,4,1)
 checar(logger.registros.back()["tipo"]=="golpe" and logger.registros.back()["dados"]["vida_removida"]==1,"Preserva dano bruto e HP removido")
 var caminho: String=logger.encerrar()
 checar(not caminho.is_empty() and FileAccess.file_exists(caminho),"Arquivo exportado")
 var linhas: PackedStringArray=FileAccess.get_file_as_string(caminho).strip_edges().split("\n")
 var inicio: Dictionary=JSON.parse_string(linhas[0]);var fim: Dictionary=JSON.parse_string(linhas[-1])
 checar(inicio["dados"]["origem"]=="prototipo_local" and fim["tipo"]=="fim","Origem e encerramento explícitos")
 var hit: Dictionary=JSON.parse_string(linhas[3])
 checar(hit["dados"]["origem"] is Array and hit["dados"]["estado_apos"]["aliado"]["ivs"].size()==6,"Snapshot estruturado de atributos e posições")
 logger.comecar();checar(logger.registros.size()==2,"Nova sessão não mistura registros")
 logger.encerrar()
 var antes: int=DirAccess.get_files_at(logger.PASTA).size()
 logger.comecar();caca.queue_free()
 await process_frame
 checar(DirAccess.get_files_at("user://diagnosticos_combate").size()>antes,"Sair da caça exporta sessão ativa")
 print("REGISTRO COMBATE: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
