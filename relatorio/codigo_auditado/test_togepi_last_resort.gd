extends SceneTree
func _initialize() -> void:
 var golpes: Array=preload("res://catalogo_golpes.gd").listar("Togepi",1,true)
 assert(golpes.size()==1)
 assert(golpes[0]["name"]=="Last Resort" and golpes[0]["learnLevel"]==1 and golpes[0]["learnLevelCatalogo"]==49)
 var bruto: Dictionary=preload("res://catalogo_golpes.gd").obter("Togepi")
 for g in bruto["attacks"]:
  if g["name"]=="Last Resort": assert(g["learnLevel"]==49)
 var agenda: RefCounted=preload("res://agenda_golpes.gd").new()
 agenda.configurar("Togepi",1)
 assert(agenda.retirar_pronto(false,1.5)["name"]=="Last Resort")
 assert(agenda.retirar_pronto(false,1.5).is_empty())
 print("TOGEPI LAST RESORT: 5 verificações; 0 falhas")
 quit()
