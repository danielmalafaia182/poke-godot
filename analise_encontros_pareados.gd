extends RefCounted
# Testa hipóteses. Não sorteia dano nem escreve no EstadoJogo ou no combate.
const DANO=preload("res://regras_dano.gd")
const CAT=preload("res://catalogo_golpes.gd")
const LIMITE_DEFESA: int=5000
const LIMITE_COMBINACOES: int=20000
var amostra: Dictionary={}
var series: Dictionary={}
var cache_grupos: Dictionary={}
var cache_familias: Dictionary={}
static func carregar() -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/amostra_pareada_20261107.json"))
static func familias() -> Array:
 var r: Array=[]
 for bonus in [1.0,1.5]:
  var sufixo: String="" if bonus==1.0 else "_stab15"
  var prefixo: String="Sem STAB · " if bonus==1.0 else "STAB×1,5 · "
  for p in [0,5,10,15,20,25,30]:
   r.append({"id":"sim_"+str(p)+sufixo,"nome":prefixo+("sem variação" if p==0 else "±%d%%" % p),"minimo":1.0-p/100.0,"maximo":1.0+p/100.0,"bonus_tipo":bonus})
  r.append({"id":"085_100"+sufixo,"nome":prefixo+"85–100%","minimo":0.85,"maximo":1.0,"bonus_tipo":bonus})
 return r
func _bonus(pid: String,g: Dictionary,f: Dictionary) -> float:
 return float(f.get("bonus_tipo",1.0)) if str(g["type"]) in amostra["perfis"][pid].get("tipos",[]) else 1.0
func iniciar(dados: Dictionary) -> void:
 amostra=dados.duplicate(true);series.clear();cache_grupos.clear();cache_familias.clear()
func encontros(pareados_apenas: bool=false) -> Array:
 var r: Array=[]
 for e in amostra.get("encontros",[]):
  if not pareados_apenas or e["pareado"]:r.append(e.duplicate(true))
 r.sort_custom(func(a,b):return a["golpes"][0]["t_s"]<b["golpes"][0]["t_s"])
 return r
func _golpe(perfil: Dictionary,nome: String) -> Dictionary:
 for g in CAT.listar(perfil["especie"],int(perfil["nivel"]),true):
  if g["name"]==nome:return g
 return {}
func _fator(g: Dictionary) -> float:
 var b: Dictionary=preload("res://regras_pokemon.gd").obter_base("Blastoise")
 return DANO.amplificar_elemento(CAT.efetividade(str(g["type"]),str(b["type1"]),str(b.get("type2",""))))
func _serie(pid: String,g: Dictionary,efetividade: float) -> PackedFloat64Array:
 var chave: String=pid+"|"+str(g["name"])+"|"+str(efetividade)
 if series.has(chave):return series[chave]
 var p: Dictionary=amostra["perfis"][pid]
 var a: PackedFloat64Array=PackedFloat64Array();a.resize(LIMITE_DEFESA)
 var d: Dictionary={"def":1,"spDef":1}
 var campo: String="def" if g["category"]=="PHYSICAL" else "spDef"
 for i in range(LIMITE_DEFESA):
  d[campo]=i+1
  a[i]=DANO.calcular_bruto_atributos(int(p["nivel"]),p["atributos"],d,g,efetividade)
 series[chave]=a;return a
func grupos(e: Dictionary) -> Array:
 if cache_grupos.has(e["id_local"]):return cache_grupos[e["id_local"]].duplicate(true)
 var gs: Dictionary={}
 for h in e["golpes"]:
  var pid: Variant=h.get("perfil_id")
  if pid==null or not amostra["perfis"].has(pid):return []
  var chave: String=str(pid)+"|"+str(h["golpe"])+"|"+str(h["efetividade"])
  if not gs.has(chave):
   var g: Dictionary=_golpe(amostra["perfis"][pid],h["golpe"])
   if g.is_empty() or g["category"] not in ["PHYSICAL","SPECIAL"]:return []
   gs[chave]={"perfil_id":pid,"golpe":g,"categoria":g["category"],"campo":"def" if g["category"]=="PHYSICAL" else "spDef","efetividade":h["efetividade"],"danos":[]}
  gs[chave]["danos"].append(int(h["dano"]))
 var r: Array=[]
 for g in gs.values():
  g["min_observado"]=g["danos"].min();g["max_observado"]=g["danos"].max()
  # Limite inferior sob multiplicador simétrico contínuo + arredondamento final.
  var razao: float=(float(g["max_observado"])-0.5)/(float(g["min_observado"])+0.5)
  g["dispersao_minima_simetrica_pct"]=maxf(0.0,100.0*(razao-1.0)/(razao+1.0))
  r.append(g)
 cache_grupos[e["id_local"]]=r
 return r.duplicate(true)
func melhor_golpe(pid: String,defesa: int,spdef: int,f: Dictionary={}) -> String:
 var p: Dictionary=amostra["perfis"][pid];var nome: String="";var maior: int=0
 var d: Dictionary={"def":defesa,"spDef":spdef}
 for g in CAT.listar(p["especie"],int(p["nivel"]),true):
  if g.has("tm") or g["category"] not in ["PHYSICAL","SPECIAL"] or int(g["power"])<=0:continue
  var dano: int=DANO.finalizar_dano(DANO.calcular_bruto_atributos(int(p["nivel"]),p["atributos"],d,g,_fator(g))*_bonus(pid,g,f))
  if dano>maior:maior=dano;nome=str(g["name"])
 return nome
func _escolhas_conferem(gs: Array,d: int,s: int,f: Dictionary) -> bool:
 var melhores: Dictionary={}
 for g in gs:
  var pid: String=g["perfil_id"]
  if not melhores.has(pid):melhores[pid]=melhor_golpe(pid,d,s,f)
  if melhores[pid]!=g["golpe"]["name"]:return false
 return true
func _eixo(gs: Array,campo: String,f: Dictionary) -> Array[int]:
 var restricoes: Array=[]
 for g in gs:
  if g["campo"]!=campo:continue
  if int(g["min_observado"])<=2:return [] # Esta análise trabalha com dano acima do piso.
  restricoes.append({"serie":_serie(g["perfil_id"],g["golpe"],float(g["efetividade"])),"bonus":_bonus(g["perfil_id"],g["golpe"],f),
   "minimo":(float(g["max_observado"])-0.5)/float(f["maximo"]),
   "maximo":(float(g["min_observado"])+0.5)/float(f["minimo"])})
 var validos: Array[int]=[]
 for i in range(LIMITE_DEFESA):
  var ok: bool=true
  for r in restricoes:
   var bruto: float=r["serie"][i]*float(r["bonus"])
   if bruto<float(r["minimo"]) or bruto>=float(r["maximo"]):ok=false;break
  if ok:validos.append(i+1)
 return validos
func _resumo_eixo(v: Array[int],gs: Array,campo: String) -> Dictionary:
 var observado: bool=false
 for g in gs:
  if g["campo"]==campo:observado=true
 return {"observado":observado,"minimo":v.front() if not v.is_empty() else null,"maximo":v.back() if not v.is_empty() else null,"quantidade":v.size(),"nota":"Limites marginais, condicionados à fórmula e ao multiplicador; não são IVs nem atributos revelados."}
func hipotese(e: Dictionary,defesa: int,spdef: int,f: Dictionary) -> Dictionary:
 if defesa<1 or spdef<1 or defesa>LIMITE_DEFESA or spdef>LIMITE_DEFESA:return {"erro":"Defesas fora da faixa1–5000."}
 var gs: Array=grupos(e);var predicoes: Array=[];var todos: bool=not gs.is_empty()
 for g in gs:
  var val: int=defesa if g["campo"]=="def" else spdef
  var bruto: float=_serie(g["perfil_id"],g["golpe"],float(g["efetividade"]))[val-1]*_bonus(g["perfil_id"],g["golpe"],f)
  var menor: int=DANO.finalizar_dano(bruto*float(f["minimo"]))
  var maior: int=DANO.finalizar_dano(bruto*float(f["maximo"]))
  var ok: bool=int(g["min_observado"])>=menor and int(g["max_observado"])<=maior
  todos=todos and ok
  predicoes.append({"perfil_id":g["perfil_id"],"golpe":g["golpe"]["name"],"categoria":g["categoria"],"observados":g["danos"],"nominal":DANO.finalizar_dano(bruto),"faixa_hipotetica":[menor,maior],"compativel":ok,"melhor_nominal":melhor_golpe(g["perfil_id"],defesa,spdef,f),"dispersao_minima_simetrica_pct":g["dispersao_minima_simetrica_pct"]})
 return {"id_local":e["id_local"],"def":defesa,"spDef":spdef,"familia":f,"danos_compativeis":todos,"escolhas_nominais_compativeis":_escolhas_conferem(gs,defesa,spdef,f),"grupos":predicoes,"fidelidade_global_comprovada":false}
func analisar_familia(e: Dictionary,f: Dictionary) -> Dictionary:
 var chave: String=e["id_local"]+"|"+f["id"]
 if cache_familias.has(chave):return cache_familias[chave].duplicate(true)
 var gs: Array=grupos(e)
 if int(e["species_id"])!=9 or not e["elegivel_ajuste"] or gs.is_empty():return {"id_local":e["id_local"],"erro":"Encontro não elegível, perfil ambíguo ou espécie fora da referência Blastoise."}
 var ds: Array[int]=_eixo(gs,"def",f);var ss: Array[int]=_eixo(gs,"spDef",f)
 var resultado: Dictionary={"id_local":e["id_local"],"familia":f,"dano_compativel_na_busca":not ds.is_empty() and not ss.is_empty(),"def":_resumo_eixo(ds,gs,"def"),"spDef":_resumo_eixo(ss,gs,"spDef"),"exemplo":{},"combinacoes_testadas":0,"escolha":"SEM PERFIL DE DANO NA BUSCA","fidelidade_global_comprovada":false}
 if resultado["dano_compativel_na_busca"]:
  # Candidatos extremos/meio primeiro; depois busca limitada sem afirmar inexistência fora dela.
  var pares: Array=[]
  for d in [ds.front(),ds.back(),ds[ds.size()/2]]:
   for s in [ss.front(),ss.back(),ss[ss.size()/2]]:pares.append(Vector2i(d,s))
  var testados: Dictionary={}
  var encontrado: bool=false
  for par in pares:
   if testados.has(par):continue
   testados[par]=true
   if _escolhas_conferem(gs,par.x,par.y,f):
    resultado["exemplo"]={"def":par.x,"spDef":par.y};encontrado=true;break
  if not encontrado:
   for d in ds:
    for s in ss:
     var par: Vector2i=Vector2i(d,s)
     if testados.has(par):continue
     if testados.size()>=LIMITE_COMBINACOES:break
     testados[par]=true
     if _escolhas_conferem(gs,d,s,f):
      resultado["exemplo"]={"def":d,"spDef":s};encontrado=true;break
    if encontrado or testados.size()>=LIMITE_COMBINACOES:break
  resultado["combinacoes_testadas"]=testados.size()
  if encontrado:
   # Quando só há ataques especiais, Def não é restringida pelo dano.
   # Reduz o exemplo até o menor valor que mantém a escolha nominal, em vez
   # de exibir arbitrariamente5000 só por ser o extremo da busca.
   var campo_livre: String="def" if not resultado["def"]["observado"] else ("spDef" if not resultado["spDef"]["observado"] else "")
   if not campo_livre.is_empty():
    var baixo: int=1;var alto: int=resultado["exemplo"][campo_livre]
    while baixo<alto:
     var meio: int=(baixo+alto)/2
     var d: int=meio if campo_livre=="def" else int(resultado["exemplo"]["def"])
     var sp: int=meio if campo_livre=="spDef" else int(resultado["exemplo"]["spDef"])
     testados[Vector2i(d,sp)]=true
     if _escolhas_conferem(gs,d,sp,f):alto=meio
     else:baixo=meio+1
    resultado["exemplo"][campo_livre]=baixo
    resultado["combinacoes_testadas"]=testados.size()
   resultado["escolha"]="COMPATÍVEL SOB HIPÓTESE"
  elif testados.size()<ds.size()*ss.size():resultado["escolha"]="INCONCLUSIVO · LIMITE DE BUSCA"
  else:resultado["escolha"]="NÃO EXPLICA ESCOLHA NOMINAL NA BUSCA"
 cache_familias[chave]=resultado
 return resultado.duplicate(true)
func analisar_todos() -> Dictionary:
 var resultados: Array=[]
 var todos: Array=encontros();var pareados: Array=encontros(true)
 for f in familias():
  var rs: Array=[];var controles: Array=[];var n_dano: int=0;var n_escolha: int=0
  var n_sessao_dano: int=0;var n_sessao_escolha: int=0;var elegiveis: int=0
  for e in todos:
   var r: Dictionary=analisar_familia(e,f)
   if e["pareado"]:rs.append(r)
   else:controles.append(r)
   if e["elegivel_ajuste"]:elegiveis+=1
   if r.get("dano_compativel_na_busca",false):
    n_sessao_dano+=1
    if e["pareado"]:n_dano+=1
   if r.get("escolha","")=="COMPATÍVEL SOB HIPÓTESE":
    n_sessao_escolha+=1
    if e["pareado"]:n_escolha+=1
  resultados.append({"familia":f,"pareados_com_dano_compativel":n_dano,"pareados_com_dano_e_escolha":n_escolha,"total_pareados":pareados.size(),"sessao_com_dano_compativel":n_sessao_dano,"sessao_com_dano_e_escolha":n_sessao_escolha,"total_encontros":todos.size(),"total_elegiveis":elegiveis,"encontros":rs,"controles_sem_troca":controles})
 return {"schema":1,"fonte":amostra["fonte"],"limite_defesa":LIMITE_DEFESA,"limite_combinacoes":LIMITE_COMBINACOES,"familias":resultados,"fidelidade_global_comprovada":false,"limites":["Def e SpDef inteiras entre1 e5000, fixas dentro de cada encontro e diferentes entre encontros.","STAB×1,5 também é uma hipótese: só para golpe do mesmo tipo observado do atacante. Não é aplicado no jogo real.","Multiplicador aplicado ao dano bruto (após o STAB hipotético) antes do arredondamento e do piso local. Só compara compatibilidade, não frequência/distribuição.","A política adicional testa maior dano nominal antes da variação, sem TMs; não está comprovada como regra universal do original.","As faixas marginais não significam que toda combinação Def/SpDef satisfaça a escolha de golpe.","A busca não impõe uma fórmula original de geração por nível/IV/qualidade; existência matemática não prova um Pokémon possível no servidor.","Nenhum ajuste é aplicado ao combate real ou ao save.","Identidades são inferidas por slot, morte e continuidade de HP; horários são dos pacotes.","Buffs, críticos, categoria/power diferentes ou outra fórmula também podem explicar variação; RNG não foi demonstrado."]}
