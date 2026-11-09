extends Node
# Observador opt-in. Não altera HP, agenda, seleção, movimento ou RNG do jogo.
const LIMITE: int=10000
const PASTA: String="user://diagnosticos_combate"
var controlador: Node
var ativo: bool=false
var registros: Array[Dictionary]=[]
var inicio_ms: int=0
var acumulado: float=0.0
var ultimo_arquivo: String=""
var pendente_exportacao: bool=false
var aviso: Label
func iniciar(caca: Node) -> void:
 controlador=caca
 caca.golpe_executado.connect(_golpe)
 caca.derrota_recompensada.connect(func(e: Dictionary) -> void: _adicionar("derrota",e))
 caca.captura_resolvida.connect(func(e: Dictionary) -> void: _adicionar("captura",e))
 caca.cura_aplicada.connect(func(e: Dictionary) -> void: _adicionar("cura",e))
func _unhandled_key_input(e: InputEvent) -> void:
 if e is InputEventKey and e.pressed and not e.echo and e.ctrl_pressed and e.shift_pressed and e.keycode==KEY_L:
  if ativo or pendente_exportacao: encerrar()
  else: comecar()
  get_viewport().set_input_as_handled()
func comecar() -> void:
 if ativo or pendente_exportacao:return
 registros.clear();inicio_ms=Time.get_ticks_msec();acumulado=0;ativo=true
 _adicionar("sessao",{"schema":1,"perfil_movimento":_perfil_movimento(),"origem":"prototipo_local","godot":Engine.get_version_info()["string"],"hunt":EstadoJogo.especie_caca.nome,"curva_dano":controlador._versao_dano(),"calibracao_parcial":controlador._calibracao_ativa(),"dano_candidato_ativo":controlador._candidata_ativa(),"nivel_dano_catalogo_selvagem_ativo":controlador.usar_nivel_dano_catalogo_selvagem and controlador._candidata_ativa(),"politica_nivel_formula_selvagem":"catalogo_huntLevel_candidato_v1" if controlador.usar_nivel_dano_catalogo_selvagem and controlador._candidata_ativa() else "nivel_pokemon_v1","rng_dano_seed":str(controlador.rng_dano.seed),"rng_dano_estado":str(controlador.rng_dano.state),"variacao_distribuicao":"uniforme_local_provisoria" if controlador._candidata_ativa() else "sem_variacao","tick_combate_ms":200 if controlador._calibracao_ativa() else 0,"cooldowns_catalogo":controlador.aplicar_cooldowns_catalogo,"intervalo_aliado":controlador.intervalo_ataques_caca,"intervalo_selvagens":controlador.intervalo_selvagem_calibrado if controlador._calibracao_ativa() else controlador.intervalo_ataques_selvagem,"auto_potion":EstadoJogo.auto_potion,"auto_catch":EstadoJogo.auto_catch,"usar_atributos":controlador.usar_atributos_combate,"hp_selvagem_multiplicador":_opcional(5,controlador.usar_atributos_combate and not controlador._hp_candidato_ativo()),"hp_selvagem_candidato":controlador._hp_candidato_ativo(),"preservar_perfis_de_combate_na_hunt":controlador.preservar_perfis_de_combate_na_hunt,"preparar_primeiro_ataque_selvagem":controlador.preparar_primeiro_ataque_selvagem,"hp_selvagem_fator_atributo_hp":_opcional(35 if controlador._hp_candidato_ativo() else 60,controlador._hp_candidato_ativo() or controlador.usar_atributos_combate),"dano_selvagem_multiplicador":_opcional(1.0 if controlador._calibracao_ativa() else 1.8,controlador.usar_atributos_combate)})
 _adicionar("estado",_estado())
 _mostrar("Registro de combate ativo · Ctrl+Shift+L para exportar")
func encerrar() -> String:
 if not ativo and not pendente_exportacao:return ultimo_arquivo
 # Reserva uma linha para o encerramento mesmo quando chega ao limite.
 if ativo: registros.append({"tipo":"fim","t_ms":Time.get_ticks_msec()-inicio_ms,"dados":{"limite_atingido":registros.size()>=LIMITE}})
 ativo=false;pendente_exportacao=true
 DirAccess.make_dir_recursive_absolute(PASTA)
 var nome: String="combate_%d_%d.jsonl" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
 var caminho: String=PASTA+"/"+nome
 var f: FileAccess=FileAccess.open(caminho,FileAccess.WRITE)
 if f==null:
  _mostrar("Falha ao salvar registro de combate; tente novamente antes de sair.")
  push_error("Não foi possível gravar o diagnóstico de combate.")
  return ""
 for r in registros:f.store_line(JSON.stringify(_json(r)))
 f.close();pendente_exportacao=false;ultimo_arquivo=ProjectSettings.globalize_path(caminho)
 _mostrar("Registro exportado · "+ultimo_arquivo)
 print("COMBATE EXPORTADO: ",ultimo_arquivo)
 return ultimo_arquivo
func _exit_tree() -> void:
 if ativo:encerrar()
func _process(delta: float) -> void:
 if not ativo:return
 acumulado+=delta
 if acumulado>=0.2:
  acumulado=0
  _adicionar("estado",_estado())
func _adicionar(tipo: String,dados: Dictionary) -> void:
 if not ativo:return
 registros.append({"tipo":tipo,"t_ms":Time.get_ticks_msec()-inicio_ms,"dados":_json(dados)})
 if registros.size()>=LIMITE:encerrar()
func _pokemon(p: DadosPokemon,hp: int,maximo: int,posicao: Vector2) -> Dictionary:
 return {"especie":p.especie.nome,"nivel":p.nivel,"ivs":{"hp":p.iv_hp,"atk":p.iv_atk,"def":p.iv_def,"spAtk":p.iv_sp_atk,"spDef":p.iv_sp_def,"speed":p.iv_spd},"qualidade":p.qualidade,"atributos":p.obter_atributos(),"power":p.obter_power(),"hp":hp,"hp_maximo":maximo,"posicao":posicao}
func _estado() -> Dictionary:
 var mobs: Array[Dictionary]=[]
 var populacao: Variant=controlador.get("selvagens")
 if populacao is Array:
  for r in populacao:
   mobs.append({"id":r.id,"slot":r.slot,"estado":r.estado,"movendo":r.movendo,"perfil_hp":r.perfil_hp,"perfil_combate_id":r.perfil_combate_id,"perfil_combate_persistente":r.perfil_combate_persistente,"primeiro_ataque_preparado":r.primeiro_ataque_preparado,"inicio_preparo_primeiro_ataque":r.inicio_preparo_primeiro_ataque,"prazo_primeiro_ataque":r.prazo_primeiro_ataque,"indicador_hp":_indicador(r),"pokemon":_pokemon(r.obter_pokemon_combate(),r.vida,r.vida_maxima,r.imagem.global_position),"pokemon_capturavel":_pokemon(r.pokemon,r.pokemon.obter_vida_atual(),r.pokemon.obter_vida_maxima(),r.imagem.global_position)})
 return {"aliado":_pokemon(controlador.pokemon_aliado,controlador.vida_aliado,controlador.pokemon_aliado.obter_vida_maxima(),controlador.imagem_aliado.global_position),"alvo_id":controlador.encontro_atual.id if controlador.encontro_atual!=null else "","aproximando":controlador.aproximando,"batalha_encerrada":controlador.batalha_encerrada,"selvagens":mobs}
func _golpe(evento: Dictionary) -> void:
 if not ativo:return
 var e: Dictionary=evento.duplicate(true)
 e["estado_apos"]=_estado()
 _adicionar("golpe",e)
func _json(v: Variant) -> Variant:
 if v is DadosPokemon:return {"especie":v.especie.nome,"nivel":v.nivel,"atributos":v.obter_atributos()}
 if v is Object:return "objeto_omitido"
 if v is Vector2 or v is Vector2i:return [v.x,v.y]
 if v is Dictionary:
  var d: Dictionary={}
  for k in v:d[str(k)]=_json(v[k])
  return d
 if v is Array:
  var a: Array=[]
  for x in v:a.append(_json(x))
  return a
 return v
func _mostrar(texto: String) -> void:
 if not is_inside_tree():return
 if aviso==null:
  var camada: CanvasLayer=CanvasLayer.new();camada.layer=95;add_child(camada)
  aviso=Label.new();aviso.position=Vector2(16,180);aviso.add_theme_font_size_override("font_size",12)
  aviso.add_theme_color_override("font_outline_color",Color.BLACK);aviso.add_theme_constant_override("outline_size",4)
  aviso.mouse_filter=Control.MOUSE_FILTER_IGNORE;camada.add_child(aviso)
 aviso.text=texto

# Evidência visual para distinguir HP real de sobreposição/renderização da barra.
func _indicador(r: EncontroSelvagem) -> Dictionary:
 var indicador: Node=r.imagem.get_node_or_null("IndicadorSelvagem")
 if indicador==null or indicador.barra==null:return {}
 return {"encontro_id":indicador.encontro.id,"vida_exibida":indicador.barra.value,"maximo_exibido":indicador.barra.max_value,"proporcao":indicador.barra.ratio,"visivel":indicador.visible}

static func _opcional(valor: Variant, habilitado: bool) -> Variant:
 if habilitado:
  return valor
 return null

func _perfil_movimento() -> Dictionary:
 var movimento: Variant=controlador.get("movimento_selvagens")
 if movimento!=null and movimento.has_method("descrever_perfil"):
  return movimento.descrever_perfil()
 return {"id":"nao_disponivel","fidelidade_comprovada":false}
