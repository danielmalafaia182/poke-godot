extends SceneTree
const REGISTRO=preload("res://especies_importadas.gd")
const VISUAL=preload("res://visual_pokemon.gd")
var falhas: int=0
var checks: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool, texto: String) -> void:
 checks+=1
 if not ok:
  falhas+=1
  push_error(texto)
func executar() -> void:
 var save: RefCounted=preload("res://salvamento_local.gd").new()
 var estado: Node=root.get_node("EstadoJogo")
 for nome in REGISTRO.obter_especies():
  var especie: DadosEspecie=REGISTRO.obter_especies()[nome]
  var p: DadosPokemon=DadosPokemon.new()
  p.especie=especie
  p.sortear_ivs();p.sortear_qualidade();p.normalizar_atributos()
  checar(preload("res://contrato_pokemon.gd").validar(p).is_empty(),"Contrato "+nome)
  checar(not especie.obter_base().is_empty(),"Base "+nome)
  var quadros: Array=VISUAL.recortar(nome)
  checar(quadros.size()==int(VISUAL.obter(nome)["quadros"])*4,"Direções completas "+nome)
  for q in quadros:
   checar(q.atlas!=null and q.region.end.x<=q.atlas.get_width() and q.region.end.y<=q.atlas.get_height(),"Recorte dentro da textura "+nome)
  checar(not preload("res://catalogo_golpes.gd").listar(nome,int(preload("res://catalogo_hunts.gd").obter(nome)["nivel"]),true).is_empty(),"Golpes "+nome)
  checar(estado.registrar_captura(p),"Captura "+nome)
  var restaurado: DadosPokemon=save._criar_pokemon(save._serializar_pokemon(p))
  checar(restaurado.especie==especie and restaurado.id_persistente==p.id_persistente and restaurado.obter_total_ivs()==p.obter_total_ivs(),"Roundtrip "+nome)
 var dados: Dictionary=save.construir_dados(estado)
 checar(save._validar(dados).is_empty(),"Save com todas as espécies")
 for nome in ["Bulbasaur","Charmander","Squirtle"]:
  estado.especie_caca=REGISTRO.obter_especies()[nome]
  estado.curar_time()
  var caca: Node=load("res://Caca.tscn").instantiate()
  root.add_child(caca)
  caca.set_process(false);caca.set_physics_process(false)
  await process_frame
  checar(caca.selvagens.size()==15 and caca.selvagens[0].pokemon.especie.nome==nome,"Hunt "+nome)
  caca.queue_free()
  await process_frame
 print("IMPORTACAO ESPECIES: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
