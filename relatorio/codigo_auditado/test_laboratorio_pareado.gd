extends SceneTree
const MOTOR=preload("res://analise_encontros_pareados.gd")
const DANO=preload("res://regras_dano.gd")
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
 checks+=1
 if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func executar() -> void:
 var amostra: Dictionary=MOTOR.carregar();var motor: RefCounted=MOTOR.new();motor.iniciar(amostra)
 check(motor.encontros().size()==12 and motor.encontros(true).size()==4,"12 vidas observadas e4 encontros pareados")
 var antigo: Array=preload("res://comparador_regras_combate.gd").casos()
 check(antigo[1]["aliado"]["nivel"]==398,"referência anterior Exeggutor398 preservada")
 var ex: Dictionary={};var gy: Dictionary={}
 for p in amostra["perfis"].values():
  if p["especie"]=="Exeggutor":ex=p
  else:gy=p
 check(ex["nivel"]==404 and ex["power"]==9486 and ex["hp_maximo"]==12624,"perfil observado Exeggutor404 sem inventar IVs")
 check(gy["nivel"]==214 and gy["atributos"]["atk"]==647 and gy["atributos"]["spAtk"]==370,"perfil Gyarados observado")
 var alvo: Dictionary={};var especiais: Dictionary={}
 for e in motor.encontros(true):
  check(e["elegivel_ajuste"] and e["alertas"].is_empty(),"pares com HP contínuo e dano contabilizado")
  if e["slot"]==10:alvo=e
  if e["slot"]==13:especiais=e
 check(alvo["hp_maximo"]==5705 and alvo["golpes"].map(func(h):return int(h["dano"]))==[689,720,690,9820],"sequência completa do mesmo alvo")
 check(alvo["golpes"][-1]["hp_antes_pacote"]==3606 and alvo["golpes"][-1]["hp_depois_pacote"]==0,"dano fatal completo separado de HP removido")
 check(especiais["golpes"].size()==2 and especiais["golpes"][0]["dano"]==766,"respawn do slot13 não mistura Hyper Beam da vida anterior")
 var fs: Array=MOTOR.familias()
 var sem: Dictionary=motor.analisar_familia(alvo,fs[0])
 check(not sem["dano_compativel_na_busca"],"defesa constante e dano sem variação não explicam689/720/690")
 var vinte: Dictionary=motor.analisar_familia(especiais,fs[4])
 check(not vinte["dano_compativel_na_busca"],"dois ataques especiais não compartilham SpDef na hipótese±20%")
 var vinte_cinco: Dictionary=motor.analisar_familia(especiais,fs[5])
 check(vinte_cinco["dano_compativel_na_busca"] and vinte_cinco["escolha"]=="COMPATÍVEL SOB HIPÓTESE","±25% admite um exemplo conjunto sem comprovar RNG")
 check(not vinte_cinco["def"]["observado"] and vinte_cinco["spDef"]["observado"],"ataques só especiais não determinam Def física")
 check(vinte_cinco["exemplo"]["def"]<5000,"exemplo não transforma extremo arbitrário da busca em defesa inferida")
 var perfil: Dictionary=vinte_cinco["exemplo"]
 var h: Dictionary=motor.hipotese(especiais,perfil["def"],perfil["spDef"],fs[5])
 check(h["danos_compativeis"] and h["escolhas_nominais_compativeis"],"exemplo é revalidado pelo preditor de dano e seleção")
 check(h["grupos"][0]["categoria"]=="SPECIAL" and h["grupos"][1]["categoria"]=="SPECIAL","Hyper Beam e Leaf Storm compartilham SpDef")
 var analise: Dictionary=motor.analisar_todos()
 check(analise["familias"].size()==16 and not analise["fidelidade_global_comprovada"],"dezesseis famílias explícitas sem afirmar fidelidade")
 check(analise["familias"][4]["pareados_com_dano_compativel"]<4 and analise["familias"][5]["pareados_com_dano_e_escolha"]==4,"±25% é a primeira família simétrica testada que explica os4pares nesta busca")
 check(analise["familias"][9]["pareados_com_dano_e_escolha"]==4,"STAB1,5 e±5% também explicam os quatro pares nesta busca")
 check(analise["familias"][9]["sessao_com_dano_e_escolha"]<12 and analise["familias"][10]["sessao_com_dano_e_escolha"]==12,"controles sem troca rejeitam±5% mesmo com STAB;±10% admite a sessão nesta busca")
 var stab: Dictionary=motor.hipotese(especiais,130,130,fs[9])
 var normal: Dictionary=motor.hipotese(especiais,130,130,fs[1])
 check(stab["grupos"][0]["nominal"]==normal["grupos"][0]["nominal"] and stab["grupos"][1]["nominal"]>normal["grupos"][1]["nominal"],"hipótese STAB afeta Leaf Storm do Exeggutor, não Hyper Beam do Gyarados")
 # Verifica todos os exemplos encontrados; compatibilidade de margens não basta.
 for f in analise["familias"]:
  for r in f["encontros"]:
   if r.get("exemplo",{}).is_empty():continue
   var e: Dictionary={}
   for episodio in motor.encontros(true):
    if episodio["id_local"]==r["id_local"]:e=episodio;break
   var v: Dictionary=motor.hipotese(e,r["exemplo"]["def"],r["exemplo"]["spDef"],f["familia"])
   check(v["danos_compativeis"] and v["escolhas_nominais_compativeis"],"testemunha concreta de compatibilidade conjunta")
 var g: Dictionary={"category":"PHYSICAL","power":120,"type":"NORMAL"}
 for nivel in [1,50,214,404]:
  for fator in [0.0,1.0/3.0,1.0,2.5]:
   for sel in [true,false]:
    for calibrado in [true,false]:
     var bruto: float=DANO.calcular_bruto_atributos(nivel,gy["atributos"],ex["atributos"],g,fator,sel,calibrado)
     check(DANO.finalizar_dano(bruto,sel,calibrado)==DANO.calcular_atributos(nivel,gy["atributos"],ex["atributos"],g,fator,sel,calibrado),"extração do dano bruto preserva cálculo determinístico")
 var estado: Node=root.get_node("EstadoJogo")
 for i in range(5):await process_frame
 var p: DadosPokemon=estado.obter_lider()
 var antes: Array=[p.id_persistente,p.nivel,p.experiencia_total,p.vida_atual,p.obter_total_ivs(),estado.estoque_bolas.duplicate(true),estado.estoque_pocoes.duplicate(true)]
 var cena: Control=load("res://laboratorio_pareado.tscn").instantiate();root.add_child(cena)
 check(cena.lista.size()==12 and cena.lista[cena.seletor.selected]["slot"]==10,"tela abre o encontro pareado informativo")
 cena.familia.select(1);cena.defesa.value=200
 var primeira: TreeItem=cena.tabela.get_root().get_first_child()
 check(primeira.get_text(5)=="SOB HIPÓTESE" and primeira.get_next().get_text(5)=="DIVERGE","cada linha compara seu próprio dano, mesmo quando outro golpe do grupo diverge")
 cena.familia.select(5);cena._usar_exemplo()
 check(cena.resultado["danos_compativeis"] and cena.resultado["escolhas_nominais_compativeis"],"botão aplica exemplo só ao laboratório")
 cena._exportar()
 check(FileAccess.file_exists(cena.ultimo_json) and FileAccess.file_exists(cena.ultimo_json.replace(".json",".txt")),"exporta evidência e hipótese em JSON/TXT")
 check(antes==[p.id_persistente,p.nivel,p.experiencia_total,p.vida_atual,p.obter_total_ivs(),estado.estoque_bolas,estado.estoque_pocoes],"análise não altera save, time, HP, XP, IVs ou estoque")
 check(amostra==MOTOR.carregar(),"observações originais não são ajustadas pelo experimento")
 cena.queue_free();await process_frame
 print("ANALISE_PAREADA: ",JSON.stringify(analise))
 print("LABORATORIO PAREADO: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
