extends Control
const MOTOR=preload("res://analise_encontros_pareados.gd")
var motor: RefCounted=MOTOR.new()
var amostra: Dictionary={}
var analise: Dictionary={}
var lista: Array=[]
var familia_lista: Array=[]
var seletor: OptionButton
var familia: OptionButton
var defesa: SpinBox
var spdef: SpinBox
var tabela: Tree
var tabela_familias: Tree
var detalhes: RichTextLabel
var aviso: Label
var resultado: Dictionary={}
var pronto: bool=false
var ultimo_json: String=""
func _botao(pai: Node,texto: String,acao: Callable) -> void:
 var b: Button=Button.new();b.text=texto;b.pressed.connect(acao);pai.add_child(b)
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 amostra=MOTOR.carregar();motor.iniciar(amostra);analise=motor.analisar_todos()
 var fundo: ColorRect=ColorRect.new();fundo.color=Color("0b1620");fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(fundo)
 var margem: MarginContainer=MarginContainer.new();margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for lado in ["left","right","top","bottom"]:margem.add_theme_constant_override("margin_"+lado,16)
 add_child(margem)
 var coluna: VBoxContainer=VBoxContainer.new();margem.add_child(coluna)
 var titulo: Label=Label.new();titulo.text="Laboratório · mesma vida do selvagem, dois aliados";titulo.add_theme_font_size_override("font_size",21);coluna.add_child(titulo)
 aviso=Label.new();aviso.text="12 encontros · 4 pareados · hipóteses locais; nenhuma alteração na caça ou no save";aviso.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;coluna.add_child(aviso)
 var topo: HBoxContainer=HBoxContainer.new();coluna.add_child(topo)
 seletor=OptionButton.new();seletor.size_flags_horizontal=Control.SIZE_EXPAND_FILL;topo.add_child(seletor)
 var todos: Array=motor.encontros()
 for pareado in [true,false]:
  for e in todos:
   if e["pareado"]==pareado:lista.append(e)
 for e in lista:seletor.add_item(("Pareado" if e["pareado"] else "Controle")+" · "+e["id_local"]+" · HP"+str(e["hp_maximo"]))
 familia=OptionButton.new();familia_lista=MOTOR.familias()
 for f in familia_lista:familia.add_item(f["nome"])
 familia.select(2);topo.add_child(familia)
 _botao(topo,"Usar exemplo compatível",_usar_exemplo)
 _botao(topo,"Exportar JSON + texto",_exportar)
 var linha: HBoxContainer=HBoxContainer.new();coluna.add_child(linha)
 for campo in ["Def compartilhada","SpDef compartilhada"]:
  var l: Label=Label.new();l.text=campo;linha.add_child(l)
  var spin: SpinBox=SpinBox.new();spin.min_value=1;spin.max_value=MOTOR.LIMITE_DEFESA;spin.step=1;spin.custom_minimum_size.x=120;linha.add_child(spin)
  if campo.begins_with("Def"):defesa=spin;defesa.value=106
  else:spdef=spin;spdef.value=110
  spin.value_changed.connect(func(_v: float) -> void:
   if pronto:_atualizar()
  )
 var nota: Label=Label.new();nota.text="Mesmo Def/SpDef para todos os golpes deste encontro. STAB e multiplicador antes do arredondamento: hipóteses, não regras confirmadas.";nota.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;coluna.add_child(nota)
 var split: VSplitContainer=VSplitContainer.new();split.size_flags_vertical=Control.SIZE_EXPAND_FILL;coluna.add_child(split)
 var superior: HSplitContainer=HSplitContainer.new();superior.custom_minimum_size.y=210;superior.split_offset=440;split.add_child(superior)
 tabela_familias=Tree.new();tabela_familias.columns=4;tabela_familias.hide_root=true;tabela_familias.column_titles_visible=true;tabela_familias.custom_minimum_size.x=280;superior.add_child(tabela_familias)
 for i in range(4):tabela_familias.set_column_title(i,["Família","Pares: dano","+ Golpe","Todos"][i])
 tabela_familias.set_column_expand_ratio(0,3)
 var raiz: TreeItem=tabela_familias.create_item()
 for f in analise["familias"]:
  var item: TreeItem=tabela_familias.create_item(raiz)
  item.set_text(0,f["familia"]["nome"]);item.set_text(1,"%d/4" % f["pareados_com_dano_compativel"]);item.set_text(2,"%d/4" % f["pareados_com_dano_e_escolha"]);item.set_text(3,"%d/%d" % [f["sessao_com_dano_e_escolha"],f["total_elegiveis"]])
  item.set_tooltip_text(0,f["familia"]["nome"])
  item.set_tooltip_text(3,"Encontros de toda a sessão com dano e escolha nominal compatíveis, incluindo os controles sem troca.")
  item.set_tooltip_text(2,"Existência de um perfil por encontro, não uma defesa única para todos os selvagens. Não valida distribuição ou política universal.")
 tabela=Tree.new();tabela.columns=6;tabela.hide_root=true;tabela.column_titles_visible=true;tabela.size_flags_horizontal=Control.SIZE_EXPAND_FILL;superior.add_child(tabela)
 for i in range(6):tabela.set_column_title(i,["Pacote (s)","Aliado / golpe","Dano","HP antes → depois","Faixa da hipótese","Avaliação"][i])
 tabela.set_column_expand_ratio(1,3);tabela.set_column_expand_ratio(3,2)
 detalhes=RichTextLabel.new();detalhes.custom_minimum_size.y=170;split.add_child(detalhes)
 seletor.item_selected.connect(func(_i: int) -> void:_atualizar())
 familia.item_selected.connect(func(_i: int) -> void:_atualizar())
 for i in range(lista.size()):
  if lista[i]["pareado"] and lista[i]["slot"]==10:seletor.select(i);break
 pronto=true;_atualizar()
func _atualizar() -> void:
 var e: Dictionary=lista[seletor.selected];var f: Dictionary=familia_lista[familia.selected]
 resultado=motor.hipotese(e,int(defesa.value),int(spdef.value),f)
 tabela.clear();var raiz: TreeItem=tabela.create_item()
 for h in e["golpes"]:
  var grupo: Dictionary={}
  for g in resultado.get("grupos",[]):
   if g["perfil_id"]==h["perfil_id"] and g["golpe"]==h["golpe"]:grupo=g;break
  var p: Dictionary=amostra["perfis"].get(h["perfil_id"],{})
  var item: TreeItem=tabela.create_item(raiz)
  var faixa: Array=grupo.get("faixa_hipotetica",[])
  var dentro: bool=faixa.size()==2 and float(h["dano"])>=float(faixa[0]) and float(h["dano"])<=float(faixa[1])
  var campos: Array=[h["t_s"],"%s Lv%d · %s" % [h["aliado"],int(p.get("nivel",0)),h["golpe"]],h["dano"],str(h["hp_antes_pacote"])+" → "+str(h["hp_depois_pacote"]),grupo.get("faixa_hipotetica",[]),"SOB HIPÓTESE" if dentro else "DIVERGE"]
  for i in range(6):item.set_text(i,str(campos[i]));item.set_tooltip_text(i,str(campos[i]))
  item.set_custom_color(5,Color("e5c77b") if dentro else Color("ef8274"))
 detalhes.text=_texto()
 aviso.text="Blastoise · %s · danos %s · escolha nominal %s · não é confirmação da fórmula" % [e["id_local"],"compatíveis sob hipótese" if resultado.get("danos_compativeis",false) else "divergentes", "compatível sob hipótese" if resultado.get("escolhas_nominais_compativeis",false) else "divergente"]
func _texto() -> String:
 var e: Dictionary=lista[seletor.selected];var f: Dictionary=familia_lista[familia.selected]
 var busca: Dictionary=motor.analisar_familia(e,f)
 var texto: String="ENCONTRO: %s · HP%d\n" % [e["id_local"],e["hp_maximo"]]
 for pid in e["perfil_ids"]:
  var p: Dictionary=amostra["perfis"][pid]
  texto+="%s Lv%d · Q%.3f · Power%d · HP%d\n%s\n" % [p["especie"],p["nivel"],p["qualidade"],p["power"],p["hp_maximo"],str(p["atributos"])]
 texto+="\nBUSCA DE HIPÓTESES: "+str(busca)+"\n"
 for g in resultado.get("grupos",[]):
  texto+="\n%s · observados %s · nominal %d · melhor nominal %s\nDispersão simétrica mínima neste grupo, considerando arredondamento: %.2f%% (não é estimativa do RNG original).\n" % [g["golpe"],str(g["observados"]),g["nominal"],g["melhor_nominal"],g["dispersao_minima_simetrica_pct"]]
 texto+="\nCONTINUIDADE DE HP\n"+str(e["curva_hp"])+"\n\nLIMITES\n"
 for l in analise["limites"]:texto+="• "+l+"\n"
 texto+="\nGolpes recebidos ficam separados: slot=-1 não identifica o atacante. O exemplo de uma hipótese não é atributo revelado."
 return texto
func _usar_exemplo() -> void:
 var r: Dictionary=motor.analisar_familia(lista[seletor.selected],familia_lista[familia.selected])
 if r.get("exemplo",{}).is_empty():aviso.text="Não há exemplo com dano e escolha nominal nesta busca. Consulte os limites.";return
 pronto=false;defesa.value=r["exemplo"]["def"];spdef.value=r["exemplo"]["spDef"];pronto=true;_atualizar()
func _exportar() -> void:
 DirAccess.make_dir_recursive_absolute("user://diagnosticos_combate")
 var base: String="user://diagnosticos_combate/pareado_%d_%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
 var r: Dictionary={"amostra":amostra,"analise_familias":analise,"hipotese_selecionada":resultado,"fidelidade_global_comprovada":false}
 var j: FileAccess=FileAccess.open(base+".json",FileAccess.WRITE)
 if j==null:aviso.text="Falha ao exportar JSON.";return
 j.store_string(JSON.stringify(r,"  "));j.close()
 var txt: FileAccess=FileAccess.open(base+".txt",FileAccess.WRITE)
 if txt==null:aviso.text="JSON exportado; falha no texto.";return
 txt.store_string(_texto()+"\n\nTODAS AS FAMÍLIAS\n"+JSON.stringify(analise,"  "));txt.close()
 ultimo_json=base+".json";aviso.text="Exportado: "+ProjectSettings.globalize_path(ultimo_json)
 print("PAREADO EXPORTADO: ",ProjectSettings.globalize_path(base))
