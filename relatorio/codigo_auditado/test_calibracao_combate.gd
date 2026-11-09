extends SceneTree
const D=preload("res://regras_dano.gd")
const A=preload("res://agenda_golpes.gd")
var checks: int=0
var falhas: int=0
var eventos: Array[Dictionary]=[]
func check(ok: bool,msg: String) -> void:
 checks+=1
 if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func fixture(nome: String,lv: int,q: float,ivs: Array[int]) -> DadosPokemon:
 var p: DadosPokemon=DadosPokemon.new();p.especie=preload("res://especies_importadas.gd").obter_especies()[nome.capitalize()];p.nivel=lv;p.qualidade=q
 var campos: Array[String]=["iv_hp","iv_atk","iv_def","iv_sp_atk","iv_sp_def","iv_spd"]
 for i in range(6):p.set(campos[i],ivs[i])
 return p
func executar() -> void:
 var geo: DadosPokemon=fixture("geodude",1,1.13,[32,28,32,32,32,17])
 var mob: DadosPokemon=fixture("geodude",1,1,[16,16,16,16,16,16])
 var tackle: Dictionary={"name":"Tackle","power":50,"type":"NORMAL","category":"PHYSICAL","cooldownMs":15000}
 check(D.calcular(geo,mob,tackle)==2 and D.calcular(mob,geo,tackle,true)==1,"referência parcial Geodude: 2 causado / 1 recebido")
 check(D.calcular(geo,mob,tackle,false,false)==1,"v1 continua disponível para comparação")
 check(D.calcular(geo,mob,{"type":"ELECTRIC","power":100,"category":"SPECIAL"})==0,"piso não remove imunidade")
 check(D.calcular(geo,mob,{"type":"NORMAL","power":0,"category":"STATUS"})==0,"status não vira dano")
 var ex: DadosPokemon=fixture("exeggutor",398,1.8,[27,29,20,30,30,2])
 var gy: DadosPokemon=fixture("gyarados",214,1.8,[23,32,23,24,23,29])
 check(ex.obter_atributos()=={"hp":1037,"atk":975,"def":796,"spAtk":1178,"spDef":796,"speed":410},"atributos Exeggutor reproduzem screenshot/log")
 check(gy.obter_atributos()=={"hp":527,"atk":647,"def":428,"spAtk":370,"spDef":500,"speed":520},"atributos Gyarados reproduzem screenshot/log")
 check(ex.obter_power()==9346 and ex.obter_vida_maxima()==12444 and ex.obter_total_ivs()==138,"Power/HP/IV total Exeggutor")
 check(gy.obter_power()==5386 and gy.obter_vida_maxima()==6324 and gy.obter_total_ivs()==154,"Power/HP/IV total Gyarados")
 var bl: DadosPokemon=fixture("blastoise",80,1,[16,16,16,16,16,16])
 for atacante in [ex,gy]:
  var agenda: RefCounted=A.new();agenda.configurar(atacante.especie.nome,atacante.nivel)
  var avaliar: Callable=func(g: Dictionary) -> float:return D.calcular(atacante,bl,g)
  var golpe: Dictionary=agenda.retirar_calibrado(1.5,avaliar)
  var nome: String="Leaf Storm" if atacante==ex else "Thrash"
  check(golpe.get("name")==nome,"seleção reproduz golpe observado: "+nome)
  check(D.calcular(atacante,bl,golpe)==D.calcular(atacante,bl,golpe,false,false),"piso não multiplica dano alto")
  check(agenda.retirar_calibrado(1.5,avaliar).is_empty(),"não ataca duas vezes no mesmo instante")
  agenda.avancar_calibrado(1.5)
  check(agenda.retirar_calibrado(1.5,avaliar).is_empty(),"quantização não antecipa ataque aos 1,5 s")
  agenda.avancar_calibrado(0.1)
  check(agenda.retirar_calibrado(1.5,avaliar).get("name")==nome,"automático repete aos 1,6 s sem esperar cooldown do catálogo")
 # Habilidades opcionais respeitam cooldown, mas compartilham intervalo com automático.
 var hab: RefCounted=A.new();hab.golpes.assign([{"name":"Leaf Storm","type":"GRASS","category":"SPECIAL","power":130,"cooldownMs":80000}])
 var um: Callable=func(_g: Dictionary) -> float:return 1.0
 check(hab.retirar_calibrado(1.5,um,true).get("cooldown_aplicado_ms")==80000,"habilidade preserva cooldown de 80 s")
 check(hab.retirar_calibrado(1.5,um,false).is_empty(),"trocar via não permite ataque duplicado")
 hab.avancar_calibrado(2)
 check(hab.retirar_calibrado(1.5,um,true).is_empty(),"habilidade não pronta após 2 s")
 check(not hab.retirar_calibrado(1.5,um,false).is_empty(),"cooldown de habilidade não bloqueia ataque automático")
 hab.avancar_calibrado(100)
 check(not hab.retirar_calibrado(1.5,um,true).is_empty() and hab.retirar_calibrado(1.5,um,true).is_empty(),"atraso longo não gera rajada")
 var fracionado: RefCounted=A.new()
 for i in range(600):fracionado.avancar_calibrado(1.0/60.0)
 check(is_equal_approx(fracionado.tempo,10.0),"resíduo do tick não perde tempo a 60 FPS")
 # Entrar em alcance entre ticks não pode encurtar o intervalo mínimo.
 var fase: RefCounted=A.new();fase.configurar("Geodude",1);fase.avancar_calibrado(0.19)
 check(not fase.retirar_calibrado(1.5,um).is_empty(),"primeiro golpe disponível ao entrar em alcance")
 fase.avancar_calibrado(1.41)
 check(fase.retirar_calibrado(1.5,um).is_empty(),"fase entre ticks não antecipa próximo golpe")
 fase.avancar_calibrado(0.2)
 check(not fase.retirar_calibrado(1.5,um).is_empty(),"fase entre ticks retoma sem perder a agenda")
 # Exercita a cena real, não só a função de dano.
 var estado: Node=root.get_node("EstadoJogo")
 estado.especie_caca=mob.especie;estado.auto_potion=false;estado.auto_catch=false
 var caca: Node2D=load("res://Caca.tscn").instantiate();caca.usar_dano_candidato=false
 root.add_child(caca)
 caca.set_process(false);caca.set_physics_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
 caca.movimento_selvagens_habilitado=false;caca.reagir_ao_cerco=false
 # Substituição exclusiva desta cena de teste; não altera o time persistente.
 caca.pokemon_aliado=geo;geo.vida_atual=24
 var alvo: EncontroSelvagem=caca.encontro_atual;alvo.pokemon=mob;alvo.vida_maxima=120;alvo.vida=120
 for outro in caca.selvagens:
  if outro!=alvo:outro.resolver(100)
 for dir: Vector2i in caca.DIRECOES:
  if caca.passagem_permitida(alvo.celula,alvo.celula+dir):
   caca.imagem_aliado.global_position=caca.celula_para_posicao(alvo.celula+dir);break
 caca.aproximando=false;caca.batalha_encerrada=false
 caca.golpe_executado.connect(func(e: Dictionary) -> void:eventos.append(e))
 caca._executar_golpes_catalogados()
 check(eventos.size()==2 and eventos[0]["dano"]==2 and eventos[1]["dano"]==1,"cena aplica resultado 2/1 sem depender de animação")
 check(caca.vida_selvagem==118 and caca.vida_aliado==23,"HP efetivamente descontado na cena")
 caca._physics_process(1.5)
 check(eventos.size()==2,"nenhum ataque antes da janela calibrada")
 caca._physics_process(0.1)
 check(eventos.size()==3 and eventos.back()["aliado"],"aliado ataca aos 1,6 s")
 caca._physics_process(0.4)
 check(eventos.size()==4 and not eventos.back()["aliado"],"selvagem ataca aos 2,0 s independentemente do aliado")
 check(eventos[0]["regra_dano"]=="atributos_local_v2_piso_2_1" and eventos[0]["cooldown_aplicado_ms"]==0 and eventos[0]["tick_combate_ms"]==200,"diagnóstico identifica hipótese, via e cooldown aplicado")
 caca.usar_calibracao_combate=false
 check(caca._dano_golpe(geo,mob,tackle,false)==1,"rollback retorna ao modelo anterior")
 caca.queue_free();await process_frame
 print("CALIBRACAO COMBATE: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
