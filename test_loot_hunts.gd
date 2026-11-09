extends SceneTree
const LOOT=preload("res://regras_loot.gd")
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool,t: String) -> void:
 checks+=1
 if not ok:falhas+=1;push_error(t)
func executar() -> void:
 var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=42
 var estado: Node=root.get_node("EstadoJogo")
 var bolas: Dictionary=estado.estoque_bolas.duplicate()
 var dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/referencias/loot_hunts.json"))
 var ids: Dictionary={}
 for item in LOOT.catalogo():
  checar(not ids.has(int(item["id"])),"ID local único")
  ids[int(item["id"])]=true
  checar(ResourceLoader.exists(item["icone"]),"Ícone ou marcador disponível")
  checar(int(item["id"]) not in [1,2,3,4,5,6,7,200,201,202,203,204],"Loot não colide com consumíveis")
 for nome in dados["especies"]:
  for i in range(15):
   var eventos: Array[Dictionary]=LOOT.sortear(nome,rng)
   var recebidos: Array[Dictionary]=estado.inventario.receber_loot(eventos)
   checar(recebidos.size()==eventos.size(),"Recebe drops de "+str(nome))
   for e in eventos:checar(e["qty"]>0 and not LOOT.obter(int(e["itemId"])).is_empty(),"Drop reconhecido")
 checar(estado.estoque_bolas==bolas,"Drops não alteram Pokébolas")
 var polen: Dictionary={}
 for item in LOOT.catalogo():
  if item["nome"]=="Bag of Pollen":polen=item
 checar(not polen.is_empty() and polen["id"]==1000004 and polen["id_original"]==4,"Alias conserva identidade original")
 var id: int=int(polen["id"])
 var lote: Array[Dictionary]=[{"itemId":id,"qty":2}]
 estado.inventario.receber_loot(lote)
 var total: int=estado.inventario.quantidade_item_bag(id)
 checar(estado.inventario.mover_item_depot(id,true).is_empty(),"Guarda material no depot")
 checar(estado.inventario.quantidade_item_bag(id)==0 and estado.itens_depot.get(id,0)==total,"Estoque transferido")
 var save: RefCounted=preload("res://salvamento_local.gd").new()
 var snapshot: Dictionary=save.construir_dados(estado)
 checar(save._validar(snapshot).is_empty(),"Save aceita catálogo expandido")
 save._restaurar(estado,snapshot)
 checar(estado.itens_depot.get(id,0)==total,"Reload conserva material")
 print("LOOT HUNTS: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
