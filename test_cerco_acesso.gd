extends SceneTree
var falhas: int=0
var checks: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool, texto: String) -> void:
 checks+=1
 if not ok: falhas+=1;push_error(texto)
func executar() -> void:
 var estado: Node=root.get_node("EstadoJogo")
 estado.especie_caca=load("res://dados/especies/geodude.tres")
 estado.auto_catch=false;estado.auto_potion=false
 var lider: DadosPokemon=estado.obter_lider()
 lider.experiencia_total=preload("res://regras_pokemon.gd").xp_total_para_nivel(100)
 lider.normalizar_atributos();estado.curar_time()
 var caca: Node=load("res://Caca.tscn").instantiate()
 root.add_child(caca)
 caca.set_process(false);caca.set_physics_process(false)
 caca.movimento_selvagens_habilitado=false
 await process_frame
 var centro: Vector2i
 var vizinhos: Array[Vector2i]=[]
 for celula in caca.celulas_acessiveis:
  var livres: Array[Vector2i]=[]
  for d in caca.DIRECOES:
   if caca.passagem_permitida(celula,celula+d): livres.append(celula+d)
  if livres.size()>=4 and livres.size()<caca.DIRECOES.size(): centro=celula;vizinhos=livres;break
 checar(vizinhos.size()>=4,"Fixture acessível")
 if vizinhos.size()<4: quit(1);return
 caca.imagem_aliado.global_position=caca.celula_para_posicao(centro)
 for r in caca.selvagens:
  r.movendo=false
  r.celula=Vector2i(1000,1000)
  r.imagem.global_position=caca.celula_para_posicao(r.celula)
 var perto: EncontroSelvagem=caca.selvagens[1]
 perto.vida_maxima=100000;perto.vida=100000
 perto.celula=vizinhos[0];perto.imagem.global_position=caca.celula_para_posicao(perto.celula)
 caca.encontro_atual=caca.selvagens[0]
 caca.aproximando=true;caca.batalha_encerrada=false;caca.recalcular_alvo_pendente=true
 var id: String=perto.id
 var hp: int=perto.vida
 caca._retomar_combate_proximo()
 checar(caca.encontro_atual==perto,"Troca alvo distante pelo atacante adjacente")
 checar(not caca.aproximando and not caca.recalcular_alvo_pendente,"Sai da espera de rota")
 checar(perto.vida<hp,"Aliado efetivamente ataca ao ser cercado")
 checar(perto.id==id,"Identidade preservada")
 hp=perto.vida
 var agenda: float=caca.agenda_aliado.proximo_ataque_rapido
 caca._retomar_combate_proximo()
 checar(perto.vida==hp and caca.agenda_aliado.proximo_ataque_rapido==agenda,"Não duplica golpe nem reseta cooldown")
 # Não interrompe posição intermediária de um passo.
 caca.encontro_atual=caca.selvagens[0];caca.aproximando=true
 caca.imagem_aliado.global_position+=Vector2(4,0)
 caca._retomar_combate_proximo()
 checar(caca.encontro_atual==caca.selvagens[0],"Não teleporta na metade do passo")
 caca.imagem_aliado.global_position=caca.celula_para_posicao(centro)
 for d in caca.DIRECOES:
  if not caca.passagem_permitida(centro,centro+d):
   perto.celula=centro+d;perto.imagem.global_position=caca.celula_para_posicao(perto.celula)
   break
 caca._retomar_combate_proximo()
 checar(caca.encontro_atual==caca.selvagens[0],"Não ataca através de parede ou quina")
 caca.queue_free();await process_frame
 var conf: Dictionary=preload("res://catalogo_hunts.gd").obter("Togepi")
 checar(conf.get("nivel")==1 and not preload("res://catalogo_golpes.gd").listar("Togepi",1,true).is_empty(),"Togepi tem golpe próprio no nível configurado")
 estado.especie_caca=preload("res://especies_importadas.gd").obter_especies()["Togepi"]
 estado.curar_time()
 caca=load("res://Caca.tscn").instantiate();root.add_child(caca)
 caca.set_process(false);caca.set_physics_process(false)
 await process_frame
 checar(caca.selvagens.size()==15 and caca.selvagens[0].pokemon.nivel==1,"Togepi nasce na hunt")
 caca.queue_free();await process_frame
 # Fluxo de acesso real: treinador Lv1 seleciona destino acima desse nível.
 estado.nivel_treinador=1
 var mapa: Control=load("res://mapa_mundi.tscn").instantiate();root.add_child(mapa)
 await process_frame
 var alvo: Dictionary={}
 for d in mapa.catalogo:
  if d["name"]=="Dragonite": alvo=d;break
 checar(not alvo.is_empty() and int(alvo.get("level",0))>1,"Destino de nível alto")
 mapa._selecionar_registro(alvo)
 for i in range(3): await process_frame
 # Fase 2 (E): hunt com mapa e hunt-config no snapshot abre a cena nova (caca_sim.tscn), não a antiga.
 checar(estado.especie_caca.nome=="Dragonite" and current_scene!=null and current_scene.scene_file_path=="res://caca_sim.tscn","Treinador Lv1 entra em hunt de nível alto")
 checar(estado.nivel_treinador==1,"Nível salvo não é adulterado")
 print("CERCO E ACESSO: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
