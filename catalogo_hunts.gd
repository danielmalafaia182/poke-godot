extends RefCounted
static var _dados: Dictionary = {}
static func recarregar() -> void:
 _dados.clear()
static func obter(nome: String) -> Dictionary:
 if _dados.is_empty():
  var leitura: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://dados/caca/hunts.json"))
  if not leitura is Dictionary: return {}
  _dados=leitura
 var resultado: Dictionary = _dados.get(nome,{})
 if not validar(resultado).is_empty():return {}
 var copia: Dictionary=resultado.duplicate(true)
 copia["regra_nivel_combate"]="configurado_localmente" if copia.has("nivel_combate") else "proxy_nivel_acesso_nao_confirmado"
 copia["nivel_combate"]=obter_nivel_combate(copia)
 return copia

static func obter_nivel_combate(dados: Dictionary) -> int:
 return int(dados.get("nivel_combate",dados.get("nivel",1)))

static func validar(dados: Dictionary) -> String:
 if dados.is_empty(): return "Caça não cadastrada."
 if dados.has("nivel_combate"):
  var n: Variant=dados["nivel_combate"]
  if not (n is int or n is float):return "Nível de combate inválido."
  if not is_finite(float(n)) or float(n)<1 or float(n)>100000 or float(n)!=floorf(float(n)):return "Nível de combate inválido."
 for campo in ["nivel","xp","vip","cenario","navegacao","inicio","pontos","populacao","respawn"]:
  if not dados.has(campo): return "Campo ausente: "+campo
 for campo in ["nivel","xp","vip","populacao","respawn"]:
  if not (dados[campo] is float or dados[campo] is int): return "Número inválido: "+campo
 if dados["nivel"]<1 or dados["xp"]<0 or dados["vip"]<0 or dados["respawn"]<=0: return "Valores inválidos."
 if not dados["cenario"] is String or not ResourceLoader.exists(dados["cenario"],"PackedScene"): return "Cenário indisponível."
 if not dados["navegacao"] is String or not FileAccess.file_exists(dados["navegacao"]): return "Navegação indisponível."
 if not _celula(dados["inicio"]): return "Posição inicial inválida."
 if not dados["pontos"] is Array or dados["populacao"]<1 or dados["populacao"]!=int(dados["populacao"]) or dados["populacao"]>dados["pontos"].size(): return "População inválida."
 var usados: Dictionary={}
 for ponto in dados["pontos"]:
  if not _celula(ponto): return "Ponto inválido."
  var chave: Vector2i=Vector2i(int(ponto[0]),int(ponto[1]))
  if usados.has(chave): return "Pontos duplicados."
  usados[chave]=true
 return ""

static func _celula(valor: Variant) -> bool:
 if not valor is Array or valor.size()!=2: return false
 for n in valor:
  if not (n is int or n is float): return false
  if n!=int(n): return false
 return true
