extends Control
const A=preload("res://auditoria_ofensiva_selvagens.gd")
var amostra: Dictionary={}
var resultado: Dictionary={}
var limites_niveis: Dictionary={}
var nivel: SpinBox
var texto: RichTextLabel
var status: Label
func _ready() -> void:
	amostra=A.carregar();limites_niveis=A.varrer(amostra)
	var fundo: ColorRect=ColorRect.new();fundo.color=Color("101b24");fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(fundo)
	var margem: MarginContainer=MarginContainer.new();margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left","top","right","bottom"]:margem.add_theme_constant_override("margin_"+lado,18)
	add_child(margem)
	var coluna: VBoxContainer=VBoxContainer.new();margem.add_child(coluna)
	var titulo: Label=Label.new();titulo.text="Dano recebido · limites dos selvagens";titulo.add_theme_font_size_override("font_size",23);coluna.add_child(titulo)
	var aviso: Label=Label.new();aviso.text="Blastoise do original contra Gyarados214 e Exeggutor406. Hipótese de nível único; a caça pode usar nível ofensivo do catálogo. Consulta sem alterar saves.";aviso.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;coluna.add_child(aviso)
	var linha: HBoxContainer=HBoxContainer.new();coluna.add_child(linha)
	var legenda: Label=Label.new();legenda.text="Nível de combate hipotético:";linha.add_child(legenda)
	nivel=SpinBox.new();nivel.min_value=1;nivel.max_value=200;nivel.value=80;linha.add_child(nivel)
	for valor in [80,94,100,150]:
		var b: Button=Button.new();b.text=str(valor);b.pressed.connect(func() -> void:nivel.value=valor);linha.add_child(b)
	var exportar: Button=Button.new();exportar.text="Exportar JSON";exportar.pressed.connect(exportar_resultado);linha.add_child(exportar)
	texto=RichTextLabel.new();texto.size_flags_vertical=Control.SIZE_EXPAND_FILL;texto.selection_enabled=true;coluna.add_child(texto)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;coluna.add_child(status)
	nivel.value_changed.connect(func(_v: float) -> void:atualizar());atualizar()
func atualizar() -> void:
	resultado=A.analisar(int(nivel.value),amostra)
	var linhas: Array[String]=["Nível testado: %d · %d/%d danos fora dos limites · %d eventos de transição excluídos" % [nivel.value,resultado["fora_limites"],resultado["eventos"],resultado["excluidos_transicao"]],""]
	for g in resultado["grupos"]:
		linhas.append("%s → %s Lv%d | observado %d–%d | limites locais %d–%d | %d/%d fora" % [g["golpe"],g["aliado"],g["nivel_aliado"],g["observados"].min(),g["observados"].max(),g["limites_dano"][0],g["limites_dano"][1],g["fora_limites"].size(),g["observados"].size()])
	linhas.append("\nNíveis não refutados pelos envelopes, na busca1–200: "+str(limites_niveis["niveis_nao_refutados_pelos_envelopes"]))
	linhas.append("Também respeitam o menor HP observado sob a candidataHP×35: "+str(limites_niveis["niveis_nao_refutados_dano_e_hp_minimo"]))
	linhas.append("\nIsso não identifica o nível real. Nível, geração de atributos e fórmula ofensiva permanecem hipóteses distintas.")
	linhas.append("\nPREMISSAS\n"+"\n".join(resultado["premissas"]))
	linhas.append("\nLIMITES\n"+"\n".join(resultado["limites"]))
	texto.text="\n".join(linhas)
	status.text="Nenhuma configuração do jogo foi alterada. Nível de acesso e nível de combate podem ser distintos."
func exportar_resultado() -> void:
	var pasta: String="user://diagnosticos_combate"
	DirAccess.make_dir_recursive_absolute(pasta)
	var caminho: String=pasta+"/ofensiva_%d_%d.json" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
	var f: FileAccess=FileAccess.open(caminho,FileAccess.WRITE)
	if f==null:status.text="Falha ao exportar.";return
	f.store_string(JSON.stringify({"resultado":resultado,"busca_niveis":limites_niveis},"  "));f.close()
	status.text="Exportado: "+ProjectSettings.globalize_path(caminho)
