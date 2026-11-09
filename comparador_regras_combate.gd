extends RefCounted
const DANO=preload("res://regras_dano.gd")
const CATALOGO=preload("res://catalogo_golpes.gd")
const PERFIL=preload("res://perfil_combate_laboratorio.gd")
const AGENDA=preload("res://agenda_golpes.gd")
static func casos() -> Array:
 return JSON.parse_string(FileAccess.get_file_as_string("res://dados/combate/casos_comparador.json"))["casos"].duplicate(true)
static func pokemon(dados: Dictionary) -> DadosPokemon:
 var p: DadosPokemon=DadosPokemon.new()
 p.especie=preload("res://especies_importadas.gd").obter_especies()[dados["especie"]]
 p.nivel=int(dados.get("nivel",1));p.qualidade=float(dados.get("qualidade",1.0))
 var campos: Array[String]=["iv_hp","iv_atk","iv_def","iv_sp_atk","iv_sp_def","iv_spd"]
 var ivs: Array=dados.get("ivs",[16,16,16,16,16,16])
 for i in range(6):p.set(campos[i],int(ivs[i]))
 return p
static func perfil_padrao(caso: Dictionary) -> Dictionary:
 var nome: String=caso["inimigo"]["especie"]
 var lv: int=int(preload("res://catalogo_hunts.gd").obter(nome)["nivel"])
 var p: DadosPokemon=pokemon({"especie":nome,"nivel":lv})
 return {"especie":nome,"nivel":lv,"vida_maxima":p.obter_vida_maxima()*5,"atributos":p.obter_atributos(),"origem":"prototipo_com_IV16_qualidade1_hipotese"}
static func _golpe(especie: String,nome: String) -> Dictionary:
 for g in CATALOGO.listar(especie,100000):
  if g["name"]==nome:return g
 return {}
static func _fator(g: Dictionary, especie: String) -> float:
 var b: Dictionary=preload("res://regras_pokemon.gd").obter_base(especie)
 return DANO.amplificar_elemento(CATALOGO.efetividade(str(g.get("type","NORMAL")),str(b.get("type1","")),str(b.get("type2",""))))
static func _prever(g: Dictionary,a: Dictionary,d: Dictionary,selvagem: bool,v2: bool) -> float:
 if g.has("tm"):return 0.0
 return DANO.calcular_atributos(int(a["nivel"]),a["atributos"],d["atributos"],g,_fator(g,str(d["especie"])),selvagem,v2)
static func _agenda(a: Dictionary,d: Dictionary,selvagem: bool,v2: bool) -> RefCounted:
 var ag: RefCounted=AGENDA.new();ag.configurar(a["especie"],int(a["nivel"]))
 return ag
static func _retirar(ag: RefCounted,a: Dictionary,d: Dictionary,selvagem: bool,v2: bool) -> Dictionary:
 var avaliar: Callable=func(g: Dictionary) -> float:return _prever(g,a,d,selvagem,v2)
 if v2:return ag.retirar_calibrado(2.0 if selvagem else 1.5,avaliar)
 return ag.retirar_pronto(false,1.5,avaliar if selvagem else Callable())
static func _tempos(a: Dictionary,d: Dictionary,selvagem: bool,v2: bool) -> Array:
 var ag: RefCounted=_agenda(a,d,selvagem,v2);var ts: Array=[]
 for i in range(601):
  if not _retirar(ag,a,d,selvagem,v2).is_empty():ts.append(snappedf(ag.tempo+ag.residuo_tick,0.001))
  if v2:ag.avancar_calibrado(1.0/60.0)
  else:ag.avancar(1.0/60.0)
 return ts
static func atributos_iguais(a: Dictionary,b: Dictionary) -> bool:
 if a.size()!=b.size():return false
 for chave in PERFIL.CHAVES:
  if not a.has(chave) or not b.has(chave):return false
  if float(a[chave])!=float(b[chave]):return false
 return true
static func contem_numero(valores: Array,procurado: float) -> bool:
 # JSON lê números como float; Array.has diferencia int de float no Godot.
 for valor in valores:
  if (valor is int or valor is float) and is_finite(float(valor)) and float(valor)==procurado:return true
 return false
static func _linha(metrica: String, original: Variant, local: Variant,status: String,nota: String="") -> Dictionary:
 return {"metrica":metrica,"original":original,"local":local,"status":status,"nota":nota}
static func comparar(caso: Dictionary,hipotese: Dictionary={},modelo: String="v2") -> Dictionary:
 var dados: Dictionary=perfil_padrao(caso) if hipotese.is_empty() else hipotese.duplicate(true)
 var perfil: RefCounted=PERFIL.new();var erro: String=perfil.configurar(dados)
 if not erro.is_empty():return {"erro":erro}
 if perfil.especie!=caso["inimigo"]["especie"]:return {"erro":"O perfil deve ter a espécie do caso selecionado."}
 var v2: bool=modelo=="v2"
 var a: DadosPokemon=pokemon(caso["aliado"])
 var aliado: Dictionary={"especie":a.especie.nome,"nivel":a.nivel,"atributos":a.obter_atributos(),"vida_maxima":a.obter_vida_maxima()}
 var inimigo: Dictionary=perfil.serializar()
 var linhas: Array=[]
 for chave in ["hp_maximo","power","atributos"]:
  var valor: Variant=a.obter_vida_maxima() if chave=="hp_maximo" else (a.obter_power() if chave=="power" else a.obter_atributos())
  linhas.append(_linha("Aliado · "+chave,caso["aliado"][chave],valor,"COINCIDE" if (atributos_iguais(valor,caso["aliado"][chave]) if chave=="atributos" else valor==caso["aliado"][chave]) else "DIVERGE","IVs da fixture: "+caso["aliado"]["origem_ivs"]))
 var hps: Array=caso["inimigo"]["hp_maximos_observados"]
 linhas.append(_linha("Selvagem · HP máximo",hps,inimigo["vida_maxima"],"COMPATÍVEL SOB HIPÓTESE" if contem_numero(hps,float(inimigo["vida_maxima"])) else "DIVERGE","Esta hipótese fixa é comparada aos HPs amostrados, sem validar a distribuição de IV/qualidade. Um HP não determina nível, Def ou SpDef."))
 linhas.append(_linha("Selvagem · nível e atributos","desconhecidos",{"nivel":inimigo["nivel"],"atributos":inimigo["atributos"]},"NÃO VALIDÁVEL","Entradas hipotéticas independentes do Pokémon capturável."))
 for lado_selvagem in [false,true]:
  var atacante: Dictionary=inimigo if lado_selvagem else aliado
  var defensor: Dictionary=aliado if lado_selvagem else inimigo
  var ag: RefCounted=_agenda(atacante,defensor,lado_selvagem,v2)
  var escolhido: Dictionary=_retirar(ag,atacante,defensor,lado_selvagem,v2)
  var originais: Array=[]
  for g in caso["golpes"]:
   if g["direcao"]==("recebido" if lado_selvagem else "causado"):originais.append(g["nome"])
  var status: String="NÃO VALIDÁVEL" if originais.is_empty() else ("COMPATÍVEL SOB HIPÓTESE" if originais.has(escolhido.get("name","")) else "DIVERGE")
  linhas.append(_linha("Golpe do selvagem" if lado_selvagem else "Golpe do aliado",originais,escolhido.get("name","nenhum"),status,"Seleção avaliada nesta hipótese. Ausência de golpe recebido no log não comprova que o selvagem não ataca."))
 var detalhes: Array=[]
 for obs in caso["golpes"]:
  var selvagem: bool=obs["direcao"]=="recebido"
  var atacante: Dictionary=inimigo if selvagem else aliado
  var defensor: Dictionary=aliado if selvagem else inimigo
  var g: Dictionary=_golpe(atacante["especie"],obs["nome"])
  if g.is_empty():
   linhas.append(_linha(obs["direcao"]+" · "+obs["nome"],obs["danos"],null,"NÃO VALIDÁVEL","Golpe ausente no catálogo."));continue
  var dano: int=int(_prever(g,atacante,defensor,selvagem,v2))
  var minimo: int=int(obs["danos"].min());var maximo: int=int(obs["danos"].max())
  var status: String="COMPATÍVEL SOB HIPÓTESE" if dano>=minimo and dano<=maximo else "DIVERGE"
  var atributo: String="Def" if g["category"]=="PHYSICAL" else "SpDef"
  linhas.append(_linha(obs["direcao"]+" · "+g["name"]+" · "+g["category"],{"min":minimo,"max":maximo,"eventos":obs["danos"].size()},dano,status,"Faltam os atributos originais do selvagem. Compatibilidade numérica não valida a fórmula."))
  var efetividade: float=_fator(g,defensor["especie"])
  linhas.append(_linha("Efetividade · "+g["name"],obs["efetividades"],efetividade,"COINCIDE" if contem_numero(obs["efetividades"],efetividade) else "DIVERGE"))
  var tempos: Array=_tempos(atacante,defensor,selvagem,v2)
  var intervalo_local: Variant=snappedf((float(tempos[1])-float(tempos[0]))*1000,1) if tempos.size()>1 else null
  var positivos: Array=[];var agrupados: int=0
  for dt in obs["intervalos_pacotes_ms"]:
   if dt>0:positivos.append(dt)
   else:agrupados+=1
  var curto: Variant=positivos.min() if not positivos.is_empty() else null
  linhas.append(_linha("Intervalos · "+g["name"],{"menor_pacote_ms":curto,"intervalos_zero_ms":agrupados},intervalo_local,"INCONCLUSIVO","Intervalos de pacotes incluem movimento/trocas e agrupamentos; não medem execução individual. "+("Há intervalo positivo menor que o perfil local: investigar." if curto!=null and intervalo_local!=null and float(curto)+50<float(intervalo_local) else "")))
  var sensibilidade: Array=[]
  for escala in [0.5,1.0,2.0]:
   var alt: Dictionary=defensor.duplicate(true);var chave: String="def" if g["category"]=="PHYSICAL" else "spDef"
   alt["atributos"][chave]=maxi(1,roundi(float(alt["atributos"][chave])*escala))
   sensibilidade.append({"defesa":alt["atributos"][chave],"dano":_prever(g,atacante,alt,selvagem,v2)})
  detalhes.append({"nome":g["name"],"direcao":obs["direcao"],"categoria":g["category"],"dano_local":dano,"intervalo_original":[minimo,maximo],"diferenca_ate_faixa":dano-minimo if dano<minimo else (dano-maximo if dano>maximo else 0),"atributo_defensivo":atributo,"sensibilidade":sensibilidade,"tempos_simulados_s":tempos,"golpes_para_ko_sem_cura":ceili(float(defensor["vida_maxima"])/dano) if dano>0 else null})
 return {"schema":1,"caso":caso["id"],"titulo":caso["titulo"],"modelo_local":modelo,"fidelidade_global_comprovada":false,"fonte":caso["fonte"],"fixture_aliado":caso["aliado"].duplicate(true),"aliado":aliado,"perfil_combate_selvagem_hipotetico":inimigo,"referencia_capturavel_local":pokemon({"especie":inimigo["especie"],"nivel":1}).obter_atributos(),"linhas":linhas,"golpes":detalhes,"limites":["As observações não revelam os atributos nem o nível de combate dos selvagens.","Alterar o perfil neste laboratório não muda a caça nem o Pokémon capturado.","O dano usa a regra local da caça. Compatibilidade sob hipótese não identifica uma fórmula única.","As faixas originais contêm vários selvagens; a simulação é um duelo de atributos fixos.","O nível1 da referência capturável é um exemplo local, sem vínculo demonstrado com o inimigo observado."]}
