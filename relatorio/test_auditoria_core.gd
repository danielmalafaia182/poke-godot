extends SceneTree
const ESP=preload("res://especies_importadas.gd")
const HUNTS=preload("res://catalogo_hunts.gd")
const GOLPES=preload("res://catalogo_golpes.gd")
const DANO=preload("res://regras_dano_candidato.gd")
const REGRAS=preload("res://regras_pokemon.gd")
var saida: Dictionary={"hunts":[],"numericos":[],"pares_sem_dano":[],"checks":0,"falhas":[]}
func _initialize() -> void: call_deferred("executar")
func check(ok: bool, caso: String) -> void:
 saida.checks+=1
 if not ok: saida.falhas.append(caso)
func individuo(especie: DadosEspecie, nivel: int, iv: int=16, qualidade: float=1.0) -> DadosPokemon:
 var p: DadosPokemon=DadosPokemon.new()
 p.especie=especie;p.nivel=nivel;p.qualidade=qualidade;p.versao_atributos=1
 for campo in preload("res://contrato_pokemon.gd").CAMPOS_IV:p.set(campo,iv)
 return p
func executar() -> void:
 var estado: Node=root.get_node("EstadoJogo")
 estado.auto_potion=false;estado.auto_catch=false
 var especies: Dictionary=ESP.obter_especies()
 var nomes: Array=especies.keys();nomes.sort()
 var configs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/caca/hunts.json"))
 for nome in nomes:
  var c: Dictionary=HUNTS.obter(nome)
  var p: DadosPokemon=individuo(especies[nome],int(c.get("nivel_combate",1)))
  var ataques: Array[Dictionary]=GOLPES.listar(nome,p.nivel,true)
  var elegiveis: Array=[]
  for a in ataques:
   if not a.has("tm") and a.category in ["PHYSICAL","SPECIAL"] and int(a.power)>0:elegiveis.append(a.name)
  var linha: Dictionary={"especie":nome,"nivel_acesso":c.get("nivel"),"nivel_atributos":p.nivel,"nivel_formula":GOLPES.obter(nome).get("huntLevel"),"ataques_elegiveis":elegiveis,"hp_iv16_q1":preload("res://regras_vida_selvagem.gd").calcular(p),"config_valida":not c.is_empty()}
  check(not c.is_empty(),nome+" config")
  check(not preload("res://visual_pokemon.gd").obter(nome).is_empty(),nome+" visual")
  # Instancia a cena real de cada hunt; não simula vitória nem usa isso como prova de balanceamento.
  estado.especie_caca=especies[nome];estado.curar_time()
  var hunt: Node=load("res://Caca.tscn").instantiate()
  root.add_child(hunt)
  hunt.set_process(false);hunt.set_physics_process(false)
  hunt.timer_combate.stop()
  if is_instance_valid(hunt.timer_auto_potion):hunt.timer_auto_potion.stop()
  linha["populacao_real"]=hunt.selvagens.size()
  linha["populacao_esperada"]=c.get("populacao")
  linha["alvo_inicial"]=hunt.indice_alvo
  check(hunt.populacao_iniciada and hunt.selvagens.size()==int(c.populacao),nome+" inicializacao")
  for mob in hunt.selvagens:
   check(mob.pokemon.especie.nome==nome and mob.vida==mob.vida_maxima and mob.vida>0,nome+" nascimento")
  saida.hunts.append(linha)
  root.remove_child(hunt);hunt.free()
  if saida.hunts.size()%20==0:
   print("AUDITORIA HUNTS ",saida.hunts.size())
   await process_frame
 # Matriz nominal: aliado Lv1/8/80, IV16, q1, contra cada espécie no nível de sua hunt.
 for nivel in [1,8,80]:
  for a_nome in nomes:
   var a: DadosPokemon=individuo(especies[a_nome],nivel)
   var golpes: Array[Dictionary]=GOLPES.listar(a_nome,nivel,true)
   for d_nome in nomes:
    var d: DadosPokemon=individuo(especies[d_nome],int(HUNTS.obter(d_nome).nivel_combate))
    var maior: int=0
    for g in golpes:
     if g.has("tm") or g.category not in ["PHYSICAL","SPECIAL"]:continue
     maior=maxi(maior,DANO.nominal(a,d,g,false))
    saida.checks+=1
    if maior<=0:saida.pares_sem_dano.append({"aliado":a_nome,"nivel":nivel,"hunt":d_nome})
  print("AUDITORIA MATRIZ LV ",nivel)
 # Limites da curva, inclusive ambos os lados das mudanças de fórmula.
 for n in [1,2,8,149,150,151,249,250,251,99999,100000]:
  var xp: int=REGRAS.xp_total_para_nivel(n)
  check(int(REGRAS.progresso(xp).nivel)==n,"XP nivel "+str(n))
  if n>1:check(int(REGRAS.progresso(xp-1).nivel)==n-1,"XP anterior "+str(n))
  saida.numericos.append({"nivel":n,"xp":xp,"anterior":REGRAS.progresso(xp-1),"exato":REGRAS.progresso(xp)})
 # Precisão angular e célula: aplica as próprias funções da caça.
 estado.especie_caca=especies.Geodude;estado.curar_time()
 var hunt: Node=load("res://Caca.tscn").instantiate();root.add_child(hunt)
 hunt.set_process(false);hunt.set_physics_process(false);hunt.timer_combate.stop();hunt.timer_auto_potion.stop()
 for graus in [0.0,44.999999999,45.0,45.000000001,89.999999999,90.0,90.000000001,179.999999999,180.0,270.0,360.0]:
  var vetor: Vector2=Vector2.RIGHT.rotated(deg_to_rad(graus))
  var local: Vector2=Vector2(16,16)+vetor*32.0
  var celula: Vector2i=hunt.posicao_para_celula(hunt.cenario_caca.to_global(local))
  saida.numericos.append({"angulo":graus,"vetor":str(vetor),"x":vetor.x,"y":vetor.y,"celula":str(celula)})
 for x in [-32.00001,-32.0,-31.99999,-0.00001,0.0,0.00001,31.99999,32.0,32.00001]:
  var cel: Vector2i=hunt.posicao_para_celula(hunt.cenario_caca.to_global(Vector2(x,16)))
  check(cel.x==floori(float(Vector2(x,16).x)/32.0),"fronteira "+str(x))
  saida.numericos.append({"fronteira_x":x,"celula_x":cel.x})
 # Toda transição adjacente de toda célula navegável do mapa compartilhado.
 var transicoes: int=0
 for origem: Vector2i in hunt.celulas_acessiveis:
  for direcao: Vector2i in hunt.DIRECOES:
   var destino: Vector2i=origem+direcao
   var esperado: bool=hunt.celula_transitavel(origem) and hunt.celula_transitavel(destino)
   if direcao.x!=0 and direcao.y!=0:esperado=esperado and hunt.celula_transitavel(origem+Vector2i(direcao.x,0)) and hunt.celula_transitavel(origem+Vector2i(0,direcao.y))
   check(hunt.passagem_permitida(origem,destino)==esperado,"transicao "+str(origem)+str(destino))
   transicoes+=1
 saida["transicoes_estaticas"]=transicoes
 saida["celulas_acessiveis"]=hunt.celulas_acessiveis.size()
 root.remove_child(hunt);hunt.free()
 for dt in [-1.0,0.0,0.000000001,0.199999,0.2,0.200001,1.0,10.0]:
  var ag: RefCounted=preload("res://agenda_golpes.gd").new()
  ag.avancar_calibrado(dt)
  saida.numericos.append({"delta":dt,"tempo_agenda":ag.tempo,"residuo":ag.residuo_tick})
  check(ag.tempo>=0 and ag.residuo_tick>=0,"delta nao negativo")
 var f: FileAccess=FileAccess.open("res://auditoria_resultados.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(saida,"\t"));f.close()
 print("AUDITORIA CORE CONCLUIDA ",saida.checks," checks; ",saida.falhas.size()," falhas; pares sem dano ",saida.pares_sem_dano.size())
 quit(1 if not saida.falhas.is_empty() else 0)
