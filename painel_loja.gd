extends Control
## Loja do Mark (fase 4, lote 1). Só desenha e manda comandos: preços, ouro e regras vêm do serviço da cidade
## (sim/servico_cidade.gd, via _ej().loja/comprar_*/vender_*). Abas: Comprar (bolas e poções), Vender itens,
## Vender Pokémon (BOX).

signal fechado
const ESTILO: Script = preload("res://estilo_hud_original.gd")
const LOOT: Script = preload("res://regras_loot.gd")
var janela: PanelContainer
var corpo: VBoxContainer
var lista: VBoxContainer
var ouro: Label
var aviso: Label
var aba: String = "comprar"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tema := Theme.new()
	tema.default_font = preload("res://assets/interface/depot/barlow_semibold.ttf")
	tema.default_font_size = 13
	theme = tema
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			fechar())
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel", ESTILO.moldura())
	add_child(janela)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 8)
	janela.add_child(corpo)
	var cab := HBoxContainer.new()
	corpo.add_child(cab)
	var titulo := Label.new()
	titulo.text = "Mark — Loja"
	titulo.add_theme_font_override("font", preload("res://assets/interface/depot/cinzel.ttf"))
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", Color("f0e6d2"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(titulo)
	ouro = Label.new()
	ouro.name = "Ouro"
	ouro.add_theme_color_override("font_color", Color("f0c040"))
	cab.add_child(ouro)
	var x := Button.new()
	x.text = "×"
	x.pressed.connect(fechar)
	cab.add_child(x)
	var abas := HBoxContainer.new()
	corpo.add_child(abas)
	for par in [["comprar", "Comprar"], ["vender", "Vender itens"], ["pokemon", "Vender Pokémon"]]:
		var b := Button.new()
		b.text = par[1]
		b.name = "Aba_" + par[0]
		b.pressed.connect(func() -> void:
			aba = par[0]
			atualizar())
		abas.add_child(b)
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(520, 380)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(rolagem)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(lista)
	aviso = Label.new()
	aviso.add_theme_color_override("font_color", Color("b9c3cf"))
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	corpo.add_child(aviso)
	resized.connect(_ajustar)
	_ej().ouro_alterado.connect(func() -> void:
		if visible: atualizar())
	hide()


func abrir() -> void:
	aviso.text = ""
	show()
	atualizar()
	_ajustar()
	call_deferred("_ajustar")


func fechar() -> void:
	hide()
	fechado.emit()


func _ajustar() -> void:
	janela.size = Vector2(560, 520).max(janela.get_combined_minimum_size())
	janela.position = (size - janela.size) * 0.5


func _linha(texto: String, preco: String, acoes: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	var n := Label.new()
	n.text = texto
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var p := Label.new()
	p.text = preco
	p.add_theme_color_override("font_color", Color("f0c040"))
	h.add_child(p)
	for a in acoes:
		h.add_child(a)
	lista.add_child(h)
	return h


func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.pressed.connect(acao)
	return b


func _resultado(erro: String, ok: String) -> void:
	aviso.text = erro if not erro.is_empty() else ok
	atualizar()


func atualizar() -> void:
	for c in lista.get_children():
		lista.remove_child(c)
		c.queue_free()
	var loja: Dictionary = _ej().loja()
	ouro.text = "💲 %d" % int(loja.get("gold", _ej().ouro))
	if loja.get("type") == "error":
		aviso.text = String(loja.get("message", ""))
		return
	match aba:
		"comprar":
			for b in loja.get("balls", []):
				var id := int(b["id"])
				var acoes: Array = []
				for q in [1, 10, 100]:
					acoes.append(_botao("+%d" % q, func() -> void:
						_resultado(_ej().comprar_bola(id, q), "Comprou %d× %s." % [q, b["name"]])))
				_linha("%s (você tem %d)" % [b["name"], _ej().obter_quantidade_bola(id)], "💲%d" % int(b["priceGold"]), acoes)
			for it in loja.get("items", []):
				var id := int(it["id"])
				var acoes: Array = []
				for q in [1, 10, 100]:
					acoes.append(_botao("+%d" % q, func() -> void:
						_resultado(_ej().comprar_item(id, q), "Comprou %d× %s." % [q, it["name"]])))
				_linha("%s (você tem %d)" % [it["name"], _ej().obter_quantidade_pocao(id)], "💲%d" % int(it["priceGold"]), acoes)
		"vender":
			var todos: Array = []
			for it in loja.get("sell", []):
				var id := int(it["itemId"])
				var q := int(it["quantity"])
				todos.append({"itemId": id, "qty": q})
				_linha("%s ×%d" % [it["name"], q], "💲%d cada" % int(it["price"]), [
					_botao("Vender 1", func() -> void: _vender([{"itemId": id, "qty": 1}])),
					_botao("Vender tudo", func() -> void: _vender([{"itemId": id, "qty": q}]))])
			if todos.is_empty():
				aviso.text = "Nada para vender na BAG."
			else:
				lista.add_child(_botao("Vender todos os itens da lista", func() -> void: _vender(todos)))
		"pokemon":
			for pk in _ej().pokemons_capturados:
				var alvo: DadosPokemon = pk
				var valor := int(preload("res://ponte_cidade.gd").dados().especie(preload("res://ponte_cidade.gd").id_especie(pk.especie.nome)).get("valorVenda", 0))
				_linha("%s Lv.%d" % [pk.especie.nome, pk.nivel], "💲%d" % valor, [_botao("Vender", func() -> void:
					var r: Dictionary = _ej().vender_pokemon([alvo])
					_resultado(String(r.get("erro", "")), "+💲%d" % int(r.get("goldGained", 0))))])
			if _ej().pokemons_capturados.is_empty():
				aviso.text = "Nenhum Pokémon na BOX."


func _vender(itens: Array) -> void:
	var r: Dictionary = _ej().vender_itens(itens)
	_resultado(String(r.get("erro", "")), "+💲%d (× %d)" % [int(r.get("goldGained", 0)), int(r.get("soldCount", 0))])


func _ej() -> Node:
	return get_node("/root/EstadoJogo")
