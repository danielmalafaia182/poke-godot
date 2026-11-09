extends SceneTree
const CATALOGO=preload("res://catalogo_hunts.gd")
var falhas: int=0
var checks: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool, texto: String) -> void:
 checks+=1
 if not ok:
  falhas+=1
  push_error(texto)
func executar() -> void:
 var original: String=FileAccess.get_file_as_string("res://dados/caca/hunts.json")
 var todas: Dictionary=JSON.parse_string(original)
 var geodude: Dictionary=CATALOGO.obter("Geodude")
 checar(geodude.size()>0,"Geodude cadastrado")
 checar(CATALOGO.obter("Larvitar").size()>0,"Larvitar cadastrado")
 checar(CATALOGO.obter("Inexistente").is_empty(),"Espécie desconhecida rejeitada")
 for campo in ["cenario","navegacao","inicio","pontos","populacao","respawn"]:
  var invalida: Dictionary=geodude.duplicate(true)
  invalida.erase(campo)
  checar(not CATALOGO.validar(invalida).is_empty(),"Campo obrigatório "+campo)
 for par in [["populacao",100],["populacao",0],["respawn",0],["inicio",[1.5,2]],["cenario","res://ausente.tscn"],["pontos",[[0,0],[0,0]]]]:
  var invalida: Dictionary=geodude.duplicate(true)
  invalida[par[0]]=par[1]
  checar(not CATALOGO.validar(invalida).is_empty(),"Valor inválido "+str(par))
 # O runner executa em cópia temporária: altera apenas a configuração dessa fixture.
 var alternativa: String="res://cenario_teste_config.tscn"
 var copia: PackedScene=load("res://cenario_caca.tscn")
 ResourceSaver.save(copia,alternativa)
 todas["Larvitar"]["cenario"]=alternativa
 todas["Larvitar"]["populacao"]=2
 todas["Larvitar"]["respawn"]=3.25
 var arquivo: FileAccess=FileAccess.open("res://dados/caca/hunts.json",FileAccess.WRITE)
 arquivo.store_string(JSON.stringify(todas));arquivo.close()
 CATALOGO.recarregar()
 var estado: Node=root.get_node("EstadoJogo")
 estado.especie_caca=load("res://dados/especies/larvitar.tres")
 estado.curar_time()
 var caca: Node=load("res://Caca.tscn").instantiate()
 root.add_child(caca)
 caca.set_process(false);caca.set_physics_process(false)
 await process_frame
 checar(caca.selvagens.size()==2,"População configurada aplicada")
 checar(is_equal_approx(caca.intervalo_respawn,3.25),"Respawn configurado aplicado")
 checar(caca.cenario_caca.scene_file_path==alternativa,"Cenário configurado carregado")
 checar(caca.selvagens[0].pokemon.especie.nome=="Larvitar","Espécie mantida")
 checar(caca.selvagens[0].imagem.recortes.size()==16,"Animação por espécie")
 arquivo=FileAccess.open("res://dados/caca/hunts.json",FileAccess.WRITE)
 arquivo.store_string(original);arquivo.close()
 CATALOGO.recarregar()
 caca.queue_free()
 await process_frame
 print("CONFIGURACAO HUNTS: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
