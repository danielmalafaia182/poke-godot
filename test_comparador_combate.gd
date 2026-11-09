extends SceneTree
const MOTOR=preload("res://comparador_regras_combate.gd")
const PERFIL=preload("res://perfil_combate_laboratorio.gd")
const DANO=preload("res://regras_dano.gd")
const IMP=preload("res://importador_registro_combate.gd")
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
 checks+=1
 if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func executar() -> void:
 var casos: Array=MOTOR.casos();check(casos.size()==3,"três referências extraídas dos logs originais")
 var relatorios: Array=[]
 for caso in casos:
  var r: Dictionary=MOTOR.comparar(caso);relatorios.append(r)
  check(not r.has("erro") and not r["fidelidade_global_comprovada"],"resultado explícito sem afirmar fidelidade global")
  for linha in r["linhas"]:
   if linha["metrica"].begins_with("Aliado"):check(linha["status"]=="COINCIDE","HP/Power/atributos reproduzem observação "+caso["titulo"])
   if linha["metrica"].begins_with("Intervalos"):check(linha["status"]=="INCONCLUSIVO","pacotes não viram taxa de execução comprovada")
   if linha["metrica"]=="Golpe do selvagem":check(linha["status"]==("NÃO VALIDÁVEL" if caso["aliado"]["especie"]=="Exeggutor" else "COMPATÍVEL SOB HIPÓTESE"),"escolha inimiga comparada apenas quando observada")
   if linha["metrica"].begins_with("Selvagem · nível"):check(linha["status"]=="NÃO VALIDÁVEL","atributos originais ausentes não são inventados")
  var captura: Dictionary=r["referencia_capturavel_local"].duplicate(true)
  var hipotese: Dictionary=MOTOR.perfil_padrao(caso);hipotese["nivel"]+=10;hipotese["atributos"]["def"]*=2
  var outro: Dictionary=MOTOR.comparar(caso,hipotese)
  check(outro["perfil_combate_selvagem_hipotetico"]["nivel"]==hipotese["nivel"] and outro["referencia_capturavel_local"]==captura,"perfil de combate separado da referência capturável")
  check(caso==MOTOR.casos()[casos.find(caso)],"experimento não altera evidência original")
 var hp_geo: Array=relatorios[0]["linhas"].filter(func(l: Dictionary) -> bool:return l["metrica"]=="Selvagem · HP máximo")
 check(hp_geo[0]["status"]=="COMPATÍVEL SOB HIPÓTESE","120 float do JSON coincide numericamente com120 int do perfil")
 check(MOTOR.contem_numero([120.0],120) and MOTOR.contem_numero([120],120.0),"busca numérica independente de tipo int/float")
 check(not MOTOR.contem_numero([120.5],120.0),"busca numérica não trunca valores fracionários")
 var hp_blast: Array=relatorios[2]["linhas"].filter(func(l: Dictionary) -> bool:return l["metrica"]=="Selvagem · HP máximo")
 check(hp_blast[0]["status"]=="DIVERGE","5340 continua divergente dos HPs amostrados de Blastoise")
 var geo: Dictionary=relatorios[0]
 check(geo["golpes"][0]["dano_local"]==2 and geo["golpes"][1]["dano_local"]==1,"duelo controlado permanece2/1")
 var antigo: Dictionary=MOTOR.comparar(casos[0],{},"v1")
 check(antigo["golpes"][0]["dano_local"]==1 and antigo["golpes"][1]["dano_local"]==2,"comparação mantém legado1/2")
 check(relatorios[1]["golpes"][0]["categoria"]=="SPECIAL" and relatorios[2]["golpes"][0]["categoria"]=="PHYSICAL","amostras cobrem especial e físico")
 check(relatorios[1]["golpes"].size()==1,"Exeggutor não recebe por engano os Skull Bash do Gyarados")
 check(relatorios[2]["golpes"][1]["intervalo_original"]==[34,37],"Skull Bash atribuído ao aliado correto")
 check(is_equal_approx(float(geo["golpes"][0]["tempos_simulados_s"][1]),1.6) and is_equal_approx(float(geo["golpes"][1]["tempos_simulados_s"][1]),2.0),"simulação usa as agendas de produção")
 var perfil: RefCounted=PERFIL.new();var dados: Dictionary=MOTOR.perfil_padrao(casos[0])
 check(perfil.configurar(dados).is_empty(),"perfil válido")
 var antes_perfil: Dictionary=perfil.serializar();dados["atributos"]["atk"]=NAN
 check(not perfil.configurar(dados).is_empty() and perfil.serializar()==antes_perfil,"entrada inválida não aplica parte do perfil")
 var a: DadosPokemon=MOTOR.pokemon(casos[1]["aliado"]);var d: DadosPokemon=MOTOR.pokemon({"especie":"Blastoise","nivel":80})
 var fis: Dictionary={"type":"NORMAL","category":"PHYSICAL","power":100}
 var esp: Dictionary={"type":"NORMAL","category":"SPECIAL","power":100}
 var atributos: Dictionary=d.obter_atributos();var original: int=DANO.calcular_atributos(a.nivel,a.obter_atributos(),atributos,fis,1)
 atributos["def"]*=2
 check(DANO.calcular_atributos(a.nivel,a.obter_atributos(),atributos,fis,1)<original,"Def reduz físico")
 check(DANO.calcular_atributos(a.nivel,a.obter_atributos(),atributos,esp,1)==DANO.calcular(a,d,esp),"Def não reduz especial")
 atributos=d.obter_atributos();atributos["spDef"]*=2
 check(DANO.calcular_atributos(a.nivel,a.obter_atributos(),atributos,esp,1)<DANO.calcular(a,d,esp),"SpDef reduz especial")
 # Regressão do núcleo compartilhado: wrapper e snapshots devem dar o mesmo dano.
 for c in casos:
  var aliado: DadosPokemon=MOTOR.pokemon(c["aliado"])
  for nome in ["Geodude","Blastoise"]:
   var defensor: DadosPokemon=MOTOR.pokemon({"especie":nome,"nivel":80})
   for g in [fis,esp,{"type":"ELECTRIC","category":"SPECIAL","power":100},{"type":"NORMAL","category":"STATUS","power":0}]:
    for selvagem in [true,false]:
     for calibrado in [true,false]:check(DANO.calcular(aliado,defensor,g,selvagem,calibrado)==DANO.calcular_atributos(aliado.nivel,aliado.obter_atributos(),defensor.obter_atributos(),g,DANO.efetividade(g,defensor),selvagem,calibrado),"snapshot preserva cálculo da caça")
 var estado: Node=root.get_node("EstadoJogo")
 for i in range(5):await process_frame
 var p: DadosPokemon=estado.obter_lider();var memoria: Array=[p.id_persistente,p.nivel,p.experiencia_total,p.vida_atual,p.obter_total_ivs(),estado.estoque_bolas.duplicate(),estado.estoque_pocoes.duplicate()]
 var cena: Control=load("res://comparador_combate.tscn").instantiate();root.add_child(cena)
 check(cena.resultado["caso"]==casos[0]["id"] and cena.tabela.get_root().get_child_count()>8,"tela abre com comparação legível")
 cena.controles["def"].value=500
 check(cena.resultado["perfil_combate_selvagem_hipotetico"]["atributos"]["def"]==500,"editar entrada recalcula resultado")
 cena._restaurar();check(cena._perfil()=={"especie":"Geodude","nivel":1,"vida_maxima":120,"atributos":MOTOR.perfil_padrao(casos[0])["atributos"]},"restaura hipótese inicial")
 # Fixture de importação: eventos iguais continuam contados; atores independentes.
 var aliado: Dictionary=casos[0]["aliado"].duplicate(true);aliado["hp_maximo"]=24
 var mobs: Array=[{"id":"a","pokemon":{"especie":"Geodude"}},{"id":"b","pokemon":{"especie":"Geodude"}}]
 var caminho: String="user://comparador_fixture.jsonl";var f: FileAccess=FileAccess.open(caminho,FileAccess.WRITE)
 for evento in [[true,"a",0.0,2],[true,"a",0.0,2],[false,"a",0.0,1],[false,"b",0.5,1],[false,"a",2.0,1]]:
  f.store_line(JSON.stringify({"tipo":"golpe","dados":{"aliado":evento[0],"encontro_id":evento[1],"tempo_atacante":evento[2],"nome":"Tackle","dano":evento[3],"estado_apos":{"aliado":aliado,"selvagens":mobs}}}))
 var errado: Dictionary=aliado.duplicate(true);errado["nivel"]=2
 f.store_line(JSON.stringify({"tipo":"golpe","dados":{"estado_apos":{"aliado":errado,"selvagens":mobs}}}))
 f.store_line("não é JSON");f.close()
 var imp: Dictionary=IMP.ler(caminho,casos[0])
 check(imp["aceitos"]==5 and imp["descartados_perfil"]==1 and imp["linhas_invalidas"]==1,"importação filtra perfis e conta eventos iguais")
 check(imp["intervalos_por_atacante_s"]["a"]==[2.0] and not imp["intervalos_por_atacante_s"].has("b"),"intervalos inimigos não são agrupados entre atacantes")
 cena._importar(caminho);check(cena.importado["aceitos"]==5,"importação integrada à tela")
 cena._exportar()
 check(FileAccess.file_exists(cena.ultimo_arquivo_json) and FileAccess.file_exists(cena.ultimo_arquivo_json.replace(".json",".txt")),"exporta JSON e texto")
 check(memoria==[p.id_persistente,p.nivel,p.experiencia_total,p.vida_atual,p.obter_total_ivs(),estado.estoque_bolas,estado.estoque_pocoes],"laboratório não altera time, HP, XP, IVs ou estoques")
 cena.queue_free();await process_frame
 print("REFERENCIAS_COMPARADAS: ",JSON.stringify(relatorios))
 print("COMPARADOR COMBATE: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
