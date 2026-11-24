@tool
extends VBoxContainer
## Dock "Game Master" (editor). Duas abas:
##   Parâmetros — busca por nome e filtro por sistema; cada parâmetro com valor atual (perfil ativo), valor original,
##                origem e status (os mesmos do REGRAS.md); editar o valor (Aplicar), "Restaurar original" do campo e
##                "Restaurar grupo" (o Resource inteiro).
##   Tabelas    — espécies, itens e hunts com busca (ex.: "Larvitar": XP, preço, chance da 1ª captura com Super Ball e os
##                drops); as células editáveis gravam em AlteracoesTabelas do perfil; "Restaurar" tira a alteração.
## Perfis: escolher, ativar e criar (a partir do ativo). O perfil "original" nunca é editado: as edições vão para o perfil
## ativo em res://dados/regras/<perfil>/.

const RJ := preload("res://sim/regras_jogo.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Regras := preload("res://sim/regras.gd")

var cat: Dictionary = {}
var perfil_op: OptionButton
var novo_nome: LineEdit
var aviso: Label
var busca: LineEdit
var sistema_op: OptionButton
var arvore: Tree
var desc: Label
var campo_valor: LineEdit
var sel: Dictionary = {}
var tab_op: OptionButton
var busca_tab: LineEdit
var arvore_tab: Tree
var dados


func _ready() -> void:
	custom_minimum_size = Vector2(320, 400)
	var f := FileAccess.open("res://dados/regras/catalogo.json", FileAccess.READ)
	cat = JSON.parse_string(f.get_as_text()) if f != null else {"parametros": []}
	var topo := HBoxContainer.new()
	add_child(topo)
	topo.add_child(_label("Perfil:"))
	perfil_op = OptionButton.new()
	perfil_op.name = "Perfil"
	topo.add_child(perfil_op)
	var ativar := _botao("Ativar", func() -> void:
		var erro := RJ.definir_perfil(perfil_op.get_item_text(perfil_op.selected), false)
		_avisar(erro if erro != "" else "Perfil ativo: " + RJ.perfil())
		_preencher())
	ativar.name = "Ativar"
	topo.add_child(ativar)
	novo_nome = LineEdit.new()
	novo_nome.placeholder_text = "novo perfil"
	novo_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(novo_nome)
	var novo := _botao("Novo perfil", func() -> void:
		var e := RJ.criar_perfil(novo_nome.text.strip_edges(), RJ.perfil(), false)
		if e == "":
			e = RJ.definir_perfil(novo_nome.text.strip_edges(), false)
		_avisar(e if e != "" else "Perfil criado e ativo: " + RJ.perfil())
		_perfis()
		_preencher())
	novo.name = "NovoPerfil"
	topo.add_child(novo)
	aviso = _label("")
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(aviso)
	var abas := TabContainer.new()
	abas.name = "Abas"
	abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(abas)
	abas.add_child(_aba_parametros())
	abas.add_child(_aba_tabelas())
	_perfis()
	_preencher()


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _botao(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	return b


func _avisar(t: String) -> void:
	aviso.text = t


func _perfis() -> void:
	perfil_op.clear()
	for p in RJ.perfis():
		perfil_op.add_item(p)
		if p == RJ.perfil():
			perfil_op.select(perfil_op.item_count - 1)


# ------------------------------------------------------------------ Parâmetros

func _aba_parametros() -> Control:
	var v := VBoxContainer.new()
	v.name = "Parâmetros"
	var h := HBoxContainer.new()
	v.add_child(h)
	busca = LineEdit.new()
	busca.name = "Busca"
	busca.placeholder_text = "buscar parâmetro (nome ou descrição)"
	busca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	busca.text_changed.connect(func(_t: String) -> void: _preencher())
	h.add_child(busca)
	sistema_op = OptionButton.new()
	sistema_op.name = "Sistema"
	sistema_op.add_item("todos os sistemas")
	var sis: Array = []
	for e in cat.get("parametros", []):
		if not String(e["sistema"]) in sis:
			sis.append(String(e["sistema"]))
	sis.sort()
	for s in sis:
		sistema_op.add_item(s)
	sistema_op.item_selected.connect(func(_i: int) -> void: _preencher())
	h.add_child(sistema_op)
	arvore = Tree.new()
	arvore.name = "Arvore"
	arvore.columns = 5
	arvore.column_titles_visible = true
	for i in 5:
		arvore.set_column_title(i, ["Parâmetro", "Valor", "Original", "Origem", "Status"][i])
	arvore.hide_root = true
	arvore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arvore.item_selected.connect(_selecionar)
	v.add_child(arvore)
	desc = _label("")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var h2 := HBoxContainer.new()
	v.add_child(h2)
	campo_valor = LineEdit.new()
	campo_valor.name = "Valor"
	campo_valor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h2.add_child(campo_valor)
	var ap := _botao("Aplicar", _aplicar)
	ap.name = "Aplicar"
	h2.add_child(ap)
	var h3 := HBoxContainer.new()
	v.add_child(h3)
	var r1 := _botao("Restaurar original", func() -> void:
		if not sel.is_empty():
			var erro := RJ.restaurar(String(sel["recurso"]), String(sel["chave"]), "", false)
			_avisar(erro if erro != "" else "%s restaurado." % sel["chave"])
			_preencher())
	r1.name = "RestaurarCampo"
	h3.add_child(r1)
	var r2 := _botao("Restaurar grupo", func() -> void:
		if not sel.is_empty():
			var erro := RJ.restaurar(String(sel["recurso"]), "", "", false)
			_avisar(erro if erro != "" else "%s inteiro restaurado ao original." % sel["recurso"])
			_preencher())
	r2.name = "RestaurarGrupo"
	h3.add_child(r2)
	return v


func _preencher() -> void:
	if arvore == null:
		return
	arvore.clear()
	var raiz := arvore.create_item()
	var q := busca.text.strip_edges().to_lower()
	var s := sistema_op.get_item_text(sistema_op.selected) if sistema_op.selected > 0 else ""
	var grupos := {}
	for e in cat.get("parametros", []):
		if s != "" and String(e["sistema"]) != s:
			continue
		if q != "" and not String(e["chave"]).to_lower().contains(q) and not String(e["descricao"]).to_lower().contains(q):
			continue
		var rec := String(e["recurso"])
		if not grupos.has(rec):
			var g := arvore.create_item(raiz)
			g.set_text(0, rec)
			g.set_text(4, String(e["sistema"]))
			grupos[rec] = g
		var it := arvore.create_item(grupos[rec])
		var atual = RJ.valores(rec).get(String(e["chave"]))
		var orig = RJ.original(rec, String(e["chave"]))
		it.set_text(0, String(e["chave"]))
		it.set_text(1, _curto(var_to_str(atual)))
		it.set_text(2, _curto(var_to_str(orig)) + ("" if String(e["original_jogo"]) == "" else " · jogo original: " + String(e["original_jogo"])))
		it.set_text(3, String(e["origem"]))
		it.set_text(4, String(e["status"]))
		if var_to_str(atual) != var_to_str(orig):
			it.set_custom_color(1, Color("f0c040"))
		it.set_tooltip_text(0, String(e["descricao"]))
		it.set_metadata(0, e)


func _curto(t: String) -> String:
	t = t.replace("\n", " ")
	return t if t.length() <= 48 else t.left(45) + "…"


func _selecionar() -> void:
	var it := arvore.get_selected()
	if it == null or it.get_metadata(0) == null:
		sel = {}
		return
	sel = it.get_metadata(0)
	desc.text = "%s — %s\nOrigem %s · %s · evidência: %s" % [sel["chave"], sel["descricao"], sel["origem"], sel["status"], sel["evidencia"]]
	campo_valor.text = JSON.stringify(RJ.valores(String(sel["recurso"])).get(String(sel["chave"])))


func _aplicar() -> void:
	if sel.is_empty():
		return
	var json := JSON.new()
	if json.parse(campo_valor.text) != OK:
		_avisar("Valor inválido (use JSON: 0.5, 10, true, \"texto\", {\"a\": 1}, [1, 2]).")
		return
	var v = json.data
	var e := RJ.gravar_valor(String(sel["recurso"]), String(sel["chave"]), v, "", false)
	_avisar(e if e != "" else "%s = %s no perfil %s" % [sel["chave"], campo_valor.text, RJ.perfil()])
	if e != "":
		# a recusa (ex.: perfil original ativo) não pode passar despercebida numa linha do topo
		var dlg := AcceptDialog.new()
		dlg.title = "Game Master"
		dlg.dialog_text = e + ("\n\nEscreva um nome no campo ao lado de Perfil, clique em \"Novo perfil\" e aplique de novo." if RJ.perfil() == "original" else "")
		add_child(dlg)
		dlg.confirmed.connect(dlg.queue_free)
		dlg.canceled.connect(dlg.queue_free)
		dlg.popup_centered()
	_preencher()


# ------------------------------------------------------------------ Tabelas

func _aba_tabelas() -> Control:
	var v := VBoxContainer.new()
	v.name = "Tabelas"
	var h := HBoxContainer.new()
	v.add_child(h)
	tab_op = OptionButton.new()
	tab_op.name = "Tabela"
	for t in ["Espécies", "Itens", "Hunts"]:
		tab_op.add_item(t)
	tab_op.item_selected.connect(func(_i: int) -> void: _preencher_tab())
	h.add_child(tab_op)
	busca_tab = LineEdit.new()
	busca_tab.name = "BuscaTabela"
	busca_tab.placeholder_text = "buscar (ex.: Larvitar)"
	busca_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	busca_tab.text_submitted.connect(func(_t: String) -> void: _preencher_tab())
	h.add_child(busca_tab)
	h.add_child(_botao("Buscar", _preencher_tab))
	arvore_tab = Tree.new()
	arvore_tab.name = "ArvoreTabela"
	arvore_tab.columns = 3
	arvore_tab.column_titles_visible = true
	for i in 3:
		arvore_tab.set_column_title(i, ["Campo", "Valor (editável)", "Original"][i])
	arvore_tab.hide_root = true
	arvore_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arvore_tab.item_edited.connect(_editar_tab)
	arvore_tab.button_clicked.connect(_restaurar_tab)
	v.add_child(arvore_tab)
	v.add_child(_label("Duplo clique no valor para editar; o ↺ de cada linha restaura o original."))
	return v


func _linha(pai: TreeItem, campo: String, atual, orig, chave: Dictionary, tabela: String) -> void:
	var it := arvore_tab.create_item(pai)
	it.set_text(0, campo)
	it.set_text(1, str(atual))
	it.set_editable(1, true)
	it.set_text(2, str(orig))
	if str(atual) != str(orig):
		it.set_custom_color(1, Color("f0c040"))
	it.set_metadata(0, {"tabela": tabela, "chave": chave, "tipo": typeof(orig)})
	it.add_button(2, _icone_restaurar(), 0, false, "Restaurar original")


func _preencher_tab() -> void:
	arvore_tab.clear()
	var raiz := arvore_tab.create_item()
	var q := busca_tab.text.strip_edges().to_lower()
	if q == "":
		return
	dados = DadosJogo.carregar()   # com as alterações do perfil
	var orig_d = DadosJogo.new()
	var base := preload("res://sim/fontes.gd").pasta_dados() + "/gerados/"
	match tab_op.selected:
		0:
			for e in preload("res://sim/fontes.gd").ler_json(base + "especies.json"):
				orig_d.especies[int(e["id"])] = e
			for id in dados.especies:
				var e: Dictionary = dados.especies[id]
				if not String(e["nome"]).to_lower().contains(q) and str(id) != q:
					continue
				var o: Dictionary = orig_d.especies.get(int(id), {})
				var g := arvore_tab.create_item(raiz)
				var chance := Regras.chance_captura(3, 0.0, float(e.get("precoNpc", 0)))
				g.set_text(0, "%s (#%d)" % [e["nome"], int(id)])
				g.set_text(1, "1ª Super Ball: %.3f%%" % (chance * 100.0))
				for campo in ["xpAbate", "precoNpc", "valorVenda", "raridade"]:
					_linha(g, campo, e.get(campo), o.get(campo), {"id": int(id), "campo": campo}, "especies")
				for i in (e.get("loot", []) as Array).size():
					var l: Dictionary = e["loot"][i]
					if l.get("itemId") == null:
						continue
					var lo: Dictionary = o.get("loot", [])[i] if i < (o.get("loot", []) as Array).size() else {}
					for campo in ["chanceBruta", "min", "max"]:
						_linha(g, "drop %s · %s" % [String(l.get("item", "")), campo], l.get(campo), lo.get(campo),
							{"especie": int(id), "itemId": int(l["itemId"]), "campo": campo}, "loot")
		1:
			for i in preload("res://sim/fontes.gd").ler_json(base + "itens.json"):
				orig_d.itens[int(i["id"])] = i
			for id in dados.itens:
				var it: Dictionary = dados.itens[id]
				if not String(it.get("nome", "")).to_lower().contains(q):
					continue
				var g := arvore_tab.create_item(raiz)
				g.set_text(0, "%s (#%d)" % [it["nome"], int(id)])
				for campo in ["precoNpc", "precoGold"]:
					_linha(g, campo, it.get(campo), orig_d.itens.get(int(id), {}).get(campo), {"id": int(id), "campo": campo}, "itens")
		2:
			for h in preload("res://sim/fontes.gd").ler_json(base + "hunts.json"):
				orig_d.hunts[String(h["slug"])] = h
			for slug in dados.hunts:
				if not String(slug).contains(q) and not String(dados.hunts[slug].get("nome", "")).to_lower().contains(q):
					continue
				var g := arvore_tab.create_item(raiz)
				g.set_text(0, "%s (%s)" % [dados.hunts[slug].get("nome", slug), slug])
				_linha(g, "nivel", dados.hunts[slug].get("nivel"), orig_d.hunts.get(slug, {}).get("nivel"), {"id": slug, "campo": "nivel"}, "hunts")


func _editar_tab() -> void:
	var it := arvore_tab.get_edited()
	var m: Dictionary = it.get_metadata(0)
	var t := it.get_text(1)
	if int(m["tipo"]) != TYPE_STRING and not t.is_valid_float():
		_avisar("Valor inválido: informe um número.")
		_preencher_tab()
		return
	var v = t if int(m["tipo"]) == TYPE_STRING else float(t)
	var e := RJ.gravar_alteracao(String(m["tabela"]), m["chave"], v, "", false)
	_avisar(e if e != "" else "Alteração gravada no perfil %s." % RJ.perfil())
	_preencher_tab()


func _restaurar_tab(item: TreeItem, _col: int, _id: int, _botao_mouse: int) -> void:
	var m: Dictionary = item.get_metadata(0)
	var erro := RJ.restaurar_alteracao(String(m["tabela"]), m["chave"], "", false)
	_avisar(erro if erro != "" else "Restaurado.")
	_preencher_tab()


var _icone_reserva: Texture2D


func _icone_restaurar() -> Texture2D:
	## Ícone "Reload" do editor; fora dele (testes), um quadrado simples para o botão não ficar sem textura.
	if has_theme_icon("Reload", "EditorIcons"):
		return get_theme_icon("Reload", "EditorIcons")
	if _icone_reserva == null:
		var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.8, 0.8))
		_icone_reserva = ImageTexture.create_from_image(img)
	return _icone_reserva
