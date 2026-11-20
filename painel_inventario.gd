extends "res://janela_base.gd"
## Inventário (C: window.inventory; textos do pacote original): a mochila em abas por categoria (Pokébola, Cura, Loot,
## Pedra de Evolução, Berry, Held Item, Item…), com quantidade e preço de NPC, e "Usar" para os itens que o jogo offline
## sabe usar (Rare Candy e berries: abre a janela de uso). Held items, TMs, addons e cartas aparecem, sem uso (lote 3
## congelado). Só desenha o EstadoJogo; usar vai pela janela de itens (sim/servico_itens.gd).

const LOOT: Script = preload("res://regras_loot.gd")
const PONTE := preload("res://ponte_cidade.gd")
const CATS := [["ball", "catBall"], ["heal", "catHeal"], ["loot", "catLoot"], ["stone", "catStone"], ["berry", "catBerry"], ["held", "catHeld"], ["outros", "catItem"]]
signal usar_solicitado
signal pocao_usada
signal aberto
var controlador: Node = null   # na hunt: caca_sim (a poção vai para a sim pelo use-heal)


func _ready() -> void:
	tamanho = Vector2(620, 560)
	aba = "loot"
	super._ready()


func itens() -> Dictionary:
	## categoria -> [{id (do servidor), nome, qtd, preco}]
	var ej: Node = get_node("/root/EstadoJogo")
	var dados = PONTE.dados()
	var cidade = PONTE.servico()
	var r := {}
	for c in CATS:
		r[c[0]] = []
	for id in ej.estoque_bolas:
		if int(ej.estoque_bolas[id]) > 0:
			r["ball"].append({"id": int(id), "nome": String(ej.obter_dados_bola(int(id)).get("nome", "Ball")), "qtd": int(ej.estoque_bolas[id]), "preco": 0})
	for id in ej.estoque_pocoes:
		if int(ej.estoque_pocoes[id]) > 0:
			r["heal"].append({"id": int(id), "nome": String(ej.obter_dados_pocao(int(id)).get("nome", "Potion")), "qtd": int(ej.estoque_pocoes[id]), "preco": int(dados.itens.get(int(id), {}).get("precoNpc", 0))})
	for interno in ej.inventario.estoque_materiais:
		var q := int(ej.inventario.estoque_materiais[interno])
		if q <= 0:
			continue
		var sid: int = LOOT.id_original(int(interno))
		var it: Dictionary = dados.itens.get(sid, {})
		var cat := String(it.get("categoria", "loot"))
		if not r.has(cat):
			cat = "outros"
		r[cat].append({"id": sid, "nome": String(it.get("nome", str(sid))), "qtd": q, "preco": cidade.preco_venda(sid)})
	for k in r:
		r[k].sort_custom(func(a, b): return String(a["nome"]) < String(b["nome"]))
	return r


func abrir() -> void:
	super.abrir()
	aberto.emit()


func usar_pocao(pid: int) -> String:
	## C (tutorial "Use uma potion": duplo clique numa Small Potion cura o líder na hora, até o valor da poção). Na hunt a
	## cura passa pela sim (use-heal); na cidade, direto no líder.
	var ej: Node = get_node("/root/EstadoJogo")
	var motivo := ""
	if controlador != null and controlador.has_method("usar_pocao"):
		controlador.usar_pocao(pid)
	else:
		motivo = ej.usar_pocao_no_lider(pid)
	if motivo == "":
		pocao_usada.emit()
	atualizar()
	return motivo


func montar() -> void:
	titulo.text = T.t("window.inventory.title", {}, "Inventário")
	var tudo := itens()
	for c in CATS:
		botao_aba(String(c[0]), "%s (%d)" % [T.t("window.inventory." + String(c[1])), (tudo[c[0]] as Array).size()])
	var lista: Array = tudo.get(aba, [])
	if lista.is_empty():
		rotulo(T.t("window.inventory.emptyBag", {}, "Mochila vazia."), Color("c8b89a"))
		return
	var total := 0
	for e in lista:
		var h := HBoxContainer.new()
		h.name = "I_%d" % int(e["id"])
		corpo.add_child(h)
		var ic: Texture2D = null
		var c: Dictionary = LOOT.obter(LOOT.id_interno(int(e["id"])))
		if not c.is_empty():
			ic = LOOT.textura(String(c.get("icone", "")))
		if ic != null:
			var tr := TextureRect.new()
			tr.texture = ic
			tr.custom_minimum_size = Vector2(24, 24)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h.add_child(tr)
		var n1 := rotulo("%d× %s" % [int(e["qtd"]), String(e["nome"])], Color.WHITE, 0, h)
		n1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if int(e["preco"]) > 0:
			rotulo("$" + n(int(e["preco"]) * int(e["qtd"])), Color("9fe0a0"), 0, h)
			total += int(e["preco"]) * int(e["qtd"])
		if aba == "heal":
			var pid := int(e["id"])
			h.mouse_filter = Control.MOUSE_FILTER_STOP
			h.gui_input.connect(func(ev: InputEvent) -> void:   # C: duplo clique na poção usa
				if ev is InputEventMouseButton and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
					usar_pocao(pid))
			botao(T.t("window.inventory.use", {}, "Usar"), func() -> void: usar_pocao(pid), "Usar_%d" % pid, h)
		if aba == "berry" or (aba == "outros" and String(e["nome"]).to_lower().find("rare candy") >= 0):
			botao("Usar", func() -> void:
				hide()
				usar_solicitado.emit(), "Usar_%d" % int(e["id"]), h)
	if total > 0:
		rotulo("Total a preço de NPC: $" + n(total), Color("c8b89a"))
