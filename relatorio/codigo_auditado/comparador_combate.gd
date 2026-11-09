extends Control
const MOTOR=preload("res://comparador_regras_combate.gd")
const IMPORTADOR=preload("res://importador_registro_combate.gd")
var casos: Array=[]
var resultado: Dictionary={}
var importado: Dictionary={}
var controles: Dictionary={}
var seletor: OptionButton
var modelo: OptionButton
var tabela: Tree
var detalhes: RichTextLabel
var aviso: Label
var seletor_arquivo: FileDialog
var pronto: bool=false
var ultimo_arquivo_json: String=""
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var fundo: ColorRect=ColorRect.new();fundo.color=Color("0b1620");fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(fundo)
 var margem: MarginContainer=MarginContainer.new();margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for lado in ["left","right","top","bottom"]:margem.add_theme_constant_override("margin_"+lado,18)
 add_child(margem)
 var coluna: VBoxContainer=VBoxContainer.new();margem.add_child(coluna)
 var titulo: Label=Label.new();titulo.text="Laboratório · Comparador de combate";titulo.add_theme_font_size_override("font_size",22);coluna.add_child(titulo)
 aviso=Label.new();aviso.text="Experimentos locais: nenhuma configuração desta tela altera a caça ou o save.";aviso.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;coluna.add_child(aviso)
 var topo: HBoxContainer=HBoxContainer.new();coluna.add_child(topo)
 seletor=OptionButton.new();seletor.size_flags_horizontal=Control.SIZE_EXPAND_FILL;topo.add_child(seletor)
 casos=MOTOR.casos()
 for caso in casos:seletor.add_item(caso["titulo"])
 modelo=OptionButton.new();modelo.add_item("V2 · atual");modelo.add_item("V1 · anterior");topo.add_child(modelo)
 var acesso: HBoxContainer=HBoxContainer.new();coluna.add_child(acesso)
 _botao(acesso,"Nova sessão pareada · Exeggutor404 / Gyarados214",func() -> void:get_tree().change_scene_to_file("res://laboratorio_pareado.tscn"))
 _botao(topo,"Restaurar hipótese",_restaurar)
 _botao(topo,"Importar log local",_abrir_arquivo)
 _botao(topo,"Exportar JSON + texto",_exportar)
 var split: HSplitContainer=HSplitContainer.new();split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.split_offset=290;coluna.add_child(split)
 var scroll: ScrollContainer=ScrollContainer.new();scroll.custom_minimum_size.x=275;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;split.add_child(scroll)
 var lateral: VBoxContainer=VBoxContainer.new();lateral.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(lateral)
 var rotulo: Label=Label.new();rotulo.text="Selvagem · hipótese de combate\nAtributos originais: desconhecidos";rotulo.add_theme_color_override("font_color",Color("f0c35b"));lateral.add_child(rotulo)
 for campo in ["nivel","vida_maxima","hp","atk","def","spAtk","spDef","speed"]:
  var linha: HBoxContainer=HBoxContainer.new();lateral.add_child(linha)
  var nome: Label=Label.new();nome.text={"nivel":"Nível de combate","vida_maxima":"HP máximo","hp":"Atributo HP","atk":"Atk","def":"Def","spAtk":"SpAtk","spDef":"SpDef","speed":"Speed (sem função)"}[campo];nome.size_flags_horizontal=Control.SIZE_EXPAND_FILL;linha.add_child(nome)
  var controle: SpinBox=SpinBox.new();controle.min_value=1 if campo in ["nivel","vida_maxima"] else 0;controle.max_value=1000000;controle.step=1;controle.custom_minimum_size.x=110;linha.add_child(controle);controles[campo]=controle
  controle.value_changed.connect(func(_v: float) -> void:
   if pronto:_recalcular()
  )
 var nota: Label=Label.new();nota.text="HP máximo e atributos são independentes. Alterar aqui não edita os IVs nem o nível de um Pokémon capturado.";nota.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;lateral.add_child(nota)
 var direita: VSplitContainer=VSplitContainer.new();direita.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(direita)
 tabela=Tree.new();tabela.columns=4;tabela.hide_root=true;tabela.column_titles_visible=true;tabela.custom_minimum_size.y=240;direita.add_child(tabela)
 for i in range(4):tabela.set_column_title(i,["Métrica","Original","Local","Avaliação"][i])
 tabela.set_column_expand_ratio(0,3);tabela.set_column_expand_ratio(1,3);tabela.set_column_expand_ratio(2,2);tabela.set_column_expand_ratio(3,3)
 detalhes=RichTextLabel.new();detalhes.custom_minimum_size.y=150;detalhes.size_flags_vertical=Control.SIZE_EXPAND_FILL;direita.add_child(detalhes)
 seletor_arquivo=FileDialog.new();seletor_arquivo.access=FileDialog.ACCESS_FILESYSTEM;seletor_arquivo.file_mode=FileDialog.FILE_MODE_OPEN_FILE;seletor_arquivo.filters=PackedStringArray(["*.jsonl ; Diagnóstico local de combate"]);seletor_arquivo.file_selected.connect(_importar);add_child(seletor_arquivo)
 seletor.item_selected.connect(func(_i: int) -> void:importado={};_restaurar())
 modelo.item_selected.connect(func(_i: int) -> void:_recalcular())
 tabela.item_selected.connect(_mostrar_nota)
 _restaurar()
func _botao(pai: Node,texto: String,acao: Callable) -> void:
 var b: Button=Button.new();b.text=texto;b.pressed.connect(acao);pai.add_child(b)
func _restaurar() -> void:
 pronto=false
 var p: Dictionary=MOTOR.perfil_padrao(casos[seletor.selected])
 for chave in controles:controles[chave].value=p[chave] if chave in ["nivel","vida_maxima"] else p["atributos"][chave]
 pronto=true;_recalcular()
func _perfil() -> Dictionary:
 var p: Dictionary={"especie":casos[seletor.selected]["inimigo"]["especie"],"nivel":int(controles["nivel"].value),"vida_maxima":int(controles["vida_maxima"].value),"atributos":{}}
 for chave in ["hp","atk","def","spAtk","spDef","speed"]:p["atributos"][chave]=int(controles[chave].value)
 return p
func _curto(v: Variant) -> String:
 if v==null:return "—"
 if v is Dictionary or v is Array:return JSON.stringify(v)
 return str(v)
func _recalcular() -> void:
 resultado=MOTOR.comparar(casos[seletor.selected],_perfil(),"v2" if modelo.selected==0 else "v1")
 tabela.clear();var raiz: TreeItem=tabela.create_item()
 if resultado.has("erro"):aviso.text=resultado["erro"];return
 for linha in resultado["linhas"]:
  var item: TreeItem=tabela.create_item(raiz)
  for i in range(4):
   var valor: Variant=linha[["metrica","original","local","status"][i]]
   item.set_text(i,_curto(valor));item.set_tooltip_text(i,_curto(valor)+"\n"+linha["nota"])
  item.set_metadata(0,linha)
  item.set_custom_color(3,Color("ef8274") if linha["status"]=="DIVERGE" else (Color("83d6b2") if linha["status"]=="COINCIDE" else Color("e5c77b")))
 aviso.text="Hipóteses editáveis · %s · fidelidade global ainda não comprovada" % resultado["modelo_local"]
 detalhes.text=_relatorio()
func _mostrar_nota() -> void:
 var item: TreeItem=tabela.get_selected()
 if item!=null:
  var nota: String=item.get_metadata(0).get("nota","")
  aviso.text=nota if not nota.is_empty() else "Comparação numérica do caso, sem fidelidade global comprovada."
func _relatorio() -> String:
 var texto: String="%s · %s\n" % [resultado.get("titulo",""),resultado.get("modelo_local","")]
 texto+="IVs do aliado: "+str(resultado.get("fixture_aliado",{}).get("origem_ivs",""))+"\n"
 for g in resultado.get("golpes",[]):
  texto+="\n%s %s (%s): local %d · original %s · diferença até a faixa %d\n" % [g["direcao"],g["nome"],g["categoria"],g["dano_local"],str(g["intervalo_original"]),g["diferenca_ate_faixa"]]
  texto+="Sensibilidade de %s: %s\n" % [g["atributo_defensivo"],str(g["sensibilidade"])]
  texto+="Golpes para KO na hipótese, sem cura: %s\nTempos simulados (s): %s\n" % [_curto(g["golpes_para_ko_sem_cura"]),str(g["tempos_simulados_s"])]
 texto+="\nReferência capturável local Lv1 (não editada): "+str(resultado.get("referencia_capturavel_local",{}))+"\n"
 for limite in resultado.get("limites",[]):texto+="\n• "+limite
 if not importado.is_empty():
  texto+="\n\nDIAGNÓSTICO LOCAL IMPORTADO\n"+JSON.stringify(importado,"  ")
  if int(importado.get("aceitos",0))==0:texto+="\nNenhum golpe com o mesmo perfil de aliado e espécie inimiga. Não é comparação direta."
 return texto
func _abrir_arquivo() -> void:seletor_arquivo.popup_centered_ratio(0.8)
func _importar(caminho: String) -> void:
 importado=IMPORTADOR.ler(caminho,casos[seletor.selected]);detalhes.text=_relatorio()
 aviso.text=str(importado["erro"]) if importado.has("erro") else "Log: %d golpes compatíveis; %d de outros perfis" % [importado["aceitos"],importado["descartados_perfil"]]
func _exportar() -> void:
 if resultado.is_empty() or resultado.has("erro"):return
 DirAccess.make_dir_recursive_absolute("user://diagnosticos_combate")
 var base: String="user://diagnosticos_combate/comparador_%d_%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
 var exportado: Dictionary=resultado.duplicate(true);exportado["log_local_importado"]=importado.duplicate(true)
 var json: FileAccess=FileAccess.open(base+".json",FileAccess.WRITE)
 if json==null:aviso.text="Falha ao exportar JSON.";return
 json.store_string(JSON.stringify(exportado,"  "));json.close()
 var txt: FileAccess=FileAccess.open(base+".txt",FileAccess.WRITE)
 if txt==null:aviso.text="JSON salvo; falha ao exportar texto.";return
 var texto: String=_relatorio()+"\n\nCOMPARAÇÃO\n"
 for linha in resultado["linhas"]:texto+="%s | original: %s | local: %s | %s\n%s\n" % [linha["metrica"],_curto(linha["original"]),_curto(linha["local"]),linha["status"],linha["nota"]]
 txt.store_string(texto);txt.close();aviso.text="Exportado: "+ProjectSettings.globalize_path(base+".json")
 ultimo_arquivo_json=base+".json"
 print("COMPARADOR EXPORTADO: ",ProjectSettings.globalize_path(base))
