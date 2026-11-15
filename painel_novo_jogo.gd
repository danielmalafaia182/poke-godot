extends Control
## Jogo novo (como a tela "CHOOSE YOUR STARTER POKÉMON" do original, C): nome do treinador e um de três iniciais —
## Bulbasaur, Charmander ou Squirtle — no nível 1, com 100 Small Potions e 100 Poké Balls. Depois de escolher, mostra a
## primeira hunt recomendada pelo tutorial do original (C). Só desenha e manda o comando: regras em sim/servico_novo_jogo.gd
## (EstadoJogo.novo_jogo). Aparece só quando o jogo abre sem save (cidade.gd).

const ESTILO: Script = preload("res://estilo_hud_original.gd")
const NovoJogo := preload("res://sim/servico_novo_jogo.gd")
var janela: PanelContainer
var corpo: VBoxContainer
var nome: LineEdit
signal concluido(resultado: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.75)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel", ESTILO.moldura())
	add_child(janela)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 10)
	janela.add_child(corpo)
	resized.connect(_ajustar)
	_montar()


func _ajustar() -> void:
	janela.size = Vector2(520, 0).max(janela.get_combined_minimum_size())
	janela.position = (size - janela.size) * 0.5


func _rotulo(t: String, tam: int = 14, cor: Color = Color("f0e6d2")) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	corpo.add_child(l)


func _montar() -> void:
	_rotulo("ESCOLHA SEU POKÉMON INICIAL", 20)
	_rotulo("Ele será o líder do time — o que caça. Os outros virão das capturas.", 14, Color("b9c3cf"))
	nome = LineEdit.new()
	nome.name = "Nome"
	nome.placeholder_text = "Nome do treinador (3 a 16 letras)"
	nome.max_length = 16
	corpo.add_child(nome)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	corpo.add_child(linha)
	for id in [1, 4, 7]:
		var b := Button.new()
		b.name = "Inicial_%d" % id
		b.text = String(NovoJogo.INICIAIS[id]["nome"])
		b.custom_minimum_size = Vector2(150, 48)
		b.pressed.connect(func() -> void: escolher(id))
		linha.add_child(b)
	_rotulo("Todo jogador novo começa com 100 Small Potions e 100 Poké Balls.", 13, Color("8a96a3"))
	_ajustar()
	call_deferred("_ajustar")


func escolher(id: int) -> void:
	var n := nome.text.strip_edges()
	var r: Dictionary = get_node("/root/EstadoJogo").novo_jogo(id, n if n.length() >= 3 else "Treinador")
	if r.has("erro"):
		return
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	_rotulo("Bem-vindo, %s!" % String(r["treinador"]), 20)
	var hunts: Dictionary = preload("res://ponte_cidade.gd").dados().hunts
	var h: String = String(hunts.get(String(r["hunt_recomendada"]), {}).get("nome", String(r["hunt_recomendada"])))
	_rotulo("Com o seu %s, a melhor primeira hunt é %s (%s!). É nível 1, perfeita para começar: abra o mapa e clique nela." % [
		String(r["inicial"]["nome"]), h, String(r["por_que"])], 14, Color("b9c3cf"))
	var ok := Button.new()
	ok.name = "Comecar"
	ok.text = "🎮 Começar a jornada!"
	ok.pressed.connect(func() -> void:
		concluido.emit(r)
		queue_free())
	corpo.add_child(ok)
	_ajustar()
	call_deferred("_ajustar")
