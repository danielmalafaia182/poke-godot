extends SceneTree
var checks: int=0
var falhas: int=0
var instante: int=100000
func _initialize() -> void:call_deferred("executar")
func check(ok: bool,msg: String) -> void:
 checks+=1
 if not ok:falhas+=1;push_error(msg)
func executar() -> void:
 var estado: Node=root.get_node("EstadoJogo")
 for i in range(5):await process_frame
 estado.especie_caca=load("res://dados/especies/geodude.tres");estado.auto_catch=false;estado.auto_potion=false
 var inicial: DadosPokemon=estado.obter_lider();inicial.vida_atual=inicial.obter_vida_maxima()
 var geo: DadosPokemon=DadosPokemon.new();geo.especie=estado.especie_caca;geo.normalizar_atributos();geo.vida_atual=geo.obter_vida_maxima();estado.time_pokemon.append(geo)
 var caca: Node2D=load("res://Caca.tscn").instantiate();root.add_child(caca)
 caca.set_process(false);caca.set_physics_process(false);caca.timer_auto_potion.stop();caca.timer_combate.stop()
 caca.relogio_troca=func() -> int:return instante
 var hud: Control=caca.get_node("Interface/HudCaca")
 var sinais: Array=[];estado.lider_alterado.connect(func() -> void:sinais.append(estado.obter_lider()))
 check(estado.selecionar_lider(geo) and caca.pokemon_aliado==geo,"primeira troca aceita imediatamente")
 check(caca.obter_troca_restante()==5.0,"cooldown começa em 5 segundos")
 var efeito: Node2D=caca.imagem_aliado.get_node("EfeitoTroca")
 check(efeito.recorte.atlas==preload("res://assets/efeitos/captura/pokeball_broke.png"),"troca reutiliza gráfico original da Pokébola")
 check(efeito.recorte.region==Rect2(0,288,64,96),"animação inicia no trecho de abertura")
 efeito._process(0.15)
 check(efeito.recorte.region==Rect2(0,480,64,96),"quadros do clarão avançam independentemente do combate")
 var fim: int=estado.prazo_troca_hunt_ms
 check(estado.selecionar_lider(geo) and estado.prazo_troca_hunt_ms==fim and sinais.size()==1,"clicar no ativo não reinicia cooldown ou emite troca")
 check(not estado.selecionar_lider(inicial) and sinais.size()==1 and estado.obter_lider()==geo,"serviço bloqueia troca antes de alterar estado ou emitir sinais")
 hud.painel_time._process(0)
 var cartao: CartaoPokemonHud=hud.painel_time.cartoes[inicial]
 check(cartao.bloqueado_cooldown and cartao.mascara_cooldown.visible and ceili(cartao.mascara_cooldown.restante)==5,"HUD mostra máscara radial e número 5 no inativo")
 check(not hud.painel_time.cartoes[geo].mascara_cooldown.visible,"ativo mantém retrato sem máscara")
 hud.my_pokes.abrir();hud.my_pokes.selecionado=inicial;hud.my_pokes.atualizar()
 check(hud.my_pokes.invocar.disabled and "5 s" in hud.my_pokes.invocar.text,"Summon também mostra bloqueio e tempo")
 for esperado in range(4,0,-1):
  instante+=1000;hud.painel_time._process(0);hud.my_pokes._process(0)
  check(ceili(cartao.mascara_cooldown.restante)==esperado,"contagem radial "+str(esperado))
  check(not estado.selecionar_lider(inicial) and sinais.size()==1,"não contorna bloqueio durante contagem "+str(esperado))
 instante=104999
 check(not estado.selecionar_lider(inicial) and estado.prazo_troca_hunt_ms==fim,"4,999 s ainda bloqueia e clique rejeitado não prolonga prazo")
 instante=105000;hud.painel_time._process(0);hud.my_pokes._process(0)
 check(not cartao.bloqueado_cooldown and not cartao.mascara_cooldown.visible and not hud.my_pokes.invocar.disabled,"libera exatamente aos 5,000 s")
 hud.painel_time.cartoes[inicial].lider_solicitado.emit(inicial)
 check(caca.pokemon_aliado==inicial and sinais.size()==2 and estado.prazo_troca_hunt_ms==110000,"nova troca aceita e reserva outros cinco segundos")
 var hp: int=geo.obter_vida_atual();var hp_inicial: int=inicial.obter_vida_atual()
 hud.my_pokes.selecionado=geo;hud.my_pokes.atualizar();hud.my_pokes.invocar.pressed.emit()
 check(caca.pokemon_aliado==inicial and geo.obter_vida_atual()==hp and inicial.obter_vida_atual()==hp_inicial,"emitir pressed manualmente não contorna serviço nem transfere HP")
 efeito._process(1.0)
 check(efeito.is_queued_for_deletion(),"efeito termina e se remove sem manter a troca bloqueada")
 var alvo: EncontroSelvagem=caca.encontro_atual;var id: String=alvo.id
 caca.queue_free();await process_frame
 check(not estado.validador_troca_lider.is_valid(),"saída da hunt remove validador transitório")
 var nova: Node2D=load("res://Caca.tscn").instantiate();root.add_child(nova)
 nova.set_physics_process(false);nova.set_process(false);nova.timer_combate.stop();nova.timer_auto_potion.stop()
 nova.relogio_troca=func() -> int:return instante
 check(not estado.selecionar_lider(geo) and is_equal_approx(nova.obter_troca_restante(),5.0),"entrar em outra hunt não contorna cooldown restante")
 check(nova.encontro_atual.id!=id,"nova hunt continua tendo encontros novos")
 instante=110000
 check(estado.selecionar_lider(geo),"nova hunt aceita troca ao terminar prazo anterior")
 nova.queue_free();await process_frame
 # Desenho determinístico da barra, inclusive HP de 1 que precisa de um pixel visível.
 var barra: ProgressBar=preload("res://estilo_combate.gd").barra();root.add_child(barra)
 var anterior: int=31
 for vida in range(120,-1,-1):
  preload("res://estilo_combate.gd").atualizar(barra,vida,120)
  var largura: int=barra.largura_preenchida()
  check(largura<=anterior and (largura>0 if vida>0 else largura==0),"preenchimento monotônico em HP "+str(vida))
  check(barra.value==vida and barra.max_value==120,"barra conserva os números reais em HP "+str(vida))
  anterior=largura
 barra.queue_free();await process_frame
 print("COOLDOWN TROCA: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
