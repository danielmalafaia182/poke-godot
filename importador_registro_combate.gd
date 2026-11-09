extends RefCounted
# Importa exclusivamente diagnóstico local, sem deduplicar golpes ou mexer no jogo.
const LIMITE_BYTES: int=20*1024*1024
static func _mesmo_aliado(p: Dictionary, esperado: Dictionary) -> bool:
 for chave in ["nivel","hp_maximo","qualidade","power"]:
  if not (p.get(chave) is int or p.get(chave) is float):return false
 if p.get("especie")!=esperado["especie"] or int(p.get("nivel",-1))!=int(esperado["nivel"]):return false
 if p.get("atributos",{})!=esperado["atributos"]:return false
 if int(p.get("hp_maximo",-1))!=int(esperado["hp_maximo"]):return false
 if absf(float(p.get("qualidade",-1))-float(esperado["qualidade"]))>0.00501:return false
 return int(p.get("power",-1))==int(esperado["power"])
static func ler(caminho: String,caso: Dictionary) -> Dictionary:
 var f: FileAccess=FileAccess.open(caminho,FileAccess.READ)
 if f==null:return {"erro":"Não foi possível abrir o diagnóstico local."}
 if f.get_length()>LIMITE_BYTES:return {"erro":"Arquivo maior que20MB; use uma sessão menor."}
 var grupos: Dictionary={};var aceitos: int=0;var descartados: int=0;var sem_contexto: int=0;var invalidas: int=0;var linhas: int=0
 var ultima_hora: Dictionary={};var intervalos: Dictionary={};var modelos: Array=[]
 while not f.eof_reached():
  var linha: String=f.get_line();linhas+=1
  if linhas>20000:return {"erro":"Mais de20000 linhas; use uma sessão menor."}
  if linha.strip_edges().is_empty():continue
  var parser: JSON=JSON.new()
  if parser.parse(linha)!=OK:invalidas+=1;continue
  var bruto: Variant=parser.data
  if not bruto is Dictionary:invalidas+=1;continue
  if bruto.get("tipo")!="golpe":continue
  var d: Variant=bruto.get("dados",{})
  if not d is Dictionary:invalidas+=1;continue
  var s: Variant=d.get("estado_apos",{})
  if not s is Dictionary or not s.get("aliado") is Dictionary:sem_contexto+=1;continue
  if not _mesmo_aliado(s["aliado"],caso["aliado"]):descartados+=1;continue
  var inimigo: Dictionary={}
  for mob in s.get("selvagens",[]):
   if mob is Dictionary and mob.get("id")==d.get("encontro_id") and mob.get("pokemon") is Dictionary:inimigo=mob["pokemon"];break
  if inimigo.get("especie")!=caso["inimigo"]["especie"]:descartados+=1;continue
  if not (d.get("dano") is int or d.get("dano") is float) or not d.get("aliado") is bool:invalidas+=1;continue
  var direcao: String="causado" if d["aliado"] else "recebido"
  var nome: String=str(d.get("nome","sem_nome"));var chave: String=direcao+" · "+nome
  if not grupos.has(chave):grupos[chave]={"direcao":direcao,"nome":nome,"danos":[],"hp_removido":[]}
  grupos[chave]["danos"].append(int(d["dano"]))
  grupos[chave]["hp_removido"].append(int(d.get("vida_removida",d["dano"])))
  var modelo: String=str(d.get("regra_dano","desconhecido"))
  if not modelos.has(modelo):modelos.append(modelo)
  # Só mede intervalos quando o próprio diagnóstico informa o relógio do atacante.
  # Cada inimigo tem chave própria. Nunca agrupa todos os recebidos numa única taxa.
  var ator: String="aliado" if d["aliado"] else str(d.get("encontro_id",""))
  if (d.get("tempo_atacante") is int or d.get("tempo_atacante") is float) and not ator.is_empty():
   var t: float=float(d["tempo_atacante"])
   if ultima_hora.has(ator) and t>=float(ultima_hora[ator]):
    if not intervalos.has(ator):intervalos[ator]=[]
    intervalos[ator].append(snappedf(t-float(ultima_hora[ator]),0.001))
   ultima_hora[ator]=t
  aceitos+=1
 f.close()
 var resumo: Array=[]
 for chave in grupos:
  var g: Dictionary=grupos[chave];var referencia: Dictionary={}
  for obs in caso["golpes"]:
   if obs["direcao"]==g["direcao"] and obs["nome"]==g["nome"]:referencia=obs;break
  var fora: int=0
  if not referencia.is_empty():
   for n in g["danos"]:
    if n<referencia["danos"].min() or n>referencia["danos"].max():fora+=1
  resumo.append({"nome":g["nome"],"direcao":g["direcao"],"eventos":g["danos"].size(),"min":g["danos"].min(),"max":g["danos"].max(),"soma_dano":g["danos"].reduce(func(a,b):return a+b,0),"soma_hp_removido":g["hp_removido"].reduce(func(a,b):return a+b,0),"fora_da_faixa_amostrada_original":fora if not referencia.is_empty() else null})
 return {"schema":1,"arquivo":caminho.get_file(),"caso":caso["id"],"aceitos":aceitos,"descartados_perfil":descartados,"sem_contexto":sem_contexto,"linhas_invalidas":invalidas,"modelos_locais":modelos,"golpes":resumo,"intervalos_por_atacante_s":intervalos,"fidelidade_global_comprovada":false,"limites":["Exige espécie, nível, seis atributos, HP máximo, Power e qualidade compatíveis do aliado.","Qualidade comparada com tolerância de0,005; Geodude só tem precisão exibida de duas casas.","Os atributos originais dos selvagens continuam desconhecidos; mesma espécie não comprova mesmo defensor.","Intervalos locais incluem deslocamento e troca de alvo; não são uma taxa intrínseca comprovada.","Todos os eventos são contados, inclusive danos iguais e simultâneos.","Comparação de faixas amostradas não determina distribuição ou regra global do original."]}
