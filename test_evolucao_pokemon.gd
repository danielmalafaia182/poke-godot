extends SceneTree
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool,t: String) -> void:
 checks+=1
 if not ok:falhas+=1;push_error(t)
func nivel(p: DadosPokemon,n: int) -> void:
 p.experiencia_total=preload("res://regras_pokemon.gd").xp_total_para_nivel(n)
 p.normalizar_atributos()
func executar() -> void:
 var estado: Node=root.get_node("EstadoJogo")
 var p: DadosPokemon=estado.obter_lider()
 var cidade: Node=load("res://cidade.tscn").instantiate();root.add_child(cidade);current_scene=cidade
 await process_frame
 var id: String=p.id_persistente
 var ivs: int=p.obter_total_ivs()
 var qualidade: float=p.qualidade
 nivel(p,59);p.vida_atual=10
 checar(not estado.evoluir_pokemon(p).is_empty() and p.especie.nome=="Larvitar","Bloqueia abaixo do nível")
 nivel(p,60)
 var xp: int=p.experiencia_total
 checar(estado.validar_evolucao(p).is_empty(),"Habilita no nível exigido")
 # Fase 4 (C, guia do original): com pedras mantém o nível; sem pedras é grátis e volta ao Lv.1. Larvitar (hunt 30)
 # precisa de 1 Rock Stone (receita F, ver CALIBRACAO_FASE4.md). O botão TEAM abre a janela de evolução.
 estado.inventario.estoque_materiais[109]=1
 var fracao: float=float(p.obter_vida_atual())/float(p.obter_vida_maxima())
 var painel: Control=cidade.painel_my_pokes
 painel.abrir()
 painel.evoluir.pressed.emit()
 var janela: Control=cidade.get_node("Interface").get_node_or_null("PainelEvolucao")
 checar(janela!=null and janela.visible and p.especie.nome=="Larvitar","Botão TEAM abre a janela de evolução (sem evoluir sozinho)")
 var com_pedras: Button=janela.find_child("ComPedras",true,false) if janela!=null else null
 if com_pedras!=null: com_pedras.pressed.emit()
 checar(p.especie.nome=="Pupitar" and estado.inventario.quantidade_item_bag(109)==0,"Janela evolui com a Rock Stone")
 checar(p.id_persistente==id and p.obter_total_ivs()==ivs and p.qualidade==qualidade and p.experiencia_total==xp and absf(float(p.obter_vida_atual())/float(p.obter_vida_maxima())-fracao)<0.02,"Preserva identidade IVs qualidade XP e a fração do HP")
 checar(estado.obter_lider()==p and estado.pokemon_inicial==p,"Mantém líder e inicial protegido")
 checar(not estado.evoluir_pokemon(p).is_empty(),"Não salta próximo requisito")
 nivel(p,100)
 # Pupitar (hunt 60 ≥ 40): 4 pedras divididas; ganha DARK → 2 Rock + 2 Darkness (receita F)
 estado.inventario.estoque_materiais[109]=2;estado.inventario.estoque_materiais[31]=2
 checar(estado.evoluir_pokemon(p,true).is_empty() and p.especie.nome=="Tyranitar" and p.nivel==100,"Segunda evolução com pedras mantém o nível")
 checar(not estado.evoluir_pokemon(p).is_empty(),"Forma final não evolui novamente")
 var g: DadosPokemon=DadosPokemon.new();g.especie=load("res://dados/especies/geodude.tres")
 g.sortear_ivs();g.sortear_qualidade();nivel(g,40)
 estado.registrar_captura(g);estado.colecao.mover_pokemon_depot(g,false)
 checar(estado.evoluir_pokemon(g,false).is_empty() and g.especie.nome=="Graveler" and g.nivel==1,"Geodude evolui no nível 40 sem pedra e volta ao Lv.1 (C)")
 nivel(g,80)
 estado.inventario.estoque_materiais[109]=4
 checar(estado.evoluir_pokemon(g,true).is_empty() and g.especie.nome=="Golem" and g.nivel==80,"Graveler evolui no nível 80 com 4 Rock Stone")
 var save: RefCounted=preload("res://salvamento_local.gd").new()
 var dados: Dictionary=save.construir_dados(estado)
 checar(save._validar(dados).is_empty(),"Save aceita inicial evoluído")
 save._restaurar(estado,dados)
 checar(estado.pokemon_inicial.especie.nome=="Tyranitar" and estado.obter_lider().id_persistente==id,"Reload mantém evolução e liderança")
 var copia: Dictionary=dados.duplicate(true)
 for registro in copia["team"]:
  if registro["id"]==copia["inicial_id"]:registro["especie"]="Bulbasaur"
 checar(not save._validar(copia).is_empty(),"Não aceita espécie alheia à linhagem inicial")
 # A exigência de cidade é verificada no backend, mesmo quando invocado diretamente.
 current_scene=null
 checar(not estado.evoluir_pokemon(estado.pokemon_inicial).is_empty(),"Backend exige cidade")
 print("EVOLUCAO POKEMON: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
