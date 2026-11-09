extends RefCounted
# Snapshot de experimento. Não referencia EstadoJogo nem o Pokémon capturável.
const CHAVES: Array[String]=["hp","atk","def","spAtk","spDef","speed"]
var especie: String=""
var nivel: int=1
var vida_maxima: int=1
var atributos: Dictionary={}
var origem: String="hipotese_local_nao_confirmada"
func serializar() -> Dictionary:
 return {"especie":especie,"nivel":nivel,"vida_maxima":vida_maxima,"atributos":atributos.duplicate(true),"origem":origem}
func configurar(dados: Dictionary) -> String:
 if not dados.get("especie") is String or str(dados["especie"]).is_empty():return "Espécie ausente."
 for campo in ["nivel","vida_maxima"]:
  var v: Variant=dados.get(campo)
  if not (v is int or v is float) or not is_finite(float(v)) or float(v)<1 or float(v)>1000000 or float(v)!=floorf(float(v)):return "Valor inválido: "+campo
 if not dados.get("atributos") is Dictionary:return "Atributos ausentes."
 for chave in CHAVES:
  var v: Variant=dados["atributos"].get(chave)
  if not (v is int or v is float) or not is_finite(float(v)) or float(v)<0 or float(v)>1000000 or float(v)!=floorf(float(v)):return "Atributo inválido: "+chave
 # Só confirma depois de validar tudo, sem aplicar parcialmente entradas inválidas.
 especie=str(dados["especie"]);nivel=int(dados["nivel"]);vida_maxima=int(dados["vida_maxima"])
 atributos=dados["atributos"].duplicate(true)
 return ""
