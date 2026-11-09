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
 var inicial: DadosPokemon=estado.pokemon_inicial;estado.selecionar_lider(inicial)
 inicial.vida_atual=7
 var laboratorio: Control=load("res://laboratorio_combate.gd").new()
 var ivs: Array[int]=[32,28,32,32,32,17]
 var geo: DadosPokemon=laboratorio._fixture(ivs);laboratorio.free()
 geo.versao_atributos=1
 geo.vida_atual=24;estado.time_pokemon.append(geo)
 var ko: DadosPokemon=geo.duplicate();ko.vida_atual=0;estado.time_pokemon.append(ko)
 var caca: Node2D=load("res://Caca.tscn").instantiate();root.add_child(caca)
 caca.set_physics_process(false);caca.set_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
 caca.relogio_troca=func() -> int:return instante
 caca.movimento_selvagens_habilitado=false;caca.reagir_ao_cerco=false
 for i in range(5):await process_frame
 var hud: Control=caca.get_node("Interface/HudCaca")
 var alvo: EncontroSelvagem=caca.encontro_atual
 var hp: int=alvo.vida;var pos: Vector2=caca.imagem_aliado.global_position
 var populacao: Array= caca.selvagens.duplicate()
 var prazo_inimigo: float=alvo.agenda_golpes.proximo_ataque_rapido
 caca.agenda_aliado.proximo_ataque_rapido=5.0
 var agenda_inicial: RefCounted=caca.agenda_aliado
 caca.imagem_aliado.quadro=3 # Último frame do Larvitar; Geodude só tem três.
 hud.my_pokes.abrir();hud.my_pokes.selecionado=geo;hud.my_pokes.atualizar()
 check(not hud.my_pokes.invocar.disabled,"Team permite invocar aliado saudável dentro da hunt")
 hud.my_pokes.invocar.pressed.emit()
 check(caca.pokemon_aliado==geo and estado.obter_lider()==geo,"botão Summon sincroniza líder e controlador")
 check(caca.vida_aliado==24 and inicial.obter_vida_atual()==7,"troca não transfere HP nem cura quem saiu")
 check(caca.encontro_atual==alvo and alvo.vida==hp and caca.selvagens==populacao,"troca preserva alvo, população e HP inimigo")
 check(caca.imagem_aliado.global_position==pos and alvo.agenda_golpes.proximo_ataque_rapido==prazo_inimigo,"troca preserva posição e relógio inimigo")
 check(caca.imagem_aliado.quadros_por_direcao==3 and caca.imagem_aliado.quadro==0 and caca.imagem_aliado.animacao_pronta,"troca reinicia somente os frames do sprite correto")
 check(hud.vida_aliado.value==24 and hud.vida_aliado.max_value==geo.obter_vida_maxima(),"barra do aliado passa a ler o novo indivíduo")
 check(hud.nome_aliado.texture.get_image().get_data()==preload("res://fonte_mundo.gd").texto("Geodude",Color("00ff00")).get_image().get_data(),"nome de mundo atualiza junto do sprite")
 check(caca.agenda_aliado.proximo_ataque_rapido==5,"trocar não antecipa o próximo ataque")
 caca._avancar_agendas_golpes(0.4)
 instante+=5000
 hud.painel_time.cartoes[inicial].lider_solicitado.emit(inicial)
 check(caca.pokemon_aliado==inicial and caca.agenda_aliado==agenda_inicial and caca.vida_aliado==7,"clique no HUD também troca, recuperando a agenda e o HP próprios")
 check(is_equal_approx(agenda_inicial.tempo,0.4) and caca.agendas_aliados[geo].tempo==agenda_inicial.tempo,"relógios já usados continuam avançando no banco")
 hud.my_pokes.selecionado=ko;hud.my_pokes.atualizar()
 check(hud.my_pokes.invocar.disabled,"Team bloqueia invocação de Pokémon sem HP")
 hud.my_pokes.invocar.pressed.emit()
 check(caca.pokemon_aliado==inicial,"invocação de derrotado não muda aliado")
 hud.painel_time.cartoes[ko].lider_solicitado.emit(ko)
 check(caca.pokemon_aliado==inicial and estado.obter_lider()==inicial,"clique no HUD também rejeita derrotado sem ressuscitar")
 instante+=5000
 hud.my_pokes.selecionado=geo;hud.my_pokes.atualizar();hud.my_pokes.invocar.pressed.emit()
 check(caca.pokemon_aliado==geo and caca.vida_aliado==24 and caca.agenda_aliado.proximo_ataque_rapido==5,"retornar ao mesmo Pokémon não reinicia HP ou prazo")
 hud.my_pokes.hide()
 # Duelo completo com golpes baixos no controlador real, mantendo o mesmo encontro.
 var d: DadosPokemon=geo.duplicate();d.qualidade=1.0
 alvo.pokemon=d;alvo.vida_maxima=120;alvo.vida=120;alvo.intervalo_ataque=9999
 for r in caca.selvagens:
  if r!=alvo:r.resolver(1000);r.imagem.hide()
 for dir: Vector2i in caca.DIRECOES:
  if caca.passagem_permitida(alvo.celula,alvo.celula+dir):
   caca.imagem_aliado.global_position=caca.celula_para_posicao(alvo.celula+dir);break
 caca.aproximando=false;caca.batalha_encerrada=false
 var indicador: Node2D=alvo.imagem.get_node("IndicadorSelvagem");indicador.atualizar()
 caca._avancar_agendas_golpes(5.0) # Aguarda o prazo preservado pelas trocas anteriores.
 var anterior: float=indicador.barra.ratio
 check(anterior==1.0 and indicador.barra.value==120,"barra começa no HP completo do encontro")
 for i in range(59):
  caca._avancar_agendas_golpes(2)
  caca._executar_golpes_catalogados()
  check(alvo.vida==120-2*(i+1) and indicador.barra.value==alvo.vida,"barra atualiza imediatamente no dano baixo "+str(i))
  check(indicador.barra.ratio<=anterior and indicador.barra.ratio>0,"barra não zera/recarrega com alvo ainda vivo "+str(i))
  anterior=indicador.barra.ratio
  # Efeitos e updates de apresentação não podem mudar a vida exibida.
  indicador._process(0.016)
  check(indicador.barra.value==alvo.vida,"processamento visual mantém HP verdadeiro "+str(i))
 check(indicador.z_index>100 and not indicador.z_as_relative and hud.placa_aliado.z_index>100,"indicadores de ambos os lados ficam acima dos impactos")
 caca._avancar_agendas_golpes(2);caca._executar_golpes_catalogados()
 check(alvo.vida==0 and indicador.barra.value==0 and not indicador.visible,"barra só chega a zero no KO real e fica oculta")
 var sprite: Sprite2D=alvo.imagem
 caca._criar_individuo(alvo.slot,caca.PONTOS_RESPAWN[alvo.slot])
 var novo: EncontroSelvagem=caca.selvagens[alvo.slot]
 check(sprite.get_node("IndicadorSelvagem")==indicador and indicador.encontro==novo,"respawn reutiliza indicador e muda sua identidade")
 var valor_novo: float=indicador.barra.value
 alvo.vida=5
 check(indicador.barra.value==valor_novo and not alvo.vida_alterada.is_connected(indicador.atualizar),"encontro antigo não altera barra após respawn")
 check(novo.vida_alterada.is_connected(indicador.atualizar),"indicador escuta somente o encontro atual")
 novo.vida=maxi(1,novo.vida-1)
 check(indicador.barra.value==novo.vida,"respawn mantém sincronização imediata")
 caca.queue_free();await process_frame
 print("TROCA HUNT E BARRAS: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
